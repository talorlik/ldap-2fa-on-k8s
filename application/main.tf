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

  depends_on = [
    data.terraform_remote_state.application_infra
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
