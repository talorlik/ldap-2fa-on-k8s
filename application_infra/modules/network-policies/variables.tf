variable "namespace" {
  description = "Kubernetes namespace where network policies will be applied"
  type        = string
  default     = "ldap"
}
