terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.21.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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

# Read backend.hcl to get bucket and region for remote state
data "local_file" "backend_config" {
  filename = "${path.module}/backend.hcl"
}

locals {
  # Parse backend.hcl to extract bucket, and region
  # backend.hcl format: bucket = "value", region = "value"
  # If backend.hcl doesn't exist, these will be null and remote state won't be used
  backend_bucket = try(
    regex("bucket\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_config.content)[0],
    null
  )
  backend_key = "backend_state/terraform.tfstate" # backend_infra state key
  backend_region = try(
    regex("region\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_config.content)[0],
    var.region
  )
}

# Retrieve cluster name from backend_infra state
data "terraform_remote_state" "backend_infra" {
  count   = local.backend_bucket != null ? 1 : 0
  backend = "s3"

  config = {
    bucket = local.backend_bucket
    key    = local.backend_key
    region = local.backend_region
  }
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
