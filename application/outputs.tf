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

##################### PostgreSQL ##########################
output "postgresql_host" {
  description = "PostgreSQL service hostname"
  value       = var.enable_postgresql ? module.postgresql[0].host : null
}

output "postgresql_connection_url" {
  description = "PostgreSQL connection URL (without password)"
  value       = var.enable_postgresql ? module.postgresql[0].connection_url : null
}

output "postgresql_database" {
  description = "PostgreSQL database name"
  value       = var.enable_postgresql ? module.postgresql[0].database : null
}

##################### SES Email ##########################
output "ses_sender_email" {
  description = "SES verified sender email"
  value       = var.enable_email_verification ? module.ses[0].sender_email : null
}

output "ses_iam_role_arn" {
  description = "ARN of the IAM role for SES access (for IRSA)"
  value       = var.enable_email_verification ? module.ses[0].iam_role_arn : null
}

output "ses_verification_status" {
  description = "SES verification status/instructions"
  value       = var.enable_email_verification ? module.ses[0].verification_status : null
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

##################### Redis SMS OTP Storage ##########################
output "redis_host" {
  description = "Redis service hostname"
  value       = var.enable_redis ? module.redis[0].redis_host : null
}

output "redis_port" {
  description = "Redis service port"
  value       = var.enable_redis ? module.redis[0].redis_port : null
}

output "redis_namespace" {
  description = "Kubernetes namespace where Redis is deployed"
  value       = var.enable_redis ? module.redis[0].redis_namespace : null
}

output "redis_password_secret_name" {
  description = "Name of the Kubernetes secret containing Redis password"
  value       = var.enable_redis ? module.redis[0].redis_password_secret_name : null
}

output "redis_password_secret_key" {
  description = "Key in the secret for Redis password"
  value       = var.enable_redis ? module.redis[0].redis_password_secret_key : null
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
