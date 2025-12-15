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
EKS cluster, networking, EBS storage, ECR) (Account B - Deployment Account)
3. **Application Layer** (`application/`) - OpenLDAP stack deployment with Helm,
using existing Route53 zone and ACM certificate (Account B - Deployment Account)

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
- **Networking**: Single NAT gateway (cost optimization), IGW, VPC endpoints for
SSM access
- **Storage**: StorageClass created in application layer (gp3, encrypted), PVCs
created by Helm chart
- **Container Registry**: ECR repository for Docker images with lifecycle
policies (immutable tags)
- **DNS & Certificates**: Uses existing Route53 hosted zone and validated ACM
certificate (via data sources)
- **Load Balancer**: AWS ALB automatically created via Ingress resources for
exposing OpenLDAP web UIs (phpLdapAdmin and LTB-passwd)
- **IngressClass/IngressClassParams**: Created by ALB module to configure EKS
Auto Mode ALB behavior (scheme, IP address type)
- **Network Policies**: Kubernetes NetworkPolicies for secure internal cluster
communication
- **OpenLDAP Image**: osixia/openldap:1.5.0 (overriding chart's default bitnami
image which doesn't exist)

### Naming Convention

All resources follow the pattern: `${prefix}-${region}-${name}-${env}`

### Workspace Strategy

Terraform workspaces are named: `${region}-${env}` (e.g., `us-east-1-prod`,
`us-east-2-dev`)

## Common Commands

### Terraform Backend State Setup

**Initial Backend Provisioning (GitHub Actions - Recommended):**

```bash
# Run via GitHub UI: Actions → "TF Backend State Provisioning" workflow
# This automatically creates S3 bucket and saves state
```

**Local Backend Setup:**

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

> **Note**: The script automatically retrieves OpenLDAP passwords from GitHub
repository secrets. For local use, you need to export them as environment
variables since GitHub CLI cannot read secret values directly.

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
secrets/variables

### Backend Infrastructure Layer

- `backend_infra/variables.tfvars` - Configure VPC CIDR, K8s version (1.34),
resource names, ECR lifecycle policies
- `backend_infra/backend.hcl` - Generated file (do not commit) with S3 backend
config
- `backend_infra/tfstate-backend-values-template.hcl` - Template for backend.hcl
- `backend_infra/modules/` - Reusable modules for ECR and VPC endpoints (EBS
module commented out)
- `backend_infra/main.tf` - Creates VPC, EKS cluster with Auto Mode, VPC
endpoints, ECR

### Application Layer

- `application/variables.tfvars` - Configure domain name, ALB settings, storage
class (passwords retrieved automatically by setup-application.sh from GitHub
secrets)
- `application/helm/openldap-values.tpl.yaml` - Helm chart values template with
osixia/openldap:1.5.0 image and Ingress annotations
- `application/providers.tf` - Retrieves cluster name from backend_infra remote
state (with fallback options)
- `application/main.tf` - Creates StorageClass, Helm release, Route53 records,
network policies, and ALB module
- `application/modules/alb/` - Creates IngressClass and IngressClassParams for
EKS Auto Mode ALB with centralized certificate and group configuration
- `application/modules/cert-manager/` - cert-manager module for self-signed TLS
certificates (optional, not actively used)
- `application/modules/network-policies/` - Network policies for secure internal
cluster communication
- `application/.env` - Local file for OpenLDAP passwords (not committed to git)
- `application/CHANGELOG.md` - Detailed changelog documenting ALB annotation
strategy changes and TLS configuration updates
- `application/OSIXIA-OPENLDAP-REQUIREMENTS.md` - OpenLDAP image requirements
and environment variable documentation
- `application/PRD-ALB.md` - Comprehensive ALB implementation guide with EKS
Auto Mode vs AWS Load Balancer Controller comparison
- `application/README.md` - Comprehensive application layer documentation
- `application/.env` - Local file for OpenLDAP passwords (not committed to git)

## Outputs

### Backend Infrastructure Outputs

- **VPC**: `vpc_id`, `public_subnets`, `private_subnets`,
`default_security_group_id`, `igw_id`
- **EKS**: `cluster_name`, `cluster_endpoint`, `cluster_arn`
- **VPC Endpoints**: `vpc_endpoint_sg_id`, `vpc_endpoint_ssm_id`,
`vpc_endpoint_ssmmessages_id`, `vpc_endpoint_ec2messages_id`, `vpc_endpoint_ids`
- **ECR**: `ecr_name`, `ecr_arn`, `ecr_url`
- **General**: `aws_account`, `region`, `env`, `prefix`

### Application Infrastructure Outputs

- **ALB**: `alb_dns_name`, `alb_ingress_class_name`,
`alb_ingress_class_params_name`, `alb_scheme`, `alb_ip_address_type`
- **Route53**: `route53_acm_cert_arn`, `route53_domain_name`, `route53_zone_id`,
`route53_name_servers`
- **Network Policies**: `network_policy_name`, `network_policy_namespace`,
`network_policy_uid`

## Important Patterns

### Terraform State Management

- **Never commit** `backend.hcl` or `terraform.tfstate` files (in `.gitignore`)
- Always use remote state backend after initial provisioning
- Use workspace naming convention: `${region}-${env}`
- State is stored in S3 with file-based locking

### Security Considerations

- All EKS nodes are in private subnets (no public IPs)
- VPC endpoints enable SSM access without internet gateway
- EBS volumes are encrypted by default
- Secrets should use `sensitive = true` in Terraform variables
- OpenLDAP admin/config passwords should never be committed in plaintext

### EKS Auto Mode Specifics

- Built-in EBS CSI driver - no manual installation needed
- Automatic IAM permissions for CSI driver
- Compute config uses "general-purpose" node pool
- ALB creation driven by Kubernetes Ingress with annotations (no separate AWS
ALB resource)

### Helm Chart Integration

- OpenLDAP chart version: 4.0.1 from `https://jp-gouin.github.io/helm-openldap`
- Uses osixia/openldap:1.5.0 Docker image (chart's default bitnami image doesn't
exist)
- Two web UIs exposed via ALB: phpLdapAdmin and LTB-passwd
- LDAP service itself remains ClusterIP (internal only)
- ALB configuration uses EKS Auto Mode (`eks.amazonaws.com/alb` controller)
instead of AWS Load Balancer Controller
- IngressClassParams (cluster-wide) contains: `scheme`, `ipAddressType`,
`group.name`, and `certificateARNs`
- Ingress annotations (per-Ingress) contain: `load-balancer-name`,
`target-type`, `listen-ports`, `ssl-redirect`
- Both Ingress resources use the same ALB with host-based routing via shared
`group.name` in IngressClassParams
- Hostnames configurable via variables: `phpldapadmin_host` (default:
`phpldapadmin.talorlik.com`) and `ltb_passwd_host` (default:
`passwd.talorlik.com`)
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

- `backend_infra/modules/` - Reusable infrastructure modules (ecr, endpoints)
  - `ecr/` - ECR repository with lifecycle policies
  - `endpoints/` - VPC endpoints for SSM access
- `application/modules/` - Application-specific modules (alb, cert-manager,
network-policies)
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `cert-manager/` - Optional cert-manager for self-signed TLS certificates
  - `network-policies/` - Kubernetes NetworkPolicies for secure communication
- Each module has its own README.md with detailed documentation
- Route53 and ACM certificate resources use data sources to reference existing
resources

## GitHub Actions Workflows

### Available Workflows

- `tfstate_infra_provisioning.yaml` - Create Terraform backend state
- `tfstate_infra_destroying.yaml` - Destroy Terraform backend state
- `backend_infra_provisioning.yaml` - Create backend infrastructure
- `backend_infra_destroying.yaml` - Destroy backend infrastructure
- `application_infra_provisioning.yaml` - Deploy OpenLDAP application
- `application_infra_destroying.yaml` - Destroy OpenLDAP application

### Required GitHub Secrets

- `AWS_STATE_ACCOUNT_ROLE_ARN` - ARN of IAM role in Account A (State Account)
that trusts GitHub OIDC provider (used for all backend state operations)
- `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` - ARN of IAM role in Production Account
(Account B) that trusts Account A role (used when `prod` environment is
selected)
- `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` - ARN of IAM role in Development Account
(Account B) that trusts Account A role (used when `dev` environment is selected)
- `GH_TOKEN` - GitHub PAT with `repo` scope (for updating repository variables)
- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password (for application
workflows)
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP config password (for application
workflows)

> **Note**: This project uses AWS SSO via GitHub OIDC instead of access keys.
Workflows automatically select the appropriate deployment role ARN based on the
selected environment. See main [README.md](README.md) for detailed IAM setup
instructions.

### Required GitHub Variables

- `AWS_REGION` - AWS region for deployment
- `BACKEND_PREFIX` - S3 prefix for backend state files
- `BACKEND_BUCKET_NAME` - Auto-generated by backend state provisioning workflow
- `APPLICATION_PREFIX` - S3 prefix for application state files

## Recent Changes (December 2024)

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
- **Updated workflows**: All workflows now use `AWS_STATE_ACCOUNT_ROLE_ARN` for
backend operations and set `deployment_account_role_arn` variable based on
selected environment

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
6. Review `CHANGELOG.md` and `application/CHANGELOG.md` for recent changes and
verification steps

### Adding New Kubernetes Resources

1. Add resources to `application/main.tf` or create a new module in
`application/modules/`
2. Update Helm values template if needed
(`application/helm/openldap-values.tpl.yaml`)
3. Ensure proper `depends_on` relationships (e.g., Helm release, data sources)
4. Plan and apply changes
5. For Ingress changes, ALB will be automatically updated via Kubernetes
controller

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
- **Single ALB**: Both Ingresses share the same ALB via `group.name` in
IngressClassParams with host-based routing

## Security Best Practices

- Always run Snyk security scans for new first-party code in supported languages
- Fix security issues found by Snyk before committing
- Rescan after fixes to ensure issues are resolved
- Repeat until no new issues are found
- Never commit OpenLDAP passwords to version control - always use environment
variables or GitHub Secrets
- EBS volumes are encrypted by default
- LDAP service is ClusterIP only (not exposed externally)
- ALB uses HTTPS with ACM certificates (TLS 1.2/1.3 only)
