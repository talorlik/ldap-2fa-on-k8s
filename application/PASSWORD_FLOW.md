# Password Flow: From Secrets to Terraform Variables

This document explains how passwords flow from GitHub Secrets and AWS Secrets Manager
through to Terraform variables and finally into Kubernetes secrets.

## Overview

Passwords are stored securely in:

1. **GitHub Repository Secrets** (for GitHub Actions workflows)
2. **AWS Secrets Manager** (for local bash scripts)

They are then passed to Terraform via environment variables using the `TF_VAR_`
prefix convention.

## Secret Storage Locations

### AWS Secrets Manager

**Secret Name:** `tf-vars` (JSON format)

```json
{
  "TF_VAR_OPENLDAP_ADMIN_PASSWORD": "<admin-password>",
  "TF_VAR_OPENLDAP_CONFIG_PASSWORD": "<config-password>",
  "TF_VAR_POSTGRESQL_PASSWORD": "<postgresql-password>",
  "TF_VAR_REDIS_PASSWORD": "<redis-password>"
}
```

### GitHub Repository Secrets

Individual secrets (plain text):

- `TF_VAR_POSTGRESQL_PASSWORD`
- `TF_VAR_REDIS_PASSWORD`
- `TF_VAR_OPENLDAP_ADMIN_PASSWORD`
- `TF_VAR_OPENLDAP_CONFIG_PASSWORD`

## Flow Diagram

```ascii
┌─────────────────────────────────────────────────────────────────┐
│                    Secret Storage                               │
├─────────────────────────────────────────────────────────────────┤
│  GitHub Secrets         │  AWS Secrets Manager                  │
│  (for CI/CD)            │  (for local scripts)                  │
│                         │                                       │
│  TF_VAR_POSTGRESQL_     │  tf-vars secret (JSON):               │
│    PASSWORD             │  {                                    │
│  TF_VAR_REDIS_PASSWORD  │    "TF_VAR_POSTGRESQL_PASSWORD": ...  │
│  ...                    │    "TF_VAR_REDIS_PASSWORD": ...       │
│                         │  }                                    │
└─────────────────────────┼───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Secret Retrieval & Conversion                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Local Script (setup-application.sh):                           │
│  1. Retrieve tf-vars secret from AWS Secrets Manager            │
│  2. Parse JSON: get_secret_key_value()                          │
│  3. Extract: TF_VAR_POSTGRESQL_PASSWORD_VALUE                   │
│  4. Export: TF_VAR_postgresql_database_password (lowercase)     │
│                                                                 │
│  GitHub Actions (.github/workflows/application_provisioning.yaml):│
│  1. Read from GitHub Secrets                                    │
│  2. Export directly: TF_VAR_postgresql_database_password        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Terraform Environment Variables                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TF_VAR_postgresql_database_password=<password>                 │
│  TF_VAR_redis_password=<password>                               │
│  TF_VAR_openldap_admin_password=<password>                      │
│                                                                 │
│  Note: Terraform automatically reads TF_VAR_* env vars          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Terraform Variables (variables.tf)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  variable "postgresql_database_password" {                      │
│    type      = string                                           │
│    sensitive = true                                             │
│  }                                                              │
│                                                                 │
│  variable "redis_password" {                                    │
│    type      = string                                           │
│    sensitive = true                                             │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Terraform Resources (main.tf)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  # PostgreSQL secret in backend namespace                       │
│  resource "kubernetes_secret" "postgresql_secret_backend_..." { │
│    data = {                                                     │
│      "password" = var.postgresql_database_password  ◄─── HERE   │
│    }                                                            │
│  }                                                              │
│                                                                 │
│  # Redis secret in backend namespace                            │
│  resource "kubernetes_secret" "redis_secret_backend_..." {      │
│    data = {                                                     │
│      "redis-password" = var.redis_password  ◄─── HERE           │
│    }                                                            │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Kubernetes Secrets                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Namespace: 2fa-app                                             │
│  ├── postgresql-secret                                          │
│  │   └── password: <base64-encoded-password>                    │
│  └── redis-secret                                               │
│      └── redis-password: <base64-encoded-password>              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Flow: Local Scripts

### Step 1: Retrieve from AWS Secrets Manager

**File:** `application/setup-application.sh` (lines 387-393)

```bash
# Retrieve Terraform variables from AWS Secrets Manager in a single call
TF_VARS_SECRET_JSON=$(get_aws_secret "tf-vars" || echo "")
```

**Function:** `get_aws_secret()` (lines 113-144)

- Uses AWS CLI: `aws secretsmanager get-secret-value --secret-id "tf-vars"`
- Returns JSON string containing all password values
- Validates JSON format

### Step 2: Extract Individual Passwords

**File:** `application/setup-application.sh` (lines 395-409)

```bash
# Extract PostgreSQL password from tf-vars secret
TF_VAR_POSTGRESQL_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_POSTGRESQL_PASSWORD" || echo "")

# Extract Redis password from tf-vars secret
TF_VAR_REDIS_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_REDIS_PASSWORD" || echo "")
```

**Function:** `get_secret_key_value()` (lines 179-207)

- Uses `jq` to parse JSON: `jq -r ".[\"${key_name}\"]"`
- Extracts specific key value from JSON
- Validates key exists and value is not empty

### Step 3: Export as Terraform Environment Variables

**File:** `application/setup-application.sh` (lines 419-424)

```bash
# Export as environment variables for Terraform
# Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
# Secrets in AWS/GitHub remain uppercase, but environment variables must be lowercase
export TF_VAR_postgresql_database_password="$TF_VAR_POSTGRESQL_PASSWORD_VALUE"
export TF_VAR_redis_password="$TF_VAR_REDIS_PASSWORD_VALUE"
export TF_VAR_openldap_admin_password="$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE"
```

**Key Points:**

- **Case conversion:** Uppercase secret keys → lowercase environment variables
- **Naming convention:** `TF_VAR_` prefix + variable name from `variables.tf`
- **Terraform auto-detection:** Terraform automatically reads `TF_VAR_*`
environment variables

### Step 4: Terraform Reads Variables

**File:** `application/variables.tf` (lines 105-109, 137-147)

```hcl
variable "postgresql_database_password" {
  description = "PostgreSQL database password. MUST be set via TF_VAR_POSTGRESQL_PASSWORD environment variable or GitHub Secret."
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis authentication password (from GitHub Secrets via TF_VAR_REDIS_PASSWORD)"
  type        = string
  sensitive   = true
  default     = ""
}
```

**Terraform Behavior:**

- Automatically maps `TF_VAR_postgresql_database_password` → `var.postgresql_database_password`
- Automatically maps `TF_VAR_redis_password` → `var.redis_password`
- No need to explicitly pass variables in `terraform apply`

### Step 5: Terraform Creates Kubernetes Secrets

**File:** `application/main.tf` (lines 208-230, 234-256)

```hcl
# Copy PostgreSQL secret to backend namespace
resource "kubernetes_secret" "postgresql_secret_backend_namespace" {
  data = {
    "password" = var.postgresql_database_password  # ← Password from environment variable
  }
}

# Copy Redis secret to backend namespace
resource "kubernetes_secret" "redis_secret_backend_namespace" {
  data = {
    "redis-password" = var.redis_password  # ← Password from environment variable
  }
}
```

**Terraform Behavior:**

- Base64-encodes password values automatically
- Creates Kubernetes Secret resources
- Stores passwords securely in Kubernetes

## Detailed Flow: GitHub Actions

### Step 1: Read from GitHub Secrets

**File:** `.github/workflows/application_provisioning.yaml` (lines 57-66)

```yaml
env:
  AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
  # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
  # Secrets in GitHub remain uppercase, but environment variables must be lowercase
  TF_VAR_postgresql_database_password: ${{ secrets.TF_VAR_POSTGRESQL_PASSWORD }}
  TF_VAR_redis_password: ${{ secrets.TF_VAR_REDIS_PASSWORD }}
  TF_VAR_openldap_admin_password: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
```

**Key Points:**

- GitHub Secrets are uppercase: `TF_VAR_POSTGRESQL_PASSWORD`
- Environment variables are lowercase: `TF_VAR_postgresql_database_password`
- Case conversion happens in workflow YAML

### Step 2-5: Same as Local Scripts

Steps 2-5 are identical - Terraform reads environment variables and creates Kubernetes
secrets.

## Case Sensitivity Mapping

| Storage Location | Key Name | Environment Variable | Terraform Variable |
| ----------------- | ---------- | --------------------- | ------------------- |
| AWS Secrets Manager | `TF_VAR_POSTGRESQL_PASSWORD` | `TF_VAR_postgresql_database_password` | `var.postgresql_database_password` |
| GitHub Secrets | `TF_VAR_POSTGRESQL_PASSWORD` | `TF_VAR_postgresql_database_password` | `var.postgresql_database_password` |
| AWS Secrets Manager | `TF_VAR_REDIS_PASSWORD` | `TF_VAR_redis_password` | `var.redis_password` |
| GitHub Secrets | `TF_VAR_REDIS_PASSWORD` | `TF_VAR_redis_password` | `var.redis_password` |

> [!IMPORTANT]
>
> - Secret keys in AWS/GitHub: **UPPERCASE**
> - Environment variables: **lowercase** (matches Terraform variable names)
> - Terraform variable names: **lowercase** (defined in `variables.tf`)

## Security Considerations

1. **Never commit passwords** to git repositories
2. **Use sensitive variables** in Terraform (`sensitive = true`)
3. **Base64 encoding** happens automatically in Kubernetes secrets
4. **Environment variables** are only available during Terraform execution
5. **Secrets are encrypted** at rest in AWS Secrets Manager and GitHub

## Verification

### Check Environment Variables (Before Terraform)

```bash
# Local script
echo $TF_VAR_postgresql_database_password  # Should show password
echo $TF_VAR_redis_password                # Should show password

# GitHub Actions
# Check workflow logs (passwords are masked automatically)
```

### Check Terraform Variables (During Terraform)

```bash
# Terraform will show variables (passwords masked)
terraform plan -var-file="variables.tfvars"
```

### Check Kubernetes Secrets (After Terraform)

```bash
# View secret (base64 encoded)
kubectl get secret postgresql-secret -n 2fa-app -o yaml

# Decode password
kubectl get secret postgresql-secret -n 2fa-app -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### Problem: "Variable not set" error

**Solution:** Verify environment variable is exported:

```bash
env | grep TF_VAR_postgresql_database_password
```

### Problem: "Failed to retrieve secret from AWS Secrets Manager"

**Solution:**

1. Check AWS credentials are configured
2. Verify secret exists:

    ```bash
    aws secretsmanager describe-secret --secret-id tf-vars
    ```

3. Check IAM permissions for Secrets Manager access

### Problem: "Failed to retrieve TF_VAR_POSTGRESQL_PASSWORD from secret"

**Solution:**

1. Verify key exists in JSON:

    ```bash
    aws secretsmanager get-secret-value --secret-id tf-vars | jq .
    ```

2. Check key name matches exactly (case-sensitive)
3. Verify JSON is valid format

### Problem: Terraform variable not found

**Solution:**

1. Verify environment variable name matches Terraform variable name exactly
2. Check case sensitivity: `TF_VAR_postgresql_database_password` (lowercase)
3. Ensure variable is exported before running `terraform plan/apply`
