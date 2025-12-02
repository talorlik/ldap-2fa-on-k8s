#!/bin/bash

# Alternative script to configure backend.hcl and variables.tfvars using GitHub API directly
# Usage: GITHUB_TOKEN=your_token ./setup-backend-api.sh
# Or: export GITHUB_TOKEN=your_token && ./setup-backend-api.sh

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

# Check if GITHUB_TOKEN is set
if [ -z "${GITHUB_TOKEN:-}" ]; then
    print_error "GITHUB_TOKEN environment variable is not set."
    echo "Please set it using:"
    echo "  export GITHUB_TOKEN=your_token"
    echo "  ./setup-backend-api.sh"
    echo ""
    echo "You can create a token at: https://github.com/settings/tokens"
    echo "Required scope: repo (for private repos) or public_repo (for public repos)"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    print_error "curl is not installed."
    exit 1
fi

# Get repository owner and name from git remote URL
if ! command -v git &> /dev/null; then
    print_error "git is not installed."
    exit 1
fi

REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
    print_error "Could not determine repository from git remote."
    echo "Please ensure you're in a git repository."
    exit 1
fi

# Parse repository owner and name from remote URL
# Handles both https://github.com/owner/repo.git and git@github.com:owner/repo.git
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]%.git}"
else
    print_error "Could not parse repository information from remote URL: ${REMOTE_URL}"
    exit 1
fi

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

# Function to get repository variable using GitHub API
get_repo_variable() {
    local var_name=$1
    local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/variables/${var_name}"
    local response
    local value

    response=$(curl -s -w "\n%{http_code}" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$api_url" 2>/dev/null || echo "")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        if [ "$http_code" == "404" ]; then
            print_error "Repository variable '${var_name}' not found."
        else
            print_error "Failed to retrieve '${var_name}'. HTTP status: ${http_code}"
            echo "Response: $body" >&2
        fi
        return 1
    fi

    # Extract value from JSON response (requires jq or use grep/sed)
    if command -v jq &> /dev/null; then
        value=$(echo "$body" | jq -r '.value' 2>/dev/null || echo "")
    else
        # Fallback: use grep and sed if jq is not available
        value=$(echo "$body" | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "")
    fi

    if [ -z "$value" ]; then
        print_error "Could not parse value for '${var_name}'."
        return 1
    fi

    echo "$value"
}

# Retrieve repository variables
print_info "Retrieving repository variables from GitHub API..."

BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
print_success "Retrieved BACKEND_BUCKET_NAME"

APPLICATION_PREFIX=$(get_repo_variable "APPLICATION_PREFIX") || exit 1
print_success "Retrieved APPLICATION_PREFIX"

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
    sed -i '' "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
    sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
else
    # Linux sed
    sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
    sed -i "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
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
print_info "  - key: ${APPLICATION_PREFIX}"
print_info "  - region: ${AWS_REGION}"
echo ""
print_info "Variables file: ${VARIABLES_FILE}"
print_info "  - env: ${ENVIRONMENT}"
print_info "  - region: ${AWS_REGION}"
echo ""
print_info "Next steps:"
echo "  1. terraform init -backend-config=\"${BACKEND_FILE}\""
echo "  2. terraform workspace select ${AWS_REGION}-${ENVIRONMENT} || terraform workspace new ${AWS_REGION}-${ENVIRONMENT}"
echo "  3. terraform plan -var-file=\"${VARIABLES_FILE}\" -out \"terraform.tfplan\""
echo "  4. terraform apply -auto-approve \"terraform.tfplan\""
