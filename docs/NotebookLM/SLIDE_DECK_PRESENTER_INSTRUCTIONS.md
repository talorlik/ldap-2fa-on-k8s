# Slide Deck Instructions (Presenter Deck)

Generate a **10-slide minimalist presenter deck** for a **15-minute technical deep-dive**
on **LDAP-2FA on Kubernetes (EKS)**. All content must be grounded in this project's
Markdown documentation.

## Objective

Walk the audience from problem and solution through the four-layer deployment,
EKS Auto Mode and LDAP stack, cross-account state/DNS/ACM, GitOps and the 2FA app,
and end-state-emphasizing **why** decisions were made, not just what was built.

## Visual Theme

**Futuristic Minimalist:** Black/dark slate backgrounds; neon blue/cyan or gold
accents. Abstract visuals (clusters, keys, network flows). Minimal text per slide;
visuals support the speaker.

## Per-Slide Requirements

1. **Visual Focus** - One core diagram or concept.
2. **Minimalist Text** - At least 5 short bullets (scannable).
3. **Speaker Script** - 2-3 sentences the presenter can say aloud.

## Mandatory Categories (~10 Slides)

**1. Problem and Solution** - Need: centralized identity with LDAP, two-factor
authentication (TOTP and SMS), self-service registration and password management,
and full automation on Kubernetes. Solution: OpenLDAP stack (PhpLdapAdmin,
LTB-passwd) plus a 2FA app (FastAPI backend, static frontend) on EKS via Terraform,
with GitOps (ArgoCD), IRSA, and cross-account state/DNS. *Why* LDAP + 2FA on EKS
with layered IaC.

**2. Golden Path Deployment** - Order: 00-tfstate_infra (State Account) then
01-backend_infra, 02-application_infra, 04-application (Deployment Account).
Each layer = standalone Terraform root, own state key; **terraform_remote_state**
passes outputs between layers. Teardown = reverse order (04 to 00) with
confirmation. *Why* layers and remote_state: clear dependencies, single state
backend, safe teardown.

**3. EKS Auto Mode, ALB, and LDAP Stack** - EKS Auto Mode (managed compute).
Single ALB created by Kubernetes Ingress; host-based routing to 2FA app,
PhpLdapAdmin, LTB-passwd. Application infra: OpenLDAP (HA, multi-master),
StorageClass (EBS), ArgoCD (AWS EKS capability). *Why* one ALB and Ingress as
source of truth; LDAP stack before app layer.

**4. Cross-Account: State vs Deployment** - **State Account:** Terraform state
(S3), Secrets Manager (github-role, tf-vars, external-id), Route53 hosted zone
and DNS records (including ACM validation CNAMEs). **Deployment Account:** EKS,
VPC, ALB, ACM certificate, ECR, application. GitHub Actions OIDC assumes State
role; Terraform assumes Deployment role (ExternalId). ACM requested in Deployment
account; validation CNAMEs created in State Route53. *Why* state and DNS
centralized; certificate in same account as ALB for EKS Auto Mode.

**5. GitOps and 2FA Application** - ArgoCD in application_infra; application
layer creates ArgoCD Applications for 2FA backend and frontend (Helm). Flow: Repo
to GitHub Actions (OIDC) to Terraform; ArgoCD syncs apps; Ingress drives ALB.
2FA app: PostgreSQL (registration/tokens), Redis (SMS OTP), SES (email), SNS (SMS).
IRSA for backend (SES, SNS). *Why* GitOps as source of truth; no secrets in
code/state; workload identity via IRSA.

**6. Conclusion - End-State and Ops** - End-state: LDAP + 2FA UIs at FQDN over
HTTPS (ACM); single ALB; OpenLDAP, PhpLdapAdmin, LTB-passwd, 2FA backend/frontend.
Secrets in Secrets Manager; IRSA and VPC endpoints for private access. Teardown:
04 to 00 with confirmation. *Why* "done" looks like this; how to teardown safely.

## Narrative Focus (Why)

- **Four layers + remote_state:** Clear order, single state backend in State
Account, outputs consumed by downstream layers, safe teardown.
- **Cross-account split:** State holds state and DNS; Deployment holds compute
and ACM; ALB and cert in same account for EKS Auto Mode.
- **Single ALB + Ingress:** One entry point, host-based routing, fewer moving
parts.
- **GitOps + IRSA + Secrets Manager:** Repo as source of truth; no secrets in
code/state; workload identity for SES/SNS.
- **VPC endpoints:** Less NAT, better security/cost for private subnets.

## Data Grounding

**All content must come from this project's docs.** Source of truth:
`docs/architecture/ARCHITECTURE.md`; `docs/auxiliary/`; `READMEs` (root, layer,
and application backend/frontend); `WARP.md` (gotchas, invariants, naming,
routing rules); `repomix_output.md` (packed repo structure and key files).
Do not add or contradict details from these documents.

**Important:** Base the entire deck on this documentation. Slide count, categories,
and narrative must align with the LDAP-2FA-on-EKS architecture, four-layer
deployment, cross-account model, and operational procedures in the cited files.
