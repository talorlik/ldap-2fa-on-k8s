/**
 * PostgreSQL Module
 *
 * Deploys PostgreSQL using the Bitnami Helm chart for user storage
 * in the LDAP 2FA application signup system.
 */

locals {
  name = "${var.prefix}-${var.region}-postgresql-${var.env}"

  # Determine values template path
  values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/postgresql-values.tpl.yaml"

  # Build PostgreSQL Helm values using templatefile
  # Note: We pass the secret name variable (not resource) to avoid circular dependency
  # The secret resource is created separately with the same name
  postgresql_values = templatefile(
    local.values_template_path,
    {
      secret_name               = var.secret_name
      database_name             = var.database_name
      database_username         = var.database_username
      storage_class             = var.storage_class
      storage_size              = var.storage_size
      resources_requests_cpu    = var.resources.requests.cpu
      resources_requests_memory = var.resources.requests.memory
      resources_limits_cpu      = var.resources.limits.cpu
      resources_limits_memory   = var.resources.limits.memory
      ecr_registry              = var.ecr_registry
      ecr_repository            = var.ecr_repository
      image_tag                 = var.image_tag
    }
  )
}

# Create namespace if it doesn't exist
resource "kubernetes_namespace" "postgresql" {
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

# Create Kubernetes secret for PostgreSQL password
# Password is sourced from GitHub Secrets via TF_VAR_postgresql_database_password
resource "kubernetes_secret" "postgresql_password" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace.postgresql.metadata[0].name

    labels = {
      app         = local.name
      environment = var.env
      managed-by  = "terraform"
    }
  }

  data = {
    "password" = var.database_password
  }

  type = "Opaque"
}

# PostgreSQL Helm release
resource "helm_release" "postgresql" {
  name = local.name
  # repository = "https://charts.bitnami.com/bitnami"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  version    = var.chart_version
  namespace  = kubernetes_namespace.postgresql.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  recreate_pods   = true
  force_update    = true
  wait            = true
  wait_for_jobs   = true
  timeout         = 600 # Reduced from 1200 to 600 seconds (10 min) for faster debugging
  upgrade_install = true

  # Allow replacement if name conflict occurs
  replace = true

  # Use templatefile to inject values into the official Bitnami PostgreSQL Helm chart values template
  # Note: The secret name is passed to the template, and the secret resource is created separately
  values = [local.postgresql_values]

  depends_on = [
    kubernetes_namespace.postgresql,
    kubernetes_secret.postgresql_password,
  ]
}
