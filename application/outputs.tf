output "alb_dns_name" {
  description = "DNS name of the shared ALB created by Ingress resources"
  value       = local.alb_dns_name
}

# output "alb_dns_name" {
#   description = "DNS name of the ALB (if created)"
#   value       = var.use_alb ? module.alb[0].alb_dns_name : "(ALB not provisioned)"
# }

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
output "network_policy_name" {
  description = "Name of the network policy for secure namespace communication"
  value       = module.network_policies.network_policy_name
}

output "network_policy_namespace" {
  description = "Namespace where the network policy is applied"
  value       = module.network_policies.network_policy_namespace
}

output "network_policy_uid" {
  description = "UID of the network policy resource"
  value       = module.network_policies.network_policy_uid
}

##################### SNS SMS 2FA ##########################
output "sns_topic_arn" {
  description = "ARN of the SNS topic for SMS 2FA"
  value       = var.enable_sms_2fa ? module.sns[0].sns_topic_arn : null
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = var.enable_sms_2fa ? module.sns[0].sns_topic_name : null
}

output "sns_iam_role_arn" {
  description = "ARN of the IAM role for SNS publishing (for IRSA)"
  value       = var.enable_sms_2fa ? module.sns[0].iam_role_arn : null
}

output "sns_service_account_annotation" {
  description = "Annotation to add to Kubernetes service account for IRSA"
  value       = var.enable_sms_2fa ? module.sns[0].service_account_annotation : null
}

##################### 2FA Application ##########################
output "twofa_app_url" {
  description = "URL for the 2FA application (frontend)"
  value       = var.twofa_app_host != null ? "https://${var.twofa_app_host}" : null
}

output "twofa_api_url" {
  description = "URL for the 2FA API (backend)"
  value       = var.twofa_app_host != null ? "https://${var.twofa_app_host}/api" : null
}

##################### ArgoCD Applications ##########################
output "argocd_backend_app_name" {
  description = "Name of the ArgoCD Application for backend"
  value       = var.enable_argocd_apps ? var.argocd_app_backend_name : null
}

output "argocd_frontend_app_name" {
  description = "Name of the ArgoCD Application for frontend"
  value       = var.enable_argocd_apps ? var.argocd_app_frontend_name : null
}
