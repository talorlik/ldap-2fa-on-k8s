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

# EKS token exec configuration
# Uses get-eks-token.sh to generate fresh tokens on every Kubernetes API call,
# preventing token expiration during long Terraform operations.
locals {
  eks_exec_env = {
    EKS_CLUSTER_NAME   = module.eks.cluster_name
    EKS_REGION         = var.region
    ASSUME_ROLE_ARN    = var.deployment_account_role_arn != null ? var.deployment_account_role_arn : ""
    ASSUME_EXTERNAL_ID = var.deployment_account_external_id != null ? var.deployment_account_external_id : ""
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "${path.module}/../scripts/get-eks-token.sh"
    env         = local.eks_exec_env
  }
}
