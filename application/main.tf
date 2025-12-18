locals {
  storage_class_name = "${var.prefix}-${var.region}-${var.storage_class_name}-${var.env}"

  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

data "aws_acm_certificate" "this" {
  domain      = var.domain_name
  most_recent = true
  statuses    = ["ISSUED"]
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
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = var.storage_class_type
    encrypted = tostring(var.storage_class_encrypted)
  }

  depends_on = [data.aws_eks_cluster.cluster]
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

  # Get ALB DNS name from either Ingress (they should both point to the same ALB)
  # Both Ingress resources use the same ALB with host-based routing
  alb_dns_name = try(
    data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname,
    ""
  )

  openldap_values = templatefile(
    "${path.module}/helm/openldap-values.tpl.yaml",
    {
      storage_class_name       = local.storage_class_name
      openldap_ldap_domain     = var.openldap_ldap_domain
      openldap_admin_password  = var.openldap_admin_password
      openldap_config_password = var.openldap_config_password
      app_name                 = local.app_name
      # ALB configuration - IngressClassParams handles scheme and ipAddressType
      ingress_class_name = var.use_alb ? module.alb[0].ingress_class_name : "alb"
      # alb_group_name           = local.alb_group_name
      alb_load_balancer_name = local.alb_load_balancer_name
      acm_cert_arn           = data.aws_acm_certificate.this.arn
      phpldapadmin_host      = var.phpldapadmin_host
      ltb_passwd_host        = var.ltb_passwd_host
      # Per-Ingress annotations still needed for grouping, TLS, ports, etc.
      alb_target_type = var.alb_target_type
      # alb_ssl_policy           = var.alb_ssl_policy
    }
  )
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
}

# Helm release for OpenLDAP Stack HA
resource "helm_release" "openldap" {
  name       = "openldap-stack-ha"
  repository = "https://jp-gouin.github.io/helm-openldap"
  chart      = "openldap-stack-ha"
  version    = "4.0.1"

  namespace        = "ldap"
  create_namespace = true

  # Force recreation on configuration changes
  recreate_pods = true
  force_update  = true

  values = [local.openldap_values]

  depends_on = [
    data.aws_eks_cluster.cluster,
    data.aws_route53_zone.this,
    data.aws_acm_certificate.this,
    kubernetes_storage_class_v1.this,
    module.alb,
  ]
}

# Create Network Policies for secure internal cluster communication
# Generic policies: Any service can communicate with any service, but only on secure ports
module "network_policies" {
  source = "./modules/network-policies"

  namespace = "ldap"

  depends_on = [helm_release.openldap]
}

# Get Ingress resources created by Helm chart to extract ALB DNS names
data "kubernetes_ingress_v1" "phpldapadmin" {
  metadata {
    name      = "openldap-stack-ha-phpldapadmin"
    namespace = "ldap"
  }

  depends_on = [helm_release.openldap]
}

data "kubernetes_ingress_v1" "ltb_passwd" {
  metadata {
    name      = "openldap-stack-ha-ltb-passwd"
    namespace = "ldap"
  }

  depends_on = [helm_release.openldap]
}

# Route53 A (alias) records for subdomains pointing to ALB
resource "aws_route53_record" "phpldapadmin" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.phpldapadmin_host
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.openldap,
    data.kubernetes_ingress_v1.phpldapadmin,
  ]
}

resource "aws_route53_record" "ltb_passwd" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.ltb_passwd_host
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.openldap,
    data.kubernetes_ingress_v1.ltb_passwd,
  ]
}

# Route53 A (alias) record for 2FA application
resource "aws_route53_record" "twofa_app" {
  count = var.twofa_app_host != null ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.twofa_app_host
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.openldap, # Ensures ALB exists before creating record
  ]
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
  database_name     = var.postgresql_database_name
  database_username = var.postgresql_database_username
  database_password = var.postgresql_database_password
  storage_class     = local.storage_class_name
  storage_size      = var.postgresql_storage_size

  tags = local.tags

  depends_on = [
    kubernetes_storage_class_v1.this,
  ]
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
  redis_password     = var.redis_password
  storage_class_name = local.storage_class_name
  storage_size       = var.redis_storage_size
  chart_version      = var.redis_chart_version

  # Network policy configuration
  backend_namespace = var.argocd_app_backend_namespace

  tags = local.tags

  depends_on = [
    kubernetes_storage_class_v1.this,
  ]
}

##################### ArgoCD ##########################

# ArgoCD Capability Module
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

# ArgoCD Application - Backend
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

  depends_on_resources = [
    module.argocd[0].argocd_capability_name
  ]
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

  depends_on_resources = [
    module.argocd[0].argocd_capability_name
  ]
}
