#!/bin/bash

# Script to configure backend.hcl and variables.tfvars with user-selected region and environment
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

# Retrieve repository variables
print_info "Retrieving repository variables..."

BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
print_success "Retrieved BACKEND_BUCKET_NAME"

BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX") || exit 1
print_success "Retrieved BACKEND_PREFIX"

# Check if placeholder file exists
if [ ! -f "$PLACEHOLDER_FILE" ]; then
    print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
    exit 1
fi

# Copy placeholder to backend file and replace placeholders
print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."

# Copy placeholder file to backend file (overwrites if exists)
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
else
    # Linux sed
    sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
    sed -i "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
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
print_info "Next steps:"
echo "  1. terraform init -backend-config=\"${BACKEND_FILE}\""
echo "  2. terraform workspace select ${AWS_REGION}-${ENVIRONMENT} || terraform workspace new ${AWS_REGION}-${ENVIRONMENT}"
echo "  3. terraform plan -var-file=\"${VARIABLES_FILE}\" -out \"plan.tfplan\""
echo "  4. terraform apply -auto-approve \"plan.tfplan\""
