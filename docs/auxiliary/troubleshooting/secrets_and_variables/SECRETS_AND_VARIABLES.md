# Secrets and Terraform Variables Troubleshooting

This document covers issues with AWS Secrets Manager, GitHub Secrets,
Terraform variables, and PostgreSQL password flow.

## AWS Secrets Manager (Local Scripts)

**Problem:** Local scripts cannot retrieve secrets from AWS Secrets Manager.

**Common issues and solutions:**

- **Secret doesn't exist:** Ensure secret named `github-role` or `tf-vars`
  exists in AWS Secrets Manager.
- **Access denied:** Your AWS credentials must have
  `secretsmanager:GetSecretValue` permission for the secrets.
- **Key not found:** Ensure the secret JSON contains the required keys.
- **Invalid JSON:** Verify the secret value is valid JSON format.
- **Wrong region:** Ensure your AWS CLI is configured to the correct region
  where the secrets exist.

**Verification:**

```bash
# Test secret retrieval manually
aws secretsmanager get-secret-value --secret-id github-role \
  --query SecretString --output text | jq .
aws secretsmanager get-secret-value --secret-id tf-vars \
  --query SecretString --output text | jq .
```

## GitHub Secrets

**Problem:** GitHub Actions workflows cannot access secrets.

**Common issues and solutions:**

- **Secret not configured:** Ensure all required secrets are set in
  Repository Settings → Secrets and variables → Actions → Secrets.
- **Wrong secret name:** Verify secret names match exactly (case-sensitive).
- **Insufficient permissions:** Ensure the workflow has access to
  repository secrets.
- **Secret not available in workflow:** Check that secrets are referenced
  correctly in workflow YAML.

## Case Sensitivity (Terraform Variables)

**Problem:** Terraform variables not recognized.

**Solution:** Ensure environment variables use lowercase to match
`variables.tf`:

- Secret: `TF_VAR_OPENLDAP_ADMIN_PASSWORD` (uppercase in GitHub/AWS).
- Environment variable: `TF_VAR_openldap_admin_password` (lowercase for
  Terraform).

## PostgreSQL Password / TF_VAR Issues

### "Variable not set" error

**Solution:** Verify environment variable is exported:

```bash
env | grep TF_VAR_postgresql_database_password
```

### "Failed to retrieve secret from AWS Secrets Manager"

**Solution:**

1. Check AWS credentials are configured.
2. Verify secret exists:
   `aws secretsmanager describe-secret --secret-id tf-vars`.
3. Check IAM permissions for Secrets Manager access.

### "Failed to retrieve TF_VAR_POSTGRESQL_PASSWORD from secret"

**Solution:**

1. Verify key exists in JSON:
   `aws secretsmanager get-secret-value --secret-id tf-vars | jq .`
2. Check key name matches exactly (case-sensitive).
3. Verify JSON is valid format.

### Terraform variable not found

**Solution:**

1. Verify environment variable name matches Terraform variable name exactly.
2. Check case sensitivity: `TF_VAR_postgresql_database_password`
   (lowercase).
3. Ensure variable is exported before running `terraform plan/apply`.

## Related Documentation

- [Troubleshooting Index](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/INDEX.md)
- [Terraform State and Backend](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/secrets_and_variables/TERRAFORM_STATE.md)
- [SECRETS_REQUIREMENTS](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/reference/SECRETS_REQUIREMENTS.md)
  - Full secrets requirements
- [PASSWORD_FLOW](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/PASSWORD_FLOW.md)
  - PostgreSQL password flow
