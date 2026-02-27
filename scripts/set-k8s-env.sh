#!/bin/bash
# Script to set Kubernetes environment variables for Terraform Helm/Kubernetes providers
# Fetches cluster name from backend_infra Terraform state
# Works for both local development and CI/CD (bash scripts and GitHub Actions workflows)
#
# Usage: source ./set-k8s-env.sh
#   Uses AWS credentials from environment variables (set by setup-application-infra.sh or CI/CD workflow)
#
# Backend_infra state key: use BACKEND_PREFIX (repo variable in CI) or parse from backend_infra/backend.hcl.
# Backend_infra workspace resolution (for S3 state path env:/<workspace>/<BACKEND_PREFIX>):
#   Callers should set one of the following so the correct state is read in all contexts:
#   1. TERRAFORM_WORKSPACE  - explicit workspace (e.g. us-east-1-prod)
#   2. AWS_REGION + ENVIRONMENT - script derives workspace as ${AWS_REGION}-${ENVIRONMENT}
#   3. If neither: uses "terraform workspace show" in script dir (application_infra); only correct
#      when run from application_infra after "terraform workspace select" has been run.
#   GitHub workflows and bash scripts (setup/destroy application and application_infra) should
#   export TERRAFORM_WORKSPACE or both AWS_REGION and ENVIRONMENT before sourcing this script.

set -e

# Get script directory - works correctly when script is sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Save original directory to restore at the end
# IMPORTANT: This script may be sourced from other directories (e.g., application/)
# We must restore the original directory before returning to avoid breaking calling scripts
_SET_K8S_ENV_ORIGINAL_PWD="$(pwd)"

cd "$SCRIPT_DIR"

# Resolve BACKEND_FILE and VARIABLES_FILE relative to caller's working directory
# (before cd changed us to script dir). This ensures the scripts work correctly
# regardless of where the script lives (e.g., scripts/ instead of application_infra/).
if [ -n "${BACKEND_FILE:-}" ] && [[ "$BACKEND_FILE" != /* ]] && [ -f "$_SET_K8S_ENV_ORIGINAL_PWD/$BACKEND_FILE" ]; then
    BACKEND_FILE="$_SET_K8S_ENV_ORIGINAL_PWD/$BACKEND_FILE"
fi
if [ -n "${VARIABLES_FILE:-}" ] && [[ "$VARIABLES_FILE" != /* ]] && [ -f "$_SET_K8S_ENV_ORIGINAL_PWD/$VARIABLES_FILE" ]; then
    VARIABLES_FILE="$_SET_K8S_ENV_ORIGINAL_PWD/$VARIABLES_FILE"
fi

# Colors for output (if not already defined by sourcing script)
if [ -z "${RED:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
fi

# Function to print colored messages (if not already defined by sourcing script)
if ! declare -f print_error > /dev/null; then
    print_error() {
        echo -e "${RED}ERROR:${NC} $1" >&2
    }
fi

if ! declare -f print_success > /dev/null; then
    print_success() {
        echo -e "${GREEN}SUCCESS:${NC} $1"
    }
fi

if ! declare -f print_info > /dev/null; then
    print_info() {
        echo -e "${YELLOW}INFO:${NC} $1"
    }
fi

echo "Using AWS credentials from environment variables"
echo "Fetching cluster name from backend_infra Terraform state..."

# Use BACKEND_FILE from environment if available, otherwise default to backend.hcl
BACKEND_FILE="${BACKEND_FILE:-backend.hcl}"

# Check if backend file exists
if [ ! -f "$BACKEND_FILE" ]; then
    echo "ERROR: $BACKEND_FILE not found. Run ./setup-application-infra.sh or the 02-application_infra_provisioning.yaml GitHub workflow first."
    exit 1
fi

# Parse backend configuration (application_infra state: bucket/region from current backend file)
BACKEND_BUCKET=$(grep 'bucket' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')
BACKEND_REGION=$(grep 'region' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')

# Backend_infra state key: from repo variable (BACKEND_PREFIX) or backend_infra/backend.hcl - never hardcoded
if [ -n "${BACKEND_PREFIX:-}" ]; then
    BACKEND_KEY="$BACKEND_PREFIX"
    echo "Backend_infra state key (from BACKEND_PREFIX): $BACKEND_KEY"
elif [ -f "../backend_infra/backend.hcl" ]; then
    BACKEND_KEY=$(grep 'key' "../backend_infra/backend.hcl" | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$BACKEND_KEY" ]; then
        echo "ERROR: Could not parse key from ../backend_infra/backend.hcl"
        exit 1
    fi
    echo "Backend_infra state key (from ../backend_infra/backend.hcl): $BACKEND_KEY"
else
    echo "ERROR: Backend_infra state key not found. Set BACKEND_PREFIX (e.g. from repo variables) or ensure backend_infra/backend.hcl exists."
    exit 1
fi

echo "Backend S3 bucket: $BACKEND_BUCKET"
echo "Backend region: $BACKEND_REGION"

# Determine backend_infra workspace for state key.
# In CI (e.g. GitHub Actions destroy/provision) we may not have run terraform in application_infra,
# so terraform workspace show would return "default" and we would read the wrong state file.
# Prefer: TERRAFORM_WORKSPACE env, then region-env (CI), then terraform workspace show (local).
if [ -n "${TERRAFORM_WORKSPACE:-}" ]; then
    WORKSPACE="$TERRAFORM_WORKSPACE"
    echo "Terraform workspace (from TERRAFORM_WORKSPACE): $WORKSPACE"
elif [ -n "${AWS_REGION:-}" ] && [ -n "${ENVIRONMENT:-}" ]; then
    WORKSPACE="${AWS_REGION}-${ENVIRONMENT}"
    echo "Terraform workspace (from AWS_REGION and ENVIRONMENT): $WORKSPACE"
else
    WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
    echo "Terraform workspace (from terraform workspace show): $WORKSPACE"
fi

# Fetch cluster name from backend_infra state
if [ "$WORKSPACE" = "default" ]; then
    STATE_KEY="$BACKEND_KEY"
else
    STATE_KEY="env:/$WORKSPACE/$BACKEND_KEY"
fi

echo "Fetching cluster name from s3://$BACKEND_BUCKET/$STATE_KEY"

# Use current credentials (State Account credentials)
CLUSTER_NAME=$(aws s3 cp "s3://$BACKEND_BUCKET/$STATE_KEY" - 2>/dev/null | jq -r '.outputs.cluster_name.value' || echo "")

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
    echo "ERROR: Could not retrieve cluster name from backend_infra state."
    echo "Make sure backend_infra has been deployed and outputs cluster_name."
    exit 1
fi

echo "Cluster name: $CLUSTER_NAME"

# Assume Deployment Account role for EKS cluster access
# This is needed for aws eks describe-cluster to access the EKS cluster
# Use AWS_REGION from environment if available, otherwise use BACKEND_REGION
AWS_REGION="${AWS_REGION:-$BACKEND_REGION}"

if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
    print_error "DEPLOYMENT_ROLE_ARN is not set. Run ./setup-application-infra.sh first."
    exit 1
fi

if [ -z "$EXTERNAL_ID" ]; then
    print_error "EXTERNAL_ID is not set. Run ./setup-application-infra.sh first."
    exit 1
fi

print_info "Assuming Deployment Account role: $DEPLOYMENT_ROLE_ARN"
print_info "Region: $AWS_REGION"

DEPLOYMENT_ROLE_SESSION_NAME="setup-application-infra-deployment-$(date +%s)"

# Assume deployment account role with ExternalId
DEPLOYMENT_ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$DEPLOYMENT_ROLE_ARN" \
    --role-session-name "$DEPLOYMENT_ROLE_SESSION_NAME" \
    --external-id "$EXTERNAL_ID" \
    --region "$AWS_REGION" 2>&1)

if [ $? -ne 0 ]; then
    print_error "Failed to assume Deployment Account role: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
    exit 1
fi

# Extract Deployment Account credentials from JSON output
if command -v jq &> /dev/null; then
    export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
else
    # Fallback: use sed for JSON parsing (works on both macOS and Linux)
    export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    print_error "Failed to extract Deployment Account credentials from assume-role output."
    print_error "Output was: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
    exit 1
fi

# Verify the Deployment Account credentials work
DEPLOYMENT_CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
if [ $? -ne 0 ]; then
    print_error "Failed to verify Deployment Account role credentials: $DEPLOYMENT_CALLER_ARN"
    exit 1
fi

print_success "Successfully assumed Deployment Account role"
print_info "Deployment Account role identity: $DEPLOYMENT_CALLER_ARN"
echo ""

# Use VARIABLES_FILE from environment if available, otherwise default to variables.tfvars
VARIABLES_FILE="${VARIABLES_FILE:-variables.tfvars}"

# Update variables.tfvars
print_info "Updating ${VARIABLES_FILE} with selected values..."

if [ ! -f "$VARIABLES_FILE" ]; then
    print_error "Variables file '${VARIABLES_FILE}' not found."
    exit 1
fi

# Update variables.tfvars (works on macOS and Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires -i '' for in-place editing
    sed -i '' "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT:-prod}\"|" "$VARIABLES_FILE"
    sed -i '' "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
    # Add or update deployment_account_role_arn
    if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
        echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
    else
        sed -i '' "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
    fi
    # Add or update deployment_account_external_id
    if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
        echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
    else
        sed -i '' "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
    fi
    # Add or update state_account_role_arn (if provided)
    if [ -n "${STATE_ACCOUNT_ROLE_ARN:-}" ]; then
        if ! grep -q "^state_account_role_arn" "$VARIABLES_FILE"; then
            echo "state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
        else
            sed -i '' "s|^state_account_role_arn[[:space:]]*=.*|state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"|" "$VARIABLES_FILE"
        fi
    fi
else
    # Linux sed
    sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT:-prod}\"|" "$VARIABLES_FILE"
    sed -i "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
    # Add or update deployment_account_role_arn
    if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
        echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
    else
        sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
    fi
    # Add or update deployment_account_external_id
    if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
        echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
    else
        sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
    fi
    # Add or update state_account_role_arn (if provided)
    if [ -n "${STATE_ACCOUNT_ROLE_ARN:-}" ]; then
        if ! grep -q "^state_account_role_arn" "$VARIABLES_FILE"; then
            echo "state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
        else
            sed -i "s|^state_account_role_arn[[:space:]]*=.*|state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"|" "$VARIABLES_FILE"
        fi
    fi
fi

print_success "Updated ${VARIABLES_FILE}"
echo ""
print_info "  - env: ${ENVIRONMENT:-prod}"
print_info "  - region: ${AWS_REGION}"
echo ""

# Get cluster endpoint
# IMPORTANT: This command must use credentials for the deployment account where the EKS cluster exists
# Credentials are set via environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
echo "Fetching cluster endpoint..."
KUBERNETES_MASTER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "")

if [ -z "$KUBERNETES_MASTER" ]; then
    print_error "Could not retrieve cluster endpoint. Make sure the cluster exists and you have AWS credentials configured."
    exit 1
fi

echo "Kubernetes Master: $KUBERNETES_MASTER"

# Export environment variables
export KUBERNETES_MASTER
export KUBE_CONFIG_PATH="${KUBE_CONFIG_PATH:-$HOME/.kube/config}"

# Update kubeconfig with latest cluster endpoint
# This MUST happen on every run to ensure kubeconfig is current
# Use deployment account credentials (already set via environment variables)
print_info "Updating kubeconfig for cluster: $CLUSTER_NAME"
print_info "Region: $AWS_REGION"

# Ensure kubeconfig directory exists
KUBE_CONFIG_DIR=$(dirname "$KUBE_CONFIG_PATH")
if [ ! -d "$KUBE_CONFIG_DIR" ]; then
    mkdir -p "$KUBE_CONFIG_DIR"
    print_info "Created kubeconfig directory: $KUBE_CONFIG_DIR"
fi

# Configure kubeconfig to use AWS CLI exec plugin for dynamic token generation
# This ensures kubectl always gets fresh tokens from whatever AWS credentials are in the environment
# Terraform's AWS provider will assume the deployment role, and kubectl will inherit those credentials
print_info "Configuring kubeconfig with AWS CLI exec plugin for dynamic authentication..."

# Fetch cluster certificate authority data
CLUSTER_CA_DATA=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.certificateAuthority.data' --output text 2>/dev/null)

if [ -z "$CLUSTER_CA_DATA" ]; then
    print_error "Failed to retrieve cluster certificate authority data"
    exit 1
fi

# Create/update kubeconfig with exec plugin configuration
cat > "$KUBE_CONFIG_PATH" <<'EOF'
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: CLUSTER_CA_DATA_PLACEHOLDER
    server: KUBERNETES_MASTER_PLACEHOLDER
  name: CLUSTER_NAME_PLACEHOLDER
contexts:
- context:
    cluster: CLUSTER_NAME_PLACEHOLDER
    user: CLUSTER_NAME_PLACEHOLDER
  name: CLUSTER_NAME_PLACEHOLDER
current-context: CLUSTER_NAME_PLACEHOLDER
users:
- name: CLUSTER_NAME_PLACEHOLDER
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
      - eks
      - get-token
      - --cluster-name
      - CLUSTER_NAME_PLACEHOLDER
      - --region
      - AWS_REGION_PLACEHOLDER
      # AWS CLI will automatically use credentials from environment variables
      # (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
      # These are set by Terraform's AWS provider assume_role block
      env: null
EOF

# Replace placeholders with actual values (avoids shell variable expansion issues)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed
    sed -i '' "s|CLUSTER_CA_DATA_PLACEHOLDER|$CLUSTER_CA_DATA|g" "$KUBE_CONFIG_PATH"
    sed -i '' "s|KUBERNETES_MASTER_PLACEHOLDER|$KUBERNETES_MASTER|g" "$KUBE_CONFIG_PATH"
    sed -i '' "s|CLUSTER_NAME_PLACEHOLDER|$CLUSTER_NAME|g" "$KUBE_CONFIG_PATH"
    sed -i '' "s|AWS_REGION_PLACEHOLDER|$AWS_REGION|g" "$KUBE_CONFIG_PATH"
else
    # Linux sed
    sed -i "s|CLUSTER_CA_DATA_PLACEHOLDER|$CLUSTER_CA_DATA|g" "$KUBE_CONFIG_PATH"
    sed -i "s|KUBERNETES_MASTER_PLACEHOLDER|$KUBERNETES_MASTER|g" "$KUBE_CONFIG_PATH"
    sed -i "s|CLUSTER_NAME_PLACEHOLDER|$CLUSTER_NAME|g" "$KUBE_CONFIG_PATH"
    sed -i "s|AWS_REGION_PLACEHOLDER|$AWS_REGION|g" "$KUBE_CONFIG_PATH"
fi

print_success "Kubeconfig configured with exec plugin"
print_info "Kubeconfig path: $KUBE_CONFIG_PATH"
print_info "kubectl will dynamically fetch tokens using current AWS credentials"

echo ""
echo "✅ Environment variables set successfully!"
echo ""
echo "KUBERNETES_MASTER=$KUBERNETES_MASTER"
echo "KUBE_CONFIG_PATH=$KUBE_CONFIG_PATH"
echo ""
echo "To use these variables in your current shell, run:"
echo "  source ./set-k8s-env.sh"

# Restore original directory before returning
# This ensures calling scripts continue in their original directory
cd "$_SET_K8S_ENV_ORIGINAL_PWD"
unset _SET_K8S_ENV_ORIGINAL_PWD
