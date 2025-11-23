# ldap-2fa-on-k8s

LDAP authentication with 2FA deployed on K8S

## Prerequisites

- AWS Account
- GitHub Account
- Fork the repository: https://github.com/talorlik/ldap-2fa-on-k8s.git
- Set your own AWS KEY and SECRET (see the workflow yaml for the correct names for your secrets)

## Terraform Deployment

1. Deploy the Terraform backend state infrastructure by running the `tfstate_infra_provisioning.yaml` workflow via the GitHub UI

   > 📖 **For detailed setup instructions**, including required GitHub Secrets, Variables, and configuration, see the [Terraform Backend State README](tf_backend_state/README.md).

> [!IMPORTANT] Make sure to alter the values in the variables.tfvars according to your setup and to commit and push them.

### Prod

```bash
terraform init

terraform workspace select us-east-1-prod || terraform workspace new us-east-1-prod

terraform plan -var-file="region.us-east-1.prod.tfvars" -out "region.us-east-1.prod.tfplan"

# To destroy all the resources that were created
terraform plan -var-file="region.us-east-1.prod.tfvars" -destroy -out "region.us-east-1.prod.tfplan"

terraform apply -auto-approve "region.us-east-1.prod.tfplan"
```
