output "app_name" {
  description = "Name of the ArgoCD Application"
  value       = kubernetes_manifest.argocd_app.object.metadata.name
}

output "app_namespace" {
  description = "Namespace where the ArgoCD Application is deployed"
  value       = kubernetes_manifest.argocd_app.object.metadata.namespace
}

output "app_uid" {
  description = "UID of the ArgoCD Application resource"
  value       = kubernetes_manifest.argocd_app.object.metadata.uid
}

output "destination_namespace" {
  description = "Target Kubernetes namespace for the application"
  value       = var.destination_namespace
}

output "repo_url" {
  description = "Git repository URL for the Application"
  value       = var.repo_url
}

output "repo_path" {
  description = "Path within the repository"
  value       = var.repo_path
}

output "target_revision" {
  description = "Git branch/tag/commit being synced"
  value       = var.target_revision
}
