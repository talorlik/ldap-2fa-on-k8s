variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for IRSA"
  type        = string
}

variable "sender_email" {
  description = "Email address to send verification emails from (must be verified in SES)"
  type        = string
}

variable "sender_domain" {
  description = "Domain to verify in SES for sending emails. If null, will verify sender_email as individual address."
  type        = string
  default     = null
}

variable "iam_role_name" {
  description = "Name component for the SES IAM role"
  type        = string
  default     = "ses-sender"
}

variable "service_account_namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "ldap-2fa"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "ldap-2fa-backend"
}

variable "route53_zone_id" {
  description = "Route53 zone ID for domain verification records (optional, for domain verification)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
