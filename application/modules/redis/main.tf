/**
 * Redis Module
 *
 * Deploys Redis using the Bitnami Helm chart for SMS OTP code storage
 * in the LDAP 2FA application. Provides TTL-based automatic expiration
 * and shared state across backend replicas.
 */

locals {
  name = "${var.prefix}-${var.region}-redis-${var.env}"

  # Determine values template path
  values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/redis-values.tpl.yaml"

  # Build Redis Helm values using templatefile
  # Note: We pass the secret name variable (not resource) to avoid circular dependency
  # The secret resource is created separately with the same name
  redis_values = templatefile(
    local.values_template_path,
    {
      secret_name               = var.secret_name
      persistence_enabled       = var.persistence_enabled
      storage_class_name        = var.storage_class_name
      storage_size              = var.storage_size
      resources_requests_cpu    = var.resources.requests.cpu
      resources_requests_memory = var.resources.requests.memory
      resources_limits_cpu      = var.resources.limits.cpu
      resources_limits_memory   = var.resources.limits.memory
      metrics_enabled           = var.metrics_enabled
      ecr_registry              = var.ecr_registry
      ecr_repository            = var.ecr_repository
      image_tag                 = var.image_tag
    }
  )
}

# Create namespace for Redis
resource "kubernetes_namespace" "redis" {
  count = var.enable_redis ? 1 : 0

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

# Create Kubernetes secret for Redis password
# Password is sourced from GitHub Secrets via TF_VAR_redis_password
resource "kubernetes_secret" "redis_password" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace.redis[0].metadata[0].name

    labels = {
      app         = local.name
      environment = var.env
      managed-by  = "terraform"
    }
  }

  data = {
    "redis-password" = var.redis_password
  }

  type = "Opaque"
}

# Redis Helm release using Bitnami chart
resource "helm_release" "redis" {
  count = var.enable_redis ? 1 : 0

  name       = local.name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = var.chart_version
  namespace  = kubernetes_namespace.redis[0].metadata[0].name

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

  # Use templatefile to inject values into the official Bitnami Redis Helm chart values template
  # Note: The secret name is passed to the template, and the secret resource is created separately
  values = [local.redis_values]

  depends_on = [
    kubernetes_namespace.redis[0],
    kubernetes_secret.redis_password[0],
  ]
}

# Network Policy: Allow backend pods to connect to Redis
# This policy restricts Redis access to only the backend namespace/pods
resource "kubernetes_network_policy_v1" "allow_backend_to_redis" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = "allow-backend-to-redis"
    namespace = kubernetes_namespace.redis[0].metadata[0].name

    labels = {
      app         = local.name
      environment = var.env
      managed-by  = "terraform"
    }
  }

  spec {
    # Apply to Redis pods
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "redis"
      }
    }

    policy_types = ["Ingress"]

    # Allow ingress from backend namespace on Redis port
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.backend_namespace
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "ldap-2fa-backend"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }

    # Allow ingress from within the Redis namespace (for Redis probes, etc.)
    ingress {
      from {
        pod_selector {}
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }
  }

  depends_on = [
    kubernetes_namespace.redis[0],
    helm_release.redis[0],
  ]
}
