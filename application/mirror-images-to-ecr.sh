#!/bin/bash
# Script to mirror third-party container images (Redis, PostgreSQL, OpenLDAP) from Docker Hub to ECR
# This eliminates Docker Hub rate limiting and external dependencies during deployments
# Only mirrors images that don't already exist in ECR
#
# Usage: ./mirror-images-to-ecr.sh
#   Requires Docker to be installed and running
#   Uses AWS credentials from environment variables (set by setup-application.sh)
#   Retrieves ECR information from backend_infra Terraform state

set -euo pipefail

cd "$(dirname "$0")"

# Colors for output (if not already defined by sourcing script)
if [ -z "${RED:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
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

info() { echo -e "${BLUE}[INFO]${NC} $*"; }

# Check required tools
for cmd in docker jq; do
  if ! command -v "$cmd" &> /dev/null; then
    print_error "$cmd is required but not installed."
    exit 1
  fi
done

# Check if Docker daemon is running
if ! docker info &> /dev/null 2>&1; then
  print_error "Docker daemon is not running. Please start Docker and try again."
  exit 1
fi

info "Starting ECR image mirroring process..."
echo ""

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "AWS Account ID: $AWS_ACCOUNT_ID"

# Use AWS_REGION from environment (set by setup-application.sh)
if [ -z "${AWS_REGION:-}" ]; then
    print_error "AWS_REGION is not set. Run ./setup-application.sh first."
    exit 1
fi
info "AWS Region: $AWS_REGION"

# Use BACKEND_FILE from environment if available, otherwise default to backend.hcl
BACKEND_FILE="${BACKEND_FILE:-backend.hcl}"

# Check if backend file exists
if [ ! -f "$BACKEND_FILE" ]; then
    print_error "$BACKEND_FILE not found. Run ./setup-application.sh first."
    exit 1
fi

# Parse backend configuration
BACKEND_BUCKET=$(grep 'bucket' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')
BACKEND_KEY="backend_state/terraform.tfstate"

info "Backend S3 bucket: $BACKEND_BUCKET"

# Get current workspace to fetch correct state
WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
info "Terraform workspace: $WORKSPACE"

# Determine state key based on workspace
if [ "$WORKSPACE" = "default" ]; then
    STATE_KEY="$BACKEND_KEY"
else
    STATE_KEY="env:/$WORKSPACE/$BACKEND_KEY"
fi

info "Fetching ECR repository information from s3://$BACKEND_BUCKET/$STATE_KEY"

# Fetch ECR URL from backend_infra state using State Account credentials
ECR_URL=$(aws s3 cp "s3://$BACKEND_BUCKET/$STATE_KEY" - 2>/dev/null | jq -r '.outputs.ecr_url.value' || echo "")

if [ -z "$ECR_URL" ] || [ "$ECR_URL" = "null" ]; then
    print_error "Could not retrieve ECR URL from backend_infra state."
    print_error "Make sure backend_infra has been deployed and outputs ecr_url."
    exit 1
fi

info "ECR Repository URL: $ECR_URL"

# Extract ECR repository name from URL (format: account.dkr.ecr.region.amazonaws.com/repo-name)
ECR_REPO_NAME=$(echo "$ECR_URL" | awk -F'/' '{print $NF}')
info "ECR Repository Name: $ECR_REPO_NAME"
echo ""

# ECR is in the Deployment Account, so we need to assume the Deployment Account role
# Check if DEPLOYMENT_ROLE_ARN and EXTERNAL_ID are set (from setup-application.sh)
if [ -z "${DEPLOYMENT_ROLE_ARN:-}" ]; then
    print_error "DEPLOYMENT_ROLE_ARN is not set. Run ./setup-application.sh first."
    exit 1
fi

if [ -z "${EXTERNAL_ID:-}" ]; then
    print_error "EXTERNAL_ID is not set. Run ./setup-application.sh first."
    exit 1
fi

print_info "Assuming Deployment Account role for ECR operations: $DEPLOYMENT_ROLE_ARN"
print_info "Region: $AWS_REGION"

# Assume deployment account role with ExternalId
DEPLOYMENT_ROLE_SESSION_NAME="mirror-images-$(date +%s)"
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

# Extract Deployment Account ID from the ARN
DEPLOYMENT_ACCOUNT_ID=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Account' --output text 2>&1)
if [ $? -ne 0 ]; then
    print_error "Failed to get Deployment Account ID: $DEPLOYMENT_ACCOUNT_ID"
    exit 1
fi

print_success "Successfully assumed Deployment Account role"
print_info "Deployment Account role identity: $DEPLOYMENT_CALLER_ARN"
print_info "Deployment Account ID: $DEPLOYMENT_ACCOUNT_ID"
echo ""

# Function to check if an image tag exists in ECR
check_ecr_image_exists() {
  local tag=$1

  # Query ECR for the specific image tag
  local result
  result=$(aws ecr describe-images \
    --repository-name "$ECR_REPO_NAME" \
    --region "$AWS_REGION" \
    --image-ids imageTag="$tag" \
    --query 'imageDetails[0].imageTags[0]' \
    --output text 2>/dev/null || echo "None")

  if [ "$result" != "None" ] && [ -n "$result" ]; then
    return 0  # Image exists
  else
    return 1  # Image does not exist
  fi
}

# Authenticate Docker to ECR (using Deployment Account ID since ECR is in Deployment Account)
info "Authenticating Docker to ECR..."
if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$DEPLOYMENT_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" 2>/dev/null; then
  print_success "Docker authenticated to ECR"
else
  print_error "Failed to authenticate Docker to ECR"
  exit 1
fi
echo ""

# Define images to mirror with specific tags
# Format: "source_image:tag ecr_tag"
# Note: Using 'latest' tag for Bitnami images as other tags use SHA values
IMAGES=(
  "bitnami/redis:latest redis-latest"
  "bitnami/postgresql:latest postgresql-latest"
  "osixia/openldap:1.5.0 openldap-1.5.0"
)

info "Checking which images need to be mirrored..."
echo ""

IMAGES_TO_MIRROR=()
IMAGES_ALREADY_EXIST=()

for image_spec in "${IMAGES[@]}"; do
  read -r SOURCE_IMAGE ECR_TAG <<< "$image_spec"

  if check_ecr_image_exists "$ECR_TAG"; then
    info "✓ Image already exists in ECR: $ECR_TAG"
    IMAGES_ALREADY_EXIST+=("$ECR_TAG")
  else
    info "✗ Image not found in ECR: $ECR_TAG (will be mirrored)"
    IMAGES_TO_MIRROR+=("$image_spec")
  fi
done

echo ""

if [ ${#IMAGES_ALREADY_EXIST[@]} -gt 0 ]; then
  print_success "${#IMAGES_ALREADY_EXIST[@]} image(s) already exist in ECR - skipping"
fi

if [ ${#IMAGES_TO_MIRROR[@]} -eq 0 ]; then
  print_success "All required images already exist in ECR. No mirroring needed."
  echo ""
  exit 0
fi

info "${#IMAGES_TO_MIRROR[@]} image(s) need to be mirrored to ECR..."
echo ""

for image_spec in "${IMAGES_TO_MIRROR[@]}"; do
  read -r SOURCE_IMAGE ECR_TAG <<< "$image_spec"

  info "Processing: $SOURCE_IMAGE -> $ECR_TAG"

  # Pull image from Docker Hub
  info "  Pulling $SOURCE_IMAGE from Docker Hub..."
  if ! docker pull --platform linux/amd64 "$SOURCE_IMAGE"; then
    print_error "  Failed to pull $SOURCE_IMAGE"
    exit 1
  fi
  print_success "  Successfully pulled $SOURCE_IMAGE"

  # Tag for ECR
  ECR_IMAGE="$ECR_URL:$ECR_TAG"
  info "  Tagging as $ECR_IMAGE..."
  docker tag "$SOURCE_IMAGE" "$ECR_IMAGE"

  # Push to ECR
  info "  Pushing to ECR..."
  if ! docker push "$ECR_IMAGE"; then
    print_error "  Failed to push $ECR_IMAGE"
    exit 1
  fi
  print_success "  Successfully pushed $ECR_IMAGE"

  # Clean up local images to save space
  info "  Cleaning up local images..."
  docker rmi "$SOURCE_IMAGE" "$ECR_IMAGE" 2>/dev/null || true

  echo ""
done

print_success "Image mirroring complete!"
echo ""

# List all images in ECR repository
info "Current images in ECR repository '$ECR_REPO_NAME':"
aws ecr describe-images --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" \
  --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
  --output table 2>/dev/null || print_info "Could not list ECR images"

echo ""
print_success "ECR images are ready for deployment"
