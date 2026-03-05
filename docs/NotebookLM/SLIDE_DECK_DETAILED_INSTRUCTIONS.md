# Slide Deck Instructions (Detailed)

Generate a **15-20 slide technical reference deck** for **LDAP 2FA on
Kubernetes (EKS)**. Self-contained for stakeholders reading without a
presenter.

## Objective

Lead with the **product purpose**: **LDAP for authentication + 2FA for
authorization** (centralized identity with a second factor). Then cover
architecture: four-layer Terraform, multi-account, EKS Auto Mode, GitOps,
state/persistence, and secrets/identity. Ground all content in this project's
Markdown docs.

## Visual Theme

**"Knowledge-Cloud Industrial."** Neon blue/cyan AWS icons; translucent 3D
EKS/GitOps elements; glowing security (shields, locks); dark slate backgrounds
with subtle grid/data-flow accents.

## Per-Slide Structure

1. **Clear title** (one line).
2. **3-5 technical bullets** (high information density).
3. **One key insight** sentence ("so what" for this slide).

## Mandatory Categories (All Seven)

### 1. Tiered Terraform Deployment

- **Four layers**, order: Layer 1 tf_backend_state (Account A) → Layer 2
  backend_infra → Layer 3 application_infra → Layer 4 application (Account B).
  Standalone roots, workspace-based state keys; **terraform_remote_state**
  only (no Parameter Store). Teardown: reverse order (4 → 3 → 2 → 1).
- **State:** S3 in Account A, versioning, encryption, file-based locking
  (no DynamoDB).

### 2. Multi-Account Security and DNS

- **Account A (State):** Terraform state bucket, Secrets Manager (e.g.
  github-role, tf-vars), Route53 hosted zone. **Account B (Deployment):** EKS,
  VPC, ALB, ACM, ECR, application workloads.
- **Roles:** State Account role (GitHub OIDC / local) for state and Route53;
  Deployment Account role for Terraform apply in Account B. Cross-account
  assume with ExternalId.
- **DNS:** Hosted zone in State Account; Route53 A/alias records (including
  ACM validation CNAMEs) created by layers 3 and 4 via State Account provider.
  **Insight:** ACM lives in Deployment Account (ALB and cert same account);
  DNS and state stay in State Account.

### 3. EKS Auto Mode, Ingress, ALB

- **EKS Auto Mode**; single ALB via IngressClass/Params; host-based routing
  (phpldapadmin, passwd, 2FA app). ACM in Deployment Account; DNS CNAMEs in
  State Account. **Insight:** Ingress drives ALB; Terraform reads ALB from
  application_infra remote state.

### 4. LDAP, 2FA, and User/Group Management

- **Core purpose:** LDAP = **authentication** (bind, credentials); 2FA =
  **authorization** (second factor before granting access). OpenLDAP stack
  (Layer 3) is identity source; 2FA app (Layer 4) enforces MFA at login.
- **Multiple 2FA options:** **TOTP** (authenticator apps, QR enrollment) and
  **SMS** (AWS SNS, verified phone). User chooses at enrollment; can add
  both; selects which method at each login.
- **User and group management:** Admin: user/group CRUD, user-group
  assignment, **approve/revoke** for signups. Self-service: profile,
  password change, email/phone change (verification link or SMS), MFA
  re-enrollment.
- **Redis TTL for SMS OTP:** SMS codes in Redis with **TTL-based expiration**
  (e.g. 5 min). No long-lived OTP storage. **Insight:** Identity in LDAP +
  PostgreSQL; transient OTP state in Redis only.

### 5. GitOps and Delivery Flow

- **ArgoCD:** AWS EKS Capability (application_infra); Layer 4 deploys 2FA
  backend and frontend via ArgoCD Applications (Helm); path-based routing
  (/ and /api). **Insight:** Terraform owns cluster/wiring; ArgoCD owns app
  manifest lifecycle.

### 6. State and Persistence

- **Terraform state:** S3 in Account A, workspace keys, file-based locking.
  **Inter-layer:** remote_state only (cluster, ECR, StorageClass, ArgoCD,
  ALB/IngressClass, LDAP connection). **In-cluster:** EBS StorageClass;
  PostgreSQL and Redis (Layer 4) on PVCs; OpenLDAP on PVCs. **Insight:** Redis
  holds SMS OTP codes with TTL; PostgreSQL holds user registration/verification
  and profile state.

### 7. Secrets and Identity

- **No secrets in code, logs, or state.** Secrets Manager (State Account for
  tf-vars, github-role); Terraform/workflows reference ARNs or assume roles.
- **GitHub Actions:** OIDC → State Account role for state/DNS; assume
  Deployment role for apply. No repo-stored AWS keys; role ARNs and
  ExternalId from secrets/variables.
- **EKS:** IRSA for 2FA backend (SES, SNS); LDAP/PostgreSQL credentials via
  K8s secrets from Terraform/Helm. **Insight:** Identity is role-based
  (OIDC, IRSA); cross-account limited to state and Route53 in State Account.

## Data Grounding

**All specs must match this project's docs:** `docs/architecture/ARCHITECTURE.md`,
`docs/auxiliary/`, `READMEs` (root, layer, and application backend/frontend),
`WARP.md` (gotchas, invariants, naming, routing rules), and
`repomix_output.md` (packed repo structure and key files).
Do not add or contradict details (four layers, remote_state,
LDAP+2FA flows, TOTP/SMS, Redis TTL, user/group/approve-revoke, host-based
routing, IRSA, etc.) from those files.
