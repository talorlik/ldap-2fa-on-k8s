variable "env" {
  description = "Environment suffix used to name resources"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Prefix used to name resources"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "cluster_name" {
  description = "Name of EKS Cluster where ALB is to be deployed"
  type        = string
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

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS/TLS termination at ALB"
  type        = string
  default     = null
}

variable "alb_scheme" {
  description = "ALB scheme: internet-facing or internal"
  type        = string
  default     = "internet-facing"
}

variable "alb_ip_address_type" {
  description = "ALB IP address type: ipv4 or dualstack"
  type        = string
  default     = "ipv4"
}
