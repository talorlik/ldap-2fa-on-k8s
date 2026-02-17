locals {
  # Retrieve ECR information from backend_infra state
  ecr_registry   = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_registry, "")
  ecr_repository = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_repository, "")

  # Retrieve StorageClass name from application_infra state
  storage_class_name = try(data.terraform_remote_state.application_infra[0].outputs.storage_class_name, "")

  # Retrieve ArgoCD capability outputs from application_infra state
  argocd_local_cluster_secret_name = try(data.terraform_remote_state.application_infra[0].outputs.local_cluster_secret_name, "")
  argocd_namespace                 = try(data.terraform_remote_state.application_infra[0].outputs.argocd_namespace, "")
  argocd_project_name              = try(data.terraform_remote_state.application_infra[0].outputs.argocd_project_name, "")

  # Retrieve ALB DNS name from application_infra state (for Route53 record)
  alb_dns_name = try(data.terraform_remote_state.application_infra[0].outputs.alb_dns_name, "")

  # ALB name and IngressClass from application_infra (same values as OpenLDAP Ingresses; required so 2FA Ingresses share the ALB)
  alb_load_balancer_name = try(data.terraform_remote_state.application_infra[0].outputs.alb_load_balancer_name, "")
  alb_ingress_class_name = try(data.terraform_remote_state.application_infra[0].outputs.alb_ingress_class_name, "")

  # LDAP config from application_infra (OpenLDAP deployment) for admin-seed Job
  ldap_host              = try(data.terraform_remote_state.application_infra[0].outputs.ldap_host, "")
  ldap_base_dn           = try(data.terraform_remote_state.application_infra[0].outputs.ldap_base_dn, "")
  ldap_admin_dn          = try(data.terraform_remote_state.application_infra[0].outputs.ldap_admin_dn, "")
  ldap_admin_group_dn    = try(data.terraform_remote_state.application_infra[0].outputs.ldap_admin_group_dn, "")
  ldap_user_search_base  = try(data.terraform_remote_state.application_infra[0].outputs.ldap_user_search_base, "ou=users")
  ldap_group_search_base = try(data.terraform_remote_state.application_infra[0].outputs.ldap_group_search_base, "ou=groups")

  # Helm parameters for 2FA app Ingress: use shared ALB name and IngressClass so Ingresses attach to existing ALB (no conflict).
  # Must set paths explicitly: setting only ingress.hosts[0].host can replace the host object and drop paths (Helm --set merge behavior).
  argocd_helm_alb_parameters_backend = local.alb_load_balancer_name != "" && local.alb_ingress_class_name != "" ? [
    {
      name         = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/load-balancer-name"
      value        = local.alb_load_balancer_name
      force_string = true
    },
    {
      name         = "ingress.className"
      value        = local.alb_ingress_class_name
      force_string = true
    },
    {
      name         = "ingress.hosts[0].host"
      value        = local.twofa_app_host
      force_string = true
    },
    {
      name         = "ingress.hosts[0].paths[0].path"
      value        = "/api"
      force_string = true
    },
    {
      name         = "ingress.hosts[0].paths[0].pathType"
      value        = "Prefix"
      force_string = true
    }
  ] : []

  argocd_helm_alb_parameters_frontend = local.alb_load_balancer_name != "" && local.alb_ingress_class_name != "" ? [
    {
      name         = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/load-balancer-name"
      value        = local.alb_load_balancer_name
      force_string = true
    },
    {
      name         = "ingress.className"
      value        = local.alb_ingress_class_name
      force_string = true
    },
    {
      name         = "ingress.hosts[0].host"
      value        = local.twofa_app_host
      force_string = true
    },
    {
      name         = "ingress.hosts[0].paths[0].path"
      value        = "/"
      force_string = true
    },
    {
      name         = "ingress.hosts[0].paths[0].pathType"
      value        = "Prefix"
      force_string = true
    }
  ] : []

  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

data "aws_route53_zone" "this" {
  provider     = aws.state_account
  name         = var.domain_name
  private_zone = false
}

# ALB zone_id mapping by region (for Route53 alias records)
# These are the canonical hosted zone IDs for Application Load Balancers
locals {
  alb_zone_ids = {
    "us-east-1"      = "Z35SXDOTRQ7X7K"
    "us-east-2"      = "Z3AADJGX6KTTL2"
    "us-west-1"      = "Z1M58G0W56PQJA"
    "us-west-2"      = "Z33MTJ483K6KNU"
    "eu-west-1"      = "Z3DZXE0Q2N3XK0"
    "eu-west-2"      = "Z3GKZC51ZF0DB4"
    "eu-west-3"      = "Z3Q77PNBUNY4FR"
    "eu-central-1"   = "Z215JYRZR1TBD5"
    "ap-southeast-1" = "Z1LMS91P8CMLE5"
    "ap-southeast-2" = "Z1GM3OXH4ZPM65"
    "ap-northeast-1" = "Z14GRHDCWA56QT"
    "ap-northeast-2" = "Z1W9GUF3Q8Z8BZ"
    "sa-east-1"      = "Z2P70J7HTTTPLU"
  }
  alb_zone_id = lookup(local.alb_zone_ids, var.region, "Z35SXDOTRQ7X7K")

  # Derive hostname from domain_name if not explicitly provided
  twofa_app_host = coalesce(var.twofa_app_host, "app.${var.domain_name}")
}

##################### PostgreSQL for User Storage ##########################

# PostgreSQL Module for user signup data storage
module "postgresql" {
  source = "./modules/postgresql"

  count = var.enable_postgresql ? 1 : 0

  env    = var.env
  region = var.region
  prefix = var.prefix

  namespace         = var.postgresql_namespace
  secret_name       = var.postgresql_secret_name
  database_name     = var.postgresql_database_name
  database_username = var.postgresql_database_username
  database_password = var.postgresql_database_password
  storage_class     = local.storage_class_name
  storage_size      = var.postgresql_storage_size

  # ECR image configuration
  ecr_registry   = local.ecr_registry
  ecr_repository = local.ecr_repository
  image_tag      = var.postgresql_image_tag

  tags = local.tags
}

##################### Redis for SMS OTP Storage ##########################

# Redis Module for centralized SMS OTP code storage with TTL-based expiration
module "redis" {
  source = "./modules/redis"

  count = var.enable_redis ? 1 : 0

  env    = var.env
  region = var.region
  prefix = var.prefix

  enable_redis       = var.enable_redis
  namespace          = var.redis_namespace
  secret_name        = var.redis_secret_name
  redis_password     = var.redis_password
  storage_class_name = local.storage_class_name
  storage_size       = var.redis_storage_size
  chart_version      = var.redis_chart_version

  # ECR image configuration
  ecr_registry   = local.ecr_registry
  ecr_repository = local.ecr_repository
  image_tag      = var.redis_image_tag

  # Network policy configuration
  backend_namespace = var.argocd_app_backend_namespace

  tags = local.tags
}

##################### SES for Email Verification ##########################

# SES Module for email verification
module "ses" {
  source = "./modules/ses"

  count = var.enable_email_verification ? 1 : 0

  env          = var.env
  region       = var.region
  prefix       = var.prefix
  cluster_name = local.cluster_name

  sender_email              = var.ses_sender_email
  sender_domain             = var.ses_sender_domain
  iam_role_name             = var.ses_iam_role_name
  service_account_namespace = var.argocd_app_backend_namespace
  service_account_name      = "ldap-2fa-backend"
  route53_zone_id           = var.ses_route53_zone_id != null ? var.ses_route53_zone_id : data.aws_route53_zone.this.zone_id

  tags = local.tags

  # Pass state account provider for Route53 resources
  # If state_account_role_arn is null, state_account provider uses default credentials
  # Note: ses module needs both aws and aws.state_account
  providers = {
    aws               = aws
    aws.state_account = aws.state_account
  }
}

##################### SNS for SMS 2FA ##########################

# SNS Module for SMS-based 2FA verification
module "sns" {
  source = "./modules/sns"

  count = var.enable_sms_2fa ? 1 : 0

  env          = var.env
  region       = var.region
  prefix       = var.prefix
  cluster_name = local.cluster_name

  sns_topic_name            = var.sns_topic_name
  sns_display_name          = var.sns_display_name
  iam_role_name             = var.sns_iam_role_name
  service_account_namespace = var.argocd_app_backend_namespace
  service_account_name      = "ldap-2fa-backend"

  configure_sms_preferences = var.configure_sms_preferences
  sms_sender_id             = var.sms_sender_id
  sms_type                  = var.sms_type
  sms_monthly_spend_limit   = var.sms_monthly_spend_limit

  tags = local.tags
}

##################### Backend namespace and LDAP admin secret
# Backend pod expects secret "ldap-admin-secret" with key LDAP_ADMIN_PASSWORD in its namespace.
# We create the namespace so Terraform owns it; we create the secret when openldap_admin_password is set.
# IMPORTANT: The password is read from the OpenLDAP secret in the ldap namespace to ensure consistency.
# This prevents password mismatches between OpenLDAP deployment and backend application.
resource "kubernetes_namespace" "backend_app" {
  count = var.enable_argocd_apps && var.argocd_app_backend_path != null ? 1 : 0

  metadata {
    name = var.argocd_app_backend_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Read OpenLDAP admin password from the OpenLDAP secret in ldap namespace
# This ensures the backend uses the same password as OpenLDAP was initialized with
# 
# IMPORTANT: Cross-namespace secret reading works because:
# 1. Terraform Kubernetes provider uses the Kubernetes API (not pod-to-pod communication)
# 2. Network policies only affect pod-to-pod traffic, not API calls
# 3. The provider authenticates via EKS cluster auth (data.aws_eks_cluster_auth.cluster.token)
#    which typically grants cluster-admin permissions, allowing secret reads from any namespace
# 
# If the secret doesn't exist or cannot be read, we fall back to var.openldap_admin_password
# This fallback is useful during initial deployment when OpenLDAP may not be deployed yet
data "kubernetes_secret" "openldap_admin" {
  count = var.enable_argocd_apps && var.argocd_app_backend_path != null && var.openldap_secret_name != "" && var.openldap_namespace != "" ? 1 : 0

  metadata {
    name      = var.openldap_secret_name
    namespace = var.openldap_namespace
  }
}

locals {
  # Use password from OpenLDAP secret if available, otherwise fall back to variable
  # This ensures consistency: if OpenLDAP secret exists and was successfully read, use it; otherwise use provided variable
  # 
  # Behavior:
  # - If openldap_secret_name is empty: Uses var.openldap_admin_password (data source not created)
  # - If data source is created but secret doesn't exist: Terraform will error (enforces deployment order)
  # - If data source succeeds: Uses password from secret (ensures consistency)
  # - If data source count is 0: Falls back to var.openldap_admin_password
  #
  # This approach ensures that once OpenLDAP is deployed, the backend always uses the same password,
  # preventing password mismatches like the one that caused the admin-seed-job to fail.
  #
  # SECURITY NOTE: This local value contains a sensitive password. It is:
  # - Derived from var.openldap_admin_password (marked sensitive = true) OR from a Kubernetes secret
  # - Only used internally in kubernetes_secret resource (never exposed in outputs)
  # - Terraform will mask it in plan/apply logs when derived from sensitive variable
  # - Never output or logged - only used to create the Kubernetes secret resource
  # - The kubernetes_secret resource handles the data securely (base64 encoding, encrypted at rest in etcd)
  # 
  # Note: We use nonsensitive() to decode the base64 value, but the resulting password is still treated
  # as sensitive when used in the kubernetes_secret resource because it's derived from sensitive sources.
  ldap_admin_password = length(data.kubernetes_secret.openldap_admin) > 0 && try(data.kubernetes_secret.openldap_admin[0].data["LDAP_ADMIN_PASSWORD"], null) != null ? (
    nonsensitive(base64decode(data.kubernetes_secret.openldap_admin[0].data["LDAP_ADMIN_PASSWORD"]))
  ) : var.openldap_admin_password
}

resource "kubernetes_secret" "ldap_admin" {
  count = var.enable_argocd_apps && var.argocd_app_backend_path != null && local.ldap_admin_password != "" ? 1 : 0

  metadata {
    name      = "ldap-admin-secret"
    namespace = kubernetes_namespace.backend_app[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ldap-2fa-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "LDAP_ADMIN_PASSWORD" = local.ldap_admin_password
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.backend_app,
    data.kubernetes_secret.openldap_admin,
  ]
}

# Copy PostgreSQL secret to backend namespace
# Backend application needs postgresql-secret in its own namespace (2fa-app)
# but PostgreSQL module creates it in ldap-2fa namespace
resource "kubernetes_secret" "postgresql_secret_backend_namespace" {
  count = var.enable_argocd_apps && var.argocd_app_backend_path != null && var.enable_postgresql ? 1 : 0

  metadata {
    name      = var.postgresql_secret_name
    namespace = kubernetes_namespace.backend_app[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ldap-2fa-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "password" = var.postgresql_database_password
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.backend_app,
    module.postgresql,
  ]
}

# Copy Redis secret to backend namespace (if Redis is enabled)
# Backend application may need redis-secret in its own namespace
resource "kubernetes_secret" "redis_secret_backend_namespace" {
  count = var.enable_argocd_apps && var.argocd_app_backend_path != null && var.enable_redis ? 1 : 0

  metadata {
    name      = var.redis_secret_name
    namespace = kubernetes_namespace.backend_app[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ldap-2fa-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "redis-password" = var.redis_password
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.backend_app,
    module.redis,
  ]
}

##################### First admin user seed (optional)
# When all admin_seed_* variables are set, create a secret and a one-time Job that
# seeds the first admin user (same username/password as LDAP admin) with email/phone
# pre-verified. Values must be set via TF_VAR_admin_seed_* (e.g. from GitHub Secrets);
# never hard-code in tfvars.
locals {
  admin_seed_enabled = var.enable_argocd_apps && var.argocd_app_backend_path != null && var.enable_postgresql && var.openldap_admin_password != "" && var.admin_seed_username != "" && var.admin_seed_email != "" && var.admin_seed_first_name != "" && var.admin_seed_last_name != "" && var.admin_seed_phone_country_code != "" && var.admin_seed_phone_number != ""
}

resource "kubernetes_secret" "admin_seed" {
  count = local.admin_seed_enabled ? 1 : 0

  metadata {
    name      = "admin-seed-secret"
    namespace = kubernetes_namespace.backend_app[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ldap-2fa-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "ADMIN_SEED_USERNAME"           = var.admin_seed_username
    "ADMIN_SEED_EMAIL"              = var.admin_seed_email
    "ADMIN_SEED_FIRST_NAME"         = var.admin_seed_first_name
    "ADMIN_SEED_LAST_NAME"          = var.admin_seed_last_name
    "ADMIN_SEED_PHONE_COUNTRY_CODE" = var.admin_seed_phone_country_code
    "ADMIN_SEED_PHONE_NUMBER"       = var.admin_seed_phone_number
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.backend_app]
}

resource "kubernetes_job" "admin_seed" {
  count = local.admin_seed_enabled ? 1 : 0

  # Do not block Terraform apply on job completion. The job runs asynchronously and
  # retries (backoff_limit = 10) until DB/LDAP are ready; in CI the apply would
  # otherwise time out or fail if the seed takes longer than the provider timeout.
  wait_for_completion = false

  metadata {
    name      = "admin-seed-job"
    namespace = kubernetes_namespace.backend_app[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "ldap-2fa-backend"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    ttl_seconds_after_finished = 86400 # Keep for 24h for debugging; then cleanup
    backoff_limit              = 10    # Retry until DB/LDAP are ready

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "admin-seed"
        }
      }
      spec {
        restart_policy = "OnFailure"
        container {
          name    = "seed"
          image   = "${local.ecr_registry}/${local.ecr_repository}:${var.backend_image_tag}"
          command = ["python", "-m", "app.seed_admin"]
          env_from {
            secret_ref {
              name = kubernetes_secret.admin_seed[0].metadata[0].name
            }
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.ldap_admin[0].metadata[0].name
            }
          }
          env {
            name  = "DATABASE_HOST"
            value = "postgresql.${var.postgresql_namespace}.svc.cluster.local"
          }
          env {
            name  = "DATABASE_PORT"
            value = "5432"
          }
          env {
            name  = "DATABASE_USER"
            value = var.postgresql_database_username
          }
          env {
            name  = "DATABASE_NAME"
            value = var.postgresql_database_name
          }
          env {
            name = "DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgresql_secret_backend_namespace[0].metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name  = "LDAP_HOST"
            value = local.ldap_host
          }
          env {
            name  = "LDAP_PORT"
            value = "389"
          }
          env {
            name  = "LDAP_BASE_DN"
            value = local.ldap_base_dn
          }
          env {
            name  = "LDAP_ADMIN_DN"
            value = local.ldap_admin_dn
          }
          env {
            name  = "LDAP_ADMIN_GROUP_DN"
            value = local.ldap_admin_group_dn
          }
          env {
            name  = "LDAP_USER_SEARCH_BASE"
            value = local.ldap_user_search_base
          }
          env {
            name  = "LDAP_GROUP_SEARCH_BASE"
            value = local.ldap_group_search_base
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.admin_seed,
    kubernetes_secret.ldap_admin,
    kubernetes_secret.postgresql_secret_backend_namespace,
  ]
}

##################### ArgoCD Application - Backend
module "argocd_app_backend" {
  source = "./modules/argocd_app"

  count = var.enable_argocd_apps && local.argocd_local_cluster_secret_name != "" && var.argocd_app_repo_url != null && var.argocd_app_backend_path != null ? 1 : 0

  app_name              = var.argocd_app_backend_name
  argocd_namespace      = local.argocd_namespace
  argocd_project_name   = local.argocd_project_name
  cluster_name_in_argo  = local.argocd_local_cluster_secret_name
  repo_url              = var.argocd_app_repo_url
  target_revision       = var.argocd_app_target_revision
  repo_path             = var.argocd_app_backend_path
  destination_namespace = var.argocd_app_backend_namespace

  sync_policy = var.argocd_app_sync_policy_automated ? {
    automated = {
      prune       = var.argocd_app_sync_policy_prune
      self_heal   = var.argocd_app_sync_policy_self_heal
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true"]
  } : null

  helm_config = length(local.argocd_helm_alb_parameters_backend) > 0 ? {
    parameters = local.argocd_helm_alb_parameters_backend
  } : null

  depends_on = [
    data.terraform_remote_state.application_infra,
    kubernetes_secret.ldap_admin,
    # PostgreSQL secret in backend namespace (created when enable_postgresql=true)
    # Terraform will handle count=0 gracefully
    kubernetes_secret.postgresql_secret_backend_namespace,
    # Redis secret in backend namespace (created when enable_redis=true)
    # Terraform will handle count=0 gracefully
    kubernetes_secret.redis_secret_backend_namespace,
    # Modules ensure PostgreSQL and Redis are deployed first
    # These are safe to reference even with count (Terraform handles it)
    module.postgresql,
    module.redis,
  ]
}

# ArgoCD Application - Frontend
module "argocd_app_frontend" {
  source = "./modules/argocd_app"

  count = var.enable_argocd_apps && local.argocd_local_cluster_secret_name != "" && var.argocd_app_repo_url != null && var.argocd_app_frontend_path != null ? 1 : 0

  app_name              = var.argocd_app_frontend_name
  argocd_namespace      = local.argocd_namespace
  argocd_project_name   = local.argocd_project_name
  cluster_name_in_argo  = local.argocd_local_cluster_secret_name
  repo_url              = var.argocd_app_repo_url
  target_revision       = var.argocd_app_target_revision
  repo_path             = var.argocd_app_frontend_path
  destination_namespace = var.argocd_app_frontend_namespace

  sync_policy = var.argocd_app_sync_policy_automated ? {
    automated = {
      prune       = var.argocd_app_sync_policy_prune
      self_heal   = var.argocd_app_sync_policy_self_heal
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true"]
  } : null

  helm_config = length(local.argocd_helm_alb_parameters_frontend) > 0 ? {
    parameters = local.argocd_helm_alb_parameters_frontend
  } : null

  depends_on = [
    data.terraform_remote_state.application_infra
  ]
}

##################### Route53 Record for 2FA Application ##########################

# Route53 record for 2FA application
module "route53_record_twofa_app" {
  source = "../application_infra/modules/route53_record"

  count = local.alb_dns_name != "" && local.twofa_app_host != "" ? 1 : 0

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = local.twofa_app_host
  alb_dns_name = local.alb_dns_name
  alb_zone_id  = local.alb_zone_id

  depends_on = [
    data.terraform_remote_state.application_infra
  ]

  providers = {
    aws.state_account = aws.state_account
  }
}
