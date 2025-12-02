# Single ALB multiple Ingresses

Goal:
Single internet-facing ALB on EKS, managed by AWS Load Balancer Controller, using:

- Domain: `talorlik.com`
- HTTPS on port 443
- ACM certificate (in ACM, already validated)
- Multiple Ingresses from `helm-openldap` (phpLDAPadmin + ltb-passwd) sharing that ALB via IngressGroup.

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
      # IngressGroup - share one ALB
      alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
      alb.ingress.kubernetes.io/group.order: "10"
      # ALB name (only on lowest order Ingress in group)
      alb.ingress.kubernetes.io/load-balancer-name: "${alb_group_name}"

      # ALB properties (define once for the group)
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip

      # TLS with ACM on 443 + redirect from 80 → 443
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
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
      # Same IngressGroup → same ALB
      alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
      alb.ingress.kubernetes.io/group.order: "20"

      # Must not conflict with group-wide settings above
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    path: /
    pathType: Prefix
    hosts:
      - "${phpldapadmin_host}"
```

What this does:

- `alb.ingress.kubernetes.io/group.name: "${alb_group_name}"` on both Ingresses forces them into the same IngressGroup, so the controller provisions a single ALB and merges the rules.
- `alb.ingress.kubernetes.io/load-balancer-name: "${alb_group_name}"` (on the Ingress with lowest order) sets a custom name for the ALB.
- `alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"` tells the controller to create an HTTPS listener and use the ACM cert.
- `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'` plus `alb.ingress.kubernetes.io/ssl-redirect: "443"` creates an HTTP 80 listener that redirects everything to HTTPS 443, while 443 terminates TLS using the ACM cert.
- `alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"` sets a modern TLS security policy.
- Route 53: create two A/AAAA alias records:

  - `${phpldapadmin_host}` → this ALB
  - `${ltb_passwd_host}` → same ALB

Result: a single internet-facing ALB with a custom name, TLS on 443, separate hostnames for each UI.

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
       name: alb
     spec:
       controller: alb.ingress.kubernetes.io
       parameters:
         apiGroup: elbv2.k8s.aws
         kind: IngressClassParams
         name: alb-default
     ```

   - Your `Ingress` then says:

     ```yaml
     spec:
       ingressClassName: alb
     ```

   - This is the piece that tells the AWS Load Balancer Controller:
     “You are responsible for this Ingress. Create/manage an ALB for it.”

   Without an IngressClass, either:

   - nothing watches the Ingress, or
   - you fall back to legacy behavior (controller-specific annotations), which AWS now documents as legacy.

3. Why you need IngressClassParams

   - `IngressClassParams` is an AWS-specific CRD that holds ALB configuration shared across many Ingresses.
   - It lets you centralize things that should not be repeated in every Helm chart, for example:

     - scheme (internet-facing vs internal)
     - ipAddressType (ipv4 / dualstack)
     - external subnets and internal subnets to use
     - security groups for the ALB
     - default tags and attributes
   - Roughly: Ingress = routing rules; IngressClassParams = ALB profile.

   Helm charts like `openldap-stack-ha` only deal with routing rules. They don’t know:

   - which subnets your ALB must live in
   - which security group policy you decided on
   - whether the ALB is shared, internal, dualstack, etc.

   IngressClassParams is where you define those once, at cluster level, and then every Ingress that uses that IngressClass inherits them automatically.

4. Why you still “need” them even though ALB is auto-provisioned

   - “ALB is auto-provisioned” = the AWS Load Balancer Controller automatically creates an ALB *when it sees an Ingress that belongs to it*.
   - How does it know the Ingress “belongs to it”? Through:

     - `spec.ingressClassName` that references an `IngressClass` with `controller: alb.ingress.kubernetes.io`.
   - How does it know what defaults to apply to that ALB? Through:

     - The `parameters` reference from the IngressClass to an `IngressClassParams` object.

   So the chain is:

   `Ingress`
   → `ingressClassName: alb`
   → `IngressClass` (`controller: alb.ingress.kubernetes.io`)
   → `parameters: IngressClassParams` (ALB config profile)
   → AWS Load Balancer Controller
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

     - Provide an `IngressClass` called `alb` and associated `IngressClassParams` that encode “use AWS ALB with these defaults”.

   That separation is why you still need IngressClass and IngressClassParams even though the ALB provisioning is “automatic”. The automation needs a target profile and a controller binding, and those are exactly those two objects.
