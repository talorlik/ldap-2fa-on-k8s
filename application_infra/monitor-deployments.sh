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

print_header "Monitoring Deployments for $ENVIRONMENT in $REGION"

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
# Parallel arrays to track per-check results
REPORT_NAMES=()
REPORT_STATUSES=()
REPORT_RETRIES=()
REPORT_DURATIONS=()

# Temp directory for capturing check output and diagnostics
REPORT_DIR=$(mktemp -d)
trap 'rm -rf "$REPORT_DIR"' EXIT

# Record a check result into the report arrays.
# Usage: record_result "Check Name" "PASSED|FAILED|TIMED_OUT" retries duration_secs
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
            "ArgoCD Capability")
                echo "=== Pod Descriptions (argocd namespace) ==="
                kubectl describe pods -n argocd 2>&1 || true
                echo ""
                echo "=== Recent Events (argocd namespace, warnings/errors) ==="
                kubectl get events -n argocd --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "OpenLDAP Helm Release")
                echo "=== Helm Releases (ldap namespace) ==="
                helm list -n ldap 2>&1 || true
                local release_name
                release_name=$(helm list -n ldap -o json 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || true)
                if [ -n "${release_name:-}" ]; then
                    echo ""
                    echo "=== Helm History: $release_name ==="
                    helm history "$release_name" -n ldap 2>&1 || true
                fi
                echo ""
                echo "=== Recent Events (ldap namespace, warnings/errors) ==="
                kubectl get events -n ldap --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
                ;;
            "OpenLDAP Pods")
                echo "=== Pod Descriptions (ldap namespace) ==="
                kubectl describe pods -n ldap -l app.kubernetes.io/name=openldap-stack-ha 2>&1 || true
                echo ""
                echo "=== Pod Logs (last 100 lines per container) ==="
                for pod in $(kubectl get pods -n ldap -l app.kubernetes.io/name=openldap-stack-ha -o name 2>/dev/null); do
                    echo "--- $pod ---"
                    kubectl logs "$pod" -n ldap --tail=100 --all-containers 2>&1 || true
                done
                echo ""
                echo "=== Recent Events (ldap namespace, warnings/errors) ==="
                kubectl get events -n ldap --sort-by=.lastTimestamp --field-selector=type!=Normal 2>&1 || true
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
        echo "Layer:         application_infra"
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
        echo "Layer:      application_infra"
        echo "Key files for investigation:"
        echo "  - application_infra/main.tf"
        echo "  - application_infra/variables.tf"
        echo "  - application_infra/variables.tfvars"
        echo "  - application_infra/providers.tf"
        echo "  - application_infra/modules/openldap/"
        echo "  - application_infra/modules/alb/"
        echo "  - application_infra/modules/argocd/"
        echo "  - application_infra/modules/network-policies/"
        echo "  - application_infra/helm/openldap-values.tpl.yaml"
        echo "  - application_infra/charts/openldap-stack-ha/"

        echo ""
        echo "============================================="
        echo "END REPORT"
        echo "============================================="
    } > "$report_file"
}

# Print the final report table.
print_report() {
    print_header "Detailed Check Report"

    # Column widths
    local name_width=30
    local status_width=12
    local retries_width=9
    local duration_width=10

    # Header
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

# Monitor all deployments (watch mode: poll each check until healthy or timeout)
STATUS=0
START_TIME=$(date +%s)

print_color "$BLUE" "\nPolling interval: ${POLL_INTERVAL}s | Timeout: $(( TIMEOUT / 60 ))m"

# Check ArgoCD Capability
wait_for_check "ArgoCD Capability" check_argocd_capability || STATUS=1

# Check OpenLDAP
wait_for_check "OpenLDAP Helm Release" check_helm_release "ldap" "openldap" "OpenLDAP" || STATUS=1
wait_for_check "OpenLDAP Pods" check_pods "ldap" "app.kubernetes.io/name=openldap-stack-ha" "OpenLDAP" || STATUS=1

# Informational checks (run once after all polling completes)
{
    print_header "Checking Ingress Resources"
    kubectl get ingress -A 2>&1 || true

    print_header "Checking Application Load Balancers"
    aws elbv2 describe-load-balancers --region "$REGION" --output table 2>&1 || true
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
    print_success "All deployments are healthy!"
else
    print_warning "Some deployments have issues. Review the report above for details."
fi

print_color "$BLUE" "\nReport saved to: $REPORT_FILE"
print_color "$BLUE" "Submit this file to an agent for failure investigation and code fix suggestions."

exit $STATUS
