env                    = "prod"
region                 = "us-east-1"
prefix                 = "talo-tf"

##################### Domain ##########################
domain_name = "talorlik.com"
twofa_app_host = "app.talorlik.com"

##################### PostgreSQL User Storage ##########################
enable_postgresql            = true
postgresql_namespace         = "ldap-2fa"
postgresql_database_name     = "ldap2fa"
postgresql_database_username = "ldap2fa"
postgresql_storage_size      = "8Gi"
postgresql_secret_name       = "postgresql-secret"
# PostgreSQL password - MUST be set via environment variable:
#   TF_VAR_postgresql_database_password (from GitHub Secret TF_VAR_POSTGRESQL_PASSWORD)
# Do NOT set password here in this file

##################### Redis SMS OTP Storage ##########################
enable_redis       = true
redis_namespace    = "redis"
redis_storage_size = "1Gi"
redis_secret_name  = "redis-secret"
# Redis password - MUST be set via environment variable:
#   TF_VAR_redis_password (from GitHub Secret TF_VAR_REDIS_PASSWORD)
# Do NOT set password here in this file

##################### SES Email Verification ##########################
enable_email_verification = true
ses_sender_email          = "noreply@talorlik.com"
ses_sender_domain         = "talorlik.com"

##################### SNS SMS 2FA ##########################
# Enable SMS-based 2FA using AWS SNS
enable_sms_2fa = false

# SNS configuration
sns_topic_name          = "2fa-sms"
sns_display_name        = "TALO LDAP 2FA Verification"
sns_iam_role_name       = "2fa-sns-publisher"
configure_sms_preferences = false
sms_sender_id           = "TALO2FA"
sms_type                = "Transactional"
sms_monthly_spend_limit = 100

##################### ArgoCD Applications ##########################
enable_argocd_apps = true

# Git repository configuration (required if enable_argocd_apps = true)
argocd_app_repo_url        = "https://github.com/talorlik/ldap-2fa-on-k8s.git"
argocd_app_target_revision = "main"

# Backend application configuration
argocd_app_backend_name      = "ldap-2fa-backend"
argocd_app_backend_path      = "application/backend/helm/ldap-2fa-backend"
argocd_app_backend_namespace = "2fa-app"

# Frontend application configuration
argocd_app_frontend_name      = "ldap-2fa-frontend"
argocd_app_frontend_path      = "application/frontend/helm/ldap-2fa-frontend"
argocd_app_frontend_namespace = "2fa-app"

# Sync policy configuration
# argocd_app_sync_policy_automated = true
# argocd_app_sync_policy_prune     = true
# argocd_app_sync_policy_self_heal  = true
