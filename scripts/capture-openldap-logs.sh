#!/usr/bin/env bash
# Capture OpenLDAP pod logs and describe output from the ldap namespace.
# Use when openldap_helm_atomic = false and the release has failed, so pods
# are still present and logs can be collected before manual cleanup.
#
# Usage: ./scripts/capture-openldap-logs.sh [namespace]
#   namespace defaults to "ldap"
# Output: ./openldap-logs/capture-YYYYMMDD-HHMMSS/ (or OPENLDAP_LOGS_DIR)

set -euo pipefail

NAMESPACE="${1:-ldap}"
OUTPUT_BASE="${OPENLDAP_LOGS_DIR:-$(pwd)/openldap-logs}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="$OUTPUT_BASE/capture-$TIMESTAMP"

mkdir -p "$OUTPUT_DIR"
echo "Capturing OpenLDAP logs to $OUTPUT_DIR"

# Pod list and describe
kubectl get pods -n "$NAMESPACE" -o wide > "$OUTPUT_DIR/pods.txt" 2>&1 || true
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=openldap-stack-ha -o yaml > "$OUTPUT_DIR/pods-openldap.yaml" 2>&1 || true

for pod in $(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=openldap-stack-ha -o name 2>/dev/null); do
  name="${pod#pod/}"
  kubectl describe "$pod" -n "$NAMESPACE" > "$OUTPUT_DIR/describe-$name.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --tail=1000 > "$OUTPUT_DIR/logs-$name.txt" 2>&1 || true
done

# ConfigMap env (LDAP_DOMAIN etc.)
kubectl get configmap -n "$NAMESPACE" -l "app.kubernetes.io/name=openldap-stack-ha" -o name 2>/dev/null | while read -r cm; do
  name="${cm#configmap/}"
  kubectl get "$cm" -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/configmap-$name.yaml" 2>&1 || true
done

# Events
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUTPUT_DIR/events.txt" 2>&1 || true

echo "Done. Logs saved under $OUTPUT_DIR"
