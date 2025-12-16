# ArgoCD Capability Requirements

## 1. Overview

### 1.1 What is EKS Argo CD Capability

The EKS Argo CD capability is a fully managed Argo CD service that:

- Runs in the EKS control plane (managed by AWS)
- Connects to your cluster via an IAM role and cluster registration Secret
- Reconciles workloads defined in Argo CD Applications
- Is enabled and configured via Terraform

### 1.2 GitOps Operational Flow

1. Create IAM role for the capability
2. Create `aws_eks_capability` resource (Argo CD)
3. Register local cluster via Kubernetes Secret
4. Define Argo CD `Application` resources pointing to Git repositories/paths
5. Argo CD automatically deploys and continuously reconciles applications from Git

### 1.3 Terraform Deployment Considerations

- **Existing workloads**: It's perfectly fine if the EKS cluster already has workloads
- **Resource naming**: Ensure resource naming and namespaces avoid collisions
- **Deployment order**: Deploy Argo CD capability first, then applications through Argo CD
- **Application behavior**:
  - If resources don't exist → Argo CD creates them on first sync
  - If resources already exist → Argo CD brings them into desired state per Git repo

## 2. Prerequisites

### 2.1 Infrastructure Prerequisites

#### 2.1.1 EKS Cluster

- Existing EKS cluster (Auto Mode or provisioned) on a supported Kubernetes version
- Must know `cluster_name` and `region`

#### 2.1.2 AWS Identity Center (IdC)

- Identity Center instance set up in a region
- One or more users or groups created
- Must know:
  - `idc_instance_arn`
  - `idc_region`
  - IDs for at least one user or group (for RBAC mapping)

#### 2.1.3 Git Repository

- Repository containing Kubernetes manifests, Helm charts, or Kustomize directories
- For initial setup: public HTTPS repository (no credentials required)
- For production: may require private repository access (see Section 7)

### 2.2 Terraform Prerequisites

#### 2.2.1 Required Providers

- `hashicorp/aws` provider version `>= 5.60.0` (includes `aws_eks_capability` resource)
  - Used to manage EKS capability and IAM resources
- `hashicorp/kubernetes` provider version `>= 2.30.0` (includes `kubernetes_manifest` for CRD support)
  - Used to create Argo CD cluster secret and Application CRDs

## 3. Architecture & Design

### 3.1 High-Level Terraform Components

The Terraform implementation requires:

1. **Providers**: AWS and Kubernetes providers configured against the EKS cluster
2. **IAM**: `aws_iam_role` for the Argo CD capability
3. **Capability**: `aws_eks_capability` resource creating the managed Argo CD
4. **Cluster Registration**: `kubernetes_secret` registering the EKS cluster with Argo CD
5. **Applications**: `kubernetes_manifest` resources defining Argo CD Applications

### 3.2 Dependency Chain & Resource Relationships

The following dependency chain must be respected:

```ascii
aws_iam_role → aws_eks_capability → kubernetes_secret (cluster registration) → kubernetes_manifest (Application)
```

Key relationships:

- IAM role must exist before capability creation
- Capability must be ACTIVE before cluster registration
- Cluster must be registered before Applications can target it
- Applications reference the registered cluster by name (`local-cluster`)

## 4. Implementation Requirements

### 4.1 Provider Configuration

#### 4.1.1 Terraform Provider Block

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

#### 4.1.2 EKS Data Sources

```hcl
# Existing cluster (Auto Mode)
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
```

#### 4.1.3 Required Variables

```hcl
variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}
```

### 4.2 IAM Requirements

#### 4.2.1 Capability IAM Role

**REQ-4.2.1.1**: Create IAM role trusted by `capabilities.eks.amazonaws.com`

```hcl
resource "aws_iam_role" "argocd_capability" {
  name = "ArgoCDCapabilityRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "capabilities.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}
```

#### 4.2.2 IAM Policy Requirements

**REQ-4.2.2.1**: Capability role must have permissions for:

- EKS API calls (describe cluster, list clusters, etc.)
- Access to Git repositories and AWS services used by Argo CD:
  - Secrets Manager (for repository credentials)
  - CodeConnections (for AWS CodeCommit/CodePipeline integration)
  - CodeCommit (if using AWS Git repositories)
  - ECR (if pulling images)

**REQ-4.2.2.2**: Example policy document (tighten for production):

```hcl
data "aws_iam_policy_document" "argocd_capability" {
  statement {
    sid    = "EKSDescribe"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeUpdate",
      "eks:ListUpdates"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "SecretsManager"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CodeConnections"
    effect = "Allow"

    actions = [
      "codeconnections:ListConnections",
      "codeconnections:GetConnection"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "argocd_capability" {
  role   = aws_iam_role.argocd_capability.id
  policy = data.aws_iam_policy_document.argocd_capability.json
}
```

**REQ-4.2.2.3**: In production, replace `resources = ["*"]` with specific ARNs
for secrets, connections, and clusters.

### 4.3 Argo CD Capability Configuration

#### 4.3.1 Required Variables

```hcl
variable "idc_instance_arn" {
  type        = string
  description = "ARN of the AWS Identity Center instance used for Argo CD auth"
}

variable "idc_region" {
  type        = string
  description = "Region of the Identity Center instance"
}

variable "idc_admin_group_id" {
  type        = string
  description = "Identity Center group ID to map to Argo CD ADMIN"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_vpce_ids" {
  type        = list(string)
  default     = []
  description = "Optional list of VPC endpoint IDs for private access to Argo CD"
}
```

#### 4.3.2 Capability Resource

**REQ-4.3.2.1**: Create `aws_eks_capability` resource with type `ARGOCD`

```hcl
resource "aws_eks_capability" "argocd" {
  cluster_name = var.cluster_name
  name         = "argocd-main"
  type         = "ARGOCD"

  role_arn                 = aws_iam_role.argocd_capability.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      # Namespace for any in-cluster Argo CRs; the control-plane service itself is managed by EKS
      namespace = var.argocd_namespace

      aws_idc {
        idc_instance_arn = var.idc_instance_arn
        idc_region       = var.idc_region
      }

      # Map an Identity Center group to Argo CD ADMIN role
      rbac_role_mappings {
        role = "ADMIN"

        identities {
          id   = var.idc_admin_group_id
          type = "SSO_GROUP"  # or SSO_USER
        }
      }

      # Optional – if specified, Argo CD endpoint is private and accessible only via these VPC endpoints
      dynamic "network_access" {
        for_each = length(var.argocd_vpce_ids) > 0 ? [1] : []
        content {
          vpce_ids = var.argocd_vpce_ids
        }
      }
    }
  }

  tags = {
    "Name"               = "argocd-main"
    "eks:cluster"        = var.cluster_name
    "eks:capabilityType" = "ARGOCD"
  }
}
```

**REQ-4.3.2.2**: Output the Argo CD server URL

```hcl
output "argocd_server_url" {
  value       = aws_eks_capability.argocd.server_url
  description = "Managed Argo CD UI/API endpoint"
}
```

**REQ-4.3.2.3**: Terraform provider waits until capability is ACTIVE before proceeding
to dependent resources.

### 4.4 Cluster Registration Requirements

#### 4.4.1 Local Cluster Registration

**REQ-4.4.1.1**: The managed capability does NOT automatically register the "local"
cluster. You must register it manually so Applications can target it.

**REQ-4.4.1.2**: Create Kubernetes Secret with cluster registration information:

```hcl
resource "kubernetes_secret" "argocd_local_cluster" {
  metadata {
    name      = "local-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  string_data = {
    name    = "local-cluster"
    # Important: use cluster ARN, not API server URL
    server  = data.aws_eks_cluster.this.arn
    project = "default"
  }

  depends_on = [
    aws_eks_capability.argocd
  ]
}
```

**REQ-4.4.1.3**: Applications must use the cluster name from the Secret (`local-cluster`)
in `spec.destination.name`, NOT `kubernetes.default.svc`.

### 4.5 Argo CD Application Requirements

#### 4.5.1 Application Variables

```hcl
variable "app_name" {
  type    = string
  default = "example-app"
}

variable "app_namespace" {
  type    = string
  default = "example"
}

variable "app_repo_url" {
  type        = string
  description = "Git repo URL containing app manifests or Helm chart"
}

variable "app_repo_path" {
  type        = string
  description = "Path within the repo (e.g. k8s/overlays/prod)"
}

variable "app_target_revision" {
  type    = string
  default = "HEAD"
}
```

#### 4.5.2 Application Resource

**REQ-4.5.2.1**: Create Argo CD Application using `kubernetes_manifest`:

```hcl
resource "kubernetes_manifest" "argocd_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"

      source = {
        repoURL        = var.app_repo_url
        targetRevision = var.app_target_revision
        path           = var.app_repo_path
      }

      # Use the cluster name used in the cluster Secret
      destination = {
        name      = kubernetes_secret.argocd_local_cluster.metadata[0].name
        namespace = var.app_namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    aws_eks_capability.argocd,
    kubernetes_secret.argocd_local_cluster
  ]
}
```

**REQ-4.5.2.2**: Application spec must include:

- `project`: Argo CD project name (default: "default")
- `source.repoURL`: Git repository URL
- `source.targetRevision`: Git branch/tag/commit (default: "HEAD")
- `source.path`: Path within repository
- `destination.name`: Cluster name from registered cluster Secret (see REQ-4.4.1.3)
- `destination.namespace`: Target Kubernetes namespace
- `syncPolicy`: Sync behavior configuration

## 5. Multi-Application Support

### 5.1 Requirements

**REQ-5.1.1**: Support multiple Argo CD Applications from the same Git repository,
each targeting different paths and namespaces.

**REQ-5.1.2**: Each Application must:

- Use the same `repoURL` and `targetRevision`
- Use different `path` values
- Use different destination namespaces
- Reference the same cluster (`local-cluster`)

### 5.2 Implementation Options

#### 5.2.1 Option A: Explicit Application Resources

**REQ-5.2.1.1**: Create separate `kubernetes_manifest` resources for each application:

```hcl
# Application 1 - service A
resource "kubernetes_manifest" "argocd_app_service_a" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "service-a-app"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/you/your-repo.git"
        targetRevision = "main"
        path           = "apps/service-a"
      }

      destination = {
        name      = kubernetes_secret.argocd_local_cluster.metadata[0].name
        namespace = "service-a"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    aws_eks_capability.argocd,
    kubernetes_secret.argocd_local_cluster
  ]
}

# Application 2 - service B
resource "kubernetes_manifest" "argocd_app_service_b" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "service-b-app"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/you/your-repo.git"
        targetRevision = "main"
        path           = "apps/service-b"
      }

      destination = {
        name      = kubernetes_secret.argocd_local_cluster.metadata[0].name
        namespace = "service-b"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    aws_eks_capability.argocd,
    kubernetes_secret.argocd_local_cluster
  ]
}
```

#### 5.2.2 Option B: Reusable Module (Recommended)

**REQ-5.2.2.1**: Create reusable module `modules/argocd_app`:

```hcl
# modules/argocd_app/main.tf
variable "app_name" {}
variable "argocd_namespace" {}
variable "cluster_name_in_argo" {}
variable "repo_url" {}
variable "target_revision" {}
variable "path" {}
variable "destination_namespace" {}

resource "kubernetes_manifest" "this" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = var.path
      }
      destination = {
        name      = var.cluster_name_in_argo
        namespace = var.destination_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}
```

**REQ-5.2.2.2**: Use module multiple times in root module:

```hcl
module "argocd_app_service_a" {
  source                = "./modules/argocd_app"
  app_name              = "service-a-app"
  argocd_namespace      = var.argocd_namespace
  cluster_name_in_argo  = kubernetes_secret.argocd_local_cluster.metadata[0].name
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  path                  = "apps/service-a"
  destination_namespace = "service-a"
}

module "argocd_app_service_b" {
  source                = "./modules/argocd_app"
  app_name              = "service-b-app"
  argocd_namespace      = var.argocd_namespace
  cluster_name_in_argo  = kubernetes_secret.argocd_local_cluster.metadata[0].name
  repo_url              = "https://github.com/you/your-repo.git"
  target_revision       = "main"
  path                  = "apps/service-b"
  destination_namespace = "service-b"
}
```

**REQ-5.2.2.3**: Module approach scales better for adding additional applications.

### 5.3 Multi-Application Behavior

**REQ-5.3.1**: Each Application appears independently in Argo CD UI with:

- Individual sync status
- Separate sync history
- Independent health status
- Independent sync policies (can be automated for one, manual for another)

**REQ-5.3.2**: Applications can be synced independently and may use different
Projects for multi-tenancy or isolation.

## 6. Execution Order & Deployment

### 6.1 Terraform Execution Sequence

**REQ-6.1.1**: Ensure EKS cluster exists and is reachable before applying Terraform.

**REQ-6.1.2**: Terraform apply must execute in this order:

1. Configure AWS and Kubernetes providers against the cluster
2. Create `aws_iam_role.argocd_capability` and policies
3. Create `aws_eks_capability.argocd` with Identity Center config and RBAC mappings
4. Create `kubernetes_secret.argocd_local_cluster` to register the EKS cluster ARN
5. Create `kubernetes_manifest.argocd_app` resources pointing to Git repositories,
paths, and namespaces

### 6.2 Post-Deployment Behavior

**REQ-6.2.1**: After Terraform apply completes:

- Argo CD runs in the EKS control plane (no extra pods on nodes)
- Argo CD communicates with cluster and Git repo as configured
- Applications are managed continuously from Git without further Terraform involvement

**REQ-6.2.2**: Applications automatically sync and reconcile based on Git
repository state.

## 7. Optional Features

### 7.1 Private Git Repository Access

**REQ-7.1.1**: Support private Git repositories using one of:

- Kubernetes Secrets with label `argocd.argoproj.io/secret-type: repository`
- AWS Secrets Manager secrets (with IAM permissions in capability role)
- AWS CodeConnections connection ARNs (referenced in Application `spec.source`)

**REQ-7.1.2**: For Kubernetes Secret approach:

- Create Secret with `argocd.argoproj.io/secret-type: repository` label
- Include `stringData` fields: `url`, `type`, `username`, `password` (or SSH keys)

**REQ-7.1.3**: For Secrets Manager approach:

- Reference secrets in Application or Project policy
- Configure IAM permissions in capability role to access Secrets Manager

**REQ-7.1.4**: For CodeConnections approach:

- Reference connection ARN in Application `spec.source` instead of direct Git URL
- Capability role must have permissions to use the connection

### 7.2 Network Access Control

**REQ-7.2.1**: Optionally restrict Argo CD endpoint access via VPC endpoints:

- Specify `argocd_vpce_ids` variable with list of VPC endpoint IDs
- When specified, Argo CD endpoint is private and accessible only via these VPC endpoints

### 7.3 Additional RBAC Mappings

**REQ-7.3.1**: Support multiple RBAC role mappings:

- Map Identity Center groups/users to different Argo CD roles (ADMIN, READ_ONLY, etc.)
- Configure multiple `rbac_role_mappings` blocks in capability configuration

## 8. References

- [Create an Argo CD capability](https://docs.aws.amazon.com/eks/latest/userguide/create-argocd-capability.html)
- [create-capability — AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/eks/create-capability.html)
- [aws_eks_capability | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability)
- [Register target clusters - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/argocd-register-clusters.html)
- [Argo CD concepts - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/argocd-concepts.html)
- [Create an Argo CD capability using the AWS CLI](https://docs.aws.amazon.com/eks/latest/userguide/argocd-create-cli.html)
- [Working with Argo CD - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/working-with-argocd.html)
- [Continuous Deployment with Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)
