#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Polling configuration (override via environment variables)
POLL_INTERVAL=${POLL_INTERVAL:-30}
TIMEOUT=${TIMEOUT:-1800}  # 30 minutes default

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

print_header "Monitoring Backend Infrastructure for $ENVIRONMENT in $REGION"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install jq to continue."
    exit 1
fi

# Retrieve role ARNs from AWS Secrets Manager (use selected region)
print_color "$BLUE" "Retrieving AWS role ARNs from Secrets Manager..."

# Get github-role secret containing all role ARNs
GITHUB_ROLE_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id github-role \
    --region "$REGION" \
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
    --region "$REGION" \
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
    --role-session-name "MonitorBackendInfra-$ENVIRONMENT" \
    --external-id "$EXTERNAL_ID" \
    --duration-seconds 3600 \
    --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')
export AWS_REGION="$REGION"

print_success "Successfully assumed Deployment Account role"

# Get cluster name from backend_infra state
print_color "$BLUE" "\nRetrieving infrastructure information from backend_infra state..."

# Re-assume state account role to access S3
STATE_CREDENTIALS=$(aws sts assume-role \
    --role-arn "$STATE_ACCOUNT_ROLE_ARN" \
    --role-session-name "MonitorBackendInfra-State" \
    --duration-seconds 3600 \
    --output json)

STATE_ACCESS_KEY_ID=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
STATE_SECRET_ACCESS_KEY=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
STATE_SESSION_TOKEN=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SessionToken')

# Get backend bucket name and prefix from GitHub repository variables or environment
if ! command -v gh &> /dev/null; then
    if [ -z "${BACKEND_BUCKET_NAME:-}" ]; then
        read -p "Enter backend bucket name: " BACKEND_BUCKET
    else
        BACKEND_BUCKET="$BACKEND_BUCKET_NAME"
    fi
    if [ -z "${BACKEND_PREFIX:-}" ]; then
        read -p "Enter backend state prefix (e.g. backend_state/terraform.tfstate): " BACKEND_PREFIX
    fi
else
    BACKEND_BUCKET=$(gh variable list --json name,value --jq '.[] | select(.name == "BACKEND_BUCKET_NAME") | .value' 2>/dev/null || echo "")
    BACKEND_PREFIX=$(gh variable list --json name,value --jq '.[] | select(.name == "BACKEND_PREFIX") | .value' 2>/dev/null || echo "")
    if [ -z "$BACKEND_BUCKET" ]; then
        print_error "BACKEND_BUCKET_NAME variable not found in GitHub repository"
        read -p "Enter backend bucket name: " BACKEND_BUCKET
    fi
    if [ -z "$BACKEND_PREFIX" ]; then
        print_error "BACKEND_PREFIX variable not found in GitHub repository"
        read -p "Enter backend state prefix (e.g. backend_state/terraform.tfstate): " BACKEND_PREFIX
    fi
fi

# Allow environment override
BACKEND_BUCKET="${BACKEND_BUCKET_NAME:-$BACKEND_BUCKET}"
BACKEND_PREFIX="${BACKEND_PREFIX:-backend_state/terraform.tfstate}"

if [ -z "$BACKEND_BUCKET" ]; then
    print_error "Backend bucket name is required"
    exit 1
fi
if [ -z "$BACKEND_PREFIX" ]; then
    print_error "Backend state prefix (BACKEND_PREFIX) is required"
    exit 1
fi
print_success "Backend bucket: $BACKEND_BUCKET"
print_success "Backend state prefix: $BACKEND_PREFIX"

# Download state file to get resource identifiers
STATE_S3_KEY="env:/${REGION}-${ENVIRONMENT}/${BACKEND_PREFIX}"
TEMP_STATE_FILE=$(mktemp)
AWS_ACCESS_KEY_ID="$STATE_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$STATE_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="$STATE_SESSION_TOKEN" \
aws s3 cp "s3://${BACKEND_BUCKET}/${STATE_S3_KEY}" "$TEMP_STATE_FILE"

CLUSTER_NAME=$(jq -r '.outputs.cluster_name.value' "$TEMP_STATE_FILE")
VPC_ID=$(jq -r '.outputs.vpc_id.value' "$TEMP_STATE_FILE")
ECR_NAME=$(jq -r '.outputs.ecr_name.value' "$TEMP_STATE_FILE")
ECR_URL=$(jq -r '.outputs.ecr_url.value' "$TEMP_STATE_FILE")
rm -f "$TEMP_STATE_FILE"

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
    print_error "Failed to retrieve cluster name from backend_infra state"
    exit 1
fi
print_success "Cluster name: $CLUSTER_NAME"
print_success "VPC ID: $VPC_ID"
print_success "ECR: $ECR_URL"

# Switch back to deployment account credentials
export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

# ===================== Check functions =====================

check_vpc() {
    print_header "Checking VPC"

    local vpc_state
    vpc_state=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" --output json 2>/dev/null)

    if [ -z "$vpc_state" ] || [ "$(echo "$vpc_state" | jq '.Vpcs | length')" -eq 0 ]; then
        print_error "VPC '$VPC_ID' not found"
        return 1
    fi

    local state cidr
    state=$(echo "$vpc_state" | jq -r '.Vpcs[0].State')
    cidr=$(echo "$vpc_state" | jq -r '.Vpcs[0].CidrBlock')
    echo "VPC ID:    $VPC_ID"
    echo "State:     $state"
    echo "CIDR:      $cidr"

    if [ "$state" = "available" ]; then
        print_success "VPC is available"
        return 0
    else
        print_warning "VPC state: $state"
        return 1
    fi
}

check_subnets() {
    print_header "Checking Subnets"

    local subnets subnet_count public_count private_count
    subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>/dev/null)
    subnet_count=$(echo "$subnets" | jq '.Subnets | length')
    public_count=$(echo "$subnets" | jq '[.Subnets[] | select(.MapPublicIpOnLaunch == true)] | length')
    private_count=$(echo "$subnets" | jq '[.Subnets[] | select(.MapPublicIpOnLaunch == false)] | length')

    echo "Total subnets: $subnet_count"
    echo "Public:        $public_count"
    echo "Private:       $private_count"

    if [ "$subnet_count" -ge 4 ]; then
        print_success "Expected subnets are present (2 public + 2 private)"
        return 0
    else
        print_warning "Expected at least 4 subnets, found $subnet_count"
        return 1
    fi
}

check_nat_gateway() {
    print_header "Checking NAT Gateway"

    local nat_gws nat_count
    nat_gws=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --region "$REGION" --output json 2>/dev/null)
    nat_count=$(echo "$nat_gws" | jq '.NatGateways | length')

    if [ "$nat_count" -ge 1 ]; then
        echo "NAT Gateways: $nat_count"
        echo "$nat_gws" | jq -r '.NatGateways[] | "  ID: \(.NatGatewayId)  State: \(.State)  Subnet: \(.SubnetId)"'
        print_success "NAT Gateway is available"
        return 0
    else
        print_warning "No available NAT Gateways found in VPC"
        return 1
    fi
}

check_internet_gateway() {
    print_header "Checking Internet Gateway"

    local igws igw_count
    igws=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>/dev/null)
    igw_count=$(echo "$igws" | jq '.InternetGateways | length')

    if [ "$igw_count" -ge 1 ]; then
        echo "$igws" | jq -r '.InternetGateways[] | "  ID: \(.InternetGatewayId)  State: \(.Attachments[0].State)"'
        print_success "Internet Gateway is attached"
        return 0
    else
        print_warning "No Internet Gateway attached to VPC"
        return 1
    fi
}

check_eks_cluster() {
    print_header "Checking EKS Cluster"

    local cluster_info
    cluster_info=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --output json 2>/dev/null)

    if [ -z "$cluster_info" ]; then
        print_error "EKS cluster '$CLUSTER_NAME' not found"
        return 1
    fi

    local cluster_status cluster_version cluster_endpoint oidc_issuer
    cluster_status=$(echo "$cluster_info" | jq -r '.cluster.status')
    cluster_version=$(echo "$cluster_info" | jq -r '.cluster.version')
    cluster_endpoint=$(echo "$cluster_info" | jq -r '.cluster.endpoint')
    oidc_issuer=$(echo "$cluster_info" | jq -r '.cluster.identity.oidc.issuer // "N/A"')

    echo "Cluster:    $CLUSTER_NAME"
    echo "Status:     $cluster_status"
    echo "Version:    $cluster_version"
    echo "Endpoint:   $cluster_endpoint"
    echo "OIDC:       $oidc_issuer"

    if [ "$cluster_status" != "ACTIVE" ]; then
        print_warning "EKS cluster status: $cluster_status"
        return 1
    fi
    print_success "EKS cluster is ACTIVE"

    if [ "$oidc_issuer" != "N/A" ] && [ -n "$oidc_issuer" ]; then
        print_success "IRSA OIDC provider is configured"
    else
        print_warning "IRSA OIDC provider not configured"
        return 1
    fi

    return 0
}

check_eks_node_pools() {
    print_header "Checking EKS Node Pools"

    local node_pools
    node_pools=$(aws eks list-node-pools --cluster-name "$CLUSTER_NAME" --region "$REGION" --output json 2>/dev/null || echo "")

    if [ -n "$node_pools" ] && [ "$(echo "$node_pools" | jq '.nodePools | length' 2>/dev/null)" -gt 0 ]; then
        echo "$node_pools" | jq -r '.nodePools[]' | while read -r pool; do
            echo "  Node pool: $pool"
        done
        print_success "EKS Auto Mode node pools configured"
        return 0
    fi

    # Fallback: check for managed node groups
    local node_groups
    node_groups=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --output json 2>/dev/null || echo "")
    if [ -n "$node_groups" ] && [ "$(echo "$node_groups" | jq '.nodegroups | length' 2>/dev/null)" -gt 0 ]; then
        echo "$node_groups" | jq -r '.nodegroups[]' | while read -r ng; do
            echo "  Node group: $ng"
        done
        print_success "EKS managed node groups configured"
        return 0
    fi

    print_warning "No node pools or node groups found (EKS Auto Mode may provision nodes on demand)"
    return 1
}

check_vpc_endpoints() {
    print_header "Checking VPC Endpoints"

    local vpc_endpoints endpoint_count available_count
    vpc_endpoints=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>/dev/null)
    endpoint_count=$(echo "$vpc_endpoints" | jq '.VpcEndpoints | length')

    echo "Total VPC endpoints: $endpoint_count"

    if [ "$endpoint_count" -gt 0 ]; then
        echo "$vpc_endpoints" | jq -r '.VpcEndpoints[] | "  \(.ServiceName)  State: \(.State)"'

        available_count=$(echo "$vpc_endpoints" | jq '[.VpcEndpoints[] | select(.State == "available")] | length')
        if [ "$available_count" -eq "$endpoint_count" ]; then
            print_success "All VPC endpoints are available"
            return 0
        else
            print_warning "$available_count/$endpoint_count VPC endpoints are available"
            return 1
        fi
    else
        print_warning "No VPC endpoints found"
        return 1
    fi
}

check_ecr_repository() {
    print_header "Checking ECR Repository"

    local ecr_repo
    ecr_repo=$(aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" --output json 2>/dev/null)

    if [ -z "$ecr_repo" ] || [ "$(echo "$ecr_repo" | jq '.repositories | length')" -eq 0 ]; then
        print_error "ECR repository '$ECR_NAME' not found"
        return 1
    fi

    local ecr_uri ecr_tag_mutability images image_count
    ecr_uri=$(echo "$ecr_repo" | jq -r '.repositories[0].repositoryUri')
    ecr_tag_mutability=$(echo "$ecr_repo" | jq -r '.repositories[0].imageTagMutability')
    echo "Repository: $ECR_NAME"
    echo "URI:        $ecr_uri"
    echo "Tag mutability: $ecr_tag_mutability"

    images=$(aws ecr list-images --repository-name "$ECR_NAME" --region "$REGION" --output json 2>/dev/null)
    image_count=$(echo "$images" | jq '.imageIds | length')
    echo "Images:     $image_count"

    if [ "$image_count" -gt 0 ]; then
        echo ""
        echo "Image tags:"
        echo "$images" | jq -r '.imageIds[] | select(.imageTag != null) | "  \(.imageTag)"' | sort | head -20
    fi

    print_success "ECR repository exists"
    return 0
}

check_cloudwatch_logs() {
    print_header "Checking EKS CloudWatch Logs"

    local log_group log_group_info log_group_count
    log_group="/aws/eks/${CLUSTER_NAME}/cluster"
    log_group_info=$(aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --output json 2>/dev/null)
    log_group_count=$(echo "$log_group_info" | jq '.logGroups | length')

    if [ "$log_group_count" -gt 0 ]; then
        echo "Log group: $log_group"
        local stored_bytes
        stored_bytes=$(echo "$log_group_info" | jq -r '.logGroups[0].storedBytes // 0')
        echo "Stored bytes: $stored_bytes"
        print_success "EKS CloudWatch log group exists"
        return 0
    else
        print_warning "EKS CloudWatch log group not found"
        return 1
    fi
}

# ===================== Report tracking =====================
REPORT_NAMES=()
REPORT_STATUSES=()
REPORT_RETRIES=()
REPORT_DURATIONS=()

# Temp directory for capturing check output and diagnostics
REPORT_DIR=$(mktemp -d)
trap 'rm -rf "$REPORT_DIR"' EXIT

record_result() {
    REPORT_NAMES+=("$1")
    REPORT_STATUSES+=("$2")
    REPORT_RETRIES+=("$3")
    REPORT_DURATIONS+=("$4")
}

# Strip ANSI escape codes from text
strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

# Collect additional diagnostics for failed/timed-out checks
collect_diagnostics() {
    local check_name="$1"
    local diag_file="$2"
    {
        case "$check_name" in
            "VPC")
                echo "=== All VPCs in Region ==="
                aws ec2 describe-vpcs --region "$REGION" --output json 2>&1 || true
                ;;
            "Subnets")
                echo "=== All Subnets in VPC $VPC_ID ==="
                aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>&1 || true
                ;;
            "NAT Gateway")
                echo "=== All NAT Gateways in VPC (including non-available) ==="
                aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>&1 || true
                ;;
            "Internet Gateway")
                echo "=== All Internet Gateways ==="
                aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>&1 || true
                ;;
            "EKS Cluster")
                echo "=== Full EKS Cluster Description ==="
                aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --output json 2>&1 || true
                ;;
            "EKS Node Pools")
                echo "=== EKS Node Pools ==="
                aws eks list-node-pools --cluster-name "$CLUSTER_NAME" --region "$REGION" --output json 2>&1 || true
                echo ""
                echo "=== EKS Node Groups ==="
                aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --output json 2>&1 || true
                ;;
            "VPC Endpoints")
                echo "=== All VPC Endpoints (detailed) ==="
                aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --region "$REGION" --output json 2>&1 || true
                ;;
            "ECR Repository")
                echo "=== ECR Repository Details ==="
                aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" --output json 2>&1 || true
                echo ""
                echo "=== ECR Lifecycle Policy ==="
                aws ecr get-lifecycle-policy --repository-name "$ECR_NAME" --region "$REGION" --output json 2>&1 || true
                ;;
            "CloudWatch Logs")
                echo "=== CloudWatch Log Groups ==="
                aws logs describe-log-groups --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/" --region "$REGION" --output json 2>&1 || true
                ;;
        esac
    } > "$diag_file" 2>&1
}

# Write structured report file for agent investigation
write_report_file() {
    local report_file="$1"
    {
        echo "============================================="
        echo "DEPLOYMENT MONITOR REPORT"
        echo "============================================="
        echo "Layer:         backend_infra"
        echo "Region:        $REGION"
        echo "Environment:   $ENVIRONMENT"
        echo "Cluster:       $CLUSTER_NAME"
        echo "VPC:           $VPC_ID"
        echo "ECR:           $ECR_URL"
        echo "Timestamp:     $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "Timeout:       ${TIMEOUT}s"
        echo "Poll interval: ${POLL_INTERVAL}s"
        echo ""

        # Summary table
        echo "============================================="
        echo "CHECK SUMMARY"
        echo "============================================="
        printf "%-30s  %-12s  %-9s  %-10s\n" "CHECK" "STATUS" "RETRIES" "DURATION"
        printf "%-30s  %-12s  %-9s  %-10s\n" \
            "$(printf '%0.s-' $(seq 1 30))" \
            "$(printf '%0.s-' $(seq 1 12))" \
            "$(printf '%0.s-' $(seq 1 9))" \
            "$(printf '%0.s-' $(seq 1 10))"

        local passed=0 failed=0 timed_out=0
        for i in "${!REPORT_NAMES[@]}"; do
            local name="${REPORT_NAMES[$i]}"
            local status="${REPORT_STATUSES[$i]}"
            local retries="${REPORT_RETRIES[$i]}"
            local dur="${REPORT_DURATIONS[$i]}"
            local dur_min=$(( dur / 60 ))
            local dur_sec=$(( dur % 60 ))
            printf "%-30s  %-12s  %-9s  %-10s\n" "$name" "$status" "$retries" "${dur_min}m ${dur_sec}s"
            case "$status" in
                PASSED)    passed=$((passed + 1)) ;;
                FAILED)    failed=$((failed + 1)) ;;
                TIMED_OUT) timed_out=$((timed_out + 1)) ;;
            esac
        done

        echo ""
        local total=${#REPORT_NAMES[@]}
        echo "Total: $total  |  Passed: $passed  |  Failed: $failed  |  Timed out: $timed_out"
        echo ""

        # Detailed output for each check
        echo "============================================="
        echo "DETAILED CHECK OUTPUT"
        echo "============================================="
        for i in "${!REPORT_NAMES[@]}"; do
            local name="${REPORT_NAMES[$i]}"
            local status="${REPORT_STATUSES[$i]}"
            local output_file="$REPORT_DIR/${i}_output.txt"
            local diag_file="$REPORT_DIR/${i}_diag.txt"

            echo ""
            echo "--- $name [$status] ---"
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                echo "[Check Output]"
                strip_ansi < "$output_file"
            fi

            if [ -f "$diag_file" ] && [ -s "$diag_file" ]; then
                echo ""
                echo "[Diagnostics]"
                strip_ansi < "$diag_file"
            fi
        done

        echo ""
        echo "============================================="
        echo "PROJECT CONTEXT"
        echo "============================================="
        echo "Repository: ldap-2fa-on-k8s"
        echo "Layer:      backend_infra"
        echo "Key files for investigation:"
        echo "  - backend_infra/main.tf"
        echo "  - backend_infra/variables.tf"
        echo "  - backend_infra/variables.tfvars"
        echo "  - backend_infra/providers.tf"
        echo "  - backend_infra/modules/ecr/"
        echo "  - backend_infra/modules/endpoints/"
        echo "  - backend_infra/modules/ebs/"

        echo ""
        echo "============================================="
        echo "END REPORT"
        echo "============================================="
    } > "$report_file"
}

print_report() {
    print_header "Detailed Check Report"

    local name_width=30
    local status_width=12
    local retries_width=9
    local duration_width=10

    printf "%-${name_width}s  %-${status_width}s  %-${retries_width}s  %-${duration_width}s\n" \
        "CHECK" "STATUS" "RETRIES" "DURATION"
    printf "%-${name_width}s  %-${status_width}s  %-${retries_width}s  %-${duration_width}s\n" \
        "$(printf '%0.s-' $(seq 1 $name_width))" \
        "$(printf '%0.s-' $(seq 1 $status_width))" \
        "$(printf '%0.s-' $(seq 1 $retries_width))" \
        "$(printf '%0.s-' $(seq 1 $duration_width))"

    local passed=0 failed=0 timed_out=0
    for i in "${!REPORT_NAMES[@]}"; do
        local name="${REPORT_NAMES[$i]}"
        local status="${REPORT_STATUSES[$i]}"
        local retries="${REPORT_RETRIES[$i]}"
        local dur="${REPORT_DURATIONS[$i]}"
        local dur_min=$(( dur / 60 ))
        local dur_sec=$(( dur % 60 ))
        local dur_str="${dur_min}m ${dur_sec}s"

        local color="$GREEN"
        case "$status" in
            PASSED)    color="$GREEN"; passed=$((passed + 1)) ;;
            FAILED)    color="$RED";   failed=$((failed + 1)) ;;
            TIMED_OUT) color="$RED";   timed_out=$((timed_out + 1)) ;;
        esac

        printf "%-${name_width}s  ${color}%-${status_width}s${NC}  %-${retries_width}s  %-${duration_width}s\n" \
            "$name" "$status" "$retries" "$dur_str"
    done

    echo ""
    local total=${#REPORT_NAMES[@]}
    echo "Total: $total  |  Passed: $passed  |  Failed: $failed  |  Timed out: $timed_out"
}

# Polling helper: retries a check function until it passes or timeout is reached.
# Tracks retries, duration, and final status for the report.
# Captures check output for the report file and collects diagnostics on failure.
# Usage: wait_for_check "Display Name" check_function [args...]
# Returns 0 on success, 1 on timeout/failure.
wait_for_check() {
    local check_name=$1
    shift
    local retries=0
    local check_start=$(date +%s)
    local check_idx=${#REPORT_NAMES[@]}
    local output_file="$REPORT_DIR/${check_idx}_output.txt"
    local diag_file="$REPORT_DIR/${check_idx}_diag.txt"
    : > "$output_file"
    : > "$diag_file"

    while true; do
        if "$@" 2>&1 | tee "$output_file"; then
            local check_duration=$(( $(date +%s) - check_start ))
            record_result "$check_name" "PASSED" "$retries" "$check_duration"
            return 0
        fi

        retries=$((retries + 1))

        local elapsed=$(( $(date +%s) - START_TIME ))
        if [ $elapsed -ge $TIMEOUT ]; then
            local check_duration=$(( $(date +%s) - check_start ))
            record_result "$check_name" "TIMED_OUT" "$retries" "$check_duration"
            print_error "Timeout reached waiting for: $check_name"
            collect_diagnostics "$check_name" "$diag_file"
            return 1
        fi

        local remaining=$(( TIMEOUT - elapsed ))
        local remaining_min=$(( remaining / 60 ))
        local remaining_sec=$(( remaining % 60 ))
        print_color "$YELLOW" "\n$check_name not ready (attempt $retries). Retrying in ${POLL_INTERVAL}s... (${remaining_min}m ${remaining_sec}s remaining)"
        sleep $POLL_INTERVAL
    done
}

# ===================== Monitor all resources (watch mode) =====================
STATUS=0
START_TIME=$(date +%s)

print_color "$BLUE" "\nPolling interval: ${POLL_INTERVAL}s | Timeout: $(( TIMEOUT / 60 ))m"

wait_for_check "VPC" check_vpc || STATUS=1
wait_for_check "Subnets" check_subnets || STATUS=1
wait_for_check "NAT Gateway" check_nat_gateway || STATUS=1
wait_for_check "Internet Gateway" check_internet_gateway || STATUS=1
wait_for_check "EKS Cluster" check_eks_cluster || STATUS=1
wait_for_check "EKS Node Pools" check_eks_node_pools || STATUS=1
wait_for_check "VPC Endpoints" check_vpc_endpoints || STATUS=1
wait_for_check "ECR Repository" check_ecr_repository || STATUS=1
wait_for_check "CloudWatch Logs" check_cloudwatch_logs || STATUS=1

##################### Report and Summary ##########################
print_report

# Write report file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${SCRIPT_DIR}/monitor-report-${REGION}-${ENVIRONMENT}-${REPORT_TIMESTAMP}.txt"
write_report_file "$REPORT_FILE"

ELAPSED=$(( $(date +%s) - START_TIME ))
ELAPSED_MIN=$(( ELAPSED / 60 ))
ELAPSED_SEC=$(( ELAPSED % 60 ))
print_header "Monitoring Summary (completed in ${ELAPSED_MIN}m ${ELAPSED_SEC}s)"
if [ $STATUS -eq 0 ]; then
    print_success "All backend infrastructure resources are healthy!"
else
    print_warning "Some backend infrastructure resources have issues. Review the report above for details."
fi

print_color "$BLUE" "\nReport saved to: $REPORT_FILE"
print_color "$BLUE" "Submit this file to an agent for failure investigation and code fix suggestions."

exit $STATUS
