#!/bin/bash

# Script to configure backend.hcl and variables.tfvars with user-selected region and environment
# and run Terraform commands
# Usage: ./setup-backend.sh

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
echo ""

# Retrieve all role ARNs from AWS Secrets Manager in a single call
# This minimizes AWS CLI calls by fetching all required role ARNs at once
print_info "Retrieving role ARNs from AWS Secrets Manager..."
SECRET_JSON=$(get_aws_secret "github-role" || echo "")
if [ -z "$SECRET_JSON" ]; then
    print_error "Failed to retrieve secret from AWS Secrets Manager"
    exit 1
fi

# Extract STATE_ACCOUNT_ROLE_ARN for backend state operations
STATE_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
if [ -z "$STATE_ROLE_ARN" ]; then
    print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
    exit 1
fi
print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"

# Determine which deployment account role ARN to use based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
else
    DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
fi

# Extract deployment account role ARN for provider assume_role
DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
    print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
    exit 1
fi
print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"

# Use STATE_ROLE_ARN for backend operations
ROLE_ARN="$STATE_ROLE_ARN"

print_info "Assuming role: $ROLE_ARN"
print_info "Region: $AWS_REGION"

# Assume the role
ROLE_SESSION_NAME="setup-backend-$(date +%s)"

# Assume role and capture output
ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME" \
    --region "$AWS_REGION" 2>&1)

if [ $? -ne 0 ]; then
    print_error "Failed to assume role: $ASSUME_ROLE_OUTPUT"
    exit 1
fi

# Extract credentials from JSON output
# Try using jq if available (more reliable), otherwise use sed/grep
if command -v jq &> /dev/null; then
    export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
else
    # Fallback: use sed for JSON parsing (works on both macOS and Linux)
    export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    print_error "Failed to extract credentials from assume-role output."
    print_error "Output was: $ASSUME_ROLE_OUTPUT"
    exit 1
fi

print_success "Successfully assumed role"

# Verify the credentials work
CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
if [ $? -ne 0 ]; then
    print_error "Failed to verify assumed role credentials: $CALLER_ARN"
    exit 1
fi

print_info "Assumed role identity: $CALLER_ARN"
echo ""

# Retrieve ExternalId from AWS Secrets Manager (plain text secret)
# Must be retrieved after assuming role to have AWS credentials
print_info "Retrieving ExternalId from AWS Secrets Manager..."
EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
if [ -z "$EXTERNAL_ID" ]; then
    print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
    exit 1
fi
print_success "Retrieved ExternalId"

# Retrieve repository variables
print_info "Retrieving repository variables..."

BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
print_success "Retrieved BACKEND_BUCKET_NAME"

BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX") || exit 1
print_success "Retrieved BACKEND_PREFIX"

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
        sed -i '' "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
        sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
    else
        # Linux sed
        sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
        sed -i "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
        sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
    fi

    print_success "Created ${BACKEND_FILE}"
fi

# Update variables.tfvars
print_info "Updating ${VARIABLES_FILE} with selected values..."

if [ ! -f "$VARIABLES_FILE" ]; then
    print_error "Variables file '${VARIABLES_FILE}' not found."
    exit 1
fi

# Update variables.tfvars (works on macOS and Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires -i '' for in-place editing
    sed -i '' "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
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
else
    # Linux sed
    sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
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
fi

print_success "Updated ${VARIABLES_FILE}"
echo ""
print_success "Configuration files updated successfully!"
echo ""
print_info "Backend file: ${BACKEND_FILE}"
print_info "  - bucket: ${BUCKET_NAME}"
print_info "  - key: ${BACKEND_PREFIX}"
print_info "  - region: ${AWS_REGION}"
echo ""
print_info "Variables file: ${VARIABLES_FILE}"
print_info "  - env: ${ENVIRONMENT}"
print_info "  - region: ${AWS_REGION}"
echo ""

# Terraform workspace name
WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"

# Terraform init
print_info "Running terraform init with backend configuration..."
terraform init -backend-config="${BACKEND_FILE}"

# Terraform workspace
print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
terraform workspace select "${WORKSPACE_NAME}" || terraform workspace new "${WORKSPACE_NAME}"

# Terraform validate
print_info "Running terraform validate..."
terraform validate

# Terraform plan
print_info "Running terraform plan..."
terraform plan -var-file="${VARIABLES_FILE}" -out terraform.tfplan

# Terraform apply
print_info "Running terraform apply..."
terraform apply -auto-approve terraform.tfplan

echo ""
print_success "Script completed successfully!"
