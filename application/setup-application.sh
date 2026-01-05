#!/bin/bash

# Script to configure backend.hcl and variables.tfvars with user-selected region and environment
# and run Terraform commands
# Usage: ./setup-application.sh

set -euo pipefail

# Clean up any existing AWS credentials from environment to prevent conflicts
# This ensures the script starts with a clean slate and uses the correct credentials
unset AWS_ACCESS_KEY_ID 2>/dev/null || true
unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
unset AWS_SESSION_TOKEN 2>/dev/null || true
unset AWS_PROFILE 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PLACEHOLDER_FILE="tfstate-backend-values-template.hcl"
BACKEND_FILE="backend.hcl"
VARIABLES_FILE="variables.tfvars"

# Export configuration variables for use by sourced scripts
export BACKEND_FILE
export VARIABLES_FILE

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_info() {
    echo -e "${YELLOW}INFO:${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed."
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed."
    echo "Please install it from: https://www.terraform.io/downloads"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed."
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub CLI."
    echo "Please run: gh auth login"
    exit 1
fi

# Check if jq is installed (required for gh --jq flag)
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed."
    echo "Please install it:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq (or use your package manager)"
    echo "  Or visit: https://stedolan.github.io/jq/download/"
    exit 1
fi

# Get repository owner and name
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    print_error "Could not determine repository information."
    echo "Please ensure you're in a git repository and have proper permissions."
    exit 1
fi

print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"

# Function to get repository variable using GitHub CLI
get_repo_variable() {
    local var_name=$1
    local value

    value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")

    if [ -z "$value" ]; then
        print_error "Repository variable '${var_name}' not found or not accessible."
        return 1
    fi

    echo "$value"
}

# Function to retrieve secret from AWS Secrets Manager
get_aws_secret() {
    local secret_name=$1
    local secret_json
    local exit_code

    # Retrieve secret from AWS Secrets Manager
    # Use AWS_REGION if set, otherwise default to us-east-1
    secret_json=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "${AWS_REGION:-us-east-1}" \
        --query SecretString \
        --output text 2>&1)

    # Capture exit code before checking
    exit_code=$?

    # Validate secret retrieval
    if [ $exit_code -ne 0 ]; then
        print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
        print_error "Error: $secret_json"
        return 1
    fi

    # Validate JSON can be parsed
    if ! echo "$secret_json" | jq empty 2>/dev/null; then
        print_error "Secret '${secret_name}' contains invalid JSON"
        return 1
    fi

    echo "$secret_json"
}

# Function to retrieve plain text secret from AWS Secrets Manager
get_aws_plaintext_secret() {
    local secret_name=$1
    local secret_value
    local exit_code

    # Retrieve secret from AWS Secrets Manager
    # Use AWS_REGION if set, otherwise default to us-east-1
    secret_value=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "${AWS_REGION:-us-east-1}" \
        --query SecretString \
        --output text 2>&1)

    # Capture exit code before checking
    exit_code=$?

    # Validate secret retrieval
    if [ $exit_code -ne 0 ]; then
        print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
        print_error "Error: $secret_value"
        return 1
    fi

    # Check if secret value is empty
    if [ -z "$secret_value" ]; then
        print_error "Secret '${secret_name}' is empty"
        return 1
    fi

    echo "$secret_value"
}

# Function to get key value from secret JSON
get_secret_key_value() {
    local secret_json=$1
    local key_name=$2
    local value

    # Validate JSON can be parsed
    if ! echo "$secret_json" | jq empty 2>/dev/null; then
        print_error "Invalid JSON provided to get_secret_key_value"
        return 1
    fi

    # Extract key value using jq
    value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)

    # Check if jq command succeeded
    if [ $? -ne 0 ]; then
        print_error "Failed to parse JSON or extract key '${key_name}'"
        return 1
    fi

    # Check if key exists (jq returns "null" for non-existent keys)
    if [ "$value" = "null" ] || [ -z "$value" ]; then
        print_error "Key '${key_name}' not found in secret JSON or value is empty"
        return 1
    fi

    echo "$value"
}

# Function to assume an AWS IAM role and export credentials
# Usage: assume_aws_role <role_arn> [external_id] [role_description] [session_name_suffix]
#   role_arn: The ARN of the role to assume (required)
#   external_id: Optional external ID for cross-account role assumption
#   role_description: Optional description for logging (defaults to "role")
#   session_name_suffix: Optional suffix for session name (defaults to "setup-application")
assume_aws_role() {
    local role_arn=$1
    local external_id=${2:-}
    local role_description=${3:-"role"}
    local session_name_suffix=${4:-"setup-application"}

    if [ -z "$role_arn" ]; then
        print_error "Role ARN is required for assume_aws_role"
        return 1
    fi

    print_info "Assuming ${role_description}: $role_arn"
    print_info "Region: $AWS_REGION"

    # Assume the role
    local role_session_name="${session_name_suffix}-$(date +%s)"
    local assume_role_output

    # Assume role and capture output
    # Add external ID if provided
    if [ -n "$external_id" ]; then
        assume_role_output=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$role_session_name" \
            --external-id "$external_id" \
            --region "$AWS_REGION" 2>&1)
    else
        assume_role_output=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$role_session_name" \
            --region "$AWS_REGION" 2>&1)
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to assume ${role_description}: $assume_role_output"
        return 1
    fi

    # Extract credentials from JSON output
    # Try using jq if available (more reliable), otherwise use sed/grep
    local access_key_id
    local secret_access_key
    local session_token

    if command -v jq &> /dev/null; then
        access_key_id=$(echo "$assume_role_output" | jq -r '.Credentials.AccessKeyId')
        secret_access_key=$(echo "$assume_role_output" | jq -r '.Credentials.SecretAccessKey')
        session_token=$(echo "$assume_role_output" | jq -r '.Credentials.SessionToken')
    else
        # Fallback: use sed for JSON parsing (works on both macOS and Linux)
        access_key_id=$(echo "$assume_role_output" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        secret_access_key=$(echo "$assume_role_output" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        session_token=$(echo "$assume_role_output" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    fi

    if [ -z "$access_key_id" ] || [ -z "$secret_access_key" ] || [ -z "$session_token" ]; then
        print_error "Failed to extract credentials from assume-role output."
        print_error "Output was: $assume_role_output"
        return 1
    fi

    # Export credentials to environment variables
    export AWS_ACCESS_KEY_ID="$access_key_id"
    export AWS_SECRET_ACCESS_KEY="$secret_access_key"
    export AWS_SESSION_TOKEN="$session_token"

    print_success "Successfully assumed ${role_description}"

    # Verify the credentials work
    local caller_arn
    caller_arn=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
    if [ $? -ne 0 ]; then
        print_error "Failed to verify assumed role credentials: $caller_arn"
        return 1
    fi

    print_info "${role_description} identity: $caller_arn"
    return 0
}

# Interactive prompts
echo ""
print_info "Select AWS Region:"
echo "1) us-east-1: N. Virginia (default)"
echo "2) us-east-2: Ohio"
read -p "Enter choice [1-2] (default: 1): " region_choice

case ${region_choice:-1} in
    1)
        SELECTED_REGION="us-east-1: N. Virginia"
        ;;
    2)
        SELECTED_REGION="us-east-2: Ohio"
        ;;
    *)
        print_error "Invalid choice. Using default: us-east-1: N. Virginia"
        SELECTED_REGION="us-east-1: N. Virginia"
        ;;
esac

# Extract region code (everything before the colon)
AWS_REGION="${SELECTED_REGION%%:*}"
export AWS_REGION
print_success "Selected region: ${SELECTED_REGION} (${AWS_REGION})"

echo ""
print_info "Select Environment:"
echo "1) prod (default)"
echo "2) dev"
read -p "Enter choice [1-2] (default: 1): " env_choice

case ${env_choice:-1} in
    1)
        ENVIRONMENT="prod"
        ;;
    2)
        ENVIRONMENT="dev"
        ;;
    *)
        print_error "Invalid choice. Using default: prod"
        ENVIRONMENT="prod"
        ;;
esac

print_success "Selected environment: ${ENVIRONMENT}"
export ENVIRONMENT
echo ""

# Retrieve role ARNs from AWS Secrets Manager in a single call
# This minimizes AWS CLI calls by fetching all required role ARNs at once
print_info "Retrieving role ARNs from AWS Secrets Manager..."
ROLE_SECRET_JSON=$(get_aws_secret "github-role" || echo "")
if [ -z "$ROLE_SECRET_JSON" ]; then
    print_error "Failed to retrieve 'github-role' secret from AWS Secrets Manager"
    exit 1
fi

# Extract STATE_ACCOUNT_ROLE_ARN for backend state operations and Route53/ACM access
STATE_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
if [ -z "$STATE_ROLE_ARN" ]; then
    print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
    exit 1
fi
export STATE_ACCOUNT_ROLE_ARN="$STATE_ROLE_ARN"
print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"

# Determine which deployment account role ARN to use based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
else
    DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
fi

# Extract deployment account role ARN for provider assume_role
DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
    print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
    exit 1
fi
export DEPLOYMENT_ROLE_ARN
print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"

# Retrieve ExternalId from AWS Secrets Manager (plain text secret)
print_info "Retrieving ExternalId from AWS Secrets Manager..."
EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
if [ -z "$EXTERNAL_ID" ]; then
    print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
    exit 1
fi
export EXTERNAL_ID
print_success "Retrieved ExternalId"

# Retrieve Terraform variables from AWS Secrets Manager in a single call
print_info "Retrieving Terraform variables from AWS Secrets Manager..."
TF_VARS_SECRET_JSON=$(get_aws_secret "tf-vars" || echo "")
if [ -z "$TF_VARS_SECRET_JSON" ]; then
    print_error "Failed to retrieve 'tf-vars' secret from AWS Secrets Manager"
    exit 1
fi

# Extract OpenLDAP password values from tf-vars secret
TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_ADMIN_PASSWORD" || echo "")
if [ -z "$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE" ]; then
    print_error "Failed to retrieve TF_VAR_OPENLDAP_ADMIN_PASSWORD from secret"
    exit 1
fi
print_success "Retrieved TF_VAR_OPENLDAP_ADMIN_PASSWORD"

TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_CONFIG_PASSWORD" || echo "")
if [ -z "$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE" ]; then
    print_error "Failed to retrieve TF_VAR_OPENLDAP_CONFIG_PASSWORD from secret"
    exit 1
fi
print_success "Retrieved TF_VAR_OPENLDAP_CONFIG_PASSWORD"

# Extract PostgreSQL password from tf-vars secret
TF_VAR_POSTGRESQL_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_POSTGRESQL_PASSWORD" || echo "")
if [ -z "$TF_VAR_POSTGRESQL_PASSWORD_VALUE" ]; then
    print_error "Failed to retrieve TF_VAR_POSTGRESQL_PASSWORD from secret"
    exit 1
fi
print_success "Retrieved TF_VAR_POSTGRESQL_PASSWORD"

# Extract Redis password from tf-vars secret
TF_VAR_REDIS_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_REDIS_PASSWORD" || echo "")
if [ -z "$TF_VAR_REDIS_PASSWORD_VALUE" ]; then
    print_error "Failed to retrieve TF_VAR_REDIS_PASSWORD from secret"
    exit 1
fi
print_success "Retrieved TF_VAR_REDIS_PASSWORD"

# Export as environment variables for Terraform
# Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
# Secrets in AWS/GitHub remain uppercase, but environment variables must be lowercase
export TF_VAR_openldap_admin_password="$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE"
export TF_VAR_openldap_config_password="$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE"
export TF_VAR_postgresql_database_password="$TF_VAR_POSTGRESQL_PASSWORD_VALUE"
export TF_VAR_redis_password="$TF_VAR_REDIS_PASSWORD_VALUE"

print_success "Retrieved and exported all secrets from AWS Secrets Manager"
echo ""

# Retrieve repository variables
print_info "Retrieving repository variables..."

BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
print_success "Retrieved BACKEND_BUCKET_NAME"

APPLICATION_PREFIX=$(get_repo_variable "APPLICATION_PREFIX") || exit 1
print_success "Retrieved APPLICATION_PREFIX"

# Check if backend.hcl already exists
if [ -f "$BACKEND_FILE" ]; then
    print_info "${BACKEND_FILE} already exists. Skipping creation."
else
    # Check if placeholder file exists
    if [ ! -f "$PLACEHOLDER_FILE" ]; then
        print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
        exit 1
    fi

    # Copy placeholder to backend file and replace placeholders
    print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."

    # Copy placeholder file to backend file
    cp "$PLACEHOLDER_FILE" "$BACKEND_FILE"

    # Replace placeholders (works on macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed requires -i '' for in-place editing
        sed -i '' "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
        sed -i '' "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
        sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
    else
        # Linux sed
        sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
        sed -i "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
        sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
    fi

    print_success "Created ${BACKEND_FILE}"
fi

print_success "Configuration files updated successfully!"
echo ""
print_info "Backend file: ${BACKEND_FILE}"
print_info "  - bucket: ${BUCKET_NAME}"
print_info "  - key: ${APPLICATION_PREFIX}"
print_info "  - region: ${AWS_REGION}"
echo ""

# Assume State Account role for backend operations
if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "setup-application"; then
    exit 1
fi

echo ""

# Mirror third-party images to ECR (if not already present)
print_info "Checking if Docker images need to be mirrored to ECR..."
if [ ! -f "mirror-images-to-ecr.sh" ]; then
    print_error "mirror-images-to-ecr.sh not found."
    exit 1
fi

# Make sure the script is executable
chmod +x ./mirror-images-to-ecr.sh

# Run the image mirroring script
if ./mirror-images-to-ecr.sh; then
    print_success "ECR image mirroring completed"
else
    print_error "ECR image mirroring failed"
    exit 1
fi

echo ""

# Terraform workspace name
WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"

# Terraform init
print_info "Running terraform init with backend configuration..."
terraform init -backend-config="${BACKEND_FILE}"

# Terraform workspace
print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
terraform workspace select "${WORKSPACE_NAME}" 2>/dev/null || terraform workspace new "${WORKSPACE_NAME}"

# Terraform validate
print_info "Running terraform validate..."
terraform validate

# Set Kubernetes environment variables
print_info "Setting Kubernetes environment variables..."
if [ ! -f "set-k8s-env.sh" ]; then
    print_error "set-k8s-env.sh not found."
    exit 1
fi

# Make sure the script is executable
chmod +x ./set-k8s-env.sh

# Source the script to set environment variables
# The script uses environment variables (Deployment Account credentials for EKS, State Account credentials for S3)
source ./set-k8s-env.sh

if [ -z "$KUBERNETES_MASTER" ]; then
    print_error "Failed to set KUBERNETES_MASTER environment variable."
    exit 1
fi

print_success "Kubernetes environment variables set"
print_info "  - KUBERNETES_MASTER: ${KUBERNETES_MASTER}"
print_info "  - KUBE_CONFIG_PATH: ${KUBE_CONFIG_PATH}"

# Export as TF_VAR_ environment variables for Terraform
export TF_VAR_kubernetes_master="$KUBERNETES_MASTER"
export TF_VAR_kube_config_path="$KUBE_CONFIG_PATH"
print_info "  - TF_VAR_kubernetes_master: ${TF_VAR_kubernetes_master}"
print_info "  - TF_VAR_kube_config_path: ${TF_VAR_kube_config_path}"
echo ""

# Assume State Account role for backend operations
if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "setup-application"; then
    exit 1
fi

echo ""

# Terraform plan
print_info "Running terraform plan..."
terraform plan -var-file="${VARIABLES_FILE}" -out terraform.tfplan

# Terraform apply
print_info "Running terraform apply..."
terraform apply -auto-approve terraform.tfplan

echo ""
print_success "Script completed successfully!"
