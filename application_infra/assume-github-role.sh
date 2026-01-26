#!/bin/bash

# Script to assume the 'github-role' for different AWS accounts (State, Dev, Prod)
# Usage: source ./assume-github-role.sh [state|dev|prod|clean] [--help]
#   OR:   eval $(./assume-github-role.sh [state|dev|prod|clean])
#   If no argument is provided, the script will prompt for account selection
#   If an argument is provided, it will skip the prompt and use the specified account
#   Use 'clean' to remove all AWS credentials from the environment
#
# IMPORTANT: This script must be SOURCED (not executed) for credentials to persist
#   in your current shell. Use: source ./assume-github-role.sh [option]
#   OR use: eval $(./assume-github-role.sh [option])

set -euo pipefail

# Detect if script is being sourced or executed
# If ${BASH_SOURCE[0]} == ${0}, script is being executed
# If ${BASH_SOURCE[0]} != ${0}, script is being sourced
IS_SOURCED=false
if [[ "${BASH_SOURCE[0]:-}" != "${0}" ]]; then
    IS_SOURCED=true
fi

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

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

print_success() {
    if [ "$IS_SOURCED" = true ]; then
        echo -e "${GREEN}SUCCESS:${NC} $1"
    else
        echo -e "${GREEN}SUCCESS:${NC} $1" >&2
    fi
}

print_info() {
    if [ "$IS_SOURCED" = true ]; then
        echo -e "${YELLOW}INFO:${NC} $1"
    else
        echo -e "${YELLOW}INFO:${NC} $1" >&2
    fi
}

# Function to display help message
show_help() {
    cat << EOF
Usage: ./assume-github-role.sh [OPTION]

This script allows you to assume the 'github-role' for different AWS accounts
(State, Dev, Prod) or clean existing AWS credentials from your environment.

OPTIONS:
    state           Assume the State Account role
    dev             Assume the Dev Account role
    prod            Assume the Prod Account role
    clean           Remove all AWS credentials from the environment
    --help, -h      Display this help message and exit

EXAMPLES:
    # IMPORTANT: This script must be SOURCED for credentials to persist!

    # Interactive mode (prompts for selection) - SOURCED
    source ./assume-github-role.sh

    # Assume State Account role - SOURCED
    source ./assume-github-role.sh state

    # Assume Dev Account role - SOURCED
    source ./assume-github-role.sh dev

    # Assume Prod Account role - SOURCED
    source ./assume-github-role.sh prod

    # Clean all AWS credentials - SOURCED
    source ./assume-github-role.sh clean

    # Alternative: Use eval to execute and apply exports
    eval $(./assume-github-role.sh state)

    # Display help (can be executed directly)
    ./assume-github-role.sh --help

NOTES:
    - Arguments are case-insensitive (state, State, STATE all work)
    - When assuming Dev or Prod roles, ExternalId is automatically retrieved
    - IMPORTANT: You must SOURCE this script (source ./assume-github-role.sh) for
    credentials to persist in your current shell session
    - If executed directly (./assume-github-role.sh), the script will output export
    commands that can be eval'd: eval $(./assume-github-role.sh state)
    - Use 'clean' to remove credentials when switching accounts

EOF
}

# Function to clean AWS credentials from environment
clean_aws_credentials() {
    print_info "Cleaning AWS credentials from environment..."

    unset AWS_ACCESS_KEY_ID 2>/dev/null || true
    unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
    unset AWS_SESSION_TOKEN 2>/dev/null || true
    unset AWS_PROFILE 2>/dev/null || true

    print_success "AWS credentials have been removed from the environment"

    # Verify credentials are cleared
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -z "${AWS_SESSION_TOKEN:-}" ]; then
        print_info "Verification: All AWS credential environment variables are unset"
    else
        print_error "Warning: Some AWS credentials may still be set"
    fi

    echo ""
    return 0
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed."
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed."
    echo "Please install it:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq (or use your package manager)"
    echo "  Or visit: https://stedolan.github.io/jq/download/"
    exit 1
fi

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
#   session_name_suffix: Optional suffix for session name (defaults to "assume-github-role")
assume_aws_role() {
    local role_arn=$1
    local external_id=${2:-}
    local role_description=${3:-"role"}
    local session_name_suffix=${4:-"assume-github-role"}

    if [ -z "$role_arn" ]; then
        print_error "Role ARN is required for assume_aws_role"
        return 1
    fi

    print_info "Assuming ${role_description}: $role_arn"
    print_info "Region: ${AWS_REGION:-us-east-1}"

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
            --region "${AWS_REGION:-us-east-1}" 2>&1)
    else
        assume_role_output=$(aws sts assume-role \
            --role-arn "$role_arn" \
            --role-session-name "$role_session_name" \
            --region "${AWS_REGION:-us-east-1}" 2>&1)
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to assume ${role_description}: $assume_role_output"
        return 1
    fi

    # Extract credentials from JSON output
    local access_key_id
    local secret_access_key
    local session_token

    access_key_id=$(echo "$assume_role_output" | jq -r '.Credentials.AccessKeyId')
    secret_access_key=$(echo "$assume_role_output" | jq -r '.Credentials.SecretAccessKey')
    session_token=$(echo "$assume_role_output" | jq -r '.Credentials.SessionToken')

    if [ -z "$access_key_id" ] || [ -z "$secret_access_key" ] || [ -z "$session_token" ]; then
        print_error "Failed to extract credentials from assume-role output."
        print_error "Output was: $assume_role_output"
        return 1
    fi

    # Store credentials in global variables for later export
    ASSUMED_AWS_ACCESS_KEY_ID="$access_key_id"
    ASSUMED_AWS_SECRET_ACCESS_KEY="$secret_access_key"
    ASSUMED_AWS_SESSION_TOKEN="$session_token"

    # Export credentials to environment variables (only if sourced)
    if [ "$IS_SOURCED" = true ]; then
        export AWS_ACCESS_KEY_ID="$access_key_id"
        export AWS_SECRET_ACCESS_KEY="$secret_access_key"
        export AWS_SESSION_TOKEN="$session_token"
    fi

    print_success "Successfully assumed ${role_description}"

    # Verify the credentials work
    local caller_arn
    if [ "$IS_SOURCED" = true ]; then
        # Use exported credentials
        caller_arn=$(aws sts get-caller-identity --region "${AWS_REGION:-us-east-1}" --query 'Arn' --output text 2>&1)
    else
        # Temporarily set credentials for verification
        caller_arn=$(AWS_ACCESS_KEY_ID="$access_key_id" \
                    AWS_SECRET_ACCESS_KEY="$secret_access_key" \
                    AWS_SESSION_TOKEN="$session_token" \
                    aws sts get-caller-identity --region "${AWS_REGION:-us-east-1}" --query 'Arn' --output text 2>&1)
    fi

    if [ $? -ne 0 ]; then
        print_error "Failed to verify assumed role credentials: $caller_arn"
        return 1
    fi

    print_info "${role_description} identity: $caller_arn"
    return 0
}

# Check for --help flag first
if [ $# -gt 0 ]; then
    ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$ARG" in
        --help|-h|help)
            show_help
            exit 0
            ;;
    esac
fi

# Check if account selection or clean was provided as argument
if [ $# -gt 0 ]; then
    # Use argument if provided
    ACCOUNT_ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$ACCOUNT_ARG" in
        state)
            ACCOUNT_TYPE="State"
            ROLE_ARN_KEY="AWS_STATE_ACCOUNT_ROLE_ARN"
            ACTION="assume"
            ;;
        dev)
            ACCOUNT_TYPE="Dev"
            ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
            ACTION="assume"
            ;;
        prod)
            ACCOUNT_TYPE="Prod"
            ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
            ACTION="assume"
            ;;
        clean)
            ACTION="clean"
            ;;
        *)
            print_error "Invalid argument: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac

    if [ "$ACTION" = "assume" ]; then
        print_info "Using account from argument: ${ACCOUNT_TYPE}"
    fi
else
    # Interactive prompt for account selection
    while true; do
        echo ""
        print_info "Select an option:"
        echo "1) Assume State Account role"
        echo "2) Assume Dev Account role"
        echo "3) Assume Prod Account role"
        echo "4) Clean AWS credentials"
        echo "5) Cancel"
        read -p "Enter choice [1-5]: " account_choice

        case "$account_choice" in
            1)
                ACCOUNT_TYPE="State"
                ROLE_ARN_KEY="AWS_STATE_ACCOUNT_ROLE_ARN"
                ACTION="assume"
                break
                ;;
            2)
                ACCOUNT_TYPE="Dev"
                ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
                ACTION="assume"
                break
                ;;
            3)
                ACCOUNT_TYPE="Prod"
                ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
                ACTION="assume"
                break
                ;;
            4)
                ACTION="clean"
                break
                ;;
            5)
                print_info "Operation cancelled."
                exit 0
                ;;
            "")
                print_error "No selection made. Please enter a valid choice [1-5]."
                ;;
            *)
                print_error "Invalid choice: '$account_choice'. Please enter a valid choice [1-5]."
                ;;
        esac
    done
fi

# Handle clean action
if [ "$ACTION" = "clean" ]; then
    clean_aws_credentials
    exit 0
fi

print_success "Selected account: ${ACCOUNT_TYPE}"
echo ""

# Set default region if not already set
if [ -z "${AWS_REGION:-}" ]; then
    AWS_REGION="us-east-1"
    export AWS_REGION
    print_info "Using default region: ${AWS_REGION}"
fi

# Retrieve role ARNs from AWS Secrets Manager
print_info "Retrieving role ARN from AWS Secrets Manager..."
ROLE_SECRET_JSON=$(get_aws_secret "github-role" || echo "")
if [ -z "$ROLE_SECRET_JSON" ]; then
    print_error "Failed to retrieve 'github-role' secret from AWS Secrets Manager"
    exit 1
fi

# Extract the selected account role ARN
ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "$ROLE_ARN_KEY" || echo "")
if [ -z "$ROLE_ARN" ]; then
    print_error "Failed to retrieve ${ROLE_ARN_KEY} from secret"
    exit 1
fi
print_success "Retrieved ${ROLE_ARN_KEY}"

# Retrieve ExternalId from AWS Secrets Manager (only needed for Dev and Prod accounts)
EXTERNAL_ID=""
if [ "$ACCOUNT_TYPE" != "State" ]; then
    print_info "Retrieving ExternalId from AWS Secrets Manager..."
    EXTERNAL_ID=$(aws secretsmanager get-secret-value \
        --secret-id "external-id" \
        --region "${AWS_REGION}" \
        --query SecretString \
        --output text 2>&1)

    if [ $? -ne 0 ]; then
        print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
        print_error "Error: $EXTERNAL_ID"
        exit 1
    fi

    if [ -z "$EXTERNAL_ID" ]; then
        print_error "ExternalId secret is empty"
        exit 1
    fi
    print_success "Retrieved ExternalId"
fi

echo ""

# Assume the selected role
if [ -n "$EXTERNAL_ID" ]; then
    if ! assume_aws_role "$ROLE_ARN" "$EXTERNAL_ID" "${ACCOUNT_TYPE} Account role" "assume-github-role"; then
        exit 1
    fi
else
    if ! assume_aws_role "$ROLE_ARN" "" "${ACCOUNT_TYPE} Account role" "assume-github-role"; then
        exit 1
    fi
fi

echo ""

# Handle output based on whether script is sourced or executed
if [ "$IS_SOURCED" = true ]; then
    # Script is sourced - credentials are already exported
    print_success "Script completed successfully!"
    print_info "AWS credentials are now exported in your current shell session."
    print_info "You can now run AWS CLI commands with the assumed role."
    echo ""
else
    # Script is executed - output export commands to stdout (for eval), messages to stderr
    print_success "Script completed successfully!" >&2
    print_info "AWS credentials ready. Export commands output below:" >&2
    print_info "Run: eval \$(./assume-github-role.sh ${1:-})" >&2
    echo "" >&2
    # Output export commands to stdout (can be eval'd)
    echo "export AWS_ACCESS_KEY_ID=\"${ASSUMED_AWS_ACCESS_KEY_ID}\""
    echo "export AWS_SECRET_ACCESS_KEY=\"${ASSUMED_AWS_SECRET_ACCESS_KEY}\""
    echo "export AWS_SESSION_TOKEN=\"${ASSUMED_AWS_SESSION_TOKEN}\""
    if [ -n "${AWS_REGION:-}" ]; then
        echo "export AWS_REGION=\"${AWS_REGION}\""
    fi
fi
