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

variable "ebs_name" {
  description = "The name of the EBS"
  type        = string
}

variable "ebs_claim_name" {
  description = "The name of the EBS claim"
  type        = string
}
