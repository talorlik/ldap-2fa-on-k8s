# Redis and SMS 2FA Enablement Summary

## Changes Made

### ✅ Backend Helm Chart Values (`application/backend/helm/ldap-2fa-backend/values.yaml`)

1. **SMS 2FA Enabled:**

    ```yaml
    sms:
      enabled: true  # Changed from false
    ```

2. **Redis Enabled:**

    ```yaml
    redis:
      enabled: true  # Changed from false
      existingSecret:
        enabled: true  # Changed from false
    ```

## Already Configured (No Changes Needed)

### ✅ Terraform Configuration (`application/variables.tfvars`)

- `enable_redis = true` ✅ Already enabled
- `enable_sms_2fa = true` ✅ Already enabled
- Redis infrastructure will be deployed

### ✅ Backend Code

- Redis client implementation exists (`app/redis/client.py`)
- SMS OTP endpoints support Redis (`routes.py`)
- Automatic fallback to in-memory storage if Redis unavailable
- All Redis environment variables configured in ConfigMap

### ✅ Infrastructure Dependencies

- Redis module configured and ready
- Redis secret will be created in backend namespace
- Network policies allow backend → Redis communication
- SNS module configured for SMS delivery

## What Happens Next

### When You Deploy

1. **Terraform will:**
    - Deploy Redis infrastructure (if not already deployed)
    - Create `redis-secret` in `redis` namespace
    - Copy `redis-secret` to `2fa-app` namespace (backend namespace)
    - Ensure all secrets exist before ArgoCD registration

2. **ArgoCD will:**
    - Sync backend application with new Helm values
    - Backend pods will:
      - Have `REDIS_ENABLED=true` environment variable
      - Have `REDIS_PASSWORD` from secret injected
      - Connect to Redis at `redis-master.redis.svc.cluster.local:6379`
      - Use Redis for SMS OTP code storage

3. **Backend Application will:**
    - Enable SMS 2FA endpoints (`/auth/sms/send-code`, `/auth/login/verify` with
    SMS)
    - Store SMS OTP codes in Redis with TTL expiration
    - Retrieve SMS codes from Redis during login verify step
    - Use AWS SNS to send SMS messages

## Verification Steps

### 1. Verify Redis Infrastructure

```bash
# Check Redis pods are running
kubectl get pods -n redis -l app.kubernetes.io/name=redis

# Check Redis secret exists
kubectl get secret redis-secret -n redis
kubectl get secret redis-secret -n 2fa-app

# Test Redis connectivity
kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD ping
```

### 2. Verify Backend Configuration

```bash
# Check backend pods have Redis environment variables
kubectl exec -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend -- env | grep REDIS

# Expected output:
# REDIS_ENABLED=true
# REDIS_HOST=redis-master.redis.svc.cluster.local
# REDIS_PORT=6379
# REDIS_PASSWORD=<password>
# REDIS_DB=0
# REDIS_SSL=false
# REDIS_KEY_PREFIX=sms_otp:

# Check backend logs for Redis connection
kubectl logs -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend | grep -i redis

# Expected: "Redis connected successfully to redis-master.redis.svc.cluster.local:6379"
```

### 3. Verify SMS 2FA Configuration

```bash
# Check SMS environment variables
kubectl exec -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend -- env | grep SMS

# Expected output:
# ENABLE_SMS_2FA=true
# SMS_CODE_LENGTH=6
# SMS_CODE_EXPIRY_SECONDS=300
# SMS_SENDER_ID=2FA
# SMS_TYPE=Transactional
```

### 4. Test SMS 2FA Flow (two-step login)

1. **Step 1 – Login start (username and password):**

    ```bash
    curl -X POST https://app.talorlik.com/api/auth/login/start \
      -H "Content-Type: application/json" \
      -d '{"username": "testuser", "password": "password", "remember_me": false}'
    ```

    Response includes `challenge_token`, `totp_enrolled`, `sms_available`.
    Optional `remember_me: true` requests a longer-lived JWT after step 2.

2. **Request SMS code (with challenge token from step 1):**

    ```bash
    curl -X POST https://app.talorlik.com/api/auth/sms/send-code \
      -H "Content-Type: application/json" \
      -d '{"challenge_token": "<challenge_token from step 1>"}'
    ```

3. **Verify code stored in Redis:**

    ```bash
    kubectl exec -it -n redis redis-master-0 -- redis-cli -a $REDIS_PASSWORD KEYS "sms_otp:*"
    ```

4. **Step 2 – Login verify (complete login with SMS code):**

    ```bash
    curl -X POST https://app.talorlik.com/api/auth/login/verify \
      -H "Content-Type: application/json" \
      -d '{"challenge_token": "<challenge_token>", "mfa_method": "sms", "verification_code": "123456"}'
    ```

    Response includes JWT `token`.

## Troubleshooting

### Redis Connection Issues

**Problem:** Backend logs show "Failed to connect to Redis"

**Solutions:**

1. Verify Redis pod is running:

    ```bash
    kubectl get pods -n redis
    ```

2. Check network policy allows backend → Redis:

    ```bash
    kubectl get networkpolicy -n redis
    ```

3. Verify Redis secret exists:

    ```bash
    kubectl get secret redis-secret -n 2fa-app
    ```

4. Check Redis password is correct:

    ```bash
    kubectl get secret redis-secret -n 2fa-app -o jsonpath='{.data.redis-password}' | base64 -d
    ```

### SMS Not Sending

**Problem:** SMS codes not being sent

**Solutions:**

1. Verify SNS module is deployed:

    ```bash
    terraform output -json | jq '.sns_topic_arn'
    ```

2. Check backend service account has IRSA role:

    ```bash
    kubectl get sa ldap-2fa-backend -n 2fa-app -o yaml
    ```

3. Verify AWS SNS permissions in IAM role
4. Check backend logs for SNS errors:

    ```bash
    kubectl logs -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend | grep -i sns
    ```

### OTP Codes Not Stored in Redis

**Problem:** Codes stored in-memory instead of Redis

**Solutions:**

1. Verify `REDIS_ENABLED=true` in backend pod:

    ```bash
    kubectl exec -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend -- env | grep REDIS_ENABLED
    ```

2. Check Redis connection in logs:

    ```bash
    kubectl logs -n 2fa-app -l app.kubernetes.io/name=ldap-2fa-backend | grep -i "redis connected"
    ```

3. Verify Redis secret is enabled: Check Helm values

    ```yaml
    redis.existingSecret.enabled: true
    ```

## Rollback

If you need to disable Redis/SMS 2FA:

1. **Update Helm values:**

    ```yaml
    sms:
      enabled: false
    redis:
      enabled: false
      existingSecret:
        enabled: false
    ```

2. **Redeploy backend:**
    - If using ArgoCD: Values will sync automatically
    - If using Helm directly:

    ```bash
    helm upgrade ldap-2fa-backend ./helm/ldap-2fa-backend
    ```

3. **Backend will automatically fallback to in-memory storage** for any pending
SMS codes

## Notes

- Redis infrastructure remains deployed even if backend disables it
(controlled by Terraform `enable_redis`)
- Backend gracefully falls back to in-memory storage if Redis is unavailable
- SMS 2FA requires AWS SNS to be configured and working
- Redis persistence ensures OTP codes survive pod restarts
- TTL-based expiration automatically cleans up expired codes
