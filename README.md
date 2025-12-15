# ldap-2fa-on-k8s

LDAP authentication with 2FA deployed on Kubernetes (EKS)

This project deploys a complete LDAP authentication solution with self-service
password management on Amazon EKS using Terraform. The infrastructure includes:

- **EKS Cluster** (Auto Mode) for running Kubernetes workloads
- **OpenLDAP Stack** with high availability and persistent storage
- **PhpLdapAdmin** web interface for LDAP administration
- **LTB-passwd** self-service password management UI
- **Application Load Balancer (ALB)** via EKS Auto Mode for internet-facing
access
- **Route53 DNS** integration for domain management
- **ACM Certificates** for HTTPS/TLS termination

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
├── backend_infra/         # Core AWS infrastructure (VPC, EKS cluster) - Account B
├── application/          # Application infrastructure (OpenLDAP, ALB, Route53) - Account B
└── .github/workflows/    # GitHub Actions workflows for CI/CD
```

## Multi-Account Architecture

This project uses a **multi-account architecture** for enhanced security:

- **Account A (State Account)**: Stores Terraform state files in S3
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

#### Required GitHub Secrets

Configure these secrets in your GitHub repository:
**Repository → Settings → Secrets and variables → Actions → Secrets**

1. **`AWS_STATE_ACCOUNT_ROLE_ARN`** (Required)
   - **Type**: Secret
   - **Description**: ARN of the IAM role in the State Account (Account A) that
   trusts GitHub OIDC
   - **Format**: `arn:aws:iam::STATE_ACCOUNT_ID:role/github-actions-state-role`
   - **Used for**: Terraform backend operations (S3 state file read/write)
   - **Permissions needed**: S3 access to state bucket
   - **Note**: This role is used for all backend state operations regardless of
   environment

2. **`AWS_PRODUCTION_ACCOUNT_ROLE_ARN`** (Required)
   - **Type**: Secret
   - **Description**: ARN of the IAM role in the Production Account (Account B)
   that trusts the State Account role
   - **Format**: `arn:aws:iam::PROD_ACCOUNT_ID:role/github-actions-prod-role`
   - **Used for**: Terraform provider operations (creating AWS resources) when
   `prod` environment is selected
   - **Permissions needed**: Full permissions to create/manage EKS, VPC, ALB,
   Route53, etc.
   - **Note**: This role is assumed by the Terraform AWS provider via
   `assume_role` configuration

3. **`AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`** (Required)
   - **Type**: Secret
   - **Description**: ARN of the IAM role in the Development Account (Account B)
   that trusts the State Account role
   - **Format**: `arn:aws:iam::DEV_ACCOUNT_ID:role/github-actions-dev-role`
   - **Used for**: Terraform provider operations (creating AWS resources) when
   `dev` environment is selected
   - **Permissions needed**: Full permissions to create/manage EKS, VPC, ALB,
   Route53, etc.
   - **Note**: This role is assumed by the Terraform AWS provider via
   `assume_role` configuration

4. **`TF_VAR_OPENLDAP_ADMIN_PASSWORD`** (Required for application deployment)
   - **Type**: Secret
   - **Description**: OpenLDAP admin password
   - **Used for**: OpenLDAP Helm chart deployment

5. **`TF_VAR_OPENLDAP_CONFIG_PASSWORD`** (Required for application deployment)
   - **Type**: Secret
   - **Description**: OpenLDAP config password
   - **Used for**: OpenLDAP Helm chart deployment

6. **`GH_TOKEN`** (Required for state backend provisioning)
   - **Type**: Secret
   - **Description**: GitHub Personal Access Token with `repo` scope
   - **Used for**: Creating/updating repository variables after state backend
   provisioning

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

> [!INFO]
> 📖 **For detailed setup instructions**, including required GitHub Secrets,
Variables, and configuration, see the [Terraform Backend State
README](tf_backend_state/README.md).
>
> [!IMPORTANT]
> Make sure to alter the values in the variables.tfvars according to your setup
and to commit and push them.

### 2. Deploy Backend Infrastructure

Deploy the main backend infrastructure (VPC, EKS cluster, VPC endpoints, EBS,
ECR).

> [!INFO]
> 📖 **For detailed information about the backend infrastructure**, including
architecture, components, and module documentation, see the [Backend
Infrastructure README](backend_infra/README.md).

### 3. Deploy Application Infrastructure

Deploy the application infrastructure (OpenLDAP stack, ALB, Route53 records).

> [!INFO]
> 📖 **For detailed information about the application infrastructure**, including
OpenLDAP configuration, ALB setup, and deployment steps, see the [Application
Infrastructure README](application/README.md).

## Local Development Setup

Before running Terraform locally, you need to generate the `backend.hcl` file
and update `variables.tfvars` with your selected region and environment. The
repository includes `tfstate-backend-values-template.hcl` as a template showing
what values need to be configured.

> **⚠️ IMPORTANT for Backend State Infrastructure**: For local deployment of
`tf_backend_state`, use the provided automation scripts (`set-state.sh` and
`get-state.sh`). These scripts automatically handle role assumption, Terraform
operations, state file management, and repository variable updates. The scripts
retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` from GitHub repository secrets and assume
the role automatically. See [Terraform Backend State
README](tf_backend_state/README.md#option-2-local-execution) for detailed
instructions.

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
- Retrieve the appropriate deployment account role ARN from GitHub secrets based
on the selected environment:
  - `prod` → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the
actual values
- Update `variables.tfvars` with the selected region, environment, and
deployment account role ARN
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!NOTE] The generated `backend.hcl` file is automatically ignored by git (see
`.gitignore`). Only the placeholder template
(`tfstate-backend-values-template.hcl`) is committed to the repository.

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
- Retrieve the appropriate deployment account role ARN from GitHub secrets based
on the selected environment:
  - `prod` → uses `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`
  - `dev` → uses `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
- Retrieve OpenLDAP password secrets (`TF_VAR_OPENLDAP_ADMIN_PASSWORD` and
`TF_VAR_OPENLDAP_CONFIG_PASSWORD`) from repository secrets and export them as
environment variables
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the
actual values (if it doesn't exist)
- Update `variables.tfvars` with the selected region, environment, and
deployment account role ARN
- Set Kubernetes environment variables using `set-k8s-env.sh`
- Run Terraform commands (init, workspace, validate, plan, apply) automatically

> [!NOTE] The generated `backend.hcl` file is automatically ignored by git (see
`.gitignore`). Only the placeholder template
(`tfstate-backend-values-template.hcl`) is committed to the repository.

**Important:** Before deploying the application infrastructure, you must:

1. **For local use**: Export OpenLDAP passwords as environment variables (the
script will retrieve them from these):

   ```bash
   export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
   export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
   ```

   > [!NOTE] The script automatically retrieves these from GitHub repository
   secrets if available. For local use, you need to export them as
   environment variables since GitHub CLI cannot read secret values directly.

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

# For local use: Export passwords as environment variables (script retrieves from GitHub secrets if available)
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"

# Run the setup script (handles all Terraform operations automatically)
./setup-application.sh
```

The script automatically handles:

- Backend configuration setup
- Retrieval of OpenLDAP password secrets from GitHub repository secrets
- Terraform initialization
- Workspace selection/creation
- Kubernetes environment variable configuration
- Terraform validation, planning, and application

## Architecture Overview

### Backend Infrastructure Components

- **VPC** with public and private subnets across multiple availability zones
- **EKS Cluster** in Auto Mode with automatic node provisioning
- **VPC Endpoints** for secure SSM access to nodes
- **EBS Storage** resources for persistent volumes
- **ECR Repository** for container image storage

### Application Infrastructure Components

- **OpenLDAP Stack HA** deployed via Helm chart with:
  - OpenLDAP StatefulSet (3 replicas for high availability)
  - PhpLdapAdmin web interface
  - LTB-passwd self-service password management
- **Application Load Balancer (ALB)** via EKS Auto Mode:
  - Internet-facing ALB with HTTPS/TLS termination
  - Single ALB handles multiple Ingresses via host-based routing
  - Automatic provisioning via IngressClass and IngressClassParams
- **Route53 DNS** records for subdomains pointing to ALB
- **Persistent Storage** using EBS-backed StorageClass

## Key Features

- **EKS Auto Mode**: Simplified cluster management with automatic load balancer
provisioning
- **High Availability**: Multi-master OpenLDAP replication with persistent
storage
- **Internet-Facing Access**: Secure HTTPS access to UIs via ALB
- **Self-Service Password Management**: LTB-passwd for user password resets
- **Automated DNS**: Route53 integration for seamless domain management
- **Secure by Default**: TLS termination, encrypted storage, network policies

## Accessing the Services

After deployment:

- **PhpLdapAdmin**: `https://phpldapadmin.${domain_name}` (e.g.,
`https://phpldapadmin.talorlik.com`)
- **LTB-passwd**: `https://passwd.${domain_name}` (e.g.,
`https://passwd.talorlik.com`)
- **LDAP Service**: Cluster-internal only (not exposed externally)

## Documentation

- [Terraform Backend State README](tf_backend_state/README.md) - Backend state infrastructure setup
- [Backend Infrastructure README](backend_infra/README.md) - Core AWS infrastructure details
- [Application Infrastructure README](application/README.md) - OpenLDAP deployment and configuration

## Security Considerations

- Passwords are managed via environment variables (never committed to git)
- TLS termination at ALB using ACM certificates
- LDAP service is ClusterIP only (not exposed externally)
- EBS volumes are encrypted by default
- Network policies restrict pod-to-pod communication to secure ports, with
cross-namespace access enabled for LDAP service access
- EKS nodes run in private subnets

## Troubleshooting

See the individual README files for troubleshooting guides:

- [Backend Infrastructure Troubleshooting](backend_infra/README.md#troubleshooting)
- [Application Infrastructure Troubleshooting](application/README.md#troubleshooting)

## License

See [LICENSE](LICENSE) file for details.
