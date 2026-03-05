# CREATE DRAW.IO ARCHITECTURE DIAGRAMS - LDAP 2FA ON EKS AUTO MODE

Use this document as the **user prompt** when generating architecture diagrams
for this project. The output is **one unified architectural diagram** rendered in
multiple formats (`.png`, `.dot`, `.drawio`) as specified in `AGENT.md`. The
diagram must look like professional AWS/EKS documentation: clear account/VPC/EKS
boundaries, AWS-style components, labeled data/control flows, and consistent
grouping by tier.

The agent has system-level rules in `AGENT.md`. This prompt complements those
by specifying **what to draw** and **how to lay it out** for this repository.

## SCENARIO

Produce **one unified architectural diagram** for **ldap-2fa-on-k8s**, which
deploys an LDAP identity solution with 2FA on **AWS EKS Auto Mode** using a
strict, layered Terraform deployment model and GitOps. The same diagram is
output in the formats required by `AGENT.md` (e.g. under
`docs/architecture-diagrams/diagrams/`).

The diagrams must reflect **all four Terraform layers** (separate roots,
separate states, strict ordering):

- **Layer 1 - `tf_backend_state` (Account A - State)**: S3 backend for Terraform
  state with locking, encryption, and access controls.
- **Layer 2 - `backend_infra` (Account B - Deployment)**: VPC, subnets, NAT/IGW,
  EKS Auto Mode, IRSA/OIDC, VPC endpoints, ECR.
- **Layer 3 - `application_infra` (Account B - Deployment)**: Single ALB via EKS
  Auto Mode ingress (IngressClass/IngressClassParams), OpenLDAP stack
  (OpenLDAP + phpLDAPadmin + LTB-passwd), StorageClass (EBS CSI), ArgoCD EKS
  capability, Route53 records.
- **Layer 4 - `application` (Account B - Deployment)**: 2FA app (frontend +
  backend), PostgreSQL, Redis, SES, SNS (SMS), ArgoCD Applications (GitOps
  for backend/frontend).

CI/CD: **GitHub Actions (OIDC)** runs Terraform per layer; no long-lived AWS keys.
GitOps: ArgoCD (AWS EKS managed capability) reconciles Helm releases for the 2FA
backend and frontend.

## ACCOUNT MODEL

Show two top-level account boundaries in the diagram.

**Account A (State Account)**:

- Terraform state backend (S3) and locking model (file-based; no DynamoDB in this
  design).
- AWS Secrets Manager secrets used by automation (e.g., GitHub role info,
  ExternalId, tf-vars).
- Route53 hosted zone and DNS records (including ACM validation records).
- GitHub Actions OIDC integration role (or equivalent runner role).

**Account B (Deployment Account)**:

- VPC, EKS Auto Mode, ECR, ALB (via EKS Auto Mode ingress integration).
- ACM certificates (same account/region as ALB).
- OpenLDAP stack and 2FA app workloads.
- Optional: separate Deployment Accounts for `dev` and `prod` as siblings.

**Cross-account trust (show explicitly)**:

- GitHub Actions OIDC -> Account A role.
- Terraform assumes into Account B role (ExternalId-protected).

## PREREQUISITES (PRE-EXISTING ELEMENTS)

Include these explicitly; they exist before any Terraform run:

- **Registered domain** - base domain (e.g., `talo-ldap.com`).
- **Route53 public hosted zone** - in **Account A**:
  - DNS resolution; holds ACM DNS validation records (CNAMEs).
  - A/ALIAS records to the ALB for: `phpldapadmin.<domain>`, `passwd.<domain>`,
    `app.<domain>`, (optional) `argocd.<domain>`.
  - If domain is registered externally, show delegation via NS records.
- **ACM certificate** - in **Account B** (same region as ALB):
  - Covers required FQDNs (wildcard or explicit SANs); validated via Route53 in
    Account A; used for TLS termination on the ALB (HTTPS 443).
- **GitHub OIDC provider** - in Account A (or the account that owns the
  runner role).
- **IAM role for GitHub Actions** - in Account A; assumed via OIDC.
- **IAM deployment role(s)** - in Account B (dev/prod), trusted by Account A
  automation role; protected by ExternalId.

## COMPONENTS TO INCLUDE

Group components logically. Use AWS icons for AWS resources and Kubernetes
icons for in-cluster components.

### CI/CD and identity

- GitHub repository, GitHub Actions, OIDC trust (GitHub -> AWS).
- Account A runner role (state/DNS/secrets).
- Cross-account assume-role to Account B deployment role (ExternalId).
- Terraform per layer; ArgoCD (AWS EKS capability) and ArgoCD Applications.

### DNS and TLS (cross-account)

**Account A**: Registered domain, Route53 public hosted zone; DNS records
(A/ALIAS): `phpldapadmin.<domain>`, `passwd.<domain>`, `app.<domain>`,
(optional) `argocd.<domain>`; ACM validation records (CNAMEs).

**Account B**: ACM certificate (same region as ALB); ALB configured for HTTPS
with ACM cert.

### Network (Account B)

- VPC boundary; public subnets (>=2 AZs): ALB, IGW, NAT Gateway; private
  subnets (>=2 AZs): EKS workloads.
- Route tables (public/private); security groups (ALB inbound 443, workload
  ingress from ALB, database/caches restricted to backend namespace).
- VPC endpoints: STS (IRSA), SSM (node management), ECR (api + dkr) if used,
  SNS if SMS is designed without public egress, (optional) CloudWatch Logs.

### Kubernetes (Account B)

- EKS Auto Mode cluster boundary; EKS Auto Mode ALB integration (IngressClass,
  IngressClassParams; single ALB via shared group semantics).
- Namespaces: `ldap` (OpenLDAP stack), `2fa-app` (or app namespace used in repo),
  `argocd` (GitOps control plane).
- EBS CSI (StorageClass), NetworkPolicies (namespace isolation), IRSA roles for
  backend (SNS/SES).

### Application dependencies (Account B)

- **OpenLDAP stack**: OpenLDAP (StatefulSet + PVC), phpLDAPadmin (UI),
  LTB-passwd (UI).
- **2FA application**: Frontend (static HTML/JS/CSS behind nginx), Backend
  (FastAPI).
- **Data plane**: PostgreSQL (user/profile/admin), Redis (OTP + challenge cache).
- **Messaging**: SES (email verification), SNS (SMS OTP).

## CONNECTIONS TO SHOW

Use arrows and label important flows (protocol/port/mechanism). Keep
**control-plane** flows visually distinct from **data-plane** flows.

### User traffic (data plane) - single ALB

Show **one ALB** with routing explicit:

- Users -> Route53 -> ALB (HTTPS 443, TLS via ACM).
- ALB host-based routes: `phpldapadmin.<domain>` -> phpLDAPadmin;
  `passwd.<domain>` -> LTB-passwd; (optional) `argocd.<domain>` -> ArgoCD UI.
- App routing (single domain, path-based): `https://app.<domain>/` -> frontend
  Ingress -> frontend Service -> frontend Pods; `https://app.<domain>/api/*` ->
  backend Ingress -> backend Service -> backend Pods.

### Internal service communication (cluster-internal only)

- Backend -> OpenLDAP (LDAP/LDAPS as implemented; **LDAP must not be
  internet-exposed**).
- Backend -> PostgreSQL; Backend -> Redis.
- Backend -> SNS (SMS) and Backend -> SES (email) via IRSA.
- Frontend is public but reaches backend only via ALB path routing (`/api/*`).

### CI/CD and GitOps (control plane)

- GitHub Actions -> AWS (OIDC) -> Account A role -> Terraform layer runs.
- Terraform reads/writes state in Account A S3 backend; assumes Account B
  deployment role (ExternalId).
- ArgoCD (AWS EKS capability) -> Kubernetes API reconciliation; ArgoCD
  Applications -> Helm releases for 2FA frontend and 2FA backend.

## UNIFIED DIAGRAM CONTENT

The **one diagram** must span the full system and include:

- **Runtime topology**: End-to-end request flows (web and CLI); single ALB with
  host-based and path-based routing; OpenLDAP stack + 2FA app + PostgreSQL +
  Redis + SES/SNS; explicit note that LDAP is not exposed externally.
- **Network**: VPC/subnet topology, IGW/NAT, EKS in private subnets, ALB in
  public subnets; VPC endpoints and traffic direction; private egress for AWS
  APIs (STS/SSM/SNS/ECR) where applicable.
- **Delivery**: GitHub Actions OIDC -> Account A -> assume-role -> Account B;
  Terraform layer execution order; image build/push to ECR if present; ArgoCD
  EKS capability and ArgoCD Applications -> cluster reconciliation.
- **Layer dependencies**: Four Terraform roots as a clear flow
  (`tf_backend_state` -> `backend_infra` -> `application_infra` -> `application`)
  with brief responsibility per layer and contracts (remote state outputs,
  DNS/ACM prerequisites, cross-account ownership).

Output this single diagram in the formats required by `AGENT.md` (e.g. `.png`,
`.dot`, `.drawio` under `docs/architecture-diagrams/diagrams/`). Do not produce
separate diagram files per view or per Terraform layer.

## LAYOUT

- Top-level split: **Account A (State)** | **Account B (Deployment)**.
- Top row: Users and GitHub Actions.
- DNS/TLS near top: Route53 (A), ACM (B), with validation records flow.
- Center: Deployment account VPC with public subnets (ALB) and private subnets
  (EKS).
- Inside EKS: namespaces grouped; OpenLDAP stack and 2FA app clearly separated.
- Right/bottom: data/services (PostgreSQL/Redis) and messaging (SES/SNS).

### Tier colors (AWS-style)

- **Edge (DNS/ALB):** light blue.
- **Platform (EKS/add-ons):** light green.
- **Data (PostgreSQL/Redis):** light orange.
- **Security/config (IAM, Secrets):** light purple.
- **CI/CD (GitHub, Terraform, ArgoCD):** light gray.

## DIAGRAM REQUIREMENTS

- Use AWS icons for AWS services and Kubernetes icons for in-cluster components.
- Use repository terminology: layer names (`tf_backend_state`, `backend_infra`,
  `application_infra`, `application`); EKS Auto Mode ALB integration
  (IngressClass/IngressClassParams); single-ALB rule grouping; app routing
  `app.<domain>/` and `app.<domain>/api/*`.
- Label key connections (HTTPS 443, OIDC, assume-role + ExternalId, IRSA,
  DB/cache ports as relevant).
- Do **not** include secret values (no passwords, tokens, ExternalId strings,
  access keys).
- Do not expand every Terraform variable/output; show only architecturally
  meaningful values and flows.
- **LDAP must never appear as an internet-facing service.**

## AUTHORITATIVE REFERENCES

Use these sources (in this order) to resolve details:

1. `AGENT.md` (in this directory; system rules and output expectations).
2. `docs/architecture/ARCHITECTURE.md` (solution architecture and layer
   responsibilities).
3. `WARP.md` (repo root; invariants, gotchas, ALB routing rules, ordering).
4. `repomix_output.md` (directory tree, key file locations).
5. Per-layer READMEs and modules (exact names and boundaries).

If something is ambiguous, add a callout: `ASSUMPTION: ...` and reference the
file/path that would confirm the detail.

## INVARIANTS CHECKLIST

Before finalizing, ensure the diagram reflects:

- **Multi-account**: Account A holds state/DNS/secrets; Account B holds
  VPC/EKS/ECR/ACM/ALB and workloads.
- **Single ALB**: One ALB; host-based routing for phpldapadmin, passwd,
  (optional) argocd; path-based routing for `app.<domain>/` and
  `app.<domain>/api/*`.
- **Internal-only**: Backend -> OpenLDAP, PostgreSQL, Redis, SNS/SES (IRSA);
  LDAP never internet-exposed; frontend reaches backend only via ALB `/api/*`.
