#!/bin/bash
# Script to set Kubernetes environment variables for Terraform Helm/Kubernetes providers
# Fetches cluster name from backend_infra Terraform state
# Works for both local development and CI/CD

set -e

cd "$(dirname "$0")"

echo "Fetching cluster name from backend_infra Terraform state..."

# Check if backend.hcl exists
if [ ! -f "backend.hcl" ]; then
  echo "ERROR: backend.hcl not found. Run ./setup-application.sh first."
  exit 1
fi

# Parse backend configuration
BACKEND_BUCKET=$(grep 'bucket' backend.hcl | sed 's/.*"\(.*\)".*/\1/')
BACKEND_REGION=$(grep 'region' backend.hcl | sed 's/.*"\(.*\)".*/\1/')
BACKEND_KEY="backend_state/terraform.tfstate"

echo "Backend S3 bucket: $BACKEND_BUCKET"
echo "Backend region: $BACKEND_REGION"

# Get current workspace to fetch correct state
WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
echo "Terraform workspace: $WORKSPACE"

# Fetch cluster name from backend_infra state
if [ "$WORKSPACE" = "default" ]; then
  STATE_KEY="$BACKEND_KEY"
else
  STATE_KEY="env:/$WORKSPACE/$BACKEND_KEY"
fi

echo "Fetching cluster name from s3://$BACKEND_BUCKET/$STATE_KEY"

CLUSTER_NAME=$(aws s3 cp "s3://$BACKEND_BUCKET/$STATE_KEY" - 2>/dev/null | jq -r '.outputs.cluster_name.value' || echo "")

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
  echo "ERROR: Could not retrieve cluster name from backend_infra state."
  echo "Make sure backend_infra has been deployed and outputs cluster_name."
  exit 1
fi

echo "Cluster name: $CLUSTER_NAME"

# Get cluster endpoint
echo "Fetching cluster endpoint..."
KUBERNETES_MASTER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$BACKEND_REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "")

if [ -z "$KUBERNETES_MASTER" ]; then
  echo "ERROR: Could not retrieve cluster endpoint. Make sure the cluster exists and you have AWS credentials configured."
  exit 1
fi

echo "Kubernetes Master: $KUBERNETES_MASTER"

# Export environment variables
export KUBERNETES_MASTER
export KUBE_CONFIG_PATH="${KUBE_CONFIG_PATH:-$HOME/.kube/config}"

echo ""
echo "✅ Environment variables set successfully!"
echo ""
echo "KUBERNETES_MASTER=$KUBERNETES_MASTER"
echo "KUBE_CONFIG_PATH=$KUBE_CONFIG_PATH"
echo ""
echo "To use these variables in your current shell, run:"
echo "  source ./set-k8s-env.sh"
