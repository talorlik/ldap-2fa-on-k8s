# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this
repository.

## WARP.md Maintenance Rules

**IMPORTANT — enforce these rules when updating this file:**

- **Maximum size**: 400 lines. If an update would exceed this limit, trim or
  consolidate existing content before adding new content.
- **No changelogs**: Do NOT add changelog entries here. Use the per-layer
  `CHANGELOG.md` files (`CHANGELOG.md`, `backend_infra/CHANGELOG.md`,
  `application_infra/CHANGELOG.md`, `application/CHANGELOG.md`).
- **No command references**: Do NOT duplicate setup/deploy/destroy commands.
  Those live in per-layer `README.md` files and setup scripts.
- **No exhaustive file listings**: Do NOT list every file in a directory or
  every Terraform output. The agent can read `outputs.tf`, `variables.tf`, and
  directory contents on demand.
- **No workflow details**: Do NOT describe each GitHub Actions workflow step.
  Workflow files are self-documenting.
- **What belongs here**: Project overview, directory tree, architectural
  patterns the agent cannot infer, critical gotchas, security rules, deployment
  ordering, and naming conventions.
- **Prefer pointers over content**: Reference docs by path (e.g., "see
  `docs/auxiliary/reference/SECRETS_REQUIREMENTS.md`") instead of duplicating
  their content.

## Project Overview

This repository deploys LDAP authentication with 2FA on Kubernetes (EKS Auto
Mode) using Terraform. The infrastructure is deployed on AWS using a
**multi-account architecture** with four deployment layers:

1. **Terraform Backend State** (`tf_backend_state/`) — S3 bucket for storing
   Terraform state (Account A — State Account)
2. **Backend Infrastructure** (`backend_infra/`) — VPC, EKS with IRSA, VPC
   endpoints, ECR (Account B — Deployment Account)
3. **Application Infrastructure** (`application_infra/`) — OpenLDAP, ALB,
   ArgoCD Capability, StorageClass, Route53 records (Account B)
4. **Application** (`application/`) — 2FA app (backend + frontend), PostgreSQL,
   Redis, SES, SNS, ArgoCD Applications (Account B)

### Multi-Account Architecture

- **Account A (State Account)**: Terraform state (S3), AWS Secrets Manager
  secrets (`github-role`, `tf-vars`, `external-id`), Route53 hosted zone and
  DNS records.
- **Account B (Deployment Account(s))**: All infrastructure and ACM
  certificates. Separate accounts for prod/dev (optional).
- GitHub Actions uses OIDC → Account A role for state operations.
- Terraform `assume_role` → Account B role (prod or dev) with ExternalId.
- `aws.state_account` provider → Account A role for Route53 (no ExternalId).
- See `docs/auxiliary/reference/SECRETS_REQUIREMENTS.md` for secrets setup.
- See `docs/auxiliary/application_infra/guides/CROSS_ACCOUNT_ACCESS.md` for
  cross-account and ACM certificate details.

## Project Directory Structure

```
ldap-2fa-on-k8s/
├── .github/workflows/           # 00- through 04- prefixed workflows
├── application_infra/           # Phase 3: OpenLDAP, ALB, ArgoCD, StorageClass
│   ├── charts/openldap-stack-ha/  # Vendored OpenLDAP chart (v5.0.0)
│   ├── helm/openldap-values.tpl.yaml
│   ├── modules/                 # alb, argocd, cert-manager, network-policies,
│   │                            # openldap, route53, route53_record
│   ├── setup-application-infra.sh
│   └── destroy-application-infra.sh
├── application/                 # Phase 4: 2FA app + dependencies
│   ├── backend/                 # Python FastAPI (src/, helm/, Dockerfile)
│   ├── frontend/                # HTML/JS/CSS + nginx (src/, helm/, Dockerfile)
│   ├── helm/                    # postgresql-values.tpl.yaml, redis-values.tpl.yaml
│   ├── modules/                 # argocd_app, postgresql, redis, ses, sns
│   ├── setup-application.sh
│   └── destroy-application.sh
├── backend_infra/               # Phase 2: VPC, EKS, ECR, VPC endpoints
│   ├── modules/                 # ecr, endpoints, ebs
│   ├── setup-backend.sh
│   └── destroy-backend.sh
├── tf_backend_state/            # Phase 1: S3 state bucket
│   ├── set-state.sh
│   └── get-state.sh
├── scripts/                     # Shared scripts
│   ├── assume-github-role.sh    # AWS role switching (must be sourced)
│   ├── get-eks-token.sh         # EKS token exec plugin for Terraform
│   ├── mirror-images-to-ecr.sh  # Docker Hub → ECR mirroring
│   ├── set-k8s-env.sh           # K8s env setup
│   └── capture-openldap-logs.sh # Pod log capture before rollback
├── docs/auxiliary/              # PRDs, guides, troubleshooting, schema docs
├── WARP.md
└── README.md
```

Each layer has its own `README.md`, `CHANGELOG.md`, `variables.tf`,
`variables.tfvars`, `providers.tf`, `main.tf`, `outputs.tf`, and
`backend.hcl` (generated, gitignored).

## Deployment Order (Critical)

Deployment order matters — always deploy in this order:

1. `tf_backend_state/` → S3 bucket
2. `backend_infra/` → VPC → EKS → VPC Endpoints → ECR
3. `application_infra/` → Route53/ACM lookup → ArgoCD (if enabled) →
   StorageClass → ALB module → OpenLDAP → Route53 records → Network policies
4. `application/` → PostgreSQL → Redis → SES → SNS → 2FA Helm releases →
   Route53 record → ArgoCD Applications

**Destroy in reverse order.** All destroy scripts require double confirmation
(`yes` then `DESTROY`).

## Naming Conventions

- **Resources**: `${prefix}-${region}-${name}-${env}`
- **Workspaces**: `${region}-${env}` (e.g., `us-east-1-prod`)
- **State keys**:
  - backend_infra: `BACKEND_PREFIX` repo variable
  - application_infra: `application_infra_state/terraform.tfstate`
  - application: `application_state/terraform.tfstate`

## Critical Gotchas

### OpenLDAP Environment Variables (MUST READ)

The jp-gouin/helm-openldap chart does **NOT** properly pass
`global.ldapDomain` to the osixia/openldap container. You **must** explicitly
set these in the `env:` section of Helm values:

- `LDAP_DOMAIN` — e.g., `ldap.talorlik.internal`
- `LDAP_ADMIN_PASSWORD`
- `LDAP_CONFIG_PASSWORD` (NOT `LDAP_CONFIG_ADMIN_PASSWORD` — osixia image uses
  `LDAP_CONFIG_PASSWORD`)

Without `LDAP_DOMAIN`, OpenLDAP initializes with empty/default config and
authentication fails. If auth fails after deployment, delete PVCs and restart
pods to reinitialize.

### OpenLDAP Chart Details

- Chart v5.0.0 vendored at `application_infra/charts/openldap-stack-ha/`
- Uses osixia/openldap:1.5.0 (chart's default bitnami image doesn't exist)
- Custom LDIF volume mounted read-only at `/tmp/custom-ldif-files`; container
  copies to bootstrap dir before startup (avoids osixia cleanup conflict)
- `customLdifFiles` creates `ou=users`, `ou=groups`, `cn=admins` on all pods
- See `application_infra/OPENLDAP_CHANGELOG.md` for chart change history

### LDAP Admin Password Consistency

`ldap-admin-secret` in backend namespace (`2fa-app`) reads password from
OpenLDAP secret (`openldap-secret`) in `ldap` namespace via Kubernetes API.
Falls back to `TF_VAR_OPENLDAP_ADMIN_PASSWORD` if secret doesn't exist. This
prevents password mismatches between layers.

### ECR Image Mirroring

All third-party images are mirrored to ECR to eliminate Docker Hub rate limits:

- `osixia/openldap:1.5.0` → `openldap-1.5.0`
- `bitnami/redis:8.4.0-debian-12-r6` → `redis-latest`
- `bitnami/postgresql:18.1.0-debian-12-r4` → `postgresql-latest`
- `osixia/phpldapadmin:0.9.0` → `phpldapadmin-0.9.0`
- `ltbproject/self-service-password:5.2.3` → `ltb-passwd-5.2.3`
- `busybox:1.36` → `busybox-1.36` (OpenLDAP init container)

Mirroring is automatic via `setup-application-infra.sh` and idempotent (skips
existing images).

### EKS Token Exec Plugin

Terraform providers use `scripts/get-eks-token.sh` as an exec plugin for fresh
EKS tokens on every API call. This prevents token expiration during long Helm
operations (20+ minute timeouts).

### StorageClass

- Volume binding mode: `WaitForFirstConsumer` (PVCs stay Pending until pod
  scheduled — normal for EKS Auto Mode)
- Provisioner: `ebs.csi.eks.amazonaws.com` (built-in to EKS Auto Mode)

### Redis Is Required

Redis is mandatory for all login challenge and SMS OTP storage. There is **no
in-memory fallback**. Endpoints return 503 when Redis is down.

## ALB Architecture

- Uses EKS Auto Mode ALB controller (`eks.amazonaws.com/alb`), NOT AWS Load
  Balancer Controller
- **IngressClassParams** (cluster-wide): `scheme`, `ipAddressType`,
  `group.name`, `certificateARNs` — set once, inherited by all Ingresses
- **Per-Ingress annotations**: `load-balancer-name`, `target-type`,
  `listen-ports`, `ssl-redirect`
- All Ingresses share **one ALB** via `group.name` with host-based routing:
  - `phpldapadmin.<domain>` → phpLDAPadmin
  - `passwd.<domain>` → LTB-passwd
  - `app.<domain>/` → 2FA frontend
  - `app.<domain>/api/*` → 2FA backend
- EKS Auto Mode IngressClassParams does NOT support subnets, security groups,
  or tags (unlike AWS LB Controller)

## 2FA Application Architecture

- **Backend**: Python FastAPI — LDAP auth, TOTP + SMS MFA, signup with
  email/phone verification, admin dashboard, profile management
- **Frontend**: Static HTML/JS/CSS served by nginx (port 8080, non-root user)
- **Deployment**: Direct Helm via Terraform (default) or ArgoCD GitOps
  (`enable_argocd_apps = true`)
- **Dependencies**: PostgreSQL (user data), Redis (OTP/challenge cache),
  SES (email), SNS (SMS, optional)
- Image tags are commit-based (no `:latest`), extracted from Helm values files
  by setup scripts
- API docs always available at `/api/docs` (Swagger) and `/api/redoc`
- See `application/backend/README.md` and `application/frontend/README.md`

## Security Rules

- **Never commit** `backend.hcl`, `terraform.tfstate`, or passwords
- **ExternalId** required for all deployment account role assumptions (prevents
  confused deputy attacks). Generated via `openssl rand -hex 32`.
- All EKS nodes are in private subnets; VPC endpoints for SSM/STS/SNS
- LDAP service is ClusterIP only (not exposed externally)
- Passwords stored in Kubernetes secrets, never plain-text in Helm values
- Containers run as non-root (frontend: `appuser` UID 1000; backend:
  multi-stage minimal image)
- Network policies restrict pod-to-pod communication to ports 389, 443, 636,
  8443
- Run Snyk security scans for new first-party code before committing
- LDAP queries use `escape_filter_chars()` and `escape_rdn()` to prevent
  injection
- Phone numbers masked in logs (SHA-256 hash); connection strings redacted

## Key Documentation Pointers

Instead of duplicating content, refer to these files when you need details:

- **Secrets setup**: `docs/auxiliary/reference/SECRETS_REQUIREMENTS.md`
- **Password flow**: `docs/auxiliary/application/guides/PASSWORD_FLOW.md`
- **Secret dependencies**: `docs/auxiliary/application/guides/SECRET_DEPENDENCIES.md`
- **Database schema**: `docs/auxiliary/application/databases/SCHEMA.md`
- **Cross-account access**: `docs/auxiliary/application_infra/guides/CROSS_ACCOUNT_ACCESS.md`
- **ALB design**: `docs/auxiliary/application_infra/design/PRD_ALB.md`
- **OpenLDAP guide**: `docs/auxiliary/application_infra/guides/OPENLDAP_README.md`
- **Troubleshooting index**: `docs/auxiliary/troubleshooting/INDEX.md`
- **LDAP troubleshooting**: `docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED_TROUBLESHOOTING.md`
- **ArgoCD design**: `docs/auxiliary/application_infra/design/PRD_ArgoCD.md`
- **Signup PRD**: `docs/auxiliary/application/design/PRD_SIGNUP_MAN.md`
- **2FA App PRD**: `docs/auxiliary/application/design/PRD_2FA_APP.md`
- **Redis enablement**: `docs/auxiliary/application/guides/REDIS_ENABLEMENT_SUMMARY.md`

## GitHub Secrets and Variables Summary

**Secrets** (see `SECRETS_REQUIREMENTS.md` for full details):
`AWS_STATE_ACCOUNT_ROLE_ARN`, `AWS_PRODUCTION_ACCOUNT_ROLE_ARN`,
`AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN`, `AWS_ASSUME_EXTERNAL_ID`, `GH_TOKEN`,
`TF_VAR_OPENLDAP_ADMIN_PASSWORD`, `TF_VAR_OPENLDAP_CONFIG_PASSWORD`,
`TF_VAR_POSTGRESQL_PASSWORD`, `TF_VAR_REDIS_PASSWORD`, plus optional
`ADMIN_SEED_*` secrets.

**Variables**: `AWS_REGION`, `BACKEND_PREFIX`, `BACKEND_BUCKET_NAME` (auto),
`APPLICATION_INFRA_PREFIX`, `APPLICATION_PREFIX`, `ECR_REPOSITORY_NAME` (auto).

## Enabling SMS 2FA

1. `enable_sts_endpoint = true` + `enable_sns_endpoint = true` in
   `backend_infra/variables.tfvars`
2. Deploy backend_infra
3. `enable_sms_2fa = true` in `application/variables.tfvars`
4. Deploy application — backend auto-detects SNS and enables SMS MFA
