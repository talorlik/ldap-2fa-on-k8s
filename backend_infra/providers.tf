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
  }

  backend "s3" {
    # Backend configuration provided via backend.hcl file
    encrypt      = true
    use_lockfile = true
  }

  required_version = "= 1.14.0"
}

provider "aws" {
  region = var.region

  # Assume role in deployment account (Account B) if role ARN is provided
  # This allows GitHub Actions to authenticate with Account A (for state)
  # while Terraform provider uses Account B (for resource deployment)
  dynamic "assume_role" {
    for_each = var.deployment_account_role_arn != null ? [1] : []
    content {
      role_arn = var.deployment_account_role_arn
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
