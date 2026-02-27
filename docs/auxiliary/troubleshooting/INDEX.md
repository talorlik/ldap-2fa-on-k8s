# Troubleshooting Index

This index links to all troubleshooting documentation for the LDAP 2FA on
Kubernetes project. Documents are grouped by area.

## Table of Contents

- [Deployment and Infrastructure](#deployment-and-infrastructure)
- [LDAP and Seeding](#ldap-and-seeding)
- [Application Layer](#application-layer-2fa-app-data-stores-notifications)
- [Cross-Account, DNS, and Certificates](#cross-account-dns-and-certificates)
- [Secrets, Variables, and State](#secrets-variables-and-state)
- [Reference](#reference)
- [Module-Specific](#module-specific-troubleshooting)
- [Quick Links from Other Docs](#quick-links-from-other-docs)

## Deployment and Infrastructure

- [Application Infrastructure Deployment](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  ArgoCD and OpenLDAP deployment failures (GitHub Actions, Terraform, Helm,
  ECR, PVC, ALB, Karpenter).
- [Backend Infrastructure](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/backend_infrastructure/BACKEND_INFRASTRUCTURE.md)
  - EKS backend (cluster access, SSM, kubectl, IRSA, SNS).
- [EKS Access Entry](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application_infra/guides/EKS_ACCESS_ENTRY.md)
  - Add an access entry for your IAM user/role to an EKS cluster (create + associate
  policy or Kubernetes groups).

## LDAP and Seeding

- [LDAP and Admin-Seed](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED.md)
  - Admin-seed-job failures, LDAP directory structure, multi-master replication,
  group membership attributes, image tags.
- [LDAP and Admin-Seed Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED_TROUBLESHOOTING.md)
  Comprehensive troubleshooting guide (investigation, root causes, corrections).

## Application Layer (2FA App, Data Stores, Notifications)

- [Application Layer](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_layer/APPLICATION_LAYER.md)
  - 2FA backend/frontend, PostgreSQL, Redis, admin-seed, Ingress/ALB, SES, SNS,
  user registration.
- [Frontend](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/frontend/FRONTEND.md)
  - 2FA web UI (API calls, JWT, QR code, SMS, admin features, styles).

## Cross-Account, DNS, and Certificates

- [Cross-Account and DNS](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/cross_account_dns/CROSS_ACCOUNT_AND_DNS.md)
  - Route53, ACM certificates, ALB certificate placement, cross-account
  Terraform.

## Secrets, Variables, and State

- [Secrets and Variables](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/secrets_and_variables/SECRETS_AND_VARIABLES.md)
  - AWS Secrets Manager, GitHub Secrets, Terraform variable case sensitivity,
  PostgreSQL password flow.
- [Terraform State and Backend](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/secrets_and_variables/TERRAFORM_STATE.md)
  - S3 state backend, OIDC, GH_TOKEN, bucket policy.

## Reference

- [Debug Commands](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/reference/DEBUG_COMMANDS.md)
  - Copy-paste commands for OpenLDAP, ArgoCD, admin-seed-job, 2FA backend,
  EKS events/logs, Terraform state.

## Module-Specific Troubleshooting

For Terraform modules that have their own short troubleshooting sections:

- **Route53 record module:** See [Cross-Account and DNS](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/cross_account_dns/CROSS_ACCOUNT_AND_DNS.md)
  and the [route53_record README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/modules/route53_record/README.md#troubleshooting).
- **Network policies module:** See the [network-policies README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/modules/network-policies/README.md#troubleshooting).

## Quick Links from Other Docs

Where to find troubleshooting from elsewhere in the repo:

- **Main README:** [Troubleshooting section](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/README.md#troubleshooting)
  links to this index and to backend/application_infra READMEs.
- **Backend infra:** [backend_infra README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/backend_infra/README.md#troubleshooting)
  (short section); details in [Backend Infrastructure](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/backend_infrastructure/BACKEND_INFRASTRUCTURE.md).
- **Application infra:** [application_infra README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application_infra/README.md#troubleshooting)
  (short section); details in [Application Infrastructure Deployment](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  and [Application Layer](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_layer/APPLICATION_LAYER.md).
- **Application (2FA):** [application README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/README.md#troubleshooting)
  (short section); details in [Application Layer](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_layer/APPLICATION_LAYER.md)
  and [LDAP and Admin-Seed](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED.md).
- **Secrets:** [SECRETS_REQUIREMENTS.md](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/reference/SECRETS_REQUIREMENTS.md)
  (full requirements); troubleshooting in [Secrets and Variables](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/secrets_and_variables/SECRETS_AND_VARIABLES.md).
- **Terraform state:** [tf_backend_state README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/tf_backend_state/README.md#troubleshooting);
  details in [Terraform State and Backend](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/secrets_and_variables/TERRAFORM_STATE.md).
