# ALB Module

This module creates Kubernetes IngressClass and IngressClassParams resources for
EKS Auto Mode Application Load Balancer (ALB) provisioning.

## Purpose

The ALB module configures EKS Auto Mode's built-in load balancer driver to
automatically provision and manage Application Load Balancers when Ingress
resources are created. It provides:

- **IngressClass**: Binds Ingress resources to EKS Auto Mode ALB controller
- **IngressClassParams**: Defines cluster-wide ALB defaults (scheme, IP type,
group name, certificate ARNs)

## Key Features

### EKS Auto Mode Integration

- **Built-in Load Balancer Driver**: EKS Auto Mode includes its own ALB driver
(`eks.amazonaws.com/alb`), no need to install AWS Load Balancer Controller
- **Automatic IAM Permissions**: EKS Auto Mode handles IAM permissions
automatically - no need to attach `AWSLoadBalancerControllerIAMPolicy`
- **Simplified Configuration**: No separate controller pods on worker nodes

### IngressClassParams Configuration

EKS Auto Mode IngressClassParams supports these cluster-wide defaults:

| Setting | Description |
|---------|-------------|
| `scheme` | `internet-facing` or `internal` |
| `ipAddressType` | `ipv4` or `dualstack` |
| `group.name` | ALB group name for grouping multiple Ingresses |
| `certificateARNs` | ACM certificate ARNs for TLS termination |

> **Note**: Unlike AWS Load Balancer Controller, EKS Auto Mode IngressClassParams
> does NOT support subnets, security groups, or tags.

### Annotation Strategy

The module implements a two-tier configuration approach:

1. **Cluster-wide defaults** (IngressClassParams):
   - `scheme`, `ipAddressType`, `group.name`, `certificateARNs`
   - Inherited by all Ingresses using this IngressClass

2. **Per-Ingress settings** (Ingress annotations):
   - `alb.ingress.kubernetes.io/load-balancer-name`
   - `alb.ingress.kubernetes.io/target-type`
   - `alb.ingress.kubernetes.io/listen-ports`
   - `alb.ingress.kubernetes.io/ssl-redirect`

## What it Creates

1. **IngressClassParams** (`null_resource.apply_ingressclassparams_manifest`)
   - Custom resource for EKS Auto Mode ALB configuration
   - Applied via `kubectl apply` (no native Terraform resource available)
   - Contains cluster-wide ALB defaults

2. **IngressClass** (`kubernetes_ingress_class_v1.ingressclass_alb`)
   - Kubernetes IngressClass resource
   - References IngressClassParams for ALB defaults
   - Set as default IngressClass for the cluster
   - Uses `eks.amazonaws.com/alb` controller

## Prerequisites

- EKS cluster with Auto Mode enabled (`compute_config.enabled = true`)
- AWS CLI installed and configured with cluster access
- ACM certificate for HTTPS/TLS termination
- `kubectl` configured with cluster access

## Usage

```hcl
module "alb" {
  source = "./modules/alb"

  env          = "prod"
  region       = "us-east-1"
  prefix       = "myorg"
  cluster_name = "my-eks-cluster"
  app_name     = "my-app"

  ingressclass_alb_name       = "ic-alb"
  ingressclassparams_alb_name = "icp-alb"

  alb_scheme          = "internet-facing"
  alb_ip_address_type = "ipv4"
  alb_group_name      = "my-app-alb-group"
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc123"
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| env | Environment suffix for resource names | string | yes | - |
| region | Deployment region | string | yes | - |
| prefix | Prefix for resource names | string | yes | - |
| app_name | Application name | string | yes | - |
| cluster_name | Name of EKS cluster | string | yes | - |
| ingressclass_alb_name | Name component for IngressClass | string | yes | - |
| ingressclassparams_alb_name | Name component for IngressClassParams | string | yes | - |
| acm_certificate_arn | ACM certificate ARN for HTTPS | string | no | null |
| alb_scheme | ALB scheme (`internet-facing` or `internal`) | string | no | "internet-facing" |
| alb_ip_address_type | IP address type (`ipv4` or `dualstack`) | string | no | "ipv4" |
| alb_group_name | ALB group name (max 63 chars) | string | no | null |

## Outputs

| Name | Description |
|------|-------------|
| ingress_class_name | Name of the IngressClass for shared ALB |
| ingress_class_params_name | Name of the IngressClassParams |
| alb_scheme | ALB scheme configured in IngressClassParams |
| alb_ip_address_type | ALB IP address type configured in IngressClassParams |

## How Ingresses Use This Module

After deploying this module, Ingress resources can use the IngressClass:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    # Per-Ingress settings
    alb.ingress.kubernetes.io/load-balancer-name: "my-alb"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: myorg-us-east-1-ic-alb-prod  # From module output
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

## Multi-Ingress Single ALB

Multiple Ingresses can share a single ALB by:

1. Using the same IngressClass (which references IngressClassParams with
`group.name`)
2. All Ingresses in the group are routed through the same ALB
3. Host-based routing directs traffic to appropriate services

Example:

- `phpldapadmin.example.com` → phpLDAPadmin service
- `passwd.example.com` → LTB-passwd service
- `app.example.com` → 2FA application

## Verifying Deployment

```bash
# Check IngressClass
kubectl get ingressclass
kubectl describe ingressclass myorg-us-east-1-ic-alb-prod

# Check IngressClassParams
kubectl get ingressclassparams
kubectl describe ingressclassparams myorg-us-east-1-icp-alb-prod

# Check Ingresses using this IngressClass
kubectl get ingress -A -o wide

# Verify ALB was created
aws elbv2 describe-load-balancers --region us-east-1
```

## Differences: EKS Auto Mode vs AWS Load Balancer Controller

| Feature | EKS Auto Mode | AWS Load Balancer Controller |
|---------|---------------|------------------------------|
| Controller | `eks.amazonaws.com/alb` | `alb.ingress.kubernetes.io` |
| API Group | `eks.amazonaws.com` | `elbv2.k8s.aws` |
| IAM Setup | Automatic | Requires IAM policy |
| Installation | Built-in | Requires Helm chart |
| IngressClassParams | `scheme`, `ipAddressType`, `group.name`, `certificateARNs` | All above plus `subnets`, `securityGroups`, `tags` |

## Notes

- IngressClassParams is created via `kubectl apply` because there's no native
Terraform resource for EKS Auto Mode IngressClassParams
- The IngressClass is set as the default class for the cluster
- ALB is automatically provisioned when Ingress resources are created
- Changes to IngressClassParams trigger resource recreation

## References

- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode.html)
- [EKS Auto Mode IngressClassParams](https://docs.aws.amazon.com/eks/latest/userguide/eks-auto-mode-ingress.html)
- [Kubernetes IngressClass Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class)
