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

# The IngressClassParams resources is _not_ a standard Kubernetes resource, therefore it gets created as a
# custom resource in Kubernetes.
#
# There is no Terraform resource in the Kubernetes provider to create it
#
# A cleaner, more Terraform-native solution is to use the `kubernetes_manifest` resource to create the IngressClassParams resource.
# However, this resource just assumes the EKS cluster already exists and fails with error during `terraform plan`.
#
# Therefore, we go with the less elegant solution below
# *** This requires the aws cli to be installed and configured with the correct AWS credentials.
#
# Annotation Strategy (cluster-wide defaults):
# - IngressClassParams defines cluster-wide defaults that apply to all Ingresses using this IngressClass
# - EKS Auto Mode IngressClassParams supports: scheme, ipAddressType, group.name, and certificateARNs
# - Per-Ingress ALB configuration (load-balancer-name, listen-ports, ssl-redirect, target-type)
#   should be defined at the Ingress level via annotations
# - All Ingresses using this IngressClass inherit cluster-wide settings from IngressClassParams

resource "null_resource" "apply_ingressclassparams_manifest" {
  provisioner "local-exec" {
    command = <<EOT
    # Set Kubernetes environment variables for Helm/Kubernetes providers
    export KUBERNETES_MASTER=$(aws eks describe-cluster --name ${var.cluster_name} --region ${var.region} --query 'cluster.endpoint' --output text)
    export KUBE_CONFIG_PATH=~/.kube/config

    # Check if kubeconfig is already configured for this cluster
    if ! kubectl config get-contexts -o name | grep -q "arn:aws:eks:${var.region}:.*:cluster/${var.cluster_name}" 2>/dev/null; then
      echo "Configuring kubeconfig for cluster ${var.cluster_name}..."
      aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name}
    else
      echo "Kubeconfig already configured for cluster ${var.cluster_name}"
    fi

    # Apply IngressClassParams (kubectl apply is idempotent)
    # EKS Auto Mode IngressClassParams supports: scheme, ipAddressType, group.name, and certificateARNs (cluster-wide defaults)
    # Note: Unlike AWS Load Balancer Controller, EKS Auto Mode does NOT support subnets, security groups, or tags in IngressClassParams
    kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: "${local.ingressclassparams_alb_name}"
spec:
  # Cluster-wide defaults: scheme, ipAddressType, group.name, and certificateARNs
  # These settings are inherited by all Ingresses that use this IngressClass
  scheme: ${var.alb_scheme}
  ipAddressType: ${var.alb_ip_address_type}
  group:
    name: "${var.alb_group_name}"
  certificateARNs:
    - "${var.acm_certificate_arn}"
EOF
    EOT
  }

  # Trigger recreation when ALB configuration changes
  triggers = {
    cluster_name        = var.cluster_name
    region              = var.region
    alb_scheme          = var.alb_scheme
    alb_ip_address_type = var.alb_ip_address_type
  }
}

# IngressClass binds Ingress resources to EKS Auto Mode controller
# and references IngressClassParams for cluster-wide ALB defaults
resource "kubernetes_ingress_class_v1" "ingressclass_alb" {
  depends_on = [null_resource.apply_ingressclassparams_manifest]
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
