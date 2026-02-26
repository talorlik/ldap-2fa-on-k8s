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
   - Single inline policy: EKS describe/list, Secrets Manager, KMS decrypt,
   CodeConnections (incl. UseConnection), and optional ECR/CodeCommit when
   enabled

2. **EKS Capability** (`aws_eks_capability.argocd`)
   - Managed ArgoCD service running in EKS control plane
   - Configured with Identity Center authentication
   - RBAC role mappings for Identity Center groups/users
   - Optional VPC endpoint configuration for private access

3. **Cluster Registration Secret** (`kubernetes_secret.argocd_local_cluster`)
   - Registers the local EKS cluster with ArgoCD
   - Required for Applications to target the cluster

## Creation Order

Resources are created in this order (later items wait for earlier ones).
Roles and IAM-role bindings are created **before** the capability so the
capability starts with permissions already in place. The capability
resource explicitly depends on the ClusterRole and IAM-role
ClusterRoleBinding so Terraform creates them first.

**Before the capability:**

1. **IAM role and inline policy**
   (`aws_iam_role.argocd_capability`,
   `aws_iam_role_policy.argocd_capability`)
2. **Namespace** (`kubernetes_namespace_v1.argocd`)
3. **Sleep** (`time_sleep.wait_for_iam_and_ns_propagation`) – IAM and namespace
   propagation
4. **ClusterRole** (`kubernetes_manifest.argocd_application_controller_clusterrole`)
   – RBAC role for ArgoCD application controller
5. **IAM role ClusterRoleBinding**
   (`kubernetes_manifest.argocd_application_controller_iam_role_binding`) –
   binds ClusterRole to the capability IAM role (so the role has permissions
   as soon as the capability starts)

**Capability and then associations:**

1. **EKS ArgoCD capability** (`aws_eks_capability.argocd`) – AWS deploys managed
   ArgoCD (CREATING then ACTIVE). AWS also creates an EKS access entry for the
   capability IAM role; we do not create that entry.
2. **Sleep** (`time_sleep.wait_for_argocd`) – waits for capability to be ACTIVE
   and for access entry and ArgoCD SAs to propagate (e.g. 5m30s)
3. **ClusterRoleBinding for service accounts**
   (`kubernetes_manifest.argocd_application_controller_clusterrolebinding`) –
   binds ClusterRole to ArgoCD SAs (argocd-application-controller, etc.); must
   be after capability because those SAs are created by the capability
4. **Access policy association**
   (`aws_eks_access_policy_association.argocd_capability_cluster_admin`) –
   associates cluster-admin policy with the **auto-created** access entry
   (entry must exist first, hence after capability)
5. **Cluster registration secret** (`kubernetes_secret.argocd_local_cluster`)
6. **External data** (`data.external.argocd_capability`) – queries server URL
   and status

The **EKS access entry** for the capability IAM role is created automatically by
AWS when the capability is created; it cannot be created beforehand. We only
associate an additional access policy with that entry after the capability
(and thus the entry) exists.

## Prerequisites

- EKS cluster (Auto Mode or provisioned) must exist
- AWS Identity Center instance must be set up
- At least one Identity Center user or group for RBAC mapping
- Terraform AWS provider version `>= 6.21.0` (includes `aws_eks_capability` resource)
- Terraform Kubernetes provider version `~> 2.0` (includes `kubernetes_manifest`
for CRD support)
- Terraform Helm provider version `~> 2.0` (used for Helm chart deployments)
- Terraform Time provider version `~> 0.9` (used for time-based resources)
- Terraform version `~> 1.14.0`

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
| ------ | ------------- | ------ | ---------- | --------- |
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
| iam_policy_kms_key_arns | KMS key ARNs for Secrets Manager decrypt | list(string) | no | ["*"] |
| enable_ecr_access | Add ECR pull permissions to IAM policy | bool | no | false |
| iam_policy_ecr_resources | ECR repository ARNs for IAM policy | list(string) | no | ["*"] |
| enable_codecommit_access | Add CodeCommit access to IAM policy | bool | no | false |
| iam_policy_codecommit_resources | CodeCommit repository ARNs for IAM policy | list(string) | no | ["*"] |

## Outputs

| Name | Description |
| ------ | ------------- |
| argocd_server_url | Managed Argo CD UI/API endpoint (automatically retrieved via AWS CLI) |
| argocd_capability_name | Name of the ArgoCD capability |
| argocd_capability_status | Status of the ArgoCD capability (automatically retrieved via AWS CLI, should be "ACTIVE" when ready) |
| argocd_capability_error | Error message if capability query fails (null if successful) |
| argocd_iam_role_arn | ARN of the IAM role used by ArgoCD capability |
| argocd_iam_role_name | Name of the IAM role used by ArgoCD capability |
| local_cluster_secret_name | Name of the Kubernetes secret for local cluster registration |
| argocd_namespace | Kubernetes namespace where ArgoCD resources are deployed |
| argocd_project_name | ArgoCD project name used for cluster registration |

> [!NOTE]
>
> The `argocd_server_url` and `argocd_capability_status` outputs are automatically
> retrieved via an external data source that queries the AWS EKS capability using
> AWS CLI. The external data source uses `scripts/assume-github-role.sh` script,
> which automatically detects the execution environment:
>
> - **GitHub Actions**: The script uses `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID`
>   environment variables (no AWS Secrets Manager access required)
> - **Local Environments**: The script falls back to AWS Secrets Manager to retrieve
>   role ARNs (secret: `github-role`) and ExternalId (secret: `external-id`)
>
> This unified approach ensures the same script works seamlessly in both environments.
> If the capability query fails, the `argocd_capability_error` output will contain
> the error message.

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

## IAM Policy

The role has a single **inline policy** with:

- EKS (DescribeCluster, ListClusters, DescribeUpdate, ListUpdates), Secrets
  Manager (GetSecretValue, DescribeSecret, ListSecrets), KMS (Decrypt,
  DescribeKey), CodeConnections (UseConnection, GetConnection, ListConnections)
- Optional ECR and/or CodeCommit when `enable_ecr_access` and/or
  `enable_codecommit_access` are true

For production, scope resources via the IAM policy variables (e.g.
`iam_policy_eks_resources`, `iam_policy_secrets_manager_resources`,
`iam_policy_code_connections_resources`, `iam_policy_kms_key_arns`,
`iam_policy_ecr_resources`, `iam_policy_codecommit_resources`):

```hcl
enable_ecr_access         = true
iam_policy_ecr_resources  = ["arn:aws:ecr:us-east-1:123456789012:repository/my-app"]

enable_codecommit_access        = true
iam_policy_codecommit_resources = ["arn:aws:codecommit:us-east-1:123456789012:my-repo"]
```

### Permissions by service

| Service | Actions | Variable for resources |
| -------- | -------- | ----------------------- |
| EKS | DescribeCluster, ListClusters, DescribeUpdate, ListUpdates | `iam_policy_eks_resources` |
| Secrets Manager | GetSecretValue, DescribeSecret, ListSecrets | `iam_policy_secrets_manager_resources` |
| KMS | Decrypt, DescribeKey | `iam_policy_kms_key_arns` |
| CodeConnections | UseConnection, GetConnection, ListConnections | `iam_policy_code_connections_resources` |
| ECR (optional) | GetAuthorizationToken, BatchCheckLayerAvailability, GetDownloadUrlForLayer, BatchGetImage | `iam_policy_ecr_resources` |
| CodeCommit (optional) | GitPull, GetRepository | `iam_policy_codecommit_resources` |

No AWS managed policy is used; the role has only the trust policy and this
inline policy.

### Recommendations

1. **Least privilege:** Scope resources via the IAM policy variables instead of
   `["*"]` where possible.
2. **ECR:** Set `enable_ecr_access = true` (and pass it from the root module) if
   Argo CD pulls from ECR.

### AWS documentation

- [Amazon EKS capability IAM role](https://docs.aws.amazon.com/eks/latest/userguide/capability-role.html)
- [Argo CD considerations - Permissions](https://docs.aws.amazon.com/eks/latest/userguide/argocd-considerations.html)
- [Configure Argo CD permissions - AWS service permissions](https://docs.aws.amazon.com/eks/latest/userguide/argocd-permissions.html)
- [Connect to Git repositories with AWS CodeConnections](https://docs.aws.amazon.com/eks/latest/userguide/integration-codeconnections.html)

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
- The external data source requires `jq` command-line tool for JSON parsing
- The external data source requires `scripts/assume-github-role.sh` script to be
present (in the repository `scripts/` directory; workflows run from application_infra)
- The script automatically works in both environments:
  - **GitHub Actions**: Uses `DEPLOYMENT_ROLE_ARN`/`EXTERNAL_ID` environment variables
  - **Local**: Falls back to AWS Secrets Manager (secrets: `github-role`, `external-id`)
- Capability status must be "ACTIVE" before deploying ArgoCD Applications
(validation is performed by application deployment scripts)
