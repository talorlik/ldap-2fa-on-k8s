# ldap-2fa-on-k8s

LDAP authentication with 2FA deployed on K8S

## Prerequisites

- AWS Account
- GitHub Account
- Fork the repository: [ldap-2fa-on-k8s](https://github.com/talorlik/ldap-2fa-on-k8s.git)
- Set your own AWS KEY and SECRET (see the workflow yaml for the correct names for your secrets)

## Terraform Deployment

1. Deploy the Terraform backend state infrastructure by running the `tfstate_infra_provisioning.yaml` workflow via the GitHub UI

   > [!INFO]
   > 📖 **For detailed setup instructions**, including required GitHub Secrets, Variables, and configuration, see the [Terraform Backend State README](tf_backend_state/README.md).

   > [!IMPORTANT]
   > Make sure to alter the values in the variables.tfvars according to your setup and to commit and push them.

2. Deploy the main backend infrastructure

   > [!INFO]
   > 📖 **For detailed information about the backend infrastructure**, including architecture, components, and module documentation, see the [Backend Infrastructure README](backend_infra/README.md).

### Local Development Setup

Before running Terraform locally, you need to generate the `backend.hcl` file and update `variables.tfvars` with your selected region and environment. The repository includes `tfstate-backend-values-template.hcl` as a template showing what values need to be configured.

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

### Running Terraform

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
