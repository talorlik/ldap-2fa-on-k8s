# ldap-2fa-on-k8s

LDAP authentication with 2FA deployed on Kubernetes (EKS)

This project deploys a complete LDAP authentication solution with two-factor
authentication (2FA), self-service password management, and GitOps capabilities
on Amazon EKS using Terraform. The infrastructure includes:

**Core Infrastructure:**

- **EKS Cluster** (Auto Mode) with IRSA for secure pod-to-AWS-service
authentication
- **VPC** with public/private subnets and VPC endpoints for private AWS service
access
- **Application Load Balancer (ALB)** via EKS Auto Mode for internet-facing
access
- **Route53 DNS** integration for domain management
- **ACM Certificates** for HTTPS/TLS termination

**LDAP Stack:**

- **OpenLDAP Stack** with high availability and multi-master replication
- **PhpLdapAdmin** web interface for LDAP administration
- **LTB-passwd** self-service password management UI

**2FA Application:**

- **Full-stack 2FA application** with Python FastAPI backend and static
HTML/JS/CSS frontend
- **Dual MFA methods**: TOTP (authenticator apps) and SMS (AWS SNS)
- **LDAP integration** for centralized user authentication
- **Self-service user registration** with email/phone verification
- **Admin dashboard** for user management, group CRUD, and approval workflows

**Supporting Infrastructure:**

- **PostgreSQL** for user registration and verification token storage
- **Redis** for SMS OTP code storage with TTL-based expiration
- **AWS SES** for email verification and notifications
- **AWS SNS** for SMS-based 2FA verification

**DevOps & Security:**

- **ArgoCD** (AWS EKS managed service) for GitOps deployments
- **cert-manager** for automatic TLS certificate management
- **Network Policies** for securing pod-to-pod communication
- **IRSA** (IAM Roles for Service Accounts) for secure AWS API access from pods

## Prerequisites

- AWS Account(s) with appropriate permissions
  - **State Account (Account A)**: For Terraform state storage (S3)
  - **Deployment Account (Account B)**: For infrastructure resources (EKS, ALB,
  Route53, etc.)
- GitHub Account
- Fork the repository:
[ldap-2fa-on-k8s](https://github.com/talorlik/ldap-2fa-on-k8s.git)
- AWS SSO/OIDC configured (see [GitHub Repository
Configuration](#github-repository-configuration))
- Route53 hosted zone must already exist (or create it manually)
- ACM certificate must already exist and be validated in the same region as the
EKS cluster

## Project Structure

```text
ldap-2fa-on-k8s/
├── tf_backend_state/      # Terraform state backend infrastructure (S3) - Account A
├── backend_infra/         # Core AWS infrastructure (VPC, EKS, VPC endpoints, IRSA) - Account B
├── application/           # Application infrastructure and deployments - Account B
│   ├── backend/           # 2FA Backend (Python FastAPI)
│   ├── frontend/          # 2FA Frontend (HTML/JS/CSS + nginx)
│   ├── helm/              # Helm values for OpenLDAP stack
│   └── modules/           # Terraform modules (ALB, ArgoCD, SNS, cert-manager, etc.)
└── .github/workflows/     # GitHub Actions workflows for CI/CD
```

For detailed information about each component, see:

- [Terraform Backend State](tf_backend_state/README.md) - S3 state management
  with file-based locking (v1.0.0), AWS provider 6.21.0, Terraform 1.14.0
- [Backend Infrastructure](backend_infra/README.md) - VPC, EKS, IRSA, VPC
  endpoints
- [Application Infrastructure](application/README.md) - OpenLDAP, 2FA app,
  ArgoCD

## Multi-Account Architecture

This project uses a **multi-account architecture** for enhanced security:

- **Account A (State Account)**: Stores Terraform state files in S3
  - S3 bucket with versioning enabled and server-side encryption (AES256)
  - S3 file-based locking (`use_lockfile = true`) for state file
    concurrency control
  - IAM-based access control with OIDC authentication (no access keys
    required)
  - GitHub Actions authenticates with Account A for backend operations
  - Provides isolation between state storage and resource deployment

- **Account B (Deployment Account)**: Contains all infrastructure resources
  - EKS cluster, VPC, ALB, Route53, and other AWS resources
  - Terraform provider assumes Account B role via cross-account role assumption
  - Provides isolation and separation of concerns

### How It Works

1. **GitHub Actions** assumes Account A role (via OIDC) for Terraform backend
access
2. **Terraform backend** uses Account A credentials to read/write state files
3. **Terraform AWS provider** assumes Account B role (via `assume_role`) for
resource deployment
4. **Remote state** data sources use Account A credentials to read state from
Account A

This architecture ensures:

- State files are isolated in a dedicated account
- Resource deployment uses separate credentials
- Enhanced security through account separation
- Better compliance and audit capabilities

## GitHub Repository Configuration

### AWS SSO/OIDC Setup

This project uses **AWS SSO via GitHub OIDC** instead of access keys for
enhanced security.

#### GitHub Secrets

> [!NOTE]
>
> For complete secrets configuration details, including AWS Secrets Manager setup for local scripts, see [Secrets Requirements](application/SECRETS_REQUIREMENTS.md).

Configure these secrets in your GitHub repository:
**Repository → Settings → Secrets and variables → Actions → Secrets**

**Required Secrets:**

- `AWS_STATE_ACCOUNT_ROLE_ARN` - IAM role ARN for state account (backend operations)
- `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` - IAM role ARN for production deployments
- `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` - IAM role ARN for development deployments
- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP config password
- `TF_VAR_POSTGRESQL_PASSWORD` - PostgreSQL database password
- `TF_VAR_REDIS_PASSWORD` - Redis password (minimum 8 characters)
- `GH_TOKEN` - GitHub Personal Access Token with `repo` scope

> [!NOTE]
>
> For SMS 2FA functionality, the SNS VPC endpoint must be enabled in
> backend_infra (`enable_sns_endpoint = true`). See [Backend Infrastructure
> README](backend_infra/README.md#vpc-endpoints-module) for details.

#### AWS IAM Setup

**Account A (State Account):**

##### Step 1: Create OIDC Identity Provider

The OIDC Identity Provider establishes trust between GitHub Actions and AWS,
allowing GitHub to authenticate without access keys.

1. **Navigate to IAM Console**:
   - Go to AWS IAM Console → **Identity providers** (left sidebar)
   - Click **Add provider**

2. **Configure Provider**:
   - Select **OpenID Connect**
   - **Provider URL**: `https://token.actions.githubusercontent.com`
   - Click **Get thumbprint** (AWS will automatically fetch GitHub's certificate
   thumbprint)
   - **Audience**: `sts.amazonaws.com`
   - Click **Add provider**

3. **Verify Creation**:
   - You should see the provider listed with ARN format:
   `arn:aws:iam::ACCOUNT_A_ID:oidc-provider/token.actions.githubusercontent.com`
   - Note this ARN - you'll need it for the role trust policy

##### Step 2: Create IAM Role and Assign to Identity Provider

Now create an IAM Role that uses this Identity Provider for authentication.

1. **Navigate to IAM Roles**:
   - Go to AWS IAM Console → **Roles** (left sidebar)
   - Click **Create role**

2. **Select Trusted Entity Type**:
   - Under **Trusted entity type**, select **Web identity**
   - Under **Web identity**, select the Identity Provider you just created:
   `token.actions.githubusercontent.com`
   - **Audience**: Select `sts.amazonaws.com` from the dropdown
   - Click **Next**

3. **Configure Trust Policy Conditions** (Optional but Recommended):
   - Click **Add condition** to restrict which repositories can assume this role
   - **Condition key**: `token.actions.githubusercontent.com:sub`
   - **Operator**: `StringLike`
   - **Value**: `repo:YOUR_ORG/YOUR_REPO:*` (replace `YOUR_ORG/YOUR_REPO` with
   your GitHub organization and repository name)
     - Example: `repo:talorlik/ldap-2fa-on-k8s:*`
   - This ensures only workflows from your specific repository can assume the
   role
   - Click **Next**

4. **Add Permissions**:
   - Create or attach a policy with S3 permissions for the state bucket
   - **Minimum required permissions**:

     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "s3:GetObject",
             "s3:PutObject",
             "s3:DeleteObject",
             "s3:ListBucket"
           ],
           "Resource": [
             "arn:aws:s3:::your-state-bucket-name",
             "arn:aws:s3:::your-state-bucket-name/*"
           ]
         }
       ]
     }
     ```

   - For initial setup, you can use a broader policy and restrict it later once
   you know the exact bucket name
   - Click **Next**

5. **Name and Create Role**:
   - **Role name**: `github-actions-state-role` (or your preferred name)
   - **Description**: "Role for GitHub Actions to access Terraform state bucket"
   - Click **Create role**

6. **Copy Role ARN**:
   - After creation, click on the role name
   - Copy the **Role ARN** (format:
   `arn:aws:iam::STATE_ACCOUNT_ID:role/github-actions-state-role`)
   - Set this as the `AWS_STATE_ACCOUNT_ROLE_ARN` secret in GitHub

**Important Notes:**

- The Identity Provider must be created **before** the IAM Role
- The IAM Role's trust policy automatically references the Identity Provider you
selected
- The condition on `token.actions.githubusercontent.com:sub` restricts access to
your specific repository
- You can update the trust policy later to add more repositories or adjust
conditions

**Account B (Production/Development Accounts):**

For each deployment account (Production and Development), create separate IAM
roles:

1. **Production Account**: Create an IAM Role that trusts the State Account
role:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::STATE_ACCOUNT_ID:role/github-actions-state-role"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```

2. Attach permissions policy with full resource deployment permissions

3. Copy the role ARN → Set as `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` secret

4. **Development Account**: Repeat steps 1-3 for the Development account

5. Copy the Development account role ARN → Set as
`AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` secret

> [!NOTE]
>
> - The State Account role (`AWS_STATE_ACCOUNT_ROLE_ARN`) is used for backend
state operations (S3)
> - The Production/Development roles are used by the Terraform provider via
`assume_role` for resource deployment
> - The workflow automatically selects the appropriate deployment role ARN based
on whether `prod` or `dev` environment is chosen
> - For single-account setups, you can use the same role ARN for state and
deployment, but multi-account is recommended for better security isolation

## Terraform Deployment

The deployment follows a three-tier approach:

### 1. Deploy Terraform Backend State Infrastructure

Deploy the Terraform backend state infrastructure by running the
`tfstate_infra_provisioning.yaml` workflow via the GitHub UI.

> [!NOTE]
>
> 📖 **For detailed setup instructions**, including required GitHub Secrets,
> Variables, and configuration, see the [Terraform Backend State
> README](tf_backend_state/README.md).

> [!IMPORTANT]
>
> Make sure to alter the values in the variables.tfvars according to your setup
> and to commit and push them.

### 2. Deploy Backend Infrastructure

Deploy the main backend infrastructure (VPC, EKS cluster, VPC endpoints, IRSA,
ECR).

This creates the foundational infrastructure including:

- VPC with public/private subnets
- EKS cluster with Auto Mode
- IRSA (OIDC provider for pod IAM roles)
- VPC endpoints (SSM, STS, and optionally SNS for SMS 2FA)
- ECR repository for container images

> [!NOTE]
>
> 📖 **For detailed information about the backend infrastructure**, including
> architecture, components, and module documentation, see the [Backend
> Infrastructure README](backend_infra/README.md).

### 3. Deploy Application Infrastructure

Deploy the application infrastructure (OpenLDAP stack, 2FA application, ALB,
Route53 records, and optionally ArgoCD).

This deploys:

- OpenLDAP Stack HA with PhpLdapAdmin and LTB-passwd
- 2FA Application (backend + frontend) with TOTP and SMS support
- ALB with host-based routing for all services
- cert-manager for TLS certificates
- Network policies for security
- ArgoCD for GitOps (optional)
- SNS resources for SMS 2FA (optional)

> [!NOTE]
>
> 📖 **For detailed information about the application infrastructure**, including
> OpenLDAP configuration, 2FA app setup, ALB configuration, and deployment steps,
> see the [Application Infrastructure README](application/README.md).

## Local Development Setup

Before running Terraform locally, you need to generate the `backend.hcl` file
and update `variables.tfvars` with your selected region and environment. The
repository includes `tfstate-backend-values-template.hcl` as a template showing
what values need to be configured.

> [!IMPORTANT]
>
> For Backend State Infrastructure**: For local deployment of
> `tf_backend_state`, use the provided automation scripts (`set-state.sh` and
> `get-state.sh`). These scripts automatically handle role assumption, Terraform
> operations, state file management, and repository variable updates. The scripts
> retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` from AWS Secrets Manager (v1.0.0) and
> assume the role automatically. See [Terraform Backend State
> README](tf_backend_state/README.md#option-2-local-execution) for detailed
> instructions.

### Backend Infrastructure Setup

#### Option 1: Using GitHub CLI (Recommended)

If you have the GitHub CLI (`gh`) installed and authenticated:

```bash
cd backend_infra
./setup-backend.sh
```

This script will:

- Prompt you to select an AWS region (us-east-1 or us-east-2)
- Prompt you to select an environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` and assume it for backend state
operations
- Retrieve the appropriate deployment account role ARN from AWS Secrets Manager based
on the selected environment:
  - `prod` → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the
actual values
- Update `variables.tfvars` with the selected region, environment, and
deployment account role ARN
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!NOTE]
>
> The script retrieves role ARNs from AWS Secrets Manager. See [Secrets Requirements](application/SECRETS_REQUIREMENTS.md) for setup instructions.

> [!NOTE]
>
> The generated `backend.hcl` file is automatically ignored by git (see
> `.gitignore`). Only the placeholder template
> (`tfstate-backend-values-template.hcl`) is committed to the repository.

### Application Infrastructure Setup

#### Using GitHub CLI (Recommended)

If you have the GitHub CLI (`gh`) installed and authenticated:

```bash
cd application
./setup-application.sh
```

This script will:

- Prompt you to select an AWS region (us-east-1 or us-east-2)
- Prompt you to select an environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` and assume it for backend state
operations
- Retrieve the appropriate deployment account role ARN from AWS Secrets Manager based
on the selected environment:
  - `prod` → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
- Retrieve password secrets from AWS Secrets Manager and export them as environment variables
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the
actual values (if it doesn't exist)
- Update `variables.tfvars` with the selected region, environment, and
deployment account role ARN
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!NOTE]
>
> The script automatically retrieves all required secrets from AWS Secrets Manager. See [Secrets Requirements](application/SECRETS_REQUIREMENTS.md) for setup instructions.

> [!NOTE]
>
> The generated `backend.hcl` file is automatically ignored by git (see
> `.gitignore`). Only the placeholder template
> (`tfstate-backend-values-template.hcl`) is committed to the repository.

**Important:** Before deploying the application infrastructure, you must:

1. **Configure secrets**: See [Secrets Requirements](application/SECRETS_REQUIREMENTS.md) for complete setup instructions.
   - For local use: Scripts automatically retrieve passwords from AWS Secrets Manager
   - For GitHub Actions: Secrets must be configured in repository settings

2. Ensure Route53 hosted zone exists for your domain
3. Ensure ACM certificate exists and is validated in the same region as your EKS
cluster

## Running Terraform

### Backend Infrastructure

After setting up the backend configuration:

```bash
cd backend_infra

terraform init -backend-config="backend.hcl"

# Workspace name is dynamic based on region and environment
# For example: us-east-1-prod, us-east-2-dev, etc.
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>

terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"

# To destroy all the resources that were created
terraform plan -var-file="variables.tfvars" -destroy -out "terraform.tfplan"

terraform apply -auto-approve "terraform.tfplan"
```

### Application Infrastructure

After backend infrastructure is deployed, use the automated setup script:

```bash
cd application
./setup-application.sh
```

The script automatically handles:

- Backend configuration setup
- Retrieval of secrets from AWS Secrets Manager (for local use) or GitHub repository secrets (for GitHub Actions)
- Terraform initialization
- Workspace selection/creation
- Kubernetes environment variable configuration
- Terraform validation, planning, and application

> [!NOTE]
>
> For secrets configuration, see [Secrets Requirements](application/SECRETS_REQUIREMENTS.md).

## Architecture Overview

### Backend Infrastructure Components

The backend infrastructure provides the foundational AWS resources for deploying containerized applications on Kubernetes. Key components include:

- **VPC** with public and private subnets across multiple availability zones
- **EKS Cluster** in Auto Mode with automatic node provisioning
- **IRSA (IAM Roles for Service Accounts)** for secure pod-to-AWS-service authentication
- **VPC Endpoints** for private AWS service access (SSM, STS, SNS)
- **ECR Repository** for container image storage

For detailed architecture diagrams, component descriptions, and configuration options, see the [Backend Infrastructure README](backend_infra/README.md).

### Application Infrastructure Components

The application infrastructure deploys the LDAP stack, 2FA application, and supporting services on the EKS cluster. Key components include:

- **OpenLDAP Stack HA** with PhpLdapAdmin and LTB-passwd UIs
- **2FA Application** with self-service registration and admin dashboard
- **Application Load Balancer (ALB)** via EKS Auto Mode for internet-facing access
- **Supporting Services**: PostgreSQL, Redis, SES, SNS (optional)
- **GitOps**: ArgoCD (AWS managed service) for declarative deployments
- **Security**: cert-manager for TLS, Network Policies for pod-to-pod security

For detailed architecture diagrams, component descriptions, API specifications, and deployment instructions, see the [Application Infrastructure README](application/README.md).

## Key Features

- **EKS Auto Mode**: Simplified cluster management with automatic load balancer
provisioning and built-in EBS CSI driver
- **Two-Factor Authentication**: Full-stack 2FA application with dual MFA
methods (TOTP and SMS)
- **Self-Service User Registration**: Email and phone verification with profile
state management (PENDING → COMPLETE → ACTIVE)
- **Admin Dashboard**: User management, group CRUD operations, and approval
workflows for user activation
- **IRSA Integration**: Secure AWS API access from pods without hardcoded
credentials
- **High Availability**: Multi-master OpenLDAP replication with persistent
storage
- **GitOps Ready**: ArgoCD (AWS managed service) for declarative, Git-driven
deployments
- **Internet-Facing Access**: Secure HTTPS access to UIs via single ALB with
host-based routing
- **Self-Service Password Management**: LTB-passwd for user password resets
- **Automated DNS**: Route53 integration for seamless domain management
- **Secure by Default**: TLS termination, encrypted storage, network policies,
VPC endpoints for private AWS access
- **Multi-Account Architecture**: Separation of state storage and resource
deployment for enhanced security

## MFA Methods

The 2FA application supports two multi-factor authentication methods:

| Method | Description | Infrastructure Required |
| -------- | ------------- | ------------------------ |
| **TOTP** | Time-based One-Time Password using authenticator apps (Google Authenticator, Authy, etc.) | None (codes generated locally) |
| **SMS** | Verification codes sent via AWS SNS to user's phone | SNS VPC endpoint, IRSA role |

For detailed API specifications, frontend architecture, and implementation details, see:
- [2FA Application PRD](application/PRD-2FA-APP.md) - Complete API and frontend specifications
- [SMS OTP Management PRD](application/PRD-SMS-MAN.md) - Redis-based SMS OTP storage implementation
- [SNS Module Documentation](application/modules/sns/README.md) - SMS 2FA infrastructure setup

## Accessing the Services

After deployment:

- **2FA Application**: `https://app.${domain_name}` (e.g.,
`https://app.talorlik.com`)
  - Self-service user registration with email/phone verification
  - Two-factor authentication enrollment and login
  - TOTP setup with QR code or SMS verification
  - User profile management
  - Admin dashboard (for LDAP admin group members)
  - **API Documentation**: `https://app.${domain_name}/api/docs` - Interactive
  Swagger UI for API exploration and testing
  - **ReDoc Documentation**: `https://app.${domain_name}/api/redoc` - Alternative
  API documentation interface
- **PhpLdapAdmin**: `https://phpldapadmin.${domain_name}` (e.g.,
`https://phpldapadmin.talorlik.com`)
  - LDAP administration interface
- **LTB-passwd**: `https://passwd.${domain_name}` (e.g.,
`https://passwd.talorlik.com`)
  - Self-service password management
- **ArgoCD** (if enabled): URL from Terraform output `argocd_server_url`
  - GitOps deployment management (AWS Identity Center authentication)
- **LDAP Service**: Cluster-internal only (not exposed externally)

## Documentation

### Infrastructure Documentation

- [Terraform Backend State README](tf_backend_state/README.md) - S3 state
  management with file-based locking (v1.0.0), AWS Secrets Manager
  integration, and GitHub variable configuration
- [Backend Infrastructure README](backend_infra/README.md) - VPC, EKS, IRSA, VPC
endpoints, and ECR documentation
- [Application Infrastructure README](application/README.md) - OpenLDAP, 2FA
app, ALB, ArgoCD, and deployment instructions

### Application Documentation

- [2FA Application PRD](application/PRD-2FA-APP.md) - Product requirements for
the 2FA application (API specs, frontend architecture)
- [User Signup Management PRD](application/PRD-SIGNUP-MAN.md) - Self-service
user registration with email/phone verification
- [Admin Functions PRD](application/PRD-ADMIN-FUNCS.md) - Admin dashboard, group
management, and approval workflows
- [SMS OTP Management PRD](application/PRD-SMS-MAN.md) - Redis-based SMS OTP
storage with TTL
- [OpenLDAP README](application/OPENLDAP-README.md) - OpenLDAP configuration and
TLS setup
- [Security Improvements](application/SECURITY-IMPROVEMENTS.md) - Security
enhancements and best practices

### Module Documentation

- [ALB Module](application/modules/alb/README.md) - EKS Auto Mode ALB configuration
- [ArgoCD Module](application/modules/argocd/README.md) - AWS managed ArgoCD
setup
- [ArgoCD Application Module](application/modules/argocd_app/README.md) -
GitOps application deployment
- [cert-manager Module](application/modules/cert-manager/README.md) - TLS
certificate management
- [Network Policies Module](application/modules/network-policies/README.md) -
Pod-to-pod security
- [PostgreSQL Module](application/modules/postgresql/README.md) - User data and
verification token storage
- [Redis Module](application/modules/redis/README.md) - SMS OTP code storage
- [SES Module](application/modules/ses/README.md) - Email verification and
notifications
- [SNS Module](application/modules/sns/README.md) - SMS 2FA integration
- [VPC Endpoints Module](backend_infra/modules/endpoints/README.md) - Private
AWS service access
- [ECR Module](backend_infra/modules/ecr/README.md) - Container registry setup

### Changelogs

- [Project Changelog](CHANGELOG.md) - All project changes
- [Backend Infrastructure Changelog](backend_infra/CHANGELOG.md) - VPC, EKS, VPC endpoints, and ECR changes
- [Application Infrastructure Changelog](application/CHANGELOG.md) - OpenLDAP, 2FA app, and supporting services changes
- [Terraform Backend State Changelog](tf_backend_state/CHANGELOG.md) - S3 state management changes

## Security Considerations

- **Secrets Management**: Passwords managed via AWS Secrets Manager (for local scripts) and GitHub repository secrets (for GitHub Actions). See [Secrets Requirements](application/SECRETS_REQUIREMENTS.md) for details.
- **IRSA**: Pods assume IAM roles via OIDC—no long-lived AWS credentials
- **VPC Endpoints**: AWS service access (SSM, STS, SNS) goes through private
endpoints—no public internet exposure
- **TLS Termination**: HTTPS at ALB using ACM certificates; internal TLS via
cert-manager
- **LDAP Security**: ClusterIP only (not exposed externally), cross-namespace
access on secure ports only
- **Network Policies**: Pod-to-pod communication restricted to encrypted ports
(443, 636, 8443)
- **Storage Encryption**: EBS volumes encrypted by default
- **Network Isolation**: EKS nodes run in private subnets
- **Multi-Account Isolation**: State storage separated from resource deployment

See [Security Improvements](application/SECURITY-IMPROVEMENTS.md) for detailed
security documentation.

## Troubleshooting

See the individual README files for troubleshooting guides:

- [Backend Infrastructure Troubleshooting](backend_infra/README.md#troubleshooting)
- [Application Infrastructure Troubleshooting](application/README.md#troubleshooting)

## License

See [LICENSE](LICENSE) file for details.
