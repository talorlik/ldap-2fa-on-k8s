# ArgoCD Application Module

This module creates an ArgoCD Application resource that subscribes a Kubernetes
application to ArgoCD for GitOps deployment.

## Purpose

The ArgoCD Application module:

- Creates a Kubernetes Application CRD that ArgoCD uses to manage application deployments
- Configures source (Git repository, path, revision) and destination (cluster, namespace)
- Sets up sync policies for automated or manual deployments
- Supports Helm charts, Kustomize, and plain Kubernetes manifests

## What it Creates

1. **ArgoCD Application** (`kubernetes_manifest.argocd_app`)
   - Kubernetes Custom Resource of type `Application` from `argoproj.io/v1alpha1`
   - Defines source repository, path, and target cluster/namespace
   - Configures sync behavior (automated, manual, retry policies)
   - Supports Helm, Kustomize, and directory-based deployments

## Prerequisites

- ArgoCD Capability must be deployed and active
- Local cluster must be registered with ArgoCD (via cluster secret)
- Git repository must be accessible from ArgoCD
- Kubernetes provider must be configured with access to the EKS cluster
- If deploying applications with Ingress resources that use ALB, the ALB module
  must be deployed first to create the IngressClass

## Integration with ALB Module

Applications deployed via ArgoCD that include Ingress resources should
reference the IngressClass created by the [ALB module](../alb/README.md). The
ALB module creates an IngressClass and IngressClassParams for EKS Auto Mode
ALB provisioning.

### Using ALB IngressClass in ArgoCD Applications

When your Git repository contains Ingress resources (e.g., in Helm charts,
Kustomize overlays, or plain manifests), they should reference the
IngressClass created by the ALB module:

**Example Ingress in your Git repository:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: my-namespace
  annotations:
    # Per-Ingress ALB settings
    alb.ingress.kubernetes.io/load-balancer-name: "my-app-alb"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: myorg-us-east-1-ic-alb-prod  # From ALB module output
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

**Key Points:**

- The `ingressClassName` should match the IngressClass name from the ALB
  module output (`module.alb.ingress_class_name`)
- Cluster-wide ALB defaults (scheme, IP type, group name, certificate ARNs)
  are configured in IngressClassParams by the ALB module
- Per-Ingress settings (load-balancer-name, target-type, listen-ports,
  ssl-redirect) are specified in Ingress annotations
- The IngressClass created by the ALB module is set as the default, so
  `ingressClassName` can be omitted if desired
- Multiple Ingresses can share a single ALB by using the same IngressClass
  (which references IngressClassParams with `group.name`)

**Helm Chart Example:**

If your ArgoCD application deploys a Helm chart, configure the IngressClass
in your values:

```yaml
# values.yaml
ingress:
  enabled: true
  className: "myorg-us-east-1-ic-alb-prod"  # From ALB module output
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: "my-app-alb"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
```

For more details on ALB configuration, see the [ALB module documentation](../alb/README.md).

## Usage

### Basic Application (Plain Manifests)

```hcl
module "argocd_app_example" {
  source = "./modules/argocd_app"

  app_name              = "example-app"
  argocd_namespace      = "argocd"
  cluster_name_in_argo  = "local-cluster"
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  repo_path             = "apps/example-app"
  destination_namespace = "example"

  sync_policy = {
    automated = {
      prune      = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true"]
  }

  depends_on = [
    module.argocd
  ]
}
```

### Helm Chart Application

```hcl
module "argocd_app_helm" {
  source = "./modules/argocd_app"

  app_name              = "nginx-app"
  argocd_namespace      = "argocd"
  cluster_name_in_argo  = "local-cluster"
  repo_url              = "https://github.com/you/helm-charts.git"
  target_revision       = "main"
  repo_path             = "charts/nginx"
  destination_namespace = "nginx"

  helm_config = {
    value_files = ["values.yaml", "values-prod.yaml"]
    parameters = [
      {
        name  = "replicaCount"
        value = "3"
      },
      {
        name         = "image.tag"
        value        = "1.21.0"
        force_string = false
      }
    ]
    release_name = "nginx"
  }

  sync_policy = {
    automated = {
      prune     = true
      self_heal = true
    }
    sync_options = ["CreateNamespace=true"]
  }

  depends_on = [
    module.argocd
  ]
}
```

### Kustomize Application

```hcl
module "argocd_app_kustomize" {
  source = "./modules/argocd_app"

  app_name              = "kustomize-app"
  argocd_namespace      = "argocd"
  cluster_name_in_argo  = "local-cluster"
  repo_url              = "https://github.com/you/kustomize-apps.git"
  target_revision       = "main"
  repo_path             = "overlays/production"
  destination_namespace = "production"

  kustomize_config = {
    images = ["nginx:1.21.0"]
    common_labels = {
      environment = "production"
      managed-by  = "argocd"
    }
  }

  sync_policy = {
    automated = {
      prune     = true
      self_heal = true
    }
  }

  depends_on = [
    module.argocd
  ]
}
```

### Manual Sync Application

```hcl
module "argocd_app_manual" {
  source = "./modules/argocd_app"

  app_name              = "manual-app"
  argocd_namespace      = "argocd"
  cluster_name_in_argo  = "local-cluster"
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  repo_path             = "apps/manual-app"
  destination_namespace = "manual"

  # No sync_policy = manual sync only
  sync_policy = null

  depends_on = [
    module.argocd
  ]
}
```

## Inputs

| Name | Description | Type | Required | Default |
| ------ | ------------- | ------ | ---------- | --------- |
| app_name | Name of the ArgoCD Application | string | yes | - |
| argocd_namespace | Kubernetes namespace for ArgoCD Application | string | no | "argocd" |
| argocd_project_name | ArgoCD project name | string | no | "default" |
| cluster_name_in_argo | Name of the cluster in ArgoCD | string | yes | - |
| repo_url | Git repository URL | string | yes | - |
| target_revision | Git branch/tag/commit | string | no | "HEAD" |
| repo_path | Path within repository | string | yes | - |
| destination_namespace | Target Kubernetes namespace | string | yes | - |
| destination_server | Optional Kubernetes server URL | string | no | null |
| app_labels | Labels for Application resource | map(string) | no | {} |
| app_annotations | Annotations for Application resource | map(string) | no | {} |
| sync_policy | Sync policy configuration | object | no | null |
| ignore_differences | List of ignore differences configs | list(object) | no | [] |
| revision_history_limit | Number of revisions to keep | number | no | 10 |
| helm_config | Helm-specific configuration | object | no | null |
| kustomize_config | Kustomize-specific configuration | object | no | null |
| directory_config | Directory-specific configuration | object | no | null |

## Outputs

| Name | Description |
| ------ | ------------- |
| app_name | Name of the ArgoCD Application |
| app_namespace | Namespace where Application is deployed |
| app_uid | UID of the Application resource |
| destination_namespace | Target Kubernetes namespace |
| repo_url | Git repository URL |
| repo_path | Path within repository |
| target_revision | Git branch/tag/commit being synced |

## Sync Policy Options

### Automated Sync

```hcl
sync_policy = {
  automated = {
    prune      = true   # Delete resources not in Git
    self_heal   = true   # Auto-sync on drift detection
    allow_empty = false # Allow empty application
  }
  sync_options = [
    "CreateNamespace=true",  # Create namespace if missing
    "PrunePropagationPolicy=foreground",
    "PruneLast=true"
  ]
}
```

### Retry Policy

```hcl
sync_policy = {
  automated = {
    prune     = true
    self_heal = true
  }
  retry = {
    limit = 5
    backoff = {
      duration    = "5s"
      factor      = 2
      max_duration = "3m"
    }
  }
}
```

## Ignore Differences

To ignore specific fields that are managed outside of Git:

```hcl
ignore_differences = [
  {
    group = "apps"
    kind  = "Deployment"
    jsonPointers = ["/spec/replicas"]
  },
  {
    kind              = "Service"
    jsonPointers      = ["/spec/clusterIP"]
    managedFieldsManagers = ["kubectl"]
  }
]
```

## Multi-Application Pattern

Deploy multiple applications from the same repository:

```hcl
module "argocd_app_service_a" {
  source = "./modules/argocd_app"

  app_name              = "service-a-app"
  cluster_name_in_argo  = module.argocd.local_cluster_secret_name
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  repo_path             = "apps/service-a"
  destination_namespace = "service-a"

  sync_policy = {
    automated = {
      prune     = true
      self_heal  = true
    }
  }

  depends_on = [module.argocd]
}

module "argocd_app_service_b" {
  source = "./modules/argocd_app"

  app_name              = "service-b-app"
  cluster_name_in_argo  = module.argocd.local_cluster_secret_name
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  repo_path             = "apps/service-b"
  destination_namespace = "service-b"

  sync_policy = {
    automated = {
      prune     = true
      self_heal  = true
    }
  }

  depends_on = [module.argocd]
}
```

## Verifying Application

```bash
# Check Application status
kubectl get application -n argocd example-app

# View Application details
kubectl describe application -n argocd example-app

# Check sync status
kubectl get application -n argocd example-app -o jsonpath='{.status.sync.status}'

# View Application in ArgoCD UI
# Navigate to: https://<argocd-server-url>/applications/example-app
```

## Notes

- Applications must reference the cluster name from the cluster registration secret
- Use `cluster_name_in_argo` from the ArgoCD module output
- Sync policies can be automated or manual
- Supports Helm, Kustomize, and plain Kubernetes manifests
- Applications are continuously reconciled by ArgoCD based on Git state
- Use `depends_on` in the module block to ensure ArgoCD capability is ready
  before creating Applications
