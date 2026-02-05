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
- **Public ACM Certificate Setup**: Public ACM certificates must be requested in
  each deployment account and validated using DNS records in the State Account's
  Route53 hosted zone. See [Public ACM Certificate Setup and DNS Validation](application_infra/CROSS-ACCOUNT-ACCESS.md#public-acm-certificate-setup-and-dns-validation)
  for detailed setup instructions with step-by-step AWS CLI commands.
- ACM certificate must already exist and be validated in the same region as the
  EKS cluster
  - Certificate must be a public ACM certificate (Amazon-issued) requested in
    the Deployment Account
  - Certificate must exist in the Deployment Account (not State Account)
  - Certificate must be validated and in `ISSUED` status
  - DNS validation records must be created in Route53 hosted zone in the State
    Account
  - See [Cross-Account Access Documentation](application_infra/CROSS-ACCOUNT-ACCESS.md)
    for details
- **Docker (for Local Deployment)**: Docker must be installed and running for
  ECR image mirroring. The `mirror-images-to-ecr.sh` script requires Docker to
  pull images from Docker Hub and push them to ECR. This step is automatically
  executed by `setup-application-infra.sh` before Terraform operations.
- **jq (for Local Deployment)**: The `jq` command-line tool is required for
  JSON parsing in the image mirroring script (with fallback to sed for
  compatibility).
- **ECR Image Tags**: Images are mirrored to ECR with standardized tags:
  - `openldap-1.5.0` (corresponds to `osixia/openldap:1.5.0`) - mirrored by infrastructure
  - `redis-latest` (corresponds to `bitnami/redis:8.4.0-debian-12-r6`) - mirrored
  by application
  - `postgresql-latest` (corresponds to `bitnami/postgresql:18.1.0-debian-12-r4`)
  mirrored by application

## Project Structure

```bash
ldap-2fa-on-k8s/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── workflows/
│       ├── application_destroying.yaml
│       ├── application_infra_destroying.yaml
│       ├── application_infra_provisioning.yaml
│       ├── application_provisioning.yaml
│       ├── backend_build_push.yaml
│       ├── backend_infra_destroying.yaml
│       ├── backend_infra_provisioning.yaml
│       ├── frontend_build_push.yaml
│       ├── tfstate_infra_destroying.yaml
│       └── tfstate_infra_provisioning.yaml
├── .gitignore
├── .markdownlint.json
├── .repomixignore
├── application_infra/               # Application infrastructure - Account B
│   ├── helm/                        # Helm values templates
│   │   └── openldap-values.tpl.yaml
│   ├── modules/                     # Infrastructure Terraform modules
│   │   ├── alb/                     # Application Load Balancer
│   │   ├── argocd/                  # ArgoCD Capability (AWS managed service)
│   │   ├── cert-manager/            # TLS certificate management
│   │   ├── network-policies/        # Pod-to-pod security
│   │   ├── openldap/                # OpenLDAP stack
│   │   ├── route53/                 # Route53 hosted zone
│   │   └── route53_record/          # Route53 DNS records
│   ├── CHANGELOG.md
│   ├── CROSS-ACCOUNT-ACCESS.md
│   ├── destroy-application-infra.sh
│   ├── main.tf
│   ├── mirror-images-to-ecr.sh
│   ├── OPENLDAP-README.md
│   ├── OSIXIA-OPENLDAP-REQUIREMENTS.md
│   ├── outputs.tf
│   ├── PRD-ALB.md
│   ├── PRD-ArgoCD.md
│   ├── PRD-DOMAIN.md
│   ├── providers.tf
│   ├── README.md
│   ├── SECURITY-IMPROVEMENTS.md
│   ├── set-k8s-env.sh
│   ├── setup-application-infra.sh
│   ├── tfstate-backend-values-template.hcl
│   ├── variables.tf
│   └── variables.tfvars
├── application/                     # 2FA Application code and dependencies - Account B
│   ├── backend/                     # 2FA Backend (Python FastAPI)
│   │   ├── Dockerfile
│   │   ├── helm/
│   │   │   └── ldap-2fa-backend/
│   │   │       ├── Chart.yaml
│   │   │       ├── values.yaml
│   │   │       └── templates/
│   │   └── src/
│   │       └── app/
│   │           ├── api/
│   │           ├── config.py
│   │           ├── database/
│   │           ├── email/
│   │           ├── ldap/
│   │           ├── main.py
│   │           ├── mfa/
│   │           ├── redis/
│   │           └── sms/
│   ├── frontend/                    # 2FA Frontend (HTML/JS/CSS + nginx)
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── helm/
│   │   │   └── ldap-2fa-frontend/
│   │   │       ├── Chart.yaml
│   │   │       ├── values.yaml
│   │   │       └── templates/
│   │   └── src/
│   │       ├── css/
│   │       ├── index.html
│   │       └── js/
│   ├── helm/                        # Application Helm values templates
│   │   ├── postgresql-values.tpl.yaml
│   │   └── redis-values.tpl.yaml
│   ├── modules/                     # Application Terraform modules
│   │   ├── argocd_app/              # ArgoCD Application CRDs
│   │   ├── postgresql/              # PostgreSQL database
│   │   ├── redis/                   # Redis for SMS OTP storage
│   │   ├── ses/                     # AWS SES for email
│   │   └── sns/                     # AWS SNS for SMS
│   ├── CHANGELOG.md
│   ├── DEPLOY-2FA-APPS.md
│   ├── destroy-application.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── PRD-2FA-APP.md
│   ├── PRD-ADMIN-FUNCS.md
│   ├── PRD-SIGNUP-MAN.md
│   ├── PRD-SMS-MAN.md
│   ├── providers.tf
│   ├── README.md
│   ├── setup-application.sh
│   ├── tfstate-backend-values-template.hcl
│   ├── variables.tf
│   └── variables.tfvars
├── backend_infra/                  # Core AWS infrastructure (VPC, EKS, VPC endpoints, IRSA) - Account B
│   ├── modules/
│   │   ├── ebs/                    # EBS CSI driver
│   │   ├── ecr/                    # ECR repository
│   │   └── endpoints/              # VPC endpoints
│   ├── CHANGELOG.md
│   ├── destroy-backend.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── README.md
│   ├── setup-backend.sh
│   ├── tfstate-backend-values-template.hcl
│   ├── variables.tf
│   └── variables.tfvars
├── docs/                           # Documentation website
│   ├── dark-theme.css
│   ├── favicon.ico
│   ├── header_banner.png
│   ├── index.html
│   └── light-theme.css
├── tf_backend_state/               # Terraform state backend infrastructure (S3) - Account A
│   ├── CHANGELOG.md
│   ├── get-state.sh
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── README.md
│   ├── set-state.sh
│   ├── variables.tf
│   └── variables.tfvars
├── CHANGELOG.md
├── LICENSE
├── monitor-deployments.sh          # Deployment monitoring script
├── README.md                       # This file
├── repomix-instructions.md
├── repomix-output.md
├── repomix.config.json
├── SECRETS_REQUIREMENTS.md         # Secrets management documentation (AWS Secrets Manager & GitHub Secrets)
└── WARP.md
```

For detailed information about each component, see:

- [Terraform Backend State](tf_backend_state/README.md) - S3 state management
  with file-based locking (v1.0.0), AWS provider 6.21.0, Terraform 1.14.0
- [Backend Infrastructure](backend_infra/README.md) - VPC, EKS, IRSA, VPC
  endpoints
- [Application Infrastructure](application_infra/README.md) - OpenLDAP, ALB,
ArgoCD Capability
- [Application Deployment](application/README.md) - 2FA app, PostgreSQL, Redis,
SES, SNS

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
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals": {
             "sts:ExternalId": "<generated-external-id>"
           }
         }
       }
     ]
   }
   ```

   Replace `<generated-external-id>` with the ExternalId value (generate using
   `openssl rand -hex 32`). This ExternalId must match the value stored in
   `AWS_ASSUME_EXTERNAL_ID` secret (for GitHub Actions) or AWS Secrets Manager
   (for local deployment).

2. Attach permissions policy with full resource deployment permissions

3. Copy the role ARN → Set as `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` secret

4. **Development Account**: Repeat steps 1-3 for the Development account

5. Copy the Development account role ARN → Set as
`AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` secret

#### State Account Role Trust Relationship Update

> [!IMPORTANT]
>
> In addition to the deployment account roles trusting the state account role, the
> state account role's Trust Relationship must also be updated to allow the
> deployment account roles. This bidirectional trust is required for proper
> cross-account role assumption.
>
> **Note:** The ExternalId security mechanism is still required when the state
> account role assumes deployment account roles. The ExternalId condition must be
> present in the deployment account roles' Trust Relationships (as documented
> above), and the state account role must provide the ExternalId when assuming
> those roles.

Update the state account role's (`github-actions-state-role`) Trust Relationship
to include the deployment account roles:

1. Navigate to the state account role in IAM Console
2. Go to **Trust relationships** tab
3. Click **Edit trust policy**
4. Add the deployment account role ARNs to the trust policy:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::STATE_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
           }
         }
       },
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": [
             "arn:aws:iam::PRODUCTION_ACCOUNT_ID:role/github-role",
             "arn:aws:iam::DEVELOPMENT_ACCOUNT_ID:role/github-role",
             "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
           ]
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```

   Replace `PRODUCTION_ACCOUNT_ID` and `DEVELOPMENT_ACCOUNT_ID` with your actual
   account IDs, and `github-role` with your actual deployment role names.

   > [!IMPORTANT]
   >
   > **Self-Assumption Statement**: The last statement allows the role to assume
   > itself. This is required when:
   > - The State Account role is used for both backend state operations and
   > Route53/ACM access
   > - Terraform providers need to assume the same role that was already assumed
   > by the initial authentication
   > - You encounter errors like "User: arn:aws:sts::ACCOUNT_ID:assumed-role/github-role/SESSION
   > is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::ACCOUNT_ID:role/github-role"

5. Click **Update policy**

> [!NOTE]
>
> Remember that the deployment account roles' Trust Relationships must still
> include the ExternalId condition (as shown in step 1 above), and the state
> account role must provide this ExternalId when assuming the deployment account
> roles. The ExternalId is retrieved from `AWS_ASSUME_EXTERNAL_ID` secret (for
> GitHub Actions) or AWS Secrets Manager (for local deployment).

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
> - **Bidirectional Trust**: Both the deployment account roles and the state
account role must trust each other in their respective Trust Relationships

## Secrets Configuration

**Required Secret Values:**

- `AWS_STATE_ACCOUNT_ROLE_ARN` - IAM role ARN for state account (backend operations)
- `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` - IAM role ARN for production deployments
- `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` - IAM role ARN for development deployments
- `AWS_ASSUME_EXTERNAL_ID` - ExternalId for cross-account role assumption security
(must match value in deployment account role Trust Relationship)
- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP config password
- `TF_VAR_POSTGRESQL_PASSWORD` - PostgreSQL database password
- `TF_VAR_REDIS_PASSWORD` - Redis password (minimum 8 characters)
- `GH_TOKEN` - GitHub Personal Access Token with `repo` scope

> [!IMPORTANT]
>
> Read the complete secrets configuration details here [Secrets Requirements](SECRETS_REQUIREMENTS.md).

### For GitHub Actions

Configure these secrets in your GitHub repository:
**Repository → Settings → Secrets and variables → Actions → Secrets**

### For Local Development

- Store secrets in AWS Secrets Manager (scripts automatically retrieve them)
- **ExternalId**: Store as plain text secret named `external-id` in
AWS Secrets Manager
  - Generate using: `openssl rand -hex 32`
  - Must match the ExternalId in deployment account role Trust Relationships

## Deployment Methods

This project supports two deployment methods: **GitHub Actions** (recommended)
and **Local Development** (for testing and development).
Both methods follow the same three-tier deployment approach.

### Deployment Overview

The deployment follows a three-tier approach that must be executed in order:

1. **Terraform Backend State Infrastructure** - S3 state storage (Account A)
2. **Backend Infrastructure** - VPC, EKS, VPC endpoints, IRSA, ECR (Account B)
3. **Application Infrastructure** - OpenLDAP, 2FA app, ALB, Route53, ArgoCD
(Account B)

> [!IMPORTANT]
>
> Before deploying, ensure:
>
> - Route53 hosted zone exists for your domain
> - ACM certificate exists and is validated in the same region as your EKS cluster
> - Secrets are configured (see [Secrets Configuration](#secrets-configuration))

### Method 1: GitHub Actions (CI/CD)

Deploy infrastructure using GitHub Actions workflows for automated, repeatable deployments.

#### Step 1. Deploy Terraform Backend State Infrastructure

Run the `tfstate_infra_provisioning.yaml` workflow via the GitHub UI.

> [!NOTE]
>
> 📖 **For detailed setup instructions**, including required GitHub Secrets,
> Variables, and configuration, see the [Terraform Backend State README](tf_backend_state/README.md).

> [!IMPORTANT]
>
> Make sure to alter the values in `variables.tfvars` according to your setup
> and commit and push them.

#### Step 2. Deploy Backend Infrastructure

Deploy the main backend infrastructure (VPC, EKS cluster, VPC endpoints, IRSA, ECR).

This creates the foundational infrastructure including:

- VPC with public/private subnets
- EKS cluster with Auto Mode
- IRSA (OIDC provider for pod IAM roles)
- VPC endpoints (SSM, STS, and optionally SNS for SMS 2FA)
- ECR repository for container images

> [!NOTE]
>
> 📖 **For detailed information about the backend infrastructure**, including
> architecture, components, and module documentation,
> see the [Backend Infrastructure README](backend_infra/README.md).

> [!IMPORTANT]
>
> For SMS 2FA functionality, the SNS VPC endpoint must be enabled in
> backend_infra (`enable_sns_endpoint = true`). See [Backend Infrastructure
> README](backend_infra/README.md#vpc-endpoints-module) for details.

#### Step 3. Deploy Application Infrastructure

Deploy the application infrastructure (OpenLDAP stack, ALB, Route53 records,
ArgoCD Capability, and StorageClass).

This deploys:

- OpenLDAP Stack HA with PhpLdapAdmin and LTB-passwd
- ALB with host-based routing for LDAP UIs
- cert-manager for TLS certificates
- Network policies for security
- ArgoCD Capability for GitOps (optional)
- StorageClass for persistent storage (used by application components)

> [!NOTE]
>
> 📖 **For detailed information about the application infrastructure**, including
> OpenLDAP configuration, ALB configuration, and deployment steps,
> see the [Application Infrastructure README](application_infra/README.md).

#### Step 4. Deploy Application

Deploy the 2FA application components (backend, frontend, PostgreSQL, Redis, SES,
SNS).

This deploys:

- PostgreSQL for user registration and verification token storage
- Redis for SMS OTP code storage
- AWS SES for email verification (configured for backend service account)
- AWS SNS for SMS 2FA (configured for backend service account)
- ArgoCD Applications for backend and frontend GitOps deployments
- Route53 record for the 2FA application

> [!IMPORTANT]
>
> **Deployment requires both build workflows:** The deployment of the backend and
> frontend applications **depends on running both** the **Backend Build and Push**
> (`backend_build_push.yaml`) and **Frontend Build and Push** (`frontend_build_push.yaml`)
> workflows. These workflows must be run immediately after completing Step 4
> (GitHub → Actions → select workflow → Run workflow, choose environment and region).
>
> **Why both are required:**
>
> - Without the backend image, ArgoCD cannot sync the backend application
> (image pull fails).
> - Without the frontend image, ArgoCD cannot sync the frontend application
> (image pull fails).
> - Both container images do not exist in ECR until you run the build workflows.
> - Without these images, ArgoCD cannot sync the 2FA applications and manual Helm
> deployment will fail.

> [!NOTE]
>
> 📖 **For detailed information about the application deployment**, including
> component configuration, dependencies, and deployment steps,
> see the [Application README](application/README.md).

### Method 2: Local Development

Deploy infrastructure locally using automated setup scripts that handle configuration,
secrets retrieval, and Terraform operations.

#### Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- AWS CLI configured with appropriate permissions
- Secrets stored in AWS Secrets Manager (see [Secrets Requirements](SECRETS_REQUIREMENTS.md))

#### Step 1. Deploy Terraform Backend State Infrastructure

For local deployment of `tf_backend_state`, use the provided automation scripts:

```bash
cd tf_backend_state
./set-state.sh  # For initial deployment
# or
./get-state.sh  # For subsequent operations
```

These scripts automatically handle:

- Role assumption for Account A
- Terraform operations
- State file management
- Repository variable updates

The scripts retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` from AWS Secrets Manager and
assume the role automatically.

> [!NOTE]
>
> 📖 See [Terraform Backend State README](tf_backend_state/README.md#option-2-local-execution)
> for detailed instructions.

#### Step 2. Deploy Backend Infrastructure

```bash
cd backend_infra
./setup-backend.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs from AWS Secrets Manager
- Generate `backend.hcl` from template (automatically ignored by git)
- Update `variables.tfvars` with selected region, environment, and deployment
account role ARN
- Run Terraform commands (init, workspace, validate, plan, apply) automatically
- **Automatically save ECR repository name to GitHub repository variable `ECR_REPOSITORY_NAME`**
(required by build workflows)

> [!NOTE]
>
> The generated `backend.hcl` file is automatically ignored by git.
> Only the placeholder template (`tfstate-backend-values-template.hcl`) is committed
> to the repository.

> [!IMPORTANT]
>
> For SMS 2FA functionality, ensure `enable_sns_endpoint = true` is set in
> `backend_infra/variables.tfvars` before deploying. See [Backend Infrastructure
> README](backend_infra/README.md#vpc-endpoints-module) for details.

#### Step 3. Deploy Application Infrastructure

```bash
cd application_infra
./setup-application-infra.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and OpenLDAP password secrets from AWS Secrets Manager
- Export OpenLDAP password secrets as environment variables
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, and deployment
account role ARN
- Mirror Docker images to ECR (OpenLDAP)
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

#### Step 4. Deploy Application

```bash
cd application
./setup-application.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and password secrets (PostgreSQL, Redis) from AWS Secrets Manager
- Export password secrets as environment variables
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, and deployment
account role ARN
- Set Kubernetes environment variables using `set-k8s-env.sh` (from application_infra)
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!IMPORTANT]
>
> **Deployment requires both build workflows:** The deployment of the backend and
> frontend applications **depends on running both** the **Backend Build and Push**
> (`backend_build_push.yaml`) and **Frontend Build and Push** (`frontend_build_push.yaml`)
> workflows. These workflows must be run immediately after running `setup-application.sh`
> (GitHub → Actions → select workflow → Run workflow, choose environment and region).
>
> **Why both are required:**
>
> - Without the backend image, ArgoCD cannot sync the backend application
> (image pull fails).
> - Without the frontend image, ArgoCD cannot sync the frontend application
> (image pull fails).
> - Both container images do not exist in ECR until you run the build workflows.
> - Without these images, ArgoCD cannot sync the 2FA applications and manual Helm
> deployment will fail.

#### Manual Terraform Commands (Alternative)

If you prefer to run Terraform commands manually instead of using the setup scripts:

**Step 1. Terraform Backend State Infrastructure:**

```bash
cd tf_backend_state
terraform init -backend-config="backend.hcl"
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

**Step 2. Backend Infrastructure:**

```bash
cd backend_infra
terraform init -backend-config="backend.hcl"
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

**Step 3. Application Infrastructure:**

```bash
cd application_infra
terraform init -backend-config="backend.hcl"
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

**Step 4. Application:**

```bash
cd application
terraform init -backend-config="backend.hcl"
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

> [!NOTE]
>
> Workspace names are dynamic based on region and environment
> (e.g., `us-east-1-prod`, `us-east-2-dev`).

## Destroying Infrastructure

This project provides automated destroy scripts for both backend and application
infrastructure, as well as GitHub Actions workflows for destroying infrastructure.

> [!WARNING]
>
> Destroying infrastructure is a **destructive operation** that permanently
> deletes all resources. This action **cannot be undone**. Always ensure you have
> backups and understand the consequences before proceeding.

### Destroy Scripts (Local Development)

#### Destroy Application

```bash
cd application
./destroy-application.sh
```

#### Destroy Application Infrastructure

```bash
cd application_infra
./destroy-application-infra.sh
```

The application destroy script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and ExternalId from AWS Secrets Manager
- Retrieve password secrets (PostgreSQL, Redis) from AWS Secrets Manager
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, deployment account
  role ARN, and ExternalId
- Set Kubernetes environment variables using `set-k8s-env.sh` (from application_infra)
- Run Terraform destroy commands (init, workspace, validate, plan destroy, apply
  destroy) automatically
- **Requires confirmation**: Type 'yes' to confirm, then 'DESTROY' to proceed

The application infrastructure destroy script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and ExternalId from AWS Secrets Manager
- Retrieve OpenLDAP password secrets from AWS Secrets Manager
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, deployment account
  role ARN, and ExternalId
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform destroy commands (init, workspace, validate, plan destroy, apply
  destroy) automatically
- **Requires confirmation**: Type 'yes' to confirm, then 'DESTROY' to proceed

#### Destroy Backend Infrastructure

```bash
cd backend_infra
./destroy-backend.sh
```

The script will:

- Prompt for AWS region (us-east-1 or us-east-2) and environment (prod or dev)
- Retrieve repository variables from GitHub
- Retrieve role ARNs and ExternalId from AWS Secrets Manager
- Generate `backend.hcl` from template (if it doesn't exist)
- Update `variables.tfvars` with selected region, environment, deployment account
  role ARN, and ExternalId
- Run Terraform destroy commands (init, workspace, validate, plan destroy, apply
  destroy) automatically
- **Requires confirmation**: Type 'yes' to confirm, then 'DESTROY' to proceed

> [!IMPORTANT]
>
> **Destroy Order**: Destroy infrastructure in reverse order of deployment:
>
> 1. **Application** (destroy first)
> 2. **Application Infrastructure** (destroy second)
> 3. **Backend Infrastructure** (destroy third)
> 4. **Terraform Backend State Infrastructure** (destroy last, if needed)

### Destroy Workflows (GitHub Actions)

#### Destroy Application

1. Go to GitHub → Actions tab
2. Select "Application Destroying" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

The workflow will:

- Use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
- Use environment-specific deployment account role ARN
- Use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
- Retrieve password secrets (PostgreSQL, Redis) from GitHub repository secrets
- Run Terraform destroy operations automatically

#### Destroy Application Infrastructure

1. Go to GitHub → Actions tab
2. Select "Application Infrastructure Destroying" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

The workflow will:

- Use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
- Use environment-specific deployment account role ARN
- Use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
- Retrieve OpenLDAP password secrets from GitHub repository secrets
- Run Terraform destroy operations automatically

#### Destroy Backend Infrastructure

1. Go to GitHub → Actions tab
2. Select "Backend Infrastructure Destroying" workflow
3. Click "Run workflow"
4. Select environment (prod or dev) and region
5. Click "Run workflow"

The workflow will:

- Use `AWS_STATE_ACCOUNT_ROLE_ARN` for backend state operations
- Use environment-specific deployment account role ARN
- Use `AWS_ASSUME_EXTERNAL_ID` for cross-account role assumption
- Run Terraform destroy operations automatically

> [!NOTE]
>
> For destroying Terraform backend state infrastructure, see the
> [Terraform Backend State README](tf_backend_state/README.md#destroying-remove-infrastructure).

## Architecture Overview

### Backend Infrastructure Components

The backend infrastructure provides the foundational AWS resources for deploying
containerized applications on Kubernetes. Key components include:

- **VPC** with public and private subnets across multiple availability zones
- **EKS Cluster** in Auto Mode with automatic node provisioning
- **IRSA (IAM Roles for Service Accounts)** for secure pod-to-AWS-service authentication
- **VPC Endpoints** for private AWS service access (SSM, STS, SNS)
- **ECR Repository** for container image storage

For detailed architecture diagrams, component descriptions, and configuration options,
see the [Backend Infrastructure README](backend_infra/README.md).

### Application Infrastructure Components

The application infrastructure deploys the LDAP stack and supporting infrastructure
on the EKS cluster. Key components include:

- **OpenLDAP Stack HA** with PhpLdapAdmin and LTB-passwd UIs
- **Application Load Balancer (ALB)** via EKS Auto Mode for internet-facing access
- **StorageClass** for persistent storage (used by application components)
- **ArgoCD Capability** (AWS managed service) for GitOps deployments
- **Security**: cert-manager for TLS, Network Policies for pod-to-pod security

For detailed architecture diagrams, component descriptions, and deployment instructions,
see the [Application Infrastructure README](application_infra/README.md).

### Application Components

The application deploys the 2FA application and supporting services. Key components
include:

- **2FA Application** with self-service registration and admin dashboard
- **PostgreSQL** for user registration and verification token storage
- **Redis** for SMS OTP code storage
- **AWS SES** for email verification (configured for backend service account)
- **AWS SNS** for SMS 2FA (configured for backend service account)
- **ArgoCD Applications** for backend and frontend GitOps deployments

For detailed architecture diagrams, component descriptions, API specifications,
and deployment instructions, see the [Application README](application/README.md).

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
- **Helm Release Safety**: Comprehensive Helm release attributes for safer
deployments with automatic rollbacks and resource readiness checks
- **ECR Image Support**: All modules use ECR images instead of Docker Hub to
prevent rate limiting and external dependencies
- **Public ACM Certificates**: Browser-trusted certificates with automatic renewal
via Amazon-issued public ACM certificates
- **Kubeconfig Auto-Update**: Automatic kubeconfig updates prevent stale cluster
endpoints and DNS lookup errors

## MFA Methods

The 2FA application supports two multi-factor authentication methods:

| Method | Description | Infrastructure Required |
| -------- | ------------- | ------------------------ |
| **TOTP** | Time-based One-Time Password using authenticator apps (Google Authenticator, Authy, etc.) | None (codes generated locally) |
| **SMS** | Verification codes sent via AWS SNS to user's phone | SNS VPC endpoint, IRSA role |

For detailed API specifications, frontend architecture, and implementation details,
see:

- [2FA Application PRD](application/PRD-2FA-APP.md) - Complete API and frontend
specifications
- [SMS OTP Management PRD](application/PRD-SMS-MAN.md) - Redis-based SMS OTP
storage implementation
- [SNS Module Documentation](application/modules/sns/README.md) - SMS 2FA
infrastructure setup

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
  Swagger UI for API exploration and testing (always enabled, not just in
  debug mode)
  - **ReDoc Documentation**: `https://app.${domain_name}/api/redoc` - Alternative
  API documentation interface (always enabled)
  - **OpenAPI Schema**: `https://app.${domain_name}/api/openapi.json` - OpenAPI
  schema in JSON format
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
- [Application Infrastructure README](application_infra/README.md) - OpenLDAP, ALB,
ArgoCD Capability
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
- [OpenLDAP Deployment PRD](application_infra/PRD-OPENLDAP.md) - OpenLDAP deployment
requirements and configuration
- [Security Improvements](application_infra/SECURITY-IMPROVEMENTS.md) - Security
enhancements and best practices

### Module Documentation

- [ALB Module](application_infra/modules/alb/README.md) - EKS Auto Mode ALB configuration
- [ArgoCD Module](application_infra/modules/argocd/README.md) - AWS managed ArgoCD
setup
- [ArgoCD Application Module](application/modules/argocd_app/README.md) -
GitOps application deployment
- [cert-manager Module](application_infra/modules/cert-manager/README.md) - TLS
certificate management
- [Network Policies](application_infra/modules/network-policies/README.md) -
  Pod-to-pod security
- [PostgreSQL Module](application/modules/postgresql/README.md) - User data and
verification token storage
- [Redis Module](application/modules/redis/README.md) - SMS OTP code storage
- [SES Module](application/modules/ses/README.md) - Email verification and
notifications
- [SNS Module](application/modules/sns/README.md) - SMS 2FA integration
- [Route53 Record Module](application_infra/modules/route53_record/README.md) -
  Route53 A (alias) records for ALB
- [VPC Endpoints Module](backend_infra/modules/endpoints/README.md) - Private
AWS service access
- [ECR Module](backend_infra/modules/ecr/README.md) - Container registry setup

### Changelogs

- [Project Changelog](CHANGELOG.md) - All project changes
- [Backend Infrastructure Changelog](backend_infra/CHANGELOG.md) - VPC, EKS,
VPC endpoints, and ECR changes
- [Application Infrastructure Changelog](application_infra/CHANGELOG.md) -
  OpenLDAP, ALB, ArgoCD Capability, and infrastructure changes
- [Application Changelog](application/CHANGELOG.md) - 2FA app, PostgreSQL,
  Redis, SES, SNS, and ArgoCD Applications changes
- [Terraform Backend State Changelog](tf_backend_state/CHANGELOG.md) - S3 state
management changes

## Security Considerations

- **Secrets Management**: See [Secrets Configuration](#secrets-configuration) for
details on managing passwords via AWS Secrets Manager (local) and GitHub repository
secrets (CI/CD)
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
- **Helm Release Safety**: Comprehensive Helm release attributes for safer deployments
with automatic rollbacks
- **ECR Image Support**: All modules use ECR images instead of Docker Hub to prevent
rate limiting
- **Kubeconfig Auto-Update**: Automatic kubeconfig updates prevent stale cluster
endpoints
- **Public ACM Certificates**: Browser-trusted certificates with automatic renewal

See [Security Improvements](application_infra/SECURITY-IMPROVEMENTS.md) for detailed
security documentation.

## Operations & Monitoring

### Deployment Monitoring Script

The project includes a monitoring script (`monitor-deployments.sh`) that provides
comprehensive health checks for all deployed components. This script is useful for
verifying deployment status, troubleshooting issues, and ensuring all services are
running correctly.

**Location:** `monitor-deployments.sh` (project root)

**What it does:**

1. **Interactive Setup:**
   - Prompts for AWS region (us-east-1 or us-east-2)
   - Prompts for environment (prod or dev)
   - Retrieves role ARNs from AWS Secrets Manager (`github-role` secret)
   - Retrieves ExternalId from AWS Secrets Manager for cross-account role assumption

2. **Cluster Access:**
   - Assumes the appropriate deployment account role (production or development)
   - Retrieves cluster name from backend_infra Terraform state (S3)
   - Updates kubeconfig to access the EKS cluster

3. **Health Checks:**
   - **ArgoCD Capability:** Verifies ArgoCD namespace and pod status
   - **OpenLDAP:** Checks Helm release status and pod health
   - **PostgreSQL:** Verifies Helm release and pod status
   - **Redis:** Checks Helm release and pod status
   - **Ingress Resources:** Lists all ingress resources across namespaces
   - **Application Load Balancers:** Displays ALB status and configuration

4. **Output:**
   - Color-coded status messages (green for success, yellow for warnings, red for
   errors)
   - Detailed pod status with counts (running, pending, failed)
   - Helm release status information
   - Summary report indicating overall deployment health

**Prerequisites:**

- `jq` command-line tool installed
- `kubectl` configured (script will update kubeconfig automatically)
- `helm` installed (for Helm release checks)
- AWS CLI configured with permissions to:
  - Access AWS Secrets Manager (to retrieve role ARNs and ExternalId)
  - Assume IAM roles in deployment accounts
  - Access S3 bucket containing Terraform state
  - Access EKS cluster
- GitHub CLI (`gh`) installed (optional, for retrieving `BACKEND_BUCKET_NAME` from
repository variables)

**Usage:**

```bash
./monitor-deployments.sh
```

The script will:

1. Prompt you to select region and environment
2. Automatically retrieve credentials and configure access
3. Perform health checks on all components
4. Display a summary with exit code 0 (all healthy) or 1 (issues found)

**Exit Codes:**

- `0`: All deployments are healthy
- `1`: Some deployments have issues (check output for details)

**Example Output:**

```text
=========================================
Monitoring Deployments for prod in us-east-1
=========================================

✓ Retrieved State Account role ARN
✓ Retrieved Deployment Account role ARN (production)
✓ Retrieved ExternalId for role assumption
✓ Successfully assumed Deployment Account role
✓ Cluster name: my-cluster-prod
✓ Kubeconfig updated successfully

=========================================
Checking ArgoCD Capability
=========================================
ArgoCD pods: 3/3 running
✓ ArgoCD is deployed and running

=========================================
Checking Helm Release: OpenLDAP
=========================================
Release: openldap-stack-ha
STATUS: deployed
✓ OpenLDAP is deployed

=========================================
Monitoring Summary
=========================================
✓ All deployments are healthy!
```

**Troubleshooting:**

- If the script fails to retrieve secrets, verify AWS credentials and Secrets Manager
permissions
- If cluster access fails, check that the backend_infra state file exists in S3
- If pods are not running, check pod logs: `kubectl logs -n <namespace> <pod-name>`
- If Helm releases show incorrect status, verify Helm is installed and has cluster
access

## Troubleshooting

See the individual README files for troubleshooting guides:

- [Backend Infrastructure Troubleshooting](backend_infra/README.md#troubleshooting)
- [Application Infrastructure Troubleshooting](application_infra/README.md#troubleshooting)

## License

See [LICENSE](LICENSE) file for details.
