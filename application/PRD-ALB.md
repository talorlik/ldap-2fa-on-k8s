# Single ALB multiple Ingresses

Goal:
Single internet-facing ALB on EKS, managed by **EKS Auto Mode** (built-in load balancer driver), using:

- Domain: `talorlik.com`
- HTTPS on port 443
- ACM certificate (in ACM, already validated)
- Multiple Ingresses from `helm-openldap` (phpLDAPadmin + ltb-passwd) sharing that ALB via IngressGroup.

**Note**: This implementation uses **EKS Auto Mode** (`eks.amazonaws.com/alb` controller), not the AWS Load Balancer Controller. EKS Auto Mode:
- Has its own built-in load balancer driver (no need to install AWS Load Balancer Controller)
- Automatically handles IAM permissions (no need to attach AWSLoadBalancerControllerIAMPolicy)
- Uses a different API group (`eks.amazonaws.com`) for IngressClassParams

Below are the adjusted `values.yaml` snippets.

## Option A - Separate hosts, same ALB, HTTPS 443 with ACM

Use two hostnames on the configured domain, one per app, on a single ALB:

- `${phpldapadmin_host}` (e.g., `phpldapadmin.talorlik.com`) → phpLDAPadmin
- `${ltb_passwd_host}` (e.g., `passwd.talorlik.com`) → ltb-passwd

`values.yaml`:

```yaml
ltb-passwd:
  enabled: true
  image:
    tag: 5.2.3
  podLabels:
    app: "${app_name}"
  ingress:
    enabled: true
    ingressClassName: "${ingress_class_name}"
    annotations:
      # IngressGroup - REQUIRED on all Ingresses in the group
      alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
      alb.ingress.kubernetes.io/group.order: "10"  # Leader Ingress (lowest order)

      # Leader Ingress annotations - group-wide ALB configuration
      # These are treated as group-wide when building the ALB
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_group_name}"
      alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/ssl-policy: "${alb_ssl_policy}"
      # Note: scheme and ipAddressType are inherited from IngressClassParams
    path: /
    pathType: Prefix
    hosts:
      - "${ltb_passwd_host}"

phpldapadmin:
  enabled: true
  podLabels:
    app: "${app_name}"
  ingress:
    enabled: true
    ingressClassName: "${ingress_class_name}"
    annotations:
      # IngressGroup - REQUIRED on all Ingresses in the group
      alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
      alb.ingress.kubernetes.io/group.order: "20"  # Secondary Ingress
      # Note: Group-wide ALB settings (listen-ports, certificate-arn, ssl-redirect, etc.)
      # are inherited from the leader Ingress (order 10). Only group.name and group.order
      # are required on secondary Ingresses.
    path: /
    pathType: Prefix
    hosts:
      - "${phpldapadmin_host}"
```

What this does:

**Annotation Strategy**:
- **IngressClassParams** (cluster-wide defaults): `scheme` (internet-facing) and `ipAddressType` (ipv4) are defined once at the cluster level
- **Leader Ingress** (order 10, ltb-passwd): Contains all group-wide ALB configuration:
  - `alb.ingress.kubernetes.io/group.name` and `group.order` (required for group membership)
  - `alb.ingress.kubernetes.io/load-balancer-name` (custom ALB name)
  - `alb.ingress.kubernetes.io/target-type` (ip vs instance)
  - `alb.ingress.kubernetes.io/listen-ports` (HTTP 80 and HTTPS 443)
  - `alb.ingress.kubernetes.io/certificate-arn` (ACM certificate for TLS)
  - `alb.ingress.kubernetes.io/ssl-redirect` (redirect HTTP to HTTPS)
  - `alb.ingress.kubernetes.io/ssl-policy` (TLS security policy)
- **Secondary Ingress** (order 20, phpldapadmin): Only contains the absolute minimum required:
  - `alb.ingress.kubernetes.io/group.name` and `group.order` (required for group membership)
  - Group-wide settings are inherited from the leader Ingress

**How it works**:
- Both Ingresses share the same `group.name`, so the controller provisions a single ALB
- The controller treats annotations on the leader Ingress (lowest order) as group-wide ALB configuration
- Secondary Ingresses inherit these group-wide settings and only need to define their own routing rules (hosts, paths)
- `scheme` and `ipAddressType` are inherited from IngressClassParams (cluster-wide defaults)
- Route 53: create two A/AAAA alias records pointing to the same ALB:
  - `${phpldapadmin_host}` → this ALB
  - `${ltb_passwd_host}` → same ALB

**Result**: A single internet-facing ALB with a custom name, TLS on 443, separate hostnames for each UI, with minimal annotation duplication.

The Helm chart can create `Ingress` objects, but it cannot magically tell Kubernetes *which controller- should act on them or *what ALB defaults- to use. That’s exactly what `IngressClass` and `IngressClassParams` are for.

Breakdown:

1. What the Ingress actually is

   - An `Ingress` is just a generic API object: “for host X and path Y, send traffic to Service Z”.
   - It does not say:

     - which controller should implement it, or
     - which type of load balancer to create, or
     - what global LB settings (scheme, IP type, tags, etc.) to apply.
   - Something (an ingress controller) must watch those Ingresses and create real cloud resources (ALB, listeners, target groups…).

2. Why you need an IngressClass

   - Modern Kubernetes: the old `kubernetes.io/ingress.class` annotation is deprecated.
   - `IngressClass` is now the official way to bind an Ingress to a specific controller.
   - Example:

     ```yaml
     kind: IngressClass
     metadata:
       name: ic-alb-ldap
       annotations:
         ingressclass.kubernetes.io/is-default-class: "true"
     spec:
       controller: eks.amazonaws.com/alb
       parameters:
         apiGroup: eks.amazonaws.com
         kind: IngressClassParams
         name: icp-alb-ldap
     ```

   - Your `Ingress` then says:

     ```yaml
     spec:
       ingressClassName: ic-alb-ldap
     ```

   - This is the piece that tells EKS Auto Mode:
     “You are responsible for this Ingress. Create/manage an ALB for it.”

   Without an IngressClass, either:

   - nothing watches the Ingress, or
   - you fall back to legacy behavior (controller-specific annotations), which AWS now documents as legacy.

3. Why you need IngressClassParams

   - `IngressClassParams` is an EKS Auto Mode-specific CRD that holds ALB configuration shared across many Ingresses.
   - It lets you centralize things that should not be repeated in every Helm chart.
   - **EKS Auto Mode IngressClassParams supports**:
     - `scheme` (internet-facing vs internal)
     - `ipAddressType` (ipv4 / dualstack)
   - **Note**: EKS Auto Mode IngressClassParams does NOT support subnets, security groups, or tags (unlike AWS Load Balancer Controller's IngressClassParams).
   - Roughly: Ingress = routing rules; IngressClassParams = ALB profile.

   Helm charts like `openldap-stack-ha` only deal with routing rules. They don’t know:

   - whether the ALB is internet-facing or internal
   - whether the ALB uses IPv4 or dual-stack
   - per-Ingress settings like target-type (ip vs instance) are still configured via annotations

   **Annotation Strategy**:
   - **IngressClassParams** (cluster-wide): Define `scheme` and `ipAddressType` once at the cluster level
   - **Leader Ingress** (lowest `group.order`): Contains all group-wide ALB configuration (load-balancer-name, listen-ports, certificate-arn, ssl-redirect, ssl-policy, target-type)
   - **Secondary Ingresses**: Only need `group.name` and `group.order` - they inherit group-wide settings from the leader

   IngressClassParams is where you define cluster-wide defaults once, and then every Ingress that uses that IngressClass inherits them automatically.

4. Why you still “need” them even though ALB is auto-provisioned

   - “ALB is auto-provisioned” = EKS Auto Mode automatically creates an ALB *when it sees an Ingress that belongs to it*.
   - How does it know the Ingress “belongs to it”? Through:

     - `spec.ingressClassName` that references an `IngressClass` with `controller: eks.amazonaws.com/alb`.
   - How does it know what defaults to apply to that ALB? Through:

     - The `parameters` reference from the IngressClass to an `IngressClassParams` object.

   So the chain is:

   `Ingress`
   → `ingressClassName: ic-alb-ldap`
   → `IngressClass` (`controller: eks.amazonaws.com/alb`)
   → `parameters: IngressClassParams` (ALB config profile: scheme, ipAddressType)
   → EKS Auto Mode
   → Creates/updates ALB, listeners, target groups, rules.

5. What would happen without them

   - If you skip IngressClass and IngressClassParams and rely only on annotations:

     - You’re using deprecated/legacy patterns.
     - It’s ambiguous which controller should act if you ever introduce more than one.
     - You repeat provider-specific config on every Ingress (in every chart).
   - With them:

     - The chart stays provider-agnostic: it just specifies `ingressClassName`.
     - The cluster owner decides at cluster level how ALBs are created and configured.

6. In Helm chart terms

   - The OpenLDAP Helm chart’s job:

     - Create `Ingress` objects with host/path/service rules.
   - Your cluster’s job:

     - Provide an `IngressClass` (e.g., `ic-alb-ldap`) with `controller: eks.amazonaws.com/alb`.
     - Provide an associated `IngressClassParams` (e.g., `icp-alb-ldap`) that encodes "use EKS Auto Mode ALB with these defaults" (scheme, ipAddressType).

   That separation is why you still need IngressClass and IngressClassParams even though the ALB provisioning is “automatic”. The automation needs a target profile and a controller binding, and those are exactly those two objects.

## Implementation Details

**Terraform creates**:
- `IngressClass` resource using `kubernetes_ingress_class_v1` resource
- `IngressClassParams` using `null_resource` with `kubectl apply` (because Terraform doesn't have native support for EKS Auto Mode's IngressClassParams CRD)
  - Contains cluster-wide defaults: `scheme` (internet-facing/internal) and `ipAddressType` (ipv4/dualstack)

**Helm chart creates**:
- `Ingress` objects with host/path/service rules
- Uses `ingressClassName` to reference the IngressClass
- **Annotation strategy**:
  - **Leader Ingress** (lowest `group.order`): Contains all group-wide ALB configuration:
    - Required: `group.name`, `group.order`
    - Group-wide: `load-balancer-name`, `listen-ports`, `certificate-arn`, `ssl-redirect`, `ssl-policy`, `target-type`
  - **Secondary Ingresses**: Only contain the absolute minimum:
    - Required: `group.name`, `group.order`
    - Group-wide settings are inherited from the leader Ingress

**IngressClass is set as default**:
- Uses annotation `ingressclass.kubernetes.io/is-default-class: "true"`
- Allows Ingresses to omit `ingressClassName` if desired

**Why this strategy**:
- Treats IngressClassParams as cluster-wide defaults (scheme, ipAddressType)
- Treats leader Ingress annotations as group-wide ALB configuration (load-balancer-name, listen-ports, certificate-arn, ssl-redirect, ssl-policy, target-type)
- Minimizes annotation duplication across multiple Ingresses in the same group
- The AWS Load Balancer Controller merges IngressClassParams + Ingress annotations asymmetrically:
  - IngressClassParams provide cluster-wide defaults
  - Leader Ingress annotations (lowest `group.order`) are treated as group-wide ALB configuration
  - Secondary Ingresses only need `group.name` and `group.order` to join the group
  - Each Ingress still defines its own routing rules (hosts, paths) in the `spec.rules` section

## Key Differences: EKS Auto Mode vs AWS Load Balancer Controller

| Feature | EKS Auto Mode | AWS Load Balancer Controller |
|---------|---------------|------------------------------|
| Controller | `eks.amazonaws.com/alb` | `alb.ingress.kubernetes.io` |
| API Group | `eks.amazonaws.com` | `elbv2.k8s.aws` |
| IAM Setup | Automatic (no manual setup) | Requires IAM policy attachment |
| Installation | Built-in to EKS | Requires separate Helm chart |
| IngressClassParams fields | `scheme`, `ipAddressType` only | `scheme`, `ipAddressType`, `subnets`, `securityGroups`, `tags`, etc. |
| Terraform support | Partial (IngressClassParams via kubectl) | Full (via `kubernetes_manifest`) |
