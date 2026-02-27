# LDAP and Admin-Seed-Job Troubleshooting Guide

This document describes persistent issues encountered with the OpenLDAP
configuration and admin-seed-job, the investigative actions taken, ad-hoc
corrections applied, and the permanent code fixes implemented.

## Table of Contents

- [Issue Summary](#issue-summary)
- [Investigation Timeline](#investigation-timeline)
- [Root Causes](#root-causes)
- [Ad-Hoc Manual Corrections](#ad-hoc-manual-corrections)
- [Permanent Code Fixes](#permanent-code-fixes)
- [Verification Steps](#verification-steps)
- [Lessons Learned](#lessons-learned)
- [Related Documentation](#related-documentation)

## Issue Summary

The admin-seed-job, designed to create the first admin user in both LDAP and
PostgreSQL, failed repeatedly with the following symptoms:

1. **Image Pull Error**: Job used `:latest` tag which doesn't exist in ECR
2. **LDAP Authentication Failure**: `LDAPInvalidCredentialsResult - 49 - invalidCredentials`
3. **LDAP Directory Structure Missing**: `LDAPNoSuchObjectResult - 32 - noSuchObject`
   for `ou=users`, `ou=groups`, and `cn=admins`
4. **Inconsistent Data Across Pods**: Multi-master replication not syncing properly
5. **Group Membership Attribute Error**: Wrong attribute used for `groupOfUniqueNames`
6. **Invalid Server Address (Headless Service DNS)**: Pod hostnames constructed
   using ClusterIP service instead of headless service, causing `invalid server
   address` on every LDAP replica

## Investigation Timeline

### Phase 1: Initial Job Failure Investigation

**Observation**: Admin-seed-job pod not found in the `2fa-app` namespace.

```bash
# Check job status
kubectl get jobs -n 2fa-app

# Job had been auto-deleted by TTL (24 hours after completion)
```

**Action**: Recreated the job via Terraform taint/apply:

```bash
cd /Users/talo/www/ldap-2fa-on-k8s/application

# Assume deployment account credentials
eval $(../scripts/assume-github-role.sh prod 2>/dev/null | grep "^export")

# Taint the job to force recreation
terraform taint 'kubernetes_job.admin_seed[0]'

# Assume state account for Terraform apply
eval $(../scripts/assume-github-role.sh state 2>/dev/null | grep "^export")

terraform apply -var-file=variables.tfvars -auto-approve
```

**Result**: Job recreated but failed with `ImagePullBackOff` - the `:latest`
tag doesn't exist in ECR.

### Phase 2: Image Tag Investigation

**Observation**: ECR repository only contains commit-based tags (e.g.,
`ldap-2fa-backend-a9013827ed212506d2e071f29e65f47a30d42788-22135158956`),
not `:latest`.

```bash
# List ECR images
aws ecr list-images --repository-name talo-tf-us-east-1-docker-images-prod \
  --region us-east-1 --query 'imageIds[*].imageTag' --output table
```

**Root Cause**: The backend build workflow pushes commit-based tags, not
`:latest`. The Terraform variable `backend_image_tag` was defaulting to
`"latest"`.

**Temporary Fix**: Manually set the correct tag in Terraform apply:

```bash
terraform apply -var-file=variables.tfvars \
  -var="backend_image_tag=ldap-2fa-backend-a9013827ed212506d2e071f29e65f47a30d42788-22135158956" \
  -auto-approve
```

### Phase 3: LDAP Directory Structure Investigation

**Observation**: Job ran but failed with LDAP errors:

```text
LDAPNoSuchObjectResult - 32 - noSuchObject
Search for "ou=users,dc=ldap,dc=talorlik,dc=internal" failed
```

**Investigation Commands**:

```bash
# Check LDAP directory structure on each pod
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  echo "=== $pod ==="
  kubectl exec -n ldap $pod -- ldapsearch -x -LLL -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" \
    -b "dc=ldap,dc=talorlik,dc=internal" \
    "(objectClass=*)" dn 2>/dev/null | head -20
done
```

**Finding**: Pod-0 had full directory structure; pods 1 and 2 only had the
base DN.

| Pod | Directory Entries |
| --- | ----------------- |
| openldap-stack-ha-0 | `dc=ldap,dc=talorlik,dc=internal`, `ou=users`, `ou=groups`, `cn=admins`, `uid=admin` |
| openldap-stack-ha-1 | `dc=ldap,dc=talorlik,dc=internal` only |
| openldap-stack-ha-2 | `dc=ldap,dc=talorlik,dc=internal` only |

### Phase 4: LDAP Group Membership Investigation

**Observation**: After manually adding directory structure, adding user to
group failed:

```text
LDAPAttributeOrValueExistsResult - 20 - attributeOrValueExists
type violatesProvisions: attribute 'member' not allowed
```

**Root Cause**: The `cn=admins` group has objectClass `groupOfUniqueNames`,
which uses `uniqueMember` attribute, not `member`.

```bash
# Check group objectClass
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x -LLL \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
  -w "$LDAP_ADMIN_PASSWORD" \
  -b "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal" \
  objectClass

# Output: groupOfUniqueNames
```

### Phase 5: Headless Service DNS Investigation

**Observation**: Admin-seed-job failed (status `Failed`, 0/1 completions).
Pod had already been cleaned up (TTL-based), so no logs were available.

```bash
# Check job status across all namespaces
kubectl get job -A

# Describe the job (shows environment, image, and pod status)
kubectl describe job admin-seed-job -n 2fa-app

# Pod was already cleaned up — no logs available
kubectl logs job/admin-seed-job -n 2fa-app --all-containers=true
# error: timed out waiting for the condition
```

**Action**: Verified all infrastructure was healthy:

```bash
# All services running
kubectl get pods -n 2fa-app      # backend + frontend running
kubectl get pods -n ldap-2fa     # postgresql-0 running
kubectl get pods -n ldap         # openldap-stack-ha-{0,1,2} running

# All secrets present with non-empty values
kubectl get secret admin-seed-secret -n 2fa-app \
  -o jsonpath='{.data}' | python3 -c \
  "import sys,json,base64; data=json.load(sys.stdin); \
   [print(f'{k}: (set, {len(base64.b64decode(v))} bytes)') for k,v in data.items()]"
kubectl get secret ldap-admin-secret -n 2fa-app \
  -o jsonpath='{.data}' | python3 -c \
  "import sys,json,base64; data=json.load(sys.stdin); \
   [print(f'{k}: (set, {len(base64.b64decode(v))} bytes)') for k,v in data.items()]"
kubectl get secret postgresql-secret -n 2fa-app \
  -o jsonpath='{.data}' | python3 -c \
  "import sys,json,base64; data=json.load(sys.stdin); \
   [print(f'{k}: (set, {len(base64.b64decode(v))} bytes)') for k,v in data.items()]"
```

**Action**: Reproduced the failure by running a debug pod with the exact same
image and environment as the seed job:

```bash
kubectl run admin-seed-debug \
  --image=<ECR_REGISTRY>/<ECR_REPO>:<BACKEND_IMAGE_TAG> \
  --namespace=2fa-app --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "admin-seed-debug",
        "image": "<ECR_REGISTRY>/<ECR_REPO>:<BACKEND_IMAGE_TAG>",
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
          {"name": "LDAP_REPLICA_COUNT", "value": "3"}
        ]
      }]
    }
  }'

# Wait for pod to complete, then read logs
sleep 15 && kubectl logs admin-seed-debug -n 2fa-app
```

**Finding**: Every LDAP pod connection failed with `invalid server address`:

```text
LDAP error ensuring directory structure: invalid server address
[openldap-stack-ha-0.openldap-stack-ha.ldap.svc.cluster.local] Failed ...
[openldap-stack-ha-1.openldap-stack-ha.ldap.svc.cluster.local] Failed ...
[openldap-stack-ha-2.openldap-stack-ha.ldap.svc.cluster.local] Failed ...
```

**Action**: Checked services in the `ldap` namespace:

```bash
kubectl get svc -n ldap
```

Revealed two services:

- `openldap-stack-ha` — ClusterIP (`172.20.x.x`), the regular service
- `openldap-stack-ha-headless` — ClusterIP `None`, the **headless** service

**Action**: Confirmed DNS resolution from within the cluster:

```bash
kubectl run dns-test \
  --image=<BACKEND_IMAGE> \
  --namespace=2fa-app --restart=Never \
  --command -- python -c "
import socket
for i in range(3):
    h = f'openldap-stack-ha-{i}.openldap-stack-ha-headless.ldap.svc.cluster.local'
    try:
        ip = socket.getaddrinfo(h, 389)[0][4][0]
        print(f'OK: {h} -> {ip}')
    except Exception as e:
        print(f'FAIL: {h} -> {e}')
print()
for i in range(3):
    h_bad = f'openldap-stack-ha-{i}.openldap-stack-ha.ldap.svc.cluster.local'
    try:
        ip = socket.getaddrinfo(h_bad, 389)[0][4][0]
        print(f'OK: {h_bad} -> {ip}')
    except Exception as e:
        print(f'FAIL: {h_bad} -> {e}')
"
sleep 10 && kubectl logs dns-test -n 2fa-app
```

Result:

```text
OK: openldap-stack-ha-0.openldap-stack-ha-headless.ldap.svc.cluster.local -> 10.0.6.194
OK: openldap-stack-ha-1.openldap-stack-ha-headless.ldap.svc.cluster.local -> 10.0.3.192
OK: openldap-stack-ha-2.openldap-stack-ha-headless.ldap.svc.cluster.local -> 10.0.25.80

FAIL: openldap-stack-ha-0.openldap-stack-ha.ldap.svc.cluster.local -> Name or service not known
FAIL: openldap-stack-ha-1.openldap-stack-ha.ldap.svc.cluster.local -> Name or service not known
FAIL: openldap-stack-ha-2.openldap-stack-ha.ldap.svc.cluster.local -> Name or service not known
```

**Root Cause**: `_get_pod_hostnames()` in `seed_admin.py` constructed pod DNS
names using the ClusterIP service (`openldap-stack-ha`), but Kubernetes
StatefulSet pod DNS requires the **headless** service
(`openldap-stack-ha-headless`). The Helm chart creates the headless service
with the naming convention `{release}-headless`.

**Cleanup**: Always delete debug pods after investigation:

```bash
kubectl delete pod admin-seed-debug -n 2fa-app --grace-period=0
kubectl delete pod dns-test -n 2fa-app --grace-period=0
```

## Root Causes

### 1. OpenLDAP Multi-Master Replication Not Working

The jp-gouin/helm-openldap chart with osixia/openldap doesn't automatically
replicate data across pods. Each pod initializes independently with an empty
directory (except for the base DN).

**Why this happens**:

- The osixia/openldap image auto-generates a base DN on first startup
- Replication configuration exists but doesn't sync initial data
- No LDIF files were configured to create the organizational structure

### 2. Missing Directory Structure Initialization

The OpenLDAP Helm chart doesn't automatically create:

- `ou=users` - organizational unit for user entries
- `ou=groups` - organizational unit for group entries
- `cn=admins,ou=groups` - admin group for 2FA application authorization

### 3. LDAPClient Using Wrong Group Membership Attribute

The `LDAPClient.add_user_to_group()` method used `member` attribute for all
groups, but `groupOfUniqueNames` requires `uniqueMember`.

### 4. seed_admin.py Not Handling Existing Users

The original `seed_admin.py` called `ldap_client.create_user()` which fails
if the user already exists, instead of updating the existing user.

### 5. Pod Hostnames Using ClusterIP Service Instead of Headless Service

The `_get_pod_hostnames()` function in `seed_admin.py` derived StatefulSet pod
DNS names from `LDAP_HOST` (the ClusterIP service), producing:

```text
openldap-stack-ha-{i}.openldap-stack-ha.ldap.svc.cluster.local  (wrong)
```

Kubernetes StatefulSet pods are only addressable via the headless service:

```text
openldap-stack-ha-{i}.openldap-stack-ha-headless.ldap.svc.cluster.local  (correct)
```

The `ldap3` library raised `invalid server address` because DNS resolution
failed for the non-existent ClusterIP-based hostnames.

### 6. Image Tag Defaulting to "latest"

The `backend_image_tag` variable defaulted to `"latest"` which doesn't exist
in ECR since build workflows use commit-based tags.

## Ad-Hoc Manual Corrections

### Adding Directory Structure to All Pods

```bash
# Set credentials
LDAP_ADMIN_PASSWORD=$(kubectl get secret -n ldap openldap-secret \
  -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)

# Create ou=users on all pods
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  kubectl exec -n ldap $pod -- ldapadd -x -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" <<EOF
dn: ou=users,dc=ldap,dc=talorlik,dc=internal
objectClass: organizationalUnit
ou: users
EOF
done

# Create ou=groups on all pods
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  kubectl exec -n ldap $pod -- ldapadd -x -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" <<EOF
dn: ou=groups,dc=ldap,dc=talorlik,dc=internal
objectClass: organizationalUnit
ou: groups
EOF
done

# Create cn=admins group on all pods (with placeholder uniqueMember)
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  kubectl exec -n ldap $pod -- ldapadd -x -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" <<EOF
dn: cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal
objectClass: groupOfUniqueNames
cn: admins
uniqueMember: cn=admin,dc=ldap,dc=talorlik,dc=internal
EOF
done
```

### Adding Admin User to Pod Missing It

```bash
# Check which pod is missing the admin user
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  echo "=== $pod ==="
  kubectl exec -n ldap $pod -- ldapsearch -x -LLL -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" \
    -b "ou=users,dc=ldap,dc=talorlik,dc=internal" \
    "(uid=admin)" dn 2>/dev/null || echo "User not found"
done

# Add user to pod-2 (was missing)
kubectl exec -n ldap openldap-stack-ha-2 -- ldapadd -x -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
  -w "$LDAP_ADMIN_PASSWORD" <<EOF
dn: uid=admin,ou=users,dc=ldap,dc=talorlik,dc=internal
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
cn: Admin
sn: User
givenName: Admin
uid: admin
mail: admin@example.com
userPassword: {SSHA}...
EOF
```

### Seeding Admin User in PostgreSQL

```bash
# Exec into backend pod
kubectl exec -it -n 2fa-app deploy/ldap-2fa-backend -- /bin/bash

# Run seed script manually (inside container)
python -m app.seed_admin
```

## Permanent Code Fixes

### 1. LDAPClient Improvements (commit 8efa064)

**File**: `application/backend/src/app/ldap/client.py`

Added methods to handle group membership correctly:

```python
def _get_group_object_class(self, group_dn: str) -> str:
    """Detect group objectClass to use correct membership attribute."""
    # Returns 'groupOfUniqueNames', 'groupOfNames', or 'posixGroup'

def update_user(self, username: str, attributes: Dict[str, Any]) -> bool:
    """Update existing user attributes."""

def create_or_update_user(self, username: str, ...) -> Tuple[bool, str]:
    """Idempotent user creation - creates or updates."""
```

Fixed `add_user_to_group()` and `remove_user_from_group()` to detect group
objectClass and use the correct membership attribute:

- `groupOfUniqueNames` → `uniqueMember`
- `groupOfNames` → `member`
- `posixGroup` → `memberUid`

### 2. seed_admin.py Idempotent Seeding (commit 8efa064)

**File**: `application/backend/src/app/seed_admin.py`

Changed from `create_user()` to `create_or_update_user()` so the seed job
doesn't fail if the user already exists.

### 3. OpenLDAP Directory Initialization (commit 8efa064)

**File**: `application_infra/helm/openldap-values.tpl.yaml`

Added `customLdifFiles` to auto-create directory structure on all pods:

```yaml
customLdifFiles:
  01-organizational-units.ldif: |-
    dn: ou=users,${openldap_base_dn}
    objectClass: organizationalUnit
    ou: users

    dn: ou=groups,${openldap_base_dn}
    objectClass: organizationalUnit
    ou: groups

  02-admin-group.ldif: |-
    dn: cn=admins,ou=groups,${openldap_base_dn}
    objectClass: groupOfUniqueNames
    cn: admins
    uniqueMember: cn=admin,${openldap_base_dn}
```

### 4. Headless Service DNS Fix

**Files**:

- `application/backend/src/app/seed_admin.py`
- `application_infra/modules/openldap/outputs.tf`
- `application_infra/outputs.tf`
- `application/main.tf`

Fixed `_get_pod_hostnames()` to construct pod DNS names using the headless
service. The function now:

1. Reads `LDAP_HEADLESS_HOST` env var if set (explicit, preferred)
2. Falls back to deriving from `LDAP_HOST` by appending `-headless` to the
   service name component (standard Helm naming convention)

Terraform changes:

- Added `ldap_headless_host` output to the OpenLDAP module
  (`{release}-headless.{namespace}.svc.cluster.local`)
- Forwarded through `application_infra` outputs
- Passed as `LDAP_HEADLESS_HOST` env var to the `kubernetes_job.admin_seed`
  resource in `application/main.tf`

### 5. Image Tag Validation (commit 6205806)

**Files**: `application/variables.tf`, `application/main.tf`,
`application/setup-application.sh`, `.github/workflows/application_provisioning.yaml`

- Variable validation rejects `"latest"` tag
- Lifecycle precondition on admin-seed job requires non-empty tag
- Scripts/workflows fail early with helpful error if tag extraction fails

### 5. Destroy Script/Workflow Fix (commit b271312)

**Files**: `application/destroy-application.sh`,
`.github/workflows/application_destroying.yaml`

Changed fallback from `"latest"` to empty string for destroy operations
(empty string passes validation and is acceptable for destroy).

## Verification Steps

### Verify LDAP Directory Structure

```bash
# Check all pods have the directory structure
for pod in openldap-stack-ha-0 openldap-stack-ha-1 openldap-stack-ha-2; do
  echo "=== $pod ==="
  kubectl exec -n ldap $pod -- ldapsearch -x -LLL -H ldap://localhost:389 \
    -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
    -w "$LDAP_ADMIN_PASSWORD" \
    -b "dc=ldap,dc=talorlik,dc=internal" \
    "(objectClass=*)" dn 2>/dev/null
done
```

Expected output for each pod:

```text
dn: dc=ldap,dc=talorlik,dc=internal
dn: ou=users,dc=ldap,dc=talorlik,dc=internal
dn: ou=groups,dc=ldap,dc=talorlik,dc=internal
dn: cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal
```

### Verify Admin User in LDAP

```bash
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x -LLL \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
  -w "$LDAP_ADMIN_PASSWORD" \
  -b "uid=admin,ou=users,dc=ldap,dc=talorlik,dc=internal" \
  "(objectClass=*)"
```

### Verify Admin User in PostgreSQL

```bash
kubectl exec -it -n 2fa-app deploy/ldap-2fa-backend -- \
  python -c "
from app.database.connection import SessionLocal
from app.database.models import User
with SessionLocal() as db:
    user = db.query(User).filter(User.username == 'admin').first()
    if user:
        print(f'Username: {user.username}')
        print(f'Email: {user.email}')
        print(f'Status: {user.status}')
        print(f'MFA Method: {user.mfa_method}')
    else:
        print('Admin user not found')
"
```

### Verify Admin Group Membership

```bash
kubectl exec -n ldap openldap-stack-ha-0 -- ldapsearch -x -LLL \
  -H ldap://localhost:389 \
  -D "cn=admin,dc=ldap,dc=talorlik,dc=internal" \
  -w "$LDAP_ADMIN_PASSWORD" \
  -b "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal" \
  "(objectClass=*)" uniqueMember
```

Expected to include:

```text
uniqueMember: uid=admin,ou=users,dc=ldap,dc=talorlik,dc=internal
```

## Lessons Learned

1. **OpenLDAP Multi-Master Replication Limitations**: The jp-gouin/helm-openldap
   chart doesn't guarantee data sync across pods for initial data. Use
   `customLdifFiles` to ensure all pods have the same base structure.

2. **Group ObjectClass Matters**: Different group objectClasses use different
   membership attributes. Always detect the objectClass before modifying
   group membership.

3. **Idempotent Operations**: Seed jobs should be idempotent - check if
   resources exist before creating, or use create-or-update operations.

4. **ECR Tag Strategy**: Build workflows should document the tagging strategy.
   Using `:latest` in deployment when builds use commit-based tags will fail.

5. **Validation at Multiple Levels**: Add validation in variables (Terraform),
   preconditions (resources), and scripts (early fail) to catch configuration
   errors before they cause deployment failures.

6. **Test Across All Replicas**: When using multi-master replication, verify
   data exists on all pods, not just the one returned by the service.

7. **StatefulSet Pod DNS Requires Headless Service**: Individual StatefulSet
   pods are only addressable via the headless service
   (`{pod}.{headless-svc}.{ns}.svc.cluster.local`), not the ClusterIP service.
   When a Helm chart creates both, pass the headless service hostname
   explicitly rather than assuming the service name matches `LDAP_HOST`.

8. **Reproduce With Debug Pods When Logs Are Gone**: When a Job pod has been
   cleaned up (TTL or backoff), run a one-off debug pod with the same image,
   `envFrom`, and `env` to reproduce the error and capture logs. Always
   clean up debug pods afterwards.

## Related Files

- `application/backend/src/app/ldap/client.py` - LDAPClient with group
  handling
- `application/backend/src/app/seed_admin.py` - Admin user seeding script
- `application_infra/helm/openldap-values.tpl.yaml` - OpenLDAP Helm values
  with customLdifFiles
- `application_infra/modules/openldap/main.tf` - OpenLDAP module
- `application/variables.tf` - Image tag validation
- `application/main.tf` - Admin-seed job definition (includes `LDAP_HEADLESS_HOST`)
- `application_infra/outputs.tf` - Exposes `ldap_headless_host` from OpenLDAP module

## References

- [OpenLDAP Admin Guide](https://www.openldap.org/doc/admin26/)
- [osixia/openldap Docker Image](https://github.com/osixia/docker-openldap)
- [jp-gouin/helm-openldap Chart](https://github.com/jp-gouin/helm-openldap)
- [LDAP objectClass Reference](https://ldap.com/object-classes/)

## Related Documentation

- [Troubleshooting Index](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/INDEX.md)
- [Application Infrastructure Deployment](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/deployment/APPLICATION_INFRA_DEPLOYMENT.md)
- [Debug Commands](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/reference/DEBUG_COMMANDS.md)
- [Application Layer Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_layer/APPLICATION_LAYER.md)
