# FLASHCARDS BULLET LIST INSTRUCTIONS

## Architecture & deployment

- Three-tier deployment order (tfstate → backend_infra → application_infra → application)
- Multi-account split: State Account vs Deployment Account
- What lives in Account A (state, secrets, Route53) vs Account B (EKS, ALB, ACM,
workloads)
- Destroy order (application → application_infra → backend_infra → tfstate)
- EKS Auto Mode and what it provides (ALB, node provisioning, EBS CSI)
- GitOps with ArgoCD (AWS managed) and how apps are deployed from Git

## AWS & infrastructure

- IRSA (IAM Roles for Service Accounts) and why pods use it instead of access keys
- VPC: public/private subnets and multi-AZ
- VPC endpoints (SSM, STS, SNS) and private AWS access
- ACM: public certs, DNS validation, CNAME in Account A for cert in Account B
- Route53: hosted zone in State Account; A/alias records for ALB
- ECR: image mirroring from Docker Hub; tags (e.g. openldap-1.5.0, redis-latest)
- ALB: host-based routing for 2FA app, PhpLdapAdmin, LTB-passwd
- EBS StorageClass and persistent volumes for LDAP and app data

## LDAP & OpenLDAP

- OpenLDAP stack HA and multi-master replication
- PhpLdapAdmin: LDAP admin UI
- LTB-passwd: self-service password management
- LDAP: cluster-internal only (ClusterIP), not exposed to internet
- OpenLDAP admin vs config password and where they’re stored
- LDAP integration in the 2FA app for centralized auth

## 2FA application

- TOTP (authenticator apps) vs SMS (AWS SNS) and when each is used
- Self-service registration: email + phone verification
- User profile states: PENDING → COMPLETE → ACTIVE
- Backend: Python FastAPI; frontend: static HTML/JS/CSS + nginx
- PostgreSQL: user registration and verification tokens
- Redis: SMS OTP storage with TTL
- AWS SES: email verification and notifications
- AWS SNS: SMS 2FA; SMS sandbox and sender ID requirements
- Admin dashboard: user management, group CRUD, approval workflows
- Profile changes: email (verification link), phone (SMS code), password (authenticated)
- API docs: `/api/docs` (Swagger), `/api/redoc`, `/api/openapi.json`
- Backend startup: DB retries (e.g. 3 × 5s) for PostgreSQL

## Security

- GitHub OIDC (no long-lived AWS keys) for Actions
- ExternalId for cross-account role assumption
- Bidirectional trust: State Account role and deployment account roles
- Network policies: which ports (e.g. 443, 636, 8443) for pod-to-pod
- TLS termination at ALB with ACM
- Secrets: GitHub Secrets vs AWS Secrets Manager (local); required vs optional
- Required secrets: state/deployment role ARNs, ExternalId, OpenLDAP, PostgreSQL,
Redis, GH_TOKEN
- Admin seed: optional one-time job for first admin (ADMIN_SEED_* vars)

## Terraform & CI/CD

- Terraform backend: S3 in State Account; file-based locking
- Backend config: `backend.hcl` from template (gitignored); `tfstate-backend-values-template.hcl`
- Workspaces: naming (e.g. `region-environment`: us-east-1-prod, us-east-2-dev)
- Provider: backend uses State Account; AWS provider assumes Deployment Account
role
- GitHub Actions workflows: 00 (tfstate), 01 (backend_infra), 02 (application_infra),
03 (build), 04 (application)
- Build workflows: backend and frontend build/push must run before application deploy
- Destroy workflows: require typing "yes" and optionally "DESTROY"

## Scripts & operations

- `set-state.sh` / `get-state.sh`: tfstate in State Account
- `setup-backend.sh`, `setup-application-infra.sh`, `setup-application.sh`:
prompts for region/env, secrets, Terraform
- `assume-github-role.sh`: assume State/Dev/Prod roles
- `get-eks-token.sh`: EKS token for Terraform Kubernetes/Helm exec plugin
- `mirror-images-to-ecr.sh`: Docker Hub → ECR (OpenLDAP, Redis, PostgreSQL)
- `set-k8s-env.sh`: kubeconfig and cluster env from backend_infra state
- Layer-specific `monitor-deployments.sh`: backend_infra, application_infra, application
- ECR repository name saved to GitHub variable `ECR_REPOSITORY_NAME` by backend_infra
setup

## Prerequisites & configuration

- Route53 hosted zone in State Account before deploy
- ACM certificate in Deployment Account, validated, same region as EKS
- SNS SMS: sandbox (verified numbers) vs production; sender ID setup
- Docker and jq for local runs (image mirroring, parsing)
- GitHub repo config: OIDC provider URL, audience, trust condition (`repo:org/repo:*`)

## Helm & Kubernetes

- Helm release safety: rollbacks, readiness checks
- Application Helm charts: ldap-2fa-backend, ldap-2fa-frontend
- Vendored chart: openldap-stack-ha (e.g. 5.0.0)
- Image sources: ECR only (no Docker Hub in cluster) to avoid rate limits

## Troubleshooting & docs

- Troubleshooting index: deployment, LDAP/admin-seed, application layer, frontend,
cross-account/DNS, secrets, state, debug commands
- Kubeconfig auto-update to avoid stale EKS endpoints
- PRDs: 2FA app, signup, admin, SMS OTP, OpenLDAP, ALB, ArgoCD, domain
- Guides: cross-account ACM, SMS sandbox, sender ID, security improvements,
password/MFA flow
