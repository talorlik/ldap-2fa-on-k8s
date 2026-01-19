#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_header() {
    print_color "$BLUE" "\n========================================="
    print_color "$BLUE" "$1"
    print_color "$BLUE" "=========================================\n"
}

print_success() {
    print_color "$GREEN" "✓ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠ $1"
}

print_error() {
    print_color "$RED" "✗ $1"
}

# Prompt for region
echo "Select AWS Region:"
echo "1) us-east-1"
echo "2) us-east-2"
read -p "Enter choice [1-2]: " region_choice

case $region_choice in
    1)
        REGION="us-east-1"
        ;;
    2)
        REGION="us-east-2"
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Prompt for environment
echo ""
echo "Select Environment:"
echo "1) prod"
echo "2) dev"
read -p "Enter choice [1-2]: " env_choice

case $env_choice in
    1)
        ENVIRONMENT="prod"
        ;;
    2)
        ENVIRONMENT="dev"
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

print_header "Monitoring Deployments for $ENVIRONMENT in $REGION"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install jq to continue."
    exit 1
fi

# Retrieve role ARNs from AWS Secrets Manager
print_color "$BLUE" "Retrieving AWS role ARNs from Secrets Manager..."

# Get github-role secret containing all role ARNs
GITHUB_ROLE_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id github-role \
    --region us-east-1 \
    --query 'SecretString' \
    --output text)

if [ -z "$GITHUB_ROLE_SECRET" ]; then
    print_error "Failed to retrieve github-role secret from Secrets Manager"
    exit 1
fi

# Extract role ARNs from JSON secret
STATE_ACCOUNT_ROLE_ARN=$(echo "$GITHUB_ROLE_SECRET" | jq -r '.AWS_STATE_ACCOUNT_ROLE_ARN')
if [ -z "$STATE_ACCOUNT_ROLE_ARN" ] || [ "$STATE_ACCOUNT_ROLE_ARN" = "null" ]; then
    print_error "AWS_STATE_ACCOUNT_ROLE_ARN not found in github-role secret"
    exit 1
fi
print_success "Retrieved State Account role ARN"

# Get deployment account role ARN based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    DEPLOYMENT_ROLE_ARN=$(echo "$GITHUB_ROLE_SECRET" | jq -r '.AWS_PRODUCTION_ACCOUNT_ROLE_ARN')
    DEPLOYMENT_TYPE="production"
else
    DEPLOYMENT_ROLE_ARN=$(echo "$GITHUB_ROLE_SECRET" | jq -r '.AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN')
    DEPLOYMENT_TYPE="development"
fi

if [ -z "$DEPLOYMENT_ROLE_ARN" ] || [ "$DEPLOYMENT_ROLE_ARN" = "null" ]; then
    print_error "Failed to retrieve ${DEPLOYMENT_TYPE} account role ARN from github-role secret"
    exit 1
fi
print_success "Retrieved Deployment Account role ARN ($DEPLOYMENT_TYPE)"

# Get ExternalId
EXTERNAL_ID=$(aws secretsmanager get-secret-value \
    --secret-id external-id \
    --region us-east-1 \
    --query 'SecretString' \
    --output text)

if [ -z "$EXTERNAL_ID" ]; then
    print_error "Failed to retrieve ExternalId from Secrets Manager"
    exit 1
fi
print_success "Retrieved ExternalId for role assumption"

# Assume deployment account role
print_color "$BLUE" "\nAssuming Deployment Account role..."
CREDENTIALS=$(aws sts assume-role \
    --role-arn "$DEPLOYMENT_ROLE_ARN" \
    --role-session-name "MonitorDeployments-$ENVIRONMENT" \
    --external-id "$EXTERNAL_ID" \
    --duration-seconds 3600 \
    --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')
export AWS_REGION="$REGION"

print_success "Successfully assumed Deployment Account role"

# Get cluster name from backend_infra state
print_color "$BLUE" "\nRetrieving cluster information from backend_infra state..."

# Re-assume state account role to access S3
STATE_CREDENTIALS=$(aws sts assume-role \
    --role-arn "$STATE_ACCOUNT_ROLE_ARN" \
    --role-session-name "MonitorDeployments-State" \
    --duration-seconds 3600 \
    --output json)

STATE_ACCESS_KEY_ID=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
STATE_SECRET_ACCESS_KEY=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
STATE_SESSION_TOKEN=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SessionToken')

# Get backend bucket name from GitHub repository variable
# Note: We need to use GitHub CLI to get repository variables
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not found. Installing or using alternative method..."
    # Fallback: try to get from environment or prompt user
    if [ -z "${BACKEND_BUCKET_NAME:-}" ]; then
        read -p "Enter backend bucket name: " BACKEND_BUCKET
    else
        BACKEND_BUCKET="$BACKEND_BUCKET_NAME"
    fi
else
    BACKEND_BUCKET=$(gh variable list --json name,value --jq '.[] | select(.name == "BACKEND_BUCKET_NAME") | .value' 2>/dev/null || echo "")
    if [ -z "$BACKEND_BUCKET" ]; then
        print_error "BACKEND_BUCKET_NAME variable not found in GitHub repository"
        read -p "Enter backend bucket name: " BACKEND_BUCKET
    fi
fi

if [ -z "$BACKEND_BUCKET" ]; then
    print_error "Backend bucket name is required"
    exit 1
fi
print_success "Backend bucket: $BACKEND_BUCKET"

# Download state file to get cluster name
TEMP_STATE_FILE=$(mktemp)
AWS_ACCESS_KEY_ID="$STATE_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$STATE_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="$STATE_SESSION_TOKEN" \
aws s3 cp "s3://${BACKEND_BUCKET}/env:/${REGION}-${ENVIRONMENT}/backend_state/terraform.tfstate" "$TEMP_STATE_FILE"

CLUSTER_NAME=$(jq -r '.outputs.cluster_name.value' "$TEMP_STATE_FILE")
rm -f "$TEMP_STATE_FILE"

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
    print_error "Failed to retrieve cluster name from backend_infra state"
    exit 1
fi
print_success "Cluster name: $CLUSTER_NAME"

# Switch back to deployment account credentials
export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

# Update kubeconfig
print_color "$BLUE" "\nUpdating kubeconfig..."
KUBE_CONFIG_PATH="${HOME}/.kube/config"
mkdir -p "$(dirname "$KUBE_CONFIG_PATH")"

aws eks update-kubeconfig \
    --region "$REGION" \
    --name "$CLUSTER_NAME" \
    --kubeconfig "$KUBE_CONFIG_PATH"

export KUBECONFIG="$KUBE_CONFIG_PATH"
print_success "Kubeconfig updated successfully"

# Function to check pod status
check_pods() {
    local namespace=$1
    local label=$2
    local resource_name=$3
    
    print_header "Checking $resource_name in namespace: $namespace"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace '$namespace' does not exist"
        return 1
    fi
    
    local pods=$(kubectl get pods -n "$namespace" -l "$label" -o json 2>/dev/null)
    
    if [ -z "$pods" ] || [ "$(echo "$pods" | jq '.items | length')" -eq 0 ]; then
        print_warning "No pods found with label '$label' in namespace '$namespace'"
        return 1
    fi
    
    # Count pods by status
    local total=$(echo "$pods" | jq '.items | length')
    local running=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Running")] | length')
    local pending=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Pending")] | length')
    local failed=$(echo "$pods" | jq '[.items[] | select(.status.phase == "Failed")] | length')
    
    echo "Total pods: $total"
    echo "Running: $running"
    echo "Pending: $pending"
    echo "Failed: $failed"
    
    # Show pod details
    echo ""
    kubectl get pods -n "$namespace" -l "$label" -o wide
    
    # Check if all pods are running
    if [ "$running" -eq "$total" ]; then
        print_success "All $resource_name pods are running"
        return 0
    else
        print_warning "Not all $resource_name pods are running"
        return 1
    fi
}

# Function to check helm releases
check_helm_release() {
    local namespace=$1
    local release_name_pattern=$2
    local resource_name=$3
    
    print_header "Checking Helm Release: $resource_name"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace '$namespace' does not exist"
        return 1
    fi
    
    local releases=$(helm list -n "$namespace" -o json 2>/dev/null)
    
    if [ -z "$releases" ] || [ "$(echo "$releases" | jq '. | length')" -eq 0 ]; then
        print_warning "No Helm releases found in namespace '$namespace'"
        return 1
    fi
    
    # Filter releases matching pattern
    local matching_release=$(echo "$releases" | jq -r ".[] | select(.name | contains(\"$release_name_pattern\")) | .name" | head -1)
    
    if [ -z "$matching_release" ]; then
        print_warning "No Helm release matching pattern '$release_name_pattern' found"
        return 1
    fi
    
    echo "Release: $matching_release"
    helm status "$matching_release" -n "$namespace"
    
    local status=$(echo "$releases" | jq -r ".[] | select(.name == \"$matching_release\") | .status")
    
    if [ "$status" = "deployed" ]; then
        print_success "$resource_name is deployed"
        return 0
    else
        print_warning "$resource_name status: $status"
        return 1
    fi
}

# Function to check ArgoCD capability (if enabled)
check_argocd_capability() {
    print_header "Checking ArgoCD Capability"
    
    # Check if ArgoCD namespace exists as a simpler indicator
    if kubectl get namespace argocd &> /dev/null; then
        echo "ArgoCD namespace: argocd"
        
        # Check for ArgoCD pods
        local argocd_pods=$(kubectl get pods -n argocd -o json 2>/dev/null)
        if [ -n "$argocd_pods" ]; then
            local total=$(echo "$argocd_pods" | jq '.items | length')
            local running=$(echo "$argocd_pods" | jq '[.items[] | select(.status.phase == "Running")] | length')
            echo "ArgoCD pods: $running/$total running"
            kubectl get pods -n argocd -o wide
            
            if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
                print_success "ArgoCD is deployed and running"
                return 0
            else
                print_warning "ArgoCD namespace exists but pods are not all running"
                return 1
            fi
        else
            print_warning "ArgoCD namespace exists but no pods found"
            return 1
        fi
    else
        print_warning "ArgoCD namespace not found - ArgoCD may not be enabled"
        return 1
    fi
}

# Monitor all deployments
STATUS=0

# Check ArgoCD Capability
check_argocd_capability || STATUS=1

# Check OpenLDAP
check_helm_release "ldap" "openldap" "OpenLDAP" || STATUS=1
check_pods "ldap" "app.kubernetes.io/name=openldap-stack-ha" "OpenLDAP" || STATUS=1

# Check PostgreSQL
check_helm_release "ldap-2fa" "postgresql" "PostgreSQL" || STATUS=1
check_pods "ldap-2fa" "app.kubernetes.io/name=postgresql" "PostgreSQL" || STATUS=1

# Check Redis
check_helm_release "redis" "redis" "Redis" || STATUS=1
check_pods "redis" "app.kubernetes.io/name=redis" "Redis" || STATUS=1

# Check Ingress resources
print_header "Checking Ingress Resources"
kubectl get ingress -A

# Check Application Load Balancers
print_header "Checking Application Load Balancers"
aws elbv2 describe-load-balancers --region "$REGION" --output table

# Summary
print_header "Monitoring Summary"
if [ $STATUS -eq 0 ]; then
    print_success "All deployments are healthy!"
else
    print_warning "Some deployments have issues. Please review the output above."
fi

exit $STATUS
