# Application Infrastructure

This Terraform configuration deploys the OpenLDAP stack with PhpLdapAdmin and LTB-passwd UIs on the EKS cluster created by the backend infrastructure.

## Overview

The application infrastructure provisions:

- **Route53 Hosted Zone** for domain management
- **ACM Certificate** with DNS validation for HTTPS
- **Helm Release** for OpenLDAP Stack HA (High Availability)
- **Application Load Balancer (ALB)** via EKS Auto Mode Ingress
- **Persistent Storage** using EBS-backed PVCs
- **Internet-Facing ALB** for UI access from the internet

## Architecture

```ascii
┌─────────────────────────────────────────────────────────┐
│                    EKS Cluster                          │
│                                                         │
│  ┌──────────────────────────────────────────────┐       │
│  │            LDAP Namespace                    │       │
│  │                                              │       │
│  │  ┌──────────────┐  ┌──────────────────┐      │       │
│  │  │ OpenLDAP     │  │ PhpLdapAdmin     │      │       │
│  │  │ StatefulSet  │  │ Deployment       │      │       │
│  │  │              │  │                  │      │       │
│  │  │ ClusterIP    │  │ Ingress (ALB)    │      │       │
│  │  │ (Internal)   │  │ (Internet)       │      │       │
│  │  └──────────────┘  └──────────────────┘      │       │
│  │                                              │       │
│  │  ┌──────────────────┐                        │       │
│  │  │ LTB-passwd       │                        │       │
│  │  │ Deployment       │                        │       │
│  │  │                  │                        │       │
│  │  │ Ingress (ALB)    │                        │       │
│  │  └──────────────────┘                        │       │
│  │                                              │       │
│  │  ┌──────────────┐                            │       │
│  │  │ EBS PVC      │                            │       │
│  │  │ (8Gi)        │                            │       │
│  │  └──────────────┘                            │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
└─────────────────────────────────────────────────────────┘
         │
         │
    ┌────▼──────────────────────┐
    │  Internet-Facing ALB      │
    │  (HTTPS)                  │
    │  - phpldapadmin.domain    │
    │  - passwd.domain          │
    └───────────────────────────┘
         │
         │
    ┌────▼────────┐
    │  Internet   │
    │  Access     │
    └─────────────┘
```

## Components

### 1. Route53 Hosted Zone and ACM Certificate

> **Note**: The Route53 module (`modules/route53/`) exists but is currently **commented out** in `main.tf`. The code uses **data sources** to reference existing Route53 hosted zone and ACM certificate resources that must already exist.

**Current Implementation (Data Sources):**

The code references existing resources using data sources:

- **Route53 Hosted Zone**: Must already exist (referenced via `data.aws_route53_zone`)
- **ACM Certificate**: Must already exist and be validated (referenced via `data.aws_acm_certificate`)
- The certificate must be in the same region as the EKS cluster

**Prerequisites:**

- Route53 hosted zone must be created beforehand (manually or via another Terraform configuration)
- ACM certificate must be created and validated beforehand
- Certificate must be in `ISSUED` status

**Outputs:**

Outputs come from data sources (not module outputs):

- `route53_acm_cert_arn`: ACM certificate ARN from data source (used by ALB)
- `route53_domain_name`: Root domain name from variable
- `route53_zone_id`: Route53 hosted zone ID from data source
- `route53_name_servers`: Route53 name servers from data source (for registrar configuration)

**Alternative Approach:**

If you want to create Route53 zone and ACM certificate via Terraform, uncomment the Route53 module in `main.tf` (lines 43-53) and update the code to use module outputs instead of data sources.

### 2. OpenLDAP Stack HA Helm Release

Deploys the complete OpenLDAP stack using the [helm-openldap](https://github.com/jp-gouin/helm-openldap) Helm chart:

- **OpenLDAP StatefulSet**: Core LDAP server with EBS-backed persistent storage
- **PhpLdapAdmin**: Web-based LDAP administration interface
- **LTB-passwd**: Self-service password management UI
- **Internal LDAP Service**: ClusterIP service (not exposed externally)

**Key Configuration:**

- Chart: `openldap-stack-ha` version `4.0.1`
- Repository: `https://jp-gouin.github.io/helm-openldap`
- Namespace: `ldap` (created automatically)
- Storage: Creates a new PVC using a StorageClass created by this Terraform configuration (see Storage Configuration section below)
- LDAP Ports: Standard ports (389 for LDAP, 636 for LDAPS)

### 3. Application Load Balancer (ALB)

The ALB is automatically provisioned by EKS Auto Mode when Ingress resources are created with the appropriate annotations:

- **Internet-Facing ALB**: Accessible from the internet (`scheme: internet-facing`)
- **HTTPS Only**: TLS termination at ALB using ACM certificate
- **Target Type**: IP mode (direct pod targeting)
- **Two Hostnames**: Single ALB handles both PhpLdapAdmin and LTB-passwd via host-based routing

**ALB Configuration:**

- Created via Kubernetes Ingress resources using EKS Auto Mode (not AWS Load Balancer Controller)
- No manual AWS `aws_lb` resource required (handled by EKS Auto Mode)
- `elastic_load_balancing` capability is **enabled by default** when EKS Auto Mode is enabled (configured in backend_infra via `compute_config.enabled = true`)
- Uses `eks.amazonaws.com/alb` controller (built into EKS Auto Mode)

**ALB Module:**

The `modules/alb/` module creates:

- `IngressClass` resource configured for EKS Auto Mode (`controller: eks.amazonaws.com/alb`)
- `IngressClassParams` resource with cluster-wide ALB defaults:
  - `scheme`: internet-facing or internal
  - `ipAddressType`: ipv4 or dualstack
  - `group.name`: ALB group name for grouping multiple Ingresses (max 63 characters)
  - `certificateARNs`: ACM certificate ARNs for TLS termination
- Note: EKS Auto Mode IngressClassParams supports `scheme`, `ipAddressType`, `group.name`, and `certificateARNs` (not subnets, security groups, or tags)

**ALB Naming:**

The configuration supports separate naming for:

- **ALB Group Name**: Kubernetes identifier (max 63 characters) - used to group multiple Ingresses
- **ALB Load Balancer Name**: AWS resource name (max 32 characters) - appears in AWS console

Both names are automatically constructed from prefix, region, and environment, with proper truncation to respect limits.

**Ingress Annotation Strategy:**

- IngressClassParams (cluster-wide) contains:
  - `scheme`: internet-facing or internal
  - `ipAddressType`: ipv4 or dualstack
  - `group.name`: ALB group name for grouping multiple Ingresses
  - `certificateARNs`: ACM certificate ARNs for TLS termination
- Ingress annotations (per-Ingress) contain:
  - `load-balancer-name`: AWS ALB name (max 32 characters)
  - `target-type`: IP or instance
  - `listen-ports`: HTTP/HTTPS ports
  - `ssl-redirect`: HTTPS redirect
- Note: `group.name` and `certificate-arn` are configured in IngressClassParams, not in Ingress annotations

The actual ALB is created automatically by EKS Auto Mode when the Helm chart creates Ingress resources that reference the IngressClass.

### 4. Storage Configuration

Creates a StorageClass and the Helm chart creates a new PVC using that StorageClass:

- **StorageClass**: Created by this Terraform configuration (`kubernetes_storage_class_v1` resource)
  - Name: `${prefix}-${region}-${storage_class_name}-${env}`
  - Provisioner: `ebs.csi.eks.amazonaws.com`
  - Volume binding mode: `WaitForFirstConsumer`
  - Encryption: Configurable via `storage_class_encrypted` variable
  - Volume type: Configurable via `storage_class_type` variable (gp2, gp3, io1, io2, etc.)
  - Can be set as default StorageClass via `storage_class_is_default` variable
- **PVC**: Created by the Helm chart using the StorageClass
  - **Storage Size**: 8Gi (configurable in Helm values)
  - **Access Mode**: ReadWriteOnce
  - The Helm chart creates a new PVC, it does not reuse an existing PVC from backend infrastructure

### 5. Network Policies

The `modules/network-policies/` module creates Kubernetes Network Policies to secure internal cluster communication:

- **Namespace-wide Policy**: Applies to all pods in the `ldap` namespace
- **Secure Ports Only**: Allows communication only on encrypted ports (443, 636, 8443)
- **DNS Resolution**: Allows DNS queries for service discovery
- **External Access**: Allows HTTPS/HTTP egress for external API calls (2FA providers, etc.)
- **Implicit Deny**: All other ports are implicitly denied by default

This ensures that even if a pod is compromised, it can only communicate on secure, encrypted ports within the cluster.

## Module Structure

```bash
application/
├── main.tf                    # Main application configuration
├── variables.tf               # Variable definitions
├── variables.tfvars          # Variable values (customize for your environment)
├── outputs.tf                # Output values
├── providers.tf              # Provider configuration (AWS, Kubernetes, Helm)
├── helm/
│   └── openldap-values.tpl.yaml  # Helm values template
├── modules/
│   ├── route53/              # Route53 hosted zone and ACM certificate module (currently commented out)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/                  # ALB module - creates IngressClass and IngressClassParams for EKS Auto Mode
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── network-policies/     # Network Policies module - secures pod-to-pod communication
│       ├── main.tf
│       ├── variables.tf
│       └── README.md
└── README.md                 # This file
```

## Prerequisites

1. **Backend Infrastructure**: The backend infrastructure must be deployed first (see [backend_infra/README.md](../backend_infra/README.md))
2. **EKS Cluster**: The EKS cluster must be running with Auto Mode enabled
3. **Route53 Hosted Zone**: Must already exist (the Route53 module is commented out, code uses data sources)
4. **ACM Certificate**: Must already exist and be validated in the same region as the EKS cluster
5. **Domain Registration**: The domain name must be registered (can be with any registrar)
6. **DNS Configuration**: After deployment, point your domain registrar's NS records to the Route53 name servers (output from data source)
7. **Environment Variables**: OpenLDAP passwords must be set via environment variables (see Configuration section)

## Configuration

### Required Variables

#### Core Variables

- `env`: Deployment environment (prod, dev)
- `region`: AWS region (must match backend infrastructure)
- `prefix`: Prefix for resource names (must match backend infrastructure)
- `cluster_name`: **Automatically retrieved** from backend_infra remote state (see Cluster Name section below)

#### Cluster Name Injection

The cluster name is automatically retrieved using a fallback chain:

1. **First**: Attempts to retrieve from `backend_infra` Terraform remote state (if `backend.hcl` exists)
2. **Second**: Uses `cluster_name` variable if provided in `variables.tfvars`
3. **Third**: Calculates cluster name using pattern: `${prefix}-${region}-${cluster_name_component}-${env}`

The backend configuration (bucket, key, region) is read from `backend.hcl` (created by `setup-backend.sh`).

If `backend.hcl` doesn't exist or remote state is not available, you can provide the cluster name directly in `variables.tfvars`:

```hcl
cluster_name = "talo-tf-us-east-1-kc-prod"
```

#### OpenLDAP Passwords (Environment Variables)

**IMPORTANT**: Passwords must be set via environment variables, NOT in `variables.tfvars`.

**Local Development (.env file):**

Create a `.env` file in the `application` directory:

```bash
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
```

Then source it before running Terraform:

```bash
source .env
terraform plan -var-file="variables.tfvars"
```

**GitHub Actions:**

Set these as GitHub Secrets:

- `TF_VAR_OPENLDAP_ADMIN_PASSWORD`
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD`

Then in your workflow, export them as Terraform variables:

```yaml
env:
  TF_VAR_OPENLDAP_ADMIN_PASSWORD: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
  TF_VAR_OPENLDAP_CONFIG_PASSWORD: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
```

#### Route53 and Domain Variables

- `domain_name`: Root domain name for Route53 hosted zone and ACM certificate (e.g., `talorlik.com`)
  - The Route53 hosted zone and ACM certificate must already exist (code uses data sources)
  - The ACM certificate should cover the domain and any subdomains you plan to use

**Note**: Hostnames for PhpLdapAdmin and LTB-passwd can be configured via variables or are automatically derived:

- PhpLdapAdmin: `phpldapadmin.${domain_name}` (or set `phpldapadmin_host` variable)
- LTB-passwd: `passwd.${domain_name}` (or set `ltb_passwd_host` variable)

#### Other OpenLDAP Variables

- `openldap_ldap_domain`: LDAP domain (e.g., `ldap.talorlik.internal`)

#### ALB Variables

- `use_alb`: Whether to create ALB resources (default: `true`)
- `ingressclass_alb_name`: Name component for ingress class (required if `use_alb` is true)
- `ingressclassparams_alb_name`: Name component for ingress class params (required if `use_alb` is true)
- `alb_group_name`: ALB group name for grouping multiple Ingresses (optional, defaults to `app_name`)
  - Kubernetes identifier (max 63 characters)
  - Used to group multiple Ingresses to share a single ALB
  - Configured in IngressClassParams (cluster-wide)
- `alb_load_balancer_name`: Custom AWS ALB name (optional, defaults to `alb_group_name` truncated to 32 chars)
  - AWS resource name (max 32 characters per AWS constraints)
  - Appears in AWS console
  - Configured in Ingress annotations (per-Ingress)
- `alb_scheme`: ALB scheme - `internet-facing` or `internal` (default: `internet-facing`)
- `alb_ip_address_type`: ALB IP address type - `ipv4` or `dualstack` (default: `ipv4`)
- `alb_target_type`: ALB target type - `ip` or `instance` (default: `ip`)
- `alb_ssl_policy`: ALB SSL policy for HTTPS listeners (default: `ELBSecurityPolicy-TLS13-1-2-2021-06`)
- `phpldapadmin_host`: Hostname for PhpLdapAdmin ingress (optional, defaults to `phpldapadmin.${domain_name}`)
- `ltb_passwd_host`: Hostname for LTB-passwd ingress (optional, defaults to `passwd.${domain_name}`)

#### Storage Variables

- `storage_class_name`: Name component for the StorageClass (e.g., `gp3-ldap`)
- `storage_class_type`: EBS volume type (gp2, gp3, io1, io2, etc.)
- `storage_class_encrypted`: Whether to encrypt EBS volumes (default: `true`)
- `storage_class_is_default`: Whether to mark StorageClass as default (default: `false`)

### Example Configuration

**variables.tfvars:**

```hcl
env                         = "prod"
region                      = "us-east-1"
prefix                      = "talo-tf"

# Cluster name from remote state
backend_bucket = "talo-tf-395323424870-s3-tfstate"
backend_key    = "backend_state/terraform.tfstate"

# OpenLDAP Configuration
# Passwords set via environment variables (see above)
openldap_ldap_domain        = "ldap.talorlik.internal"

# Route53 and Domain Configuration
domain_name                 = "talorlik.com"
# Note: Route53 zone and ACM certificate must already exist
# The ACM certificate should cover the domain and wildcard subdomains (*.talorlik.com)
```

**.env file (local development):**

```bash
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
```

## Deployment

### Step 1: Configure Variables

1. Update `variables.tfvars` with your values:
   - Configure LDAP domain
   - Set domain name (must match existing Route53 hosted zone)
   - Ensure ACM certificate exists and covers your domain/subdomains

2. **Set passwords via environment variables:**

   **Local Development:**

   ```bash
   # Create .env file
   cat > .env << EOF
   export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
   export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
   EOF

   # Source it
   source .env
   ```

   **GitHub Actions:**

   - Add `TF_VAR_OPENLDAP_ADMIN_PASSWORD` and `TF_VAR_OPENLDAP_CONFIG_PASSWORD` as GitHub Secrets
   - Export them in your workflow as `TF_VAR_*` environment variables

### Step 2: Set Up Environment Variables

**Local Development:**

```bash
cd application

# Create .env file with passwords
cat > .env << EOF
export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
EOF

# Source the environment variables
source .env
```

**GitHub Actions:**

Ensure your workflow exports the secrets as Terraform variables:

```yaml
env:
  TF_VAR_OPENLDAP_ADMIN_PASSWORD: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
  TF_VAR_OPENLDAP_CONFIG_PASSWORD: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
```

### Step 3: Set Up Backend Configuration

#### Option 1: Using GitHub CLI (Recommended)

```bash
cd application
./setup-backend.sh
```

This script will:

- Prompt you to select an AWS region (us-east-1 or us-east-2)
- Prompt you to select an environment (prod or dev)
- Retrieve repository variables from GitHub
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the actual values
- Update `variables.tfvars` with the selected region and environment

#### Option 2: Using GitHub API Directly

If you don't have GitHub CLI installed:

```bash
cd application
export GITHUB_TOKEN=your_token
./setup-backend-api.sh
```

You can create a GitHub token at: <https://github.com/settings/tokens>
Required scope: `repo` (for private repos) or `public_repo` (for public repos)

> **Note:** The generated `backend.hcl` file is automatically ignored by git (see `.gitignore`). Only the placeholder template (`tfstate-backend-values-template.hcl`) is committed to the repository.

### Step 4: Initialize Terraform

```bash
cd application

terraform init -backend-config="backend.hcl"
```

### Step 5: Select Workspace

```bash
# Workspace name should match backend infrastructure
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>
```

### Step 6: Plan and Apply

```bash
terraform plan -var-file="variables.tfvars" -out="terraform.tfplan"

terraform apply "terraform.tfplan"
```

### Step 7: Configure Domain Registrar

After deployment, configure your domain registrar to use the Route53 name servers:

```bash
# Get Route53 name servers
terraform output -json | jq -r '.route53_name_servers.value'

# Or view in AWS Console: Route53 > Hosted zones > Your domain > NS record
```

Update your domain registrar's NS records to point to these Route53 name servers.

### Step 8: Verify Deployment

```bash
# Check Helm release status
helm list -n ldap

# Check OpenLDAP pods
kubectl get pods -n ldap

# Check Ingress resources
kubectl get ingress -n ldap

# Check ALB status (via AWS CLI)
aws elbv2 describe-load-balancers --region us-east-1

# Check Route53 hosted zone
aws route53 list-hosted-zones --query "HostedZones[?Name=='talorlik.com.']"

# Check ACM certificate status
aws acm list-certificates --region us-east-1
```

## Accessing the Services

### PhpLdapAdmin

- **URL**: `https://phpldapadmin.${domain_name}` (e.g., `https://phpldapadmin.talorlik.com`)
- **Access**: Internet-facing (via internet-facing ALB)
- **Login**: Use OpenLDAP admin credentials
- **Note**: Ensure DNS is properly configured at your registrar

### LTB-passwd

- **URL**: `https://passwd.${domain_name}` (e.g., `https://passwd.talorlik.com`)
- **Access**: Internet-facing (via internet-facing ALB)
- **Purpose**: Self-service password management for LDAP users
- **Note**: Ensure DNS is properly configured at your registrar

### LDAP Service

- **Access**: Cluster-internal only (ClusterIP service)
- **Port**: 389 (LDAP), 636 (LDAPS)
- **Not Exposed**: LDAP ports are not accessible outside the cluster

## Security Considerations

1. **Internet-Facing ALB**: Both UIs are accessible from the internet via a single ALB with host-based routing (ensure proper security measures are in place)
2. **HTTPS Only**: TLS termination at ALB with ACM certificate (automatically validated via Route53)
3. **LDAP Internal**: LDAP service is ClusterIP only, not exposed externally
4. **Sensitive Variables**: Passwords are marked as sensitive in Terraform and must be set via environment variables, never in `variables.tfvars`
5. **Encrypted Storage**: EBS volumes are encrypted by default (configurable via `storage_class_encrypted`)
6. **Network Isolation**: Services run in private subnets
7. **Network Policies**: Kubernetes Network Policies restrict pod-to-pod communication to secure ports only (443, 636, 8443)
8. **Password Injection**: Passwords are injected at runtime via environment variables or GitHub Secrets, ensuring they never appear in version control
9. **DNS Validation**: ACM certificate uses DNS validation via Route53, ensuring secure certificate provisioning
10. **EKS Auto Mode Security**: IAM permissions are automatically handled by EKS Auto Mode (no manual policy attachment required)

## Customization

### Modifying Helm Values

Edit `helm/openldap-values.tpl.yaml` to customize:

- LDAP ports
- Storage size
- Image tags
- Environment variables
- Ingress annotations

After modifying the template, run `terraform plan` and `terraform apply`.

### Using Secrets Instead of Plain Text

To use Kubernetes secrets instead of plain text passwords:

1. Create a Kubernetes secret with keys `LDAP_ADMIN_PASSWORD` and `LDAP_CONFIG_ADMIN_PASSWORD`
2. Update the Helm values template to use `global.existingSecret`
3. Remove `adminPassword` and `configPassword` from the template

Example:

```yaml
global:
  existingSecret: "openldap-secrets"
  # Remove adminPassword and configPassword
```

## Troubleshooting

### Common Issues

1. **Helm Release Fails**
   - Verify EKS cluster is accessible: `kubectl get nodes`
   - Check Helm repository is accessible: `helm repo list`
   - Verify PVC exists: `kubectl get pvc -n ldap`

2. **ALB Not Created**
   - Ensure EKS Auto Mode has `elastic_load_balancing.enabled = true`
   - Check Ingress annotations are correct
   - Verify ACM certificate validation completed (check Route53 validation records)
   - Ensure certificate is in the same region as the EKS cluster

3. **PVC Not Found**
   - Verify PVC name matches exactly (case-sensitive)
   - Check PVC exists: `kubectl get pvc -A`
   - Ensure PVC is in the same namespace or update namespace in Helm values

4. **Cannot Access UIs**
   - Verify ALB is created: `aws elbv2 describe-load-balancers`
   - Check DNS resolution: `dig phpldapadmin.${domain_name}` or `nslookup phpldapadmin.${domain_name}`
   - Verify domain registrar NS records point to Route53 name servers
   - Verify security groups allow HTTPS traffic
   - Check Ingress status: `kubectl describe ingress -n ldap`
   - Verify ACM certificate is validated: `aws acm describe-certificate --certificate-arn <arn>`

### Useful Commands

```bash
# View Helm release values
helm get values openldap-stack-ha -n ldap

# Check OpenLDAP logs
kubectl logs -n ldap -l app=openldap

# Check PhpLdapAdmin logs
kubectl logs -n ldap -l app=phpldapadmin

# Check LTB-passwd logs
kubectl logs -n ldap -l app=ltb-passwd

# View Ingress details
kubectl describe ingress -n ldap

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Test LDAP connectivity (from within cluster)
kubectl run -it --rm ldap-test --image=osixia/openldap --restart=Never -- bash
ldapsearch -x -H ldap://openldap-stack-ha:389 -b "dc=corp,dc=internal"
```

## Outputs

The application provides outputs for:

- `alb_dns_name`: DNS name of the ALB (extracted from Ingress resources created by Helm chart)
  - Empty string if ALB is still provisioning or not created
  - Retrieved from either phpldapadmin or ltb-passwd Ingress status
- `route53_acm_cert_arn`: ACM certificate ARN (from data source, not module)
- `route53_domain_name`: Root domain name (from variable)
- `route53_zone_id`: Route53 hosted zone ID (from data source)
- `route53_name_servers`: Route53 name servers (from data source, for registrar configuration)

View all outputs:

```bash
terraform output
```

**Important**: After deployment, update your domain registrar's NS records to point to the Route53 name servers shown in the `route53_name_servers` output.

## References

- [Helm OpenLDAP Chart](https://github.com/jp-gouin/helm-openldap)
- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode.html)
- [EKS Auto Mode IngressClassParams](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode-ingress.html)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [OpenLDAP Documentation](https://www.openldap.org/doc/)
- [PhpLdapAdmin Documentation](https://www.phpldapadmin.org/)
- [LTB-passwd Documentation](https://ltb-project.org/documentation/self-service-password)

## Architecture Notes

### Route53 A Records

The Terraform configuration automatically creates Route53 A (alias) records for the subdomains:

- `phpldapadmin.${domain_name}` → ALB DNS name
- `passwd.${domain_name}` → ALB DNS name

These records are created after the Helm release and Ingress resources are provisioned, ensuring the ALB DNS name is available.

### Internet-Facing ALB Configuration

The ALB is configured as `internet-facing` to enable:

- Access to UIs from anywhere on the internet
- Public accessibility for user convenience
- HTTPS-only access for secure communication
- Proper DNS configuration required for public access

### Why ClusterIP for LDAP?

The LDAP service uses ClusterIP (not LoadBalancer or NodePort) to:

- Keep LDAP ports strictly internal to the cluster
- Prevent external access to LDAP
- Only allow access from pods within the cluster
- Follow security best practices for sensitive services

### EKS Auto Mode Benefits

Using EKS Auto Mode provides:

- Automatic ALB provisioning via Ingress annotations
- No need to manually install or configure AWS Load Balancer Controller
- Simplified IAM permissions (handled automatically by EKS)
- Built-in EBS CSI driver (no manual installation needed)
- IngressClassParams support for cluster-wide ALB defaults (scheme, ipAddressType)
- Direct integration with EKS cluster (no separate controller pods)

### Network Policies

The Network Policies module enforces security at the pod level:

- **Secure Ports Only**: Pods can only communicate on encrypted ports (443, 636, 8443)
- **Namespace Isolation**: Policies apply to all pods in the `ldap` namespace
- **DNS Required**: DNS resolution is allowed for service discovery
- **External Access**: HTTPS/HTTP egress is allowed for external API calls
- **Default Deny**: All other ports are implicitly denied

This provides defense-in-depth security, ensuring that even if a pod is compromised, it can only communicate on secure, encrypted ports.
