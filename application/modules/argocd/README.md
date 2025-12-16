# ArgoCD Capability Module

This module deploys the AWS EKS ArgoCD Capability, which is a fully managed Argo
CD service that runs in the EKS control plane.

## Purpose

The ArgoCD Capability module:

- Creates IAM role and policies for ArgoCD capability
- Deploys the managed ArgoCD service on EKS
- Configures AWS Identity Center (IdC) authentication
- Registers the local EKS cluster with ArgoCD
- Sets up RBAC mappings for Identity Center groups/users

## What it Creates

1. **IAM Role** (`aws_iam_role.argocd_capability`)
   - Trusted by `capabilities.eks.amazonaws.com`
   - Attached with policies for EKS, Secrets Manager, CodeConnections, and
   optionally ECR/CodeCommit

2. **EKS Capability** (`aws_eks_capability.argocd`)
   - Managed ArgoCD service running in EKS control plane
   - Configured with Identity Center authentication
   - RBAC role mappings for Identity Center groups/users
   - Optional VPC endpoint configuration for private access

3. **Cluster Registration Secret** (`kubernetes_secret.argocd_local_cluster`)
   - Registers the local EKS cluster with ArgoCD
   - Required for Applications to target the cluster

## Prerequisites

- EKS cluster (Auto Mode or provisioned) must exist
- AWS Identity Center instance must be set up
- At least one Identity Center user or group for RBAC mapping
- Terraform AWS provider version `>= 5.60.0`
- Terraform Kubernetes provider version `>= 2.30.0`

## Usage

```hcl
module "argocd" {
  source = "./modules/argocd"

  env    = "prod"
  region = "us-east-1"
  prefix = "myorg"
  cluster_name = "my-eks-cluster"

  idc_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  idc_region       = "us-east-1"

  rbac_role_mappings = [
    {
      role = "ADMIN"
      identities = [
        {
          id   = "g-1234567890abcdef"
          type = "SSO_GROUP"
        }
      ]
    }
  ]

  # Optional: Enable ECR access for pulling images
  enable_ecr_access = true

  # Optional: Restrict access via VPC endpoints
  argocd_vpce_ids = ["vpce-1234567890abcdef0"]
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| env | Deployment environment | string | yes | - |
| region | Deployment region | string | yes | - |
| prefix | Name added to all resources | string | yes | - |
| cluster_name | Name of the EKS cluster | string | yes | - |
| argocd_role_name_component | Name component for ArgoCD IAM role | string | no | "argocd-role" |
| argocd_capability_name_component | Name component for ArgoCD capability | string | no | "argocd" |
| argocd_namespace | Kubernetes namespace for ArgoCD resources | string | no | "argocd" |
| argocd_project_name | ArgoCD project name for cluster registration | string | no | "default" |
| local_cluster_secret_name | Name of the Kubernetes secret for local cluster registration | string | no | "local-cluster" |
| idc_instance_arn | ARN of the AWS Identity Center instance | string | yes | - |
| idc_region | Region of the Identity Center instance | string | yes | - |
| rbac_role_mappings | List of RBAC role mappings for Identity Center | list(object) | no | [] |
| argocd_vpce_ids | List of VPC endpoint IDs for private access | list(string) | no | [] |
| delete_propagation_policy | Delete propagation policy (RETAIN or DELETE) | string | no | "RETAIN" |
| iam_policy_eks_resources | EKS resource ARNs for IAM policy | list(string) | no | ["*"] |
| iam_policy_secrets_manager_resources | Secrets Manager ARNs for IAM policy | list(string) | no | ["*"] |
| iam_policy_code_connections_resources | CodeConnections ARNs for IAM policy | list(string) | no | ["*"] |
| enable_ecr_access | Whether to enable ECR access in IAM policy | bool | no | false |
| iam_policy_ecr_resources | ECR repository ARNs for IAM policy | list(string) | no | ["*"] |
| enable_codecommit_access | Whether to enable CodeCommit access in IAM policy | bool | no | false |
| iam_policy_codecommit_resources | CodeCommit repository ARNs for IAM policy | list(string) | no | ["*"] |

## Outputs

| Name | Description |
|------|-------------|
| argocd_server_url | Managed Argo CD UI/API endpoint |
| argocd_capability_name | Name of the ArgoCD capability |
| argocd_capability_status | Status of the ArgoCD capability |
| argocd_iam_role_arn | ARN of the IAM role used by ArgoCD capability |
| argocd_iam_role_name | Name of the IAM role used by ArgoCD capability |
| local_cluster_secret_name | Name of the Kubernetes secret for local cluster registration |
| argocd_namespace | Kubernetes namespace where ArgoCD resources are deployed |
| argocd_project_name | ArgoCD project name used for cluster registration |

## RBAC Role Mappings

RBAC role mappings connect Identity Center groups/users to ArgoCD roles:

```hcl
rbac_role_mappings = [
  {
    role = "ADMIN"
    identities = [
      {
        id   = "g-1234567890abcdef"  # Identity Center group ID
        type = "SSO_GROUP"
      }
    ]
  },
  {
    role = "READ_ONLY"
    identities = [
      {
        id   = "u-0987654321fedcba"  # Identity Center user ID
        type = "SSO_USER"
      }
    ]
  }
]
```

Valid ArgoCD roles:

- `ADMIN` - Full administrative access
- `READ_ONLY` - Read-only access
- Custom roles defined in ArgoCD Projects

## IAM Policy Resources

For production, replace wildcard resources (`["*"]`) with specific ARNs:

```hcl
iam_policy_eks_resources = [
  "arn:aws:eks:us-east-1:123456789012:cluster/my-cluster"
]

iam_policy_secrets_manager_resources = [
  "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-git-repo-*"
]
```

## Network Access Control

To restrict ArgoCD endpoint access via VPC endpoints:

```hcl
argocd_vpce_ids = [
  "vpce-1234567890abcdef0",
  "vpce-0987654321fedcba1"
]
```

When specified, ArgoCD endpoint is private and accessible only via these VPC endpoints.

## Verifying Deployment

```bash
# Check capability status
aws eks describe-capability \
  --cluster-name my-eks-cluster \
  --capability-name myorg-us-east-1-argocd-prod \
  --capability-type ARGOCD

# Check cluster registration secret
kubectl get secret local-cluster -n argocd

# Access ArgoCD UI (get URL from output)
echo $TF_OUTPUT_argocd_server_url
```

## Notes

- The capability runs in the EKS control plane (no pods on worker nodes)
- Cluster registration is required before Applications can target the cluster
- Use the `local_cluster_secret_name` output when creating ArgoCD Applications
- IAM policies use wildcards by default; tighten for production use
- Delete propagation policy defaults to `RETAIN` to prevent accidental deletion
