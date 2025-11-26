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