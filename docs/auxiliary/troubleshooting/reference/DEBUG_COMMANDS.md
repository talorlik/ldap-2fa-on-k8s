# Debugging Commands for ArgoCD and OpenLDAP Deployments

This document contains commands used to debug the deployment of ArgoCD,
OpenLDAP, the admin-seed-job, and the 2FA application on EKS. Commands are
written as a **runbook**: copy-paste blocks set variables from the cluster
first, then use those variables so that transient values (pod names, passwords,
image tags, etc.) are never hard-coded.

## Prerequisite: Authenticate & Connect to Cluster

```bash
# Assume deployment account role
source ./scripts/assume-github-role.sh prod

OR

# (Need to add access entry for your admin SSO principal on the cluster; see
# [EKS_ACCESS_ENTRY.md](../../application_infra/guides/EKS_ACCESS_ENTRY.md))
aws sso login --profile prod

# Set cluster name from current context (use after kubeconfig is updated)
export CLUSTER_NAME=$(kubectl config current-context | sed 's/.*\///')
# Or set explicitly if needed:
# export CLUSTER_NAME=talo-tf-us-east-1-kc-prod

# Update kubeconfig (use CLUSTER_NAME if already set)
aws eks update-kubeconfig --name "${CLUSTER_NAME:-talo-tf-us-east-1-kc-prod}" --region us-east-1

# 2FA application namespace (used in Admin-Seed and 2FA Backend sections)
export FA_NS="${FA_NS:-2fa-app}"
```

## OpenLDAP Debugging

Use these variables in the OpenLDAP section. Run once after connecting to the
cluster:

```bash
export LDAP_NS=ldap
export LDAP_ADMIN_PASSWORD=$(kubectl get secret openldap-secret -n ldap -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)
export LDAP_BASE_DN="dc=ldap,dc=talorlik,dc=internal"
export LDAP_ADMIN_DN="cn=admin,${LDAP_BASE_DN}"
# First OpenLDAP pod (for single-pod commands)
export LDAP_POD_0=$(kubectl get pods -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[0].metadata.name}')
# All OpenLDAP pod names (for iteration)
export LDAP_PODS=$(kubectl get pods -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[*].metadata.name}')
export LDAP_STS=$(kubectl get statefulset -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[0].metadata.name}')
export LDAP_HELM_RELEASE=$(helm list -n "$LDAP_NS" -o json 2>/dev/null | jq -r '.[] | select(.chart | test("openldap|ldap")) | .name' | head -1)
export LDAP_STACK_SECRET=$(helm get values "${LDAP_HELM_RELEASE:-openldap-stack-ha}" -n "$LDAP_NS" -o json 2>/dev/null | jq -r '.existingSecret // "openldap-stack-ha"')
```

### Pod & Resource Status

```bash
kubectl get pods -n "$LDAP_NS"
kubectl get pods -n "$LDAP_NS" -o wide
kubectl get pvc -n "$LDAP_NS"
kubectl get svc -n "$LDAP_NS"
kubectl get ingress -n "$LDAP_NS"
kubectl get secrets -n "$LDAP_NS"
LDAP_ENV_CM=$(kubectl get configmap -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[0].metadata.name}')
kubectl get configmap -n "$LDAP_NS" "$LDAP_ENV_CM" -o yaml
```

### Environment & Configuration

```bash
# Check LDAP environment variables on pod
kubectl exec -n "$LDAP_NS" "$LDAP_POD_0" -- env | grep -E "^LDAP_"

# Check container image
kubectl get pod "$LDAP_POD_0" -n "$LDAP_NS" -o jsonpath='{.spec.containers[0].image}'

# Check env and envFrom in StatefulSet
kubectl get statefulset -n "$LDAP_NS" "$LDAP_STS" -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.'
kubectl get statefulset -n "$LDAP_NS" "$LDAP_STS" -o jsonpath='{.spec.template.spec.containers[0].envFrom}' | jq '.'
```

### Logs & Events

```bash
kubectl logs "$LDAP_POD_0" -n "$LDAP_NS" --tail=50
LDAP_CONTAINER=$(kubectl get pod "$LDAP_POD_0" -n "$LDAP_NS" -o jsonpath='{.spec.containers[0].name}')
kubectl logs "$LDAP_POD_0" -n "$LDAP_NS" --container "$LDAP_CONTAINER" | head -100
kubectl logs "$LDAP_POD_0" -n "$LDAP_NS" --container init-chmod-secret
kubectl describe pod "$LDAP_POD_0" -n "$LDAP_NS" | grep -A 20 "Events:"
```

### LDAP Authentication & Query Tests

```bash
# Test admin bind (ldapwhoami)
kubectl exec -n "$LDAP_NS" "$LDAP_POD_0" -- ldapwhoami -x -H ldap://localhost:389 \
  -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD"

# List all entries
kubectl exec -n "$LDAP_NS" "$LDAP_POD_0" -- ldapsearch -x -LLL \
  -H ldap://localhost:389 \
  -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
  -b "$LDAP_BASE_DN" "(objectClass=*)" dn

# Check naming contexts
kubectl exec -n "$LDAP_NS" "$LDAP_POD_0" -- ldapsearch -x \
  -H ldap://localhost:389 -b "" -s base namingContexts

# Search for specific OUs
kubectl exec -n "$LDAP_NS" "$LDAP_POD_0" -- ldapsearch -x \
  -H ldap://localhost:389 \
  -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
  -b "$LDAP_BASE_DN" "(objectClass=organizationalUnit)" dn

# Check directory structure on ALL pods (replication check)
for pod in $LDAP_PODS; do
  echo "=== $pod ==="
  kubectl exec -n "$LDAP_NS" "$pod" -- ldapsearch -x -H ldap://localhost:389 \
    -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "$LDAP_BASE_DN" "(objectClass=*)" dn
done
```

### Secret Inspection & Password Comparison

```bash
# List keys in secrets
kubectl get secret openldap-secret -n "$LDAP_NS" -o json | jq -r '.data | keys[]'
kubectl get secret "${LDAP_STACK_SECRET}" -n "$LDAP_NS" -o json | jq -r '.data | keys[]'

# Decode all secret values
kubectl get secret -n "$LDAP_NS" "${LDAP_STACK_SECRET}" \
  -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'

# Compare password hashes between namespaces
echo "ldap-admin-secret in ${FA_NS:-2fa-app}:" && \
kubectl get secret ldap-admin-secret -n "${FA_NS:-2fa-app}" \
  -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d \
  | shasum -a 256 | cut -c1-16 && \
echo "openldap-secret in ldap:" && \
kubectl get secret openldap-secret -n "$LDAP_NS" \
  -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d \
  | shasum -a 256 | cut -c1-16
```

### Helm Inspection

```bash
helm get values "${LDAP_HELM_RELEASE:-openldap-stack-ha}" -n "$LDAP_NS" | grep -A5 existingSecret
helm get values "${LDAP_HELM_RELEASE:-openldap-stack-ha}" -n "$LDAP_NS" -a | grep -A20 "global:" | head -30
helm history "${LDAP_HELM_RELEASE:-openldap-stack-ha}" -n "$LDAP_NS"
```

### Recovery: PVC Delete & Pod Restart

```bash
# List PVCs and pods for the OpenLDAP StatefulSet (verify before delete)
kubectl get pvc -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o name
kubectl get pods -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o name

# Delete PVCs to force reinitialization
kubectl get pvc -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | xargs -I {} kubectl delete pvc {} -n "$LDAP_NS"

# Remove PVC finalizers if stuck (repeat for each PVC that is stuck)
for pvc in $(kubectl get pvc -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[*].metadata.name}'); do
  kubectl patch pvc "$pvc" -n "$LDAP_NS" -p '{"metadata":{"finalizers":null}}'
done

# Delete pods to trigger restart
for pod in $LDAP_PODS; do
  kubectl delete pod "$pod" -n "$LDAP_NS"
done

# Wait for first pod to be ready
kubectl wait --for=condition=ready "pod/$(kubectl get pods -n "$LDAP_NS" -l app.kubernetes.io/name=openldap-stack-ha -o jsonpath='{.items[0].metadata.name}')" -n "$LDAP_NS" --timeout=120s
```

### Manual LDAP Directory Creation (Ad-Hoc Fix)

```bash
# Add OUs and admin group manually (requires LDAP_* variables from OpenLDAP section)
kubectl exec -i -n "$LDAP_NS" "$LDAP_POD_0" -- ldapadd -x \
  -H ldap://localhost:389 \
  -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -c <<EOF
dn: ou=users,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: users

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups

dn: cn=admins,ou=groups,${LDAP_BASE_DN}
objectClass: groupOfUniqueNames
cn: admins
description: Administrator group
uniqueMember: ${LDAP_ADMIN_DN}
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

Set variables from the cluster (run once). Use the same region as your
kubeconfig.

```bash
export AWS_REGION=us-east-1
export EKS_CLUSTER_NAME=$(kubectl config current-context | sed 's/.*\///')
export ARGOCD_CAPABILITY_NAME=$(aws eks list-capabilities --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'capabilities[?contains(capabilityName, `argocd`)].capabilityName' --output text | head -1)
export ARGOCD_ROLE_ARN=$(aws eks describe-capability --cluster-name "$EKS_CLUSTER_NAME" --capability-name "$ARGOCD_CAPABILITY_NAME" --region "$AWS_REGION" --query 'capability.configuration.argoCd.roleArn' --output text)
export ARGOCD_ROLE_NAME=$(echo "$ARGOCD_ROLE_ARN" | sed 's|.*/||')
```

### Capability Status and Health

```bash
# Full capability details (status, health.issues, configuration)
aws eks describe-capability \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --capability-name "$ARGOCD_CAPABILITY_NAME" \
  --region "$AWS_REGION"

# Status and health only (quick check)
aws eks describe-capability \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --capability-name "$ARGOCD_CAPABILITY_NAME" \
  --region "$AWS_REGION" \
  --query 'capability.{status:status,health:health}'

# Status and server URL
aws eks describe-capability \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --capability-name "$ARGOCD_CAPABILITY_NAME" \
  --region "$AWS_REGION" \
  --query 'capability.{server_url:configuration.argoCd.serverUrl,status:status}'
```

### Access Entry and Associated Policies

If health shows AccessDenied, verify the access entry exists and has the
expected policies (e.g. `AmazonEKSClusterAdminPolicy`). Use the ArgoCD
capability IAM role ARN as principal (set in the ArgoCD variables block above).

```bash
# Describe the access entry for the ArgoCD capability role
aws eks describe-access-entry \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ARGOCD_ROLE_ARN" \
  --region "$AWS_REGION"

# List policies associated with that entry (must include cluster-admin if
# Terraform association succeeded)
aws eks list-associated-access-policies \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ARGOCD_ROLE_ARN" \
  --region "$AWS_REGION"
```

### IAM Role Trust Policy

The capability role must allow `capabilities.eks.amazonaws.com` to assume it.
If policies are associated but health still shows AccessDenied, check the
trust policy.

```bash
aws iam get-role --role-name "$ARGOCD_ROLE_NAME" \
  --query 'Role.AssumeRolePolicyDocument'
```

Expected: principal `Service` =
`capabilities.eks.amazonaws.com`, actions `sts:AssumeRole` and
`sts:TagSession`. See [Application Infrastructure
Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md) (sections 3 and 4)
if policies are correct but capability remains CREATING.

### Capability Role Policies (Inline)

The capability role has a single inline IAM policy (EKS, Secrets Manager,
KMS, CodeConnections, and optional ECR/CodeCommit when enabled). To list
what is attached:

```bash
# Inline policy names on the role (ARGOCD_ROLE_NAME from trust policy block)
aws iam list-role-policies --role-name "$ARGOCD_ROLE_NAME"
```

Expect one inline policy named `*-policy` (e.g.
`talo-tf-us-east-1-argocd-role-prod-policy`). No AWS managed policies are
attached. See the [ArgoCD module README](../../../application_infra/modules/argocd/README.md)
(IAM Policy section) for permissions by service.

### ArgoCD Namespace and Pods

```bash
kubectl get pods -n argocd
kubectl get pods -A
```

## Admin-Seed-Job Debugging

Set job/pod variables (run once; FA_NS from Prerequisite or set here):

```bash
export FA_NS="${FA_NS:-2fa-app}"
export ADMIN_SEED_JOB=admin-seed-job
export ADMIN_SEED_POD=$(kubectl get pods -n "$FA_NS" -l job-name=admin-seed-job -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
```

### Job & Pod Status

```bash
kubectl get jobs -n "$FA_NS"
kubectl describe job "$ADMIN_SEED_JOB" -n "$FA_NS"
kubectl get pods -n "$FA_NS" -l job-name=admin-seed-job
kubectl get pods -n "$FA_NS" -l app.kubernetes.io/name=admin-seed
```

### Logs

```bash
kubectl logs -n "$FA_NS" -l job-name=admin-seed-job --tail=100
# Logs from previous container (if pod restarted); set ADMIN_SEED_POD if not set above
ADMIN_SEED_POD=$(kubectl get pods -n "$FA_NS" -l job-name=admin-seed-job -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n "$FA_NS" "$ADMIN_SEED_POD" --previous
```

### Events

```bash
kubectl get events -n "$FA_NS" --sort-by='.lastTimestamp' | tail -30
kubectl get events -n "$FA_NS" --sort-by='.lastTimestamp' | grep -i seed
```

### Secrets Used by Seed Job

```bash
kubectl get secrets -n "$FA_NS" | grep -E '(admin|ldap|seed|postgresql)'
kubectl get secret admin-seed-secret -n "$FA_NS" \
  -o jsonpath='{.data}' | jq -r 'keys[]'
kubectl get secret ldap-admin-secret -n "$FA_NS" \
  -o jsonpath='{.data}' | jq -r 'keys[]'
```

### Delete and Re-Trigger

```bash
kubectl delete job "$ADMIN_SEED_JOB" -n "$FA_NS"
```

### Reproduce Failure with Debug Pod

When the seed job pod has been cleaned up (TTL expiry, backoff limit), run a
one-off pod with the same image and environment to reproduce the error. Image
is taken from the backend deployment.

```bash
# Fetch backend image from the ldap-2fa-backend deployment
SEED_IMAGE=$(kubectl get deployment ldap-2fa-backend -n "$FA_NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
# Create a debug pod that mirrors the seed job's configuration
kubectl run admin-seed-debug \
  --image="$SEED_IMAGE" \
  --namespace="$FA_NS" --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "admin-seed-debug",
        "image": "'"$SEED_IMAGE"'",
        "command": ["python", "-m", "app.seed_admin"],
        "envFrom": [
          {"secretRef": {"name": "admin-seed-secret"}},
          {"secretRef": {"name": "ldap-admin-secret"}}
        ],
        "env": [
          {"name": "DATABASE_HOST", "value": "postgresql.ldap-2fa.svc.cluster.local"},
          {"name": "DATABASE_PORT", "value": "5432"},
          {"name": "DATABASE_USER", "value": "ldap2fa"},
          {"name": "DATABASE_NAME", "value": "ldap2fa"},
          {"name": "DATABASE_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "postgresql-secret", "key": "password"}}},
          {"name": "LDAP_HOST", "value": "openldap-stack-ha.ldap.svc.cluster.local"},
          {"name": "LDAP_PORT", "value": "389"},
          {"name": "LDAP_BASE_DN", "value": "dc=ldap,dc=talorlik,dc=internal"},
          {"name": "LDAP_ADMIN_DN", "value": "cn=admin,dc=ldap,dc=talorlik,dc=internal"},
          {"name": "LDAP_ADMIN_GROUP_DN", "value": "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal"},
          {"name": "LDAP_USER_SEARCH_BASE", "value": "ou=users"},
          {"name": "LDAP_GROUP_SEARCH_BASE", "value": "ou=groups"},
          {"name": "LDAP_REPLICA_COUNT", "value": "3"},
          {"name": "LDAP_HEADLESS_HOST", "value": "openldap-stack-ha-headless.ldap.svc.cluster.local"}
        ]
      }]
    }
  }'

# Wait and read logs
sleep 15 && kubectl logs admin-seed-debug -n "$FA_NS"

# Clean up
kubectl delete pod admin-seed-debug -n "$FA_NS" --grace-period=0
```

### Verify StatefulSet Pod DNS Resolution (Headless Service)

StatefulSet pods are only addressable via the headless service. Use this to
confirm DNS works for individual pods. Uses the same backend image as the seed
job.

```bash
SEED_IMAGE=$(kubectl get deployment ldap-2fa-backend -n "$FA_NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
kubectl run dns-test \
  --image="$SEED_IMAGE" \
  --namespace="$FA_NS" --restart=Never \
  --command -- python -c "
import socket
for i in range(3):
    h = f'openldap-stack-ha-{i}.openldap-stack-ha-headless.ldap.svc.cluster.local'
    try:
        ip = socket.getaddrinfo(h, 389)[0][4][0]
        print(f'OK: {h} -> {ip}')
    except Exception as e:
        print(f'FAIL: {h} -> {e}')
"
sleep 10 && kubectl logs dns-test -n "$FA_NS"
kubectl delete pod dns-test -n "$FA_NS" --grace-period=0
```

### Verify Secrets (Non-Empty, Without Revealing Values)

```bash
for secret in admin-seed-secret ldap-admin-secret postgresql-secret; do
  echo "=== $secret ==="
  kubectl get secret $secret -n "$FA_NS" \
    -o jsonpath='{.data}' | python3 -c \
    "import sys,json,base64; data=json.load(sys.stdin); \
     [print(f'  {k}: ({len(base64.b64decode(v))} bytes)') for k,v in data.items()]"
done
```

### Check ECR Images (Verify Image Tag Exists)

```bash
# Get ECR repo from the backend image (e.g. 944880695150.dkr.ecr.us-east-1.amazonaws.com/talo-tf-us-east-1-docker-images-prod:abc123)
BACKEND_IMAGE=$(kubectl get deployment ldap-2fa-backend -n "$FA_NS" -o jsonpath='{.spec.template.spec.containers[0].image}')
ECR_REPO=$(echo "$BACKEND_IMAGE" | cut -d: -f1 | sed 's|.*/||')
aws ecr describe-images \
  --repository-name "$ECR_REPO" \
  --region "${AWS_REGION:-us-east-1}" --output table
```

### Test DB Connectivity from 2fa-app Namespace

```bash
kubectl run test-db-conn --rm -it --restart=Never -n "$FA_NS" \
  --image=busybox -- nc -zv postgresql.ldap-2fa.svc.cluster.local 5432
```

## 2FA Backend App Debugging

Set backend pod variable (run once):

```bash
export FA_NS="${FA_NS:-2fa-app}"
export BACKEND_POD=$(kubectl get pod -n "$FA_NS" -l app.kubernetes.io/name=ldap-2fa-backend -o jsonpath='{.items[0].metadata.name}')
```

```bash
kubectl get pods -n "$FA_NS"
kubectl get all -n "$FA_NS"
kubectl logs -n "$FA_NS" "$BACKEND_POD" --tail=200
kubectl get ingress -n "$FA_NS" -o yaml
kubectl get deployment ldap-2fa-backend -n "$FA_NS" -o yaml \
  | grep -A100 'containers:' | head -120

# Health check from inside the pod
kubectl exec -n "$FA_NS" "$BACKEND_POD" -- python3 -c \
  "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/api/healthz').read().decode())"
```

### Redis (Required for Login and SMS OTP)

The backend requires Redis for login challenges and SMS OTP storage. If Redis is
unavailable, login/start and SMS endpoints return 503 "Storage unavailable."

#### Step-by-step: Ensure Redis is up and reachable from the backend

Run these in order. Set `FA_NS` if your backend namespace differs (e.g.
`export FA_NS=twofa-backend`).

1. **Redis namespace and pods**

    ```bash
    kubectl get ns redis
    kubectl get pods -n redis -l app.kubernetes.io/name=redis
    kubectl get svc -n redis
    ```

    - Pods should be Running and Ready. The master pod is typically
      `<release>-master-0` (e.g. `talo-tf-us-east-1-redis-prod-master-0`).
    - Backend REDIS_HOST must match the Redis service name. Terraform passes
      `redis.host` to the backend via ArgoCD (e.g.
      `talo-tf-us-east-1-redis-prod-master.redis.svc.cluster.local`).

2. **Redis secret in Redis namespace**

    ```bash
    kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d | wc -c
    ```

    - Should output a non-zero length (password present).

3. **Redis secret in backend namespace**

    ```bash
    kubectl get secret redis-secret -n "${FA_NS:-2fa-app}"
    ```

    - Backend reads `REDIS_PASSWORD` from this secret. If missing, Terraform
      should create it when `enable_redis` is true (see
      `kubernetes_secret.redis_secret_backend_namespace`).

4. **Backend environment (REDIS_HOST / REDIS_PASSWORD)**

    ```bash
    kubectl get deployment -n "${FA_NS:-2fa-app}" -l app.kubernetes.io/name=ldap-2fa-backend -o name
    kubectl get deployment -n "${FA_NS:-2fa-app}" ldap-2fa-backend -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.[] | select(.name | startswith("REDIS")) | {name, valueFrom}'
    ```

    - Confirm `REDIS_HOST` matches the Redis service in the cluster (e.g.
      `talo-tf-us-east-1-redis-prod-master.redis.svc.cluster.local`) and
      `REDIS_PASSWORD` comes from secret `redis-secret`.

5. **Test Redis from a backend pod**

    ```bash
    BACKEND_POD=$(kubectl get pod -n "${FA_NS:-2fa-app}" -l app.kubernetes.io/name=ldap-2fa-backend -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n "${FA_NS:-2fa-app}" "$BACKEND_POD" -- python3 -c "
    import os
    import redis
    r = redis.Redis(host=os.environ.get('REDIS_HOST','redis-master.redis.svc.cluster.local'),
      port=int(os.environ.get('REDIS_PORT',6379)),
      password=os.environ.get('REDIS_PASSWORD','') or None,
      decode_responses=True, socket_connect_timeout=5)
    r.ping()
    print('Redis OK')
    "
    ```

    - If this fails: connection refused / timeout usually means network (e.g.
      NetworkPolicy) or wrong host/port; authentication error means wrong password
      or missing secret in backend namespace. "Name or service not known" means
      REDIS_HOST does not match the Redis service name in the cluster (Terraform
      should pass the correct host via ArgoCD; ensure backend deployment has
      redis.host set to the actual service, e.g.
      `<release>-master.redis.svc.cluster.local`).

6. **Backend logs (Redis connection errors)**

    ```bash
    BACKEND_POD=$(kubectl get pod -n "${FA_NS:-2fa-app}" -l app.kubernetes.io/name=ldap-2fa-backend -o jsonpath='{.items[0].metadata.name}')
    kubectl logs -n "${FA_NS:-2fa-app}" "$BACKEND_POD" --tail=100 | grep -i redis
    ```

    - Look for "Failed to connect to Redis" or "Redis authentication failed".

7. **Optional: list Redis keys (login challenge / OTP)**

    ```bash
    REDIS_POD=$(kubectl get pod -n redis -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}')
    REDIS_PASSWORD=$(kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
    kubectl exec -n redis "$REDIS_POD" -- redis-cli -a "$REDIS_PASSWORD" KEYS "sms_otp:*"
    ```

    - Redis pod name is typically `<release>-master-0` (e.g.
      `talo-tf-us-east-1-redis-prod-master-0`).

#### Quick checks (all-in-one)

```bash
# Redis pods and secrets
kubectl get pods -n redis -l app.kubernetes.io/name=redis
kubectl get secret redis-secret -n redis
kubectl get secret redis-secret -n "${FA_NS:-2fa-app}"

# Test Redis from a backend pod (REDIS_PASSWORD from env)
BACKEND_POD=$(kubectl get pod -n "${FA_NS:-2fa-app}" -l app.kubernetes.io/name=ldap-2fa-backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${FA_NS:-2fa-app}" "$BACKEND_POD" -- python3 -c "
import os
import redis
r = redis.Redis(host=os.environ.get('REDIS_HOST','redis-master.redis.svc.cluster.local'),
  port=int(os.environ.get('REDIS_PORT',6379)),
  password=os.environ.get('REDIS_PASSWORD','') or None,
  decode_responses=True, socket_connect_timeout=5)
r.ping()
print('Redis OK')
"

# List login challenge and SMS OTP keys (password from secret)
REDIS_POD=$(kubectl get pod -n redis -l app.kubernetes.io/name=redis -o jsonpath='{.items[0].metadata.name}')
REDIS_PASSWORD=$(kubectl get secret redis-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
kubectl exec -n redis "$REDIS_POD" -- redis-cli -a "$REDIS_PASSWORD" KEYS "sms_otp:*"
```

## EKS Cluster-Level Logs & Events

Set cluster and region (run once; or use values from ArgoCD section):

```bash
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-$(kubectl config current-context | sed 's/.*\///')}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
```

### Cluster Info & Status

```bash
# Cluster overview
kubectl cluster-info

# Describe the EKS cluster (version, endpoint, logging, status)
aws eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint,Logging:logging}'

# List all EKS clusters in the region
aws eks list-clusters --region "$AWS_REGION" --output text

# List node groups / compute (Auto Mode)
aws eks list-compute --cluster-name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" 2>/dev/null || \
aws eks describe-cluster --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" --query 'cluster.computeConfig'
```

### Cluster-Wide Kubernetes Events

```bash
# All events across all namespaces (sorted by time)
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Warning events only (potential issues)
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp'

# Events for a specific namespace
kubectl get events -n ldap --sort-by='.lastTimestamp' | tail -30
kubectl get events -n "${FA_NS:-2fa-app}" --sort-by='.lastTimestamp' | tail -30

# Events related to specific resource types
kubectl get events -A --sort-by='.lastTimestamp' | grep -i -E 'failed|error|back-off|unhealthy|oom'
```

### Node Status & Logs

```bash
# List nodes and their status
kubectl get nodes -o wide

# Describe a node (capacity, conditions, events); NODE_NAME from first node or set explicitly
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl describe node "$NODE_NAME"

# Node conditions summary (Ready, MemoryPressure, DiskPressure, etc.)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[*]}{.type}={.status}{" "}{end}{"\n"}{end}'

# Node resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

### EKS CloudWatch Logs (Control Plane)

Log group name is derived from the cluster name. On macOS use `date -v-1H +%s000`;
on Linux use `date -d '1 hour ago' +%s000`.

```bash
EKS_LOG_GROUP="/aws/eks/${EKS_CLUSTER_NAME}/cluster"
LOG_START=$(date -v-1H +%s000 2>/dev/null || date -d '1 hour ago' +%s000)

# Check which log types are enabled on the cluster
aws eks describe-cluster \
  --name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'cluster.logging.clusterLogging'

# List available EKS log groups in CloudWatch
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/eks/$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION"

# Tail recent control plane logs (API server)
aws logs filter-log-events \
  --log-group-name "$EKS_LOG_GROUP" \
  --log-stream-name-prefix kube-apiserver \
  --start-time "$LOG_START" \
  --region "$AWS_REGION" \
  --query 'events[*].message' --output text | tail -50

# Tail recent authenticator logs
aws logs filter-log-events \
  --log-group-name "$EKS_LOG_GROUP" \
  --log-stream-name-prefix authenticator \
  --start-time "$LOG_START" \
  --region "$AWS_REGION" \
  --query 'events[*].message' --output text | tail -50

# Tail recent scheduler logs
aws logs filter-log-events \
  --log-group-name "$EKS_LOG_GROUP" \
  --log-stream-name-prefix kube-scheduler \
  --start-time "$LOG_START" \
  --region "$AWS_REGION" \
  --query 'events[*].message' --output text | tail -50

# Tail recent controller manager logs
aws logs filter-log-events \
  --log-group-name "$EKS_LOG_GROUP" \
  --log-stream-name-prefix kube-controller-manager \
  --start-time "$LOG_START" \
  --region "$AWS_REGION" \
  --query 'events[*].message' --output text | tail -50

# Search control plane logs for errors (last hour)
aws logs filter-log-events \
  --log-group-name "$EKS_LOG_GROUP" \
  --start-time "$LOG_START" \
  --filter-pattern "ERROR" \
  --region "$AWS_REGION" \
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
  --cluster-name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION"

# Describe a specific access entry (use first principal from list, or set ACCESS_PRINCIPAL_ARN)
ACCESS_PRINCIPAL_ARN=$(aws eks list-access-entries --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'accessEntries[0]' --output text)
aws eks describe-access-entry \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ACCESS_PRINCIPAL_ARN" \
  --region "$AWS_REGION"

# List access policies associated with an entry
aws eks list-associated-access-policies \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ACCESS_PRINCIPAL_ARN" \
  --region "$AWS_REGION"

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
  --cluster-name "$EKS_CLUSTER_NAME" \
  --region "$AWS_REGION"

# Describe a specific add-on (e.g., coredns, kube-proxy, vpc-cni)
ADDON_NAME=$(aws eks list-addons --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'addons[0]' --output text)
aws eks describe-addon \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --addon-name "$ADDON_NAME" \
  --region "$AWS_REGION"

# Check ArgoCD capability status (uses ARGOCD_CAPABILITY_NAME if set in ArgoCD section)
ARGOCD_CAP_NAME="${ARGOCD_CAPABILITY_NAME:-$(aws eks list-capabilities --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'capabilities[?contains(capabilityName, `argocd`)].capabilityName' --output text | head -1)}"
aws eks describe-capability \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --capability-name "$ARGOCD_CAP_NAME" \
  --region "$AWS_REGION" \
  --output json \
  --query 'capability.{server_url:configuration.argoCd.serverUrl,status:status}'
```

## Terraform State Inspection

Run from the Terraform root where the admin seed job is managed (e.g.
`application/`).

```bash
# List state resources related to admin seed
terraform state list | grep admin_seed

# Set resource address from state (use the one that matches your job)
ADMIN_SEED_RESOURCE=$(terraform state list | grep 'kubernetes_job.*admin_seed' | head -1)

# Taint and re-apply that resource
terraform taint "$ADMIN_SEED_RESOURCE"
terraform apply -target="$ADMIN_SEED_RESOURCE" \
  -var-file="variables.tfvars" -auto-approve
```

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Application Infrastructure Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md)
  - ArgoCD: capability stuck in CREATING, AccessDenied in health, access
    entry/policies, state out of sync (sections 3 and 4)
- [LDAP and Admin-Seed](../ldap_admin_seed/LDAP_ADMIN_SEED.md)
