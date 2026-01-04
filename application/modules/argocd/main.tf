locals {
  argocd_role_name       = "${var.prefix}-${var.region}-${var.argocd_role_name_component}-${var.env}"
  argocd_capability_name = "${var.prefix}-${var.region}-${var.argocd_capability_name_component}-${var.env}"

  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

# IAM Role for ArgoCD Capability
resource "aws_iam_role" "argocd_capability" {
  name = local.argocd_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = local.argocd_role_name
    }
  )
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
    aws_iam_role.argocd_capability
  ]
}

# External data source to query ArgoCD capability details via AWS CLI
# This automatically retrieves server_url and status without manual CLI commands
data "external" "argocd_capability" {
  program = ["bash", "-c", <<-EOT
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
      echo '{"server_url":"","status":"","error":"jq is required but not installed"}' >&2
      exit 1
    fi

    # Query the capability
    result=$(aws eks describe-capability \
      --cluster-name "${var.cluster_name}" \
      --capability-name "${local.argocd_capability_name}" \
      --capability-type ARGOCD \
      --region "${var.region}" \
      2>&1) || {
      # If capability doesn't exist yet or command failed, return empty values
      echo '{"server_url":"","status":""}'
      exit 0
    }

    # Extract and format as JSON using jq
    echo "$result" | jq -c '{
      server_url: (.capability.configuration.argoCd.serverUrl // .configuration.argoCd.serverUrl // ""),
      status: (.capability.status // .status // "")
    }' 2>/dev/null || echo '{"server_url":"","status":""}'
  EOT
  ]

  depends_on = [aws_eks_capability.argocd]
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
    name    = base64encode(var.local_cluster_secret_name)
    server  = base64encode(data.aws_eks_cluster.this.arn)
    project = base64encode(var.argocd_project_name)
  }

  type = "Opaque"

  depends_on = [
    aws_eks_capability.argocd
  ]
}
