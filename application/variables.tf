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

variable "app_name" {
  description = "Application name"
  type        = string
}

##################### OpenLDAP ##########################

variable "openldap_ldap_domain" {
  description = "OpenLDAP domain (e.g., ldap.talorlik.internal)"
  type        = string
}

variable "openldap_admin_password" {
  description = "OpenLDAP admin password. MUST be set via TF_VAR_openldap_admin_password environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
  # No default - must be provided via environment variable or .env file
}

variable "openldap_config_password" {
  description = "OpenLDAP config password. MUST be set via TF_VAR_openldap_config_password environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
  # No default - must be provided via environment variable or .env file
}

##################### Storage ##########################

variable "storage_class_name" {
  description = "Name of the Kubernetes StorageClass to create and use for OpenLDAP PVC"
  type        = string
}

variable "storage_class_type" {
  description = "EBS volume type for the StorageClass (gp2, gp3, io1, io2, etc.)"
  type        = string
}

variable "storage_class_encrypted" {
  description = "Whether to encrypt EBS volumes created by the StorageClass"
  type        = bool
}

variable "storage_class_is_default" {
  description = "Whether to mark this StorageClass as the default for the cluster"
  type        = bool
}

##################### Route53 ##########################

variable "domain_name" {
  description = "Root domain name for Route53 hosted zone and ACM certificate (e.g., talorlik.com)"
  type        = string
}

# variable "subject_alternative_names" {
#   description = "List of subject alternative names for the ACM certificate (e.g., [\"*.talorlik.com\"])"
#   type        = list(string)
#   default     = []
# }

# variable "use_existing_route53_zone" {
#   description = "Whether to use an existing Route53 zone"
#   type        = bool
#   default     = false
# }

# Use ALB - can set this to false for to get NLB
### NLB not yet implemented. If false you get no load balancer
variable "use_alb" {
  description = "When true, uses AWS Auto to create ALB. When false an NLB is created"
  type        = bool
  default     = true
}

# variable "ingress_alb_name" {
#   description = "Name component for ingress ALB resource (between prefix and env)"
#   type        = string
# }

# variable "service_alb_name" {
#   description = "Name component for service ALB resource (between prefix and env)"
#   type        = string
# }

variable "ingressclass_alb_name" {
  description = "Name component for ingressclass ALB resource (between prefix and env)"
  type        = string
}

variable "ingressclassparams_alb_name" {
  description = "Name component for ingressclassparams ALB resource (between prefix and env)"
  type        = string
}

##################### ALB Configuration ##########################

variable "alb_group_name" {
  description = "ALB group name for grouping multiple Ingress resources to share a single ALB"
  type        = string
  default     = null # If null, will be derived from app_name
}

variable "phpldapadmin_host" {
  description = "Hostname for phpLDAPadmin ingress (e.g., phpldapadmin.talorlik.com). If null, will be derived from domain_name"
  type        = string
  default     = null
}

variable "ltb_passwd_host" {
  description = "Hostname for ltb-passwd ingress (e.g., passwd.talorlik.com). If null, will be derived from domain_name"
  type        = string
  default     = null
}

variable "alb_scheme" {
  description = "ALB scheme: internet-facing or internal"
  type        = string
  default     = "internet-facing"
  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "ALB scheme must be either 'internet-facing' or 'internal'"
  }
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

variable "alb_ssl_policy" {
  description = "ALB SSL policy for HTTPS listeners"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "alb_ip_address_type" {
  description = "ALB IP address type: ipv4 or dualstack"
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "dualstack"], var.alb_ip_address_type)
    error_message = "ALB IP address type must be either 'ipv4' or 'dualstack'"
  }
}

variable "cluster_name" {
  description = "Full name of the EKS cluster (will be retrieved from backend_infra remote state if backend.hcl exists, otherwise must be provided)"
  type        = string
  default     = null
}

variable "cluster_name_component" {
  description = "Name component for cluster (used only if cluster_name not provided and remote state unavailable). Full name format: prefix-region-cluster_name_component-env"
  type        = string
  default     = "kc"
}
