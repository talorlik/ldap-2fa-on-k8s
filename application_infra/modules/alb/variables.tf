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
  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "ALB scheme must be either 'internet-facing' or 'internal'"
  }
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

variable "alb_group_name" {
  description = "ALB group name for grouping multiple Ingress resources to share a single ALB. This is an internal Kubernetes identifier (max 63 characters)."
  type        = string
  default     = null # If null, will be derived from app_name
}

variable "kubernetes_master" {
  description = "Kubernetes API server endpoint (KUBERNETES_MASTER environment variable). Set by set-k8s-env.sh or GitHub workflow."
  type        = string
  default     = null
  nullable    = true
}

variable "kube_config_path" {
  description = "Path to kubeconfig file (KUBE_CONFIG_PATH environment variable). Set by set-k8s-env.sh or GitHub workflow."
  type        = string
  default     = null
  nullable    = true
}

variable "wait_for_crd" {
  description = "Whether to wait for EKS Auto Mode CRD to be available before creating IngressClassParams. Set to true for initial cluster deployments, false after cluster is established."
  type        = bool
  default     = false
}
