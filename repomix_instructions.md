# Repomix Instructions for ldap-2fa-on-k8s

## Overview

You are an expert AWS DevOps and Platform Architect. This document is a packed
snapshot of my repository "ldap-2fa-on-k8s". Use the directory tree at the top as
the system-of-record for how components relate.

## Primary Goal

Build an accurate mental model of the end-to-end deployment and runtime architecture,
focusing on:

- Multi-account deployment design (state/secrets account vs target deployment account),
IAM role chaining/assume-role boundaries, and how Terraform providers and workflows
prevent credential drift.
- Terraform stacks and module composition, especially:
  - tf_backend_state (remote state + locking)
  - backend_infra (VPC endpoints, EKS Auto Mode, ECR, storage classes)
  - application (ALB/IngressClassParams, LDAP stack via Helm, ArgoCD EKS Capability,
  ArgoCD Applications, DNS/ACM integration)
- CI/CD and GitOps:
  - GitHub Actions workflows for terraform plan/apply and any image build/push flows
  - ArgoCD application definitions and how changes propagate to the cluster
  (automated sync, paths, environments/branches)
- Security and network posture:
  - Private-by-default design (LDAP not exposed externally)
  - ALB ingress grouping, TLS termination via ACM, Route53 records
  - VPC endpoints usage and any egress constraints
  - Kubernetes network policies and namespace isolation

## Extraction Instructions

1. Start by summarizing the repository's stack boundaries and deployment order
(what must exist before what).
2. Enumerate all AWS accounts/roles/profiles referenced and map which actions run
under which identity (local and GitHub Actions).
3. Trace external request flows:
   - Web: ALB -> frontend -> /api -> backend -> LDAP, plus optional SMS (SNS)
   - CLI: ALB -> /api -> backend -> LDAP, plus optional SMS (SNS)
4. Identify all inputs/outputs between stacks (Terraform remote_state outputs,
Helm values, variables, secrets) and where each value originates.
5. List "gotchas" and invariants (single ALB via group.name + group.order, one
app domain with path routing, backend endpoints under /api, no global credential
switching inside scripts).

## Ignore Patterns

- Non-essential markdown boilerplate, badges, and screenshots.
- Generated files, local caches, Terraform .terraform directories, plan/state artifacts,
node_modules, Python venvs.

## Ambiguity Handling

When something is ambiguous, state the assumption explicitly and point to the
exact file/path that would confirm it.
