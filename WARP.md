# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This repository deploys LDAP authentication with 2FA on Kubernetes (EKS Auto Mode) using Terraform. The infrastructure is deployed on AWS and consists of three main layers:

1. **Terraform Backend State** (`tf_backend_state/`) - S3 bucket for storing Terraform state files
2. **Backend Infrastructure** (`backend_infra/`) - Core AWS infrastructure (VPC, EKS cluster, networking, EBS storage, ECR)
3. **Application Layer** (`application/`) - OpenLDAP stack deployment with Helm, using existing Route53 zone and ACM certificate

## Architecture

### Three-Phased Deployment Model

- **Phase 1**: Deploy Terraform backend state infrastructure first (prerequisite for all other deployments)
- **Phase 2**: Deploy backend infrastructure (VPC, EKS, networking, EBS, ECR) using the remote state backend
- **Phase 3**: Deploy application layer (OpenLDAP Helm chart, Route53 DNS records, network policies) on top of the EKS cluster

### Infrastructure Components

- **VPC**: Custom VPC with public/private subnets across 2 availability zones
- **EKS Auto Mode**: Simplified cluster management with automatic node provisioning and built-in EBS CSI driver (Kubernetes 1.34)
- **Networking**: Single NAT gateway (cost optimization), IGW, VPC endpoints for SSM access
- **Storage**: StorageClass created in application layer (gp3, encrypted), PVCs created by Helm chart
- **Container Registry**: ECR repository for Docker images with lifecycle policies (immutable tags)
- **DNS & Certificates**: Uses existing Route53 hosted zone and validated ACM certificate (via data sources)
- **Load Balancer**: AWS ALB automatically created via Ingress resources for exposing OpenLDAP web UIs (phpLdapAdmin and LTB-passwd)
- **IngressClass/IngressClassParams**: Created by ALB module to configure EKS Auto Mode ALB behavior (scheme, IP address type)
- **Network Policies**: Kubernetes NetworkPolicies for secure internal cluster communication
- **OpenLDAP Image**: osixia/openldap:1.5.0 (overriding chart's default bitnami image which doesn't exist)

### Naming Convention

All resources follow the pattern: `${prefix}-${region}-${name}-${env}`

### Workspace Strategy

Terraform workspaces are named: `${region}-${env}` (e.g., `us-east-1-prod`, `us-east-2-dev`)

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

# If previously run via GitHub Actions, download state first:
aws s3 cp s3://<bucket_name>/<prefix> ./terraform.tfstate

terraform init
terraform plan -var-file="variables.tfvars" -out terraform.tfplan
terraform apply -auto-approve terraform.tfplan
```

### Backend Infrastructure Setup

**Configure Backend (Required before first run):**

```bash
cd backend_infra

# Option 1: Using GitHub CLI (requires gh and jq)
./setup-backend.sh

# Option 2: Using GitHub API with token
export GITHUB_TOKEN=your_github_token
./setup-backend-api.sh
```

**Deploy Backend Infrastructure:**

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

**Set Environment Variables (Required):**

```bash
# Create .env file with passwords
cat > application/.env << EOF
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
EOF

# Source environment variables
source application/.env
```

**Deploy OpenLDAP Application:**

```bash
cd application

# Configure backend (same as backend_infra)
./setup-backend.sh

# Initialize and select workspace
terraform init -backend-config="backend.hcl"
terraform workspace select us-east-1-prod || terraform workspace new us-east-1-prod

# Deploy application
terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"
terraform apply -auto-approve "terraform.tfplan"
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

- `tf_backend_state/variables.tfvars` - Configure `env`, `region`, `prefix`, `principal_arn`
- `tf_backend_state/README.md` - Detailed setup instructions for GitHub secrets/variables

### Backend Infrastructure Layer

- `backend_infra/variables.tfvars` - Configure VPC CIDR, K8s version (1.34), resource names, ECR lifecycle policies
- `backend_infra/backend.hcl` - Generated file (do not commit) with S3 backend config
- `backend_infra/tfstate-backend-values-template.hcl` - Template for backend.hcl
- `backend_infra/modules/` - Reusable modules for ECR and VPC endpoints (EBS module commented out)
- `backend_infra/main.tf` - Creates VPC, EKS cluster with Auto Mode, VPC endpoints, ECR

### Application Layer

- `application/variables.tfvars` - Configure domain name, ALB settings, storage class (passwords via .env file)
- `application/helm/openldap-values.tpl.yaml` - Helm chart values template with osixia/openldap:1.5.0 image and Ingress annotations
- `application/providers.tf` - Retrieves cluster name from backend_infra remote state (with fallback options)
- `application/main.tf` - Creates StorageClass, Helm release, Route53 records, network policies, and ALB module
- `application/modules/alb/` - Creates IngressClass and IngressClassParams for EKS Auto Mode ALB
- `application/modules/cert-manager/` - cert-manager module for self-signed TLS certificates (optional)
- `application/modules/network-policies/` - Network policies for secure internal cluster communication
- `application/PRD.md` - Detailed product requirements and implementation guide
- `application/README.md` - Comprehensive application layer documentation
- `application/.env` - Local file for OpenLDAP passwords (not committed to git)

## Important Patterns

### Terraform State Management

- **Never commit** `backend.hcl` or `terraform.tfstate` files (in `.gitignore`)
- Always use remote state backend after initial provisioning
- Use workspace naming convention: `${region}-${env}`
- State is stored in S3 with file-based locking (no DynamoDB table needed)

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
- ALB creation driven by Kubernetes Ingress with annotations (no separate AWS ALB resource)

### Helm Chart Integration

- OpenLDAP chart version: 4.0.1 from `https://jp-gouin.github.io/helm-openldap`
- Uses osixia/openldap:1.5.0 Docker image (chart's default bitnami image doesn't exist)
- Two web UIs exposed via ALB: phpLdapAdmin and LTB-passwd
- LDAP service itself remains ClusterIP (internal only)
- ALB configuration split between IngressClassParams (scheme, ipAddressType) and per-Ingress annotations (target-type, TLS, ports)
- Both Ingress resources use the same ALB with host-based routing via `alb.ingress.kubernetes.io/group.name` and `group.order` annotations
- Hostnames configurable via variables: `phpldapadmin_host` (default: `phpldapadmin.talorlik.com`) and `ltb_passwd_host` (default: `passwd.talorlik.com`)
- IngressClass created by ALB module references the IngressClassParams for cluster-wide ALB configuration

**CRITICAL: OpenLDAP Environment Variables**
- The jp-gouin/helm-openldap chart does NOT properly pass `global.ldapDomain` to the osixia/openldap container
- Must explicitly set these in the `env:` section of Helm values:
  - `LDAP_DOMAIN`: The LDAP domain (e.g., "ldap.talorlik.internal")
  - `LDAP_ADMIN_PASSWORD`: Admin password
  - `LDAP_CONFIG_PASSWORD`: Config password
- Without `LDAP_DOMAIN`, OpenLDAP initializes with empty/default config and authentication fails
- If authentication fails after deployment, delete PVCs and restart pods to reinitialize with correct environment variables

### Resource Deployment Order

Deployment order matters:

1. Terraform backend state infrastructure (S3 bucket)
2. Backend infrastructure (VPC → EKS → VPC Endpoints → ECR)
3. Application layer (Existing Route53 zone + ACM cert lookup → StorageClass → ALB module → Helm release → Route53 A records → Network policies)

### Module Structure

- `backend_infra/modules/` - Reusable infrastructure modules (ecr, endpoints)
  - `ecr/` - ECR repository with lifecycle policies
  - `endpoints/` - VPC endpoints for SSM access
- `application/modules/` - Application-specific modules (alb, cert-manager, network-policies)
  - `alb/` - IngressClass and IngressClassParams for EKS Auto Mode ALB
  - `cert-manager/` - Optional cert-manager for self-signed TLS certificates
  - `network-policies/` - Kubernetes NetworkPolicies for secure communication
- Each module has its own README.md with detailed documentation
- Route53 and ACM certificate resources use data sources to reference existing resources

## GitHub Actions Workflows

### Available Workflows

- `tfstate_infra_provisioning.yaml` - Create Terraform backend state
- `tfstate_infra_destroying.yaml` - Destroy Terraform backend state
- `backend_infra_provisioning.yaml` - Create backend infrastructure
- `backend_infra_destroying.yaml` - Destroy backend infrastructure
- `application_infra_provisioning.yaml` - Deploy OpenLDAP application
- `application_infra_destroying.yaml` - Destroy OpenLDAP application

### Required GitHub Secrets

- `AWS_ACCESS_KEY_ID` - AWS access key for API calls
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key
- `GH_TOKEN` - GitHub PAT with `repo` scope (for updating repository variables)
- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password (for application workflows)
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP config password (for application workflows)

### Required GitHub Variables

- `AWS_REGION` - AWS region for deployment
- `BACKEND_PREFIX` - S3 prefix for backend state files
- `BACKEND_BUCKET_NAME` - Auto-generated by backend state provisioning workflow
- `APPLICATION_PREFIX` - S3 prefix for application state files

## Development Workflow

### Making Infrastructure Changes

1. Update `variables.tfvars` with desired changes
2. For application layer, ensure passwords are set via environment variables (see Configuration section)
3. Run `terraform plan` to review changes
4. Apply changes with `terraform apply`
5. For multi-region deployments, switch workspaces and repeat

### Adding New Kubernetes Resources

1. Add resources to `application/main.tf` or create a new module in `application/modules/`
2. Update Helm values template if needed (`application/helm/openldap-values.tpl.yaml`)
3. Ensure proper `depends_on` relationships (e.g., Helm release, data sources)
4. Plan and apply changes
5. For Ingress changes, ALB will be automatically updated via Kubernetes controller

### Troubleshooting

- **PVC stuck in Pending**: Normal until a pod uses it (EBS Auto Mode behavior with WaitForFirstConsumer)
- **Terraform workspace issues**: Ensure workspace exists before selecting (format: `region-env`, e.g. `us-east-1-prod`)
- **Backend config errors**: Re-run `setup-backend.sh` to regenerate `backend.hcl`
- **SSM access denied**: Check VPC endpoint security groups and IAM policies
- **Cluster name not found**: Ensure backend_infra is deployed first and `backend.hcl` is configured correctly, or provide `cluster_name` in variables.tfvars
- **OpenLDAP password errors**: Verify passwords are set via environment variables (`TF_VAR_OPENLDAP_ADMIN_PASSWORD`, `TF_VAR_OPENLDAP_CONFIG_PASSWORD`)
- **ALB not created**: Check Ingress resources have proper annotations, ACM certificate is validated, and IngressClass/IngressClassParams exist
- **Route53 DNS not resolving**: Ensure Route53 A records point to ALB DNS name and NS records are configured at registrar
- **IngressClass not found**: Ensure ALB module is deployed (via `use_alb = true` variable)

**OpenLDAP Authentication Issues (Error 49: Invalid Credentials)**

1. **Root Cause**: OpenLDAP was initialized without proper `LDAP_DOMAIN` environment variable
   - Symptoms: `ldap_bind: Invalid credentials (49)` even with correct password
   - The jp-gouin chart's `global.ldapDomain` doesn't pass through to osixia/openldap container
   - Must explicitly set `LDAP_DOMAIN`, `LDAP_ADMIN_PASSWORD`, and `LDAP_CONFIG_PASSWORD` in `env:` section

2. **Fix**: Delete PVCs to force re-initialization with correct environment variables:
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

**ALB Ingress Group Issues (Multiple ALBs Created)**

1. **Root Cause**: AWS Load Balancer Controller creates separate ALBs when multiple Ingresses with same `group.name` are created simultaneously
   - Symptoms: Each Ingress shows different ALB address; one returns 404 while other works
   - Example: `phpldapadmin` on `k8s-ldap-openldap-xxx` and `passwd` on `talo-tf-us-east-1-talo-ldap-prod-xxx`

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

**Route53 Record State Issues**

1. **Root Cause**: Route53 records reference `local.alb_dns_name` which is empty when Ingresses don't exist
   - Symptoms: Terraform validation error "expected length of alias.0.name to be in the range (1 - 1024), got"

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

- **Internal LDAP TLS**: osixia/openldap auto-generates self-signed certificates on first startup
  - Environment variables: `LDAP_TLS: "true"`, `LDAP_TLS_ENFORCE: "false"`, `LDAP_TLS_VERIFY_CLIENT: "never"`
  - Filenames: `LDAP_TLS_CRT_FILENAME: "ldap.crt"`, `LDAP_TLS_KEY_FILENAME: "ldap.key"`, `LDAP_TLS_CA_CRT_FILENAME: "ca.crt"`
- **ALB TLS**: ACM certificate terminates TLS at ALB for public access
- **cert-manager Module**: Optional module for managing custom certificates (currently exists but not actively used)

### Storage Configuration

- **StorageClass**: Created by application Terraform (`kubernetes_storage_class_v1` resource)
  - Name pattern: `${prefix}-${region}-${storage_class_name}-${env}` (e.g., `talo-tf-us-east-1-gp3-ldap-prod`)
  - Provisioner: `ebs.csi.eks.amazonaws.com` (built-in to EKS Auto Mode)
  - Volume binding mode: `WaitForFirstConsumer` (PVCs stay Pending until pod is scheduled)
  - Type: `gp3` (configurable via `storage_class_type` variable)
  - Encryption: Enabled by default (configurable via `storage_class_encrypted` variable)
- **PVC**: Created by Helm chart using the StorageClass
  - Size: 8Gi (configurable in Helm values)
  - Access mode: ReadWriteOnce
  - Replication: 3 replicas, each with its own PVC

### ALB Configuration

- **IngressClassParams** (cluster-wide): Sets `scheme` and `ipAddressType` for all ALBs using the IngressClass
- **Per-Ingress annotations**: Control `target-type`, TLS settings, listen ports, SSL policy
- **IngressGroup**: Both Ingresses use same `group.name` and different `group.order` values to share one ALB
- **Load Balancer Name**: Only set on the lowest `group.order` Ingress (ltb-passwd, order 10)
- **TLS Annotations**: Present on both Ingresses for compatibility across AWS Load Balancer Controller versions

## Security Best Practices

- Always run Snyk security scans for new first-party code in supported languages
- Fix security issues found by Snyk before committing
- Rescan after fixes to ensure issues are resolved
- Repeat until no new issues are found
- Never commit OpenLDAP passwords to version control - always use environment variables or GitHub Secrets
- EBS volumes are encrypted by default
- LDAP service is ClusterIP only (not exposed externally)
- ALB uses HTTPS with ACM certificates (TLS 1.2/1.3 only)
