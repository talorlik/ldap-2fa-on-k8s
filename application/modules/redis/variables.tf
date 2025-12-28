variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Name prefix added to all resources"
  type        = string
}

variable "enable_redis" {
  description = "Enable Redis deployment"
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
  default     = "redis"
}

variable "secret_name" {
  description = "Name of the Kubernetes secret for Redis password"
  type        = string
  default     = "redis-secret"
}

variable "redis_password" {
  description = "Redis authentication password (from GitHub Secrets via TF_VAR_redis_password)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.redis_password) >= 8
    error_message = "Redis password must be at least 8 characters."
  }
}

variable "chart_version" {
  description = "Bitnami Redis Helm chart version"
  type        = string
  default     = "19.6.4"
}

variable "storage_class_name" {
  description = "Storage class for Redis PVC"
  type        = string
  default     = ""
}

variable "storage_size" {
  description = "Storage size for Redis PVC"
  type        = string
  default     = "1Gi"
}

variable "persistence_enabled" {
  description = "Enable persistence for Redis data"
  type        = bool
  default     = true
}

variable "resources" {
  description = "Resource limits and requests for Redis"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "500m"
      memory = "256Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

variable "metrics_enabled" {
  description = "Enable Prometheus metrics exporter"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "backend_namespace" {
  description = "Namespace where the backend pods are deployed (for network policy)"
  type        = string
  default     = "twofa-backend"
}
