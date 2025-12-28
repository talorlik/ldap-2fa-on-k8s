locals {
  # Determine values template path
  values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/openldap-values.tpl.yaml"

  openldap_values = templatefile(
    local.values_template_path,
    {
      storage_class_name   = var.storage_class_name
      openldap_ldap_domain = var.openldap_ldap_domain
      openldap_secret_name = var.openldap_secret_name
      app_name             = var.app_name
      # ALB configuration - IngressClassParams handles scheme and ipAddressType
      ingress_class_name     = var.use_alb && var.ingress_class_name != null ? var.ingress_class_name : "alb"
      alb_load_balancer_name = var.alb_load_balancer_name
      acm_cert_arn           = var.acm_cert_arn
      phpldapadmin_host      = var.phpldapadmin_host
      ltb_passwd_host        = var.ltb_passwd_host
      # Per-Ingress annotations still needed for grouping, TLS, ports, etc.
      alb_target_type = var.alb_target_type
    }
  )
}

# Create namespace for OpenLDAP
resource "kubernetes_namespace" "openldap" {
  metadata {
    name = var.namespace

    labels = {
      name        = var.namespace
      environment = var.env
      managed-by  = "terraform"
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# Create Kubernetes secret for OpenLDAP passwords
# Passwords are sourced from GitHub Secrets via TF_VAR_openldap_admin_password and TF_VAR_openldap_config_password
resource "kubernetes_secret" "openldap_passwords" {
  metadata {
    name      = var.openldap_secret_name
    namespace = kubernetes_namespace.openldap.metadata[0].name

    labels = {
      app         = "openldap"
      environment = var.env
      managed-by  = "terraform"
    }
  }

  data = {
    "LDAP_ADMIN_PASSWORD"        = var.openldap_admin_password
    "LDAP_CONFIG_ADMIN_PASSWORD" = var.openldap_config_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.openldap]
}

# Helm release for OpenLDAP Stack HA
resource "helm_release" "openldap" {
  name       = var.helm_release_name
  repository = var.helm_chart_repository
  chart      = var.helm_chart_name
  version    = var.helm_chart_version

  namespace        = kubernetes_namespace.openldap.metadata[0].name
  create_namespace = false

  # Force recreation on configuration changes
  recreate_pods = true
  force_update  = true

  values = [local.openldap_values]

  depends_on = [
    kubernetes_namespace.openldap,
    kubernetes_secret.openldap_passwords,
  ]
}

# Create Network Policies for secure internal cluster communication
# Generic policies: Any service can communicate with any service, but only on secure ports
module "network_policies" {
  source = "../network-policies"

  count = var.enable_network_policies ? 1 : 0

  namespace = var.namespace

  depends_on = [helm_release.openldap]
}

# Get Ingress resources created by Helm chart to extract ALB DNS names
data "kubernetes_ingress_v1" "phpldapadmin" {
  metadata {
    name      = "${var.helm_release_name}-phpldapadmin"
    namespace = var.namespace
  }

  depends_on = [helm_release.openldap]
}

data "kubernetes_ingress_v1" "ltb_passwd" {
  metadata {
    name      = "${var.helm_release_name}-ltb-passwd"
    namespace = var.namespace
  }

  depends_on = [helm_release.openldap]
}

# Route53 A (alias) records for subdomains pointing to ALB
resource "aws_route53_record" "phpldapadmin" {
  zone_id = var.route53_zone_id
  name    = var.phpldapadmin_host
  type    = "A"

  alias {
    name                   = try(data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname, data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname, "")
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.openldap,
    data.kubernetes_ingress_v1.phpldapadmin,
    data.kubernetes_ingress_v1.ltb_passwd,
  ]
}

resource "aws_route53_record" "ltb_passwd" {
  zone_id = var.route53_zone_id
  name    = var.ltb_passwd_host
  type    = "A"

  alias {
    name                   = try(data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname, data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname, "")
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    helm_release.openldap,
    data.kubernetes_ingress_v1.phpldapadmin,
    data.kubernetes_ingress_v1.ltb_passwd,
  ]
}
