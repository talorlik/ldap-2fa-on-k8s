terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.21.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  backend "s3" {
    # Backend configuration provided via backend.hcl file
    encrypt      = true
    use_lockfile = true
  }

  required_version = "~> 1.14.0"
}

provider "aws" {
  region = var.region

  # Assume role in deployment account (Account B) if role ARN is provided
  # This allows GitHub Actions to authenticate with Account A (for state)
  # while Terraform provider uses Account B (for resource deployment)
  # ExternalId is required for security when assuming cross-account roles
  dynamic "assume_role" {
    for_each = var.deployment_account_role_arn != null ? [1] : []
    content {
      role_arn    = var.deployment_account_role_arn
      external_id = var.deployment_account_external_id
    }
  }
}

# Provider alias for state account (where Route53 hosted zone and Private CA reside)
provider "aws" {
  alias  = "state_account"
  region = var.region

  # Assume role in state account if role ARN is provided
  # This allows querying Route53 hosted zones from the state account
  # while deploying resources to the deployment account
  # Note: ACM certificates are in deployment accounts (issued from Private CA in State Account)
  # Note: ExternalId is not used for state account role assumption (by design)
  dynamic "assume_role" {
    for_each = var.state_account_role_arn != null ? [1] : []
    content {
      role_arn = var.state_account_role_arn
    }
  }
}

# Read backend_infra backend.hcl to get bucket, region, and state key (BACKEND_PREFIX)
# All remote state information comes from backend_infra since that's where the state is stored
data "local_file" "backend_infra_backend_config" {
  filename = "${path.module}/../backend_infra/backend.hcl"
}

locals {
  # Parse backend_infra backend.hcl to extract bucket, region, and key
  # backend.hcl format: bucket = "value", region = "value", key = "value"
  # If backend.hcl doesn't exist, these will be null and remote state won't be used
  backend_bucket = try(
    regex("bucket\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_infra_backend_config.content)[0],
    null
  )

  # Parse backend_infra backend.hcl to get BACKEND_PREFIX
  # This ensures backend_infra uses its own prefix from repository variable
  backend_key = try(
    regex("key\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_infra_backend_config.content)[0],
    "backend_state/terraform.tfstate" # fallback if backend.hcl doesn't exist
  )

  backend_region = try(
    regex("region\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_infra_backend_config.content)[0],
    var.region
  )

  # Determine workspace name: use provided variable or derive from region and env
  # This matches the workspace naming convention used in scripts: ${region}-${env}
  # The workspace argument in terraform_remote_state will handle the workspace prefix automatically
  terraform_workspace = coalesce(
    var.terraform_workspace,
    "${var.region}-${var.env}"
  )
}

# Retrieve cluster name from backend_infra state
# Uses the workspace argument to automatically handle workspace-prefixed state keys
# Reference: https://developer.hashicorp.com/terraform/language/state/remote-state-data
data "terraform_remote_state" "backend_infra" {
  count   = local.backend_bucket != null ? 1 : 0
  backend = "s3"

  # Use workspace argument to specify which workspace state to access
  # For S3 backend: "default" workspace uses base key, other workspaces use env:/${workspace}/${key}
  # Always pass the workspace value explicitly to ensure correct state lookup
  workspace = local.terraform_workspace

  config = merge(
    {
      bucket = local.backend_bucket
      key    = local.backend_key
      region = local.backend_region
    },
    # Add assume_role block to assume state account role when accessing remote state
    # This allows cross-account state access without requiring provider configuration
    # Note: Terraform 1.6.0+ requires assume_role block instead of top-level role_arn
    var.state_account_role_arn != null ? {
      assume_role = {
        role_arn = var.state_account_role_arn
      }
    } : {}
  )
}

locals {
  # Get cluster name from remote state if available, otherwise use provided value or calculate it
  cluster_name = coalesce(
    try(data.terraform_remote_state.backend_infra[0].outputs.cluster_name, null),
    var.cluster_name,
    "${var.prefix}-${var.region}-${var.cluster_name_component}-${var.env}"
  )
}

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
