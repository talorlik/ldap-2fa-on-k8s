locals {
  # Determine values template path
  values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/openldap-values.tpl.yaml"

  # Compute base DN from domain if not provided
  # e.g., "ldap.talorlik.internal" -> "dc=ldap,dc=talorlik,dc=internal"
  computed_base_dn = var.openldap_base_dn != null ? var.openldap_base_dn : join(",", [
    for part in split(".", var.openldap_ldap_domain) : "dc=${part}"
  ])

  openldap_values = templatefile(
    local.values_template_path,
    {
      storage_class_name   = var.storage_class_name
      openldap_ldap_domain = var.openldap_ldap_domain
      openldap_base_dn     = local.computed_base_dn
      app_name             = var.app_name
      # ECR image configuration
      ecr_registry       = var.ecr_registry
      ecr_repository     = var.ecr_repository
      openldap_image_tag = var.openldap_image_tag
      # ALB configuration - IngressClassParams handles scheme and ipAddressType
      ingress_class_name     = var.use_alb && var.ingress_class_name != null ? var.ingress_class_name : "alb"
      alb_load_balancer_name = var.alb_load_balancer_name
      acm_cert_arn           = var.acm_cert_arn
      phpldapadmin_host      = var.phpldapadmin_host
      ltb_passwd_host        = var.ltb_passwd_host
      # Per-Ingress annotations still needed for grouping, TLS, ports, etc.
      alb_target_type = var.alb_target_type
      alb_ssl_policy  = var.alb_ssl_policy
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
    # Ignore changes to labels that might be modified by ArgoCD, Helm, or other controllers
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
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

  lifecycle {
    # Ignore changes to labels/annotations that might be modified by ArgoCD, Helm, or other controllers
    # This prevents Terraform from trying to recreate the secret if it's modified externally
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
    # Create before destroy to avoid downtime if secret needs to be recreated
    create_before_destroy = true
  }

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

  atomic          = true
  cleanup_on_fail = true
  # Force recreation on configuration changes
  recreate_pods   = true
  force_update    = true
  wait            = true
  wait_for_jobs   = true
  upgrade_install = true
  # 5 minute timeout as requested
  timeout = 300 # 5 minutes in seconds

  # Allow replacement if name conflict occurs
  replace = true

  values = [local.openldap_values]

  # CRITICAL: The jp-gouin/helm-openldap chart ignores global.existingSecret and creates
  # its own secret with the release name. We use set_sensitive to inject the correct
  # passwords directly into the chart values. This ensures:
  # 1. The Helm-created secret has the correct password from the start
  # 2. OpenLDAP initializes the PVC with the correct password
  # 3. Passwords are marked sensitive (not shown in plan output or logs)
  # Ref: https://github.com/jp-gouin/helm-openldap - uses global.adminPassword/configPassword
  set_sensitive {
    name  = "global.adminPassword"
    value = var.openldap_admin_password
  }

  set_sensitive {
    name  = "global.configPassword"
    value = var.openldap_config_password
  }

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
