# Secrets Requirements

This document consolidates all secrets-related information for the LDAP 2FA on
Kubernetes project. It covers both AWS Secrets Manager (for local scripts) and
GitHub Repository Secrets (for GitHub Actions workflows).

## Overview

The project uses secrets in two different contexts:

1. **AWS Secrets Manager** - Used by local bash scripts
(`setup-backend.sh`, `setup-application.sh`, `set-state.sh`, `get-state.sh`)
2. **GitHub Repository Secrets** - Used by GitHub Actions workflows

> [!NOTE]
>
> Local scripts retrieve secrets from **AWS Secrets Manager**, while GitHub Actions
> workflows use **GitHub Repository Secrets**. Both must be configured for the
> project to work in both contexts.

## Secret Categories

### 1. IAM Role ARNs

These are used for AWS authentication and role assumption:

- `AWS_STATE_ACCOUNT_ROLE_ARN` - Role for Terraform state backend operations and
  Route53/ACM cross-account access
- `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` - Role for production deployments
- `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` - Role for development deployments

### 1.1. ExternalId for Cross-Account Role Assumption

- `AWS_ASSUME_EXTERNAL_ID` - ExternalId for cross-account role assumption security
  - **Purpose:** Prevents confused deputy attacks when assuming deployment account
  roles
  - **Generation:** `openssl rand -hex 32`
  - **Storage:**
    - AWS Secrets Manager: Plain text secret named `external-id`
    - GitHub: Repository secret `AWS_ASSUME_EXTERNAL_ID`
  - **Requirement:** Must match the ExternalId configured in deployment account
  role Trust Relationships
  - **Used By:** `setup-backend.sh`, `setup-application.sh`, and all GitHub Actions
  workflows

### 2. Application Passwords

These are used for application infrastructure components:

- `TF_VAR_OPENLDAP_ADMIN_PASSWORD` - OpenLDAP admin password
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD` - OpenLDAP configuration password
- `TF_VAR_POSTGRESQL_PASSWORD` - PostgreSQL database password
- `TF_VAR_REDIS_PASSWORD` - Redis authentication password (minimum 8 characters)

### 3. GitHub Token

- `GH_TOKEN` - GitHub Personal Access Token with `repo` scope
(for repository variable updates)

## AWS Secrets Manager Configuration

Local bash scripts retrieve secrets from AWS Secrets Manager. Two separate secrets
are used:

### Secret 1: `github-role`

Contains IAM role ARNs for AWS authentication:

```json
{
  "AWS_STATE_ACCOUNT_ROLE_ARN": "arn:aws:iam::<state-account-id>:role/<role-name>",
  "AWS_PRODUCTION_ACCOUNT_ROLE_ARN": "arn:aws:iam::<prod-account-id>:role/<role-name>",
  "AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN": "arn:aws:iam::<dev-account-id>:role/<role-name>"
}
```

### Secret 2: `tf-vars`

Contains Terraform variable values (passwords):

```json
{
  "TF_VAR_OPENLDAP_ADMIN_PASSWORD": "<admin-password>",
  "TF_VAR_OPENLDAP_CONFIG_PASSWORD": "<config-password>",
  "TF_VAR_POSTGRESQL_PASSWORD": "<postgresql-password>",
  "TF_VAR_REDIS_PASSWORD": "<redis-password>"
}
```

### Secret 3: `external-id`

Contains ExternalId for cross-account role assumption (plain text, not JSON):

```text
<generated-external-id>
```

**Important:** This is a plain text secret, not JSON. Generate using:

```bash
openssl rand -hex 32
```

The same value must be:

- Stored in AWS Secrets Manager as `external-id` (plain text)
- Stored in GitHub repository secret `AWS_ASSUME_EXTERNAL_ID`
- Added to deployment account role Trust Relationships as a condition

### Creating AWS Secrets Manager Secrets

#### Create the `github-role` secret

```bash
aws secretsmanager create-secret \
  --name github-role \
  --secret-string '{
    "AWS_STATE_ACCOUNT_ROLE_ARN": "arn:aws:iam::123456789012:role/TerraformStateRole",
    "AWS_PRODUCTION_ACCOUNT_ROLE_ARN": "arn:aws:iam::987654321098:role/TerraformDeploymentRole",
    "AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN": "arn:aws:iam::111222333444:role/TerraformDeploymentRole"
  }' \
  --region us-east-1
```

Or update an existing secret:

```bash
aws secretsmanager update-secret \
  --secret-id github-role \
  --secret-string '{
    "AWS_STATE_ACCOUNT_ROLE_ARN": "arn:aws:iam::123456789012:role/TerraformStateRole",
    "AWS_PRODUCTION_ACCOUNT_ROLE_ARN": "arn:aws:iam::987654321098:role/TerraformDeploymentRole",
    "AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN": "arn:aws:iam::111222333444:role/TerraformDeploymentRole"
  }' \
  --region us-east-1
```

#### Create the `tf-vars` secret

```bash
aws secretsmanager create-secret \
  --name tf-vars \
  --secret-string '{
    "TF_VAR_OPENLDAP_ADMIN_PASSWORD": "YourAdminPasswordHere",
    "TF_VAR_OPENLDAP_CONFIG_PASSWORD": "YourConfigPasswordHere",
    "TF_VAR_POSTGRESQL_PASSWORD": "YourPostgreSQLPasswordHere",
    "TF_VAR_REDIS_PASSWORD": "YourRedisPasswordHere"
  }' \
  --region us-east-1
```

Or update an existing secret:

```bash
aws secretsmanager update-secret \
  --secret-id tf-vars \
  --secret-string '{
    "TF_VAR_OPENLDAP_ADMIN_PASSWORD": "YourAdminPasswordHere",
    "TF_VAR_OPENLDAP_CONFIG_PASSWORD": "YourConfigPasswordHere",
    "TF_VAR_POSTGRESQL_PASSWORD": "YourPostgreSQLPasswordHere",
    "TF_VAR_REDIS_PASSWORD": "YourRedisPasswordHere"
  }' \
  --region us-east-1
```

### Creating the `external-id` secret

```bash
# Generate ExternalId
EXTERNAL_ID=$(openssl rand -hex 32)
echo "Generated ExternalId: $EXTERNAL_ID"

# Create the secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name external-id \
  --secret-string "$EXTERNAL_ID" \
  --region us-east-1
```

Or update an existing secret:

```bash
aws secretsmanager update-secret \
  --secret-id external-id \
  --secret-string "$EXTERNAL_ID" \
  --region us-east-1
```

> [!IMPORTANT]
>
> The same ExternalId value must be:
>
> 1. Stored in AWS Secrets Manager as `external-id` (plain text)
> 2. Stored in GitHub repository secret `AWS_ASSUME_EXTERNAL_ID`
> 3. Added to deployment account role Trust Relationships as a condition:
>
>    ```json
>    {
>      "Condition": {
>        "StringEquals": {
>          "sts:ExternalId": "<generated-external-id>"
>        }
>      }
>    }
>    ```

> [!IMPORTANT]
>
> **Bidirectional Trust Relationships Required:**
>
> For multi-account setups, both trust relationships must be configured:
>
> 1. **Deployment Account Roles** must trust the State Account role (already
>    documented above) **with ExternalId condition**
> 2. **State Account Role** must also trust the Deployment Account roles in its
>    Trust Relationship
>
> **ExternalId Still Required**: The ExternalId security mechanism is still
> required when the state account role assumes deployment account roles. The
> ExternalId condition must be present in the deployment account roles' Trust
> Relationships, and the state account role must provide the ExternalId when
> assuming those roles. The ExternalId is retrieved from `AWS_ASSUME_EXTERNAL_ID`
> secret (for GitHub Actions) or AWS Secrets Manager (for local deployment).
>
> Update the state account role's (`github-actions-state-role`) Trust
> Relationship to include the deployment account role ARNs:
>
> ```json
> {
>   "Version": "2012-10-17",
>   "Statement": [
>     {
>       "Effect": "Allow",
>       "Principal": {
>         "Federated": "arn:aws:iam::STATE_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
>       },
>       "Action": "sts:AssumeRoleWithWebIdentity",
>       "Condition": {
>         "StringLike": {
>           "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
>         }
>       }
>     },
>     {
>       "Effect": "Allow",
>       "Principal": {
>         "AWS": [
>           "arn:aws:iam::PRODUCTION_ACCOUNT_ID:role/github-role",
>           "arn:aws:iam::DEVELOPMENT_ACCOUNT_ID:role/github-role",
>           "arn:aws:iam::STATE_ACCOUNT_ID:role/github-role"
>         ]
>       },
>       "Action": "sts:AssumeRole"
>     }
>   ]
> }
> ```
>
> Replace `PRODUCTION_ACCOUNT_ID` and `DEVELOPMENT_ACCOUNT_ID` with your actual
> account IDs, and `github-role` with your actual deployment role names.
>
> > [!IMPORTANT]
> >
> > **Self-Assumption Statement**: The last statement allows the role to assume
> itself. This is required when:
>
> - The State Account role is used for both backend state operations and
> Route53/ACM access (when `state_account_role_arn` points to the same role)
> - Terraform providers need to assume the same role that was already assumed
> by the initial authentication
> - You encounter errors like "User: arn:aws:sts::ACCOUNT_ID:assumed-role/github-role/SESSION
> is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::ACCOUNT_ID:role/github-role"

### IAM Permissions for AWS Secrets Manager

The AWS credentials used to run local scripts must have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:github-role-*",
        "arn:aws:secretsmanager:*:*:secret:tf-vars-*",
        "arn:aws:secretsmanager:*:*:secret:external-id-*"
      ]
    }
  ]
}
```

## GitHub Repository Secrets Configuration

GitHub Actions workflows use **repository secrets**, not AWS Secrets Manager.
Configure these at:
**Repository → Settings → Secrets and variables → Actions → Secrets**

### Required GitHub Repository Secrets

| Secret Name | Type | Description | Used By |
| ------------- | ------ | ------------- | --------- |
| `AWS_STATE_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for backend state operations (S3 bucket access) | All workflows |
| `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for production deployments | Workflows (when `prod` environment) |
| `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for development deployments | Workflows (when `dev` environment) |
| `AWS_ASSUME_EXTERNAL_ID` | ExternalId | ExternalId for cross-account role assumption security | All deployment workflows |
| `TF_VAR_OPENLDAP_ADMIN_PASSWORD` | Password | OpenLDAP admin password | Application deployment workflows |
| `TF_VAR_OPENLDAP_CONFIG_PASSWORD` | Password | OpenLDAP config password | Application deployment workflows |
| `TF_VAR_POSTGRESQL_PASSWORD` | Password | PostgreSQL database password | Application deployment workflows |
| `TF_VAR_REDIS_PASSWORD` | Password | Redis password for SMS OTP storage (minimum 8 characters) | Application deployment workflows |
| `GH_TOKEN` | GitHub PAT | GitHub Personal Access Token with `repo` scope | State backend provisioning workflow |

### Setting Up GitHub Repository Secrets

1. Navigate to your repository on GitHub
2. Go to **Settings → Secrets and variables → Actions → Secrets**
3. Click **New repository secret**
4. Enter the secret name and value
5. Click **Add secret**

### GitHub Token Setup

The `GH_TOKEN` secret is a GitHub Personal Access Token (PAT) with `repo` scope:

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens
(classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "Terraform Backend State")
4. Select scope: **`repo`** (Full control of private repositories)
5. Click "Generate token" and copy it immediately
6. Store it as a repository secret named `GH_TOKEN`

**Used for**: Creating/updating repository variables after state backend provisioning

## Secret Details

### IAM Role ARNs

#### AWS_STATE_ACCOUNT_ROLE_ARN

- **Type:** String (IAM Role ARN)
- **Description:** The ARN of the IAM role in the state account used for
  Terraform backend state operations (S3 bucket access) and Route53/ACM
  cross-account access
backend state operations (S3 bucket access for Terraform state)
- **Format:** `arn:aws:iam::<account-id>:role/<role-name>`
- **Example:** `arn:aws:iam::123456789012:role/TerraformStateRole`
- **Used By:**
  - `setup-backend.sh`
  - `setup-application.sh`
  - `set-state.sh`
  - `get-state.sh`
  - All GitHub Actions workflows
- **Trust Relationship Requirement:** For multi-account setups, the state account
role's Trust Relationship must include the deployment account role ARNs to enable
bidirectional trust. See the "Bidirectional Trust Relationships Required" section
above (in the ExternalId configuration) for configuration details.
- **Self-Assumption Requirement:** If the State Account role is used for both
backend state operations and Route53/ACM access (when `state_account_role_arn` points
to the same role), the trust policy must allow the role to assume itself. See the
"Bidirectional Trust Relationships Required" section above for the complete trust
policy example including the self-assumption statement.

#### AWS_PRODUCTION_ACCOUNT_ROLE_ARN

- **Type:** String (IAM Role ARN)
- **Description:** The ARN of the IAM role in the production deployment account
used for Terraform provider assume_role operations
- **Format:** `arn:aws:iam::<account-id>:role/<role-name>`
- **Example:** `arn:aws:iam::987654321098:role/TerraformDeploymentRole`
- **Used By:**
  - `setup-backend.sh` (when environment is "prod")
  - `setup-application.sh` (when environment is "prod")
  - GitHub Actions workflows (when `prod` environment is selected)

#### AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN

- **Type:** String (IAM Role ARN)
- **Description:** The ARN of the IAM role in the development deployment account
used for Terraform provider assume_role operations
- **Format:** `arn:aws:iam::<account-id>:role/<role-name>`
- **Example:** `arn:aws:iam::111222333444:role/TerraformDeploymentRole`
- **Used By:**
  - `setup-backend.sh` (when environment is "dev")
  - `setup-application.sh` (when environment is "dev")
  - GitHub Actions workflows (when `dev` environment is selected)

#### AWS_ASSUME_EXTERNAL_ID

- **Secret Location:**
  - AWS Secrets Manager: Plain text secret named `external-id`
  - GitHub: Repository secret `AWS_ASSUME_EXTERNAL_ID`
- **Type:** String (ExternalId)
- **Description:** ExternalId for cross-account role assumption security. Prevents
confused deputy attacks by ensuring only authorized callers can assume deployment
account roles. Must match the ExternalId configured in deployment account role Trust
Relationships.
- **Generation:** `openssl rand -hex 32`
- **Format:** Hexadecimal string (64 characters)
- **Example:** `a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456`
- **Used By:**
  - `setup-backend.sh` (retrieved from AWS Secrets Manager)
  - `setup-application.sh` (retrieved from AWS Secrets Manager)
  - All GitHub Actions workflows (retrieved from GitHub secrets)
- **Security Note:** This is a sensitive security credential and must be stored
securely. The same value must be configured in:
  1. AWS Secrets Manager as `external-id` (plain text)
  2. GitHub repository secret `AWS_ASSUME_EXTERNAL_ID`
  3. Deployment account role Trust Relationships (as a condition)

### Application Passwords

#### TF_VAR_OPENLDAP_ADMIN_PASSWORD

- **Secret Location:**
  - AWS Secrets Manager: `tf-vars` secret, key `TF_VAR_OPENLDAP_ADMIN_PASSWORD`
  - GitHub: Repository secret `TF_VAR_OPENLDAP_ADMIN_PASSWORD`
- **Type:** String (Password)
- **Description:** The admin password for OpenLDAP
- **Exported As:** `TF_VAR_openldap_admin_password` (lowercase) - Terraform automatically
recognizes `TF_VAR_` prefix
- **Format:** Plain text password string
- **Example:** `MySecureAdminPassword123!`
- **Used By:** `setup-application.sh` only
- **Security Note:** This is a sensitive value and should be stored securely

> [!IMPORTANT]
>
> The secret key in AWS/GitHub remains uppercase (`TF_VAR_OPENLDAP_ADMIN_PASSWORD`),
> but when exported as an environment variable, it must be lowercase (`TF_VAR_openldap_admin_password`)
> to match the variable name in `variables.tf`.

#### TF_VAR_OPENLDAP_CONFIG_PASSWORD

- **Secret Location:**
  - AWS Secrets Manager: `tf-vars` secret, key `TF_VAR_OPENLDAP_CONFIG_PASSWORD`
  - GitHub: Repository secret `TF_VAR_OPENLDAP_CONFIG_PASSWORD`
- **Type:** String (Password)
- **Description:** The configuration password for OpenLDAP (cn=config)
- **Exported As:** `TF_VAR_openldap_config_password` (lowercase)
- **Format:** Plain text password string
- **Example:** `MySecureConfigPassword456!`
- **Used By:** `setup-application.sh` only
- **Security Note:** This is a sensitive value and should be stored securely

#### TF_VAR_POSTGRESQL_PASSWORD

- **Secret Location:**
  - AWS Secrets Manager: `tf-vars` secret, key `TF_VAR_POSTGRESQL_PASSWORD`
  - GitHub: Repository secret `TF_VAR_POSTGRESQL_PASSWORD` (note: some docs may
  reference `TF_VAR_POSTGRES_PASSWORD`, but the correct name is `TF_VAR_POSTGRESQL_PASSWORD`)
- **Type:** String (Password)
- **Description:** The password for PostgreSQL database used for user management
and verification token storage
- **Exported As:** `TF_VAR_postgresql_database_password` (lowercase)
- **Format:** Plain text password string
- **Example:** `MySecurePostgreSQLPassword789!`
- **Used By:** `setup-application.sh` only
- **Security Note:** This is a sensitive value and should be stored securely

#### TF_VAR_REDIS_PASSWORD

- **Secret Location:**
  - AWS Secrets Manager: `tf-vars` secret, key `TF_VAR_REDIS_PASSWORD`
  - GitHub: Repository secret `TF_VAR_REDIS_PASSWORD`
- **Type:** String (Password)
- **Description:** The password for Redis used for SMS OTP code storage with
TTL-based expiration
- **Exported As:** `TF_VAR_redis_password` (lowercase)
- **Format:** Plain text password string (minimum 8 characters)
- **Example:** `MySecureRedisPassword012!`
- **Used By:** `setup-application.sh` only
- **Security Note:** This is a sensitive value and should be stored securely
- **Minimum Length:** 8 characters (Redis requirement)

## Implementation Notes

### Case Sensitivity

TF_VAR environment variables are case-sensitive and must match the variable names
defined in `variables.tf`.

- **Secret names in AWS/GitHub:** Remain uppercase (e.g., `TF_VAR_OPENLDAP_ADMIN_PASSWORD`)
- **Environment variables:** Must be lowercase (e.g., `TF_VAR_openldap_admin_password`)
to match Terraform variable names

### Secret Retrieval Strategy

1. **Three Secret Calls:** Local scripts retrieve secrets from three separate secrets
in AWS Secrets Manager:
   - `github-role` - Contains all IAM role ARNs (single call, JSON format)
   - `tf-vars` - Contains all Terraform variable values (single call, JSON format)
   - `external-id` - Contains ExternalId for cross-account role assumption
   (single call, plain text)
   This minimizes AWS CLI calls by fetching all required values from each secret
   in one operation.

2. **JSON Validation:** Scripts validate that each secret contains valid JSON
before attempting to extract values.

3. **Error Handling:** If any required key is missing or empty, scripts will exit
with an error message indicating which key failed.

4. **Environment-Based Selection:** Scripts automatically select the appropriate
deployment role ARN based on the selected environment (prod vs dev).

5. **Terraform Integration:** All Terraform variables are exported as environment
variables with the `TF_VAR_` prefix, which Terraform automatically recognizes
as variable values.

6. **Separation of Concerns:** ARNs and passwords are stored in separate secrets
for better security and organization.

### Local Script Behavior

Local bash scripts (`setup-backend.sh`, `setup-application.sh`, `set-state.sh`,
`get-state.sh`):

- Retrieve role ARNs from AWS Secrets Manager secret `github-role`
- Retrieve ExternalId from AWS Secrets Manager secret `external-id` (plain text)
- Retrieve passwords from AWS Secrets Manager secret `tf-vars`
- Export them as environment variables for Terraform
- Automatically handle case conversion (uppercase secrets → lowercase environment
variables)
- Add ExternalId to `variables.tfvars` for Terraform provider configuration

### GitHub Actions Workflow Behavior

GitHub Actions workflows:

- Retrieve secrets directly from GitHub Repository Secrets
- Automatically export them as environment variables for Terraform
- Handle case conversion in workflow YAML

Example workflow configuration:

```yaml
env:
  TF_VAR_openldap_admin_password: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
  TF_VAR_openldap_config_password: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
  TF_VAR_postgresql_database_password: ${{ secrets.TF_VAR_POSTGRESQL_PASSWORD }}
  TF_VAR_redis_password: ${{ secrets.TF_VAR_REDIS_PASSWORD }}
```

## Summary Tables

### AWS Secrets Manager Secrets (for Local Bash Scripts)

| Secret Name | Key Name | Type | Required For | Description |
| ------------- | ---------- | ------ | -------------- | ------------- |
| `github-role` | `AWS_STATE_ACCOUNT_ROLE_ARN` | IAM Role ARN | All scripts | Role for backend state operations and Route53/ACM access |
| `github-role` | `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` | IAM Role ARN | Scripts (prod) | Role for production deployments |
| `github-role` | `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` | IAM Role ARN | Scripts (dev) | Role for development deployments |
| `external-id` | (plain text) | ExternalId | `setup-backend.sh`, `setup-application.sh` | ExternalId for cross-account role assumption security |
| `tf-vars` | `TF_VAR_OPENLDAP_ADMIN_PASSWORD` | Password | `setup-application.sh` | OpenLDAP admin password (exported as `TF_VAR_openldap_admin_password`) |
| `tf-vars` | `TF_VAR_OPENLDAP_CONFIG_PASSWORD` | Password | `setup-application.sh` | OpenLDAP config password (exported as `TF_VAR_openldap_config_password`) |
| `tf-vars` | `TF_VAR_POSTGRESQL_PASSWORD` | Password | `setup-application.sh` | PostgreSQL database password (exported as `TF_VAR_postgresql_database_password`) |
| `tf-vars` | `TF_VAR_REDIS_PASSWORD` | Password | `setup-application.sh` | Redis password for SMS OTP storage (exported as `TF_VAR_redis_password`) |

### GitHub Repository Secrets (for GitHub Actions Workflows)

| Secret Name | Type | Description |
| ------------- | ------ | ------------- |
| `AWS_STATE_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for backend state operations and Route53/ACM access |
| `AWS_PRODUCTION_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for production deployments |
| `AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN` | IAM Role ARN | Role for development deployments |
| `AWS_ASSUME_EXTERNAL_ID` | ExternalId | ExternalId for cross-account role assumption security (must match deployment account role Trust Relationship) |
| `TF_VAR_OPENLDAP_ADMIN_PASSWORD` | Password | OpenLDAP admin password |
| `TF_VAR_OPENLDAP_CONFIG_PASSWORD` | Password | OpenLDAP config password |
| `TF_VAR_POSTGRESQL_PASSWORD` | Password | PostgreSQL database password |
| `TF_VAR_REDIS_PASSWORD` | Password | Redis password for SMS OTP storage (minimum 8 characters) |
| `GH_TOKEN` | GitHub PAT | GitHub Personal Access Token with `repo` scope |

### GitHub Repository Variables (for GitHub Actions Workflows)

Variables are non-sensitive values that can be accessed by workflows. Configure
them at:
**Repository → Settings → Secrets and variables → Actions → Variables**

| Variable Name | Type | Description | How It's Set |
| ------------- | ------ | ------------- | ------------ |
| `AWS_REGION` | Variable | AWS region where resources will be created | Manual |
| `BACKEND_PREFIX` | Variable | Prefix for Terraform state file path in S3 bucket | Manual |
| `APPLICATION_PREFIX` | Variable | Prefix for application infrastructure resources | Manual |
| `BACKEND_BUCKET_NAME` | Variable | Dynamically generated S3 bucket name for Terraform state | **Auto-generated** by `tfstate_infra_provisioning.yaml` workflow |
| `ECR_REPOSITORY_NAME` | Variable | ECR repository name for Docker image storage | **Auto-generated** by `backend_infra_provisioning.yaml` workflow or `setup-backend.sh` script |

> [!IMPORTANT]
>
> **Auto-generated Variables:**
>
> - `BACKEND_BUCKET_NAME`: Automatically set after provisioning Terraform backend
> state infrastructure
> - `ECR_REPOSITORY_NAME`: Automatically set after provisioning backend infrastructure
>   - Set by `backend_infra_provisioning.yaml` workflow after successful
> Terraform apply
>   - Set by `setup-backend.sh` script after successful Terraform apply
>   - Required by build workflows (`backend_build_push.yaml` and `frontend_build_push.yaml`)
>   - **⚠️ You don't need to create these manually** - they are created automatically

## Troubleshooting

### AWS Secrets Manager Issues (Local Scripts)

**Problem:** Local scripts cannot retrieve secrets from AWS Secrets Manager

**Common issues and solutions:**

- **Secret doesn't exist:** Ensure secret named `github-role` or `tf-vars` exists
in AWS Secrets Manager
- **Access denied:** Your AWS credentials must have `secretsmanager:GetSecretValue`
permission for the secrets
- **Key not found:** Ensure the secret JSON contains the required keys
- **Invalid JSON:** Verify the secret value is valid JSON format
- **Wrong region:** Ensure your AWS CLI is configured to the correct region where
the secrets exist

**Verification:**

```bash
# Test secret retrieval manually
aws secretsmanager get-secret-value --secret-id github-role --query SecretString --output text | jq .
aws secretsmanager get-secret-value --secret-id tf-vars --query SecretString --output text | jq .
```

### GitHub Secrets Issues

**Problem:** GitHub Actions workflows cannot access secrets

**Common issues and solutions:**

- **Secret not configured:** Ensure all required secrets are set in
Repository Settings → Secrets and variables → Actions → Secrets
- **Wrong secret name:** Verify secret names match exactly (case-sensitive)
- **Insufficient permissions:** Ensure the workflow has access to repository secrets
- **Secret not available in workflow:** Check that secrets are referenced correctly
in workflow YAML

### Case Sensitivity Issues

**Problem:** Terraform variables not recognized

**Solution:** Ensure environment variables use lowercase to match `variables.tf`:

- Secret: `TF_VAR_OPENLDAP_ADMIN_PASSWORD` (uppercase in GitHub/AWS)
- Environment variable: `TF_VAR_openldap_admin_password` (lowercase for Terraform)

## Related Documentation

- [Main README](README.md) - Project overview and setup instructions
- [Application Infrastructure README](application/README.md) - Application deployment
details
- [Backend Infrastructure README](backend_infra/README.md) - Backend infrastructure
setup
- [Terraform Backend State README](tf_backend_state/README.md) - State backend
configuration
