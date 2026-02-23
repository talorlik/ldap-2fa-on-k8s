#!/bin/bash
# get-eks-token.sh - Get EKS authentication token with optional cross-account role assumption
#
# Used by Terraform kubernetes and helm providers (exec plugin) for dynamic token generation.
# Generates a fresh EKS token on every Kubernetes API call, preventing token expiration
# issues during long Terraform operations (e.g., Helm releases with 20-minute timeouts).
#
# Environment variables (set by Terraform exec block's env map):
#   EKS_CLUSTER_NAME   - EKS cluster name (required)
#   EKS_REGION         - AWS region (required)
#   ASSUME_ROLE_ARN    - Role ARN to assume before getting token (optional)
#   ASSUME_EXTERNAL_ID - ExternalId for role assumption (optional, used with ASSUME_ROLE_ARN)
#
# Usage in providers.tf:
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "${path.module}/../get-eks-token.sh"
#     env = {
#       EKS_CLUSTER_NAME   = local.cluster_name
#       EKS_REGION         = var.region
#       ASSUME_ROLE_ARN    = var.deployment_account_role_arn != null ? var.deployment_account_role_arn : ""
#       ASSUME_EXTERNAL_ID = var.deployment_account_external_id != null ? var.deployment_account_external_id : ""
#     }
#   }
#
# Credential flow:
#   GitHub Actions: Env has State Account creds → script assumes Deployment Account role → gets EKS token
#   Local dev:      Env already has Deployment Account creds → script skips assume-role → gets EKS token directly

set -euo pipefail

# Validate required environment variables
if [ -z "${EKS_CLUSTER_NAME:-}" ]; then
  echo "ERROR: EKS_CLUSTER_NAME environment variable is required" >&2
  exit 1
fi

if [ -z "${EKS_REGION:-}" ]; then
  echo "ERROR: EKS_REGION environment variable is required" >&2
  exit 1
fi

# If role ARN is provided, assume it first (cross-account access)
if [ -n "${ASSUME_ROLE_ARN:-}" ]; then
  ASSUME_ROLE_ARGS=(
    "sts" "assume-role"
    "--role-arn" "$ASSUME_ROLE_ARN"
    "--role-session-name" "terraform-eks-token-$(date +%s)"
    "--region" "$EKS_REGION"
    "--output" "json"
  )

  # Add ExternalId if provided (required for deployment account roles)
  if [ -n "${ASSUME_EXTERNAL_ID:-}" ]; then
    ASSUME_ROLE_ARGS+=("--external-id" "$ASSUME_EXTERNAL_ID")
  fi

  CREDS=$(aws "${ASSUME_ROLE_ARGS[@]}" 2>/dev/null)

  export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
fi

# Get and output the EKS token (ExecCredential JSON format)
exec aws eks get-token --cluster-name "$EKS_CLUSTER_NAME" --region "$EKS_REGION" --output json
