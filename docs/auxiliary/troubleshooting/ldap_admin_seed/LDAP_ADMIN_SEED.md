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

### 5. Image Tag Defaulting to "latest"

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

### 4. Image Tag Validation (commit 6205806)

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

## Related Files

- `application/backend/src/app/ldap/client.py` - LDAPClient with group
  handling
- `application/backend/src/app/seed_admin.py` - Admin user seeding script
- `application_infra/helm/openldap-values.tpl.yaml` - OpenLDAP Helm values
  with customLdifFiles
- `application_infra/modules/openldap/main.tf` - OpenLDAP module
- `application/variables.tf` - Image tag validation
- `application/main.tf` - Admin-seed job definition

## References

- [OpenLDAP Admin Guide](https://www.openldap.org/doc/admin26/)
- [osixia/openldap Docker Image](https://github.com/osixia/docker-openldap)
- [jp-gouin/helm-openldap Chart](https://github.com/jp-gouin/helm-openldap)
- [LDAP objectClass Reference](https://ldap.com/object-classes/)

## Related Documentation

- [Troubleshooting Index](../INDEX.md)
- [Application Infrastructure Deployment](../deployment/APPLICATION_INFRA_DEPLOYMENT.md)
- [Debug Commands](../reference/DEBUG_COMMANDS.md)
- [Application Layer Troubleshooting](../application_layer/APPLICATION_LAYER.md)
