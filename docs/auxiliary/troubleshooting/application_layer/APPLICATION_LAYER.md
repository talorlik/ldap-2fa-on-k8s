# Application Layer Troubleshooting (2FA App, PostgreSQL, Redis, SES, SNS)

This document covers the 2FA application backend/frontend, PostgreSQL,
Redis, admin-seed-job, SES, SNS, Ingress/ALB, and user registration.

## 2FA Application Issues

- Check backend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-backend`
- Check frontend pods: `kubectl logs -n 2fa-app -l app=ldap-2fa-frontend`
- Verify LDAP connectivity from backend (internal DNS resolution).
- Check IRSA role assumption: verify service account annotations.

## Pods Not Starting

```bash
kubectl describe pod -n 2fa-app <pod-name>
kubectl logs -n 2fa-app <pod-name>
kubectl get secrets -n 2fa-app
kubectl get secrets -n ldap-2fa   # PostgreSQL secret
kubectl get secrets -n redis      # Redis secret
```

## Image Pull Errors

```bash
# Verify ECR authentication
aws ecr get-login-password --region ${REGION} | docker login --username AWS \
  --password-stdin ${ECR_URL%%/*}

# Check if image exists in ECR
aws ecr describe-images --repository-name ${ECR_REPO_NAME} --region ${REGION} \
  --image-ids imageTag=${BACKEND_TAG}
```

## Ingress / ALB: Conflicting Load Balancer Name

If you see **"Failed build model due to conflicting load balancer name"**,
the 2FA frontend or backend Ingress has a different (or empty)
`alb.ingress.kubernetes.io/load-balancer-name` than the OpenLDAP Ingresses.
All Ingresses in the same IngressGroup must use the same ALB name.

- **ArgoCD:** Ensure `application_infra` is applied first so it outputs
  `alb_load_balancer_name`. Then apply `application/` so the ArgoCD apps
  receive Helm parameters with that name and the IngressClass. Sync the
  frontend and backend applications in ArgoCD.
- **Manual Helm:** Use the same `ALB_NAME` as OpenLDAP in backend and
  frontend values under
  `ingress.annotations.alb.ingress.kubernetes.io/load-balancer-name`.

```bash
kubectl describe ingress -n 2fa-app
kubectl get ingressclass ${INGRESS_CLASS}
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-name}{"\n"}{end}'
```

## Backend Cannot Connect to Services

```bash
# Test LDAP from backend pod
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('openldap-stack-ha.ldap.svc.cluster.local', 389)); print('LDAP reachable')"

# Test PostgreSQL
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('${POSTGRES_HOST}', 5432)); print('PostgreSQL reachable')"

# Test Redis
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('${REDIS_HOST}', ${REDIS_PORT})); print('Redis reachable')"
```

## IRSA Not Working

```bash
kubectl get serviceaccount -n 2fa-app -o yaml
aws iam get-role --role-name <role-name>
kubectl get pod -n 2fa-app -o jsonpath='{.items[0].spec.containers[0].env}' | jq
```

## PostgreSQL Issues

- Check pods: `kubectl get pods -n ldap-2fa -l app.kubernetes.io/name=postgresql`
- Check logs: `kubectl logs -n ldap-2fa -l app.kubernetes.io/name=postgresql`
- Check PVC: `kubectl get pvc -n ldap-2fa`
- Test: `kubectl exec -it -n ldap-2fa postgresql-0 -- psql -U ldap2fa -d ldap2fa`

**Backend "Name or service not known" (gaierror):**

- Backend expects Service `postgresql` in namespace `ldap-2fa`
  (DNS: `postgresql.ldap-2fa.svc.cluster.local`).
- Check: `kubectl get ns ldap-2fa`, `kubectl get svc -n ldap-2fa`. If the
  service has a longer name, re-apply `application/` so Helm uses
  `fullnameOverride: "postgresql"` (see `application/helm/postgresql-values.tpl.yaml`).

**Backend "Connection refused" (Errno 111):**

- DNS works but nothing accepts TCP on 5432. Usually PostgreSQL pod still
  starting or not ready.
- Check pod is Running and READY 1/1; check PostgreSQL logs and Service
  port 5432.

## Redis Issues

- Check pods: `kubectl get pods -n redis -l app.kubernetes.io/name=redis`
- Check logs and PVC; test:
  `kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD ping`

For Redis connection issues, see also
[REDIS_ENABLEMENT_SUMMARY](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/guides/REDIS_ENABLEMENT_SUMMARY.md#troubleshooting).

## Admin-Seed-Job Failures

- **ImagePullBackOff:** ECR uses commit-based tags, not `:latest`. Ensure
  Backend Build workflow has run and Helm values have the correct tag.
- **LDAP noSuchObject (32):** Directory structure (`ou=users`, `ou=groups`,
  `cn=admins`) may be missing on some pods. The `customLdifFiles` in
  OpenLDAP Helm values now auto-create these on all pods.
- **LDAP invalidCredentials (49):** Password mismatch between
  application_infra and application. The `ldap-admin-secret` now reads
  password from OpenLDAP secret in `ldap` namespace.
- **Group membership attribute error:** `groupOfUniqueNames` uses
  `uniqueMember`, not `member`. The LDAPClient now auto-detects the group
  objectClass.

For full investigation and fixes, see [LDAP and Admin-Seed](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED.md).

## SMS 2FA Not Working

- Verify SNS access: `aws sns get-sms-attributes`
- Check IAM role permissions and VPC endpoints for SNS and STS.
- Check backend logs for SNS errors; verify phone number format (E.164).

## SES Issues

- Check email identity:
`aws ses get-identity-verification-attributes --identities your@email.com`
- Check send quota: `aws ses get-send-quota`
- Verify IRSA: Check service account annotation for SES IAM role.

## User Registration Issues

- Check backend logs for registration errors.
- Verify PostgreSQL connectivity.
- Check SES sending limits (sandbox mode restricts recipients).
- Verify SNS SMS spending limit.

## Related Documentation

- [Troubleshooting Index](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/INDEX.md)
- [LDAP and Admin-Seed](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/ldap_admin_seed/LDAP_ADMIN_SEED.md)
- [Application Infrastructure Deployment](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
- [Frontend Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/frontend/FRONTEND.md)
- [Debug Commands](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/reference/DEBUG_COMMANDS.md)
- [application/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/README.md)
- [DEPLOY_2FA_APPS](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/deployment/DEPLOY_2FA_APPS.md)
