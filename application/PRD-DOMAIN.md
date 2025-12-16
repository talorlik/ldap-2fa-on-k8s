# DOMAIN SETUP AND LINKING TO ALB AND LDAP

> **Note**: This document describes creating Route53 hosted zone and ACM
certificate resources via Terraform. However, the current implementation in
`main.tf` uses **data sources** to reference existing resources instead of
creating them. The Route53 module (`modules/route53/`) exists but is commented
out. If you want to create these resources via Terraform, uncomment the module
and update the code accordingly.

There are three separate pieces:

1. Public DNS zone for talorlik.com.
2. ACM certificate for talorlik.com / *.talorlik.com, validated via Route53.
3. Using that ACM ARN in ALB (via Ingress annotations).

Below is a linear Terraform-centric setup.

## 1. Route53 hosted zone for `talorlik.com`

In `backend_infra`:

```hcl
resource "aws_route53_zone" "talo_ldap" {
  name = "talorlik.com"
}
```

If the domain is registered elsewhere, point the registrar's NS records at
`aws_route53_zone.talo_ldap.name_servers`.

## 2. ACM certificate with DNS validation

ALB needs an ACM cert in the same region as the ALB / EKS cluster.

```hcl
resource "aws_acm_certificate" "talo_ldap" {
  domain_name               = "talorlik.com"
  validation_method         = "DNS"
  subject_alternative_names = ["*.talorlik.com"]

  lifecycle {
    create_before_destroy = true
  }
}
```

## 3. DNS validation records in Route53

Create validation records in the hosted zone using `domain_validation_options`:

```hcl
resource "aws_route53_record" "talo_ldap_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.talo_ldap.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.talo_ldap.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60

  records = [each.value.record]
}
```

## 4. Finalize ACM certificate

Bind the certificate to its DNS validation records:

```hcl
resource "aws_acm_certificate_validation" "talo_ldap" {
  certificate_arn = aws_acm_certificate.talo_ldap.arn

  validation_record_fqdns = [
    for r in aws_route53_record.talo_ldap_cert_validation : r.fqdn
  ]
}
```

After this, `aws_acm_certificate_validation.talo_ldap.certificate_arn` is the
"ready" cert ARN for ALB.

## 5. Terraform outputs: `acm_cert_arn` and `domain_name`

In the same module (`backend_infra`) define:

```hcl
output "acm_cert_arn" {
  description = "ACM certificate ARN for talorlik.com (*.talorlik.com)"
  value       = aws_acm_certificate_validation.talo_ldap.certificate_arn
}

output "domain_name" {
  description = "Root domain name for LDAP app"
  value       = aws_route53_zone.talo_ldap.name
}
```

If `backend_infra` is called as a module, the root module will see:

- `module.backend_infra.acm_cert_arn`
- `module.backend_infra.domain_name`

These are what you feed into Helm templates or other modules.

## 6. Use outputs inside the same module for Helm values

If Helm is deployed from `backend_infra` itself, you can use the outputs as
locals directly (no extra wiring):

```hcl
locals {
  openldap_domain_name = aws_route53_zone.talo_ldap.name
  openldap_phpldapadmin_host = "phpldapadmin.${local.openldap_domain_name}"
  openldap_ltb_passwd_host   = "passwd.${local.openldap_domain_name}"

  openldap_values = templatefile(
    "${path.module}/helm/openldap-values.tpl.yaml",
    {
      acm_cert_arn       = aws_acm_certificate_validation.talo_ldap.certificate_arn
      phpldapadmin_host  = local.openldap_phpldapadmin_host
      ltb_passwd_host    = local.openldap_ltb_passwd_host
      # plus LDAP domain, passwords, PVC name, etc.
      openldap_ldap_domain     = "talorlik.com"
      openldap_admin_password  = var.openldap_admin_password
      openldap_config_password = var.openldap_config_password
    }
  )
}
```

If Helm is in another module, pass outputs `acm_cert_arn` and `domain_name` into
that module as variables and derive the hosts there.

## 7. Values template for `openldap-stack-ha` (using ACM ARN and domain)

Example `helm/openldap-values.tpl.yaml` excerpt:

```yaml
global:
  imageRegistry: ""
  imagePullSecrets: []
  storageClass: ""
  ldapDomain: "${openldap_ldap_domain}"
  adminPassword:  "${openldap_admin_password}"
  configPassword: "${openldap_config_password}"
  ldapPort: 389
  sslLdapPort: 636

persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 8Gi

service:
  annotations: {}
  externalIPs: []
  type: ClusterIP
  sessionAffinity: None

ltb-passwd:
  enabled: true
  image:
    tag: 5.2.3
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
    path: /
    pathType: Prefix
    hosts:
      - "${ltb_passwd_host}"
  ldap:
    bindPWKey: LDAP_ADMIN_PASSWORD

phpldapadmin:
  enabled: true
  env:
    PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: "never"
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
    path: /
    pathType: Prefix
    hosts:
      - "${phpldapadmin_host}"
```

LDAP service itself stays `ClusterIP`, so only the GUI Ingresses are exposed via
ALB using that ACM certificate.

## 8. Helm release for OpenLDAP from Terraform

In `backend_infra`:

```hcl
resource "helm_release" "openldap" {
  name       = "openldap-stack-ha"
  repository = "https://jp-gouin.github.io/helm-openldap"
  chart      = "openldap-stack-ha"
  version    = "4.0.1"

  namespace        = "ldap"
  create_namespace = true

  values = [local.openldap_values]

  depends_on = [
    aws_eks_cluster.main,
    aws_acm_certificate_validation.talo_ldap,
    # PVC / StorageClass resources, if managed here
  ]
}
```

EKS Auto Mode with AWS Load Balancer Controller will see the Ingresses and
provision an internal ALB with HTTPS listeners using `acm_cert_arn`.

## 9. Route53 records for application and GUIs

Once the ALB exists, you either:

- Let AWS Load Balancer Controller create Route53 records via external-dns (if
you add it), or
- Create `A` records pointing to the ALB.

Manual Terraform example using the ALB DNS name:

```hcl
data "aws_lb" "ldap_alb" {
  # filter by tag or name corresponding to the Ingress-created ALB
  # name = "k8s-<something>"  # adjust as needed
}

resource "aws_route53_record" "phpldapadmin" {
  zone_id = aws_route53_zone.talo_ldap.zone_id
  name    = "phpldapadmin.${aws_route53_zone.talo_ldap.name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ldap_alb.dns_name
    zone_id                = data.aws_lb.ldap_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "passwd" {
  zone_id = aws_route53_zone.talo_ldap.zone_id
  name    = "passwd.${aws_route53_zone.talo_ldap.name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ldap_alb.dns_name
    zone_id                = data.aws_lb.ldap_alb.zone_id
    evaluate_target_health = true
  }
}
```

Now:

- `output.acm_cert_arn` is the ACM cert used by the ALB for HTTPS.
- `output.domain_name` is `talorlik.com`, from which you derive
`phpldapadmin.talorlik.com`, `passwd.talorlik.com`, and later app endpoints.
- LDAP stays internal (`ClusterIP`), while the admin/password GUIs and app
endpoints are exposed via ALB with TLS terminated using that ACM certificate.
