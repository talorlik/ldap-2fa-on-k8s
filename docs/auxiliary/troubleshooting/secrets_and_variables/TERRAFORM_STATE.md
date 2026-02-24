# Terraform State and Backend Troubleshooting

This document covers issues with the Terraform remote state backend (S3)
and GitHub Actions OIDC used by `tf_backend_state` and workflows.

## "Resource not accessible by integration" error

- **Cause:** `GH_TOKEN` doesn't have proper permissions or doesn't exist.
- **Solution:** Create a PAT with `repo` scope and store it as `GH_TOKEN`
  secret.

## "Access Denied" when accessing S3

- **Cause:** The IAM principal doesn't have S3 permissions, or there's a
  mismatch between the caller and the bucket policy.
- **Solution:**
  - The bucket policy uses the current caller's ARN. Verify it matches:
    run `aws sts get-caller-identity` to see your current ARN.
  - Ensure the caller has S3 permissions for the state bucket.
  - For GitHub Actions: Verify the IAM role ARN in `AWS_STATE_ACCOUNT_ROLE_ARN`
    secret matches the assumed role.
  - Check that the OIDC trust relationship is correctly configured.

## OIDC Authentication Issues

- **Cause:** GitHub OIDC provider not configured correctly or role trust
  policy incorrect.
- **Solution:**
  - Verify OIDC Identity Provider exists in the state account.
  - Check role trust policy includes correct repository name.
  - Ensure `AWS_STATE_ACCOUNT_ROLE_ARN` secret contains the correct role ARN
    (for GitHub Actions).

## AWS Secrets Manager (for github-role secret)

- **Cause:** Local scripts cannot retrieve secret from AWS Secrets Manager.
- **Common issues:** Secret doesn't exist; access denied; key
  `AWS_STATE_ACCOUNT_ROLE_ARN` missing; invalid JSON; wrong region.
- **Verification:**

  ```bash
  aws secretsmanager get-secret-value --secret-id github-role \
    --query SecretString --output text | jq .
  ```

## Bucket name conflicts

- **Cause:** Another account is using the same prefix.
- **Solution:** Use a more unique prefix in `variables.tfvars`.

## State file not found during destroy

- **Cause:** The state file wasn't uploaded or the bucket name variable is
  incorrect.
- **Solution:** Verify `BACKEND_BUCKET_NAME` variable exists and contains
  the correct bucket name.

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Secrets and Variables](SECRETS_AND_VARIABLES.md)
- [tf_backend_state README](../../../tf_backend_state/README.md)
