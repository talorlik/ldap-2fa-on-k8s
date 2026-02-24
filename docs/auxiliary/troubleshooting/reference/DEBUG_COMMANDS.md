# Debugging Commands for ArgoCD and OpenLDAP Deployments

This document contains commands used to debug the deployment of ArgoCD,
OpenLDAP, the admin-seed-job, and the 2FA application on EKS.

## Prerequisite: Authenticate & Connect to Cluster

```bash
# Assume deployment account role
source ./scripts/assume-github-role.sh prod

# Update kubeconfig
aws eks update-kubeconfig --name talo-tf-us-east-1-kc-prod --region us-east-1
```

## OpenLDAP Debugging

### Pod & Resource Status

```bash
kubectl get pods -n ldap
kubectl get pods -n ldap -o wide
kubectl get pvc -n ldap
kubectl get svc -n ldap
kubectl get ingress -n ldap
kubectl get secrets -n ldap
kubectl get configmap -n ldap openldap-stack-ha-env -o yaml
```

### Environment & Configuration

```bash
# Check LDAP environment variables on pod
kubectl exec -n ldap openldap-stack-ha-0 -- env | grep -E "^LDAP_"

# Check container image
kubectl get pod openldap-stack-ha-0 -n ldap -o jsonpath='{.spec.containers[0].image}'

# Check env and envFrom in StatefulSet
kubectl get statefulset -n ldap openldap-stack-ha \
  -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.'
kubectl get statefulset -n ldap openldap-stack-ha \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom}' | jq '.'
```

### Logs & Events

```bash
kubectl logs openldap-stack-ha-0 -n ldap --tail=50
kubectl logs openldap-stack-ha-0 -n ldap --container openldap-stack-ha | head -100
kubectl logs openldap-stack-ha-0 -n ldap --container init-chmod-secret
kubectl describe pod openldap-stack-ha-0 -n ldap | grep -A 20 "Events:"
```

### LDAP Authentication & Query Tests

```bash
# Test admin bind (ldapwhoami)
kubectl exec -n ldap openldap-stack-ha-0 -- ldapwhoami -x -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
  -w "$(kubectl get secret openldap-secret -n ldap \
    -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)"

# List all entries
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x -LLL \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" -w "<password>" \
  -b "dc=ldap,dc=talorlik,dc=internal" "(objectClass=*)" dn

# Check naming contexts
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x \
  -H ldap://localhost:389 -b "" -s base namingContexts

# Search for specific OUs
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" -w "<password>" \
  -b "dc=ldap,dc=talorlik,dc=internal" "(objectClass=organizationalUnit)" dn

# Check directory structure on ALL pods (replication check)
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  echo "=== $pod ==="
  kubectl exec -n ldap $pod -- ldapsearch -x -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" -w "<password>" \
    -b "dc=ldap,dc=talorlik,dc=internal" "(objectClass=*)" dn
done
```

### Secret Inspection & Password Comparison

```bash
# List keys in secrets
kubectl get secret openldap-secret -n ldap -o json | jq -r '.data | keys[]'
kubectl get secret openldap-stack-ha -n ldap -o json | jq -r '.data | keys[]'

# Decode all secret values
kubectl get secret -n ldap openldap-stack-ha \
  -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'

# Compare password hashes between namespaces
echo "ldap-admin-secret in 2fa-app:" && \
kubectl get secret ldap-admin-secret -n 2fa-app \
  -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d \
  | shasum -a 256 | cut -c1-16 && \
echo "openldap-secret in ldap:" && \
kubectl get secret openldap-secret -n ldap \
  -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d \
  | shasum -a 256 | cut -c1-16
```

### Helm Inspection

```bash
helm get values openldap-stack-ha -n ldap | grep -A5 existingSecret
helm get values openldap-stack-ha -n ldap -a | grep -A20 "global:" | head -30
helm history openldap-stack-ha -n ldap
```

### Recovery: PVC Delete & Pod Restart

```bash
# Delete PVCs to force reinitialization
kubectl delete pvc -n ldap \
  data-openldap-stack-ha-0 \
  data-openldap-stack-ha-1 \
  data-openldap-stack-ha-2

# Remove PVC finalizers if stuck
kubectl patch pvc data-openldap-stack-ha-0 -n ldap \
  -p '{"metadata":{"finalizers":null}}'
kubectl patch pvc data-openldap-stack-ha-1 -n ldap \
  -p '{"metadata":{"finalizers":null}}'
kubectl patch pvc data-openldap-stack-ha-2 -n ldap \
  -p '{"metadata":{"finalizers":null}}'

# Delete pods to trigger restart
kubectl delete pod -n ldap \
  openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2

# Wait for readiness
kubectl wait --for=condition=ready pod/openldap-stack-ha-0 -n ldap --timeout=120s
```

### Manual LDAP Directory Creation (Ad-Hoc Fix)

```bash
# Add OUs and admin group manually
kubectl exec -i -n ldap openldap-stack-ha-0 -- ldapadd -x \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" -w "<password>" -c <<EOF
dn: ou=users,dc=ldap,dc=talorlik,dc=internal
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=ldap,dc=talorlik,dc=internal
objectClass: organizationalUnit
ou: groups

dn: cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal
objectClass: groupOfUniqueNames
cn: admins
description: Administrator group
uniqueMember: cn=admin,dc=ldap,dc=talorlik,dc=internal
EOF
```

### External Access Test

```bash
curl -sI https://phpldapadmin.talorlik.com --max-time 10 | head -5
curl -sI https://passwd.talorlik.com --max-time 10 | head -5
```

## ArgoCD Debugging

When the ArgoCD capability is stuck in CREATING or you see AccessDenied in
health, use the commands below to inspect capability status, access entry,
associated policies, and IAM trust. See [Application Infrastructure
Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md) for fixes (e.g.
[Capability stuck in CREATING with AccessDenied](../deployment/APPLICATION_INFRA_DEPLOYMENT.md#3-capability-stuck-in-creating-with-accessdenied-in-health),
[Capability already exists / state out of
sync](../deployment/APPLICATION_INFRA_DEPLOYMENT.md#4-capability-already-exists-state-out-of-sync)).

### Capability Status and Health

```bash
# Full capability details (status, health.issues, configuration)
aws eks describe-capability \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --capability-name talo-tf-us-east-1-argocd-prod \
  --region us-east-1

# Status and health only (quick check)
aws eks describe-capability \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --capability-name talo-tf-us-east-1-argocd-prod \
  --region us-east-1 \
  --query 'capability.{status:status,health:health}'

# Status and server URL
aws eks describe-capability \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --capability-name talo-tf-us-east-1-argocd-prod \
  --region us-east-1 \
  --query 'capability.{server_url:configuration.argoCd.serverUrl,status:status}'
```

### Access Entry and Associated Policies

If health shows AccessDenied, verify the access entry exists and has the
expected policies (e.g. `AmazonEKSClusterAdminPolicy`). Use the ArgoCD
capability IAM role ARN as principal.

```bash
# Describe the access entry for the ArgoCD capability role
aws eks describe-access-entry \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn arn:aws:iam::944880695150:role/talo-tf-us-east-1-argocd-role-prod \
  --region us-east-1

# List policies associated with that entry (must include cluster-admin if
# Terraform association succeeded)
aws eks list-associated-access-policies \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn arn:aws:iam::944880695150:role/talo-tf-us-east-1-argocd-role-prod \
  --region us-east-1
```

### IAM Role Trust Policy

The capability role must allow `capabilities.eks.amazonaws.com` to assume it.
If policies are associated but health still shows AccessDenied, check the
trust policy.

```bash
aws iam get-role --role-name talo-tf-us-east-1-argocd-role-prod \
  --query 'Role.AssumeRolePolicyDocument'
```

Expected: principal `Service` =
`capabilities.eks.amazonaws.com`, actions `sts:AssumeRole` and
`sts:TagSession`. See [Application Infrastructure
Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md) (sections 3 and 4)
if policies are correct but capability remains CREATING.

### Capability Role Policies (Attached and Inline)

The capability role has the AWS managed policy
`AmazonEKSCapabilityArgoCD`, a core integrations inline policy (EKS,
Secrets Manager, CodeConnections, KMS), and an optional supplemental
inline policy for ECR/CodeCommit when enabled. To list what is
attached:

```bash
# Managed policies attached to the role
aws iam list-attached-role-policies --role-name talo-tf-us-east-1-argocd-role-prod

# Inline policy names on the role
aws iam list-role-policies --role-name talo-tf-us-east-1-argocd-role-prod
```

Expect `AmazonEKSCapabilityArgoCD` in attached policies and inline
policies such as `*-core-integrations` and (if ECR/CodeCommit enabled)
`*-supplemental`. See [ArgoCD IAM Policy
Comparison](../../reference/ARGOCD_IAM_POLICY_COMPARISON.md).

### ArgoCD Namespace and Pods

```bash
kubectl get pods -n argocd
kubectl get pods -A
```

## Admin-Seed-Job Debugging

### Job & Pod Status

```bash
kubectl get jobs -n 2fa-app
kubectl describe job admin-seed-job -n 2fa-app
kubectl get pods -n 2fa-app -l job-name=admin-seed-job
kubectl get pods -n 2fa-app -l app.kubernetes.io/name=admin-seed
```

### Logs

```bash
kubectl logs -n 2fa-app -l job-name=admin-seed-job --tail=100
kubectl logs -n 2fa-app <pod-name> --previous
```

### Events

```bash
kubectl get events -n 2fa-app --sort-by='.lastTimestamp' | tail -30
kubectl get events -n 2fa-app --sort-by='.lastTimestamp' | grep -i seed
```

### Secrets Used by Seed Job

```bash
kubectl get secrets -n 2fa-app | grep -E '(admin|ldap|seed|postgresql)'
kubectl get secret admin-seed-secret -n 2fa-app \
  -o jsonpath='{.data}' | jq -r 'keys[]'
kubectl get secret ldap-admin-secret -n 2fa-app \
  -o jsonpath='{.data}' | jq -r 'keys[]'
```

### Delete and Re-Trigger

```bash
kubectl delete job admin-seed-job -n 2fa-app
```

### Check ECR Images (Verify Image Tag Exists)

```bash
aws ecr describe-images \
  --repository-name talo-tf-us-east-1-docker-images-prod \
  --region us-east-1 --output table
```

### Test DB Connectivity from 2fa-app Namespace

```bash
kubectl run test-db-conn --rm -it --restart=Never -n 2fa-app \
  --image=busybox -- nc -zv postgresql.ldap-2fa.svc.cluster.local 5432
```

## 2FA Backend App Debugging

```bash
kubectl get pods -n 2fa-app
kubectl get all -n 2fa-app
kubectl logs -n 2fa-app <backend-pod> --tail=200
kubectl get ingress -n 2fa-app -o yaml
kubectl get deployment ldap-2fa-backend -n 2fa-app -o yaml \
  | grep -A100 'containers:' | head -120

# Health check from inside the pod
kubectl exec -n 2fa-app <backend-pod> -- python3 -c \
  "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/api/healthz').read().decode())"
```

## EKS Cluster-Level Logs & Events

### Cluster Info & Status

```bash
# Cluster overview
kubectl cluster-info

# Describe the EKS cluster (version, endpoint, logging, status)
aws eks describe-cluster \
  --name talo-tf-us-east-1-kc-prod \
  --region us-east-1 \
  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint,Logging:logging}'

# List all EKS clusters in the region
aws eks list-clusters --region us-east-1 --output text

# List node groups / compute (Auto Mode)
aws eks list-compute --cluster-name talo-tf-us-east-1-kc-prod \
  --region us-east-1 2>/dev/null || \
aws eks describe-cluster --name talo-tf-us-east-1-kc-prod \
  --region us-east-1 --query 'cluster.computeConfig'
```

### Cluster-Wide Kubernetes Events

```bash
# All events across all namespaces (sorted by time)
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Warning events only (potential issues)
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp'

# Events for a specific namespace
kubectl get events -n ldap --sort-by='.lastTimestamp' | tail -30
kubectl get events -n 2fa-app --sort-by='.lastTimestamp' | tail -30

# Events related to specific resource types
kubectl get events -A --sort-by='.lastTimestamp' | grep -i -E 'failed|error|back-off|unhealthy|oom'
```

### Node Status & Logs

```bash
# List nodes and their status
kubectl get nodes -o wide

# Describe a node (capacity, conditions, events)
kubectl describe node <node-name>

# Node conditions summary (Ready, MemoryPressure, DiskPressure, etc.)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[*]}{.type}={.status}{" "}{end}{"\n"}{end}'

# Node resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

### EKS CloudWatch Logs (Control Plane)

```bash
# Check which log types are enabled on the cluster
aws eks describe-cluster \
  --name talo-tf-us-east-1-kc-prod \
  --region us-east-1 \
  --query 'cluster.logging.clusterLogging'

# List available EKS log groups in CloudWatch
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/talo-tf-us-east-1-kc-prod \
  --region us-east-1

# Tail recent control plane logs (API server)
aws logs filter-log-events \
  --log-group-name /aws/eks/talo-tf-us-east-1-kc-prod/cluster \
  --log-stream-name-prefix kube-apiserver \
  --start-time $(date -v-1H +%s000) \
  --region us-east-1 \
  --query 'events[*].message' --output text | tail -50

# Tail recent authenticator logs
aws logs filter-log-events \
  --log-group-name /aws/eks/talo-tf-us-east-1-kc-prod/cluster \
  --log-stream-name-prefix authenticator \
  --start-time $(date -v-1H +%s000) \
  --region us-east-1 \
  --query 'events[*].message' --output text | tail -50

# Tail recent scheduler logs
aws logs filter-log-events \
  --log-group-name /aws/eks/talo-tf-us-east-1-kc-prod/cluster \
  --log-stream-name-prefix kube-scheduler \
  --start-time $(date -v-1H +%s000) \
  --region us-east-1 \
  --query 'events[*].message' --output text | tail -50

# Tail recent controller manager logs
aws logs filter-log-events \
  --log-group-name /aws/eks/talo-tf-us-east-1-kc-prod/cluster \
  --log-stream-name-prefix kube-controller-manager \
  --start-time $(date -v-1H +%s000) \
  --region us-east-1 \
  --query 'events[*].message' --output text | tail -50

# Search control plane logs for errors (last hour)
aws logs filter-log-events \
  --log-group-name /aws/eks/talo-tf-us-east-1-kc-prod/cluster \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern "ERROR" \
  --region us-east-1 \
  --query 'events[*].message' --output text | tail -30
```

### EKS Access & IAM Debugging

Use these to inspect access entries and policy associations. For ArgoCD
capability stuck in CREATING with AccessDenied, see [Application
Infrastructure Deployment - ArgoCD
failures](../deployment/APPLICATION_INFRA_DEPLOYMENT.md#argocd-deployment-failures)
(sections 3 and 4).

```bash
# List access entries on the cluster
aws eks list-access-entries \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --region us-east-1

# Describe a specific access entry
aws eks describe-access-entry \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn <role-or-user-arn> \
  --region us-east-1

# List access policies associated with an entry
aws eks list-associated-access-policies \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --principal-arn <role-or-user-arn> \
  --region us-east-1

# Verify current caller identity
aws sts get-caller-identity
```

### EKS Add-ons & Capabilities

For ArgoCD capability status and health (CREATING, AccessDenied), use the
[ArgoCD Debugging](#argocd-debugging) section above and [Application
Infrastructure Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md)
(ArgoCD failures, state out of sync).

```bash
# List installed add-ons
aws eks list-addons \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --region us-east-1

# Describe a specific add-on (e.g., coredns, kube-proxy, vpc-cni)
aws eks describe-addon \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --addon-name <addon-name> \
  --region us-east-1

# Check ArgoCD capability status
aws eks describe-capability \
  --cluster-name talo-tf-us-east-1-kc-prod \
  --capability-name talo-tf-us-east-1-argocd-prod \
  --region us-east-1 \
  --output json \
  --query 'capability.{server_url:configuration.argoCd.serverUrl,status:status}'
```

## Terraform State Inspection

```bash
# List state resources related to admin seed
terraform state list | grep admin_seed

# Taint and re-apply a specific resource
terraform taint 'kubernetes_job.admin_seed[0]'
terraform apply -target='kubernetes_job.admin_seed[0]' \
  -var-file="variables.tfvars" -auto-approve
```

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Application Infrastructure Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  - ArgoCD: capability stuck in CREATING, AccessDenied in health, access
    entry/policies, state out of sync (sections 3 and 4)
- [LDAP and Admin-Seed](../ldap_admin_seed/LDAP_ADMIN_SEED.md)
