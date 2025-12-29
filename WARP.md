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
3. **Application Layer** (`application/`) - OpenLDAP stack, 2FA application
(backend + frontend), ArgoCD, SNS for SMS 2FA, using existing Route53 zone and
ACM certificate (Account B - Deployment Account)

**Multi-Account Architecture:**

- **Account A (State Account)**: Stores Terraform state files in S3
- **Account B (Deployment Accounts)**: Contains all infrastructure resources
  - **Production Account**: Separate account for production infrastructure
  - **Development Account**: Separate account for development infrastructure
- GitHub Actions uses OIDC to assume Account A role for backend state operations
- Terraform provider assumes Account B role (prod or dev) via `assume_role` for
resource deployment
- Environment-based role selection: workflows and scripts automatically select
the appropriate deployment role ARN based on the selected environment (`prod` or
`dev`)

## Architecture

### Three-Phased Deployment Model

- **Phase 1**: Deploy Terraform backend state infrastructure first (prerequisite
for all other deployments)
- **Phase 2**: Deploy backend infrastructure (VPC, EKS, networking, EBS, ECR)
using the remote state backend
- **Phase 3**: Deploy application layer (OpenLDAP Helm chart, Route53 DNS
records, network policies) on top of the EKS cluster

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
policies (immutable tags)
- **DNS & Certificates**: Uses existing Route53 hosted zone and validated ACM
certificate (via data sources)
- **Load Balancer**: AWS ALB automatically created via Ingress resources for
exposing web UIs (phpLdapAdmin, LTB-passwd, and 2FA application)
- **IngressClass/IngressClassParams**: Created by ALB module to configure EKS
Auto Mode ALB behavior (scheme, IP address type, certificate ARN, group name)
- **Network Policies**: Kubernetes NetworkPolicies for secure internal cluster
communication with cross-namespace access for LDAP service
- **OpenLDAP Image**: osixia/openldap:1.5.0 (overriding chart's default bitnami
image which doesn't exist)
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

```text
ldap-2fa-on-k8s/
├── SECRETS_REQUIREMENTS.md     # Secrets management documentation (root)
├── tf_backend_state/           # Terraform state backend (S3) - Account A
├── backend_infra/              # Core AWS infrastructure - Account B
│   └── modules/
│       ├── ebs/                # EBS storage (commented out)
│       ├── ecr/                # Container registry
│       └── endpoints/          # VPC endpoints (SSM, STS, SNS)
├── application/                # Application infrastructure - Account B
│   ├── backend/                # 2FA Backend (Python FastAPI)
│   │   ├── src/                # Source code
│   │   ├── helm/               # Helm chart
│   │   └── Dockerfile
│   ├── frontend/               # 2FA Frontend (HTML/JS/CSS)
│   │   ├── src/                # Source code
│   │   ├── helm/               # Helm chart
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   ├── helm/                   # Helm values templates (OpenLDAP, Redis)
│   └── modules/                # Terraform modules
│       ├── alb/                # IngressClass and IngressClassParams
│       ├── argocd/             # ArgoCD capability (AWS managed)
│       ├── argocd_app/         # ArgoCD Application CRD
│       ├── cert-manager/       # TLS certificate management
│       ├── network-policies/   # Kubernetes NetworkPolicies
│       ├── openldap/           # OpenLDAP Stack HA deployment module (NEW)
│       ├── postgresql/         # PostgreSQL database (Bitnami Helm)
│       ├── redis/              # Redis cache for SMS OTP
│       ├── route53/            # Route53 hosted zone (commented out)
│       ├── ses/                # SES for email verification
│       └── sns/                # SNS for SMS 2FA
├── .github/workflows/          # CI/CD workflows
│   ├── tfstate_infra_*.yaml
│   ├── backend_infra_*.yaml
│   ├── application_infra_*.yaml
│   ├── backend_build_push.yaml
│   └── frontend_build_push.yaml
└── docs/                       # GitHub Pages documentation
    └── index.html              # Project documentation website
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
- Assume the IAM role with temporary credentials
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
terraform plan -var-file="variables.tfvars" -destroy -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
```

### Application Layer Deployment

**Prerequisites:**
Ensure you have:

- A registered domain name (e.g., `talorlik.com`)
- An existing Route53 hosted zone for your domain
- A validated ACM certificate for your domain
- **For local backend state scripts**: AWS Secrets Manager secret named `github-role`
with JSON containing `AWS_STATE_ACCOUNT_ROLE_ARN` (see tf_backend_state/README.md)

**Deploy OpenLDAP Application:**

```bash
cd application

# For local use: Export passwords as environment variables (script retrieves from GitHub secrets if available)
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"

# Deploy application (handles all configuration and Terraform operations automatically)
./setup-application.sh
```

This script will:

- Prompt for region and environment selection
- Retrieve AWS_STATE_ACCOUNT_ROLE_ARN and assume it for backend operations
- Retrieve environment-specific deployment role ARN (prod or dev)
- Retrieve OpenLDAP password secrets from repository secrets and export them as
environment variables
- Create backend.hcl from template if it doesn't exist
- Update variables.tfvars with selected values
- Set Kubernetes environment variables using set-k8s-env.sh
- Run all Terraform commands automatically (init, workspace, validate, plan,
apply)

> [!NOTE]
>
> The script automatically retrieves OpenLDAP passwords from GitHub
> repository secrets. For local use, you need to export them as environment
> variables since GitHub CLI cannot read secret values directly.

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

**Push Docker image to ECR:**

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr_url>

# Tag and push image
docker tag <image>:<tag> <ecr_url>:<tag>
docker push <ecr_url>:<tag>
```

## Key Configuration Files

### Backend State

- `tf_backend_state/variables.tfvars` - Configure `env`, `region`, `prefix`
(principal_arn is optional and auto-detected)
- `tf_backend_state/README.md` - Detailed setup instructions for GitHub
secrets/variables and AWS Secrets Manager configuration
- `tf_backend_state/set-state.sh` - Automated provisioning and state upload script
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

### Application Layer

- `application/variables.tfvars` - Configure:
  - Domain name, ALB settings, storage class
  - ArgoCD configuration (enable_argocd, Identity Center settings)
  - SNS/SMS 2FA configuration (enable_sms_2fa)
  - Passwords retrieved automatically by setup-application.sh from AWS Secrets Manager
- `application/setup-application.sh` - Unified setup script for application
deployment (retrieves secrets from AWS Secrets Manager)
- `application/set-k8s-env.sh` - Kubernetes environment variable configuration
- `application/helm/openldap-values.tpl.yaml` - Helm chart values template with
osixia/openldap:1.5.0 image (used by OpenLDAP module)
- `application/helm/redis-values.tpl.yaml` - Redis Helm chart values template
- `application/providers.tf` - Retrieves cluster name from backend_infra remote
state (with fallback options)
- `application/main.tf` - Creates:
  - StorageClass for persistent storage
  - OpenLDAP module invocation (Helm release, secrets, Ingress, Route53 records)
  - 2FA backend Helm release (if ArgoCD not used)
  - 2FA frontend Helm release (if ArgoCD not used)
  - Route53 records for 2FA app subdomain
  - ALB module (IngressClass and IngressClassParams)
  - Network policies
  - PostgreSQL module (with Kubernetes secrets)
  - Redis module (with Kubernetes secrets)
  - SES module
  - SNS module (if SMS 2FA enabled)
  - ArgoCD capability (if enabled)
  - ArgoCD Applications (if enabled)
- `application/modules/` - Terraform modules:
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `argocd/` - AWS EKS managed ArgoCD capability
  - `argocd_app/` - ArgoCD Application CRD for GitOps
  - `cert-manager/` - TLS certificate management (optional)
  - `network-policies/` - Kubernetes NetworkPolicies with cross-namespace access
  - `openldap/` - OpenLDAP Stack HA deployment with secrets, Ingress, and Route53
  - `postgresql/` - PostgreSQL database with Kubernetes secrets
  - `redis/` - Redis cache with Kubernetes secrets for SMS OTP storage
  - `route53/` - Route53 hosted zone creation (commented out, uses data sources)
  - `ses/` - AWS SES for email verification and notifications
  - `sns/` - SNS resources for SMS 2FA with IRSA
- `SECRETS_REQUIREMENTS.md` - Comprehensive secrets management documentation
  - AWS Secrets Manager setup for local scripts
  - GitHub Repository Secrets setup for workflows
  - Secret naming conventions and case sensitivity
- `application/backend/` - 2FA backend application:
  - `src/` - Python FastAPI source code
  - `helm/` - Helm chart with Ingress for `/api/*`
  - `Dockerfile` - Container image definition
- `application/frontend/` - 2FA frontend application:
  - `src/` - Static HTML/JS/CSS files
  - `helm/` - Helm chart with Ingress for `/`
  - `Dockerfile` - Container image definition (nginx)
  - `nginx.conf` - nginx configuration
- `application/CHANGELOG.md` - Detailed changelog documenting all application
changes
- `application/PRD-2FA-APP.md` - Product requirements document for 2FA
application
- `application/PRD-SIGNUP-MAN.md` - Product requirements document for signup
management system
- `application/PRD-ALB.md` - Comprehensive ALB implementation guide
- `application/OPENLDAP-README.md` - OpenLDAP configuration and TLS setup
- `application/OSIXIA-OPENLDAP-REQUIREMENTS.md` - OpenLDAP image requirements
- `application/SECURITY-IMPROVEMENTS.md` - Security enhancements and best
practices

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
- Uses osixia/openldap:1.5.0 Docker image (chart's default bitnami image doesn't
exist)
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
  - PostgreSQL for user registration and profile data (with Kubernetes secrets)
  - Redis for SMS OTP code caching (with Kubernetes secrets)
  - AWS SES for email verification and notifications (via IRSA)
  - AWS SNS for SMS verification codes (via IRSA)
  - Exposed at `/api/*` path on `app.<domain>`
  - Uses IRSA for SNS, SES access (no hardcoded credentials)
  - Swagger UI always enabled at `/api/docs` for interactive API documentation
  - Helm chart includes: Deployment, Service, Ingress, ConfigMap, Secret,
  ServiceAccount
- Frontend: Static HTML/JS/CSS served by nginx
  - Signup form with email/phone verification
  - Admin dashboard (visible to admin group members)
  - User profile page
  - Top navigation bar with user menu
  - Exposed at `/` path on `app.<domain>`
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

### CRITICAL: OpenLDAP Environment Variables**

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
3. Application layer (Existing Route53 zone + ACM cert lookup → StorageClass →
ALB module → Helm release → Route53 A records → Network policies)

### Module Structure

- `backend_infra/modules/` - Reusable infrastructure modules:
  - `ecr/` - ECR repository with lifecycle policies
  - `endpoints/` - VPC endpoints for SSM, STS (IRSA), and SNS (SMS 2FA)
  - `ebs/` - EBS storage (commented out in main.tf)
- `application/modules/` - Application-specific modules:
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `argocd/` - AWS EKS managed ArgoCD capability for GitOps
  - `argocd_app/` - ArgoCD Application CRD for GitOps deployments
  - `cert-manager/` - Optional cert-manager for self-signed TLS certificates
  - `network-policies/` - Kubernetes NetworkPolicies for secure communication
  with cross-namespace access
  - `openldap/` - **NEW**: OpenLDAP Stack HA deployment with multi-master replication,
  Kubernetes secrets, phpLDAPadmin, ltb-passwd, Ingress, and Route53 DNS records
  - `postgresql/` - PostgreSQL database with Kubernetes secrets for user data
  - `redis/` - Redis cache with Kubernetes secrets for SMS OTP storage with TTL
  - `route53/` - Route53 hosted zone creation (exists but commented out, uses
  data sources)
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
(OpenLDAP, 2FA app, ArgoCD, SNS)
- `application_infra_destroying.yaml` - Destroy application infrastructure

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
- `APPLICATION_PREFIX` - S3 prefix for application state files

## Recent Changes (December 2024 - January 2025)

### Security Enhancements and Code Scanning Fixes (December 28, 2024)

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

### Kubernetes Secrets Integration and OpenLDAP Module (December 27-28, 2024)

- **OpenLDAP Module (`application/modules/openldap/`)**: NEW
  - Modularized OpenLDAP Stack HA deployment with comprehensive configuration
  - Includes phpLDAPadmin and ltb-passwd web interfaces
  - Manages Kubernetes secrets for OpenLDAP passwords
  - Handles Helm release deployment with templated values
  - Creates Route53 DNS records for web UIs
  - Creates ALB Ingress resources for public access
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

### AWS Secrets Manager Integration for Local Scripts (December 27, 2024)

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

## Recent Changes (December 2024)

### Admin Functions and User Profile Management (December 18, 2024)

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

### User Signup Management System (December 18, 2024)

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

### Redis SMS OTP Storage (December 18, 2024)

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

### PostgreSQL and SES Integration (December 18, 2024)

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

### 2FA Application and SMS Integration (December 18, 2024 - Initial Release)

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

### ArgoCD GitOps Integration (December 16, 2024)

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

### Documentation and Linting Improvements (December 15, 2024)

- **Markdown lint compliance**:
  - Corrected row length issues across all documentation files
  - Added `.markdownlint.json` for consistent formatting
  - Updated all README files, CHANGELOGs, and PRD documents

### Deployment Versatility and Security Improvements (December 14, 2024)

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

## Earlier Changes (December 2024)

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
