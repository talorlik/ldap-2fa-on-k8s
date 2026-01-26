output "alb_dns_name" {
  description = "DNS name of the shared ALB created by Ingress resources"
  value       = var.use_alb ? local.alb_dns_name : null
}

##################### StorageClass ##########################
output "storage_class_name" {
  description = "Name of the Kubernetes StorageClass created for PVCs"
  value       = kubernetes_storage_class_v1.this.metadata[0].name
}

output "route53_acm_cert_arn" {
  description = "ACM certificate ARN (validated and ready for use)"
  value       = data.aws_acm_certificate.this.arn
}

output "route53_domain_name" {
  description = "Root domain name"
  value       = var.domain_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.this.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers (for registrar configuration)"
  value       = data.aws_route53_zone.this.name_servers
}

##################### ALB Module ##########################
output "alb_ingress_class_name" {
  description = "Name of the IngressClass for shared ALB"
  value       = var.use_alb ? module.alb[0].ingress_class_name : null
}

output "alb_ingress_class_params_name" {
  description = "Name of the IngressClassParams for ALB configuration"
  value       = var.use_alb ? module.alb[0].ingress_class_params_name : null
}

output "alb_scheme" {
  description = "ALB scheme configured in IngressClassParams"
  value       = var.use_alb ? module.alb[0].alb_scheme : null
}

output "alb_ip_address_type" {
  description = "ALB IP address type configured in IngressClassParams"
  value       = var.use_alb ? module.alb[0].alb_ip_address_type : null
}

##################### Network Policies Module ##########################
# Network policies are created within the openldap module
# These outputs expose the network policy information from the openldap module
output "network_policy_name" {
  description = "Name of the network policy for secure namespace communication"
  value       = module.openldap.network_policy_name
}

output "network_policy_namespace" {
  description = "Namespace where the network policy is applied"
  value       = module.openldap.network_policy_namespace
}

output "network_policy_uid" {
  description = "UID of the network policy resource"
  value       = module.openldap.network_policy_uid
}

##################### ArgoCD Capability ##########################
output "argocd_server_url" {
  description = "Managed Argo CD UI/API endpoint (automatically retrieved via AWS CLI)"
  value       = var.enable_argocd ? module.argocd[0].argocd_server_url : null
}

output "argocd_capability_name" {
  description = "Name of the ArgoCD capability"
  value       = var.enable_argocd ? module.argocd[0].argocd_capability_name : null
}

output "argocd_capability_status" {
  description = "Status of the ArgoCD capability (automatically retrieved via AWS CLI)"
  value       = var.enable_argocd ? module.argocd[0].argocd_capability_status : null
}

output "argocd_capability_error" {
  description = "Error of the ArgoCD capability (automatically retrieved via AWS CLI)"
  value       = var.enable_argocd ? module.argocd[0].argocd_capability_error : null
}
output "argocd_iam_role_arn" {
  description = "ARN of the IAM role used by ArgoCD capability"
  value       = var.enable_argocd ? module.argocd[0].argocd_iam_role_arn : null
}

output "argocd_iam_role_name" {
  description = "Name of the IAM role used by ArgoCD capability"
  value       = var.enable_argocd ? module.argocd[0].argocd_iam_role_name : null
}

output "local_cluster_secret_name" {
  description = "Name of the Kubernetes secret for local cluster registration"
  value       = var.enable_argocd ? module.argocd[0].local_cluster_secret_name : null
}

output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD resources are deployed"
  value       = var.enable_argocd ? var.argocd_namespace : null
}

output "argocd_project_name" {
  description = "ArgoCD project name used for cluster registration"
  value       = var.enable_argocd ? var.argocd_project_name : null
}
