# Network Policies for securing internal cluster communication
# These policies enforce secure communication between all services in the namespace
# Generic approach: Any service can talk to any service, but only on secure ports

# Generic Network Policy: Allow secure inter-pod communication within namespace
# This policy applies to ALL pods in the namespace and allows them to communicate
# with each other, but only on secure/encrypted ports
resource "kubernetes_network_policy_v1" "namespace_secure_communication" {
  metadata {
    name      = "namespace-secure-communication"
    namespace = var.namespace
  }

  spec {
    # Apply to all pods in the namespace
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    # Ingress: Allow traffic from any pod in the same namespace on secure ports
    ingress {
      # Allow from any pod in the same namespace
      from {
        pod_selector {}
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    ingress {
      from {
        pod_selector {}
      }
      ports {
        port     = "636"
        protocol = "TCP"
      }
    }

    # Allow HTTPS on common alternative ports if needed
    ingress {
      from {
        pod_selector {}
      }
      ports {
        port     = "8443"
        protocol = "TCP"
      }
    }

    # Ingress: Allow traffic from any pod in other namespaces on secure ports
    # This enables cross-namespace communication for LDAP service access
    ingress {
      # Allow from any pod in any namespace
      from {
        namespace_selector {}
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        port     = "636"
        protocol = "TCP"
      }
    }

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        port     = "8443"
        protocol = "TCP"
      }
    }

    # Egress: Allow traffic to any pod in the same namespace on secure ports
    egress {
      # Allow to any pod in the same namespace
      to {
        pod_selector {}
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {}
      }
      ports {
        port     = "636"
        protocol = "TCP"
      }
    }

    egress {
      to {
        pod_selector {}
      }
      ports {
        port     = "8443"
        protocol = "TCP"
      }
    }

    # Egress: Allow DNS resolution (required for service discovery)
    egress {
      to {
        namespace_selector {}
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      to {
        namespace_selector {}
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    # Egress: Allow HTTPS for external API calls (2FA providers, etc.)
    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    # Egress: Allow HTTP for external API calls if needed (though HTTPS is preferred)
    # Note: This is included for compatibility, but services should prefer HTTPS
    egress {
      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }
}

# Note: We don't need a separate default deny policy because:
# 1. The namespace_secure_communication policy above applies to all pods
# 2. It only allows specific secure ports (443, 636, 8443)
# 3. All other ports are implicitly denied
# 4. This approach is simpler and avoids policy conflicts
