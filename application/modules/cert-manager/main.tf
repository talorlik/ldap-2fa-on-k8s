# cert-manager for automated TLS certificate management
# This creates self-signed certificates for OpenLDAP internal TLS

resource "null_resource" "install_cert_manager" {
  provisioner "local-exec" {
    command = <<-EOT
      # Install cert-manager via kubectl
      kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
      
      # Wait for cert-manager to be ready
      echo "Waiting for cert-manager to be ready..."
      kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
      kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
      kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
      
      echo "cert-manager installation complete"
    EOT
  }

  triggers = {
    cluster_name = var.cluster_name
  }
}

# Create a self-signed ClusterIssuer and Certificate for OpenLDAP
resource "null_resource" "create_openldap_certificate" {
  depends_on = [null_resource.install_cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait a bit for webhook to be fully ready
      sleep 10
      
      # Create self-signed ClusterIssuer, CA cert, CA-based Issuer, then OpenLDAP cert
      kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: openldap-ca
  namespace: ${var.namespace}
spec:
  secretName: openldap-ca-secret
  duration: 87600h # 10 years
  renewBefore: 720h # 30 days
  isCA: true
  commonName: "OpenLDAP CA"
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: openldap-ca-issuer
  namespace: ${var.namespace}
spec:
  ca:
    secretName: openldap-ca-secret
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: openldap-tls
  namespace: ${var.namespace}
spec:
  secretName: openldap-tls
  duration: 87600h # 10 years
  renewBefore: 720h # 30 days
  isCA: false
  privateKey:
    algorithm: RSA
    size: 2048
  dnsNames:
    - openldap-stack-ha
    - openldap-stack-ha.${var.namespace}
    - openldap-stack-ha.${var.namespace}.svc
    - openldap-stack-ha.${var.namespace}.svc.cluster.local
    - openldap-stack-ha-headless
    - openldap-stack-ha-headless.${var.namespace}
    - openldap-stack-ha-headless.${var.namespace}.svc
    - openldap-stack-ha-headless.${var.namespace}.svc.cluster.local
    - openldap-stack-ha-0.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local
    - openldap-stack-ha-1.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local
    - openldap-stack-ha-2.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local
    - "*.${var.domain_name}"
    - ${var.domain_name}
  issuerRef:
    name: openldap-ca-issuer
    kind: Issuer
EOF
      
      echo "Waiting for certificate to be ready..."
      kubectl wait --for=condition=Ready --timeout=60s certificate/openldap-tls -n ${var.namespace}
      echo "Certificate created successfully"
    EOT
  }

  triggers = {
    namespace   = var.namespace
    domain_name = var.domain_name
  }
}
