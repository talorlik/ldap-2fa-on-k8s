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

variable "namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
  default     = "ldap-2fa"
}

variable "secret_name" {
  description = "Name of the Kubernetes secret for PostgreSQL password"
  type        = string
  default     = "postgresql-secret"
}

variable "chart_version" {
  description = "PostgreSQL Helm chart version"
  type        = string
  default     = "18.1.15"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "ldap2fa"
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = "ldap2fa"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "storage_class" {
  description = "Storage class for PostgreSQL PVC"
  type        = string
  default     = ""
}

variable "storage_size" {
  description = "Storage size for PostgreSQL PVC"
  type        = string
  default     = "8Gi"
}

variable "resources" {
  description = "Resource limits and requests for PostgreSQL"
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
      memory = "512Mi"
    }
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ecr_registry" {
  description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
  type        = string
}

variable "ecr_repository" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag" {
  description = "PostgreSQL image tag in ECR"
  type        = string
  default     = "postgresql-latest"
}

variable "values_template_path" {
  description = "Path to the PostgreSQL values template file"
  type        = string
  default     = null
}
