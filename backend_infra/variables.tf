variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Name added to all resources"
  type        = string
}

variable "principal_arn" {
  description = "My ARN"
  type        = string
}

variable "provider_profile" {
  description = "The profile that is going to be used for deployment (for local development)"
  type        = string
  default     = null
}

variable "deployment_account_role_arn" {
  description = "ARN of the IAM role to assume in the deployment account (Account B). Required when using GitHub Actions with multi-account setup."
  type        = string
  default     = null
}

###################### VPC #########################

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "igw_name" {
  description = "The name of the Internet Gateway"
  type        = string
}

variable "ngw_name" {
  description = "The name of the NAT Gateway"
  type        = string
}

variable "route_table_name" {
  description = "The name of the route table"
  type        = string
}

############ Kubernetes Cluster #################

variable "k8s_version" {
  description = "The version of Kubernetes to deploy."
  type        = string
}

variable "cluster_name" {
  description = "The Name of Kubernetes Cluster"
  type        = string
}

##################### Endpoints ##########################

variable "endpoint_sg_name" {
  description = "The name of the endpoint security group"
  type        = string
}

##################### EBS ##########################

variable "ebs_name" {
  description = "The name of the EBS"
  type        = string
}

variable "ebs_claim_name" {
  description = "The name of the EBS claim"
  type        = string
}

##################### ECR ##########################

variable "ecr_name" {
  description = "The name of the ECR"
  type        = string
}

variable "image_tag_mutability" {
  description = "The value that determines if the image is overridable"
  type        = string
}

variable "ecr_lifecycle_policy" {}
