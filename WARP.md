# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this
repository.

## Project Overview

This repository deploys LDAP authentication with 2FA on Kubernetes (EKS Auto
Mode) using Terraform. The infrastructure is deployed on AWS using a
**multi-account architecture** and consists of three main layers:

1. **Terraform Backend State** (`tf_backend_state/`) - S3 bucket for storing
Terraform state files (Account A - State Account)
2. **Backend Infrastructure** (`backend_infra/`) - Core AWS infrastructure (VPC,
EKS cluster with IRSA, VPC endpoints, ECR) (Account B - Deployment Account)
3. **Application Infrastructure** (`application_infra/`) - Infrastructure components
(OpenLDAP, ALB, ArgoCD Capability, StorageClass, Route53 records for phpldapadmin/ltb-passwd)
(Account B - Deployment Account)
4. **Application** (`application/`) - 2FA application code (backend + frontend)
and application dependencies (PostgreSQL, Redis, SES, SNS, ArgoCD Applications)
(Account B - Deployment Account)

**Multi-Account Architecture:**

- **Account A (State Account)**: Stores Terraform state files in S3, Route53
hosted zones, and ACM certificates
- **Account B (Deployment Accounts)**: Contains all infrastructure resources
  - **Production Account**: Separate account for production infrastructure
  - **Development Account**: Separate account for development infrastructure
- GitHub Actions uses OIDC to assume Account A role for backend state operations
- Terraform provider assumes Account B role (prod or dev) via `assume_role` for
resource deployment with ExternalId for enhanced security
- **State Account provider** (`aws.state_account`) assumes Account A role for
Route53 and ACM operations (no ExternalId required)
- Environment-based role selection: workflows and scripts automatically select
the appropriate deployment role ARN based on the selected environment (`prod` or
`dev`)
- **ExternalId Security**: Cross-account role assumption uses ExternalId to
prevent confused deputy attacks (for deployment account roles only)

## Architecture

### Four-Phased Deployment Model

- **Phase 1**: Deploy Terraform backend state infrastructure first (prerequisite
for all other deployments)
- **Phase 2**: Deploy backend infrastructure (VPC, EKS, networking, ECR, VPC
endpoints) using the remote state backend
- **Phase 3**: Deploy application infrastructure (OpenLDAP, ALB, ArgoCD Capability,
StorageClass, Route53 DNS records for phpldapadmin/ltb-passwd) on top of the
EKS cluster
- **Phase 4**: Deploy application (2FA app code, PostgreSQL, Redis, SES, SNS,
ArgoCD Applications, Route53 DNS record for twofa_app) using infrastructure from
Phase 3

### Infrastructure Components

- **VPC**: Custom VPC with public/private subnets across 2 availability zones
- **EKS Auto Mode**: Simplified cluster management with automatic node
provisioning and built-in EBS CSI driver (Kubernetes 1.34)
- **IRSA (IAM Roles for Service Accounts)**: Enabled via OIDC provider for
secure pod-to-AWS-service authentication
- **Networking**: Single NAT gateway (cost optimization), IGW, VPC endpoints for
SSM, STS (IRSA), and SNS (SMS 2FA) access
- **Storage**: StorageClass created in application layer (gp3, encrypted), PVCs
created by Helm chart
- **Container Registry**: ECR repository for Docker images with lifecycle
policies (immutable tags). All third-party images (Redis, PostgreSQL, OpenLDAP)
are automatically mirrored from Docker Hub to ECR during deployment
- **DNS & Certificates**: Uses existing Route53 hosted zone and validated ACM
certificate (via data sources). Supports cross-account access when Route53/ACM
are in State Account
- **Load Balancer**: AWS ALB automatically created via Ingress resources for
exposing web UIs (phpLdapAdmin, LTB-passwd, and 2FA application)
- **IngressClass/IngressClassParams**: Created by ALB module to configure EKS
Auto Mode ALB behavior (scheme, IP address type, certificate ARN, group name)
- **Network Policies**: Kubernetes NetworkPolicies for secure internal cluster
communication with cross-namespace access for LDAP service
- **Container Image Management**: All third-party images (OpenLDAP, Redis,
PostgreSQL) are mirrored to ECR to eliminate Docker Hub rate limits and external
dependencies. Images are pulled from ECR during deployment
  - OpenLDAP: osixia/openldap:1.5.0 → ECR tag `openldap-1.5.0`
  - Redis: bitnami/redis:8.4.0-debian-12-r6 → ECR tag `redis-latest`
  - PostgreSQL: bitnami/postgresql:18.1.0-debian-12-r4 → ECR tag `postgresql-latest`
- **2FA Application**: Full-stack application with Python FastAPI backend and
static HTML/JS/CSS frontend, supporting TOTP and SMS MFA methods
- **User Signup Management**: Self-service registration with email/phone
verification and admin approval workflow
- **PostgreSQL Database**: User registration data, verification tokens, and
profile management
- **Redis Cache**: SMS OTP code storage with automatic TTL expiration
- **ArgoCD**: AWS EKS managed ArgoCD service for GitOps deployments (optional)
- **SNS Integration**: AWS SNS for SMS-based 2FA verification codes (optional)
- **SES Integration**: AWS SES for email verification and notifications

### Naming Convention

All resources follow the pattern: `${prefix}-${region}-${name}-${env}`

### Workspace Strategy

Terraform workspaces are named: `${region}-${env}` (e.g., `us-east-1-prod`,
`us-east-2-dev`)

## Project Directory Structure

```bash
ldap-2fa-on-k8s/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── workflows/
│       ├── application_infra_destroying.yaml
│       ├── application_infra_provisioning.yaml
│       ├── backend_build_push.yaml
│       ├── backend_infra_destroying.yaml
│       ├── backend_infra_provisioning.yaml
│       ├── frontend_build_push.yaml
│       ├── tfstate_infra_destroying.yaml
│       └── tfstate_infra_provisioning.yaml
├── application_infra/          # Application infrastructure - Account B
│   ├── helm/                   # Helm values templates (OpenLDAP)
│   │   └── openldap-values.tpl.yaml
│   ├── modules/                # Infrastructure Terraform modules
│   │   ├── alb/                # IngressClass and IngressClassParams
│   │   ├── argocd/             # ArgoCD Capability (AWS managed)
│   │   ├── cert-manager/       # TLS certificate management
│   │   ├── network-policies/   # Kubernetes NetworkPolicies
│   │   ├── openldap/           # OpenLDAP Stack HA deployment module
│   │   ├── route53/            # Route53 hosted zone
│   │   └── route53_record/     # Route53 A (alias) record creation
│   ├── destroy-application-infra.sh
│   ├── mirror-images-to-ecr.sh # ECR image mirroring script
│   ├── set-k8s-env.sh
│   ├── setup-application-infra.sh
│   └── [other infrastructure files...]
├── application/                # 2FA Application code and dependencies - Account B
│   ├── backend/                # 2FA Backend (Python FastAPI)
│   │   ├── src/                # Source code
│   │   ├── helm/               # Helm chart
│   │   ├── Dockerfile
│   │   └── README.md           # Backend API documentation
│   ├── frontend/               # 2FA Frontend (HTML/JS/CSS)
│   │   ├── src/                # Source code
│   │   ├── helm/               # Helm chart
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── README.md           # Frontend documentation
│   ├── helm/                   # Application Helm values templates (Redis, PostgreSQL)
│   ├── modules/                # Application Terraform modules
│   │   ├── argocd_app/         # ArgoCD Application CRD
│   │   ├── postgresql/         # PostgreSQL database (Bitnami Helm)
│   │   ├── redis/              # Redis cache for SMS OTP
│   │   ├── ses/                # SES for email verification
│   │   └── sns/                # SNS for SMS 2FA
│   ├── destroy-application.sh
│   ├── setup-application.sh
│   └── [other application files...]
├── backend_infra/              # Core AWS infrastructure - Account B
│   ├── modules/
│   │   ├── ebs/                # EBS storage
│   │   ├── ecr/                # Container registry
│   │   └── endpoints/          # VPC endpoints (SSM, STS, SNS)
│   ├── destroy-backend.sh
│   ├── setup-backend.sh
│   └── [other backend_infra files...]
├── docs/                       # GitHub Pages documentation
│   ├── index.html              # Project documentation website
│   ├── dark-theme.css
│   ├── light-theme.css
│   └── [other docs files...]
├── tf_backend_state/           # Terraform state backend (S3) - Account A
│   ├── get-state.sh
│   ├── set-state.sh
│   └── [other tf_backend_state files...]
├── CHANGELOG.md
├── LICENSE
├── monitor-deployments.sh      # Deployment monitoring script
├── README.md
├── SECRETS_REQUIREMENTS.md     # Secrets management documentation
└── [other root files...]
```

## Common Commands

### Terraform Backend State Setup

**Initial Backend Provisioning (GitHub Actions - Recommended):**

```bash
# Run via GitHub UI: Actions → "TF Backend State Provisioning" workflow
# This automatically creates S3 bucket and saves state
```

**Local Backend Setup (Automated):**

```bash
cd tf_backend_state

# Provision infrastructure and upload state (all-in-one script)
./set-state.sh

# Or download existing state file from S3
./get-state.sh
```

The scripts automatically:

- Retrieve `AWS_STATE_ACCOUNT_ROLE_ARN` from AWS Secrets Manager (secret: 'github-role')
- Retrieve `AWS_ASSUME_EXTERNAL_ID` from AWS Secrets Manager (secret: 'external-id')
- Assume the IAM role with temporary credentials and ExternalId
- Handle Terraform provisioning (if infrastructure doesn't exist)
- Upload/download state files to/from S3
- Update GitHub repository variables

**Manual Local Setup (if not using automated scripts):**

```bash
cd tf_backend_state

# IMPORTANT: Assume the IAM role first (required for local deployment)
# The bucket policy grants access to the role ARN, not your user ARN
aws sts assume-role \
  --role-arn "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role" \
  --role-session-name "local-deployment"

# Export the temporary credentials from the assume-role output
export AWS_ACCESS_KEY_ID=<temporary-access-key>
export AWS_SECRET_ACCESS_KEY=<temporary-secret-key>
export AWS_SESSION_TOKEN=<session-token>

# If previously run via GitHub Actions, download state first:
aws s3 cp s3://<bucket_name>/<prefix> ./terraform.tfstate

terraform init
terraform plan -var-file="variables.tfvars" -out terraform.tfplan
terraform apply -auto-approve terraform.tfplan
```

### Backend Infrastructure Setup

**Configure Backend and Deploy (Automated):**

```bash
cd backend_infra

# Option 1: Using GitHub CLI (requires gh and jq)
# This script will:
# - Prompt for region and environment selection
# - Retrieve AWS_STATE_ACCOUNT_ROLE_ARN and assume it for backend operations
# - Retrieve ExternalId for secure cross-account role assumption
# - Retrieve environment-specific deployment role ARN (prod or dev)
# - Create backend.hcl from template if it doesn't exist
# - Update variables.tfvars with selected values
# - Run all Terraform commands automatically (init, workspace, validate, plan, apply)
./setup-backend.sh
```

**Manual Deployment (if not using automated script):**

```bash
cd backend_infra

# Initialize with backend configuration
terraform init -backend-config="backend.hcl"

# Select or create workspace (format: region-environment)
terraform workspace select us-east-1-prod || terraform workspace new us-east-1-prod

# Plan and apply
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

**Destroy Backend Infrastructure:**

```bash
cd backend_infra

# Option 1: Automated destroy script (recommended)
# This script will:
# - Prompt for region and environment selection
# - Retrieve role ARNs and ExternalId from AWS Secrets Manager
# - Configure backend and variables automatically
# - Require safety confirmations (type 'yes' then 'DESTROY')
# - Run Terraform destroy commands
./destroy-backend.sh

# Option 2: Manual destroy
terraform plan -var-file="variables.tfvars" -destroy -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

### Application Infrastructure Deployment

**Prerequisites:**
Ensure you have:

- A registered domain name (e.g., `talorlik.com`)
- An existing Route53 hosted zone for your domain
- **Public ACM certificates** requested in each deployment account and validated
via DNS records in State Account's Route53 hosted zone
  - See [Public ACM Certificate Setup and DNS Validation](application_infra/CROSS-ACCOUNT-ACCESS.md#public-acm-certificate-setup-and-dns-validation)
  for detailed setup instructions
  - Certificates are browser-trusted (no security warnings) and automatically
  renewed by ACM
- **For local scripts**: AWS Secrets Manager secrets configured:
  - `github-role`: Contains `AWS_STATE_ACCOUNT_ROLE_ARN` and deployment account
  role ARNs
  - `external-id`: Contains `AWS_ASSUME_EXTERNAL_ID`
  - `tf-vars`: Contains OpenLDAP password
  - See `SECRETS_REQUIREMENTS.md` for detailed setup instructions

**Deploy Application Infrastructure (OpenLDAP, ALB, ArgoCD Capability):**

```bash
cd application_infra

# For local use: Export passwords as environment variables (script retrieves from GitHub secrets if available)
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"

# Deploy infrastructure (handles all configuration and Terraform operations automatically)
./setup-application-infra.sh
```

This script will:

- Prompt for region and environment selection
- Retrieve AWS_STATE_ACCOUNT_ROLE_ARN and assume it for backend operations
- Retrieve ExternalId for secure cross-account role assumption
- Retrieve environment-specific deployment role ARN (prod or dev)
- Retrieve OpenLDAP password secrets from repository secrets and export them as
environment variables
- Create backend.hcl from template if it doesn't exist
- Update variables.tfvars with selected values
- **Mirror third-party Docker image to ECR** (OpenLDAP)
  - Checks if image already exists in ECR
  - Only mirrors if missing from Docker Hub
  - Uses Deployment Account credentials for ECR operations
- Set Kubernetes environment variables using set-k8s-env.sh
- Run all Terraform commands automatically (init, workspace, validate, plan,
apply)

> [!NOTE]
>
> The script automatically retrieves OpenLDAP passwords from AWS Secrets Manager
> (for local use). For GitHub Actions workflows, passwords are retrieved from
> GitHub repository secrets.

**Destroy Application Infrastructure:**

```bash
cd application_infra

# Automated destroy script with comprehensive safety checks
# This script will:
# - Prompt for region and environment selection
# - Retrieve role ARNs, ExternalId, and passwords from AWS Secrets Manager
# - Configure backend, variables, and Kubernetes environment automatically
# - Require safety confirmations (type 'yes' then 'DESTROY')
# - Run Terraform destroy commands
./destroy-application-infra.sh
```

### Application Deployment (2FA App)

**Prerequisites:**

- Application infrastructure must be deployed first (see above)
- Backend infrastructure must be deployed
- **For local scripts**: AWS Secrets Manager secrets configured with PostgreSQL
and Redis passwords

**Deploy 2FA Application:**

```bash
cd application

# For local use: Export passwords as environment variables
export TF_VAR_POSTGRESQL_PASSWORD="YourSecurePassword123!"
export TF_VAR_REDIS_PASSWORD="YourSecurePassword123!"

# Deploy application (handles all configuration and Terraform operations automatically)
./setup-application.sh
```

This script will:

- Prompt for region and environment selection
- Retrieve AWS_STATE_ACCOUNT_ROLE_ARN and assume it for backend operations
- Retrieve ExternalId for secure cross-account role assumption
- Retrieve environment-specific deployment role ARN (prod or dev)
- Retrieve password secrets from repository secrets and export them as environment
variables
- Create backend.hcl from template if it doesn't exist
- Update variables.tfvars with selected values
- Reference application_infra remote state for dependencies (StorageClass, ArgoCD,
ALB DNS)
- Run all Terraform commands automatically (init, workspace, validate, plan, apply)

**Destroy Application:**

```bash
cd application

# Automated destroy script with comprehensive safety checks
./destroy-application.sh
```

### Kubernetes Operations

**Configure kubectl:**

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

**Check cluster resources:**

```bash
kubectl get nodes
kubectl get pods -n ldap
kubectl get pvc -n ldap
kubectl get ingress -n ldap
```

**Access EKS nodes via SSM (no SSH required):**

```bash
aws ssm start-session --target <instance-id>
```

### ECR Operations

**Mirror Third-Party Images to ECR:**

The `mirror-images-to-ecr.sh` script automatically mirrors third-party images
from Docker Hub to ECR. This eliminates Docker Hub rate limits and external
dependencies.

```bash
cd application

# Run manually (if needed)
./mirror-images-to-ecr.sh
```

The script:

- Fetches ECR repository URL from backend_infra Terraform state
- Assumes Deployment Account role for ECR operations
- Checks which images already exist in ECR
- Pulls missing images from Docker Hub
- Tags and pushes them to ECR with consistent naming:
  - `redis-latest` tag for Redis (bitnami/redis:latest)
  - `postgresql-latest` tag for PostgreSQL (bitnami/postgresql:latest)
  - `openldap-1.5.0` for OpenLDAP (osixia/openldap:1.5.0)

**Push Custom Docker Image to ECR:**

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr_url>

# Tag and push image
docker tag <image>:<tag> <ecr_url>:<tag>
docker push <ecr_url>:<tag>
```

**Note**: The `setup-application.sh` script automatically runs the image
mirroring script, so manual execution is typically not needed.

## Key Configuration Files

### Backend State

- `tf_backend_state/variables.tfvars` - Configure `env`, `region`, `prefix`
(principal_arn automatically detected via `data.aws_caller_identity`)
- `tf_backend_state/README.md` - Detailed setup instructions for GitHub
secrets/variables and AWS Secrets Manager configuration
- `tf_backend_state/set-state.sh` - Enhanced automated provisioning and state upload
script with intelligent infrastructure detection
- `tf_backend_state/get-state.sh` - Automated state download script
- `tf_backend_state/CHANGELOG.md` - Detailed changelog for backend state infrastructure

### Backend Infrastructure Layer

- `backend_infra/variables.tfvars` - Configure VPC CIDR, K8s version (1.34),
resource names, ECR lifecycle policies, VPC endpoints (enable_sts_endpoint,
enable_sns_endpoint)
- `backend_infra/backend.hcl` - Generated file (do not commit) with S3 backend
config
- `backend_infra/tfstate-backend-values-template.hcl` - Template for backend.hcl
- `backend_infra/modules/` - Reusable modules:
  - `ecr/` - Container registry with lifecycle policies
  - `endpoints/` - VPC endpoints for SSM, STS (IRSA), and SNS (SMS 2FA)
  - `ebs/` - EBS storage (commented out in main.tf)
- `backend_infra/main.tf` - Creates VPC, EKS cluster with Auto Mode and IRSA,
VPC endpoints, ECR
- `backend_infra/setup-backend.sh` - Automated setup script with role assumption
and Terraform execution
- `backend_infra/destroy-backend.sh` - Automated destroy script with safety
confirmations

### Application Infrastructure Layer

- `application_infra/variables.tfvars` - Configure:
  - Domain name, ALB settings, storage class
  - ArgoCD Capability configuration (enable_argocd, Identity Center settings)
  - OpenLDAP passwords retrieved automatically by setup-application-infra.sh from
  AWS Secrets Manager
- `application_infra/setup-application-infra.sh` - Setup script for infrastructure
deployment (retrieves secrets from AWS Secrets Manager, mirrors OpenLDAP image
to ECR)
- `application_infra/destroy-application-infra.sh` - Automated destroy script with
safety
confirmations and Kubernetes environment setup
- `application_infra/set-k8s-env.sh` - Kubernetes environment variable configuration
- `application_infra/mirror-images-to-ecr.sh` - ECR image mirroring script for OpenLDAP
(called by setup-application-infra.sh)
- `application_infra/helm/openldap-values.tpl.yaml` - Helm chart values template
configured to pull OpenLDAP image from ECR (openldap-1.5.0)
- `application_infra/providers.tf` - Retrieves cluster name from backend_infra remote
state (with fallback options)
- `application_infra/main.tf` - Creates:
  - StorageClass for persistent storage
  - OpenLDAP module invocation (Helm release, secrets, Ingress)
  - Route53 records for phpldapadmin and ltb_passwd
  - ALB module (IngressClass and IngressClassParams)
  - Network policies
  - ArgoCD Capability (if enabled)
- `application_infra/modules/` - Infrastructure Terraform modules:
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `argocd/` - AWS EKS managed ArgoCD Capability
  - `cert-manager/` - TLS certificate management (optional)
  - `network-policies/` - Kubernetes NetworkPolicies with cross-namespace access
  - `openldap/` - OpenLDAP Stack HA deployment with secrets, Ingress, and Route53
  - `route53/` - Route53 hosted zone creation (commented out, uses data sources)
  - `route53_record/` - Route53 A (alias) record creation
- `application_infra/CHANGELOG.md` - Infrastructure-specific changelog
- `application_infra/PRD-ALB.md` - Comprehensive ALB implementation guide
- `application_infra/PRD-DOMAIN.md` - Domain and DNS configuration
- `application_infra/PRD-OPENLDAP.md` - OpenLDAP deployment requirements
- `application_infra/PRD-ArgoCD.md` - ArgoCD Capability documentation
- `application_infra/OPENLDAP-README.md` - OpenLDAP configuration and TLS setup
- `application_infra/OSIXIA-OPENLDAP-REQUIREMENTS.md` - OpenLDAP image requirements
- `application_infra/SECURITY-IMPROVEMENTS.md` - Security enhancements and best
practices
- `application_infra/CROSS-ACCOUNT-ACCESS.md` - Cross-account access documentation

### Application Layer

- `application/variables.tfvars` - Configure:
  - SNS/SMS 2FA configuration (enable_sms_2fa)
  - PostgreSQL and Redis configuration
  - ArgoCD Applications configuration (if enabled)
  - Passwords retrieved automatically by setup-application.sh from AWS Secrets Manager
- `application/setup-application.sh` - Setup script for application deployment
(retrieves secrets from AWS Secrets Manager)
- `application/destroy-application.sh` - Automated destroy script with safety confirmations
- `application/helm/postgresql-values.tpl.yaml` - PostgreSQL Helm chart values template
(image configuration in module, pulls from ECR)
- `application/helm/redis-values.tpl.yaml` - Redis Helm chart values template
(image configuration in module, pulls from ECR)
- `application/providers.tf` - References application_infra remote state for dependencies
- `application/main.tf` - Creates:
  - 2FA backend Helm release (if ArgoCD not used)
  - 2FA frontend Helm release (if ArgoCD not used)
  - Route53 record for 2FA app subdomain
  - PostgreSQL module (with Kubernetes secrets)
  - Redis module (with Kubernetes secrets)
  - SES module
  - SNS module (if SMS 2FA enabled)
  - ArgoCD Applications (if enabled)
- `application/modules/` - Application Terraform modules:
  - `argocd_app/` - ArgoCD Application CRD for GitOps
  - `postgresql/` - PostgreSQL database with Kubernetes secrets
  - `redis/` - Redis cache with Kubernetes secrets for SMS OTP storage
  - `ses/` - AWS SES for email verification and notifications
  - `sns/` - SNS resources for SMS 2FA with IRSA
- `application/backend/` - 2FA backend application:
  - `src/` - Python FastAPI source code
  - `helm/` - Helm chart with Ingress for `/api/*`
  - `Dockerfile` - Container image definition
  - `README.md` - Comprehensive backend API documentation
- `application/frontend/` - 2FA frontend application:
  - `src/` - Static HTML/JS/CSS files
  - `helm/` - Helm chart with Ingress for `/`
  - `Dockerfile` - Container image definition (nginx, runs as non-root user)
  - `nginx.conf` - nginx configuration (listens on port 8080)
  - `README.md` - Comprehensive frontend application documentation
- `application/CHANGELOG.md` - Application-specific changelog
- `application/PRD-2FA-APP.md` - Product requirements document for 2FA application
- `application/PRD-SIGNUP-MAN.md` - Product requirements document for signup management
system
- `application/PRD-ADMIN-FUNCS.md` - Product requirements for admin functions
- `application/PRD-SMS-MAN.md` - Product requirements for SMS management
- `SECRETS_REQUIREMENTS.md` - Comprehensive secrets management documentation
  - AWS Secrets Manager setup for local scripts (role ARNs, ExternalId, passwords)
  - GitHub Repository Secrets setup for workflows
  - ExternalId configuration for cross-account role assumption security
  - Secret naming conventions and case sensitivity

## Outputs

### Backend Infrastructure Outputs

- **VPC**: `vpc_id`, `public_subnets`, `private_subnets`,
`default_security_group_id`, `igw_id`
- **EKS**: `cluster_name`, `cluster_endpoint`, `cluster_arn`, `oidc_provider_arn`
(for IRSA)
- **VPC Endpoints**: `vpc_endpoint_sg_id`, `vpc_endpoint_ssm_id`,
`vpc_endpoint_ssmmessages_id`, `vpc_endpoint_ec2messages_id`,
`vpc_endpoint_sts_id` (if enabled), `vpc_endpoint_sns_id` (if enabled),
`vpc_endpoint_ids`
- **ECR**: `ecr_name`, `ecr_arn`, `ecr_url`
- **General**: `aws_account`, `region`, `env`, `prefix`

### Application Infrastructure Outputs

- **ALB**: `alb_dns_name`, `alb_ingress_class_name`,
`alb_ingress_class_params_name`, `alb_scheme`, `alb_ip_address_type`
- **OpenLDAP**: `openldap_namespace`, `openldap_secret_name`,
`openldap_helm_release_name`, `openldap_alb_dns_name`,
`phpldapadmin_route53_record`, `ltb_passwd_route53_record`
- **Route53**: `route53_acm_cert_arn`, `route53_domain_name`, `route53_zone_id`,
`route53_name_servers`
- **Network Policies**: `network_policy_name`, `network_policy_namespace`,
`network_policy_uid`
- **ArgoCD** (if enabled): `argocd_capability_arn`, `argocd_capability_id`,
`argocd_server_url`
- **SNS** (if enabled): `sns_topic_arn`, `sns_topic_name`, `sns_iam_role_arn`,
`sns_iam_role_name`
- **SES** (if enabled): `ses_iam_role_arn`, `ses_iam_role_name`,
`ses_email_identity_arn`
- **PostgreSQL** (if enabled): `postgresql_service_name`, `postgresql_port`
- **Redis** (if enabled): `redis_service_name`, `redis_port`

## Important Patterns

### Terraform State Management

- **Never commit** `backend.hcl` or `terraform.tfstate` files (in `.gitignore`)
- Always use remote state backend after initial provisioning
- Use workspace naming convention: `${region}-${env}`
- State is stored in S3 with file-based locking (no DynamoDB required)
- **Local scripts** retrieve role ARNs from AWS Secrets Manager (secret: `github-role`)
- **GitHub Actions** retrieve role ARNs from GitHub repository secrets

### Security Considerations

- All EKS nodes are in private subnets (no public IPs)
- VPC endpoints enable SSM access without internet gateway
- EBS volumes are encrypted by default
- Secrets should use `sensitive = true` in Terraform variables
- OpenLDAP admin/config passwords should never be committed in plaintext
- **ExternalId for Cross-Account Role Assumption**:
  - Prevents confused deputy attacks in multi-account deployments
  - ExternalId retrieved from AWS Secrets Manager (`external-id`) for local scripts
  - ExternalId retrieved from GitHub repository secret (`AWS_ASSUME_EXTERNAL_ID`)
  for workflows
  - Must be configured in deployment account role Trust Relationships
  - Generated using: `openssl rand -hex 32`

### EKS Auto Mode and IRSA

- **EKS Auto Mode**:
  - Built-in EBS CSI driver - no manual installation needed
  - Automatic IAM permissions for CSI driver
  - Compute config uses "general-purpose" node pool
  - ALB creation driven by Kubernetes Ingress with annotations (no separate AWS
  ALB resource)
- **IRSA (IAM Roles for Service Accounts)**:
  - Enabled via `enable_irsa = true` in backend_infra
  - Creates OIDC provider for the EKS cluster
  - Allows pods to assume IAM roles for AWS service access
  - Required for SMS 2FA (SNS access)
  - No hardcoded AWS credentials needed in pods

### Application Deployments

**OpenLDAP Stack (via OpenLDAP Module):**

- Deployed via `application/modules/openldap/` Terraform module
- OpenLDAP chart version: 4.0.1 from `https://jp-gouin.github.io/helm-openldap`
- Uses osixia/openldap:1.5.0 Docker image mirrored to ECR (chart's default
bitnami image doesn't exist)
- Image pulled from ECR with tag `openldap-1.5.0` instead of Docker Hub
- **Multi-master replication**: 3 replicas for high availability
- **Kubernetes secrets**: Admin and config passwords stored in Kubernetes secrets,
not plain-text in Helm values
- **Web UIs**: phpLDAPadmin and ltb-passwd exposed via ALB with separate Ingress
resources
- **LDAP service**: ClusterIP (internal only) for secure cluster-internal access
- **Route53 DNS**: Module creates A (alias) records pointing to ALB
- Hostnames configurable via variables:
  - `phpldapadmin_host` (default: `phpldapadmin.talorlik.com`)
  - `ltb_passwd_host` (default: `passwd.talorlik.com`)
  - `twofa_app_host` (default: `app.talorlik.com`)
- **TLS**: Auto-generated self-signed certificates from osixia/openldap image

**2FA Application (Helm Charts or ArgoCD):**

- Backend: Python FastAPI with comprehensive authentication features
  - LDAP authentication and MFA support (TOTP and SMS)
  - Self-service user signup with email/phone verification
  - Admin dashboard for user and group management
  - User profile management
  - PostgreSQL for user registration and profile data (with Kubernetes secrets,
  image pulled from ECR)
  - Redis for SMS OTP code caching (with Kubernetes secrets, image pulled from
  ECR)
  - AWS SES for email verification and notifications (via IRSA)
  - AWS SNS for SMS verification codes (via IRSA)
  - Exposed at `/api/*` path on `app.<domain>`
  - Uses IRSA for SNS, SES access (no hardcoded credentials)
  - Swagger UI always enabled at `/api/docs` for interactive API documentation
  - Optimized Python code for better performance and logging efficiency
  - Helm chart includes: Deployment, Service, Ingress, ConfigMap, Secret,
  ServiceAccount
- Frontend: Static HTML/JS/CSS served by nginx
  - Signup form with email/phone verification
  - Admin dashboard (visible to admin group members)
  - User profile page
  - Top navigation bar with user menu
  - Exposed at `/` path on `app.<domain>`
  - Runs as non-root user (`appuser`, UID 1000) on port 8080
  - Service exposes port 80 externally (forwards to container port 8080)
  - Helm chart includes: Deployment, Service, Ingress
- Deployment method:
  - Direct Helm deployment via Terraform (default)
  - Or via ArgoCD GitOps (if `enable_argocd = true`)

**ALB Configuration:**

- Uses EKS Auto Mode (`eks.amazonaws.com/alb` controller) instead of AWS Load
Balancer Controller
- IngressClassParams (cluster-wide) contains: `scheme`, `ipAddressType`,
`group.name`, and `certificateARNs`
- Ingress annotations (per-Ingress) contain: `load-balancer-name`,
`target-type`, `listen-ports`, `ssl-redirect`
- All Ingress resources use the same ALB with host-based routing via shared
`group.name` in IngressClassParams
- IngressClass created by ALB module references the IngressClassParams for
cluster-wide ALB configuration
- Certificate ARN configured once in IngressClassParams and inherited by all
Ingresses using this IngressClass

### ECR Image Mirroring Pattern

- **All third-party images mirrored to ECR**: OpenLDAP, Redis, PostgreSQL images
are automatically pulled from Docker Hub and pushed to ECR during deployment
- **Eliminates external dependencies**: No reliance on Docker Hub availability or
rate limits during pod startup
- **Faster image pulls**: Images pulled from same AWS region as EKS cluster
- **Version pinning**: Specific image versions are tagged and stored in ECR:
  - `redis-latest` tag for Redis (bitnami/redis:latest)
  - `postgresql-latest` tag for PostgreSQL (bitnami/postgresql:latest)
  - `openldap-1.5.0` for OpenLDAP (osixia/openldap:1.5.0) - version-pinned
- **Automatic mirroring**: `setup-application.sh` and GitHub Actions workflow
automatically check and mirror images before Terraform deployment
- **Idempotent operation**: Script only mirrors images that don't already exist
in ECR
- **Multi-account support**: Script properly handles credential switching between
State Account (for reading backend_infra state) and Deployment Account (for ECR
operations)

### CRITICAL: OpenLDAP Environment Variables

- The jp-gouin/helm-openldap chart does NOT properly pass `global.ldapDomain` to
the osixia/openldap container
- Must explicitly set these in the `env:` section of Helm values:
  - `LDAP_DOMAIN`: The LDAP domain (e.g., "ldap.talorlik.internal")
  - `LDAP_ADMIN_PASSWORD`: Admin password
  - `LDAP_CONFIG_PASSWORD`: Config password
- Without `LDAP_DOMAIN`, OpenLDAP initializes with empty/default config and
authentication fails
- If authentication fails after deployment, delete PVCs and restart pods to
reinitialize with correct environment variables

### Resource Deployment Order

Deployment order matters:

1. Terraform backend state infrastructure (S3 bucket)
2. Backend infrastructure (VPC → EKS → VPC Endpoints → ECR)
3. Application infrastructure (Existing Route53 zone + ACM cert lookup →
StorageClass → ALB module → OpenLDAP Helm release → Route53 A records →
Network policies → ArgoCD Capability)
4. Application (PostgreSQL → Redis → SES → SNS → 2FA backend/frontend Helm
releases → Route53 A record for twofa_app → ArgoCD Applications)

### Module Structure

- `backend_infra/modules/` - Reusable infrastructure modules:
  - `ecr/` - ECR repository with lifecycle policies
  - `endpoints/` - VPC endpoints for SSM, STS (IRSA), and SNS (SMS 2FA)
  - `ebs/` - EBS storage (commented out in main.tf)
- `application_infra/modules/` - Infrastructure-specific modules:
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `argocd/` - AWS EKS managed ArgoCD Capability for GitOps
  - `cert-manager/` - Optional cert-manager for self-signed TLS certificates
  - `network-policies/` - Kubernetes NetworkPolicies for secure communication
  with cross-namespace access
  - `openldap/` - OpenLDAP Stack HA deployment with multi-master replication,
  Kubernetes secrets, phpLDAPadmin, ltb-passwd, and Ingress
  - `route53/` - Route53 hosted zone creation (exists but commented out, uses
  data sources)
  - `route53_record/` - Route53 A (alias) record creation for per-record management
- `application/modules/` - Application-specific modules:
  - `argocd_app/` - ArgoCD Application CRD for GitOps deployments
  - `postgresql/` - PostgreSQL database with Kubernetes secrets for user data
  - `redis/` - Redis cache with Kubernetes secrets for SMS OTP storage with TTL
  - `ses/` - AWS SES for email verification and admin notifications
  - `sns/` - SNS resources for SMS-based 2FA with IRSA
- Each module has its own README.md with detailed documentation
- Route53 and ACM certificate resources use data sources to reference existing
resources
- All password-based services (OpenLDAP, PostgreSQL, Redis) now use Kubernetes secrets
instead of plain-text values in Helm charts

## GitHub Actions Workflows

### Available Workflows

**Infrastructure Workflows:**

- `tfstate_infra_provisioning.yaml` - Create Terraform backend state
- `tfstate_infra_destroying.yaml` - Destroy Terraform backend state
- `backend_infra_provisioning.yaml` - Create backend infrastructure
- `backend_infra_destroying.yaml` - Destroy backend infrastructure
- `application_infra_provisioning.yaml` - Deploy application infrastructure
(OpenLDAP, ALB, ArgoCD Capability, StorageClass)
- `application_infra_destroying.yaml` - Destroy application infrastructure
- `application_provisioning.yaml` - Deploy application (2FA app, PostgreSQL, Redis,
SES, SNS)
- `application_destroying.yaml` - Destroy application

**Application CI/CD Workflows:**

- `backend_build_push.yaml` - Build and push 2FA backend Docker image to ECR
- `frontend_build_push.yaml` - Build and push 2FA frontend Docker image to ECR

### Required GitHub Secrets

**AWS Authentication:**

- `AWS_STATE_ACCOUNT_ROLE_ARN` - ARN of IAM role in Account A (State Account)
that trusts GitHub OIDC provider (used for all backend state operations)
- `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` - ARN of IAM role in Production Account
(Account B) that trusts Account A role (used when `prod` environment is
selected)
- `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` - ARN of IAM role in Development Account
(Account B) that trusts Account A role (used when `dev` environment is selected)
- `AWS_ASSUME_EXTERNAL_ID` - ExternalId for cross-account role assumption
(prevents confused deputy attacks, required in deployment role Trust Relationships)

**Terraform Automation:**

- `GH_TOKEN` - GitHub PAT with `repo` scope (for updating repository variables)

**OpenLDAP Credentials:**

- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password (for application
workflows)
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP config password (for application
workflows)

**Database Credentials:**

- `TF_VAR_POSTGRESQL_PASSWORD` - PostgreSQL database password
- `TF_VAR_REDIS_PASSWORD` - Redis cache password

> [!NOTE]
>
> This project uses AWS SSO via GitHub OIDC instead of access keys.
> Workflows automatically select the appropriate deployment role ARN based on the
> selected environment. See main [README.md](README.md) for detailed IAM setup
> instructions.

### Required GitHub Variables

- `AWS_REGION` - AWS region for deployment
- `BACKEND_PREFIX` - S3 prefix for backend state files
- `BACKEND_BUCKET_NAME` - Auto-generated by backend state provisioning workflow
- `APPLICATION_INFRA_PREFIX` - S3 prefix for application infrastructure state files
(value: `application_infra_state/terraform.tfstate`)
- `APPLICATION_PREFIX` - S3 prefix for application state files
(value: `application_state/terraform.tfstate`)
- `ECR_REPOSITORY_NAME` - Auto-generated by backend infrastructure provisioning
workflow or `setup-backend.sh` script (required for build workflows)

## Recent Changes (December 2025 - January 2026)

### Project Reorganization: Separation of Infra and App (Jan 20-22, 2026)

- **MAJOR: Directory Structure Reorganization**
  - Separated application infrastructure from application code deployment for clearer
  separation of concerns
  - **Renamed** `application/` directory to `application_infra/` for infrastructure
  provisioning
  - **Created new** `application/` directory for 2FA application code and dependencies
  - **Enables independent deployment ordering**: Infrastructure must be deployed
  before application

- **Infrastructure Components (`application_infra/`)**
  - Contains OpenLDAP, ALB, ArgoCD Capability, cert-manager, network-policies,
  Route53 records (phpldapadmin, ltb-passwd)
  - Scripts: `setup-application-infra.sh`, `destroy-application-infra.sh`,
  `mirror-images-to-ecr.sh`, `set-k8s-env.sh`
  - Exports outputs for application use: `storage_class_name`, `local_cluster_secret_name`,
  `argocd_namespace`, `argocd_project_name`, `alb_dns_name`
  - State file key: `application_infra_state/terraform.tfstate`
  (uses `APPLICATION_INFRA_PREFIX` repository variable)

- **Application Components (`application/`)**
  - Contains 2FA application code: `backend/` (Python FastAPI), `frontend/` (HTML/JS/CSS)
  - Contains application modules: argocd_app, postgresql, redis, ses, sns
  - Scripts: `setup-application.sh`, `destroy-application.sh`
  - References `application_infra` remote state for infrastructure dependencies
  - State file key: `application_state/terraform.tfstate`
  (uses `APPLICATION_PREFIX` repository variable)

- **New GitHub Workflows**
  - Created `application_provisioning.yaml` - Deploys 2FA application and dependencies
  - Created `application_destroying.yaml` - Destroys application deployments
  - Updated `application_infra_provisioning.yaml` and `application_infra_destroying.yaml`
  - Application workflows depend on application_infra being deployed first

- **Deployment Order (CRITICAL)**
  1. `tf_backend_state/` - Terraform state backend (S3)
  2. `backend_infra/` - VPC, EKS, ECR, VPC endpoints
  3. `application_infra/` - OpenLDAP, ALB, ArgoCD Capability, StorageClass
  4. `application/` - 2FA app, PostgreSQL, Redis, SES, SNS, ArgoCD Applications

- **Backend State Configuration Standardization**
  - Infrastructure uses `APPLICATION_INFRA_PREFIX` repository variable (value: `application_infra_state/terraform.tfstate`)
  - Application uses `APPLICATION_PREFIX` repository variable (value: `application_state/terraform.tfstate`)
  - Both use same S3 bucket but different state file keys for isolation
  - Templates updated: `tfstate-backend-values-template.hcl` in both directories

- **Documentation Updates**
  - Split CHANGELOGs: `application_infra/CHANGELOG.md` and `application/CHANGELOG.md`
  - Created `application_infra/README.md` - Infrastructure deployment guide
  - Created `application/README.md` - Application deployment guide
  - Updated root `README.md` with new directory structure and deployment order

### Python Code Performance and Container Security Improvements (Jan 20, 2026)

- **Python Code Optimization**:
  - Improved logging performance across all backend modules
  - Optimized database connection handling in `app/database/connection.py`
  - Enhanced LDAP client operations with better error handling and performance
  - Improved email client logging efficiency
  - Optimized TOTP and SMS client modules for better performance
  - Updated API routes with more efficient logging patterns
  - Better resource management and reduced overhead

- **Backend Container Security Enhancement**:
  - Simplified multi-stage Docker build for backend application
  - Optimized layer caching for faster builds
  - Reduced attack surface with minimal base image
  - Improved build efficiency and container size

- **Frontend Container Security Enhancement**:
  - Changed frontend container port from 80 to 8080 for non-root execution
  - Frontend container now runs as non-root user (`appuser`, UID 1000)
  - Updated nginx configuration to listen on port 8080
  - Updated Dockerfile health check to use port 8080
  - Kubernetes service port remains 80 (external interface unchanged)
  - Container port 8080 is internal only; service forwards to container port 8080
  - No impact on external access or routing (handled by ALB)
  - Follows security best practices for containerized applications

- **Comprehensive Documentation**:
  - Added complete backend API documentation (`application/backend/README.md`)
    with architecture overview, API endpoints, development guidelines, and
    security considerations
  - Added comprehensive frontend documentation (`application/frontend/README.md`)
    with architecture diagrams, feature documentation, nginx configuration,
    and deployment guide
  - Updated `application/README.md` with frontend security details and port
    configuration
  - Enhanced security documentation in `application/SECURITY-IMPROVEMENTS.md`
  - All documentation reflects latest backend and frontend implementation

### ECR Repository Name Automation and Build Workflow Improvements (Jan 19, 2026)

- **Automatic ECR Repository Name Variable Management**:
  - Backend infrastructure provisioning now automatically saves ECR repository name
  to GitHub repository variable `ECR_REPOSITORY_NAME`
  - `setup-backend.sh` script automatically retrieves ECR repository name from
  Terraform outputs and saves it to GitHub variables
  - `backend_infra_provisioning.yaml` workflow automatically sets `ECR_REPOSITORY_NAME`
  variable after provisioning
  - Eliminates need for manual GitHub variable configuration
  - Build workflows (`backend_build_push.yaml` and `frontend_build_push.yaml`) now
  require `ECR_REPOSITORY_NAME` variable
  - Removed redundant PREFIX fallback logic from build workflows for cleaner, more
  maintainable code

- **Build Workflow Simplification**:
  - Simplified ECR repository name resolution in build workflows
  - Removed manual PREFIX-based repository name construction
  - Build workflows now fail fast with clear error message if `ECR_REPOSITORY_NAME`
  is not set
  - Error messages guide users to run backend infrastructure provisioning first

- **Deployment Monitoring Script**:
  - Added `monitor-deployments.sh` script for monitoring deployment progress
  - Provides real-time feedback on infrastructure provisioning status

- **ArgoCD Application Outputs**:
  - Corrected and enhanced ArgoCD application outputs for better visibility
  - Improved output structure for ArgoCD applications

### Public ACM Certificate Architecture Migration (January 18, 2026)

- **Public ACM Certificate Architecture**:
  - Uses Public ACM certificates (Amazon-issued) for browser-trusted certificates
  - Public ACM certificates requested in each deployment account (development, production)
  - DNS validation records created in Route53 hosted zone in State Account
  - Certificates stored in respective **deployment accounts** (not State Account)
  - Eliminates cross-account certificate access complexity
  - Compatible with **EKS Auto Mode ALB controller** requirements
  (certificate must be in same account as ALB)
  - Comprehensive Public ACM certificate setup documentation in `application/CROSS-ACCOUNT-ACCESS.md`
  with step-by-step AWS CLI commands
  - Certificate validation workflow documented for both production and
  development accounts
  - Certificates automatically renewed by ACM (no manual intervention required)
  - Browser-trusted certificates (no security warnings)
  - Updated all documentation to reflect Public ACM certificate architecture
  (PRD-ALB.md, README.md, docs/index.html)
  - Private CA setup moved to "Legacy" section (deprecated for public-facing applications)

### Helm Release Deployment Improvements (January 14, 2026)

- **Enhanced Helm Release Attributes for Safer Deployments**:
  - Added comprehensive Helm release attributes to all application modules
  (OpenLDAP, PostgreSQL, Redis, cert-manager):
    - `atomic: true` - Prevents partial deployments on failure
    - `force_update: true` - Enables forced updates when needed
    - `replace: true` - Prevents resource name conflicts and allows reusing names
    - `cleanup_on_fail: true` - Cleans up resources on failed deployments
    - `recreate_pods: true` - Forces pod restart on upgrade and rollbacks
    - `wait: true` - Waits for all resources to be ready before marking success
    - `wait_for_jobs: true` - Waits for any jobs to complete before marking success
    - `upgrade_install: true` - Prevents failures if pre-existing resources exist
  - OpenLDAP module timeout set to 5 minutes (300 seconds)
  - PostgreSQL and Redis module timeouts set to 10 minutes (600 seconds)
  - Improved deployment reliability and rollback safety
  - Better error handling during deployment failures

- **Standardized Helm Values Passing**:
  - Standardized how Helm values are passed through to all modules
  (OpenLDAP, PostgreSQL, Redis)
  - All modules now use consistent `templatefile()` approach with `values_template_path`
  variable
  - Modules can use default template path or custom path via variable
  - Improved maintainability and consistency across all Helm chart deployments
  - Created comprehensive Helm values templates:
    - `helm/postgresql-values.tpl.yaml` - PostgreSQL Helm chart values template
    - `helm/redis-values.tpl.yaml` - Updated Redis Helm chart values template
    - `helm/openldap-values.tpl.yaml` - Updated OpenLDAP Helm chart values template

- **PostgreSQL Chart Repository Fix**:
  - Fixed PostgreSQL Helm chart download issue by changing repository format
  - Changed from `https://charts.bitnami.com/bitnami` to `oci://registry-1.docker.io/bitnamicharts`
  - Uses OCI registry format for better compatibility and reliability
  - Resolves chart download failures during deployment

### Container Image Tag Strategy Update (January 14, 2026)

- **Image Tag Standardization**:
  - Changed Redis and PostgreSQL image tags to use descriptive tags instead of
  SHA digests
  - Redis default image tag: `redis-latest` (mirrors `bitnami/redis:8.4.0-debian-12-r6`)
  - PostgreSQL default image tag: `postgresql-latest` (mirrors `bitnami/postgresql:18.1.0-debian-12-r4`)
  - OpenLDAP continues to use specific version tag: `openldap-1.5.0` (mirrors `osixia/openldap:1.5.0`)
  - Image tags correspond to tags created by `mirror-images-to-ecr.sh` script
  - ECR mirroring script updated to push images with consistent naming convention
  - Simplifies image management and updates while maintaining version control
  - Default image tags can be overridden via `variables.tfvars`

### Cross-Account Access for Route53 (January 5, 2026)

- **State Account Role ARN Support**:
  - Added support for querying Route53 hosted zones from State Account
  - New variable `state_account_role_arn` for assuming role in State Account
  (where Route53 resides)
  - State account provider alias (`aws.state_account`) configured in `providers.tf`
  - All Route53 data sources and resources now use state account provider when configured
  - Route53 records (phpldapadmin, ltb_passwd, twofa_app, SES verification/DKIM)
  created in State Account
  - Route53 DNS validation records for Public ACM certificates created in
  State Account
  - Public ACM certificates are requested in Deployment Account (not State Account)
  - Scripts automatically inject `state_account_role_arn` into `variables.tfvars`
  - No ExternalId required for state account role assumption (by design)
  - Comprehensive cross-account access documentation in `application_infra/CROSS-ACCOUNT-ACCESS.md`
  - Self-assumption support: State Account role can assume itself when needed

### Route53 Record Module Separation (January 5, 2026)

- **Dedicated Route53 Record Module**:
  - Separated Route53 record creation from OpenLDAP module into dedicated `route53_record`
  module
  - New module located at `application_infra/modules/route53_record/` for
  per-record creation
  - Module uses state account provider (`aws.state_account`) for cross-account access
  - Route53 records created in State Account while ALB deployed in Deployment Account
  - Three separate module calls in `main.tf`:
    - `module.route53_record_phpldapadmin` - Creates A record for phpLDAPadmin
    - `module.route53_record_ltb_passwd` - Creates A record for ltb-passwd
    - `module.route53_record_twofa_app` - Creates A record for 2FA application
  - Module outputs: `record_name`, `record_fqdn`, `record_id`
  - Precondition ensures ALB DNS name is available before record creation
  - Comprehensive ALB zone_id mapping by region (13 AWS regions supported)
  - Proper dependency chain: OpenLDAP module → ALB data source → Route53 records
  - Lifecycle block with `create_before_destroy` for safe updates
  - Comprehensive module documentation in `application_infra/modules/route53_record/README.md`

### ECR Image Mirroring for Third-Party Container Images (January 5, 2026)

- **Automated Image Mirroring Script**:
  - Created `application_infra/mirror-images-to-ecr.sh` script (290+ lines) to eliminate
  Docker Hub rate limiting and external dependencies
  - Automatically mirrors third-party container images from Docker Hub to ECR:
    - `bitnami/redis:8.4.0-debian-12-r6` → `redis-8.4.0`
    - `bitnami/postgresql:18.1.0-debian-12-r4` → `postgresql-18.1.0`
    - `osixia/openldap:1.5.0` → `openldap-1.5.0`
  - Checks if images exist in ECR before mirroring (skips if already present)
  - Uses State Account credentials to fetch ECR URL from backend_infra state
  - Assumes Deployment Account role for ECR operations (with ExternalId)
  - Authenticates Docker to ECR automatically using `aws ecr get-login-password`
  - Cleans up local images after pushing to save disk space
  - Lists all images in ECR repository after completion
  - Integrated into `application_infra/setup-application-infra.sh`
  (runs before Terraform operations)
  - Integrated into GitHub Actions workflow (runs after Terraform validate)
  - Requires Docker to be installed and running
  - Requires `jq` for JSON parsing (with fallback to sed for compatibility)
  - Prevents Docker Hub rate limiting (200 pulls per 6 hours for anonymous) and
  external dependencies
  - Comprehensive error handling and user feedback
  - Proper credential switching for multi-account architecture
- **ECR Image Support for All Modules**:
  - All three modules (OpenLDAP, PostgreSQL, Redis) now use ECR images instead of
  Docker Hub
  - New variables in `application/variables.tf`: `openldap_image_tag`, `postgresql_image_tag`,
  `redis_image_tag`
  - ECR registry and repository computed from backend_infra state (`ecr_url`)
  - All modules updated with ECR configuration variables
  (registry, repository, tag)
  - Helm values templates updated to use ECR images
  - Image tags correspond to tags created by `mirror-images-to-ecr.sh`
- **Application main.tf Enhancements**:
  - Retrieves ECR URL from backend_infra remote state
  - Parses ECR URL to extract registry and repository name
  - Passes ECR configuration to OpenLDAP, Redis, and PostgreSQL modules
- **GitHub Actions Workflow Updates**:
  - Added Docker Buildx setup to `application_infra_provisioning.yaml`
  - Integrated `mirror-images-to-ecr.sh` execution before Terraform deployment
  - Follows same multi-account credential flow as local scripts
- **EKS ECR Permissions**:
  - EKS Auto Mode automatically provides ECR pull permissions to nodes
  - No additional IAM policy configuration required
  - Nodes can pull images from ECR without hardcoded credentials

### Destroy Scripts for Infrastructure Cleanup (December 30, 2025)

- **Automated Destroy Scripts**:
  - Created `backend_infra/destroy-backend.sh` for destroying backend infrastructure
  - Created `application_infra/destroy-application-infra.sh` for destroying application
  infrastructure
  - Created `application/destroy-application.sh` for destroying application
  - Both scripts support interactive region and environment selection
  - Automatic retrieval of role ARNs, ExternalId, and secrets from AWS Secrets Manager
  - Automatic backend configuration and variables.tfvars updates
  - Kubernetes environment setup for application destroy script (via `set-k8s-env.sh`)
  - Comprehensive error handling and user guidance
- **Safety Features**:
  - Double confirmation required before destruction (type 'yes' then 'DESTROY')
  - Clear warnings about irreversible actions
  - Validation of user input before proceeding
  - Color-coded output for better visibility
- **GitHub Actions Integration**:
  - Updated destroying workflows with ExternalId support
  - Workflows use same role assumption pattern as provisioning workflows
  - Proper permissions declarations for security compliance

### Terraform Backend State Enhancements (December 30, 2025)

- **Simplified Terraform Configuration**:
  - Removed `principal_arn` variable - bucket policy now automatically uses current
  caller's ARN via `data.aws_caller_identity.current.arn`
  - Eliminates need to pass principal ARN as a variable, simplifying configuration
  - Reduces user configuration burden and potential errors
- **Enhanced set-state.sh Script**:
  - Automatic role assumption from AWS Secrets Manager (secret: `github-role`)
  - Intelligent infrastructure provisioning detection via `BACKEND_BUCKET_NAME`
  repository variable
  - Automatic state file download from S3 when bucket exists
  - Terraform validation, plan, and apply workflow integration
  - Bucket name verification and GitHub repository variable management
  - Comprehensive error handling with colored output (INFO, SUCCESS, ERROR)
  - Always updates bucket name and state file to ensure synchronization
  - Enhanced credential extraction with jq fallback to sed for broader compatibility
  - Improved user feedback throughout the process

### ExternalId Security Feature for Cross-Account Role Assumption (Dec 29, 2025)

- **ExternalId Support**:
  - Added ExternalId requirement for enhanced security when assuming deployment
  account roles
  - Prevents confused deputy attacks in multi-account deployments
  - ExternalId retrieved from AWS Secrets Manager (secret: `external-id`) for
  local deployment scripts
  - ExternalId retrieved from GitHub repository secret (`AWS_ASSUME_EXTERNAL_ID`)
  for GitHub Actions workflows
  - ExternalId passed to Terraform provider's `assume_role` block in both
  `application` and `backend_infra`
  - New variable `deployment_account_external_id` added to `application/variables.tf`
  and `backend_infra/variables.tf`
  - Setup scripts (`setup-application.sh` and `setup-backend.sh`) automatically
  retrieve ExternalId from AWS Secrets Manager
  - Destroy scripts (`destroy-application.sh` and `destroy-backend.sh`) also
  retrieve ExternalId from AWS Secrets Manager
  - GitHub Actions workflows updated to use `AWS_ASSUME_EXTERNAL_ID` secret
  - Deployment account roles must have ExternalId condition in Trust Relationship
  - **Bidirectional Trust Relationships**: Both deployment account roles and state
  account role must trust each other in their respective Trust Relationships
  - State account role's Trust Relationship must include deployment account role
  ARNs to enable proper cross-account role assumption
  - ExternalId generation: `openssl rand -hex 32`
- **Documentation Updates**:
  - Updated `SECRETS_REQUIREMENTS.md` with comprehensive ExternalId setup instructions
  and bidirectional trust relationship requirements
  - Updated all README files with ExternalId configuration steps and destroy script
  usage
  - Updated `SECURITY-IMPROVEMENTS.md` with ExternalId security benefits
  - Updated GitHub Pages documentation (`docs/index.html`)
  - Updated CHANGELOG.md files across all layers with destroy script additions

### Security Enhancements and Code Scanning Fixes (December 28, 2025)

- **GitHub Workflow Security Improvements**:
  - Added explicit permissions declarations to all workflow jobs
  - Applied principle of least privilege with `contents: read` or empty
  `permissions: {}`
  where no permissions needed
  - Fixes automated code scanning alerts for missing workflow permissions
  - Affected workflows: all infrastructure provisioning/destroying and build/push
  workflows
- **LDAP Injection Prevention**:
  - Fixed LDAP query injection vulnerability in `application/backend/src/app/ldap/client.py`
  - Added DN component escaping using `ldap3.utils.dn.escape_rdn()`
  - Protects `user_exists()` and `get_user_attribute()` methods from malicious input
  - User-controlled input now properly sanitized before LDAP queries
- **Sensitive Information Logging Protection**:
  - Fixed clear-text logging of phone numbers in `application/backend/src/app/sms/client.py`
  - Replaced phone number logging with SHA-256 hash (first 8 characters)
  - Applied to `opt_in_phone_number()` method
  - Protects PII in application logs
- **API Documentation Always Enabled**:
  - Swagger UI (`/api/docs`) and ReDoc UI (`/api/redoc`) now always accessible in
  production
  - Removed debug mode condition for API documentation endpoints
  - OpenAPI schema available at `/api/openapi.json`
  - Interactive documentation automatically updates when endpoints change
- **Documentation Improvements**:
  - Removed duplication by replacing detailed module descriptions with links to
  module READMEs
  - Enhanced cross-references to module documentation (ALB, ArgoCD, cert-manager,
  Network Policies, PostgreSQL, Redis, SES, SNS, VPC Endpoints, ECR, OpenLDAP)
  - Updated component descriptions to be more concise with links to detailed documentation
  - Improved consistency across documentation files
  - Main README restructured for better clarity and organization

### Kubernetes Secrets Integration and OpenLDAP Module (December 27-28, 2025)

- **OpenLDAP Module (`application/modules/openldap/`)**:
  - Modularized OpenLDAP Stack HA deployment with comprehensive configuration
  - Includes phpLDAPadmin and ltb-passwd web interfaces
  - Manages Kubernetes secrets for OpenLDAP passwords
  - Handles Helm release deployment with templated values
  - Creates ALB Ingress resources for public access
  - Route53 DNS records now created separately via `route53_record` module
  - See [OpenLDAP Module Documentation](application/modules/openldap/README.md)
  for details
- **Kubernetes Secrets for All Components**:
  - **OpenLDAP**: Kubernetes secret created by OpenLDAP module for admin/config
  passwords
  - **PostgreSQL**: Uses Kubernetes secret for database password (created by module)
  - **Redis**: Uses Kubernetes secret for authentication password (created by module)
  - Eliminates plain-text passwords in Helm values
  - All secrets created from Terraform variables (sourced from AWS Secrets Manager
  or GitHub Secrets)
- **Secrets Management Consolidation**:
  - Created comprehensive `SECRETS_REQUIREMENTS.md` documentation (located in root)
  - Documents both AWS Secrets Manager setup (for local scripts) and
  GitHub Repository Secrets (for workflows)
  - Two AWS Secrets Manager secrets: `github-role` (IAM role ARNs) and `tf-vars`
  (passwords)
  - Clear distinction between local and GitHub Actions secret retrieval methods
  - Case sensitivity guidance for TF_VAR environment variables
- **Updated Setup Scripts**:
  - `backend_infra/setup-backend.sh`: Now retrieves secrets from AWS Secrets Manager
  - `application/setup-application.sh`: Retrieves both role ARNs and passwords
  from AWS Secrets Manager
  - Eliminated dependency on GitHub CLI for secret retrieval (GitHub CLI cannot
  read secret values)
  - Scripts automatically export secrets as environment variables for Terraform
  - Improved error handling and validation
- **GitHub Workflows Updated**:
  - Added missing `TF_VAR_POSTGRESQL_PASSWORD` and `TF_VAR_REDIS_PASSWORD` to workflows
  - Workflows continue to use GitHub Repository Secrets (unchanged)
  - Added permissions declarations to all jobs
- **Module Improvements**:
  - PostgreSQL module now creates Kubernetes secret with `postgresql-password` key
  - Redis module creates Kubernetes secret with `redis-password` key
  - OpenLDAP module creates Kubernetes secret with admin/config password keys
  - Bitnami Helm charts configured to use `existingSecret` instead of plain-text
  values

### AWS Secrets Manager Integration for Local Scripts (December 27, 2025)

- **Local script secret retrieval from AWS Secrets Manager**:
  - Updated `get-state.sh` and `set-state.sh` to retrieve role ARNs from
  AWS Secrets Manager
  - Secret name: `github-role` containing JSON with key `AWS_STATE_ACCOUNT_ROLE_ARN`
  - Replaces previous GitHub CLI secret access (GitHub CLI cannot read secret
  values directly)
  - Scripts automatically assume the role retrieved from AWS Secrets Manager
- **GitHub Actions workflows unchanged**:
  - Workflows continue to retrieve role ARN from GitHub repository secrets
  - No changes to `AWS_STATE_ACCOUNT_ROLE_ARN` GitHub secret configuration
- **Prerequisites for local execution**:
  - AWS Secrets Manager secret `github-role` must exist with proper JSON structure
  - User credentials must have `secretsmanager:GetSecretValue` permission
  - Example secret JSON: `{"AWS_STATE_ACCOUNT_ROLE_ARN": "arn:aws:iam::<account-id>:role/<role-name>"}`
- **Improved error handling**:
  - Comprehensive error messages for secret retrieval failures
  - JSON validation for secret content
  - Key existence validation within secret
- **Updated documentation**:
  - `tf_backend_state/README.md` updated with AWS Secrets Manager setup instructions
  - `tf_backend_state/CHANGELOG.md` updated with latest changes
  - Clarified differences between GitHub Actions (repository secrets) and local
  scripts (AWS Secrets Manager)

## Recent Changes (December 2025)

### Admin Functions and User Profile Management (December 18, 2025)

- **Admin Dashboard and User Management**:
  - Admin tab visible only to LDAP admin group members
  - User management with filter by status (pending, complete, active, revoked)
  - View user details: name, email, phone, verification status, MFA method,
  groups
  - Activation and revocation workflow with audit logging
  - Approval requires group assignment (at least one group)
  - Creates user in LDAP with all attributes on approval
  - Revocation removes user from LDAP and all groups
- **User Profile Management**:
  - Profile page with viewable and editable fields
  - Edit restrictions: email/phone read-only after verification
  - Profile fields: username, first/last name, email, phone, MFA method, status
- **Group Management (Full CRUD)**:
  - Create, read, update, delete groups via admin interface
  - Group-user assignment management
  - Sync with LDAP groups on create/update/delete
  - View group members and member counts
- **Admin Notifications**:
  - Email notification to all admins on new user signup
  - Uses AWS SES infrastructure with IRSA
  - Async notification (non-blocking)
- **Top Navigation Bar**:
  - Persistent navigation after login
  - User menu with profile and logout options
  - Admin-specific menu items for admin users

### User Signup Management System (December 18, 2025)

- **Self-Service User Registration**:
  - Signup form with fields: first/last name, username, email, phone, password,
  MFA method
  - Username validation (3-64 chars, alphanumeric + underscore/hyphen)
  - Email and phone uniqueness validation
  - Password hashing with bcrypt
- **Email Verification via AWS SES**:
  - UUID token-based verification links
  - 24-hour token expiry (configurable)
  - Resend verification with 60-second cooldown
  - Email delivery via AWS SES with IRSA
- **Phone Verification via AWS SNS**:
  - 6-digit OTP code via SMS
  - 1-hour code expiry
  - Resend code with 60-second cooldown
  - SMS delivery via AWS SNS with IRSA
- **Profile State Management**:
  - PENDING: User registered, verification incomplete
  - COMPLETE: All verifications complete, awaiting admin
  - ACTIVE: Admin activated, exists in LDAP
  - REVOKED: Admin revoked, removed from LDAP
- **Login Restrictions**:
  - PENDING users cannot login (shows missing verifications)
  - COMPLETE users see "awaiting admin approval" message
  - Only ACTIVE users can complete login flow

### Redis SMS OTP Storage (December 18, 2025)

- **Redis Module (`modules/redis/`) for SMS OTP Code Storage**:
  - Bitnami Redis Helm chart deployment via Terraform
  - Standalone architecture (sufficient for OTP cache use case)
  - Password authentication via Kubernetes Secret (from GitHub Secrets)
  - PersistentVolume storage with RDB snapshots for data recovery
  - Non-root security context (UID 1001)
  - Network policy restricting Redis access to backend pods only
  - TTL-based automatic expiration for OTP codes
- **Redis Client Module (`app/redis/`)**:
  - `RedisOTPClient` class with TTL-aware storage operations
  - Automatic fallback to in-memory storage when Redis is disabled
  - Methods: `store_code()`, `get_code()`, `delete_code()`, `code_exists()`
  - Connection health checking and error handling
  - Lazy initialization with connection pooling

### PostgreSQL and SES Integration (December 18, 2025)

- **PostgreSQL Module (`modules/postgresql/`)**:
  - Bitnami PostgreSQL Helm chart deployment
  - Database for user registrations and verification tokens
  - Password authentication from GitHub Secrets
  - PersistentVolume storage with RDB
- **SES Module (`modules/ses/`)**:
  - AWS SES email identity verification
  - IAM Role with IRSA for secure pod access
  - Email sending for verification and notifications
  - Sender email configuration
- **Database Connection Module (`app/database/`)**:
  - PostgreSQL connection management
  - SQLAlchemy models for users, verification tokens, groups, user-group
  relationships
  - Async database operations
- **Email Client Module (`app/email/`)**:
  - AWS SES integration for sending emails
  - Email templates for verification and welcome emails
  - IRSA-based authentication for SES access
- **New API Endpoints**:
  - `POST /api/auth/signup` - Register new user
  - `POST /api/auth/verify-email` - Verify email with token
  - `POST /api/auth/verify-phone` - Verify phone with code
  - `POST /api/auth/resend-verification` - Resend verification
  - `GET /api/profile/status/{username}` - Get profile status
  - `GET /api/profile/{username}` - Get user profile
  - `PUT /api/profile/{username}` - Update user profile
  - Admin endpoints for user and group management
- **Product Requirements Document**: Comprehensive PRD-SIGNUP-MAN.md documenting
signup system, user stories, and API specifications

### 2FA Application and SMS Integration (December 18, 2025 - Initial Release)

- **Full-stack 2FA application deployed**:
  - Python FastAPI backend with LDAP authentication integration
  - Static HTML/JS/CSS frontend with modern, responsive UI
  - Support for **two MFA methods**: TOTP (authenticator apps) and SMS (AWS SNS)
  - Single domain routing (`app.<domain>`) with path-based routing (`/` for
  frontend, `/api/*` for backend)
  - Kubernetes resources: Deployments, Services, Ingresses, ConfigMaps, Secrets,
  ServiceAccounts, HPA
  - Complete Helm charts for both backend and frontend
  - Dockerfiles for containerized deployment
- **SNS module for SMS-based 2FA verification**:
  - SNS Topic for centralized SMS notifications
  - IAM Role configured for IRSA (IAM Roles for Service Accounts)
  - Direct SMS support for sending verification codes to phone numbers
  - E.164 phone number format support
  - Transactional SMS type for higher delivery priority
  - Cost control via monthly spend limits
- **GitHub Actions CI/CD workflows**:
  - `backend_build_push.yaml` - Builds and pushes backend Docker image to ECR
  - `frontend_build_push.yaml` - Builds and pushes frontend Docker image to ECR
  - Triggered on changes to `application/backend/**` and
  `application/frontend/**` paths
- **Product Requirements Document**: Comprehensive PRD-2FA-APP.md documenting
architecture, API specs, and frontend components

### ArgoCD GitOps Integration (December 16, 2025)

- **ArgoCD capability module**:
  - Deploys AWS EKS managed ArgoCD service (runs in EKS control plane)
  - Creates IAM role and policies for ArgoCD capability
  - Configures AWS Identity Center (IdC) authentication
  - Registers local EKS cluster with ArgoCD
  - Sets up RBAC mappings for Identity Center groups/users
  - Optional VPC endpoint configuration for private access
- **ArgoCD Application module**:
  - Creates ArgoCD Application CRD for GitOps deployments
  - Supports multiple deployment types (Kubernetes manifests, Helm charts,
  Kustomize)
  - Configurable sync policies (automated/manual)
  - Retry policies with backoff configuration
  - Ignore differences for externally managed fields

### Documentation and Linting Improvements (December 15, 2025)

- **Markdown lint compliance**:
  - Corrected row length issues across all documentation files
  - Added `.markdownlint.json` for consistent formatting
  - Updated all README files, CHANGELOGs, and PRD documents

### Deployment Versatility and Security Improvements (December 14, 2025)

- **Cross-namespace LDAP access**:
  - Updated network policies to allow services in other namespaces to access
  LDAP service on secure ports (443, 636, 8443)
  - Enables microservices in different namespaces to securely access centralized
  LDAP service
- **Password management via GitHub Secrets**:
  - OpenLDAP passwords now exclusively managed through GitHub repository secrets
  - Setup scripts automatically retrieve and export passwords
  - Removed dependency on local password files
- **Unified application setup script**:
  - New `setup-application.sh` consolidates all application deployment steps
  - Handles role assumption, backend configuration, Terraform operations, and
  Kubernetes environment setup
  - Replaces previous `setup-backend.sh` and `setup-backend-api.sh` scripts

## Earlier Changes (December 2025)

### Multi-Account Architecture and Role Management (Latest)

- **Environment-based AWS role ARN selection**: Added support for separate
deployment role ARNs for production and development environments
  - New GitHub secrets: `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` and
  `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`
  - Workflows and scripts automatically select the appropriate role ARN based on
  selected environment (`prod` or `dev`)
  - Backend state operations always use `AWS_STATE_ACCOUNT_ROLE_ARN` (Account A)
  - Deployment operations use environment-specific role ARNs via Terraform
  provider `assume_role`
- **Removed `provider_profile` variable**: No longer needed since role
assumption is handled via setup scripts and workflows
  - Removed from `backend_infra/variables.tf`, `backend_infra/variables.tfvars`,
  `backend_infra/providers.tf`
  - Removed from `application/variables.tf`, `application/variables.tfvars`,
  `application/providers.tf`
- **Automated Terraform execution in backend_infra setup script**:
  - `backend_infra/setup-backend.sh` now automatically runs Terraform commands
  (init, workspace, validate, plan, apply)
  - Eliminates the need for manual Terraform command execution after backend
  configuration
  - Script handles workspace creation/selection automatically
  - Script assumes `AWS_STATE_ACCOUNT_ROLE_ARN` for backend operations and
  retrieves environment-specific deployment role ARN
- **Automated backend.hcl creation in backend_infra**:
  - `setup-backend.sh` now automatically creates `backend.hcl` from template if
  it doesn't exist
  - Skips creation if `backend.hcl` already exists (prevents overwriting
  existing configuration)
- **Updated workflows**: All infrastructure and application workflows now use
`AWS_STATE_ACCOUNT_ROLE_ARN` for backend operations and set
`deployment_account_role_arn` variable based on selected environment
- **CI/CD workflows**: New workflows for building and pushing 2FA application
Docker images to ECR

### ALB Annotation Strategy Improvements

- **Moved certificate ARN and group name to IngressClassParams**: Centralized
TLS and group configuration at the cluster level
- **Reduced annotation duplication**: Certificate and group configuration
defined once in IngressClassParams, inherited by all Ingresses
- **Simplified Helm values**: Removed `group.name` and `certificate-arn` from
Ingress annotations
- **Updated documentation**: Comprehensive ALB implementation guide in
`PRD-ALB.md` with EKS Auto Mode comparison

### New Outputs and Modules

- **Added comprehensive outputs**: Backend infrastructure outputs (VPC
endpoints, ECR) and application outputs (ALB, Route53, network policies)
- **cert-manager module**: Optional module for self-signed TLS certificates
(exists but not actively used)
- **CHANGELOG.md**: Detailed changelog tracking ALB configuration changes, TLS
environment variable updates, and multi-account architecture changes
- **OSIXIA-OPENLDAP-REQUIREMENTS.md**: Documentation for osixia/openldap image
requirements

## Development Workflow

### Making Infrastructure Changes

1. Update `variables.tfvars` with desired changes
2. For application layer, ensure OpenLDAP passwords are exported as environment
variables (for local use) or available as GitHub secrets (the setup script
handles retrieval automatically)
3. For backend_infra, run `./setup-backend.sh` to automatically configure and
deploy (includes Terraform init, workspace, validate, plan, apply)
4. For application layer, run `./setup-application.sh` to automatically
configure and deploy (includes password secret retrieval, Terraform init,
workspace, validate, plan, apply, and Kubernetes environment setup)
5. For multi-region or multi-environment deployments, run setup scripts again
with different selections
6. Review `CHANGELOG.md`, `backend_infra/CHANGELOG.md`, and
`application/CHANGELOG.md` for recent changes and verification steps

### Destroying Infrastructure

1. **Application Layer**:
   - Run `./destroy-application.sh` from the `application/` directory
   - Script automatically retrieves credentials and configurations
   - Requires double confirmation (type 'yes' then 'DESTROY')
   - Handles Kubernetes environment setup automatically
2. **Backend Infrastructure**:
   - Run `./destroy-backend.sh` from the `backend_infra/` directory
   - Script automatically retrieves credentials and configurations
   - Requires double confirmation (type 'yes' then 'DESTROY')
3. **Backend State**:
   - Use GitHub Actions workflow "TF Backend State Destroying" (recommended)
   - Or manually destroy using Terraform commands after assuming IAM role
4. **Destroy Order**: Always destroy in reverse order of creation:
   - Application layer → Backend infrastructure → Backend state

### Developing 2FA Application

1. **Backend Changes** (`application/backend/`):
   - Make changes to Python code in `src/`
   - Test locally if possible
   - Commit and push changes to `application/backend/**`
   - GitHub Actions workflow `backend_build_push.yaml` automatically:
     - Builds Docker image
     - Tags with commit SHA
     - Pushes to ECR
     - If using ArgoCD: ArgoCD detects change and syncs
     - If using direct Helm: Update image tag in Helm values and re-apply
2. **Frontend Changes** (`application/frontend/`):
   - Make changes to HTML/JS/CSS in `src/`
   - Test locally with a simple HTTP server
   - Frontend container runs on port 8080 as non-root user (`appuser`, UID 1000)
   - Kubernetes service exposes port 80 externally (forwards to container port 8080)
   - Commit and push changes to `application/frontend/**`
   - GitHub Actions workflow `frontend_build_push.yaml` automatically handles
   build and push
   - Deployment follows same pattern as backend
3. **Terraform Module Changes** (`application/modules/`):
   - Update module code and test
   - Run `./setup-application.sh` to apply changes
   - Review outputs and verify resources

### Adding New Kubernetes Resources

1. Add resources to `application/main.tf` or create a new module in
`application/modules/`
2. Update Helm values template if needed
(`application/helm/openldap-values.tpl.yaml`)
3. Ensure proper `depends_on` relationships (e.g., Helm release, data sources)
4. For IRSA-enabled resources:
   - Create IAM role with trust policy for EKS OIDC provider
   - Attach necessary permissions
   - Add annotation to ServiceAccount: `eks.amazonaws.com/role-arn`
5. Plan and apply changes using `./setup-application.sh`
6. For Ingress changes, ALB will be automatically updated via Kubernetes
controller
7. If using ArgoCD, commit manifests to Git and let ArgoCD sync

### Troubleshooting

- **PVC stuck in Pending**: Normal until a pod uses it (EBS Auto Mode behavior
with WaitForFirstConsumer)
- **Terraform workspace issues**: Ensure workspace exists before selecting
(format: `region-env`, e.g. `us-east-1-prod`)
- **Backend config errors**: Re-run `setup-backend.sh` (backend_infra) or
`setup-application.sh` (application) to regenerate `backend.hcl`
- **SSM access denied**: Check VPC endpoint security groups and IAM policies
- **Cluster name not found**: Ensure backend_infra is deployed first and
`backend.hcl` is configured correctly, or provide `cluster_name` in
variables.tfvars
- **OpenLDAP password errors**: The setup script automatically retrieves
passwords from GitHub secrets. For local use, ensure passwords are exported as
environment variables (`TF_VAR_OPENLDAP_ADMIN_PASSWORD`,
`TF_VAR_OPENLDAP_CONFIG_PASSWORD`) before running the script
- **ALB not created**: Check Ingress resources have proper annotations, ACM
certificate is validated, and IngressClass/IngressClassParams exist
- **Route53 DNS not resolving**: Ensure Route53 A records point to ALB DNS name
and NS records are configured at registrar
- **IngressClass not found**: Ensure ALB module is deployed (via `use_alb =
true` variable)
- **Certificate not applied**: Certificate ARN is configured in
IngressClassParams, not in Ingress annotations

### OpenLDAP Authentication Issues (Error 49: Invalid Credentials)**

1. **Root Cause**: OpenLDAP was initialized without proper `LDAP_DOMAIN`
environment variable
   - Symptoms: `ldap_bind: Invalid credentials (49)` even with correct password
   - The jp-gouin chart's `global.ldapDomain` doesn't pass through to
   osixia/openldap container
   - Must explicitly set `LDAP_DOMAIN`, `LDAP_ADMIN_PASSWORD`, and
   `LDAP_CONFIG_PASSWORD` in `env:` section

2. **Fix**: Delete PVCs to force re-initialization with correct environment
variables:

   ```bash
   kubectl delete pvc -n ldap --all
   kubectl delete pod -n ldap openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2
   # Wait for pods to restart and PVCs to recreate
   ```

3. **Verify Fix**:

   ```bash
   # Check environment variables are set
   kubectl exec -n ldap openldap-stack-ha-0 -- env | grep LDAP_DOMAIN

   # Test authentication
   kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x -LLL -H ldap://localhost:389 \
     -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" -w "<password>" \
     -b "dc=ldap,dc=talorlik,dc=internal" "(objectClass=*)" dn
   ```

### ALB Ingress Group Issues (Multiple ALBs Created)**

1. **Root Cause**: AWS Load Balancer Controller creates separate ALBs when
multiple Ingresses with same `group.name` are created simultaneously
   - Symptoms: Each Ingress shows different ALB address; one returns 404 while
   other works
   - Example: `phpldapadmin` on `k8s-ldap-openldap-xxx` and `passwd` on
   `talo-tf-us-east-1-talo-ldap-prod-xxx`

2. **Fix**: Delete all ALBs and Ingresses, then recreate cleanly:

   ```bash
   # Delete all LDAP-related ALBs
   aws elbv2 describe-load-balancers --region us-east-1 \
     --query 'LoadBalancers[?contains(LoadBalancerName, `ldap`)].LoadBalancerArn' \
     --output text | xargs -n1 aws elbv2 delete-load-balancer --region us-east-1 --load-balancer-arn

   # Delete Ingresses
   kubectl delete ingress -n ldap --all

   # Wait for cleanup (60 seconds)
   sleep 60

   # Recreate Helm release
   terraform apply -replace="helm_release.openldap" -var-file="variables.tfvars" -auto-approve
   ```

3. **Verify Fix**:

   ```bash
   # Both Ingresses should show same ALB address
   kubectl get ingress -n ldap

   # Test both sites return 200 OK
   curl -I https://phpldapadmin.talorlik.com
   curl -I https://passwd.talorlik.com
   ```

### Route53 Record State Issues**

1. **Root Cause**: Route53 records reference `local.alb_dns_name` which is empty
when Ingresses don't exist
   - Symptoms: Terraform validation error "expected length of alias.0.name to be
   in the range (1 - 1024), got"

2. **Fix**: Remove records from Terraform state and AWS, then recreate:

   ```bash
   # Remove from Terraform state
   terraform state rm aws_route53_record.phpldapadmin aws_route53_record.ltb_passwd

   # Delete from AWS (create delete batch)
   cat > /tmp/delete-records.json << 'EOF'
   {
     "Changes": [
       {
         "Action": "DELETE",
         "ResourceRecordSet": {
           "Name": "phpldapadmin.talorlik.com",
           "Type": "A",
           "AliasTarget": {
             "HostedZoneId": "Z35SXDOTRQ7X7K",
             "DNSName": "<old-alb-dns-name>",
             "EvaluateTargetHealth": true
           }
         }
       },
       {
         "Action": "DELETE",
         "ResourceRecordSet": {
           "Name": "passwd.talorlik.com",
           "Type": "A",
           "AliasTarget": {
             "HostedZoneId": "Z35SXDOTRQ7X7K",
             "DNSName": "<old-alb-dns-name>",
             "EvaluateTargetHealth": true
           }
         }
       }
     ]
   }
   EOF
   aws route53 change-resource-record-sets --hosted-zone-id <zone-id> --change-batch file:///tmp/delete-records.json

   # Apply Terraform to recreate records
   terraform apply -auto-approve -var-file="variables.tfvars"
   ```

## Important Notes

### MFA Methods

The 2FA application supports two multi-factor authentication methods:

| Method | Description | Infrastructure Required |
| -------- | ------------- | ------------------------ |
| **TOTP** | Time-based One-Time Password using authenticator apps (Google Authenticator, Authy, etc.) | None (codes generated locally) |
| **SMS** | Verification codes sent via AWS SNS to user's phone | SNS VPC endpoint, IRSA role, SNS module |

**Enabling SMS 2FA:**

1. Set `enable_sts_endpoint = true` in `backend_infra/variables.tfvars` (for
IRSA)
2. Set `enable_sns_endpoint = true` in `backend_infra/variables.tfvars` (for
SNS access)
3. Deploy backend_infra with VPC endpoints
4. Set `enable_sms_2fa = true` in `application/variables.tfvars`
5. Deploy application infrastructure with SNS module
6. Backend automatically detects SNS configuration and enables SMS MFA method

### TLS Configuration

- **Internal LDAP TLS**: osixia/openldap auto-generates self-signed certificates
on first startup
  - Environment variables: `LDAP_TLS: "true"`, `LDAP_TLS_ENFORCE: "false"`,
  `LDAP_TLS_VERIFY_CLIENT: "never"`
  - Filenames: `LDAP_TLS_CRT_FILENAME: "ldap.crt"`, `LDAP_TLS_KEY_FILENAME:
  "ldap.key"`, `LDAP_TLS_CA_CRT_FILENAME: "ca.crt"`
- **ALB TLS**: ACM certificate terminates TLS at ALB for public access
- **cert-manager Module**: Optional module for managing custom certificates
(currently exists but not actively used)

### Storage Configuration

- **StorageClass**: Created by application Terraform
(`kubernetes_storage_class_v1` resource)
  - Name pattern: `${prefix}-${region}-${storage_class_name}-${env}` (e.g.,
  `talo-tf-us-east-1-gp3-ldap-prod`)
  - Provisioner: `ebs.csi.eks.amazonaws.com` (built-in to EKS Auto Mode)
  - Volume binding mode: `WaitForFirstConsumer` (PVCs stay Pending until pod is
  scheduled)
  - Type: `gp3` (configurable via `storage_class_type` variable)
  - Encryption: Enabled by default (configurable via `storage_class_encrypted`
  variable)
- **PVC**: Created by Helm chart using the StorageClass
  - Size: 8Gi (configurable in Helm values)
  - Access mode: ReadWriteOnce
  - Replication: 3 replicas, each with its own PVC

### ALB Configuration

- **EKS Auto Mode**: Uses built-in load balancer driver (`eks.amazonaws.com/alb`
controller) with automatic IAM permissions
- **IngressClassParams** (cluster-wide): Sets `scheme`, `ipAddressType`,
`group.name`, and `certificateARNs` for all ALBs using the IngressClass
  - Note: EKS Auto Mode IngressClassParams does NOT support subnets, security
  groups, or tags (unlike AWS Load Balancer Controller)
- **Per-Ingress annotations**: Control `load-balancer-name`, `target-type`,
`listen-ports`, `ssl-redirect`
  - Note: `group.name` and `certificate-arn` are configured in
  IngressClassParams, not in Ingress annotations
- **ALB Naming**: Separate configuration for:
  - `alb_group_name`: Kubernetes identifier (max 63 characters)
  - `alb_load_balancer_name`: AWS resource name (max 32 characters)
- **Certificate Management**: ACM certificate ARN configured once in
IngressClassParams and inherited by all Ingresses
- **Single ALB**: All Ingresses (OpenLDAP web UIs + 2FA app) share the same ALB
via `group.name` in IngressClassParams with host-based routing
- **Routing**:
  - `phpldapadmin.<domain>` → phpLDAPadmin service
  - `passwd.<domain>` → LTB-passwd service
  - `app.<domain>/` → 2FA frontend service
  - `app.<domain>/api/*` → 2FA backend service

## Security Best Practices

- Always run Snyk security scans for new first-party code in supported languages
- Fix security issues found by Snyk before committing
- Rescan after fixes to ensure issues are resolved
- Repeat until no new issues are found
- Never commit OpenLDAP passwords to version control - always use environment
variables or GitHub Secrets
- **Container Security**:
  - Frontend container runs as non-root user (`appuser`, UID 1000) for improved
  security
  - Backend container uses multi-stage builds with minimal attack surface
  - Both containers follow principle of least privilege
  - No privileged ports required (frontend uses port 8080 internally)
- **IRSA (IAM Roles for Service Accounts)**:
  - Pods assume IAM roles via OIDC—no long-lived AWS credentials
  - IAM roles scoped to specific service accounts and namespaces
  - Required for SMS 2FA (SNS access)
- **VPC Endpoints**:
  - AWS service access (SSM, STS, SNS) goes through private endpoints—no public
  internet exposure
  - STS endpoint required for IRSA
  - SNS endpoint required for SMS 2FA
- **Network Policies**:
  - Pod-to-pod communication restricted to encrypted ports (443, 636, 8443)
  - Cross-namespace access enabled only for LDAP service on secure ports
- EBS volumes are encrypted by default
- LDAP service is ClusterIP only (not exposed externally)
- ALB uses HTTPS with ACM certificates (TLS 1.2/1.3 only)
- 2FA application uses constant-time comparison for code verification
- SMS codes expire after configurable timeout (default: 5 minutes)
- Phone numbers validated in E.164 format
- Phone numbers masked in API responses and logs
