variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where OpenLDAP is deployed"
  type        = string
}

variable "domain_name" {
  description = "Domain name for certificate DNS names"
  type        = string
}
