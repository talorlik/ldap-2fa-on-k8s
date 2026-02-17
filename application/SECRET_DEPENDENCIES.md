# Secret Dependencies

This document outlines which components require which secrets to operate correctly.

## Secret Overview

There are three main secrets used in the application deployment, plus an optional
one for first-admin seed:

1. **`postgresql-secret`** - PostgreSQL database password
2. **`redis-secret`** - Redis authentication password
3. **`ldap-admin-secret`** - LDAP admin password for backend authentication
4. **`admin-seed-secret`** (optional) - First admin user profile (username, email,
name, phone). When set with all required keys, a one-time Job seeds the first admin
so they can log in with the same username/password as LDAP. See [SECRETS_REQUIREMENTS.md](../SECRETS_REQUIREMENTS.md).

## Component Dependencies

### 1. PostgreSQL Module (`application/modules/postgresql`)

**Required Secret:** `postgresql-secret`

**Location:** Created in `ldap-2fa` namespace

**Usage:**

- The PostgreSQL Helm chart (Bitnami) requires this secret to authenticate the database
- Secret key: `password`
- Referenced in `helm/postgresql-values.tpl.yaml`:

  ```yaml
  auth:
    existingSecret: "${secret_name}"
    existingSecretPasswordKey: "password"
  ```

**Critical:** Without this secret, PostgreSQL pods will fail to start because they
cannot authenticate.

### 2. Redis Module (`application/modules/redis`)

**Required Secret:** `redis-secret`

**Location:** Created in `redis` namespace

**Usage:**

- The Redis Helm chart (Bitnami) requires this secret for authentication
- Secret key: `redis-password`
- Referenced in `helm/redis-values.tpl.yaml`:

  ```yaml
  auth:
    enabled: true
    existingSecret: "${secret_name}"
    existingSecretPasswordKey: "redis-password"
  ```

**Critical:** Without this secret, Redis pods will fail to start because authentication
is enabled.

### 3. Backend Application (`application/backend`)

**Required Secrets:** All three secrets are required

**Location:** All secrets must exist in the backend namespace (`2fa-app`)

#### 3.1 `ldap-admin-secret`

**Usage:**

- Backend application uses this to authenticate with LDAP for user lookups
- Secret key: `LDAP_ADMIN_PASSWORD`
- Referenced in `backend/helm/ldap-2fa-backend/templates/deployment.yaml`:

  ```yaml
  - name: LDAP_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: ldap-admin-secret
        key: LDAP_ADMIN_PASSWORD
  ```

**Creation:**

- Created by Terraform in the `2fa-app` namespace
- **Password source:** Terraform reads the password from the OpenLDAP secret (`openldap-secret`)
in the `ldap` namespace to ensure consistency
- **Fallback:** If the OpenLDAP secret doesn't exist, Terraform falls back to
`TF_VAR_OPENLDAP_ADMIN_PASSWORD` variable (useful during initial deployment)
- **Configuration:** Secret name and namespace can be customized via `openldap_secret_name`
and `openldap_namespace` variables (defaults: `openldap-secret` and `ldap`)

> [!IMPORTANT]
>
> **Password Consistency:** This approach ensures the backend always uses the same
> password as OpenLDAP was initialized with, preventing password mismatches that
> would cause LDAP authentication failures (e.g., `admin-seed-job` failures).

**Critical:** Without this secret, the backend cannot authenticate with LDAP and
will fail to:

- Look up users
- Create new users
- Verify user credentials
- Perform any LDAP operations

#### 3.2 `postgresql-secret`

**Usage:**

- Backend application uses this to construct the PostgreSQL connection URL
- Secret key: `password`
- Referenced in `backend/helm/ldap-2fa-backend/templates/deployment.yaml`:

  ```yaml
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: postgresql-secret
        key: password
  ```

**Critical:** Without this secret, the backend cannot:

- Connect to PostgreSQL database
- Store user registration data
- Store email verification tokens
- Perform any database operations

#### 3.3 `redis-secret` (Conditional)

**Usage:**

- Backend application uses this only if SMS 2FA is enabled (`redis.enabled: true`)
- Secret key: `redis-password`
- Referenced in `backend/helm/ldap-2fa-backend/templates/deployment.yaml`:

  ```yaml
  {{- if .Values.redis.existingSecret.enabled }}
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-secret
        key: redis-password
  {{- end }}
  ```

**Critical (when SMS enabled):** Without this secret, the backend cannot:

- Connect to Redis for SMS OTP storage
- Store SMS verification codes
- Retrieve SMS verification codes
- SMS 2FA functionality will fail

#### 3.4 `admin-seed-secret` (Optional)

**Usage:**

- Used only when first admin seed is enabled (all `ADMIN_SEED_*` variables set in
Terraform).
- The one-time `admin-seed-job` reads this secret and `ldap-admin-secret` to create
the LDAP user, add them to the admins group, and upsert the PostgreSQL user with
email/phone pre-verified.
- Secret keys: `ADMIN_SEED_USERNAME`, `ADMIN_SEED_EMAIL`, `ADMIN_SEED_FIRST_NAME`,
`ADMIN_SEED_LAST_NAME`, `ADMIN_SEED_PHONE_COUNTRY_CODE`, `ADMIN_SEED_PHONE_NUMBER`.
- Created by Terraform in the backend namespace when admin seed variables are provided
(e.g. from GitHub Secrets or AWS `tf-vars`).

**Optional:** If not set, no first admin is seeded; you can still create users via
signup and approve them with an existing admin.

### 4. Frontend Application (`application/frontend`)

**Required Secrets:** None

**Usage:**

- The frontend is a static application that communicates with the backend via
HTTP API
- It does not require direct access to any secrets
- All authentication and data operations are handled by the backend

## Deployment Order Requirements

To ensure all components operate correctly, secrets must be deployed in this order:

1. **PostgreSQL Module** creates `postgresql-secret` in `ldap-2fa` namespace
2. **Redis Module** creates `redis-secret` in `redis` namespace
3. **Backend Namespace** is created (`2fa-app`)
4. **Secrets are copied** to backend namespace:

    - `postgresql-secret` → copied to `2fa-app` namespace
    - `redis-secret` → copied to `2fa-app` namespace (if Redis enabled)
    - `ldap-admin-secret` → created in `2fa-app` namespace
    (password read from OpenLDAP secret in `ldap` namespace)
    - `admin-seed-secret` → created in `2fa-app` namespace (optional; when admin
    seed vars are set)
5. **ArgoCD Backend Application** is registered (depends on all secrets existing)
6. **admin-seed Job** runs once (when admin-seed-secret exists) to seed the first
admin user

## Failure Scenarios

### Missing `postgresql-secret` in backend namespace

- **Symptom:** Backend pods fail to start with database connection errors
- **Error:** `FATAL: password authentication failed` or `could not connect to server`
- **Impact:** Complete backend failure - no user registration, no data storage

### Missing `ldap-admin-secret` in backend namespace

- **Symptom:** Backend pods start but fail LDAP operations
- **Error:** `Invalid credentials` or `LDAP bind failed`
- **Impact:** Cannot authenticate users, cannot create users, LDAP operations fail

### Missing `redis-secret` in backend namespace (when SMS enabled)

- **Symptom:** Backend pods start but SMS 2FA fails
- **Error:** `NOAUTH Authentication required` or Redis connection errors
- **Impact:** SMS 2FA functionality broken, but other features work

### Missing secrets in PostgreSQL/Redis namespaces

- **Symptom:** PostgreSQL/Redis pods fail to start
- **Error:** Pods crash with authentication errors
- **Impact:** Complete failure of database/cache services

## Verification

To verify all secrets are correctly deployed:

```bash
# Check PostgreSQL secret in ldap-2fa namespace
kubectl get secret postgresql-secret -n ldap-2fa

# Check Redis secret in redis namespace
kubectl get secret redis-secret -n redis

# Check all secrets in backend namespace
kubectl get secrets -n 2fa-app | grep -E "postgresql-secret|redis-secret|ldap-admin-secret|admin-seed-secret"

# Verify backend pod can access secrets
kubectl describe pod -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend | grep -A 10 "Environment:"
```
