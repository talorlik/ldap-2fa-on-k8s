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

variable "endpoint_sg_name" {
  description = "The name of the endpoint security group"
  type        = string
}

variable "node_security_group_id" {
  description = "The ID of the node security group"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC (for security group rules)"
  type        = string
}

variable "private_subnets" {
  description = "The IDs of the private subnets"
  type        = list(string)
}

variable "enable_sts_endpoint" {
  description = "Whether to create STS VPC endpoint (required for IRSA)"
  type        = bool
  default     = true
}

variable "enable_sns_endpoint" {
  description = "Whether to create SNS VPC endpoint (required for SMS 2FA)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to add to the resources"
  type        = map(string)
}