locals {
  storage_class_name = "${var.prefix}-${var.region}-${var.storage_class_name}-${var.env}"

  # Retrieve ECR information from backend_infra state
  ecr_registry   = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_registry, "")
  ecr_repository = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_repository, "")

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

# ACM Certificate must be in the deployment account (not state account)
# EKS Auto Mode ALB controller cannot access cross-account certificates
# The certificate must exist in the same account where the ALB is created
# Certificate is issued from Private CA in State Account but stored in Deployment Account
# Each deployment account (development, production) has its own certificate
data "aws_acm_certificate" "this" {
  # Use default provider (deployment account) instead of state_account
  # EKS Auto Mode ALB controller requires certificate in the same account
  # Certificate is issued from Private CA in State Account but stored here
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
  volume_binding_mode    = "Immediate" # Changed from WaitForFirstConsumer to prevent PVC binding deadlocks
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
  openldap_secret_name     = var.openldap_secret_name
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
  alb_ssl_policy         = var.alb_ssl_policy
  acm_cert_arn           = data.aws_acm_certificate.this.arn

  enable_network_policies = var.enable_network_policies

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

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = local.phpldapadmin_host
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

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = local.ltb_passwd_host
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
