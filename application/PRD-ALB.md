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
      # Note: group.name and certificate-arn are configured in IngressClassParams (cluster-wide)
      # Only per-Ingress settings are specified here
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
      alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      # Note: scheme, ipAddressType, group.name, and certificateARNs are inherited from IngressClassParams
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
      # Same annotations as ltb-passwd - group.name and certificate-arn are in IngressClassParams
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
      alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
    path: /
    pathType: Prefix
    hosts:
      - "${phpldapadmin_host}"
```

What this does:

**Annotation Strategy**:
- **IngressClassParams** (cluster-wide defaults): Configured once at the cluster level:
  - `scheme` (internet-facing)
  - `ipAddressType` (ipv4)
  - `group.name` (ALB group name for grouping multiple Ingresses)
  - `certificateARNs` (ACM certificate ARNs for TLS termination)
- **Ingress annotations**: Each Ingress specifies per-Ingress settings:
  - `alb.ingress.kubernetes.io/load-balancer-name` (custom ALB name, max 32 characters)
  - `alb.ingress.kubernetes.io/target-type` (ip vs instance)
  - `alb.ingress.kubernetes.io/listen-ports` (HTTP 80 and HTTPS 443)
  - `alb.ingress.kubernetes.io/ssl-redirect` (redirect HTTP to HTTPS)
  - Note: `group.name` and `certificate-arn` are configured in IngressClassParams, not in annotations

**How it works**:
- Both Ingresses use the same `group.name` (configured in IngressClassParams), so the controller provisions a single ALB
- Certificate ARN is configured once in IngressClassParams and applies to all Ingresses using this IngressClass
- All Ingresses share the same ALB configuration from IngressClassParams (scheme, ipAddressType, group.name, certificateARNs)
- Each Ingress only needs to specify per-Ingress settings (load-balancer-name, target-type, listen-ports, ssl-redirect)
- Route 53: create two A/AAAA alias records pointing to the same ALB:
  - `${phpldapadmin_host}` → this ALB
  - `${ltb_passwd_host}` → same ALB

**Result**: A single internet-facing ALB with a custom name, TLS on 443, separate hostnames for each UI, with minimal annotation duplication and centralized certificate/group configuration.

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
     - `group.name` (ALB group name for grouping multiple Ingresses)
     - `certificateARNs` (ACM certificate ARNs for TLS termination)
   - **Note**: EKS Auto Mode IngressClassParams does NOT support subnets, security groups, or tags (unlike AWS Load Balancer Controller's IngressClassParams).
   - Roughly: Ingress = routing rules; IngressClassParams = ALB profile.

   Helm charts like `openldap-stack-ha` only deal with routing rules. They don’t know:

   - whether the ALB is internet-facing or internal
   - whether the ALB uses IPv4 or dual-stack
   - per-Ingress settings like target-type (ip vs instance) are still configured via annotations

   **Annotation Strategy**:
   - **IngressClassParams** (cluster-wide): Define `scheme`, `ipAddressType`, `group.name`, and `certificateARNs` once at the cluster level
   - **Ingress annotations**: Only need per-Ingress settings:
     - `load-balancer-name`: AWS ALB name (max 32 characters)
     - `target-type`: IP or instance mode
     - `listen-ports`: HTTP/HTTPS ports
     - `ssl-redirect`: HTTPS redirect configuration
     - Note: `group.name` and `certificate-arn` are now configured in IngressClassParams, not in Ingress annotations

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
  - Contains cluster-wide defaults:
    - `scheme` (internet-facing/internal)
    - `ipAddressType` (ipv4/dualstack)
    - `group.name` (ALB group name for grouping multiple Ingresses)
    - `certificateARNs` (ACM certificate ARNs for TLS termination)

**Helm chart creates**:
- `Ingress` objects with host/path/service rules
- Uses `ingressClassName` to reference the IngressClass
- **Annotation strategy**:
  - All Ingresses use the same annotations (no leader/secondary distinction needed):
    - `load-balancer-name`: AWS ALB name (max 32 characters)
    - `target-type`: IP or instance mode
    - `listen-ports`: HTTP/HTTPS ports (e.g., `[{"HTTP":80},{"HTTPS":443}]`)
    - `ssl-redirect`: HTTPS redirect configuration
  - Note: `group.name` and `certificate-arn` are configured in IngressClassParams (cluster-wide), not in Ingress annotations

**IngressClass is set as default**:
- Uses annotation `ingressclass.kubernetes.io/is-default-class: "true"`
- Allows Ingresses to omit `ingressClassName` if desired

**Why this strategy**:
- Treats IngressClassParams as cluster-wide defaults (scheme, ipAddressType, group.name, certificateARNs)
- Minimizes annotation duplication across multiple Ingresses in the same group
- Certificate ARN and group name are configured once in IngressClassParams, not repeated in each Ingress
- Each Ingress only needs to specify per-Ingress settings (load-balancer-name, target-type, listen-ports, ssl-redirect)
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
