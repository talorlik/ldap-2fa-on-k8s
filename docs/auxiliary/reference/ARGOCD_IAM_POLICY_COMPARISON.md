# ArgoCD IAM Policy Comparison

Comparison between the project's ArgoCD capability IAM permissions and the
permissions described in official AWS documentation. The project uses the AWS
managed policy `AmazonEKSCapabilityArgoCD` for core permissions and an
optional supplemental inline policy for ECR and CodeCommit when enabled. The
managed policy is not fully documented in the public [AWS Managed Policy
Reference](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/);
the tables below use the EKS user guide as the authoritative source.

## Summary

| Aspect | Official (EKS user guide) | This project |
| -------- | --------------------------- | -------------- |
| Core permissions | None required by default; optional add-ons | AWS managed policy `AmazonEKSCapabilityArgoCD` |
| Integrations (EKS, Secrets Manager, CodeConnections, KMS) | Optional; docs list required actions | Core integrations inline policy (always attached) |
| Extras | ECR, CodeCommit as needed | Supplemental inline policy: ECR and/or CodeCommit when enabled |

The project attaches `AmazonEKSCapabilityArgoCD` plus an explicit **core
integrations** inline policy (EKS describe/list, Secrets Manager, CodeConnections
including UseConnection, KMS decrypt) so the role has all documented
permissions even if the managed policy omits some. Optional ECR and CodeCommit
are added via a supplemental inline policy when enabled.

## Service-by-service comparison

### EKS

| Item | Official (capability-role, argocd-considerations) | Your custom policy | Notes |
| ------ | -------------------------------------------------- | -------------------- | ------- |
| Documented for Argo CD role | No EKS actions listed; "no IAM permissions required by default" | eks:DescribeCluster, eks:ListClusters, eks:DescribeUpdate, eks:ListUpdates | EKS actions may be required by the capability control plane; not documented as customer role requirements. Your policy grants them with configurable resources (default `["*"]`). |

### Secrets Manager

| Item | Official | Your custom policy | Notes |
| ------ | ---------- | -------------------- | ------- |
| Actions | GetSecretValue, DescribeSecret (optional; capability-role example); argocd-considerations suggests AWSSecretsManagerClientReadOnlyAccess | GetSecretValue, DescribeSecret, ListSecrets | You include ListSecrets (broader). Official example scopes to `arn:aws:secretsmanager:region:account-id:secret:argocd/*`; yours uses var (default `["*"]`). KMS decrypt is in AWSSecretsManagerClientReadOnlyAccess; your policy does not add kms:Decrypt (Secrets Manager may use default key or you may need it for custom keys). |
| Resources | Example: argocd/* | var.iam_policy_secrets_manager_resources (default `["*"]`) | Configurable; can be tightened. |

### CodeConnections

| Item | Official | Your custom policy | Notes |
| ------ | ---------- | -------------------- | ------- |
| Actions | UseConnection, GetConnection (integration-codeconnections, capability-role example) | ListConnections, GetConnection | **Gap:** You have ListConnections but not **UseConnection**; UseConnection is required for Argo CD to use the connection. Add codeconnections:UseConnection. |
| Resources | Example: connection/* | var.iam_policy_code_connections_resources (default `["*"]`) | Configurable. |

### ECR (optional)

| Item | Official | Your custom policy | Notes |
| ------ | ---------- | -------------------- | ------- |
| Actions | GetAuthorizationToken, BatchCheckLayerAvailability, GetDownloadUrlForLayer, BatchGetImage (argocd-permissions) | Same four actions | Equivalent when enable_ecr_access = true. |
| When included | When using ECR for Helm/images | When var.enable_ecr_access = true (default false) | Your default is off; enable via module variable if needed. |
| Resources | * | var.iam_policy_ecr_resources (default `["*"]`) | Equivalent when enabled. |

### CodeCommit (optional)

| Item | Official | Your custom policy | Notes |
| ------ | ---------- | -------------------- | ------- |
| Actions | GitPull (argocd-considerations); GetRepository not in all examples | GitPull, GetRepository | You add GetRepository; both are reasonable for repo access. |
| When included | When using CodeCommit repos | When var.enable_codecommit_access = true (default false) | Same idea. |
| Resources | * or specific repo ARN | var.iam_policy_codecommit_resources (default `["*"]`) | Configurable. |

## AmazonEKSCapabilityArgoCD managed policy

The managed policy `arn:aws:iam::aws:policy/AmazonEKSCapabilityArgoCD` is not
documented in the EKS user guide or in the AWS Managed Policy Reference (the
reference URL returns a generic managed policies page). The EKS docs instead
describe:

- A capability role with only a trust policy for basic use
- Optional inline or custom policies for Secrets Manager, CodeConnections,
  CodeCommit, and ECR as needed

If you attach `AmazonEKSCapabilityArgoCD`, its contents are not publicly
listed; you can inspect them in the IAM console or via
`aws iam get-policy-version`. The comparison above uses only the
documented, recommended permissions from the EKS user guide.

## Implementation in this project

The module attaches:

- **Managed:** `AmazonEKSCapabilityArgoCD`
- **Core integrations (always):** EKS (DescribeCluster, ListClusters,
  DescribeUpdate, ListUpdates), Secrets Manager (GetSecretValue,
  DescribeSecret, ListSecrets), CodeConnections (UseConnection, GetConnection,
  ListConnections), KMS (Decrypt, DescribeKey)
- **Supplemental (optional):** ECR when `enable_ecr_access` is true; CodeCommit
  when `enable_codecommit_access` is true

This avoids AccessDenied from missing permissions regardless of the managed
policy contents.

## Recommendations

1. **Least privilege:** Use the IAM policy variables to scope resources (e.g.
   `iam_policy_secrets_manager_resources`, `iam_policy_code_connections_resources`)
   instead of `["*"]` where possible.
2. **ECR:** Set `enable_ecr_access = true` (and pass it from the root module)
   if Argo CD pulls from ECR.

## References

- [Amazon EKS capability IAM role](https://docs.aws.amazon.com/eks/latest/userguide/capability-role.html)
- [Argo CD considerations - Permissions](https://docs.aws.amazon.com/eks/latest/userguide/argocd-considerations.html)
- [Configure Argo CD permissions - AWS service permissions](https://docs.aws.amazon.com/eks/latest/userguide/argocd-permissions.html)
- [Connect to Git repositories with AWS CodeConnections](https://docs.aws.amazon.com/eks/latest/userguide/integration-codeconnections.html)
