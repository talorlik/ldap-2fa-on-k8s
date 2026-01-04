# cert-manager for automated TLS certificate management
# This creates self-signed certificates for OpenLDAP internal TLS

# Install cert-manager via Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.2"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "webhook.timeoutSeconds"
    value = "30"
  }

  set {
    name  = "prometheus.enabled"
    value = "false"
  }

  # Wait for cert-manager to be ready before proceeding
  wait = true
  wait_for_jobs = true
}

# Wait for cert-manager webhook to be fully ready before creating certificates
# This ensures the webhook can validate certificate resources
resource "time_sleep" "wait_for_cert_manager_webhook" {
  depends_on = [helm_release.cert_manager]
  create_duration = "30s"
}

# Create a self-signed ClusterIssuer
resource "kubernetes_manifest" "selfsigned_issuer" {
  depends_on = [time_sleep.wait_for_cert_manager_webhook]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }

  wait {
    fields = {
      "status.conditions[?(@.type=='Ready')].status" = "True"
    }
  }
}

# Create Certificate Authority (CA) certificate
resource "kubernetes_manifest" "openldap_ca" {
  depends_on = [kubernetes_manifest.selfsigned_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "openldap-ca"
      namespace = var.namespace
    }
    spec = {
      secretName  = "openldap-ca-secret"
      duration    = "87600h" # 10 years
      renewBefore = "720h"    # 30 days
      isCA        = true
      commonName  = "OpenLDAP CA"
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
      issuerRef = {
        name = "selfsigned-issuer"
        kind = "ClusterIssuer"
      }
    }
  }

  wait {
    fields = {
      "status.conditions[?(@.type=='Ready')].status" = "True"
    }
  }
}

# Create Issuer based on the CA certificate
resource "kubernetes_manifest" "openldap_ca_issuer" {
  depends_on = [kubernetes_manifest.openldap_ca]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Issuer"
    metadata = {
      name      = "openldap-ca-issuer"
      namespace = var.namespace
    }
    spec = {
      ca = {
        secretName = "openldap-ca-secret"
      }
    }
  }

  wait {
    fields = {
      "status.conditions[?(@.type=='Ready')].status" = "True"
    }
  }
}

# Create TLS certificate for OpenLDAP
resource "kubernetes_manifest" "openldap_tls" {
  depends_on = [kubernetes_manifest.openldap_ca_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "openldap-tls"
      namespace = var.namespace
    }
    spec = {
      secretName  = "openldap-tls"
      duration    = "87600h" # 10 years
      renewBefore = "720h"   # 30 days
      isCA        = false
      privateKey = {
        algorithm = "RSA"
        size      = 2048
      }
      dnsNames = [
        "openldap-stack-ha",
        "openldap-stack-ha.${var.namespace}",
        "openldap-stack-ha.${var.namespace}.svc",
        "openldap-stack-ha.${var.namespace}.svc.cluster.local",
        "openldap-stack-ha-headless",
        "openldap-stack-ha-headless.${var.namespace}",
        "openldap-stack-ha-headless.${var.namespace}.svc",
        "openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
        "openldap-stack-ha-0.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
        "openldap-stack-ha-1.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
        "openldap-stack-ha-2.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
        "*.${var.domain_name}",
        var.domain_name
      ]
      issuerRef = {
        name = "openldap-ca-issuer"
        kind = "Issuer"
      }
    }
  }

  wait {
    fields = {
      "status.conditions[?(@.type=='Ready')].status" = "True"
    }
  }
}
