locals {
  storage_class_name = "${var.prefix}-${var.region}-${var.storage_class_name}-${var.env}"

  # Retrieve ECR information from backend_infra state
  ecr_url = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_url, null)
  
  # Parse ECR URL to extract registry and repository
  # Format: account.dkr.ecr.region.amazonaws.com/repo-name
  ecr_registry   = local.ecr_url != null ? regex("^([^/]+)", local.ecr_url)[0] : ""
  ecr_repository = local.ecr_url != null ? regex("/(.+)$", local.ecr_url)[0] : ""

  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

data "aws_route53_zone" "this" {
  provider    = aws.state_account
  name        = var.domain_name
  private_zone = false
}

data "aws_acm_certificate" "this" {
  provider   = aws.state_account
  domain     = var.domain_name
  most_recent = true
  statuses   = ["ISSUED"]
}

# Create StorageClass for OpenLDAP PVC
resource "kubernetes_storage_class_v1" "this" {
  metadata {
    name = local.storage_class_name
    annotations = var.storage_class_is_default ? {
      "storageclass.kubernetes.io/is-default-class" = "true"
    } : {}
  }

  storage_provisioner    = "ebs.csi.eks.amazonaws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"  # Changed from WaitForFirstConsumer to prevent PVC binding deadlocks
  allow_volume_expansion = true

  parameters = {
    type      = var.storage_class_type
    encrypted = tostring(var.storage_class_encrypted)
  }

  depends_on = [data.aws_eks_cluster.cluster]

  lifecycle {
    # Prevent Terraform from trying to recreate if the resource already exists
    # This helps when the resource exists but isn't in state
    ignore_changes = [
      metadata[0].annotations,
    ]
    # Allow replacement if needed
    replace_triggered_by = []
  }
}

# module "route53" {
#   source = "./modules/route53"

#   use_existing_route53_zone = var.use_existing_route53_zone
#   env                       = var.env
#   region                    = var.region
#   prefix                    = var.prefix
#   domain_name               = var.domain_name
#   subject_alternative_names = var.subject_alternative_names
#   tags                      = local.tags
# }

locals {
  app_name = "${var.prefix}-${var.region}-${var.app_name}-${var.env}"

  # ALB group name: Kubernetes identifier (max 63 chars) used to group Ingresses
  # If alb_group_name is set, concatenate with prefix, region, and env (truncate to 63 chars if needed)
  # If not set, use app_name (truncate to 63 chars if needed)
  alb_group_name = var.alb_group_name != null ? (
    length("${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}") > 63 ?
    substr("${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}", 0, 63) :
    "${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}"
    ) : (
    length(local.app_name) > 63 ? substr(local.app_name, 0, 63) : local.app_name
  )

  # ALB load balancer name: AWS resource name (max 32 chars per AWS constraints)
  # If alb_load_balancer_name is set, concatenate with prefix, region, and env (truncate to 32 chars if needed)
  # If not set, use alb_group_name (truncate to 32 chars if needed)
  alb_load_balancer_name = var.alb_load_balancer_name != null ? (
    length("${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}") > 32 ?
    substr("${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}", 0, 32) :
    "${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}"
    ) : (
    length(local.alb_group_name) > 32 ? substr(local.alb_group_name, 0, 32) : local.alb_group_name
  )

  # ALB zone_id mapping by region (for Route53 alias records)
  # These are the canonical hosted zone IDs for Application Load Balancers
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

  # ALB DNS name: Query AWS directly using the ALB name.
  # While this is the preferred approach, we are reliant on the OpenLDAP module
  # being fully deployed as this guarantees that an Ingress resource exists, which triggers ALB creation.
  # The ALB must exist before this can be queried.
  alb_dns_name = var.use_alb ? data.aws_lb.alb[0].dns_name : null

  # Derive hostnames from domain_name if not explicitly provided
  # These are used for Route53 records and must be non-null
  # Note: domain_name is a required variable (not a resource), so no depends_on is needed
  # The coalesce ensures we always have a value - either from the variable or derived from domain_name
  phpldapadmin_host = coalesce(var.phpldapadmin_host, "phpldapadmin.${var.domain_name}")
  ltb_passwd_host   = coalesce(var.ltb_passwd_host, "passwd.${var.domain_name}")
  twofa_app_host    = coalesce(var.twofa_app_host, "app.${var.domain_name}")
}

# ALB module creates IngressClass and IngressClassParams for EKS Auto Mode
# The Ingress/Service resources in the module are commented out (not needed)
module "alb" {
  source = "./modules/alb"

  count = var.use_alb ? 1 : 0

  env          = var.env
  region       = var.region
  prefix       = var.prefix
  app_name     = local.app_name
  cluster_name = local.cluster_name
  # ingress_alb_name            = var.ingress_alb_name
  # service_alb_name            = var.service_alb_name
  ingressclass_alb_name       = var.ingressclass_alb_name
  ingressclassparams_alb_name = var.ingressclassparams_alb_name
  acm_certificate_arn         = try(data.aws_acm_certificate.this.arn, null)
  alb_scheme                  = var.alb_scheme
  alb_ip_address_type         = var.alb_ip_address_type
  alb_group_name              = local.alb_group_name

  wait_for_crd = var.wait_for_crd
}

##################### OpenLDAP ##########################

# OpenLDAP Module
module "openldap" {
  source = "./modules/openldap"

  env    = var.env
  region = var.region
  prefix = var.prefix

  app_name                 = local.app_name
  openldap_ldap_domain     = var.openldap_ldap_domain
  openldap_admin_password  = var.openldap_admin_password
  openldap_config_password = var.openldap_config_password
  storage_class_name       = local.storage_class_name

  # ECR image configuration
  ecr_registry       = local.ecr_registry
  ecr_repository     = local.ecr_repository
  openldap_image_tag = var.openldap_image_tag

  # Use derived values from locals to ensure non-null values
  # These are derived from domain_name if not explicitly provided
  phpldapadmin_host = local.phpldapadmin_host
  ltb_passwd_host   = local.ltb_passwd_host

  use_alb                = var.use_alb
  ingress_class_name     = var.use_alb ? module.alb[0].ingress_class_name : null
  alb_load_balancer_name = local.alb_load_balancer_name
  alb_target_type        = var.alb_target_type
  acm_cert_arn           = data.aws_acm_certificate.this.arn

  tags = local.tags

  depends_on = [
    kubernetes_storage_class_v1.this,
    module.alb,
  ]
}

# Query AWS for ALB DNS name using the load balancer name.
# While querying AWS directly is the preferred approach, we are reliant on the OpenLDAP module
# being fully deployed as this guarantees that an Ingress resource exists, which triggers ALB creation.
data "aws_lb" "alb" {
  count = var.use_alb ? 1 : 0
  name  = local.alb_load_balancer_name

  # Ensure OpenLDAP module is fully deployed (creates Ingress which triggers ALB creation)
  depends_on = [module.openldap]
}

##################### Route53 Records ##########################

# Route53 A (alias) records for all subdomains pointing to ALB
# All records use consistent ALB data source approach to avoid timing issues

# Route53 record for phpLDAPadmin
module "route53_record_phpldapadmin" {
  source = "./modules/route53_record"

  count = var.use_alb && local.phpldapadmin_host != "" ? 1 : 0

  zone_id  = data.aws_route53_zone.this.zone_id
  name     = local.phpldapadmin_host
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  depends_on = [
    module.openldap, # Ensures Ingress is created (which triggers ALB creation)
    data.aws_lb.alb, # Ensures ALB exists before creating record
  ]

  providers = {
    aws.state_account = aws.state_account
  }
}

# Route53 record for ltb-passwd
module "route53_record_ltb_passwd" {
  source = "./modules/route53_record"

  count = var.use_alb && local.ltb_passwd_host != "" ? 1 : 0

  zone_id  = data.aws_route53_zone.this.zone_id
  name     = local.ltb_passwd_host
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  depends_on = [
    module.openldap, # Ensures Ingress is created (which triggers ALB creation)
    data.aws_lb.alb, # Ensures ALB exists before creating record
  ]

  providers = {
    aws.state_account = aws.state_account
  }
}

# Route53 record for 2FA application
module "route53_record_twofa_app" {
  source = "./modules/route53_record"

  count = var.use_alb && local.twofa_app_host != "" ? 1 : 0

  zone_id  = data.aws_route53_zone.this.zone_id
  name     = local.twofa_app_host
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  depends_on = [
    module.openldap, # Ensures Ingress is created (which triggers ALB creation)
    data.aws_lb.alb, # Ensures ALB exists before creating record
  ]

  providers = {
    aws.state_account = aws.state_account
  }
}

##################### ArgoCD ##########################

# ArgoCD Capability Module
# Deployed early to allow other modules to depend on it
module "argocd" {
  source = "./modules/argocd"

  count = var.enable_argocd ? 1 : 0

  env    = var.env
  region = var.region
  prefix = var.prefix

  cluster_name = local.cluster_name

  argocd_role_name_component       = var.argocd_role_name_component
  argocd_capability_name_component = var.argocd_capability_name_component
  argocd_namespace                 = var.argocd_namespace
  argocd_project_name              = var.argocd_project_name

  idc_instance_arn = var.idc_instance_arn
  idc_region       = var.idc_region

  rbac_role_mappings        = var.argocd_rbac_role_mappings
  argocd_vpce_ids           = var.argocd_vpce_ids
  delete_propagation_policy = var.argocd_delete_propagation_policy
}

# Wait for ArgoCD capability to be fully deployed and ACTIVE
# This ensures proper deployment ordering when ArgoCD is enabled
resource "time_sleep" "wait_for_argocd" {
  count = var.enable_argocd ? 1 : 0

  create_duration = "60s"  # Wait 60 seconds for ArgoCD capability to be ready

  depends_on = [module.argocd]
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
  ecr_registry  = local.ecr_registry
  ecr_repository = local.ecr_repository
  image_tag     = var.postgresql_image_tag

  tags = local.tags

  # Static list: always depends on OpenLDAP
  # ArgoCD dependency is handled implicitly through module ordering (ArgoCD is defined before this module)
  depends_on = [module.openldap]
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

  # Static list: always depends on OpenLDAP
  # ArgoCD dependency is handled implicitly through module ordering (ArgoCD is defined before this module)
  depends_on = [module.openldap]
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

  count = var.enable_argocd_apps && var.enable_argocd && var.argocd_app_repo_url != null && var.argocd_app_backend_path != null ? 1 : 0

  app_name              = var.argocd_app_backend_name
  argocd_namespace      = var.argocd_namespace
  argocd_project_name   = var.argocd_project_name
  cluster_name_in_argo  = module.argocd[0].local_cluster_secret_name
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
}

# ArgoCD Application - Frontend
module "argocd_app_frontend" {
  source = "./modules/argocd_app"

  count = var.enable_argocd_apps && var.enable_argocd && var.argocd_app_repo_url != null && var.argocd_app_frontend_path != null ? 1 : 0

  app_name              = var.argocd_app_frontend_name
  argocd_namespace      = var.argocd_namespace
  argocd_project_name   = var.argocd_project_name
  cluster_name_in_argo  = module.argocd[0].local_cluster_secret_name
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
}
