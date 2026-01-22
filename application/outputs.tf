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

##################### 2FA Application ##########################
output "twofa_app_url" {
  description = "URL for the 2FA application (frontend)"
  value       = local.twofa_app_host != "" ? "https://${local.twofa_app_host}" : null
}

output "twofa_api_url" {
  description = "URL for the 2FA API (backend)"
  value       = local.twofa_app_host != "" ? "https://${local.twofa_app_host}/api" : null
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

##################### Route53 Record ##########################
output "twofa_app_route53_record_name" {
  description = "Route53 record name for 2FA application"
  value       = length(module.route53_record_twofa_app) > 0 ? module.route53_record_twofa_app[0].record_name : null
}

output "twofa_app_route53_record_fqdn" {
  description = "Fully qualified domain name (FQDN) of the Route53 record for 2FA application"
  value       = length(module.route53_record_twofa_app) > 0 ? module.route53_record_twofa_app[0].record_fqdn : null
}
