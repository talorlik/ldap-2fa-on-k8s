variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Name added to all resources"
  type        = string
}

variable "ecr_name" {
  description = "The name of the ECR"
  type        = string
}

variable "image_tag_mutability" {
  description = "The value that determines if the image is overridable"
  type        = string
}

variable "policy" {
  type = string
}

variable "tags" {
  type = map(string)
}
