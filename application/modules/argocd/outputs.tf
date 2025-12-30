output "argocd_server_url" {
  description = "Managed Argo CD UI/API endpoint (automatically retrieved via AWS CLI)"
  value       = data.external.argocd_capability.result.server_url != "" ? data.external.argocd_capability.result.server_url : null
}

output "argocd_capability_name" {
  description = "Name of the ArgoCD capability"
  value       = local.argocd_capability_name
}

output "argocd_capability_status" {
  description = "Status of the ArgoCD capability (automatically retrieved via AWS CLI)"
  value       = data.external.argocd_capability.result.status != "" ? data.external.argocd_capability.result.status : null
}

output "argocd_iam_role_arn" {
  description = "ARN of the IAM role used by ArgoCD capability"
  value       = aws_iam_role.argocd_capability.arn
}

output "argocd_iam_role_name" {
  description = "Name of the IAM role used by ArgoCD capability"
  value       = aws_iam_role.argocd_capability.name
}

output "local_cluster_secret_name" {
  description = "Name of the Kubernetes secret for local cluster registration"
  value       = kubernetes_secret.argocd_local_cluster.metadata[0].name
}

output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD resources are deployed"
  value       = var.argocd_namespace
}

output "argocd_project_name" {
  description = "ArgoCD project name used for cluster registration"
  value       = var.argocd_project_name
}
