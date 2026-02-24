#!/bin/bash

# Imports existing resources into Terraform state when "terraform apply" fails
# with "already exists". Parses the apply error output to find which resources
# failed and runs the appropriate terraform import for each.
#
# Usage: from application_infra/
#   # After apply fails, pass the captured error output (file or stdin)
#   ./import-existing-resources.sh apply-error.log
#   terraform apply -auto-approve terraform.tfplan 2>&1 | tee err.log; ./import-existing-resources.sh err.log
#
#   # With no input (e.g. before apply), proactively imports known resources
#   # that might already exist (ALB IngressClass/IngressClassParams, etc.)
#   ./import-existing-resources.sh
#
# Prerequisites: terraform init, variables.tfvars (or TF_VAR_*). For proactive
# ALB import or when error mentions Kubernetes resources: kubectl configured
# for the EKS cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VARIABLES_FILE="${VARIABLES_FILE:-variables.tfvars}"

if [ ! -f "$VARIABLES_FILE" ]; then
  echo "ERROR: $VARIABLES_FILE not found. Run from application_infra or set VARIABLES_FILE." >&2
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  echo "ERROR: terraform not in PATH." >&2
  exit 1
fi

# Ensure Terraform is initialized
if [ ! -d .terraform ]; then
  echo "INFO: Running terraform init..."
  terraform init -input=false
fi

get_tf_var() {
  terraform console -var-file="$VARIABLES_FILE" -input=false <<< "$1" 2>/dev/null | tr -d '"'
}

# Read error content: from file argument or stdin (if not a TTY)
read_error_content() {
  if [ -n "${1:-}" ] && [ -f "$1" ]; then
    cat "$1"
  elif [ ! -t 0 ]; then
    cat
  else
    return 1
  fi
}

# Parse "already exists" blocks from Terraform error output.
# Extracts resource address (from "with ADDRESS,") and optional name (from "NAME" already exists).
# Outputs one line per resource: ADDRESS\tNAME (NAME may be empty). Uses portable awk.
parse_already_exists() {
  local content="$1"
  echo "$content" | awk '
    BEGIN { addr = "" }
    /[[:space:]]with[[:space:]]+module\./ {
      for (i=1;i<=NF;i++) if ($i == "with" && $(i+1) ~ /^module\./) {
        addr = $(i+1); gsub(/,/, "", addr); break
      }
      next
    }
    /already exists/ {
      if (addr == "") next
      name = ""
      if (match($0, /"[^"]+"[[:space:]]+already exists/)) {
        start = index($0, "\"")
        rest = substr($0, start + 1)
        end = index(rest, "\"")
        if (end > 0) name = substr(rest, 1, end - 1)
      } else if (match($0, /"[^"]+"/)) {
        start = index($0, "\"")
        rest = substr($0, start + 1)
        end = index(rest, "\"")
        if (end > 0) name = substr(rest, 1, end - 1)
      }
      print addr "\t" name
      addr = ""
    }
  '
}

# Import a resource by address and optional name from the error.
# Returns 0 if import was run (and succeeded), non-zero otherwise.
import_resource() {
  local addr="$1"
  local name="$2"
  local import_id=""
  local need_kubectl=""

  case "$addr" in
    module.alb[0].kubernetes_manifest.ingressclassparams_alb)
      if [ -z "$name" ]; then
        prefix=$(get_tf_var 'var.prefix')
        region=$(get_tf_var 'var.region')
        env=$(get_tf_var 'var.env')
        icp_comp=$(get_tf_var 'var.ingressclassparams_alb_name')
        [ -z "$prefix" ] && return 1
        name="${prefix}-${region}-${icp_comp}-${env}"
      fi
      import_id="apiVersion=eks.amazonaws.com/v1,kind=IngressClassParams,name=$name"
      need_kubectl=1
      ;;
    module.alb[0].kubernetes_ingress_class_v1.ingressclass_alb)
      if [ -z "$name" ]; then
        prefix=$(get_tf_var 'var.prefix')
        region=$(get_tf_var 'var.region')
        env=$(get_tf_var 'var.env')
        ic_comp=$(get_tf_var 'var.ingressclass_alb_name')
        [ -z "$prefix" ] && return 1
        name="${prefix}-${region}-${ic_comp}-${env}"
      fi
      import_id="$name"
      need_kubectl=1
      ;;
    module.argocd[0].aws_eks_capability.argocd)
      local cluster_name
      cluster_name=$(get_tf_var 'local.cluster_name')
      if [ -z "$cluster_name" ]; then
        cluster_name=$(get_tf_var 'var.cluster_name')
      fi
      if [ -z "$name" ]; then
        name=$(get_tf_var 'module.argocd[0].argocd_capability_name')
      fi
      if [ -z "$name" ]; then
        prefix=$(get_tf_var 'var.prefix')
        region=$(get_tf_var 'var.region')
        env=$(get_tf_var 'var.env')
        comp=$(get_tf_var 'var.argocd_capability_name_component')
        [ -z "$prefix" ] && return 1
        name="${prefix}-${region}-${comp}-${env}"
      fi
      [ -z "$cluster_name" ] && return 1
      import_id="${cluster_name},${name}"
      ;;
    *)
      echo "No import rule for resource: $addr" >&2
      return 1
      ;;
  esac

  if [ -n "$need_kubectl" ] && ! command -v kubectl &>/dev/null; then
    echo "Skipping $addr: kubectl not in PATH (required for Kubernetes import)." >&2
    return 1
  fi

  echo "Importing $addr (id: $import_id)"
  terraform import -var-file="$VARIABLES_FILE" "$addr" "$import_id"
}

# Proactive import: try known resources that might already exist (no error input).
proactive_import() {
  local imported=0
  local use_alb
  use_alb=$(get_tf_var 'var.use_alb')
  if [ "$use_alb" = "true" ]; then
    local prefix region env ic_comp icp_comp icp_name ic_name
    prefix=$(get_tf_var 'var.prefix')
    region=$(get_tf_var 'var.region')
    env=$(get_tf_var 'var.env')
    ic_comp=$(get_tf_var 'var.ingressclass_alb_name')
    icp_comp=$(get_tf_var 'var.ingressclassparams_alb_name')
    if [ -n "$prefix" ] && [ -n "$region" ] && [ -n "$env" ] && [ -n "$ic_comp" ] && [ -n "$icp_comp" ]; then
      icp_name="${prefix}-${region}-${icp_comp}-${env}"
      ic_name="${prefix}-${region}-${ic_comp}-${env}"
      if command -v kubectl &>/dev/null; then
        if kubectl get "ingressclassparams.eks.amazonaws.com/$icp_name" -o name &>/dev/null; then
          import_resource 'module.alb[0].kubernetes_manifest.ingressclassparams_alb' "$icp_name" && ((imported++)) || true
        fi
        if kubectl get "ingressclass.networking.k8s.io/$ic_name" -o name &>/dev/null; then
          import_resource 'module.alb[0].kubernetes_ingress_class_v1.ingressclass_alb' "$ic_name" && ((imported++)) || true
        fi
      fi
    fi
  fi
  return $imported
}

# Main
ERROR_CONTENT=""
if ! ERROR_CONTENT=$(read_error_content "${1:-}"); then
  echo "No error input provided. Running proactive import for known resources (if any)."
  proactive_import || true
  exit 0
fi

if ! echo "$ERROR_CONTENT" | grep -q 'already exists'; then
  echo "No 'already exists' errors found in input. Nothing to import."
  exit 0
fi

imported=0
seen=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  addr="${line%%$'\t'*}"
  name="${line#*$'\t'}"
  # Deduplicate by address
  if [[ "$seen" == *"|${addr}|"* ]]; then continue; fi
  seen="${seen}|${addr}|"
  if import_resource "$addr" "$name"; then
    ((imported++)) || true
  fi
done < <(parse_already_exists "$ERROR_CONTENT" | sort -u)

if [ "$imported" -eq 0 ]; then
  echo "No resources were imported (unknown resource types or import failed)."
else
  echo "Imported $imported resource(s). Re-run: terraform plan -var-file=$VARIABLES_FILE"
fi
