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

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "argocd_role_name_component" {
  description = "Name component for ArgoCD IAM role (between prefix and env)"
  type        = string
  default     = "argocd-role"
}

variable "argocd_capability_name_component" {
  description = "Name component for ArgoCD capability (between prefix and env)"
  type        = string
  default     = "argocd"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD resources"
  type        = string
  default     = "argocd"
}

variable "argocd_project_name" {
  description = "ArgoCD project name for cluster registration"
  type        = string
  default     = "default"
}

variable "local_cluster_secret_name" {
  description = "Name of the Kubernetes secret for local cluster registration"
  type        = string
  default     = "local-cluster"
}

variable "idc_instance_arn" {
  description = "ARN of the AWS Identity Center instance used for Argo CD auth"
  type        = string
}

variable "idc_region" {
  description = "Region of the Identity Center instance"
  type        = string
}

variable "rbac_role_mappings" {
  description = "List of RBAC role mappings for Identity Center groups/users"
  type = list(object({
    role = string
    identities = list(object({
      id   = string
      type = string # SSO_GROUP or SSO_USER
    }))
  }))
  default = []
}

variable "argocd_vpce_ids" {
  description = "Optional list of VPC endpoint IDs for private access to Argo CD"
  type        = list(string)
  default     = []
}

variable "delete_propagation_policy" {
  description = "Delete propagation policy for ArgoCD capability (RETAIN or DELETE)"
  type        = string
  default     = "RETAIN"
  validation {
    condition     = contains(["RETAIN", "DELETE"], var.delete_propagation_policy)
    error_message = "Delete propagation policy must be either 'RETAIN' or 'DELETE'"
  }
}

# IAM Policy Resources
variable "iam_policy_eks_resources" {
  description = "List of EKS resource ARNs for IAM policy (use ['*'] for all clusters)"
  type        = list(string)
  default     = ["*"]
}

variable "iam_policy_secrets_manager_resources" {
  description = "List of Secrets Manager secret ARNs for IAM policy (use ['*'] for all secrets)"
  type        = list(string)
  default     = ["*"]
}

variable "iam_policy_code_connections_resources" {
  description = "List of CodeConnections connection ARNs for IAM policy (use ['*'] for all connections)"
  type        = list(string)
  default     = ["*"]
}

variable "enable_ecr_access" {
  description = "Whether to enable ECR access in IAM policy (for pulling container images)"
  type        = bool
  default     = false
}

variable "iam_policy_ecr_resources" {
  description = "List of ECR repository ARNs for IAM policy (use ['*'] for all repositories)"
  type        = list(string)
  default     = ["*"]
}

variable "enable_codecommit_access" {
  description = "Whether to enable CodeCommit access in IAM policy (for Git repository access)"
  type        = bool
  default     = false
}

variable "iam_policy_codecommit_resources" {
  description = "List of CodeCommit repository ARNs for IAM policy (use ['*'] for all repositories)"
  type        = list(string)
  default     = ["*"]
}
