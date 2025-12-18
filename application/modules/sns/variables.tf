variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "sns_topic_name" {
  description = "Name component for the SNS topic"
  type        = string
  default     = "2fa-sms"
}

variable "sns_display_name" {
  description = "Display name for the SNS topic (appears in SMS sender)"
  type        = string
  default     = "2FA Verification"
}

variable "iam_role_name" {
  description = "Name component for the IAM role"
  type        = string
  default     = "2fa-sns-publisher"
}

variable "service_account_namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "2fa-app"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "ldap-2fa-backend"
}

variable "configure_sms_preferences" {
  description = "Whether to configure account-level SMS preferences"
  type        = bool
  default     = false
}

variable "sms_sender_id" {
  description = "Default sender ID for SMS messages (max 11 alphanumeric characters)"
  type        = string
  default     = "2FA"
}

variable "sms_type" {
  description = "Default SMS type: Promotional or Transactional"
  type        = string
  default     = "Transactional"
  validation {
    condition     = contains(["Promotional", "Transactional"], var.sms_type)
    error_message = "SMS type must be either 'Promotional' or 'Transactional'"
  }
}

variable "sms_monthly_spend_limit" {
  description = "Monthly spend limit for SMS in USD"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
