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

print_header "Monitoring Application Deployments for $ENVIRONMENT in $REGION"

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
    --role-session-name "MonitorApplication-$ENVIRONMENT" \
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
    --role-session-name "MonitorApplication-State" \
    --duration-seconds 3600 \
    --output json)

STATE_ACCESS_KEY_ID=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
STATE_SECRET_ACCESS_KEY=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
STATE_SESSION_TOKEN=$(echo "$STATE_CREDENTIALS" | jq -r '.Credentials.SessionToken')

# Get backend bucket name and prefix from GitHub repository variables or environment
# BACKEND_PREFIX is the backend_infra state key (e.g. backend_state/terraform.tfstate)
if ! command -v gh &> /dev/null; then
    # Fallback: try to get from environment or prompt user
    if [ -z "${BACKEND_BUCKET_NAME:-}" ]; then
        read -p "Enter backend bucket name: " BACKEND_BUCKET
    else
        BACKEND_BUCKET="$BACKEND_BUCKET_NAME"
    fi
    if [ -z "${BACKEND_PREFIX:-}" ]; then
        read -p "Enter backend state prefix (e.g. backend_state/terraform.tfstate): " BACKEND_PREFIX
    fi
else
    # Uses current repository when run from repo root or with gh auth
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

# Download state file to get cluster name (correct TF state path for backend_infra workspace)
STATE_S3_KEY="env:/${REGION}-${ENVIRONMENT}/${BACKEND_PREFIX}"
TEMP_STATE_FILE=$(mktemp)
AWS_ACCESS_KEY_ID="$STATE_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$STATE_SECRET_ACCESS_KEY" \
AWS_SESSION_TOKEN="$STATE_SESSION_TOKEN" \
aws s3 cp "s3://${BACKEND_BUCKET}/${STATE_S3_KEY}" "$TEMP_STATE_FILE"

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
            "PostgreSQL Helm Release")
                echo "=== Helm Releases (ldap-2fa namespace) ==="
                helm list -n ldap-2fa 2>&1 || true
                local release_name
                release_name=$(helm list -n ldap-2fa -o json 2>/dev/null | jq -r '.[] | select(.name | contains("postgresql")) | .name' 2>/dev/null | head -1 || true)
                if [ -n "${release_name:-}" ]; then
                    echo ""
                    echo "=== Helm History: $release_name ==="
                    helm history "$release_name" -n ldap-2fa 2>&1 || true
                fi
                echo ""
                echo "=== Recent Events (ldap-2fa namespace, warnings/errors) ==="
                kubectl get events -n ldap-2fa --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "PostgreSQL Pods")
                echo "=== Pod Descriptions ==="
                kubectl describe pods -n ldap-2fa -l app.kubernetes.io/name=postgresql 2>&1 || true
                echo ""
                echo "=== Pod Logs (last 100 lines) ==="
                for pod in $(kubectl get pods -n ldap-2fa -l app.kubernetes.io/name=postgresql -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n ldap-2fa --tail=100 --all-containers 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (ldap-2fa namespace, warnings/errors) ==="
                kubectl get events -n ldap-2fa --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "Redis Helm Release")
                echo "=== Helm Releases (redis namespace) ==="
                helm list -n redis 2>&1 || true
                local release_name
                release_name=$(helm list -n redis -o json 2>/dev/null | jq -r '.[] | select(.name | contains("redis")) | .name' 2>/dev/null | head -1 || true)
                if [ -n "${release_name:-}" ]; then
                    echo ""
                    echo "=== Helm History: $release_name ==="
                    helm history "$release_name" -n redis 2>&1 || true
                fi
                echo ""
                echo "=== Recent Events (redis namespace, warnings/errors) ==="
                kubectl get events -n redis --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "Redis Pods")
                echo "=== Pod Descriptions ==="
                kubectl describe pods -n redis -l app.kubernetes.io/name=redis 2>&1 || true
                echo ""
                echo "=== Pod Logs (last 100 lines) ==="
                for pod in $(kubectl get pods -n redis -l app.kubernetes.io/name=redis -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n redis --tail=100 --all-containers 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (redis namespace, warnings/errors) ==="
                kubectl get events -n redis --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "2FA Backend Pods")
                echo "=== Pod Descriptions ==="
                kubectl describe pods -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend 2>&1 || true
                echo ""
                echo "=== Pod Logs (last 100 lines) ==="
                for pod in $(kubectl get pods -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n 2fa-app --tail=100 --all-containers 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (2fa-app namespace, warnings/errors) ==="
                kubectl get events -n 2fa-app --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "2FA Frontend Pods")
                echo "=== Pod Descriptions ==="
                kubectl describe pods -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-frontend 2>&1 || true
                echo ""
                echo "=== Pod Logs (last 100 lines) ==="
                for pod in $(kubectl get pods -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-frontend -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n 2fa-app --tail=100 --all-containers 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (2fa-app namespace, warnings/errors) ==="
                kubectl get events -n 2fa-app --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "Backend Namespace Secrets")
                echo "=== All Secrets in 2fa-app namespace ==="
                kubectl get secrets -n 2fa-app 2>&1 || true
                echo ""
                echo "=== Expected secrets: ldap-admin-secret, postgresql-secret, redis-secret ==="
                for secret in ldap-admin-secret postgresql-secret redis-secret; do
                    if kubectl get secret "$secret" -n 2fa-app &> /dev/null; then
                        echo "  ✓ $secret exists"
                    else
                        echo "  ✗ $secret NOT FOUND"
                    fi
                done
                ;;
            "Admin-Seed Job")
                echo "=== Job Description ==="
                kubectl describe job admin-seed-job -n 2fa-app 2>&1 || true
                echo ""
                echo "=== Job Pod Logs ==="
                for pod in $(kubectl get pods -n 2fa-app -l app.kubernetes.io/name=admin-seed -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n 2fa-app --tail=200 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (2fa-app namespace, warnings/errors) ==="
                kubectl get events -n 2fa-app --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "ArgoCD Applications")
                echo "=== ArgoCD Application Details ==="
                for app_name in ldap-2fa-backend ldap-2fa-frontend; do
                    echo "--- $app_name ---"
                    kubectl describe application "$app_name" -n argocd 2>&1 || echo "Not found"
                done
                echo ""
                echo "=== Recent Events (argocd namespace, warnings/errors) ==="
                kubectl get events -n argocd --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
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
        echo "Layer:         application"
        echo "Region:        $REGION"
        echo "Environment:   $ENVIRONMENT"
        echo "Cluster:       $CLUSTER_NAME"
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

        # Informational sections
        if [ -f "$REPORT_DIR/informational.txt" ] && [ -s "$REPORT_DIR/informational.txt" ]; then
            echo ""
            echo "============================================="
            echo "INFORMATIONAL (collected once)"
            echo "============================================="
            strip_ansi < "$REPORT_DIR/informational.txt"
        fi

        echo ""
        echo "============================================="
        echo "PROJECT CONTEXT"
        echo "============================================="
        echo "Repository: ldap-2fa-on-k8s"
        echo "Layer:      application"
        echo "Key files for investigation:"
        echo "  - application/main.tf"
        echo "  - application/variables.tf"
        echo "  - application/variables.tfvars"
        echo "  - application/providers.tf"
        echo "  - application/modules/postgresql/"
        echo "  - application/modules/redis/"
        echo "  - application/modules/ses/"
        echo "  - application/modules/sns/"
        echo "  - application/modules/argocd_app/"
        echo "  - application/helm/postgresql-values.tpl.yaml"
        echo "  - application/helm/redis-values.tpl.yaml"
        echo "  - application/backend/helm/ldap-2fa-backend/"
        echo "  - application/frontend/helm/ldap-2fa-frontend/"
        echo "  - application/backend/src/"
        echo "  - application/backend/Dockerfile"
        echo "  - application/frontend/Dockerfile"

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

# Function to check Kubernetes secrets
check_secrets() {
    local namespace=$1
    local resource_name=$2
    shift 2
    local secret_names=("$@")

    print_header "Checking Kubernetes Secrets: $resource_name"

    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace '$namespace' does not exist"
        return 1
    fi

    local all_ok=true
    for secret_name in "${secret_names[@]}"; do
        if kubectl get secret -n "$namespace" "$secret_name" &> /dev/null; then
            print_success "Secret '$secret_name' exists in namespace '$namespace'"
        else
            print_warning "Secret '$secret_name' NOT found in namespace '$namespace'"
            all_ok=false
        fi
    done

    if [ "$all_ok" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to check admin-seed job
check_admin_seed_job() {
    local namespace=$1

    print_header "Checking Admin-Seed Job"

    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace '$namespace' does not exist"
        return 1
    fi

    local job=$(kubectl get job admin-seed-job -n "$namespace" -o json 2>/dev/null)

    if [ -z "$job" ]; then
        print_warning "admin-seed-job not found in namespace '$namespace' (may not be configured)"
        return 0
    fi

    local succeeded=$(echo "$job" | jq -r '.status.succeeded // 0')
    local failed=$(echo "$job" | jq -r '.status.failed // 0')
    local active=$(echo "$job" | jq -r '.status.active // 0')

    echo "Succeeded: $succeeded"
    echo "Failed: $failed"
    echo "Active: $active"

    # Show job pods
    echo ""
    kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=admin-seed" -o wide 2>/dev/null || true

    if [ "$succeeded" -ge 1 ]; then
        print_success "admin-seed-job completed successfully"
        return 0
    elif [ "$active" -ge 1 ]; then
        print_warning "admin-seed-job is still running"
        return 1
    else
        print_warning "admin-seed-job has not completed successfully (failed: $failed)"
        return 1
    fi
}

# Function to check ArgoCD Applications (if ArgoCD is enabled)
check_argocd_applications() {
    print_header "Checking ArgoCD Applications"

    if ! kubectl get namespace argocd &> /dev/null; then
        print_warning "ArgoCD namespace not found - ArgoCD may not be enabled"
        return 0
    fi

    # Check if ArgoCD Application CRD exists
    if ! kubectl api-resources --api-group=argoproj.io 2>/dev/null | grep -q "applications"; then
        print_warning "ArgoCD Application CRD not found - ArgoCD may not be fully deployed"
        return 0
    fi

    local apps_found=false

    for app_name in "ldap-2fa-backend" "ldap-2fa-frontend"; do
        local app=$(kubectl get application "$app_name" -n argocd -o json 2>/dev/null)

        if [ -z "$app" ]; then
            print_warning "ArgoCD Application '$app_name' not found"
            continue
        fi

        apps_found=true
        local health=$(echo "$app" | jq -r '.status.health.status // "Unknown"')
        local sync=$(echo "$app" | jq -r '.status.sync.status // "Unknown"')

        echo "Application: $app_name"
        echo "  Health: $health"
        echo "  Sync:   $sync"

        if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
            print_success "ArgoCD Application '$app_name' is healthy and synced"
        else
            print_warning "ArgoCD Application '$app_name' - health: $health, sync: $sync"
        fi
    done

    if [ "$apps_found" = false ]; then
        print_warning "No ArgoCD Applications found for 2FA app"
        return 1
    fi

    return 0
}

# Monitor all deployments (watch mode: poll each check until healthy or timeout)
STATUS=0
START_TIME=$(date +%s)

print_color "$BLUE" "\nPolling interval: ${POLL_INTERVAL}s | Timeout: $(( TIMEOUT / 60 ))m"

# Check PostgreSQL
wait_for_check "PostgreSQL Helm Release" check_helm_release "ldap-2fa" "postgresql" "PostgreSQL" || STATUS=1
wait_for_check "PostgreSQL Pods" check_pods "ldap-2fa" "app.kubernetes.io/name=postgresql" "PostgreSQL" || STATUS=1

# Check Redis
wait_for_check "Redis Helm Release" check_helm_release "redis" "redis" "Redis" || STATUS=1
wait_for_check "Redis Pods" check_pods "redis" "app.kubernetes.io/name=redis" "Redis" || STATUS=1

# Check 2FA Backend pods
wait_for_check "2FA Backend Pods" check_pods "2fa-app" "app.kubernetes.io/name=ldap-2fa-backend" "2FA Backend" || STATUS=1

# Check 2FA Frontend pods
wait_for_check "2FA Frontend Pods" check_pods "2fa-app" "app.kubernetes.io/name=ldap-2fa-frontend" "2FA Frontend" || STATUS=1

# Check Kubernetes secrets in backend namespace
wait_for_check "Backend Namespace Secrets" check_secrets "2fa-app" "Backend Namespace Secrets" \
    "ldap-admin-secret" \
    "postgresql-secret" \
    "redis-secret" || STATUS=1

# Check admin-seed job
wait_for_check "Admin-Seed Job" check_admin_seed_job "2fa-app" || STATUS=1

# Check ArgoCD Applications
wait_for_check "ArgoCD Applications" check_argocd_applications || STATUS=1

# Informational check (run once after all polling completes)
{
    print_header "Checking 2FA Application Ingress Resources"
    kubectl get ingress -n 2fa-app 2>&1 || print_warning "No Ingress resources found in 2fa-app namespace"
} 2>&1 | tee "$REPORT_DIR/informational.txt"

# Report and summary
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
    print_success "All application deployments are healthy!"
else
    print_warning "Some application deployments have issues. Review the report above for details."
fi

print_color "$BLUE" "\nReport saved to: $REPORT_FILE"
print_color "$BLUE" "Submit this file to an agent for failure investigation and code fix suggestions."

exit $STATUS
