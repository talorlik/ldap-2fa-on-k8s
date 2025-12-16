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

  depends_on_resources = [
    module.argocd.argocd_capability_name,
    module.argocd.local_cluster_secret_name
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

  depends_on_resources = [
    module.argocd.argocd_capability_name
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

  depends_on_resources = [
    module.argocd.argocd_capability_name
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

  depends_on_resources = [
    module.argocd.argocd_capability_name
  ]
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
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
| depends_on_resources | Resources this depends on | list(any) | no | [] |

## Outputs

| Name | Description |
|------|-------------|
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

  depends_on_resources = [module.argocd.argocd_capability_name]
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

  depends_on_resources = [module.argocd.argocd_capability_name]
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
- Use `depends_on_resources` to ensure ArgoCD capability is ready before creating
Applications
