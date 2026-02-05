env                    = "prod"
region                 = "us-east-1"
prefix = "talo-tf"

##################### OpenLDAP ##########################
# OpenLDAP passwords - MUST be set via environment variables:
#   TF_VAR_openldap_admin_password (from GitHub Secret TF_VAR_OPENLDAP_ADMIN_PASSWORD)
#   TF_VAR_openldap_config_password (from GitHub Secret TF_VAR_OPENLDAP_CONFIG_PASSWORD)
# Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
# Or via .env file (see README for details)
# Do NOT set passwords here in this file

# OpenLDAP domain (e.g., ldap.talorlik.internal)
openldap_ldap_domain = "ldap.talorlik.internal"
openldap_secret_name = "openldap-secret"

##################### Storage ##########################
# StorageClass configuration for OpenLDAP PVC
storage_class_name       = "gp3-ldap"
storage_class_type       = "gp3"
storage_class_encrypted  = true
storage_class_is_default = true

##################### Network Policies ##########################
# Enable network policies for the OpenLDAP namespace
enable_network_policies = true

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

# ALB scheme: internet-facing or internal
# alb_scheme = "internet-facing"

# ALB target type: ip or instance
# alb_target_type = "ip"

# ALB SSL policy for HTTPS listeners
alb_ssl_policy = "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"

# ALB IP address type: ipv4 or dualstack
# alb_ip_address_type = "ipv4"

# EKS Cluster
# Cluster name will be automatically retrieved from backend_infra remote state
# if backend.hcl exists (created via setup-application.sh script).
# Otherwise, provide cluster name directly:
# cluster_name = "talo-tf-us-east-1-kc-prod"

wait_for_crd = true

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
argocd_role_name_component       = "argocd-role"
argocd_capability_name_component = "argocd"
argocd_namespace                 = "argocd"
argocd_project_name              = "default"

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
argocd_delete_propagation_policy = "RETAIN"

deployment_account_role_arn = "arn:aws:iam::944880695150:role/github-role"
deployment_account_external_id = "5f8697f36412ae83d62efc0a2ebd898fbb4a1721f0da986d9fa1ea7769223f47"

# State account configuration (where Route53 hosted zone and ACM certificate reside)
# Required when Route53 and ACM resources are in a different account than deployment account
# This is automatically injected by setup-application.sh and set-k8s-env.sh scripts
# state_account_role_arn = "arn:aws:iam::STATE_ACCOUNT_ID:role/terraform-state-role"
state_account_role_arn = "arn:aws:iam::395323424870:role/github-role"
