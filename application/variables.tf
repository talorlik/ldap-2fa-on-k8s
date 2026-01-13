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

variable "deployment_account_role_arn" {
  description = "ARN of the IAM role to assume in the deployment account (Account B). Required when using GitHub Actions with multi-account setup."
  type        = string
  default     = null
  nullable    = true
}

variable "deployment_account_external_id" {
  description = "ExternalId for cross-account role assumption security. Required when assuming roles in deployment accounts. Must match the ExternalId configured in the deployment account role's Trust Relationship. Retrieved from AWS Secrets Manager (secret: 'external-id') for local deployment or GitHub secret (AWS_ASSUME_EXTERNAL_ID) for GitHub Actions."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "state_account_role_arn" {
  description = "ARN of the IAM role to assume in the state account (where Route53 hosted zone and ACM certificate reside). Required when Route53 and ACM resources are in a different account than the deployment account."
  type        = string
  default     = null
  nullable    = true
}

##################### OpenLDAP ##########################
variable "app_name" {
  description = "Application name"
  type        = string
}

variable "openldap_ldap_domain" {
  description = "OpenLDAP domain (e.g., ldap.talorlik.internal)"
  type        = string
}

variable "openldap_admin_password" {
  description = "OpenLDAP admin password. MUST be set via TF_VAR_OPENLDAP_ADMIN_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
  # No default - must be provided via environment variable or .env file
}

variable "openldap_config_password" {
  description = "OpenLDAP config password. MUST be set via TF_VAR_OPENLDAP_CONFIG_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
  type        = string
  sensitive   = true
  # No default - must be provided via environment variable or .env file
}

variable "openldap_secret_name" {
  description = "Name of the Kubernetes secret for OpenLDAP passwords"
  type        = string
  default     = "openldap-secret"
}

variable "openldap_image_tag" {
  description = "OpenLDAP image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
  type        = string
  default     = "openldap-1.5.0"
}

variable "postgresql_image_tag" {
  description = "PostgreSQL image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
  type        = string
  default     = "postgresql-latest"
}

variable "redis_image_tag" {
  description = "Redis image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
  type        = string
  default     = "redis-latest"
}

##################### Storage ##########################

variable "storage_class_name" {
  description = "Name of the Kubernetes StorageClass to create and use for OpenLDAP PVC"
  type        = string
}

variable "storage_class_type" {
  description = "EBS volume type for the StorageClass (gp2, gp3, io1, io2, etc.)"
  type        = string
}

variable "storage_class_encrypted" {
  description = "Whether to encrypt EBS volumes created by the StorageClass"
  type        = bool
}

variable "storage_class_is_default" {
  description = "Whether to mark this StorageClass as the default for the cluster"
  type        = bool
}

##################### Route53 ##########################

variable "domain_name" {
  description = "Root domain name for Route53 hosted zone and ACM certificate (e.g., talorlik.com)"
  type        = string
}

# variable "subject_alternative_names" {
#   description = "List of subject alternative names for the ACM certificate (e.g., [\"*.talorlik.com\"])"
#   type        = list(string)
#   default     = []
# }

# variable "use_existing_route53_zone" {
#   description = "Whether to use an existing Route53 zone"
#   type        = bool
#   default     = false
# }

# Use ALB - can set this to false for to get NLB
### NLB not yet implemented. If false you get no load balancer
variable "use_alb" {
  description = "When true, uses AWS Auto to create ALB. When false an NLB is created"
  type        = bool
  default     = true
}

# variable "ingress_alb_name" {
#   description = "Name component for ingress ALB resource (between prefix and env)"
#   type        = string
# }

# variable "service_alb_name" {
#   description = "Name component for service ALB resource (between prefix and env)"
#   type        = string
# }

variable "ingressclass_alb_name" {
  description = "Name component for ingressclass ALB resource (between prefix and env)"
  type        = string
}

variable "ingressclassparams_alb_name" {
  description = "Name component for ingressclassparams ALB resource (between prefix and env)"
  type        = string
}

##################### ALB Configuration ##########################

variable "alb_group_name" {
  description = "ALB group name for grouping multiple Ingress resources to share a single ALB. This is an internal Kubernetes identifier (max 63 characters)."
  type        = string
  default     = null # If null, will be derived from app_name
}

variable "alb_load_balancer_name" {
  description = "Custom name for the AWS ALB (appears in AWS console). Must be ≤ 32 characters per AWS constraints. If null, defaults to alb_group_name (truncated to 32 chars if needed)."
  type        = string
  default     = null
}

variable "phpldapadmin_host" {
  description = "Hostname for phpLDAPadmin ingress (e.g., phpldapadmin.talorlik.com). If null, will be derived from domain_name"
  type        = string
  default     = null
  nullable    = true
}

variable "ltb_passwd_host" {
  description = "Hostname for ltb-passwd ingress (e.g., passwd.talorlik.com). If null, will be derived from domain_name"
  type        = string
  default     = null
  nullable    = true
}

variable "twofa_app_host" {
  description = "Hostname for 2FA application ingress (e.g., app.talorlik.com). If null, will be derived from domain_name"
  type        = string
  default     = null
}

variable "alb_scheme" {
  description = "ALB scheme: internet-facing or internal"
  type        = string
  default     = "internet-facing"
  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "ALB scheme must be either 'internet-facing' or 'internal'"
  }
}

variable "alb_target_type" {
  description = "ALB target type: ip or instance"
  type        = string
  default     = "ip"
  validation {
    condition     = contains(["ip", "instance"], var.alb_target_type)
    error_message = "ALB target type must be either 'ip' or 'instance'"
  }
}

variable "alb_ssl_policy" {
  description = "ALB SSL policy for HTTPS listeners"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"
}

variable "alb_ip_address_type" {
  description = "ALB IP address type: ipv4 or dualstack"
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "dualstack"], var.alb_ip_address_type)
    error_message = "ALB IP address type must be either 'ipv4' or 'dualstack'"
  }
}

variable "cluster_name" {
  description = "Full name of the EKS cluster (will be retrieved from backend_infra remote state if backend.hcl exists, otherwise must be provided)"
  type        = string
  default     = null
}

variable "cluster_name_component" {
  description = "Name component for cluster (used only if cluster_name not provided and remote state unavailable). Full name format: prefix-region-cluster_name_component-env"
  type        = string
  default     = "kc"
}

variable "terraform_workspace" {
  description = "Terraform workspace name for remote state lookup. If null, will be derived from region and env as 'region-env'. This ensures the correct workspace state is used when fetching ECR registry information from backend_infra."
  type        = string
  default     = null
  nullable    = true
}

variable "kubernetes_master" {
  description = "Kubernetes API server endpoint (KUBERNETES_MASTER environment variable). Set by set-k8s-env.sh or GitHub workflow. Can be set via TF_VAR_kubernetes_master."
  type        = string
  default     = null
  nullable    = true
}

variable "kube_config_path" {
  description = "Path to kubeconfig file (KUBE_CONFIG_PATH environment variable). Set by set-k8s-env.sh or GitHub workflow. Can be set via TF_VAR_kube_config_path."
  type        = string
  default     = null
  nullable    = true
}

variable "wait_for_crd" {
  description = "Whether to wait for EKS Auto Mode CRD to be available before creating IngressClassParams. Set to true for initial cluster deployments, false after cluster is established."
  type        = bool
  default     = false
}

##################### PostgreSQL User Storage ##########################

variable "enable_postgresql" {
  description = "Whether to deploy PostgreSQL for user storage"
  type        = bool
  default     = true
}

variable "postgresql_namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
  default     = "ldap-2fa"
}

variable "postgresql_database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ldap2fa"
}

variable "postgresql_database_username" {
  description = "PostgreSQL database username"
  type        = string
  default     = "ldap2fa"
}

variable "postgresql_database_password" {
  description = "PostgreSQL database password. MUST be set via TF_VAR_POSTGRESQL_PASSWORD environment variable or GitHub Secret."
  type        = string
  sensitive   = true
}

variable "postgresql_secret_name" {
  description = "Name of the Kubernetes secret for PostgreSQL password"
  type        = string
  default     = "postgresql-secret"
}

variable "postgresql_storage_size" {
  description = "PostgreSQL storage size"
  type        = string
  default     = "8Gi"
}

##################### SES Email Verification ##########################

variable "enable_email_verification" {
  description = "Whether to enable email verification using SES"
  type        = bool
  default     = true
}

variable "ses_sender_email" {
  description = "Email address to send verification emails from"
  type        = string
  default     = "noreply@example.com"
}

variable "ses_sender_domain" {
  description = "Domain to verify in SES (optional, for domain-level verification)"
  type        = string
  default     = null
}

variable "ses_iam_role_name" {
  description = "Name component for the SES IAM role"
  type        = string
  default     = "ses-sender"
}

variable "ses_route53_zone_id" {
  description = "Route53 zone ID for SES domain verification (optional, defaults to main domain zone)"
  type        = string
  default     = null
}

##################### SNS SMS 2FA ##########################

variable "enable_sms_2fa" {
  description = "Whether to enable SMS-based 2FA using SNS"
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Name component for the SNS topic"
  type        = string
}

variable "sns_display_name" {
  description = "Display name for the SNS topic (appears in SMS sender)"
  type        = string
}

variable "sns_iam_role_name" {
  description = "Name component for the SNS IAM role"
  type        = string
}

variable "configure_sms_preferences" {
  description = "Whether to configure account-level SMS preferences"
  type        = bool
  default     = false
}

variable "sms_sender_id" {
  description = "Default sender ID for SMS messages (max 11 alphanumeric characters)"
  type        = string
}

variable "sms_type" {
  description = "Default SMS type: Promotional or Transactional"
  type        = string
  validation {
    condition     = contains(["Promotional", "Transactional"], var.sms_type)
    error_message = "SMS type must be either 'Promotional' or 'Transactional'"
  }
}

variable "sms_monthly_spend_limit" {
  description = "Monthly spend limit for SMS in USD"
  type        = number
}

##################### Redis SMS OTP Storage ##########################

variable "enable_redis" {
  description = "Enable Redis deployment for SMS OTP storage"
  type        = bool
  default     = false
}

variable "redis_password" {
  description = "Redis authentication password (from GitHub Secrets via TF_VAR_REDIS_PASSWORD)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.enable_redis == false || length(var.redis_password) >= 8
    error_message = "Redis password must be at least 8 characters when Redis is enabled."
  }
}

variable "redis_secret_name" {
  description = "Name of the Kubernetes secret for Redis password"
  type        = string
  default     = "redis-secret"
}

variable "redis_namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
  default     = "redis"
}

variable "redis_storage_size" {
  description = "Redis PVC storage size"
  type        = string
  default     = "1Gi"
}

variable "redis_chart_version" {
  description = "Bitnami Redis Helm chart version"
  type        = string
  default     = "19.6.4"
}

##################### ArgoCD ##########################

variable "enable_argocd" {
  description = "Whether to enable ArgoCD capability deployment"
  type        = bool
  default     = false
}

variable "argocd_role_name_component" {
  description = "Name component for ArgoCD IAM role (between prefix and env)"
  type        = string
}

variable "argocd_capability_name_component" {
  description = "Name component for ArgoCD capability (between prefix and env)"
  type        = string
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD resources"
  type        = string
}

variable "argocd_project_name" {
  description = "ArgoCD project name for cluster registration"
  type        = string
}

variable "idc_instance_arn" {
  description = "ARN of the AWS Identity Center instance used for Argo CD auth"
  type        = string
  default     = null
  nullable    = true
}

variable "idc_region" {
  description = "Region of the Identity Center instance"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_rbac_role_mappings" {
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

variable "argocd_delete_propagation_policy" {
  description = "Delete propagation policy for ArgoCD capability (RETAIN or DELETE)"
  type        = string
  validation {
    condition     = contains(["RETAIN", "DELETE"], var.argocd_delete_propagation_policy)
    error_message = "Delete propagation policy must be either 'RETAIN' or 'DELETE'"
  }
}

##################### ArgoCD Applications ##########################

variable "enable_argocd_apps" {
  description = "Whether to enable ArgoCD Application deployments"
  type        = bool
  default     = false
}

variable "argocd_app_repo_url" {
  description = "Git repository URL containing application manifests. Supports both HTTPS (https://github.com/user/repo.git) and SSH (git@github.com:user/repo.git) URLs. SSH URLs require SSH key credentials to be configured via a Kubernetes Secret with label 'argocd.argoproj.io/secret-type: repository'"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_app_target_revision" {
  description = "Git branch, tag, or commit to sync (default: HEAD)"
  type        = string
  default     = "HEAD"
}

# Backend App Configuration
variable "argocd_app_backend_name" {
  description = "Name of the ArgoCD Application for backend"
  type        = string
}

variable "argocd_app_backend_path" {
  description = "Path within the repository to the backend application manifests"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_app_backend_namespace" {
  description = "Target Kubernetes namespace for the backend application"
  type        = string
}

# Frontend App Configuration
variable "argocd_app_frontend_name" {
  description = "Name of the ArgoCD Application for frontend"
  type        = string
}

variable "argocd_app_frontend_path" {
  description = "Path within the repository to the frontend application manifests"
  type        = string
  default     = null
  nullable    = true
}

variable "argocd_app_frontend_namespace" {
  description = "Target Kubernetes namespace for the frontend application"
  type        = string
}

variable "argocd_app_sync_policy_automated" {
  description = "Enable automated sync policy for ArgoCD Applications"
  type        = bool
  default     = true
}

variable "argocd_app_sync_policy_prune" {
  description = "Enable prune for automated sync (delete resources not in Git)"
  type        = bool
  default     = true
}

variable "argocd_app_sync_policy_self_heal" {
  description = "Enable self-heal for automated sync (auto-sync on drift detection)"
  type        = bool
  default     = true
}
