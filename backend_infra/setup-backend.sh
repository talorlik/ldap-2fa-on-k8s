#!/bin/bash

# Script to configure backend.hcl and variables.tfvars with user-selected region and environment
# and run Terraform commands
# Usage: ./setup-backend.sh

set -euo pipefail

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
    echo ""
    echo "Or use the alternative method with curl (requires GITHUB_TOKEN environment variable):"
    echo "  export GITHUB_TOKEN=your_token"
    echo "  ./setup-backend-api.sh"
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

# Function to check if repository secret exists using GitHub CLI
check_repo_secret_exists() {
    local secret_name=$1
    local exists

    exists=$(gh secret list --repo "${REPO_OWNER}/${REPO_NAME}" --json name --jq ".[] | select(.name == \"${secret_name}\") | .name" 2>/dev/null || echo "")

    if [ -z "$exists" ]; then
        return 1
    fi

    return 0
}

# Function to get repository secret value
# Note: GitHub CLI doesn't allow reading secret values directly for security reasons
# In GitHub Actions, secrets are automatically available as environment variables
get_repo_secret_value() {
    local secret_name=$1
    local value

    # In GitHub Actions, secrets are available as environment variables with the same name
    # For local use, we check if it's set as an environment variable
    value="${!secret_name:-}"

    if [ -z "$value" ]; then
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

# Retrieve STATE_ACCOUNT_ROLE_ARN for backend state operations
print_info "Retrieving AWS_STATE_ACCOUNT_ROLE_ARN from repository secrets..."
if ! check_repo_secret_exists "AWS_STATE_ACCOUNT_ROLE_ARN"; then
    print_error "AWS_STATE_ACCOUNT_ROLE_ARN secret not found in repository secrets."
    echo "Please ensure AWS_STATE_ACCOUNT_ROLE_ARN is set in GitHub repository secrets."
    exit 1
fi

STATE_ROLE_ARN=$(get_repo_secret_value "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
if [ -z "$STATE_ROLE_ARN" ]; then
    print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN secret value."
    echo "In GitHub Actions, secrets are automatically available as environment variables."
    echo "For local use, ensure the secret is available as an environment variable."
    exit 1
fi
print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"

# Determine which deployment account role ARN secret to use based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    DEPLOYMENT_ROLE_ARN_SECRET_NAME="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
else
    DEPLOYMENT_ROLE_ARN_SECRET_NAME="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
fi

# Retrieve deployment account role ARN for provider assume_role
print_info "Retrieving ${DEPLOYMENT_ROLE_ARN_SECRET_NAME} from repository secrets..."
if ! check_repo_secret_exists "${DEPLOYMENT_ROLE_ARN_SECRET_NAME}"; then
    print_error "${DEPLOYMENT_ROLE_ARN_SECRET_NAME} secret not found in repository secrets."
    echo "Please ensure ${DEPLOYMENT_ROLE_ARN_SECRET_NAME} is set in GitHub repository secrets."
    exit 1
fi

DEPLOYMENT_ROLE_ARN=$(get_repo_secret_value "${DEPLOYMENT_ROLE_ARN_SECRET_NAME}" || echo "")
if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
    print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_SECRET_NAME} secret value."
    echo "In GitHub Actions, secrets are automatically available as environment variables."
    echo "For local use, ensure the secret is available as an environment variable."
    exit 1
fi
print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_SECRET_NAME}"

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
terraform workspace select "${WORKSPACE_NAME}" 2>/dev/null || terraform workspace new "${WORKSPACE_NAME}"

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
