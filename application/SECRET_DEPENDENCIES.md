# Secret Dependencies

This document outlines which components require which secrets to operate correctly.

## Secret Overview

There are three main secrets used in the application deployment:

1. **`postgresql-secret`** - PostgreSQL database password
2. **`redis-secret`** - Redis authentication password
3. **`ldap-admin-secret`** - LDAP admin password for backend authentication

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
5. **ArgoCD Backend Application** is registered (depends on all secrets existing)

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
kubectl get secrets -n 2fa-app | grep -E "postgresql-secret|redis-secret|ldap-admin-secret"

# Verify backend pod can access secrets
kubectl describe pod -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend | grep -A 10 "Environment:"
```
