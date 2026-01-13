# *** EKS Auto mode has its own load balancer driver ***
# So there is no need to configure AWS Load Balancer Controller

# *** EKS Auto Mode takes care of IAM permissions ***
# There is no need to attach AWSLoadBalancerControllerIAMPolicy to the EKS Node IAM Role

locals {
  # ingress_alb_name            = "${var.prefix}-${var.region}-${var.ingress_alb_name}-${var.env}"
  # service_alb_name            = "${var.prefix}-${var.region}-${var.service_alb_name}-${var.env}"
  ingressclass_alb_name       = "${var.prefix}-${var.region}-${var.ingressclass_alb_name}-${var.env}"
  ingressclassparams_alb_name = "${var.prefix}-${var.region}-${var.ingressclassparams_alb_name}-${var.env}"
}

# Kubernetes Ingress and Service resources commented out
# These are not needed - OpenLDAP Helm chart creates its own Ingress resources
# which will use the IngressClass defined below

# resource "kubernetes_ingress_v1" "ingress_alb" {
#   metadata {
#     name      = local.ingress_alb_name
#     namespace = "default"
#     annotations = merge(
#       {
#         "alb.ingress.kubernetes.io/scheme"         = "internet-facing"
#         "alb.ingress.kubernetes.io/tags"          = "Terraform=true,Environment=${var.env}"
#         "alb.ingress.kubernetes.io/target-type"   = "ip"
#         "alb.ingress.kubernetes.io/listen-ports" = var.acm_certificate_arn != null ? "[{\"HTTP\":80},{\"HTTPS\":443}]" : "[{\"HTTP\":80}]"
#       },
#       var.acm_certificate_arn != null ? {
#         "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
#         "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
#         "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#       } : {}
#     )
#   }
#
#   spec {
#     # this matches the name of IngressClass.
#     # this can be omitted if you have a default ingressClass in cluster: the one with ingressclass.kubernetes.io/is-default-class: "true"  annotation
#     ingress_class_name = local.ingressclass_alb_name
#
#     rule {
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
#
#           backend {
#             service {
#               name = kubernetes_service_v1.service_alb.metadata[0].name
#               port {
#                 number = 8080
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }
#
# # Kubernetes Service for the App
# resource "kubernetes_service_v1" "service_alb" {
#   metadata {
#     name      = local.service_alb_name
#     namespace = "default"
#     labels = {
#       app = var.app_name
#     }
#   }
#
#   spec {
#     selector = {
#       app = var.app_name
#     }
#
#     port {
#       port        = 8080
#       target_port = 8080
#     }
#
#     type = "ClusterIP"
#   }
# }

# The IngressClassParams resource is a custom Kubernetes resource (CRD) provided by EKS Auto Mode.
# We use the `kubernetes_manifest` resource to manage it in a Terraform-native way.
#
# ⚠️ RISKS AND MITIGATION:
#
# 1. CRD Availability Risk:
#    - The IngressClassParams CRD is installed by EKS Auto Mode when the cluster is created
#    - If Terraform runs before Auto Mode finishes initializing, the CRD may not exist
#    - This causes failures during `terraform apply` (not plan, since we can't check CRD existence in plan)
#
# 2. Mitigation Strategies:
#    a) Ensure cluster is fully ready: The Kubernetes provider uses data sources that require
#       the cluster to exist, but doesn't guarantee CRD availability
#    b) Use time_sleep for initial deployments: Adds a delay to allow Auto Mode to initialize
#    c) Retry logic: Terraform will retry on apply, but you may need to run apply multiple times
#    d) Manual verification: Check CRD exists: `kubectl get crd ingressclassparams.eks.amazonaws.com`
#
# 3. Alternative Approach:
#    If you experience frequent CRD availability issues, consider:
#    - Using the original null_resource + kubectl approach (more forgiving)
#    - Adding a data source to check CRD existence first (requires kubectl provider)
#    - Using a Helm chart that handles CRD installation
#
# Annotation Strategy (cluster-wide defaults):
# - IngressClassParams defines cluster-wide defaults that apply to all Ingresses using this IngressClass
# - EKS Auto Mode IngressClassParams supports: scheme, ipAddressType, group.name, and certificateARNs
# - Per-Ingress ALB configuration (load-balancer-name, listen-ports, ssl-redirect, target-type)
#   should be defined at the Ingress level via annotations
# - All Ingresses using this IngressClass inherit cluster-wide settings from IngressClassParams

# Optional: Add a delay for initial cluster setup to allow EKS Auto Mode to install CRDs
#
# IMPORTANT: There is NO Terraform resource that represents "CRD is installed"
# The IngressClassParams CRD is installed asynchronously by EKS Auto Mode after cluster creation.
# The cluster resource (module.eks in backend_infra) completes before CRDs are guaranteed to exist.
#
# What we're actually waiting for:
# - NOT a Terraform resource (there isn't one for CRD availability)
# - The asynchronous EKS Auto Mode process to install the CRD
# - This typically happens within seconds of cluster creation, but isn't guaranteed
#
# Set wait_for_crd = true for initial deployments, false after cluster is established
resource "time_sleep" "wait_for_eks_auto_mode" {
  # Always create the resource, but use 0s duration when wait_for_crd is false
  # This allows us to always reference it in depends_on (which requires a static list)
  create_duration = var.wait_for_crd ? "30s" : "0s"

  # Trigger recreation if cluster changes (helps with new cluster deployments)
  triggers = {
    cluster_name = var.cluster_name
  }
}

resource "kubernetes_manifest" "ingressclassparams_alb" {
  # Wait for:
  # 1. The Kubernetes provider to be configured (implicit via data.aws_eks_cluster)
  # 2. Optionally, a delay to allow EKS Auto Mode to install the CRD
  #
  # Note: We can't explicitly depend on the CRD existing because there's no Terraform
  # resource for it. The time_sleep is a workaround for the asynchronous CRD installation.
  # When wait_for_crd is false, time_sleep has 0s duration (no actual delay).
  depends_on = [time_sleep.wait_for_eks_auto_mode]

  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "IngressClassParams"
    metadata = {
      name = local.ingressclassparams_alb_name
    }
    spec = merge(
      {
        scheme        = var.alb_scheme
        ipAddressType = var.alb_ip_address_type
        group = {
          name = var.alb_group_name
        }
      },
      var.acm_certificate_arn != null && var.acm_certificate_arn != "" ? {
        certificateARNs = [var.acm_certificate_arn]
      } : {}
    )
  }

  # Wait for the resource to be created and ready
  # This ensures the resource exists before dependent resources are created
  wait {
    fields = {
      "metadata.name" = local.ingressclassparams_alb_name
    }
  }

  # Use server-side apply to handle conflicts better
  # This is safer for custom resources that might be managed elsewhere
  computed_fields = ["metadata.labels", "metadata.annotations"]
}

# IngressClass binds Ingress resources to EKS Auto Mode controller
# and references IngressClassParams for cluster-wide ALB defaults
resource "kubernetes_ingress_class_v1" "ingressclass_alb" {
  depends_on = [kubernetes_manifest.ingressclassparams_alb]
  metadata {
    name = local.ingressclass_alb_name

    # Use this annotation to set an IngressClass as Default
    # If an Ingress doesn't specify a class, it will use the Default
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    # Configures the IngressClass to use EKS Auto Mode (built-in load balancer driver)
    controller = "eks.amazonaws.com/alb"
    parameters {
      api_group = "eks.amazonaws.com"
      kind      = "IngressClassParams"
      # References IngressClassParams which contains cluster-wide defaults (scheme, ipAddressType, group.name, certificateARNs)
      name = local.ingressclassparams_alb_name
    }
  }
}
