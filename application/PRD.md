# Application Requirements

## 1. What you want the chart to do

Target state:

- `openldap` StatefulSet with EBS backed PVC inside the cluster only.
- PhpLdapAdmin UI exposed via ALB.
- LTB-passwd UI exposed via ALB (self-service password).
- No external exposure of the LDAP ports themselves.

The chart already supports:

- Global LDAP config: `global.ldapDomain`, `adminPassword`, `configPassword`,
ports. ([GitHub][1])
- Built in PhpLdapAdmin and LTB-passwd, each with an `ingress` block you can
customize. ([GitHub][1])

EKS Auto Mode already supports ALB if `elastic_load_balancing.enabled = true` in
the cluster `kubernetes_network_config`. ([j-labs][2])
ALB creation is driven by Kubernetes `Ingress` with AWS Load Balancer Controller
annotations. ([Kubernetes SIGs][3])

So you only need:

- Correct `values.yaml` overrides.
- A `helm_release` in Terraform that applies those values.

No separate AWS `aws_lb` resource is required.

## 2. Minimal values changes

Key sections from your `values-openldap-stack-ha (1).yaml` that must be
adjusted.

### 2.1 Global LDAP and credentials

Defaults you currently have:

```yaml
global:
  imageRegistry: ""
  imagePullSecrets: [""]
  storageClass: ""
  ldapDomain: "example.org"
  adminPassword:  Not@SecurePassw0rd
  configPassword: Not@SecurePassw0rd
  ldapPort: 1389
  sslLdapPort: 1636
```

Change to something like:

```yaml
global:
  imageRegistry: ""
  imagePullSecrets: []
  storageClass: ""              # leave empty, use persistence.storageClass instead
  ldapDomain: "ldap.talorlik.internal"   # or whatever LDAP base you want
  adminPassword:  "${TF_VAR_OPENLDAP_ADMIN_PASSWORD}"
  configPassword: "${TF_VAR_OPENLDAP_CONFIG_PASSWORD}"
  ldapPort: 389                 # standard LDAP
  sslLdapPort: 636              # standard LDAPS
```

In Terraform you will not literally hardcode
`${TF_VAR_OPENLDAP_ADMIN_PASSWORD}`; you will template these from variables or
inject via `global.existingSecret`. The important part is:

- Do not keep `Not@SecurePassw0rd`.
- Set `ldapDomain` to the real domain you will use for DNs. ([GitHub][1])

If you prefer secrets instead of cleartext in values:

- Use `global.existingSecret` (documented in the chart README) which expects
keys `LDAP_ADMIN_PASSWORD` and `LDAP_CONFIG_ADMIN_PASSWORD`, and remove
`adminPassword` / `configPassword` from the file. ([GitHub][1])

### 2.2 Persistence on your EBS StorageClass / PVC

Your current persistence block:

```yaml
persistence:
  enabled: true
  # storageClass: "standard-singlewriter"
  # existingClaim: openldap-pvc
  accessModes:
    - ReadWriteOnce
  size: 8Gi
```

> **Note**: The current implementation uses pattern 2 (chart creates PVC with
StorageClass). The code creates a StorageClass resource and the Helm chart
creates a new PVC using that StorageClass. The `existingClaim` option (pattern
1) is not used in the current implementation.

You can use one of these two patterns:

1. Reuse the existing PVC (not currently used):

```yaml
persistence:
  enabled: true
  existingClaim: "openldap-pvc"   # must match your PVC name
  accessModes:
    - ReadWriteOnce
  size: 8Gi                       # ignored when existingClaim is used, but harmless
```

2. Let the chart create a PVC with your StorageClass (current implementation):

```yaml
persistence:
  enabled: true
  storageClass: "your-ebs-sc-name"
  accessModes:
    - ReadWriteOnce
  size: 8Gi
```

The current implementation uses pattern 2: a StorageClass is created by
Terraform (`kubernetes_storage_class_v1` resource), and the Helm chart creates a
new PVC using that StorageClass.

### 2.3 Keep LDAP service internal

Your current service block:

```yaml
service:
  annotations: {}
  externalIPs: []
  #loadBalancerIP:
  #loadBalancerSourceRanges: []
  type: ClusterIP
  sessionAffinity: None
```

Leave `type: ClusterIP`. Do not change to `LoadBalancer` or `NodePort`. This
keeps LDAP itself strictly internal.

### 2.4 Externalize only the UIs via ALB

From your file:

```yaml
ltb-passwd:
  enabled : true
  image:
    tag: 5.2.3
  ingress:
    enabled: true
    annotations: {}
    path: /
    pathType: Prefix
    hosts:
    - "ssl-ldap2.example"
  ldap:
    bindPWKey: LDAP_ADMIN_PASSWORD

phpldapadmin:
  enabled: true
  env:
    PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: "never"
  ingress:
    enabled: true
    annotations: {}
    path: /
    pathType: Prefix
    hosts:
    - phpldapadmin.example
```

You want these two to be the only exposed pieces, via AWS ALB. For AWS Load
Balancer Controller you add the ALB annotations on the Ingress. ([Kubernetes
SIGs][3])

Example for private (internal) ALB, TLS terminated at ALB:

```yaml
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
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:eu-west-1:ACCOUNT:certificate/XXXXXXXX"
    path: /
    pathType: Prefix
    hosts:
      - "passwd.ldap.talorlik.internal"
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
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:eu-west-1:ACCOUNT:certificate/XXXXXXXX"
    path: /
    pathType: Prefix
    hosts:
      - "phpldapadmin.ldap.talorlik.internal"
```

Points:

- `scheme: internal` ensures ALB is only reachable inside the VPC.
([enterprise-k8s.arcgis.com][4])
- `target-type: ip` is typical with CNI mode and avoids NodePort. ([Kubernetes
SIGs][3])
- `listen-ports` plus `certificate-arn` ensures HTTPS listener with ACM cert.
([Kubernetes SIGs][3])

LDAP service remains `ClusterIP`; only these UIs have Ingress, hence only these
UIs are reachable via ALB.

## 3. Helm from Terraform

Assume:

- You already have an `aws_eks_cluster` resource and `data
"aws_eks_cluster_auth"` for the token.
- You are running this inside `backend_infra`.

### 3.1 Providers

Pattern consistent with EKS docs:

```hcl
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
```

This matches the pattern used in EKS Auto Mode articles and Terraform examples.
([j-labs][2])

### 3.2 Variables for sensitive bits

In `variables.tf`:

```hcl
variable "openldap_admin_password" {
  type      = string
  sensitive = true
}

variable "openldap_config_password" {
  type      = string
  sensitive = true
}

variable "openldap_ldap_domain" {
  type = string
}

variable "acm_cert_arn" {
  type = string
}

variable "phpldapadmin_host" {
  type = string
}

variable "ltb_passwd_host" {
  type = string
}
```

Values go into `variables.tfvars` or GitHub Actions env/vars.

### 3.3 Template the values file

Create `backend_infra/helm/openldap-values.tpl.yaml` and move your adjusted YAML
there, replacing literal values with interpolation placeholders:

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

### 3.4 Helm release resource

In `backend_infra/main.tf` or a dedicated module:

```hcl
locals {
  openldap_values = templatefile(
    "${path.module}/helm/openldap-values.tpl.yaml",
    {
      openldap_admin_password  = var.openldap_admin_password
      openldap_config_password = var.openldap_config_password
      openldap_ldap_domain     = var.openldap_ldap_domain
      acm_cert_arn             = var.acm_cert_arn
      phpldapadmin_host        = var.phpldapadmin_host
      ltb_passwd_host          = var.ltb_passwd_host
    }
  )
}

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
    # optionally your EBS StorageClass / PVC resources if you manage them here
  ]
}
```

Execution order:

1. EKS cluster and its EKS Auto Mode settings applied
(`elastic_load_balancing.enabled = true`). ([j-labs][2])
2. StorageClass / PVC resources applied.
3. `helm_release.openldap` applied.

On apply:

- Helm installs OpenLDAP StatefulSet, Service, and the two UI Deployments plus
Services.
- The two Ingress resources for `phpldapadmin` and `ltb-passwd` are created with
ALB annotations.
- AWS Load Balancer Controller in EKS Auto Mode detects these Ingresses and
provisions an internal ALB with HTTPS, ACM cert, and targets pointing at the
pods. ([Kubernetes SIGs][3])

You now have:

- LDAP reachable only inside the cluster via ClusterIP service.
- Two GUIs reachable via ALB on the hostnames you specified, for manual
management and self service.

[1]: https://github.com/jp-gouin/helm-openldap "GitHub - jp-gouin/helm-openldap:
Helm chart of Openldap in High availability with multi-master replication and
PhpLdapAdmin and Ltb-Passwd"
[2]:
https://www.j-labs.pl/en/tech-blog/aws-eks-auto-mode/?utm_source=chatgpt.com
"AWS EKS Auto Mode with Terraform. Guidebook"
[3]:
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/?utm_source=chatgpt.com
"Ingress annotations - AWS Load Balancer Controller"
[4]:
https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm?utm_source=chatgpt.com
"Use application load balancing on Amazon Elastic ..."
