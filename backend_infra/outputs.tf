output "aws_account" {
  description = "The AWS Account ID"
  value       = local.current_account
}

output "region" {
  description = "The AWS region"
  value       = var.region
}

output "env" {
  description = "The Environment e.g. prod"
  value       = var.env
}

output "prefix" {
  description = "The prefix to all names"
  value       = var.prefix
}

###################### VPC ######################
output "vpc_id" {
  description = "The VPC's ID"
  value       = module.vpc.vpc_id
}

output "default_security_group_id" {
  description = "The default security group for the VPC"
  value       = module.vpc.default_security_group_id
}

output "public_subnets" {
  description = "The VPC's associated public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "The VPC's associated private subnets."
  value       = module.vpc.private_subnets
}

output "igw_id" {
  description = "The Internet Gateway's ID"
  value       = module.vpc.igw_id
}

########## Kubernetes Cluster ##############

output "cluster_name" {
  description = "The Name of Kubernetes Cluster"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster API Endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

##################### VPC Endpoints ##########################
output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC endpoints"
  value       = module.endpoints.vpc_endpoint_sg_id
}

output "vpc_endpoint_ssm_id" {
  description = "VPC endpoint ID for SSM"
  value       = module.endpoints.vpc_endpoint_ssm_id
}

output "vpc_endpoint_ssmmessages_id" {
  description = "VPC endpoint ID for SSM Messages"
  value       = module.endpoints.vpc_endpoint_ssmmessages_id
}

output "vpc_endpoint_ec2messages_id" {
  description = "VPC endpoint ID for EC2 Messages"
  value       = module.endpoints.vpc_endpoint_ec2messages_id
}

output "vpc_endpoint_ids" {
  description = "List of all VPC endpoint IDs"
  value       = module.endpoints.vpc_endpoint_ids
}

output "vpc_endpoint_sts_id" {
  description = "VPC endpoint ID for STS (IRSA)"
  value       = module.endpoints.vpc_endpoint_sts_id
}

output "vpc_endpoint_sns_id" {
  description = "VPC endpoint ID for SNS (SMS 2FA)"
  value       = module.endpoints.vpc_endpoint_sns_id
}

##################### ECR ##########################
output "ecr_name" {
  description = "ECR repository name"
  value       = module.ecr.ecr_name
}

output "ecr_arn" {
  description = "ECR repository ARN"
  value       = module.ecr.ecr_arn
}

output "ecr_url" {
  description = "ECR repository URL"
  value       = module.ecr.ecr_url
}

##################### EBS ##########################
# output "ebs_pvc_name" {
#   value = module.ebs.ebs_pvc_name
# }
#
# output "ebs_storage_class_name" {
#   value = module.ebs.ebs_storage_class_name
# }
