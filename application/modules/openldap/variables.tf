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

variable "app_name" {
  description = "Full application name (computed in parent module as prefix-region-app_name-env)"
  type        = string
}

variable "openldap_ldap_domain" {
  description = "OpenLDAP domain (e.g., ldap.talorlik.internal)"
  type        = string
}

variable "openldap_admin_password" {
  description = "OpenLDAP admin password. MUST be set via TF_VAR_OPENLDAP_ADMIN_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
}

variable "openldap_config_password" {
  description = "OpenLDAP config password. MUST be set via TF_VAR_OPENLDAP_CONFIG_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
}

variable "openldap_secret_name" {
  description = "Name of the Kubernetes secret for OpenLDAP passwords"
  type        = string
  default     = "openldap-secret"
}

variable "storage_class_name" {
  description = "Name of the Kubernetes StorageClass to use for OpenLDAP PVC"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for OpenLDAP"
  type        = string
  default     = "ldap"
}

variable "phpldapadmin_host" {
  description = "Hostname for phpLDAPadmin ingress (e.g., phpldapadmin.talorlik.com). Derived from domain_name if not provided."
  type        = string
}

variable "ltb_passwd_host" {
  description = "Hostname for ltb-passwd ingress (e.g., passwd.talorlik.com). Derived from domain_name if not provided."
  type        = string
}

variable "use_alb" {
  description = "Whether to use ALB for ingress"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Name of the IngressClass for ALB (from ALB module)"
  type        = string
  default     = null
}

variable "alb_load_balancer_name" {
  description = "Custom name for the AWS ALB (appears in AWS console). Must be ≤ 32 characters per AWS constraints."
  type        = string
}

variable "alb_target_type" {
  description = "ALB target type: ip or instance"
  type        = string
  default     = "ip"
  validation {
    condition     = contains(["ip", "instance"], var.alb_target_type)
    error_message = "ALB target type must be either 'ip' or 'instance'"
  }
}

variable "acm_cert_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for creating DNS records"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB canonical hosted zone ID for Route53 alias records. This should be computed in the parent module from the region mapping and passed to this module."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "helm_chart_version" {
  description = "OpenLDAP Helm chart version"
  type        = string
  default     = "4.0.1"
}

variable "helm_chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://jp-gouin.github.io/helm-openldap"
}

variable "helm_chart_name" {
  description = "Helm chart name"
  type        = string
  default     = "openldap-stack-ha"
}

variable "helm_release_name" {
  description = "Helm release name"
  type        = string
  default     = "openldap-stack-ha"
}

variable "values_template_path" {
  description = "Path to the OpenLDAP values template file"
  type        = string
  default     = null
}

variable "enable_network_policies" {
  description = "Whether to enable network policies for the OpenLDAP namespace"
  type        = bool
  default     = true
}
