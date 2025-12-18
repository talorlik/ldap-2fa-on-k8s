env    = "prod"
region = "us-east-1"
prefix = "talo-tf"

##################### OpenLDAP ##########################
# OpenLDAP passwords - MUST be set via environment variables:
#   TF_VAR_OPENLDAP_ADMIN_PASSWORD
#   TF_VAR_OPENLDAP_CONFIG_PASSWORD
# Or via .env file (see README for details)
# Do NOT set passwords here in this file

# OpenLDAP domain (e.g., ldap.talorlik.internal)
openldap_ldap_domain = "ldap.talorlik.internal"

##################### Storage ##########################
# StorageClass configuration for OpenLDAP PVC
storage_class_name       = "gp3-ldap"
storage_class_type       = "gp3"
storage_class_encrypted  = true
storage_class_is_default = true

##################### ALB Configuration ##########################
app_name = "talo-ldap"
# ingress_alb_name            = "ingress-alb"
# service_alb_name            = "service-alb"
ingressclass_alb_name       = "ic-alb-ldap"
ingressclassparams_alb_name = "icp-alb-ldap"

# ALB group name for grouping multiple Ingress resources (defaults to app_name if not set)
# If set, will be concatenated as: ${prefix}-${region}-${alb_group_name}-${env} (truncated to 63 chars if needed)
# This is an internal Kubernetes identifier (max 63 characters)
alb_group_name = "alb-group"

# ALB load balancer name - AWS resource name (max 32 characters per AWS constraints)
# If set, will be concatenated as: ${prefix}-${region}-${alb_load_balancer_name}-${env} (truncated to 32 chars if needed)
# If not set, defaults to alb_group_name (truncated to 32 chars if needed)
alb_load_balancer_name = "alb"

# Hostnames for ingress resources (defaults to subdomain.domain_name if not set)
phpldapadmin_host = "phpldapadmin.talorlik.com"
ltb_passwd_host   = "passwd.talorlik.com"
twofa_app_host    = "app.talorlik.com"

# ALB scheme: internet-facing or internal
# alb_scheme = "internet-facing"

# ALB target type: ip or instance
# alb_target_type = "ip"

# ALB SSL policy for HTTPS listeners
alb_ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# ALB IP address type: ipv4 or dualstack
# alb_ip_address_type = "ipv4"

# EKS Cluster
# Cluster name will be automatically retrieved from backend_infra remote state
# if backend.hcl exists (created via setup-application.sh script).
# Otherwise, provide cluster name directly:
# cluster_name = "talo-tf-us-east-1-kc-prod"

##################### SMS 2FA (SNS) ##########################
# Enable SMS-based 2FA using AWS SNS
enable_sms_2fa = true

# SNS configuration (uses defaults if not specified)
# sns_topic_name      = "2fa-sms"
# sns_display_name    = "2FA Verification"
# sns_iam_role_name   = "2fa-sns-publisher"
# sms_sender_id       = "2FA"
# sms_type            = "Transactional"
# sms_monthly_spend_limit = 10

##################### Route53 ##########################
# Domain name for Route53 hosted zone and ACM certificate
domain_name = "talorlik.com"
# Subject alternative names for ACM certificate (wildcard subdomains)
# subject_alternative_names = ["*.talorlik.com"]
# Whether to use an existing Route53 zone
# use_existing_route53_zone = false

##################### ArgoCD ##########################
# Enable ArgoCD capability deployment
enable_argocd = true

# ArgoCD configuration
# argocd_role_name_component       = "argocd-role"
# argocd_capability_name_component = "argocd"
# argocd_namespace                 = "argocd"
# argocd_project_name              = "default"

# AWS Identity Center configuration (required if enable_argocd = true)
idc_instance_arn = "arn:aws:sso:::instance/ssoins-72238050a762e47d"
idc_region       = "us-east-1"

# RBAC role mappings for Identity Center groups/users
# Example: Map an Identity Center group to ArgoCD ADMIN role
argocd_rbac_role_mappings = [
  {
    role = "ADMIN"
    identities = [
      {
        id   = "b4e89458-f011-7074-5aa3-969ffe349784" # Identity Center group ID
        type = "SSO_GROUP"
      }
    ]
  }
]

# Optional: VPC endpoint IDs for private access to Argo CD
# argocd_vpce_ids = []

# Delete propagation policy (RETAIN or DELETE)
# argocd_delete_propagation_policy = "RETAIN"

##################### ArgoCD Applications ##########################
# Enable ArgoCD Application deployments
enable_argocd_apps = true

# Git repository configuration (required if enable_argocd_apps = true)
argocd_app_repo_url        = "https://github.com/talorlik/ldap-2fa-on-k8s.git"
argocd_app_target_revision = "main"

# Backend App Configuration
argocd_app_backend_name      = "ldap-2fa-backend"
argocd_app_backend_path      = "application/backend/helm/ldap-2fa-backend"
argocd_app_backend_namespace = "2fa-app"

# Frontend App Configuration
argocd_app_frontend_name      = "ldap-2fa-frontend"
argocd_app_frontend_path      = "application/frontend/helm/ldap-2fa-frontend"
argocd_app_frontend_namespace = "2fa-app"

# Sync policy configuration
# argocd_app_sync_policy_automated = true
# argocd_app_sync_policy_prune     = true
# argocd_app_sync_policy_self_heal  = true
