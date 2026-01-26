locals {
  argocd_role_name       = "${var.prefix}-${var.region}-${var.argocd_role_name_component}-${var.env}"
  argocd_capability_name = "${var.prefix}-${var.region}-${var.argocd_capability_name_component}-${var.env}"

  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

# IAM Trust Policy for ArgoCD Capability Role
data "aws_iam_policy_document" "argocd_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

# IAM Role for ArgoCD Capability
resource "aws_iam_role" "argocd_capability" {
  name = local.argocd_role_name

  assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json

  tags = merge(
    local.tags,
    {
      Name = local.argocd_role_name
    }
  )

  # Force replacement if trust policy changes to ensure AWS validates correctly
  lifecycle {
    create_before_destroy = true
  }
}

# IAM Policy Document for ArgoCD Capability
data "aws_iam_policy_document" "argocd_capability" {
  statement {
    sid    = "EKSDescribe"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeUpdate",
      "eks:ListUpdates"
    ]

    resources = var.iam_policy_eks_resources
  }

  statement {
    sid    = "SecretsManager"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]

    resources = var.iam_policy_secrets_manager_resources
  }

  statement {
    sid    = "CodeConnections"
    effect = "Allow"

    actions = [
      "codeconnections:ListConnections",
      "codeconnections:GetConnection"
    ]

    resources = var.iam_policy_code_connections_resources
  }

  dynamic "statement" {
    for_each = var.enable_ecr_access ? [1] : []
    content {
      sid    = "ECRAccess"
      effect = "Allow"

      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]

      resources = var.iam_policy_ecr_resources
    }
  }

  dynamic "statement" {
    for_each = var.enable_codecommit_access ? [1] : []
    content {
      sid    = "CodeCommitAccess"
      effect = "Allow"

      actions = [
        "codecommit:GitPull",
        "codecommit:GetRepository"
      ]

      resources = var.iam_policy_codecommit_resources
    }
  }
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy" "argocd_capability" {
  name   = "${local.argocd_role_name}-policy"
  role   = aws_iam_role.argocd_capability.id
  policy = data.aws_iam_policy_document.argocd_capability.json
}

# EKS Cluster Data Source
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Create ArgoCD namespace
# The namespace must exist before the EKS Capability can deploy into it
# and before the cluster registration secret can be created
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/instance"   = local.argocd_capability_name
      "app.kubernetes.io/managed-by" = "terraform"
      "eks.capability"               = "argocd"
    }
  }

  lifecycle {
    # Prevent deletion of namespace if it contains resources
    prevent_destroy = false
  }
}

# Wait for IAM role to propagate before creating EKS capability
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role.argocd_capability,
    aws_iam_role_policy.argocd_capability
  ]

  create_duration = "60s"
}

# EKS Capability for ArgoCD
resource "aws_eks_capability" "argocd" {
  cluster_name    = var.cluster_name
  capability_name = local.argocd_capability_name
  type            = "ARGOCD"

  role_arn                  = aws_iam_role.argocd_capability.arn
  delete_propagation_policy = var.delete_propagation_policy

  configuration {
    argo_cd {
      namespace = var.argocd_namespace

      aws_idc {
        idc_instance_arn = var.idc_instance_arn
        idc_region       = var.idc_region
      }

      dynamic "rbac_role_mapping" {
        for_each = var.rbac_role_mappings
        content {
          role = rbac_role_mapping.value.role

          dynamic "identity" {
            for_each = rbac_role_mapping.value.identities
            content {
              id   = identity.value.id
              type = identity.value.type
            }
          }
        }
      }

      dynamic "network_access" {
        for_each = length(var.argocd_vpce_ids) > 0 ? [1] : []
        content {
          vpce_ids = var.argocd_vpce_ids
        }
      }
    }
  }

  tags = merge(
    local.tags,
    {
      Name                 = local.argocd_capability_name
      "eks:cluster"        = var.cluster_name
      "eks:capabilityType" = "ARGOCD"
    }
  )

  depends_on = [
    kubernetes_namespace_v1.argocd,
    aws_iam_role.argocd_capability,
    aws_iam_role_policy.argocd_capability,
    time_sleep.wait_for_iam_propagation
  ]
}

# Wait for ArgoCD capability to be fully deployed and ACTIVE
# This ensures proper deployment ordering when ArgoCD is enabled
resource "time_sleep" "wait_for_argocd" {
  create_duration = "5m" # Wait 5 minutes for ArgoCD capability to be ready

  depends_on = [aws_eks_capability.argocd]
}

# External data source to query ArgoCD capability details via AWS CLI
# This automatically retrieves server_url and status without manual CLI commands
# Uses assume-github-role.sh to assume the correct deployment account role based on var.env
data "external" "argocd_capability" {
  program = ["bash", "-c", <<-EOT
    set -u -o pipefail
    export AWS_PAGER=""

    # Always return strings
    SERVER_URL=""
    STATUS=""
    ERR=""

    # Map env -> account type
    ENV_LOWER="$(echo "${var.env}" | tr '[:upper:]' '[:lower:]')"
    if [ "$ENV_LOWER" = "prod" ]; then
      ACCOUNT_TYPE="prod"
    else
      ACCOUNT_TYPE="dev"
    fi

    # Locate the assume script (prefer root module dir)
    SCRIPT_PATH="${path.root}/assume-github-role.sh"
    if [ ! -x "$SCRIPT_PATH" ]; then
      SCRIPT_PATH="./assume-github-role.sh"
    fi

    if [ ! -x "$SCRIPT_PATH" ]; then
      ERR="assume_script_not_found"
    fi

    # Ensure jq exists (your assume script requires it anyway)
    if [ -z "$ERR" ] && ! command -v jq >/dev/null 2>&1; then
      ERR="jq_not_found"
    fi

    # Assume role (silence all output so nothing breaks JSON)
    if [ -z "$ERR" ]; then
      TMP="$(mktemp 2>/dev/null || echo "/tmp/argocd_assume_$$")"
      if ! source "$SCRIPT_PATH" "$ACCOUNT_TYPE" >"$TMP" 2>&1; then
        MSG="$(head -c 400 "$TMP" 2>/dev/null | tr -d '\n\r' || true)"
        ERR="failed_to_assume_role:$${MSG}"
      fi
      rm -f "$TMP" 2>/dev/null || true
    fi

    # Query capability (default null/missing to empty string)
    if [ -z "$ERR" ]; then
      TMP="$(mktemp 2>/dev/null || echo "/tmp/argocd_describe_$$")"
      RESULT="$(aws eks describe-capability \
        --cluster-name "${var.cluster_name}" \
        --capability-name "${local.argocd_capability_name}" \
        --region "${var.region}" \
        --output json \
        --query 'capability.{server_url:(configuration.argoCd.serverUrl || `""`),status:(status || `""`)}' \
        2>"$TMP")"
      RC=$?

      if [ $RC -ne 0 ]; then
        MSG="$(head -c 400 "$TMP" 2>/dev/null | tr -d '\n\r' || true)"
        ERR="describe_failed:$${MSG}"
      else
        SERVER_URL="$(echo "$RESULT" | jq -r '.server_url // ""' 2>/dev/null || echo "")"
        STATUS="$(echo "$RESULT" | jq -r '.status // ""' 2>/dev/null || echo "")"
      fi

      rm -f "$TMP" 2>/dev/null || true
    fi

    # Emit ONLY JSON (string values). Never fail Terraform.
    jq -n \
      --arg server_url "$SERVER_URL" \
      --arg status "$STATUS" \
      --arg error "$ERR" \
      '{server_url:$server_url,status:$status,error:$error}'

    exit 0
  EOT
  ]

  query      = { wait_for = aws_eks_capability.argocd.arn }
  depends_on = [time_sleep.wait_for_argocd]
}

# Cluster Registration Secret
resource "kubernetes_secret" "argocd_local_cluster" {
  metadata {
    name      = var.local_cluster_secret_name
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name    = var.local_cluster_secret_name
    server  = data.aws_eks_cluster.this.arn
    project = var.argocd_project_name
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace_v1.argocd,
    aws_eks_capability.argocd
  ]
}
