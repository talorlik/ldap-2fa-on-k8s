variable "env" {
  description = "Deployment environment (for tagging)"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Prefix for the resources"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., talorlik.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "List of subject alternative names for the ACM certificate (e.g., [\"*.talorlik.com\"])"
  type        = list(string)
  default     = []
}

variable "use_existing_route53_zone" {
  description = "Whether to use an existing Route53 zone"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}
