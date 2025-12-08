# ldap-2fa-on-k8s

LDAP authentication with 2FA deployed on Kubernetes (EKS)

This project deploys a complete LDAP authentication solution with self-service password management on Amazon EKS using Terraform. The infrastructure includes:

- **EKS Cluster** (Auto Mode) for running Kubernetes workloads
- **OpenLDAP Stack** with high availability and persistent storage
- **PhpLdapAdmin** web interface for LDAP administration
- **LTB-passwd** self-service password management UI
- **Application Load Balancer (ALB)** via EKS Auto Mode for internet-facing access
- **Route53 DNS** integration for domain management
- **ACM Certificates** for HTTPS/TLS termination

## Prerequisites

- AWS Account with appropriate permissions
- GitHub Account
- Fork the repository: [ldap-2fa-on-k8s](https://github.com/talorlik/ldap-2fa-on-k8s.git)
- Set your own AWS KEY and SECRET (see the workflow yaml for the correct names for your secrets)
- Route53 hosted zone must already exist (or create it manually)
- ACM certificate must already exist and be validated in the same region as the EKS cluster

## Project Structure

```text
ldap-2fa-on-k8s/
├── tf_backend_state/      # Terraform state backend infrastructure (S3)
├── backend_infra/         # Core AWS infrastructure (VPC, EKS cluster)
├── application/          # Application infrastructure (OpenLDAP, ALB, Route53)
└── .github/workflows/    # GitHub Actions workflows for CI/CD
```

## Terraform Deployment

The deployment follows a three-tier approach:

### 1. Deploy Terraform Backend State Infrastructure

Deploy the Terraform backend state infrastructure by running the `tfstate_infra_provisioning.yaml` workflow via the GitHub UI.

> [!INFO]
> 📖 **For detailed setup instructions**, including required GitHub Secrets, Variables, and configuration, see the [Terraform Backend State README](tf_backend_state/README.md).
>
> [!IMPORTANT]
> Make sure to alter the values in the variables.tfvars according to your setup and to commit and push them.

### 2. Deploy Backend Infrastructure

Deploy the main backend infrastructure (VPC, EKS cluster, VPC endpoints, EBS, ECR).

> [!INFO]
> 📖 **For detailed information about the backend infrastructure**, including architecture, components, and module documentation, see the [Backend Infrastructure README](backend_infra/README.md).

### 3. Deploy Application Infrastructure

Deploy the application infrastructure (OpenLDAP stack, ALB, Route53 records).

> [!INFO]
> 📖 **For detailed information about the application infrastructure**, including OpenLDAP configuration, ALB setup, and deployment steps, see the [Application Infrastructure README](application/README.md).

## Local Development Setup

Before running Terraform locally, you need to generate the `backend.hcl` file and update `variables.tfvars` with your selected region and environment. The repository includes `tfstate-backend-values-template.hcl` as a template showing what values need to be configured.

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
- Create `backend.hcl` from `tfstate-backend-values-template.hcl` with the actual values
- Update `variables.tfvars` with the selected region and environment

#### Option 2: Using GitHub API Directly

If you don't have GitHub CLI installed, you can use the API version:

```bash
cd backend_infra
export GITHUB_TOKEN=your_github_token
./setup-backend-api.sh
```

You can create a GitHub token at: <https://github.com/settings/tokens>
Required scope: `repo` (for private repos) or `public_repo` (for public repos)

> **Note:** The generated `backend.hcl` file is automatically ignored by git (see `.gitignore`). Only the placeholder template (`tfstate-backend-values-template.hcl`) is committed to the repository.

### Application Infrastructure Setup

The application infrastructure uses the same backend setup process:

```bash
cd application
./setup-backend.sh
# or
export GITHUB_TOKEN=your_github_token
./setup-backend-api.sh
```

**Important:** Before deploying the application infrastructure, you must:

1. Set OpenLDAP passwords via environment variables (never in `variables.tfvars`):

   ```bash
   export TF_VAR_OPENLDAP_ADMIN_PASSWORD="YourSecurePassword123!"
   export TF_VAR_OPENLDAP_CONFIG_PASSWORD="YourSecurePassword123!"
   ```

2. Ensure Route53 hosted zone exists for your domain
3. Ensure ACM certificate exists and is validated in the same region as your EKS cluster

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

After backend infrastructure is deployed and backend configuration is set up:

```bash
cd application

# Set passwords via environment variables
source .env  # or export TF_VAR_OPENLDAP_* variables

terraform init -backend-config="backend.hcl"

# Use the same workspace as backend infrastructure
terraform workspace select <region>-<environment> || terraform workspace new <region>-<environment>

terraform plan -var-file="variables.tfvars" -out "terraform.tfplan"

terraform apply -auto-approve "terraform.tfplan"
```

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

- **EKS Auto Mode**: Simplified cluster management with automatic load balancer provisioning
- **High Availability**: Multi-master OpenLDAP replication with persistent storage
- **Internet-Facing Access**: Secure HTTPS access to UIs via ALB
- **Self-Service Password Management**: LTB-passwd for user password resets
- **Automated DNS**: Route53 integration for seamless domain management
- **Secure by Default**: TLS termination, encrypted storage, network policies

## Accessing the Services

After deployment:

- **PhpLdapAdmin**: `https://phpldapadmin.${domain_name}` (e.g., `https://phpldapadmin.talorlik.com`)
- **LTB-passwd**: `https://passwd.${domain_name}` (e.g., `https://passwd.talorlik.com`)
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
- Network policies restrict pod-to-pod communication
- EKS nodes run in private subnets

## Troubleshooting

See the individual README files for troubleshooting guides:

- [Backend Infrastructure Troubleshooting](backend_infra/README.md#troubleshooting)
- [Application Infrastructure Troubleshooting](application/README.md#troubleshooting)

## License

See [LICENSE](LICENSE) file for details.
