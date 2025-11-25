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

variable "deploy_account_profile" {
  description = "The profile that is associated with the account to deploy to"
  type        = string
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