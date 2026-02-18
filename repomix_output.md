This file is a merged representation of the entire codebase, combined into a single document by Repomix.
The content has been processed where empty lines have been removed, line numbers have been added.

# File Summary

## Purpose
This file contains a packed representation of the entire repository's contents.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Empty lines have been removed from all files
- Line numbers have been added to the beginning of each line
- Files are sorted by Git change count (files with more changes are at the bottom)

# Directory Structure
```
.github/
  workflows/
    application_infra_destroying.yaml
    application_infra_provisioning.yaml
    backend_build_push.yaml
    backend_infra_destroying.yaml
    backend_infra_provisioning.yaml
    frontend_build_push.yaml
    tfstate_infra_destroying.yaml
    tfstate_infra_provisioning.yaml
application/
  backend/
    helm/
      ldap-2fa-backend/
        templates/
          tests/
            test-connection.yaml
          _helpers.tpl
          configmap.yaml
          deployment.yaml
          hpa.yaml
          ingress.yaml
          NOTES.txt
          secret.yaml
          service.yaml
          serviceaccount.yaml
        .helmignore
        Chart.yaml
        values.yaml
    src/
      app/
        api/
          __init__.py
          routes.py
        database/
          __init__.py
          connection.py
          models.py
        email/
          __init__.py
          client.py
        ldap/
          __init__.py
          client.py
        mfa/
          __init__.py
          totp.py
        redis/
          __init__.py
          client.py
        sms/
          __init__.py
          client.py
        config.py
        main.py
      requirements.txt
    Dockerfile
  frontend/
    helm/
      ldap-2fa-frontend/
        templates/
          tests/
            test-connection.yaml
          _helpers.tpl
          deployment.yaml
          hpa.yaml
          ingress.yaml
          NOTES.txt
          service.yaml
          serviceaccount.yaml
        .helmignore
        Chart.yaml
        values.yaml
    src/
      css/
        styles.css
      js/
        api.js
        main.js
      index.html
    Dockerfile
    nginx.conf
  helm/
    openldap-values.tpl.yaml
    postgresql-values.tpl.yaml
    redis-values.tpl.yaml
  modules/
    alb/
      main.tf
      outputs.tf
      variables.tf
    argocd/
      main.tf
      outputs.tf
      variables.tf
    argocd_app/
      main.tf
      outputs.tf
      variables.tf
    cert-manager/
      main.tf
      outputs.tf
      variables.tf
    network-policies/
      main.tf
      outputs.tf
      variables.tf
    openldap/
      main.tf
      outputs.tf
      variables.tf
    postgresql/
      main.tf
      outputs.tf
      variables.tf
    redis/
      main.tf
      outputs.tf
      variables.tf
    route53/
      main.tf
      outputs.tf
      variables.tf
    route53_record/
      main.tf
      outputs.tf
      providers.tf
      variables.tf
    ses/
      main.tf
      outputs.tf
      providers.tf
      variables.tf
    sns/
      main.tf
      outputs.tf
      variables.tf
  destroy-application.sh
  main.tf
  mirror-images-to-ecr.sh
  outputs.tf
  providers.tf
  set-k8s-env.sh
  setup-application.sh
  tfstate-backend-values-template.hcl
  variables.tf
backend_infra/
  modules/
    ebs/
      main.tf
      outputs.tf
      variables.tf
    ecr/
      main.tf
      outputs.tf
      variables.tf
    endpoints/
      main.tf
      outputs.tf
      variables.tf
  destroy-backend.sh
  main.tf
  outputs.tf
  providers.tf
  setup-backend.sh
  tfstate-backend-values-template.hcl
  variables.tf
docs/
  dark-theme.css
  favicon.ico
  header_banner.png
  index.html
  light-theme.css
tf_backend_state/
  get-state.sh
  main.tf
  outputs.tf
  providers.tf
  set-state.sh
  variables.tf
.gitignore
repomix.config.json
```

# Files

## File: application/backend/helm/ldap-2fa-backend/templates/tests/test-connection.yaml
```yaml
 1: apiVersion: v1
 2: kind: Pod
 3: metadata:
 4:   name: "{{ include "ldap-2fa-backend.fullname" . }}-test-connection"
 5:   labels:
 6:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 7:   annotations:
 8:     "helm.sh/hook": test
 9: spec:
10:   containers:
11:     - name: wget
12:       image: busybox
13:       command: ['wget']
14:       args: ['{{ include "ldap-2fa-backend.fullname" . }}:{{ .Values.service.port }}']
15:   restartPolicy: Never
```

## File: application/backend/helm/ldap-2fa-backend/templates/_helpers.tpl
```
 1: {{/*
 2: Expand the name of the chart.
 3: */}}
 4: {{- define "ldap-2fa-backend.name" -}}
 5: {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
 6: {{- end }}
 7:
 8: {{/*
 9: Create a default fully qualified app name.
10: We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
11: If release name contains chart name it will be used as a full name.
12: */}}
13: {{- define "ldap-2fa-backend.fullname" -}}
14: {{- if .Values.fullnameOverride }}
15: {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
16: {{- else }}
17: {{- $name := default .Chart.Name .Values.nameOverride }}
18: {{- if contains $name .Release.Name }}
19: {{- .Release.Name | trunc 63 | trimSuffix "-" }}
20: {{- else }}
21: {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
22: {{- end }}
23: {{- end }}
24: {{- end }}
25:
26: {{/*
27: Create chart name and version as used by the chart label.
28: */}}
29: {{- define "ldap-2fa-backend.chart" -}}
30: {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
31: {{- end }}
32:
33: {{/*
34: Common labels
35: */}}
36: {{- define "ldap-2fa-backend.labels" -}}
37: helm.sh/chart: {{ include "ldap-2fa-backend.chart" . }}
38: {{ include "ldap-2fa-backend.selectorLabels" . }}
39: {{- if .Chart.AppVersion }}
40: app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
41: {{- end }}
42: app.kubernetes.io/managed-by: {{ .Release.Service }}
43: {{- end }}
44:
45: {{/*
46: Selector labels
47: */}}
48: {{- define "ldap-2fa-backend.selectorLabels" -}}
49: app.kubernetes.io/name: {{ include "ldap-2fa-backend.name" . }}
50: app.kubernetes.io/instance: {{ .Release.Name }}
51: {{- end }}
52:
53: {{/*
54: Create the name of the service account to use
55: */}}
56: {{- define "ldap-2fa-backend.serviceAccountName" -}}
57: {{- if .Values.serviceAccount.create }}
58: {{- default (include "ldap-2fa-backend.fullname" .) .Values.serviceAccount.name }}
59: {{- else }}
60: {{- default "default" .Values.serviceAccount.name }}
61: {{- end }}
62: {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/hpa.yaml
```yaml
 1: {{- if .Values.autoscaling.enabled }}
 2: apiVersion: autoscaling/v2
 3: kind: HorizontalPodAutoscaler
 4: metadata:
 5:   name: {{ include "ldap-2fa-backend.fullname" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 8: spec:
 9:   scaleTargetRef:
10:     apiVersion: apps/v1
11:     kind: Deployment
12:     name: {{ include "ldap-2fa-backend.fullname" . }}
13:   minReplicas: {{ .Values.autoscaling.minReplicas }}
14:   maxReplicas: {{ .Values.autoscaling.maxReplicas }}
15:   metrics:
16:     {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
17:     - type: Resource
18:       resource:
19:         name: cpu
20:         target:
21:           type: Utilization
22:           averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
23:     {{- end }}
24:     {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
25:     - type: Resource
26:       resource:
27:         name: memory
28:         target:
29:           type: Utilization
30:           averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
31:     {{- end }}
32: {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/ingress.yaml
```yaml
 1: {{- if .Values.ingress.enabled -}}
 2: apiVersion: networking.k8s.io/v1
 3: kind: Ingress
 4: metadata:
 5:   name: {{ include "ldap-2fa-backend.fullname" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 8:   {{- with .Values.ingress.annotations }}
 9:   annotations:
10:     {{- toYaml . | nindent 4 }}
11:   {{- end }}
12: spec:
13:   {{- with .Values.ingress.className }}
14:   ingressClassName: {{ . }}
15:   {{- end }}
16:   {{- if .Values.ingress.tls }}
17:   tls:
18:     {{- range .Values.ingress.tls }}
19:     - hosts:
20:         {{- range .hosts }}
21:         - {{ . | quote }}
22:         {{- end }}
23:       secretName: {{ .secretName }}
24:     {{- end }}
25:   {{- end }}
26:   rules:
27:     {{- range .Values.ingress.hosts }}
28:     - host: {{ .host | quote }}
29:       http:
30:         paths:
31:           {{- range .paths }}
32:           - path: {{ .path }}
33:             {{- with .pathType }}
34:             pathType: {{ . }}
35:             {{- end }}
36:             backend:
37:               service:
38:                 name: {{ include "ldap-2fa-backend.fullname" $ }}
39:                 port:
40:                   number: {{ $.Values.service.port }}
41:           {{- end }}
42:     {{- end }}
43: {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/NOTES.txt
```
 1: LDAP 2FA Backend API has been deployed!
 2:
 3: 1. Get the application URL:
 4: {{- if .Values.ingress.enabled }}
 5: {{- range $host := .Values.ingress.hosts }}
 6:   {{- range .paths }}
 7:   https://{{ $host.host }}{{ .path }}
 8:   {{- end }}
 9: {{- end }}
10: {{- else if contains "NodePort" .Values.service.type }}
11:   export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "ldap-2fa-backend.fullname" . }})
12:   export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
13:   echo http://$NODE_IP:$NODE_PORT
14: {{- else if contains "LoadBalancer" .Values.service.type }}
15:   NOTE: It may take a few minutes for the LoadBalancer IP to be available.
16:         You can watch the status by running:
17:         kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "ldap-2fa-backend.fullname" . }}
18:   export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "ldap-2fa-backend.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
19:   echo http://$SERVICE_IP:{{ .Values.service.port }}
20: {{- else if contains "ClusterIP" .Values.service.type }}
21:   kubectl --namespace {{ .Release.Namespace }} port-forward svc/{{ include "ldap-2fa-backend.fullname" . }} 8000:{{ .Values.service.port }}
22:   echo "Visit http://127.0.0.1:8000/api/healthz"
23: {{- end }}
24:
25: 2. API Endpoints:
26:    - Health Check: GET /api/healthz
27:    - Enroll MFA:   POST /api/auth/enroll
28:    - Login:        POST /api/auth/login
29:
30: 3. Test the health endpoint:
31:    curl -s https://{{ (index .Values.ingress.hosts 0).host }}/api/healthz | jq
32:
33: 4. Enroll a user for MFA:
34:    curl -X POST https://{{ (index .Values.ingress.hosts 0).host }}/api/auth/enroll \
35:      -H "Content-Type: application/json" \
36:      -d '{"username": "testuser", "password": "testpassword"}'
37:
38: 5. Login with MFA:
39:    curl -X POST https://{{ (index .Values.ingress.hosts 0).host }}/api/auth/login \
40:      -H "Content-Type: application/json" \
41:      -d '{"username": "testuser", "password": "testpassword", "totp_code": "123456"}'
```

## File: application/backend/helm/ldap-2fa-backend/templates/secret.yaml
```yaml
 1: {{- if not .Values.externalSecret.enabled }}
 2: # This secret is only created if externalSecret.enabled is false
 3: # In production, use an external secret (e.g., from AWS Secrets Manager)
 4: apiVersion: v1
 5: kind: Secret
 6: metadata:
 7:   name: {{ include "ldap-2fa-backend.fullname" . }}-secret
 8:   labels:
 9:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
10: type: Opaque
11: data:
12:   # LDAP Admin Password - base64 encoded
13:   # WARNING: In production, use externalSecret.enabled=true to reference
14:   # an existing secret managed by External Secrets Operator or similar
15:   LDAP_ADMIN_PASSWORD: {{ "" | b64enc | quote }}
16: {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/service.yaml
```yaml
 1: apiVersion: v1
 2: kind: Service
 3: metadata:
 4:   name: {{ include "ldap-2fa-backend.fullname" . }}
 5:   labels:
 6:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 7: spec:
 8:   type: {{ .Values.service.type }}
 9:   ports:
10:     - port: {{ .Values.service.port }}
11:       targetPort: http
12:       protocol: TCP
13:       name: http
14:   selector:
15:     {{- include "ldap-2fa-backend.selectorLabels" . | nindent 4 }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/serviceaccount.yaml
```yaml
 1: {{- if .Values.serviceAccount.create -}}
 2: apiVersion: v1
 3: kind: ServiceAccount
 4: metadata:
 5:   name: {{ include "ldap-2fa-backend.serviceAccountName" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 8:   annotations:
 9:     {{- if .Values.serviceAccountIAM.roleArn }}
10:     eks.amazonaws.com/role-arn: {{ .Values.serviceAccountIAM.roleArn | quote }}
11:     {{- end }}
12:     {{- with .Values.serviceAccount.annotations }}
13:     {{- toYaml . | nindent 4 }}
14:     {{- end }}
15: automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
16: {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/Chart.yaml
```yaml
 1: apiVersion: v2
 2: name: ldap-2fa-backend
 3: description: Backend API for LDAP 2FA authentication application
 4: type: application
 5: # Chart version - increment when making changes to the chart
 6: version: 0.1.0
 7: # Application version - updated by CI/CD pipeline
 8: appVersion: "1.0.0"
 9: keywords:
10:   - ldap
11:   - 2fa
12:   - mfa
13:   - authentication
14:   - totp
15: maintainers:
16:   - name: Talo
17:     url: https://github.com/talorlik
18: home: https://github.com/talorlik/ldap-2fa-on-k8s
19: sources:
20:   - https://github.com/talorlik/ldap-2fa-on-k8s
```

## File: application/backend/src/app/api/__init__.py
```python
1: """API module for 2FA Backend."""
2: from app.api.routes import router
3: __all__ = ["router"]
```

## File: application/backend/src/app/database/connection.py
```python
 1: """Database connection and session management."""
 2: import logging
 3: from contextlib import asynccontextmanager
 4: from typing import AsyncGenerator
 5: from sqlalchemy.ext.asyncio import (
 6:     AsyncSession,
 7:     async_sessionmaker,
 8:     create_async_engine,
 9: )
10: from sqlalchemy.pool import NullPool
11: from app.config import get_settings
12: logger = logging.getLogger(__name__)
13: # Global engine and session factory
14: _engine = None
15: AsyncSessionLocal: async_sessionmaker[AsyncSession] | None = None
16: async def init_db() -> None:
17:     """Initialize database connection and create tables."""
18:     global _engine, AsyncSessionLocal
19:     settings = get_settings()
20:     logger.info(f"Initializing database connection to: {settings.database_url.split('@')[-1]}")
21:     _engine = create_async_engine(
22:         settings.database_url,
23:         echo=settings.debug,
24:         poolclass=NullPool,  # Use NullPool for async
25:     )
26:     AsyncSessionLocal = async_sessionmaker(
27:         bind=_engine,
28:         class_=AsyncSession,
29:         expire_on_commit=False,
30:         autocommit=False,
31:         autoflush=False,
32:     )
33:     # Create tables
34:     from app.database.models import Base
35:     async with _engine.begin() as conn:
36:         await conn.run_sync(Base.metadata.create_all)
37:     logger.info("Database initialized successfully")
38: async def close_db() -> None:
39:     """Close database connection."""
40:     global _engine, AsyncSessionLocal
41:     if _engine:
42:         await _engine.dispose()
43:         _engine = None
44:         AsyncSessionLocal = None
45:         logger.info("Database connection closed")
46: async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
47:     """Get an async database session."""
48:     if AsyncSessionLocal is None:
49:         raise RuntimeError("Database not initialized. Call init_db() first.")
50:     async with AsyncSessionLocal() as session:
51:         try:
52:             yield session
53:             await session.commit()
54:         except Exception:
55:             await session.rollback()
56:             raise
57: @asynccontextmanager
58: async def get_db() -> AsyncGenerator[AsyncSession, None]:
59:     """Context manager for database sessions."""
60:     if AsyncSessionLocal is None:
61:         raise RuntimeError("Database not initialized. Call init_db() first.")
62:     async with AsyncSessionLocal() as session:
63:         try:
64:             yield session
65:             await session.commit()
66:         except Exception:
67:             await session.rollback()
68:             raise
```

## File: application/backend/src/app/email/__init__.py
```python
1: """Email package for sending verification emails via AWS SES."""
2: from app.email.client import EmailClient
3: __all__ = ["EmailClient"]
```

## File: application/backend/src/app/ldap/__init__.py
```python
1: """LDAP client module for authentication operations."""
2: from app.ldap.client import LDAPClient
3: __all__ = ["LDAPClient"]
```

## File: application/backend/src/app/mfa/__init__.py
```python
1: """MFA/TOTP module for two-factor authentication."""
2: from app.mfa.totp import TOTPManager
3: __all__ = ["TOTPManager"]
```

## File: application/backend/src/app/mfa/totp.py
```python
  1: """TOTP (Time-based One-Time Password) manager for MFA."""
  2: import base64
  3: import hashlib
  4: import hmac
  5: import logging
  6: import secrets
  7: import struct
  8: import time
  9: from typing import Optional
 10: from urllib.parse import quote
 11: from app.config import Settings, get_settings
 12: logger = logging.getLogger(__name__)
 13: class TOTPManager:
 14:     """Manager for TOTP operations."""
 15:     def __init__(self, settings: Optional[Settings] = None):
 16:         """Initialize TOTP manager with settings."""
 17:         self.settings = settings or get_settings()
 18:     def generate_secret(self) -> str:
 19:         """
 20:         Generate a new TOTP secret.
 21:         Returns:
 22:             Base32 encoded secret string
 23:         """
 24:         # Generate 20 bytes (160 bits) of random data
 25:         secret_bytes = secrets.token_bytes(20)
 26:         # Encode as base32 (standard for TOTP)
 27:         secret = base64.b32encode(secret_bytes).decode("utf-8")
 28:         logger.debug("Generated new TOTP secret")
 29:         return secret
 30:     def generate_otpauth_uri(
 31:         self,
 32:         secret: str,
 33:         username: str,
 34:         issuer: Optional[str] = None,
 35:     ) -> str:
 36:         """
 37:         Generate an otpauth:// URI for QR code generation.
 38:         Args:
 39:             secret: The TOTP secret (base32 encoded)
 40:             username: The username/account name
 41:             issuer: Optional issuer name (defaults to settings)
 42:         Returns:
 43:             otpauth:// URI string
 44:         """
 45:         issuer = issuer or self.settings.totp_issuer
 46:         # URL-encode the issuer and username
 47:         encoded_issuer = quote(issuer, safe="")
 48:         encoded_username = quote(username, safe="")
 49:         # Build the otpauth URI
 50:         uri = (
 51:             f"otpauth://totp/{encoded_issuer}:{encoded_username}"
 52:             f"?secret={secret}"
 53:             f"&issuer={encoded_issuer}"
 54:             f"&algorithm={self.settings.totp_algorithm}"
 55:             f"&digits={self.settings.totp_digits}"
 56:             f"&period={self.settings.totp_interval}"
 57:         )
 58:         logger.debug(f"Generated otpauth URI for user: {username}")
 59:         return uri
 60:     def _get_algorithm(self) -> str:
 61:         """Get the hash algorithm name for hashlib."""
 62:         algorithm_map = {
 63:             "SHA1": "sha1",
 64:             "SHA256": "sha256",
 65:             "SHA512": "sha512",
 66:         }
 67:         return algorithm_map.get(self.settings.totp_algorithm, "sha1")
 68:     def _generate_hotp(self, secret: str, counter: int) -> str:
 69:         """
 70:         Generate HOTP value.
 71:         Args:
 72:             secret: Base32 encoded secret
 73:             counter: Counter value
 74:         Returns:
 75:             HOTP code as string
 76:         """
 77:         # Decode the base32 secret
 78:         key = base64.b32decode(secret.upper())
 79:         # Pack the counter as big-endian 64-bit integer
 80:         counter_bytes = struct.pack(">Q", counter)
 81:         # Compute HMAC
 82:         algorithm = self._get_algorithm()
 83:         hmac_result = hmac.new(key, counter_bytes, algorithm).digest()
 84:         # Dynamic truncation
 85:         offset = hmac_result[-1] & 0x0F
 86:         truncated = struct.unpack(">I", hmac_result[offset : offset + 4])[0]
 87:         truncated &= 0x7FFFFFFF
 88:         # Generate OTP
 89:         otp = truncated % (10 ** self.settings.totp_digits)
 90:         return str(otp).zfill(self.settings.totp_digits)
 91:     def generate_totp(self, secret: str, timestamp: Optional[int] = None) -> str:
 92:         """
 93:         Generate current TOTP code.
 94:         Args:
 95:             secret: Base32 encoded secret
 96:             timestamp: Optional Unix timestamp (defaults to current time)
 97:         Returns:
 98:             TOTP code as string
 99:         """
100:         if timestamp is None:
101:             timestamp = int(time.time())
102:         counter = timestamp // self.settings.totp_interval
103:         return self._generate_hotp(secret, counter)
104:     def verify_totp(
105:         self,
106:         secret: str,
107:         code: str,
108:         window: int = 1,
109:     ) -> bool:
110:         """
111:         Verify a TOTP code.
112:         Args:
113:             secret: Base32 encoded secret
114:             code: The TOTP code to verify
115:             window: Number of intervals to check before and after current time
116:         Returns:
117:             True if code is valid, False otherwise
118:         """
119:         if not code or not code.isdigit():
120:             logger.warning("Invalid TOTP code format")
121:             return False
122:         # Normalize code length
123:         code = code.zfill(self.settings.totp_digits)
124:         current_time = int(time.time())
125:         current_counter = current_time // self.settings.totp_interval
126:         # Check codes within the window
127:         for offset in range(-window, window + 1):
128:             counter = current_counter + offset
129:             expected_code = self._generate_hotp(secret, counter)
130:             if hmac.compare_digest(code, expected_code):
131:                 logger.debug(f"TOTP verification successful (offset: {offset})")
132:                 return True
133:         logger.debug("TOTP verification failed")
134:         return False
```

## File: application/backend/src/app/redis/__init__.py
```python
1: """Redis module for SMS OTP storage."""
2: from app.redis.client import RedisOTPClient, get_otp_client
3: __all__ = ["RedisOTPClient", "get_otp_client"]
```

## File: application/backend/src/app/redis/client.py
```python
  1: """Redis client for SMS OTP operations.
  2: Provides a centralized, TTL-aware storage for SMS verification codes,
  3: replacing the in-memory dictionary approach.
  4: """
  5: import json
  6: import logging
  7: from functools import lru_cache
  8: from typing import Optional
  9: import redis
 10: from app.config import get_settings
 11: logger = logging.getLogger(__name__)
 12: class RedisOTPClient:
 13:     """Redis client for SMS OTP operations.
 14:     Provides methods for storing, retrieving, and managing SMS OTP codes
 15:     with automatic TTL-based expiration.
 16:     """
 17:     def __init__(self) -> None:
 18:         """Initialize the Redis OTP client."""
 19:         self._settings = get_settings()
 20:         self._client: Optional[redis.Redis] = None
 21:         self._connected = False
 22:         if self._settings.redis_enabled:
 23:             self._initialize_client()
 24:     def _initialize_client(self) -> None:
 25:         """Initialize the Redis client connection."""
 26:         try:
 27:             self._client = redis.Redis(
 28:                 host=self._settings.redis_host,
 29:                 port=self._settings.redis_port,
 30:                 password=self._settings.redis_password or None,
 31:                 db=self._settings.redis_db,
 32:                 ssl=self._settings.redis_ssl,
 33:                 decode_responses=True,
 34:                 socket_connect_timeout=5,
 35:                 socket_timeout=5,
 36:                 retry_on_timeout=True,
 37:             )
 38:             # Test connection
 39:             self._client.ping()
 40:             self._connected = True
 41:             logger.info(
 42:                 "Redis connected successfully to %s:%s",
 43:                 self._settings.redis_host,
 44:                 self._settings.redis_port,
 45:             )
 46:         except redis.ConnectionError as e:
 47:             logger.error("Failed to connect to Redis: %s", e)
 48:             self._connected = False
 49:             self._client = None
 50:         except redis.AuthenticationError as e:
 51:             logger.error("Redis authentication failed: %s", e)
 52:             self._connected = False
 53:             self._client = None
 54:     @property
 55:     def is_enabled(self) -> bool:
 56:         """Check if Redis is enabled in settings."""
 57:         return self._settings.redis_enabled
 58:     @property
 59:     def is_connected(self) -> bool:
 60:         """Check if Redis client is connected."""
 61:         if not self._connected or not self._client:
 62:             return False
 63:         try:
 64:             self._client.ping()
 65:             return True
 66:         except (redis.ConnectionError, redis.TimeoutError):
 67:             self._connected = False
 68:             return False
 69:     def _get_key(self, username: str) -> str:
 70:         """Generate the Redis key for a username."""
 71:         return f"{self._settings.redis_key_prefix}{username}"
 72:     def store_code(
 73:         self,
 74:         username: str,
 75:         code: str,
 76:         phone_number: str,
 77:         ttl_seconds: Optional[int] = None,
 78:     ) -> bool:
 79:         """Store OTP code with automatic TTL expiration.
 80:         Args:
 81:             username: The username to store the code for
 82:             code: The verification code
 83:             phone_number: The phone number (for reference)
 84:             ttl_seconds: Time-to-live in seconds (defaults to settings value)
 85:         Returns:
 86:             True if successful, False otherwise
 87:         """
 88:         if not self.is_enabled:
 89:             logger.debug("Redis not enabled, skipping store_code")
 90:             return False
 91:         if not self.is_connected:
 92:             logger.error("Redis not connected, cannot store code")
 93:             return False
 94:         try:
 95:             key = self._get_key(username)
 96:             value = json.dumps({
 97:                 "code": code,
 98:                 "phone_number": phone_number,
 99:             })
100:             ttl = ttl_seconds or self._settings.sms_code_expiry_seconds
101:             self._client.setex(key, ttl, value)
102:             logger.debug("Stored OTP code for %s with TTL %ss", username, ttl)
103:             return True
104:         except redis.RedisError as e:
105:             logger.error("Failed to store OTP code: %s", e)
106:             return False
107:     def get_code(self, username: str) -> Optional[dict]:
108:         """Retrieve OTP code data if not expired.
109:         Args:
110:             username: The username to retrieve the code for
111:         Returns:
112:             Dictionary with 'code' and 'phone_number' keys, or None if not found
113:         """
114:         if not self.is_enabled:
115:             logger.debug("Redis not enabled, skipping get_code")
116:             return None
117:         if not self.is_connected:
118:             logger.error("Redis not connected, cannot get code")
119:             return None
120:         try:
121:             key = self._get_key(username)
122:             value = self._client.get(key)
123:             if value is None:
124:                 logger.debug("No OTP code found for %s", username)
125:                 return None
126:             data = json.loads(value)
127:             logger.debug("Retrieved OTP code for %s", username)
128:             return data
129:         except redis.RedisError as e:
130:             logger.error("Failed to retrieve OTP code: %s", e)
131:             return None
132:         except json.JSONDecodeError as e:
133:             logger.error("Failed to decode OTP data: %s", e)
134:             return None
135:     def delete_code(self, username: str) -> bool:
136:         """Delete OTP code after successful verification.
137:         Args:
138:             username: The username to delete the code for
139:         Returns:
140:             True if successful, False otherwise
141:         """
142:         if not self.is_enabled:
143:             logger.debug("Redis not enabled, skipping delete_code")
144:             return False
145:         if not self.is_connected:
146:             logger.error("Redis not connected, cannot delete code")
147:             return False
148:         try:
149:             key = self._get_key(username)
150:             deleted = self._client.delete(key)
151:             logger.debug("Deleted OTP code for %s: %s", username, deleted > 0)
152:             return deleted > 0
153:         except redis.RedisError as e:
154:             logger.error("Failed to delete OTP code: %s", e)
155:             return False
156:     def code_exists(self, username: str) -> bool:
157:         """Check if valid OTP code exists for user.
158:         Args:
159:             username: The username to check
160:         Returns:
161:             True if code exists, False otherwise
162:         """
163:         if not self.is_enabled:
164:             return False
165:         if not self.is_connected:
166:             return False
167:         try:
168:             key = self._get_key(username)
169:             return self._client.exists(key) > 0
170:         except redis.RedisError as e:
171:             logger.error("Failed to check OTP code existence: %s", e)
172:             return False
173:     def get_ttl(self, username: str) -> int:
174:         """Get remaining TTL for a user's OTP code.
175:         Args:
176:             username: The username to check
177:         Returns:
178:             TTL in seconds, -1 if no expiry, -2 if key doesn't exist
179:         """
180:         if not self.is_enabled or not self.is_connected:
181:             return -2
182:         try:
183:             key = self._get_key(username)
184:             return self._client.ttl(key)
185:         except redis.RedisError as e:
186:             logger.error("Failed to get TTL: %s", e)
187:             return -2
188:     def health_check(self) -> dict:
189:         """Perform health check on Redis connection.
190:         Returns:
191:             Dictionary with health status information
192:         """
193:         if not self.is_enabled:
194:             return {
195:                 "enabled": False,
196:                 "connected": False,
197:                 "status": "disabled",
198:             }
199:         try:
200:             if self._client and self._client.ping():
201:                 info = self._client.info("server")
202:                 return {
203:                     "enabled": True,
204:                     "connected": True,
205:                     "status": "healthy",
206:                     "redis_version": info.get("redis_version", "unknown"),
207:                 }
208:         except redis.RedisError as e:
209:             return {
210:                 "enabled": True,
211:                 "connected": False,
212:                 "status": "unhealthy",
213:                 "error": str(e),
214:             }
215:         return {
216:             "enabled": True,
217:             "connected": False,
218:             "status": "disconnected",
219:         }
220: # In-memory fallback storage when Redis is disabled
221: _inmemory_sms_codes: dict[str, dict] = {}
222: class InMemoryOTPStorage:
223:     """In-memory fallback storage for SMS OTP codes.
224:     Used when Redis is disabled, maintaining backward compatibility.
225:     """
226:     @staticmethod
227:     def store_code(
228:         username: str,
229:         code: str,
230:         phone_number: str,
231:         expires_at: float,
232:     ) -> bool:
233:         """Store code in memory with expiration timestamp."""
234:         _inmemory_sms_codes[username] = {
235:             "code": code,
236:             "phone_number": phone_number,
237:             "expires_at": expires_at,
238:         }
239:         return True
240:     @staticmethod
241:     def get_code(username: str) -> Optional[dict]:
242:         """Get code from memory."""
243:         return _inmemory_sms_codes.get(username)
244:     @staticmethod
245:     def delete_code(username: str) -> bool:
246:         """Delete code from memory."""
247:         if username in _inmemory_sms_codes:
248:             del _inmemory_sms_codes[username]
249:             return True
250:         return False
251:     @staticmethod
252:     def code_exists(username: str) -> bool:
253:         """Check if code exists in memory."""
254:         return username in _inmemory_sms_codes
255: @lru_cache
256: def get_otp_client() -> RedisOTPClient:
257:     """Get cached Redis OTP client instance."""
258:     return RedisOTPClient()
```

## File: application/backend/src/app/sms/__init__.py
```python
1: """SMS module for 2FA verification via AWS SNS."""
2: from app.sms.client import SMSClient
3: __all__ = ["SMSClient"]
```

## File: application/backend/Dockerfile
```
 1: # Stage 1: Build stage
 2: FROM python:3.12-slim AS builder
 3:
 4: WORKDIR /app
 5:
 6: # Install build dependencies
 7: RUN apt-get update && apt-get install -y --no-install-recommends \
 8:     gcc \
 9:     libldap2-dev \
10:     libsasl2-dev \
11:     && rm -rf /var/lib/apt/lists/*
12:
13: # Copy requirements and install dependencies
14: COPY src/requirements.txt .
15: RUN pip install --no-cache-dir --user -r requirements.txt
16:
17: # Stage 2: Runtime stage
18: FROM python:3.12-slim
19:
20: # Create non-root user for security
21: RUN groupadd -r appgroup && useradd -r -g appgroup appuser
22:
23: WORKDIR /app
24:
25: # Install runtime dependencies only
26: RUN apt-get update && apt-get install -y --no-install-recommends \
27:     libldap-2.5-0 \
28:     libsasl2-2 \
29:     && rm -rf /var/lib/apt/lists/* \
30:     && apt-get clean
31:
32: # Copy installed packages from builder
33: COPY --from=builder /root/.local /home/appuser/.local
34:
35: # Copy application code
36: COPY src/app ./app
37:
38: # Set environment variables
39: ENV PATH=/home/appuser/.local/bin:$PATH \
40:     PYTHONDONTWRITEBYTECODE=1 \
41:     PYTHONUNBUFFERED=1 \
42:     PYTHONPATH=/app
43:
44: # Default environment variables (can be overridden)
45: ENV LDAP_HOST=openldap-stack-ha.ldap.svc.cluster.local \
46:     LDAP_PORT=389 \
47:     LDAP_USE_SSL=false \
48:     LDAP_BASE_DN=dc=ldap,dc=talorlik,dc=internal \
49:     LDAP_USER_SEARCH_BASE=ou=users \
50:     TOTP_ISSUER=LDAP-2FA-App \
51:     TOTP_DIGITS=6 \
52:     TOTP_INTERVAL=30 \
53:     TOTP_ALGORITHM=SHA1 \
54:     APP_NAME="LDAP 2FA Backend API" \
55:     DEBUG=false \
56:     LOG_LEVEL=INFO
57:
58: # Switch to non-root user
59: USER appuser
60:
61: # Expose port
62: EXPOSE 8000
63:
64: # Health check
65: HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
66:     CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/healthz')" || exit 1
67:
68: # Run the application with gunicorn for production
69: CMD ["gunicorn", "app.main:app", \
70:     "--bind", "0.0.0.0:8000", \
71:     "--workers", "2", \
72:     "--worker-class", "uvicorn.workers.UvicornWorker", \
73:     "--access-logfile", "-", \
74:     "--error-logfile", "-"]
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/tests/test-connection.yaml
```yaml
 1: apiVersion: v1
 2: kind: Pod
 3: metadata:
 4:   name: "{{ include "ldap-2fa-frontend.fullname" . }}-test-connection"
 5:   labels:
 6:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 7:   annotations:
 8:     "helm.sh/hook": test
 9: spec:
10:   containers:
11:     - name: wget
12:       image: busybox
13:       command: ['wget']
14:       args: ['{{ include "ldap-2fa-frontend.fullname" . }}:{{ .Values.service.port }}']
15:   restartPolicy: Never
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/_helpers.tpl
```
 1: {{/*
 2: Expand the name of the chart.
 3: */}}
 4: {{- define "ldap-2fa-frontend.name" -}}
 5: {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
 6: {{- end }}
 7:
 8: {{/*
 9: Create a default fully qualified app name.
10: We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
11: If release name contains chart name it will be used as a full name.
12: */}}
13: {{- define "ldap-2fa-frontend.fullname" -}}
14: {{- if .Values.fullnameOverride }}
15: {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
16: {{- else }}
17: {{- $name := default .Chart.Name .Values.nameOverride }}
18: {{- if contains $name .Release.Name }}
19: {{- .Release.Name | trunc 63 | trimSuffix "-" }}
20: {{- else }}
21: {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
22: {{- end }}
23: {{- end }}
24: {{- end }}
25:
26: {{/*
27: Create chart name and version as used by the chart label.
28: */}}
29: {{- define "ldap-2fa-frontend.chart" -}}
30: {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
31: {{- end }}
32:
33: {{/*
34: Common labels
35: */}}
36: {{- define "ldap-2fa-frontend.labels" -}}
37: helm.sh/chart: {{ include "ldap-2fa-frontend.chart" . }}
38: {{ include "ldap-2fa-frontend.selectorLabels" . }}
39: {{- if .Chart.AppVersion }}
40: app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
41: {{- end }}
42: app.kubernetes.io/managed-by: {{ .Release.Service }}
43: {{- end }}
44:
45: {{/*
46: Selector labels
47: */}}
48: {{- define "ldap-2fa-frontend.selectorLabels" -}}
49: app.kubernetes.io/name: {{ include "ldap-2fa-frontend.name" . }}
50: app.kubernetes.io/instance: {{ .Release.Name }}
51: {{- end }}
52:
53: {{/*
54: Create the name of the service account to use
55: */}}
56: {{- define "ldap-2fa-frontend.serviceAccountName" -}}
57: {{- if .Values.serviceAccount.create }}
58: {{- default (include "ldap-2fa-frontend.fullname" .) .Values.serviceAccount.name }}
59: {{- else }}
60: {{- default "default" .Values.serviceAccount.name }}
61: {{- end }}
62: {{- end }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/deployment.yaml
```yaml
 1: apiVersion: apps/v1
 2: kind: Deployment
 3: metadata:
 4:   name: {{ include "ldap-2fa-frontend.fullname" . }}
 5:   labels:
 6:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 7: spec:
 8:   {{- if not .Values.autoscaling.enabled }}
 9:   replicas: {{ .Values.replicaCount }}
10:   {{- end }}
11:   selector:
12:     matchLabels:
13:       {{- include "ldap-2fa-frontend.selectorLabels" . | nindent 6 }}
14:   template:
15:     metadata:
16:       {{- with .Values.podAnnotations }}
17:       annotations:
18:         {{- toYaml . | nindent 8 }}
19:       {{- end }}
20:       labels:
21:         {{- include "ldap-2fa-frontend.labels" . | nindent 8 }}
22:         {{- with .Values.podLabels }}
23:         {{- toYaml . | nindent 8 }}
24:         {{- end }}
25:     spec:
26:       {{- with .Values.imagePullSecrets }}
27:       imagePullSecrets:
28:         {{- toYaml . | nindent 8 }}
29:       {{- end }}
30:       serviceAccountName: {{ include "ldap-2fa-frontend.serviceAccountName" . }}
31:       {{- with .Values.podSecurityContext }}
32:       securityContext:
33:         {{- toYaml . | nindent 8 }}
34:       {{- end }}
35:       containers:
36:         - name: {{ .Chart.Name }}
37:           {{- with .Values.securityContext }}
38:           securityContext:
39:             {{- toYaml . | nindent 12 }}
40:           {{- end }}
41:           image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
42:           imagePullPolicy: {{ .Values.image.pullPolicy }}
43:           ports:
44:             - name: http
45:               containerPort: {{ .Values.service.port }}
46:               protocol: TCP
47:           {{- with .Values.livenessProbe }}
48:           livenessProbe:
49:             {{- toYaml . | nindent 12 }}
50:           {{- end }}
51:           {{- with .Values.readinessProbe }}
52:           readinessProbe:
53:             {{- toYaml . | nindent 12 }}
54:           {{- end }}
55:           {{- with .Values.resources }}
56:           resources:
57:             {{- toYaml . | nindent 12 }}
58:           {{- end }}
59:           {{- with .Values.volumeMounts }}
60:           volumeMounts:
61:             {{- toYaml . | nindent 12 }}
62:           {{- end }}
63:       {{- with .Values.volumes }}
64:       volumes:
65:         {{- toYaml . | nindent 8 }}
66:       {{- end }}
67:       {{- with .Values.nodeSelector }}
68:       nodeSelector:
69:         {{- toYaml . | nindent 8 }}
70:       {{- end }}
71:       {{- with .Values.affinity }}
72:       affinity:
73:         {{- toYaml . | nindent 8 }}
74:       {{- end }}
75:       {{- with .Values.tolerations }}
76:       tolerations:
77:         {{- toYaml . | nindent 8 }}
78:       {{- end }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/hpa.yaml
```yaml
 1: {{- if .Values.autoscaling.enabled }}
 2: apiVersion: autoscaling/v2
 3: kind: HorizontalPodAutoscaler
 4: metadata:
 5:   name: {{ include "ldap-2fa-frontend.fullname" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 8: spec:
 9:   scaleTargetRef:
10:     apiVersion: apps/v1
11:     kind: Deployment
12:     name: {{ include "ldap-2fa-frontend.fullname" . }}
13:   minReplicas: {{ .Values.autoscaling.minReplicas }}
14:   maxReplicas: {{ .Values.autoscaling.maxReplicas }}
15:   metrics:
16:     {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
17:     - type: Resource
18:       resource:
19:         name: cpu
20:         target:
21:           type: Utilization
22:           averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
23:     {{- end }}
24:     {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
25:     - type: Resource
26:       resource:
27:         name: memory
28:         target:
29:           type: Utilization
30:           averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
31:     {{- end }}
32: {{- end }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/ingress.yaml
```yaml
 1: {{- if .Values.ingress.enabled -}}
 2: apiVersion: networking.k8s.io/v1
 3: kind: Ingress
 4: metadata:
 5:   name: {{ include "ldap-2fa-frontend.fullname" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 8:   {{- with .Values.ingress.annotations }}
 9:   annotations:
10:     {{- toYaml . | nindent 4 }}
11:   {{- end }}
12: spec:
13:   {{- with .Values.ingress.className }}
14:   ingressClassName: {{ . }}
15:   {{- end }}
16:   {{- if .Values.ingress.tls }}
17:   tls:
18:     {{- range .Values.ingress.tls }}
19:     - hosts:
20:         {{- range .hosts }}
21:         - {{ . | quote }}
22:         {{- end }}
23:       secretName: {{ .secretName }}
24:     {{- end }}
25:   {{- end }}
26:   rules:
27:     {{- range .Values.ingress.hosts }}
28:     - host: {{ .host | quote }}
29:       http:
30:         paths:
31:           {{- range .paths }}
32:           - path: {{ .path }}
33:             {{- with .pathType }}
34:             pathType: {{ . }}
35:             {{- end }}
36:             backend:
37:               service:
38:                 name: {{ include "ldap-2fa-frontend.fullname" $ }}
39:                 port:
40:                   number: {{ $.Values.service.port }}
41:           {{- end }}
42:     {{- end }}
43: {{- end }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/NOTES.txt
```
 1: LDAP 2FA Frontend has been deployed!
 2:
 3: 1. Get the application URL:
 4: {{- if .Values.ingress.enabled }}
 5: {{- range $host := .Values.ingress.hosts }}
 6:   {{- range .paths }}
 7:   https://{{ $host.host }}{{ .path }}
 8:   {{- end }}
 9: {{- end }}
10: {{- else if contains "NodePort" .Values.service.type }}
11:   export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "ldap-2fa-frontend.fullname" . }})
12:   export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
13:   echo http://$NODE_IP:$NODE_PORT
14: {{- else if contains "LoadBalancer" .Values.service.type }}
15:   NOTE: It may take a few minutes for the LoadBalancer IP to be available.
16:         You can watch the status by running:
17:         kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "ldap-2fa-frontend.fullname" . }}
18:   export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "ldap-2fa-frontend.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
19:   echo http://$SERVICE_IP:{{ .Values.service.port }}
20: {{- else if contains "ClusterIP" .Values.service.type }}
21:   kubectl --namespace {{ .Release.Namespace }} port-forward svc/{{ include "ldap-2fa-frontend.fullname" . }} 8080:{{ .Values.service.port }}
22:   echo "Visit http://127.0.0.1:8080"
23: {{- end }}
24:
25: 2. Features:
26:    - User enrollment for MFA (generates QR code for authenticator apps)
27:    - Login with LDAP credentials + TOTP code
28:    - Responsive design with dark mode support
29:
30: 3. The frontend communicates with the backend via relative URLs:
31:    - /api/healthz - Health check
32:    - /api/auth/enroll - MFA enrollment
33:    - /api/auth/login - Login with 2FA
34:
35: 4. Ensure the backend is deployed and accessible at the same host:
36:    kubectl get ingress -n {{ .Release.Namespace }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/service.yaml
```yaml
 1: apiVersion: v1
 2: kind: Service
 3: metadata:
 4:   name: {{ include "ldap-2fa-frontend.fullname" . }}
 5:   labels:
 6:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 7: spec:
 8:   type: {{ .Values.service.type }}
 9:   ports:
10:     - port: {{ .Values.service.port }}
11:       targetPort: http
12:       protocol: TCP
13:       name: http
14:   selector:
15:     {{- include "ldap-2fa-frontend.selectorLabels" . | nindent 4 }}
```

## File: application/frontend/helm/ldap-2fa-frontend/templates/serviceaccount.yaml
```yaml
 1: {{- if .Values.serviceAccount.create -}}
 2: apiVersion: v1
 3: kind: ServiceAccount
 4: metadata:
 5:   name: {{ include "ldap-2fa-frontend.serviceAccountName" . }}
 6:   labels:
 7:     {{- include "ldap-2fa-frontend.labels" . | nindent 4 }}
 8:   {{- with .Values.serviceAccount.annotations }}
 9:   annotations:
10:     {{- toYaml . | nindent 4 }}
11:   {{- end }}
12: automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
13: {{- end }}
```

## File: application/frontend/helm/ldap-2fa-frontend/Chart.yaml
```yaml
 1: apiVersion: v2
 2: name: ldap-2fa-frontend
 3: description: Frontend UI for LDAP 2FA authentication application
 4: type: application
 5: # Chart version - increment when making changes to the chart
 6: version: 0.1.0
 7: # Application version - updated by CI/CD pipeline
 8: appVersion: "1.0.0"
 9: keywords:
10:   - ldap
11:   - 2fa
12:   - mfa
13:   - authentication
14:   - frontend
15:   - nginx
16: maintainers:
17:   - name: Talo
18:     url: https://github.com/talorlik
19: home: https://github.com/talorlik/ldap-2fa-on-k8s
20: sources:
21:   - https://github.com/talorlik/ldap-2fa-on-k8s
```

## File: application/frontend/Dockerfile
```
 1: # Stage 1: Build stage (for any potential future build steps like minification)
 2: FROM node:20-alpine AS builder
 3:
 4: WORKDIR /app
 5:
 6: # Copy source files
 7: COPY src/ ./src/
 8:
 9: # In a real-world scenario, you might add build steps here:
10: # - npm install
11: # - npm run build (minify, bundle, etc.)
12:
13: # For now, we just copy the files as-is since we're using vanilla HTML/CSS/JS
14:
15: # Stage 2: Production stage with nginx
16: FROM nginx:1.27-alpine
17:
18: # Remove default nginx configuration
19: RUN rm -rf /etc/nginx/conf.d/default.conf
20:
21: # Copy custom nginx configuration
22: COPY nginx.conf /etc/nginx/conf.d/default.conf
23:
24: # Copy static files from builder
25: COPY --from=builder /app/src/ /usr/share/nginx/html/
26:
27: # Create non-root user and set permissions
28: RUN addgroup -g 1000 -S appgroup && \
29:     adduser -u 1000 -S appuser -G appgroup && \
30:     chown -R appuser:appgroup /usr/share/nginx/html && \
31:     chown -R appuser:appgroup /var/cache/nginx && \
32:     chown -R appuser:appgroup /var/log/nginx && \
33:     chown -R appuser:appgroup /etc/nginx/conf.d && \
34:     touch /var/run/nginx.pid && \
35:     chown -R appuser:appgroup /var/run/nginx.pid
36:
37: # Switch to non-root user
38: USER appuser
39:
40: # Expose port
41: EXPOSE 80
42:
43: # Health check
44: HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
45:     CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1
46:
47: # Start nginx
48: CMD ["nginx", "-g", "daemon off;"]
```

## File: application/frontend/nginx.conf
```ini
 1: server {
 2:     listen 80;
 3:     listen [::]:80;
 4:     server_name _;
 5:
 6:     # Root directory for static files
 7:     root /usr/share/nginx/html;
 8:     index index.html;
 9:
10:     # Security headers
11:     add_header X-Frame-Options "SAMEORIGIN" always;
12:     add_header X-Content-Type-Options "nosniff" always;
13:     add_header X-XSS-Protection "1; mode=block" always;
14:     add_header Referrer-Policy "strict-origin-when-cross-origin" always;
15:
16:     # Gzip compression
17:     gzip on;
18:     gzip_vary on;
19:     gzip_min_length 1024;
20:     gzip_proxied any;
21:     gzip_types
22:         text/plain
23:         text/css
24:         text/javascript
25:         application/javascript
26:         application/json
27:         application/xml
28:         image/svg+xml;
29:
30:     # Serve static files
31:     location / {
32:         try_files $uri $uri/ /index.html;
33:
34:         # Cache static assets
35:         location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
36:             expires 1y;
37:             add_header Cache-Control "public, immutable";
38:             access_log off;
39:         }
40:     }
41:
42:     # Health check endpoint
43:     location /health {
44:         access_log off;
45:         return 200 "healthy\n";
46:         add_header Content-Type text/plain;
47:     }
48:
49:     # Deny access to hidden files
50:     location ~ /\. {
51:         deny all;
52:         access_log off;
53:         log_not_found off;
54:     }
55:
56:     # Custom error pages
57:     error_page 404 /index.html;
58:     error_page 500 502 503 504 /50x.html;
59:     location = /50x.html {
60:         root /usr/share/nginx/html;
61:     }
62: }
```

## File: application/helm/postgresql-values.tpl.yaml
```yaml
 1: # PostgreSQL Helm Values Template
 2: # Used by Terraform to configure Bitnami PostgreSQL deployment
 3: # for user storage in the LDAP 2FA application signup system
 4: # Based on official Bitnami PostgreSQL Helm chart values structure
 5: # Allow non-standard images (ECR) to bypass Bitnami image verification
 6: global:
 7:   security:
 8:     allowInsecureImages: true
 9: # Override default image to use ECR repository
10: image:
11:   registry: "${ecr_registry}"
12:   repository: "${ecr_repository}"
13:   tag: "${image_tag}"
14:   pullPolicy: IfNotPresent
15: # Standalone architecture
16: architecture: standalone
17: # Authentication configuration
18: auth:
19:   database: "${database_name}"
20:   username: "${database_username}"
21:   enablePostgresUser: false
22:   # Reference Kubernetes secret created by Terraform
23:   # (password sourced from GitHub Secrets → TF_VAR_postgresql_database_password)
24:   existingSecret: "${secret_name}"
25:   existingSecretPasswordKey: "password"
26: # Primary (master) configuration
27: primary:
28:   # Persistence for data recovery across restarts
29:   persistence:
30:     enabled: true
31: %{ if storage_class != "" ~}
32:     storageClass: "${storage_class}"
33: %{ endif ~}
34:     size: "${storage_size}"
35:   # Resource limits
36:   resources:
37:     requests:
38:       cpu: "${resources_requests_cpu}"
39:       memory: "${resources_requests_memory}"
40:     limits:
41:       cpu: "${resources_limits_cpu}"
42:       memory: "${resources_limits_memory}"
43:   # Service configuration
44:   service:
45:     type: ClusterIP
46: # Metrics (disabled by default)
47: metrics:
48:   enabled: false
```

## File: application/modules/alb/outputs.tf
```hcl
 1: # output "alb_dns_name" {
 2: #   description = "Application Load Balancer DNS Name"
 3: #   value = (
 4: #     length(kubernetes_ingress_v1.ingress_alb.status) > 0 &&
 5: #     length(kubernetes_ingress_v1.ingress_alb.status[0].load_balancer) > 0 &&
 6: #     length(kubernetes_ingress_v1.ingress_alb.status[0].load_balancer[0].ingress) > 0
 7: #   ) ? kubernetes_ingress_v1.ingress_alb.status[0].load_balancer[0].ingress[0].hostname : "ALB is still provisioning"
 8: # }
 9:
10: output "ingress_class_name" {
11:   description = "Name of the IngressClass for shared ALB"
12:   value       = kubernetes_ingress_class_v1.ingressclass_alb.metadata[0].name
13: }
14:
15: output "ingress_class_params_name" {
16:   description = "Name of the IngressClassParams for ALB configuration"
17:   value       = local.ingressclassparams_alb_name
18: }
19:
20: output "alb_scheme" {
21:   description = "ALB scheme configured in IngressClassParams"
22:   value       = var.alb_scheme
23: }
24:
25: output "alb_ip_address_type" {
26:   description = "ALB IP address type configured in IngressClassParams"
27:   value       = var.alb_ip_address_type
28: }
```

## File: application/modules/argocd/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name added to all resources"
 13:   type        = string
 14: }
 15:
 16: variable "cluster_name" {
 17:   description = "Name of the EKS cluster"
 18:   type        = string
 19: }
 20:
 21: variable "argocd_role_name_component" {
 22:   description = "Name component for ArgoCD IAM role (between prefix and env)"
 23:   type        = string
 24:   default     = "argocd-role"
 25: }
 26:
 27: variable "argocd_capability_name_component" {
 28:   description = "Name component for ArgoCD capability (between prefix and env)"
 29:   type        = string
 30:   default     = "argocd"
 31: }
 32:
 33: variable "argocd_namespace" {
 34:   description = "Kubernetes namespace for ArgoCD resources"
 35:   type        = string
 36:   default     = "argocd"
 37: }
 38:
 39: variable "argocd_project_name" {
 40:   description = "ArgoCD project name for cluster registration"
 41:   type        = string
 42:   default     = "default"
 43: }
 44:
 45: variable "local_cluster_secret_name" {
 46:   description = "Name of the Kubernetes secret for local cluster registration"
 47:   type        = string
 48:   default     = "local-cluster"
 49: }
 50:
 51: variable "idc_instance_arn" {
 52:   description = "ARN of the AWS Identity Center instance used for Argo CD auth"
 53:   type        = string
 54: }
 55:
 56: variable "idc_region" {
 57:   description = "Region of the Identity Center instance"
 58:   type        = string
 59: }
 60:
 61: variable "rbac_role_mappings" {
 62:   description = "List of RBAC role mappings for Identity Center groups/users"
 63:   type = list(object({
 64:     role = string
 65:     identities = list(object({
 66:       id   = string
 67:       type = string # SSO_GROUP or SSO_USER
 68:     }))
 69:   }))
 70:   default = []
 71: }
 72:
 73: variable "argocd_vpce_ids" {
 74:   description = "Optional list of VPC endpoint IDs for private access to Argo CD"
 75:   type        = list(string)
 76:   default     = []
 77: }
 78:
 79: variable "delete_propagation_policy" {
 80:   description = "Delete propagation policy for ArgoCD capability (RETAIN or DELETE)"
 81:   type        = string
 82:   default     = "RETAIN"
 83:   validation {
 84:     condition     = contains(["RETAIN", "DELETE"], var.delete_propagation_policy)
 85:     error_message = "Delete propagation policy must be either 'RETAIN' or 'DELETE'"
 86:   }
 87: }
 88:
 89: # IAM Policy Resources
 90: variable "iam_policy_eks_resources" {
 91:   description = "List of EKS resource ARNs for IAM policy (use ['*'] for all clusters)"
 92:   type        = list(string)
 93:   default     = ["*"]
 94: }
 95:
 96: variable "iam_policy_secrets_manager_resources" {
 97:   description = "List of Secrets Manager secret ARNs for IAM policy (use ['*'] for all secrets)"
 98:   type        = list(string)
 99:   default     = ["*"]
100: }
101:
102: variable "iam_policy_code_connections_resources" {
103:   description = "List of CodeConnections connection ARNs for IAM policy (use ['*'] for all connections)"
104:   type        = list(string)
105:   default     = ["*"]
106: }
107:
108: variable "enable_ecr_access" {
109:   description = "Whether to enable ECR access in IAM policy (for pulling container images)"
110:   type        = bool
111:   default     = false
112: }
113:
114: variable "iam_policy_ecr_resources" {
115:   description = "List of ECR repository ARNs for IAM policy (use ['*'] for all repositories)"
116:   type        = list(string)
117:   default     = ["*"]
118: }
119:
120: variable "enable_codecommit_access" {
121:   description = "Whether to enable CodeCommit access in IAM policy (for Git repository access)"
122:   type        = bool
123:   default     = false
124: }
125:
126: variable "iam_policy_codecommit_resources" {
127:   description = "List of CodeCommit repository ARNs for IAM policy (use ['*'] for all repositories)"
128:   type        = list(string)
129:   default     = ["*"]
130: }
```

## File: application/modules/argocd_app/outputs.tf
```hcl
 1: output "app_name" {
 2:   description = "Name of the ArgoCD Application"
 3:   value       = kubernetes_manifest.argocd_app.manifest.metadata.name
 4: }
 5:
 6: output "app_namespace" {
 7:   description = "Namespace where the ArgoCD Application is deployed"
 8:   value       = kubernetes_manifest.argocd_app.manifest.metadata.namespace
 9: }
10:
11: output "app_uid" {
12:   description = "UID of the ArgoCD Application resource"
13:   value       = kubernetes_manifest.argocd_app.manifest.metadata.uid
14: }
15:
16: output "destination_namespace" {
17:   description = "Target Kubernetes namespace for the application"
18:   value       = var.destination_namespace
19: }
20:
21: output "repo_url" {
22:   description = "Git repository URL for the Application"
23:   value       = var.repo_url
24: }
25:
26: output "repo_path" {
27:   description = "Path within the repository"
28:   value       = var.repo_path
29: }
30:
31: output "target_revision" {
32:   description = "Git branch/tag/commit being synced"
33:   value       = var.target_revision
34: }
```

## File: application/modules/cert-manager/outputs.tf
```hcl
1: output "certificate_secret_name" {
2:   description = "Name of the Kubernetes secret containing the TLS certificate"
3:   value       = "openldap-tls"
4: }
```

## File: application/modules/cert-manager/variables.tf
```hcl
 1: variable "cluster_name" {
 2:   description = "Name of the EKS cluster"
 3:   type        = string
 4: }
 5:
 6: variable "namespace" {
 7:   description = "Kubernetes namespace where OpenLDAP is deployed"
 8:   type        = string
 9: }
10:
11: variable "domain_name" {
12:   description = "Domain name for certificate DNS names"
13:   type        = string
14: }
```

## File: application/modules/network-policies/outputs.tf
```hcl
 1: output "network_policy_name" {
 2:   description = "Name of the network policy for secure namespace communication"
 3:   value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].name
 4: }
 5:
 6: output "network_policy_namespace" {
 7:   description = "Namespace where the network policy is applied"
 8:   value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].namespace
 9: }
10:
11: output "network_policy_uid" {
12:   description = "UID of the network policy resource"
13:   value       = kubernetes_network_policy_v1.namespace_secure_communication.metadata[0].uid
14: }
```

## File: application/modules/network-policies/variables.tf
```hcl
1: variable "namespace" {
2:   description = "Kubernetes namespace where network policies will be applied"
3:   type        = string
4:   default     = "ldap"
5: }
```

## File: application/modules/postgresql/outputs.tf
```hcl
 1: output "host" {
 2:   description = "PostgreSQL service hostname"
 3:   value       = "postgresql.${var.namespace}.svc.cluster.local"
 4: }
 5:
 6: output "port" {
 7:   description = "PostgreSQL service port"
 8:   value       = 5432
 9: }
10:
11: output "database" {
12:   description = "Database name"
13:   value       = var.database_name
14: }
15:
16: output "username" {
17:   description = "Database username"
18:   value       = var.database_username
19: }
20:
21: output "connection_url" {
22:   description = "PostgreSQL connection URL (without password)"
23:   value       = "postgresql+asyncpg://${var.database_username}@postgresql.${var.namespace}.svc.cluster.local:5432/${var.database_name}"
24: }
25:
26: output "namespace" {
27:   description = "Kubernetes namespace where PostgreSQL is deployed"
28:   value       = var.namespace
29: }
```

## File: application/modules/redis/outputs.tf
```hcl
 1: output "redis_enabled" {
 2:   description = "Whether Redis is enabled"
 3:   value       = var.enable_redis
 4: }
 5:
 6: output "redis_host" {
 7:   description = "Redis service hostname"
 8:   value       = var.enable_redis ? "redis-master.${var.namespace}.svc.cluster.local" : ""
 9: }
10:
11: output "redis_port" {
12:   description = "Redis service port"
13:   value       = 6379
14: }
15:
16: output "redis_namespace" {
17:   description = "Kubernetes namespace where Redis is deployed"
18:   value       = var.enable_redis ? var.namespace : ""
19: }
20:
21: output "redis_password_secret_name" {
22:   description = "Name of the Kubernetes secret containing Redis password"
23:   value       = var.enable_redis ? var.secret_name : ""
24: }
25:
26: output "redis_password_secret_key" {
27:   description = "Key in the secret for Redis password"
28:   value       = "redis-password"
29: }
30:
31: output "redis_connection_url" {
32:   description = "Redis connection URL (without password)"
33:   value       = var.enable_redis ? "redis://redis-master.${var.namespace}.svc.cluster.local:6379/0" : ""
34: }
```

## File: application/modules/route53/outputs.tf
```hcl
 1: output "acm_cert_arn" {
 2:   description = "ACM certificate ARN (validated and ready for use)"
 3:   value       = module.acm.acm_certificate_arn
 4: }
 5:
 6: output "domain_name" {
 7:   description = "Root domain name"
 8:   value       = local.domain_name
 9: }
10:
11: output "zone_id" {
12:   description = "Route53 hosted zone ID"
13:   value       = local.zone_id
14: }
15:
16: output "name_servers" {
17:   description = "Route53 name servers for the hosted zone (for registrar configuration)"
18:   value       = try(data.aws_route53_zone.this[0].name_servers, aws_route53_zone.this[0].name_servers)
19: }
```

## File: application/modules/route53/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment (for tagging)"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Prefix for the resources"
13:   type        = string
14: }
15:
16: variable "domain_name" {
17:   description = "Root domain name (e.g., talorlik.com)"
18:   type        = string
19: }
20:
21: variable "subject_alternative_names" {
22:   description = "List of subject alternative names for the ACM certificate (e.g., [\"*.talorlik.com\"])"
23:   type        = list(string)
24:   default     = []
25: }
26:
27: variable "use_existing_route53_zone" {
28:   description = "Whether to use an existing Route53 zone"
29:   type        = bool
30:   default     = false
31: }
32:
33: variable "tags" {
34:   description = "Tags to apply to the resources"
35:   type        = map(string)
36:   default     = {}
37: }
```

## File: application/modules/route53_record/main.tf
```hcl
 1: # Route53 A (alias) record pointing to an ALB
 2: resource "aws_route53_record" "this" {
 3:   provider = aws.state_account
 4:
 5:   zone_id = var.zone_id
 6:   name    = var.name
 7:   type    = "A"
 8:
 9:   alias {
10:     name                   = var.alb_dns_name
11:     zone_id                = var.alb_zone_id
12:     evaluate_target_health = var.evaluate_target_health
13:   }
14:
15:   lifecycle {
16:     create_before_destroy = true
17:
18:     # Precondition: Ensure ALB DNS name is never null or empty
19:     precondition {
20:       condition     = var.alb_dns_name != null && var.alb_dns_name != ""
21:       error_message = "ALB DNS name must be available before creating Route53 record. Ensure the ALB has been provisioned."
22:     }
23:   }
24: }
```

## File: application/modules/route53_record/outputs.tf
```hcl
 1: output "record_name" {
 2:   description = "Route53 record name"
 3:   value       = aws_route53_record.this.name
 4: }
 5:
 6: output "record_fqdn" {
 7:   description = "Fully qualified domain name (FQDN) of the Route53 record"
 8:   value       = aws_route53_record.this.fqdn
 9: }
10:
11: output "record_id" {
12:   description = "Route53 record ID"
13:   value       = aws_route53_record.this.id
14: }
```

## File: application/modules/route53_record/variables.tf
```hcl
 1: variable "zone_id" {
 2:   description = "Route53 hosted zone ID for creating DNS records"
 3:   type        = string
 4: }
 5:
 6: variable "name" {
 7:   description = "DNS record name (e.g., phpldapadmin.talorlik.com)"
 8:   type        = string
 9: }
10:
11: variable "alb_dns_name" {
12:   description = "DNS name of the ALB to point the record to"
13:   type        = string
14: }
15:
16: variable "alb_zone_id" {
17:   description = "ALB canonical hosted zone ID for Route53 alias records. This should be computed from the region mapping."
18:   type        = string
19: }
20:
21: variable "evaluate_target_health" {
22:   description = "Whether to evaluate target health for the alias record"
23:   type        = bool
24:   default     = true
25: }
```

## File: application/modules/ses/outputs.tf
```hcl
 1: output "sender_email" {
 2:   description = "Verified sender email address"
 3:   value       = var.sender_email
 4: }
 5:
 6: output "sender_domain" {
 7:   description = "Verified sender domain (if configured)"
 8:   value       = var.sender_domain
 9: }
10:
11: output "iam_role_arn" {
12:   description = "ARN of the IAM role for SES access"
13:   value       = aws_iam_role.ses_sender.arn
14: }
15:
16: output "iam_role_name" {
17:   description = "Name of the IAM role for SES access"
18:   value       = aws_iam_role.ses_sender.name
19: }
20:
21: output "email_identity_arn" {
22:   description = "ARN of the SES email identity"
23:   value       = var.sender_domain != null ? aws_ses_domain_identity.sender[0].arn : aws_ses_email_identity.sender[0].arn
24: }
25:
26: output "verification_status" {
27:   description = "Instructions for email verification"
28:   value       = var.sender_domain == null ? "Check inbox of ${var.sender_email} and click verification link from AWS" : "Domain verification via DNS records"
29: }
```

## File: application/modules/ses/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Name prefix for resources"
13:   type        = string
14: }
15:
16: variable "cluster_name" {
17:   description = "EKS cluster name for IRSA"
18:   type        = string
19: }
20:
21: variable "sender_email" {
22:   description = "Email address to send verification emails from (must be verified in SES)"
23:   type        = string
24: }
25:
26: variable "sender_domain" {
27:   description = "Domain to verify in SES for sending emails. If null, will verify sender_email as individual address."
28:   type        = string
29:   default     = null
30: }
31:
32: variable "iam_role_name" {
33:   description = "Name component for the SES IAM role"
34:   type        = string
35:   default     = "ses-sender"
36: }
37:
38: variable "service_account_namespace" {
39:   description = "Kubernetes namespace for the service account"
40:   type        = string
41:   default     = "ldap-2fa"
42: }
43:
44: variable "service_account_name" {
45:   description = "Name of the Kubernetes service account"
46:   type        = string
47:   default     = "ldap-2fa-backend"
48: }
49:
50: variable "route53_zone_id" {
51:   description = "Route53 zone ID for domain verification records (optional, for domain verification)"
52:   type        = string
53:   default     = null
54: }
55:
56: variable "tags" {
57:   description = "Tags to apply to resources"
58:   type        = map(string)
59:   default     = {}
60: }
```

## File: application/modules/sns/main.tf
```hcl
  1: # SNS Module for SMS-based 2FA Verification
  2: #
  3: # This module creates:
  4: # - SNS Topic for SMS notifications
  5: # - IAM Role for EKS Service Account (IRSA) to publish to SNS
  6: # - IAM Policy for SNS SMS publishing
  7:
  8: locals {
  9:   sns_topic_name = "${var.prefix}-${var.region}-${var.sns_topic_name}-${var.env}"
 10:   iam_role_name  = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
 11: }
 12:
 13: # Data source to get AWS account ID
 14: data "aws_caller_identity" "current" {}
 15:
 16: # Data source to get EKS cluster OIDC provider
 17: data "aws_eks_cluster" "cluster" {
 18:   name = var.cluster_name
 19: }
 20:
 21: # SNS Topic for SMS messages
 22: resource "aws_sns_topic" "sms" {
 23:   name         = local.sns_topic_name
 24:   display_name = var.sns_display_name
 25:
 26:   tags = var.tags
 27: }
 28:
 29: # SNS Topic Policy - allows the IAM role to publish
 30: resource "aws_sns_topic_policy" "sms" {
 31:   arn = aws_sns_topic.sms.arn
 32:
 33:   policy = jsonencode({
 34:     Version = "2012-10-17"
 35:     Id      = "SNSTopicPolicy"
 36:     Statement = [
 37:       {
 38:         Sid    = "AllowPublishFromIAMRole"
 39:         Effect = "Allow"
 40:         Principal = {
 41:           AWS = aws_iam_role.sns_publisher.arn
 42:         }
 43:         Action   = "sns:Publish"
 44:         Resource = aws_sns_topic.sms.arn
 45:       }
 46:     ]
 47:   })
 48: }
 49:
 50: # IAM Role for EKS Service Account (IRSA)
 51: resource "aws_iam_role" "sns_publisher" {
 52:   name = local.iam_role_name
 53:
 54:   assume_role_policy = jsonencode({
 55:     Version = "2012-10-17"
 56:     Statement = [
 57:       {
 58:         Effect = "Allow"
 59:         Principal = {
 60:           Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
 61:         }
 62:         Action = "sts:AssumeRoleWithWebIdentity"
 63:         Condition = {
 64:           StringEquals = {
 65:             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
 66:             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
 67:           }
 68:         }
 69:       }
 70:     ]
 71:   })
 72:
 73:   tags = var.tags
 74: }
 75:
 76: # IAM Policy for SNS SMS publishing
 77: resource "aws_iam_role_policy" "sns_publish" {
 78:   name = "${local.iam_role_name}-policy"
 79:   role = aws_iam_role.sns_publisher.id
 80:
 81:   policy = jsonencode({
 82:     Version = "2012-10-17"
 83:     Statement = [
 84:       {
 85:         Sid    = "AllowSNSPublish"
 86:         Effect = "Allow"
 87:         Action = [
 88:           "sns:Publish"
 89:         ]
 90:         Resource = aws_sns_topic.sms.arn
 91:       },
 92:       {
 93:         Sid    = "AllowDirectSMSPublish"
 94:         Effect = "Allow"
 95:         Action = [
 96:           "sns:Publish"
 97:         ]
 98:         Resource = "*"
 99:         Condition = {
100:           StringEquals = {
101:             "sns:Protocol" = "sms"
102:           }
103:         }
104:       },
105:       {
106:         Sid    = "AllowSNSSubscribe"
107:         Effect = "Allow"
108:         Action = [
109:           "sns:Subscribe",
110:           "sns:ConfirmSubscription",
111:           "sns:Unsubscribe",
112:           "sns:ListSubscriptionsByTopic"
113:         ]
114:         Resource = aws_sns_topic.sms.arn
115:       },
116:       {
117:         Sid    = "AllowSNSCheckOptOut"
118:         Effect = "Allow"
119:         Action = [
120:           "sns:CheckIfPhoneNumberIsOptedOut",
121:           "sns:OptInPhoneNumber"
122:         ]
123:         Resource = "*"
124:       }
125:     ]
126:   })
127: }
128:
129: # Set SMS attributes for the account (optional - for production use)
130: resource "aws_sns_sms_preferences" "sms_preferences" {
131:   count = var.configure_sms_preferences ? 1 : 0
132:
133:   default_sender_id   = var.sms_sender_id
134:   default_sms_type    = var.sms_type
135:   monthly_spend_limit = var.sms_monthly_spend_limit
136:
137:   # Note: delivery_status_iam_role_arn and delivery_status_success_sampling_rate
138:   # can be configured for SMS delivery status logging
139: }
```

## File: application/modules/sns/outputs.tf
```hcl
 1: output "sns_topic_arn" {
 2:   description = "ARN of the SNS topic for SMS"
 3:   value       = aws_sns_topic.sms.arn
 4: }
 5:
 6: output "sns_topic_name" {
 7:   description = "Name of the SNS topic"
 8:   value       = aws_sns_topic.sms.name
 9: }
10:
11: output "iam_role_arn" {
12:   description = "ARN of the IAM role for SNS publishing"
13:   value       = aws_iam_role.sns_publisher.arn
14: }
15:
16: output "iam_role_name" {
17:   description = "Name of the IAM role"
18:   value       = aws_iam_role.sns_publisher.name
19: }
20:
21: output "service_account_annotation" {
22:   description = "Annotation to add to Kubernetes service account for IRSA"
23:   value = {
24:     "eks.amazonaws.com/role-arn" = aws_iam_role.sns_publisher.arn
25:   }
26: }
```

## File: application/modules/sns/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "AWS region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Prefix for resource names"
13:   type        = string
14: }
15:
16: variable "cluster_name" {
17:   description = "Name of the EKS cluster"
18:   type        = string
19: }
20:
21: variable "sns_topic_name" {
22:   description = "Name component for the SNS topic"
23:   type        = string
24:   default     = "2fa-sms"
25: }
26:
27: variable "sns_display_name" {
28:   description = "Display name for the SNS topic (appears in SMS sender)"
29:   type        = string
30:   default     = "2FA Verification"
31: }
32:
33: variable "iam_role_name" {
34:   description = "Name component for the IAM role"
35:   type        = string
36:   default     = "2fa-sns-publisher"
37: }
38:
39: variable "service_account_namespace" {
40:   description = "Kubernetes namespace for the service account"
41:   type        = string
42:   default     = "2fa-app"
43: }
44:
45: variable "service_account_name" {
46:   description = "Name of the Kubernetes service account"
47:   type        = string
48:   default     = "ldap-2fa-backend"
49: }
50:
51: variable "configure_sms_preferences" {
52:   description = "Whether to configure account-level SMS preferences"
53:   type        = bool
54:   default     = false
55: }
56:
57: variable "sms_sender_id" {
58:   description = "Default sender ID for SMS messages (max 11 alphanumeric characters)"
59:   type        = string
60:   default     = "2FA"
61: }
62:
63: variable "sms_type" {
64:   description = "Default SMS type: Promotional or Transactional"
65:   type        = string
66:   default     = "Transactional"
67:   validation {
68:     condition     = contains(["Promotional", "Transactional"], var.sms_type)
69:     error_message = "SMS type must be either 'Promotional' or 'Transactional'"
70:   }
71: }
72:
73: variable "sms_monthly_spend_limit" {
74:   description = "Monthly spend limit for SMS in USD"
75:   type        = number
76:   default     = 10
77: }
78:
79: variable "tags" {
80:   description = "Tags to apply to resources"
81:   type        = map(string)
82:   default     = {}
83: }
```

## File: application/tfstate-backend-values-template.hcl
```hcl
1: bucket         = "<BACKEND_BUCKET_NAME>"
2: key            = "<APPLICATION_PREFIX>"
3: region         = "<AWS_REGION>"
```

## File: backend_infra/modules/ebs/main.tf
```hcl
 1: # Resources in the Kubernetes Cluster such as StorageClass
 2: # *** EKS Auto mode has its own EBS CSI driver ***
 3: # There is no need to install one
 4:
 5: # *** EKS Auto Mode takes care of IAM permissions ***
 6: # There is no need to attach AmazonEBSCSIDriverPolicy to the EKS Node IAM Role
 7:
 8: # EBS Storage Class
 9: resource "kubernetes_storage_class" "ebs" {
10:   metadata {
11:     name = "${var.prefix}-${var.region}-${var.ebs_name}-${var.env}"
12:     annotations = {
13:       "storageclass.kubernetes.io/is-default-class" = "true"
14:     }
15:   }
16:
17:   # *** This setting specifies the EKS Auto Mode provisioner ***
18:   storage_provisioner = "ebs.csi.eks.amazonaws.com"
19:
20:   # The reclaim policy for a PersistentVolume tells the cluster
21:   # what to do with the volume after it has been released of its claim
22:   reclaim_policy = "Delete"
23:
24:   # Delay the binding and provisioning of a PersistentVolume until a Pod
25:   # using the PersistentVolumeClaim is created
26:   volume_binding_mode = "WaitForFirstConsumer"
27:
28:   # see StorageClass Parameters Reference here:
29:   # https://docs.aws.amazon.com/eks/latest/userguide/create-storage-class.html
30:   parameters = {
31:     type      = "gp3"
32:     encrypted = "true"
33:   }
34: }
35:
36: # EBS Persistent Volume Claim
37: resource "kubernetes_persistent_volume_claim_v1" "ebs_pvc" {
38:   metadata {
39:     name = "${var.prefix}-${var.region}-${var.ebs_claim_name}-${var.env}"
40:   }
41:
42:   spec {
43:     # Volume can be mounted as read-write by a single node
44:     #
45:     # ReadWriteOnce access mode should enable multiple pods to
46:     # access it when the pods are running on the same node.
47:     #
48:     # Using EKS Auto Mode it appears to only allow one pod to access it
49:     access_modes = ["ReadWriteOnce"]
50:
51:     resources {
52:       requests = {
53:         storage = "1Gi"
54:       }
55:     }
56:
57:     storage_class_name = kubernetes_storage_class.ebs.metadata[0].name
58:   }
59:
60:   # Setting this allows `Terraform apply` to continue
61:   # Otherwise it would hang here waiting for claim to bind to a pod
62:   wait_until_bound = false
63: }
64:
65: # This will create the PVC, which will wait until a pod needs it, and then create a PersistentVolume
```

## File: backend_infra/modules/ebs/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Name added to all resources"
13:   type        = string
14: }
15:
16: variable "ebs_name" {
17:   description = "The name of the EBS"
18:   type        = string
19: }
20:
21: variable "ebs_claim_name" {
22:   description = "The name of the EBS claim"
23:   type        = string
24: }
```

## File: backend_infra/modules/ecr/main.tf
```hcl
 1: locals {
 2:   ecr_name = "${var.prefix}-${var.region}-${var.ecr_name}-${var.env}"
 3: }
 4:
 5: resource "aws_ecr_repository" "ecr" {
 6:   name                 = local.ecr_name
 7:   image_tag_mutability = var.image_tag_mutability
 8:   force_delete         = true
 9:
10:   tags = merge(
11:     {
12:       Name = "${local.ecr_name}"
13:     },
14:     var.tags
15:   )
16: }
17:
18: resource "aws_ecr_lifecycle_policy" "ecr_policy" {
19:   repository = aws_ecr_repository.ecr.name
20:   policy     = var.policy
21: }
```

## File: backend_infra/modules/ecr/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9:   default     = "us-east-1"
10: }
11:
12: variable "prefix" {
13:   description = "Name added to all resources"
14:   type        = string
15: }
16:
17: variable "ecr_name" {
18:   description = "The name of the ECR"
19:   type        = string
20: }
21:
22: variable "image_tag_mutability" {
23:   description = "The value that determines if the image is overridable"
24:   type        = string
25: }
26:
27: variable "policy" {
28:   type = string
29: }
30:
31: variable "tags" {
32:   type = map(string)
33: }
```

## File: backend_infra/tfstate-backend-values-template.hcl
```hcl
1: bucket         = "<BACKEND_BUCKET_NAME>"
2: key            = "<BACKEND_PREFIX>"
3: region         = "<AWS_REGION>"
```

## File: tf_backend_state/outputs.tf
```hcl
1: output "bucket_name" {
2:   value = aws_s3_bucket.terraform_state.bucket
3: }
```

## File: tf_backend_state/providers.tf
```hcl
 1: terraform {
 2:   required_providers {
 3:     aws = {
 4:       source  = "hashicorp/aws"
 5:       version = "= 6.21.0"
 6:     }
 7:   }
 8:
 9:   required_version = "~> 1.14.0"
10: }
11:
12: provider "aws" {
13:   region = var.region
14: }
```

## File: application/backend/helm/ldap-2fa-backend/templates/configmap.yaml
```yaml
 1: apiVersion: v1
 2: kind: ConfigMap
 3: metadata:
 4:   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 5:   labels:
 6:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
 7: data:
 8:   # LDAP Configuration
 9:   LDAP_HOST: {{ .Values.ldap.host | quote }}
10:   LDAP_PORT: {{ .Values.ldap.port | quote }}
11:   LDAP_USE_SSL: {{ .Values.ldap.useSsl | quote }}
12:   LDAP_BASE_DN: {{ .Values.ldap.baseDn | quote }}
13:   LDAP_ADMIN_DN: {{ .Values.ldap.adminDn | quote }}
14:   LDAP_USER_SEARCH_BASE: {{ .Values.ldap.userSearchBase | quote }}
15:   LDAP_USER_SEARCH_FILTER: {{ .Values.ldap.userSearchFilter | quote }}
16:   LDAP_ADMIN_GROUP_DN: {{ .Values.ldapAdmin.groupDn | quote }}
17:   LDAP_USERS_GID: {{ .Values.ldapAdmin.usersGid | quote }}
18:   LDAP_UID_START: {{ .Values.ldapAdmin.uidStart | quote }}
19:   # Database Configuration
20:   {{- if not .Values.database.externalSecret.enabled }}
21:   DATABASE_URL: {{ .Values.database.url | quote }}
22:   {{- end }}
23:   # Email/SES Configuration
24:   ENABLE_EMAIL_VERIFICATION: {{ .Values.email.enabled | quote }}
25:   SES_SENDER_EMAIL: {{ .Values.email.senderEmail | quote }}
26:   EMAIL_VERIFICATION_EXPIRY_HOURS: {{ .Values.email.verificationExpiryHours | quote }}
27:   APP_URL: {{ .Values.email.appUrl | quote }}
28:   # MFA/TOTP Configuration
29:   TOTP_ISSUER: {{ .Values.mfa.issuer | quote }}
30:   TOTP_DIGITS: {{ .Values.mfa.digits | quote }}
31:   TOTP_INTERVAL: {{ .Values.mfa.interval | quote }}
32:   TOTP_ALGORITHM: {{ .Values.mfa.algorithm | quote }}
33:   # SMS/SNS Configuration
34:   ENABLE_SMS_2FA: {{ .Values.sms.enabled | quote }}
35:   AWS_REGION: {{ .Values.sms.awsRegion | quote }}
36:   SNS_TOPIC_ARN: {{ .Values.sms.snsTopicArn | quote }}
37:   SMS_SENDER_ID: {{ .Values.sms.senderId | quote }}
38:   SMS_TYPE: {{ .Values.sms.smsType | quote }}
39:   SMS_CODE_LENGTH: {{ .Values.sms.codeLength | quote }}
40:   SMS_CODE_EXPIRY_SECONDS: {{ .Values.sms.codeExpirySeconds | quote }}
41:   SMS_MESSAGE_TEMPLATE: {{ .Values.sms.messageTemplate | quote }}
42:   # Application Configuration
43:   APP_NAME: {{ .Values.app.name | quote }}
44:   DEBUG: {{ .Values.app.debug | quote }}
45:   LOG_LEVEL: {{ .Values.app.logLevel | quote }}
46:   CORS_ORIGINS: {{ .Values.app.corsOrigins | quote }}
47:   # Redis Configuration
48:   REDIS_ENABLED: {{ .Values.redis.enabled | quote }}
49:   REDIS_HOST: {{ .Values.redis.host | quote }}
50:   REDIS_PORT: {{ .Values.redis.port | quote }}
51:   REDIS_DB: {{ .Values.redis.db | quote }}
52:   REDIS_SSL: {{ .Values.redis.ssl | quote }}
53:   REDIS_KEY_PREFIX: {{ .Values.redis.keyPrefix | quote }}
```

## File: application/backend/helm/ldap-2fa-backend/templates/deployment.yaml
```yaml
  1: apiVersion: apps/v1
  2: kind: Deployment
  3: metadata:
  4:   name: {{ include "ldap-2fa-backend.fullname" . }}
  5:   labels:
  6:     {{- include "ldap-2fa-backend.labels" . | nindent 4 }}
  7: spec:
  8:   {{- if not .Values.autoscaling.enabled }}
  9:   replicas: {{ .Values.replicaCount }}
 10:   {{- end }}
 11:   selector:
 12:     matchLabels:
 13:       {{- include "ldap-2fa-backend.selectorLabels" . | nindent 6 }}
 14:   template:
 15:     metadata:
 16:       annotations:
 17:         # Force rollout on configmap changes
 18:         checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
 19:         {{- with .Values.podAnnotations }}
 20:         {{- toYaml . | nindent 8 }}
 21:         {{- end }}
 22:       labels:
 23:         {{- include "ldap-2fa-backend.labels" . | nindent 8 }}
 24:         {{- with .Values.podLabels }}
 25:         {{- toYaml . | nindent 8 }}
 26:         {{- end }}
 27:     spec:
 28:       {{- with .Values.imagePullSecrets }}
 29:       imagePullSecrets:
 30:         {{- toYaml . | nindent 8 }}
 31:       {{- end }}
 32:       serviceAccountName: {{ include "ldap-2fa-backend.serviceAccountName" . }}
 33:       {{- with .Values.podSecurityContext }}
 34:       securityContext:
 35:         {{- toYaml . | nindent 8 }}
 36:       {{- end }}
 37:       containers:
 38:         - name: {{ .Chart.Name }}
 39:           {{- with .Values.securityContext }}
 40:           securityContext:
 41:             {{- toYaml . | nindent 12 }}
 42:           {{- end }}
 43:           image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
 44:           imagePullPolicy: {{ .Values.image.pullPolicy }}
 45:           ports:
 46:             - name: http
 47:               containerPort: {{ .Values.service.port }}
 48:               protocol: TCP
 49:           env:
 50:             # LDAP Configuration
 51:             - name: LDAP_HOST
 52:               valueFrom:
 53:                 configMapKeyRef:
 54:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 55:                   key: LDAP_HOST
 56:             - name: LDAP_PORT
 57:               valueFrom:
 58:                 configMapKeyRef:
 59:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 60:                   key: LDAP_PORT
 61:             - name: LDAP_USE_SSL
 62:               valueFrom:
 63:                 configMapKeyRef:
 64:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 65:                   key: LDAP_USE_SSL
 66:             - name: LDAP_BASE_DN
 67:               valueFrom:
 68:                 configMapKeyRef:
 69:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 70:                   key: LDAP_BASE_DN
 71:             - name: LDAP_ADMIN_DN
 72:               valueFrom:
 73:                 configMapKeyRef:
 74:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 75:                   key: LDAP_ADMIN_DN
 76:             - name: LDAP_USER_SEARCH_BASE
 77:               valueFrom:
 78:                 configMapKeyRef:
 79:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 80:                   key: LDAP_USER_SEARCH_BASE
 81:             - name: LDAP_USER_SEARCH_FILTER
 82:               valueFrom:
 83:                 configMapKeyRef:
 84:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 85:                   key: LDAP_USER_SEARCH_FILTER
 86:             - name: LDAP_ADMIN_GROUP_DN
 87:               valueFrom:
 88:                 configMapKeyRef:
 89:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 90:                   key: LDAP_ADMIN_GROUP_DN
 91:             - name: LDAP_USERS_GID
 92:               valueFrom:
 93:                 configMapKeyRef:
 94:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
 95:                   key: LDAP_USERS_GID
 96:             - name: LDAP_UID_START
 97:               valueFrom:
 98:                 configMapKeyRef:
 99:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
100:                   key: LDAP_UID_START
101:             # LDAP Admin Password from Secret
102:             {{- if .Values.externalSecret.enabled }}
103:             - name: LDAP_ADMIN_PASSWORD
104:               valueFrom:
105:                 secretKeyRef:
106:                   name: {{ .Values.externalSecret.secretName }}
107:                   key: {{ .Values.externalSecret.adminPasswordKey }}
108:             {{- end }}
109:             # Database Configuration
110:             {{- if .Values.database.externalSecret.enabled }}
111:             - name: DATABASE_URL
112:               valueFrom:
113:                 secretKeyRef:
114:                   name: {{ .Values.database.externalSecret.secretName }}
115:                   key: {{ .Values.database.externalSecret.passwordKey }}
116:             {{- else }}
117:             - name: DATABASE_URL
118:               valueFrom:
119:                 configMapKeyRef:
120:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
121:                   key: DATABASE_URL
122:             {{- end }}
123:             # Email/SES Configuration
124:             - name: ENABLE_EMAIL_VERIFICATION
125:               valueFrom:
126:                 configMapKeyRef:
127:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
128:                   key: ENABLE_EMAIL_VERIFICATION
129:             - name: SES_SENDER_EMAIL
130:               valueFrom:
131:                 configMapKeyRef:
132:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
133:                   key: SES_SENDER_EMAIL
134:             - name: EMAIL_VERIFICATION_EXPIRY_HOURS
135:               valueFrom:
136:                 configMapKeyRef:
137:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
138:                   key: EMAIL_VERIFICATION_EXPIRY_HOURS
139:             - name: APP_URL
140:               valueFrom:
141:                 configMapKeyRef:
142:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
143:                   key: APP_URL
144:             # MFA/TOTP Configuration
145:             - name: TOTP_ISSUER
146:               valueFrom:
147:                 configMapKeyRef:
148:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
149:                   key: TOTP_ISSUER
150:             - name: TOTP_DIGITS
151:               valueFrom:
152:                 configMapKeyRef:
153:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
154:                   key: TOTP_DIGITS
155:             - name: TOTP_INTERVAL
156:               valueFrom:
157:                 configMapKeyRef:
158:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
159:                   key: TOTP_INTERVAL
160:             - name: TOTP_ALGORITHM
161:               valueFrom:
162:                 configMapKeyRef:
163:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
164:                   key: TOTP_ALGORITHM
165:             # SMS/SNS Configuration
166:             - name: ENABLE_SMS_2FA
167:               valueFrom:
168:                 configMapKeyRef:
169:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
170:                   key: ENABLE_SMS_2FA
171:             - name: AWS_REGION
172:               valueFrom:
173:                 configMapKeyRef:
174:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
175:                   key: AWS_REGION
176:             - name: SNS_TOPIC_ARN
177:               valueFrom:
178:                 configMapKeyRef:
179:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
180:                   key: SNS_TOPIC_ARN
181:             - name: SMS_SENDER_ID
182:               valueFrom:
183:                 configMapKeyRef:
184:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
185:                   key: SMS_SENDER_ID
186:             - name: SMS_TYPE
187:               valueFrom:
188:                 configMapKeyRef:
189:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
190:                   key: SMS_TYPE
191:             - name: SMS_CODE_LENGTH
192:               valueFrom:
193:                 configMapKeyRef:
194:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
195:                   key: SMS_CODE_LENGTH
196:             - name: SMS_CODE_EXPIRY_SECONDS
197:               valueFrom:
198:                 configMapKeyRef:
199:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
200:                   key: SMS_CODE_EXPIRY_SECONDS
201:             - name: SMS_MESSAGE_TEMPLATE
202:               valueFrom:
203:                 configMapKeyRef:
204:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
205:                   key: SMS_MESSAGE_TEMPLATE
206:             # Application Configuration
207:             - name: APP_NAME
208:               valueFrom:
209:                 configMapKeyRef:
210:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
211:                   key: APP_NAME
212:             - name: DEBUG
213:               valueFrom:
214:                 configMapKeyRef:
215:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
216:                   key: DEBUG
217:             - name: LOG_LEVEL
218:               valueFrom:
219:                 configMapKeyRef:
220:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
221:                   key: LOG_LEVEL
222:             - name: CORS_ORIGINS
223:               valueFrom:
224:                 configMapKeyRef:
225:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
226:                   key: CORS_ORIGINS
227:             # Redis Configuration
228:             - name: REDIS_ENABLED
229:               valueFrom:
230:                 configMapKeyRef:
231:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
232:                   key: REDIS_ENABLED
233:             - name: REDIS_HOST
234:               valueFrom:
235:                 configMapKeyRef:
236:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
237:                   key: REDIS_HOST
238:             - name: REDIS_PORT
239:               valueFrom:
240:                 configMapKeyRef:
241:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
242:                   key: REDIS_PORT
243:             - name: REDIS_DB
244:               valueFrom:
245:                 configMapKeyRef:
246:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
247:                   key: REDIS_DB
248:             - name: REDIS_SSL
249:               valueFrom:
250:                 configMapKeyRef:
251:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
252:                   key: REDIS_SSL
253:             - name: REDIS_KEY_PREFIX
254:               valueFrom:
255:                 configMapKeyRef:
256:                   name: {{ include "ldap-2fa-backend.fullname" . }}-config
257:                   key: REDIS_KEY_PREFIX
258:             # Redis Password from Secret
259:             {{- if .Values.redis.existingSecret.enabled }}
260:             - name: REDIS_PASSWORD
261:               valueFrom:
262:                 secretKeyRef:
263:                   name: {{ .Values.redis.existingSecret.name }}
264:                   key: {{ .Values.redis.existingSecret.key }}
265:             {{- end }}
266:           {{- with .Values.livenessProbe }}
267:           livenessProbe:
268:             {{- toYaml . | nindent 12 }}
269:           {{- end }}
270:           {{- with .Values.readinessProbe }}
271:           readinessProbe:
272:             {{- toYaml . | nindent 12 }}
273:           {{- end }}
274:           {{- with .Values.resources }}
275:           resources:
276:             {{- toYaml . | nindent 12 }}
277:           {{- end }}
278:           {{- with .Values.volumeMounts }}
279:           volumeMounts:
280:             {{- toYaml . | nindent 12 }}
281:           {{- end }}
282:       {{- with .Values.volumes }}
283:       volumes:
284:         {{- toYaml . | nindent 8 }}
285:       {{- end }}
286:       {{- with .Values.nodeSelector }}
287:       nodeSelector:
288:         {{- toYaml . | nindent 8 }}
289:       {{- end }}
290:       {{- with .Values.affinity }}
291:       affinity:
292:         {{- toYaml . | nindent 8 }}
293:       {{- end }}
294:       {{- with .Values.tolerations }}
295:       tolerations:
296:         {{- toYaml . | nindent 8 }}
297:       {{- end }}
```

## File: application/backend/helm/ldap-2fa-backend/.helmignore
```
 1: # Patterns to ignore when building packages.
 2: # This supports shell glob matching, relative path matching, and
 3: # negation (prefixed with !). Only one pattern per line.
 4: .DS_Store
 5: # Common VCS dirs
 6: .git/
 7: .gitignore
 8: .bzr/
 9: .bzrignore
10: .hg/
11: .hgignore
12: .svn/
13: # Common backup files
14: *.swp
15: *.bak
16: *.tmp
17: *.orig
18: *~
19: # Various IDEs
20: .project
21: .idea/
22: *.tmproj
23: .vscode/
24: .cursor/
25: # General
26: .github/
```

## File: application/backend/src/app/database/__init__.py
```python
 1: """Database package for user storage and management."""
 2: from app.database.connection import (
 3:     get_db,
 4:     init_db,
 5:     close_db,
 6:     get_async_session,
 7:     AsyncSessionLocal,
 8: )
 9: from app.database.models import (
10:     Base,
11:     User,
12:     VerificationToken,
13:     ProfileStatus,
14:     Group,
15:     UserGroup,
16: )
17: __all__ = [
18:     "get_db",
19:     "init_db",
20:     "close_db",
21:     "get_async_session",
22:     "AsyncSessionLocal",
23:     "Base",
24:     "User",
25:     "VerificationToken",
26:     "ProfileStatus",
27:     "Group",
28:     "UserGroup",
29: ]
```

## File: application/backend/src/app/database/models.py
```python
  1: """Database models for user management."""
  2: import uuid
  3: from datetime import datetime
  4: from enum import Enum
  5: from typing import Optional
  6: from sqlalchemy import (
  7:     Boolean,
  8:     DateTime,
  9:     String,
 10:     Text,
 11:     ForeignKey,
 12:     Index,
 13:     func,
 14: )
 15: from sqlalchemy.dialects.postgresql import UUID
 16: from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
 17: class Base(DeclarativeBase):
 18:     """Base class for all database models."""
 19:     pass
 20: class ProfileStatus(str, Enum):
 21:     """User profile status states."""
 22:     PENDING = "pending"  # Signup complete, verification incomplete
 23:     COMPLETE = "complete"  # Email + Phone verified, awaiting admin approval
 24:     ACTIVE = "active"  # Admin activated, user exists in LDAP
 25:     REVOKED = "revoked"  # Admin revoked, removed from LDAP
 26: class MFAMethodType(str, Enum):
 27:     """Supported MFA methods."""
 28:     TOTP = "totp"
 29:     SMS = "sms"
 30: class User(Base):
 31:     """User model for storing signup and profile information."""
 32:     __tablename__ = "users"
 33:     # Primary key
 34:     id: Mapped[uuid.UUID] = mapped_column(
 35:         UUID(as_uuid=True),
 36:         primary_key=True,
 37:         default=uuid.uuid4,
 38:     )
 39:     # Basic profile information
 40:     username: Mapped[str] = mapped_column(
 41:         String(64),
 42:         unique=True,
 43:         nullable=False,
 44:         index=True,
 45:     )
 46:     email: Mapped[str] = mapped_column(
 47:         String(255),
 48:         unique=True,
 49:         nullable=False,
 50:         index=True,
 51:     )
 52:     first_name: Mapped[str] = mapped_column(String(100), nullable=False)
 53:     last_name: Mapped[str] = mapped_column(String(100), nullable=False)
 54:     # Phone number (split into country code and number)
 55:     phone_country_code: Mapped[str] = mapped_column(
 56:         String(5),
 57:         nullable=False,
 58:     )  # e.g., "+1", "+44"
 59:     phone_number: Mapped[str] = mapped_column(
 60:         String(20),
 61:         nullable=False,
 62:     )  # e.g., "5551234567"
 63:     # Password (bcrypt hash, used when creating LDAP user)
 64:     password_hash: Mapped[str] = mapped_column(Text, nullable=False)
 65:     # Verification status
 66:     email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
 67:     phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
 68:     # Profile status
 69:     status: Mapped[str] = mapped_column(
 70:         String(20),
 71:         default=ProfileStatus.PENDING.value,
 72:         index=True,
 73:     )
 74:     # MFA settings
 75:     mfa_method: Mapped[str] = mapped_column(
 76:         String(10),
 77:         default=MFAMethodType.TOTP.value,
 78:     )
 79:     totp_secret: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
 80:     # Timestamps
 81:     created_at: Mapped[datetime] = mapped_column(
 82:         DateTime(timezone=True),
 83:         server_default=func.now(),
 84:     )
 85:     updated_at: Mapped[datetime] = mapped_column(
 86:         DateTime(timezone=True),
 87:         server_default=func.now(),
 88:         onupdate=func.now(),
 89:     )
 90:     # Admin activation
 91:     activated_at: Mapped[Optional[datetime]] = mapped_column(
 92:         DateTime(timezone=True),
 93:         nullable=True,
 94:     )
 95:     activated_by: Mapped[Optional[str]] = mapped_column(
 96:         String(64),
 97:         nullable=True,
 98:     )  # Admin username who activated
 99:     # Relationships
100:     verification_tokens: Mapped[list["VerificationToken"]] = relationship(
101:         "VerificationToken",
102:         back_populates="user",
103:         cascade="all, delete-orphan",
104:     )
105:     user_groups: Mapped[list["UserGroup"]] = relationship(
106:         "UserGroup",
107:         back_populates="user",
108:         cascade="all, delete-orphan",
109:     )
110:     # Indexes
111:     __table_args__ = (
112:         Index("ix_users_status_created", "status", "created_at"),
113:         Index("ix_users_phone", "phone_country_code", "phone_number"),
114:     )
115:     @property
116:     def full_name(self) -> str:
117:         """Get user's full name."""
118:         return f"{self.first_name} {self.last_name}"
119:     @property
120:     def full_phone_number(self) -> str:
121:         """Get full phone number with country code."""
122:         return f"{self.phone_country_code}{self.phone_number}"
123:     @property
124:     def masked_phone(self) -> str:
125:         """Get masked phone number for display."""
126:         full = self.full_phone_number
127:         if len(full) > 4:
128:             return "*" * (len(full) - 4) + full[-4:]
129:         return full
130:     @property
131:     def masked_email(self) -> str:
132:         """Get masked email for display."""
133:         if "@" not in self.email:
134:             return self.email
135:         local, domain = self.email.split("@", 1)
136:         if len(local) > 2:
137:             masked_local = local[0] + "*" * (len(local) - 2) + local[-1]
138:         else:
139:             masked_local = "*" * len(local)
140:         return f"{masked_local}@{domain}"
141:     def is_verification_complete(self) -> bool:
142:         """Check if all verifications are complete."""
143:         return self.email_verified and self.phone_verified
144:     def update_status_if_complete(self) -> bool:
145:         """Update status to COMPLETE if all verifications done."""
146:         if self.is_verification_complete() and self.status == ProfileStatus.PENDING.value:
147:             self.status = ProfileStatus.COMPLETE.value
148:             return True
149:         return False
150: class VerificationTokenType(str, Enum):
151:     """Types of verification tokens."""
152:     EMAIL = "email"
153:     PHONE = "phone"
154: class VerificationToken(Base):
155:     """Verification token model for email and phone verification."""
156:     __tablename__ = "verification_tokens"
157:     id: Mapped[uuid.UUID] = mapped_column(
158:         UUID(as_uuid=True),
159:         primary_key=True,
160:         default=uuid.uuid4,
161:     )
162:     user_id: Mapped[uuid.UUID] = mapped_column(
163:         UUID(as_uuid=True),
164:         ForeignKey("users.id", ondelete="CASCADE"),
165:         nullable=False,
166:         index=True,
167:     )
168:     token_type: Mapped[str] = mapped_column(
169:         String(10),
170:         nullable=False,
171:     )  # "email" or "phone"
172:     token: Mapped[str] = mapped_column(
173:         String(255),
174:         nullable=False,
175:         index=True,
176:     )  # UUID for email, 6-digit code for phone
177:     expires_at: Mapped[datetime] = mapped_column(
178:         DateTime(timezone=True),
179:         nullable=False,
180:     )
181:     used: Mapped[bool] = mapped_column(Boolean, default=False)
182:     created_at: Mapped[datetime] = mapped_column(
183:         DateTime(timezone=True),
184:         server_default=func.now(),
185:     )
186:     # Relationships
187:     user: Mapped["User"] = relationship("User", back_populates="verification_tokens")
188:     def is_expired(self) -> bool:
189:         """Check if token is expired."""
190:         return datetime.now(self.expires_at.tzinfo) > self.expires_at
191:     def is_valid(self) -> bool:
192:         """Check if token is valid (not used and not expired)."""
193:         return not self.used and not self.is_expired()
194: class Group(Base):
195:     """Group model for organizing users."""
196:     __tablename__ = "groups"
197:     id: Mapped[uuid.UUID] = mapped_column(
198:         UUID(as_uuid=True),
199:         primary_key=True,
200:         default=uuid.uuid4,
201:     )
202:     name: Mapped[str] = mapped_column(
203:         String(100),
204:         unique=True,
205:         nullable=False,
206:         index=True,
207:     )
208:     description: Mapped[Optional[str]] = mapped_column(
209:         Text,
210:         nullable=True,
211:     )
212:     # Corresponding LDAP group DN
213:     ldap_dn: Mapped[str] = mapped_column(
214:         String(500),
215:         nullable=False,
216:         unique=True,
217:     )
218:     # Timestamps
219:     created_at: Mapped[datetime] = mapped_column(
220:         DateTime(timezone=True),
221:         server_default=func.now(),
222:     )
223:     updated_at: Mapped[datetime] = mapped_column(
224:         DateTime(timezone=True),
225:         server_default=func.now(),
226:         onupdate=func.now(),
227:     )
228:     # Relationships
229:     user_groups: Mapped[list["UserGroup"]] = relationship(
230:         "UserGroup",
231:         back_populates="group",
232:         cascade="all, delete-orphan",
233:     )
234:     @property
235:     def member_count(self) -> int:
236:         """Get the number of members in this group."""
237:         return len(self.user_groups) if self.user_groups else 0
238: class UserGroup(Base):
239:     """Association table for user-group membership."""
240:     __tablename__ = "user_groups"
241:     user_id: Mapped[uuid.UUID] = mapped_column(
242:         UUID(as_uuid=True),
243:         ForeignKey("users.id", ondelete="CASCADE"),
244:         primary_key=True,
245:     )
246:     group_id: Mapped[uuid.UUID] = mapped_column(
247:         UUID(as_uuid=True),
248:         ForeignKey("groups.id", ondelete="CASCADE"),
249:         primary_key=True,
250:     )
251:     # Assignment metadata
252:     assigned_at: Mapped[datetime] = mapped_column(
253:         DateTime(timezone=True),
254:         server_default=func.now(),
255:     )
256:     assigned_by: Mapped[str] = mapped_column(
257:         String(64),
258:         nullable=False,
259:     )  # Admin username who assigned
260:     # Relationships
261:     user: Mapped["User"] = relationship("User", back_populates="user_groups")
262:     group: Mapped["Group"] = relationship("Group", back_populates="user_groups")
263:     # Indexes
264:     __table_args__ = (
265:         Index("ix_user_groups_user", "user_id"),
266:         Index("ix_user_groups_group", "group_id"),
267:     )
```

## File: application/backend/src/app/email/client.py
```python
  1: """AWS SES email client for sending verification emails."""
  2: import logging
  3: from typing import Optional
  4: import boto3
  5: from botocore.exceptions import ClientError
  6: from app.config import Settings, get_settings
  7: logger = logging.getLogger(__name__)
  8: class EmailClient:
  9:     """Client for sending emails via AWS SES."""
 10:     def __init__(self, settings: Optional[Settings] = None):
 11:         """Initialize email client with settings."""
 12:         self.settings = settings or get_settings()
 13:         self._client = None
 14:     @property
 15:     def client(self):
 16:         """Get or create SES client."""
 17:         if self._client is None:
 18:             self._client = boto3.client(
 19:                 "ses",
 20:                 region_name=self.settings.aws_region,
 21:             )
 22:         return self._client
 23:     def send_verification_email(
 24:         self,
 25:         to_email: str,
 26:         token: str,
 27:         username: str,
 28:         first_name: str,
 29:     ) -> tuple[bool, str]:
 30:         """
 31:         Send email verification link.
 32:         Args:
 33:             to_email: Recipient email address
 34:             token: Verification token (UUID)
 35:             username: User's username
 36:             first_name: User's first name for personalization
 37:         Returns:
 38:             Tuple of (success: bool, message: str)
 39:         """
 40:         verification_link = (
 41:             f"{self.settings.app_url}/verify-email?token={token}&username={username}"
 42:         )
 43:         subject = f"Verify your email - {self.settings.totp_issuer}"
 44:         html_body = f"""
 45: <!DOCTYPE html>
 46: <html>
 47: <head>
 48:     <meta charset="UTF-8">
 49:     <meta name="viewport" content="width=device-width, initial-scale=1.0">
 50: </head>
 51: <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
 52:     <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
 53:         <h1 style="color: white; margin: 0; font-size: 28px;">Email Verification</h1>
 54:     </div>
 55:     <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
 56:         <p style="font-size: 16px;">Hello <strong>{first_name}</strong>,</p>
 57:         <p style="font-size: 16px;">Thank you for signing up! Please verify your email address by clicking the button below:</p>
 58:         <div style="text-align: center; margin: 30px 0;">
 59:             <a href="{verification_link}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
 60:                 Verify Email Address
 61:             </a>
 62:         </div>
 63:         <p style="font-size: 14px; color: #666;">Or copy and paste this link into your browser:</p>
 64:         <p style="font-size: 12px; color: #888; word-break: break-all; background: #fff; padding: 10px; border-radius: 5px; border: 1px solid #e0e0e0;">
 65:             {verification_link}
 66:         </p>
 67:         <p style="font-size: 14px; color: #666; margin-top: 30px;">
 68:             This link will expire in <strong>{self.settings.email_verification_expiry_hours} hours</strong>.
 69:         </p>
 70:         <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
 71:         <p style="font-size: 12px; color: #999; text-align: center;">
 72:             If you didn't create an account, you can safely ignore this email.
 73:         </p>
 74:     </div>
 75: </body>
 76: </html>
 77: """
 78:         text_body = f"""
 79: Hello {first_name},
 80: Thank you for signing up! Please verify your email address by visiting the link below:
 81: {verification_link}
 82: This link will expire in {self.settings.email_verification_expiry_hours} hours.
 83: If you didn't create an account, you can safely ignore this email.
 84: """
 85:         try:
 86:             response = self.client.send_email(
 87:                 Source=self.settings.ses_sender_email,
 88:                 Destination={"ToAddresses": [to_email]},
 89:                 Message={
 90:                     "Subject": {"Data": subject, "Charset": "UTF-8"},
 91:                     "Body": {
 92:                         "Text": {"Data": text_body, "Charset": "UTF-8"},
 93:                         "Html": {"Data": html_body, "Charset": "UTF-8"},
 94:                     },
 95:                 },
 96:             )
 97:             message_id = response.get("MessageId", "unknown")
 98:             logger.info(f"Verification email sent to {to_email}, MessageId: {message_id}")
 99:             return True, f"Verification email sent successfully"
100:         except ClientError as e:
101:             error_code = e.response.get("Error", {}).get("Code", "Unknown")
102:             error_message = e.response.get("Error", {}).get("Message", str(e))
103:             logger.error(f"Failed to send email to {to_email}: {error_code} - {error_message}")
104:             return False, f"Failed to send email: {error_message}"
105:         except Exception as e:
106:             logger.error(f"Unexpected error sending email to {to_email}: {e}")
107:             return False, f"Failed to send email: {str(e)}"
108:     def send_welcome_email(
109:         self,
110:         to_email: str,
111:         username: str,
112:         first_name: str,
113:     ) -> tuple[bool, str]:
114:         """
115:         Send welcome email after admin activation.
116:         Args:
117:             to_email: Recipient email address
118:             username: User's username
119:             first_name: User's first name
120:         Returns:
121:             Tuple of (success: bool, message: str)
122:         """
123:         login_link = f"{self.settings.app_url}"
124:         subject = f"Your account has been activated - {self.settings.totp_issuer}"
125:         html_body = f"""
126: <!DOCTYPE html>
127: <html>
128: <head>
129:     <meta charset="UTF-8">
130:     <meta name="viewport" content="width=device-width, initial-scale=1.0">
131: </head>
132: <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
133:     <div style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
134:         <h1 style="color: white; margin: 0; font-size: 28px;">Account Activated!</h1>
135:     </div>
136:     <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
137:         <p style="font-size: 16px;">Hello <strong>{first_name}</strong>,</p>
138:         <p style="font-size: 16px;">Great news! Your account has been approved and activated by an administrator.</p>
139:         <p style="font-size: 16px;">You can now log in using your username <strong>{username}</strong> and the password you created during signup.</p>
140:         <div style="text-align: center; margin: 30px 0;">
141:             <a href="{login_link}" style="background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
142:                 Login Now
143:             </a>
144:         </div>
145:         <p style="font-size: 14px; color: #666;">
146:             Remember to have your authenticator app ready for two-factor authentication.
147:         </p>
148:         <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
149:         <p style="font-size: 12px; color: #999; text-align: center;">
150:             If you have any questions, please contact your system administrator.
151:         </p>
152:     </div>
153: </body>
154: </html>
155: """
156:         text_body = f"""
157: Hello {first_name},
158: Great news! Your account has been approved and activated by an administrator.
159: You can now log in using your username ({username}) and the password you created during signup.
160: Login here: {login_link}
161: Remember to have your authenticator app ready for two-factor authentication.
162: If you have any questions, please contact your system administrator.
163: """
164:         try:
165:             response = self.client.send_email(
166:                 Source=self.settings.ses_sender_email,
167:                 Destination={"ToAddresses": [to_email]},
168:                 Message={
169:                     "Subject": {"Data": subject, "Charset": "UTF-8"},
170:                     "Body": {
171:                         "Text": {"Data": text_body, "Charset": "UTF-8"},
172:                         "Html": {"Data": html_body, "Charset": "UTF-8"},
173:                     },
174:                 },
175:             )
176:             message_id = response.get("MessageId", "unknown")
177:             logger.info(f"Welcome email sent to {to_email}, MessageId: {message_id}")
178:             return True, "Welcome email sent successfully"
179:         except ClientError as e:
180:             error_code = e.response.get("Error", {}).get("Code", "Unknown")
181:             error_message = e.response.get("Error", {}).get("Message", str(e))
182:             logger.error(f"Failed to send welcome email to {to_email}: {error_code} - {error_message}")
183:             return False, f"Failed to send email: {error_message}"
184:         except Exception as e:
185:             logger.error(f"Unexpected error sending welcome email to {to_email}: {e}")
186:             return False, f"Failed to send email: {str(e)}"
187:     def send_admin_notification_email(
188:         self,
189:         admin_emails: list[str],
190:         new_user: dict,
191:     ) -> tuple[bool, str]:
192:         """
193:         Send notification email to admins when a new user signs up.
194:         Args:
195:             admin_emails: List of admin email addresses
196:             new_user: Dictionary with new user details:
197:                 - username: str
198:                 - full_name: str
199:                 - email: str
200:                 - phone: str
201:                 - signup_time: str (ISO format)
202:         Returns:
203:             Tuple of (success: bool, message: str)
204:         """
205:         if not admin_emails:
206:             logger.warning("No admin emails to send notification to")
207:             return True, "No admin emails configured"
208:         admin_dashboard_link = f"{self.settings.app_url}/#admin"
209:         subject = f"New User Signup - {new_user.get('username', 'Unknown')} - {self.settings.totp_issuer}"
210:         html_body = f"""
211: <!DOCTYPE html>
212: <html>
213: <head>
214:     <meta charset="UTF-8">
215:     <meta name="viewport" content="width=device-width, initial-scale=1.0">
216: </head>
217: <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
218:     <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
219:         <h1 style="color: white; margin: 0; font-size: 28px;">New User Registration</h1>
220:     </div>
221:     <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e0e0e0; border-top: none;">
222:         <p style="font-size: 16px;">A new user has registered and is awaiting approval.</p>
223:         <div style="background: #fff; padding: 20px; border-radius: 8px; border: 1px solid #e0e0e0; margin: 20px 0;">
224:             <h3 style="margin: 0 0 15px 0; color: #333; font-size: 18px;">User Details</h3>
225:             <table style="width: 100%; border-collapse: collapse;">
226:                 <tr>
227:                     <td style="padding: 8px 0; color: #666; width: 120px;">Username:</td>
228:                     <td style="padding: 8px 0; font-weight: bold;">{new_user.get('username', 'N/A')}</td>
229:                 </tr>
230:                 <tr>
231:                     <td style="padding: 8px 0; color: #666;">Full Name:</td>
232:                     <td style="padding: 8px 0; font-weight: bold;">{new_user.get('full_name', 'N/A')}</td>
233:                 </tr>
234:                 <tr>
235:                     <td style="padding: 8px 0; color: #666;">Email:</td>
236:                     <td style="padding: 8px 0; font-weight: bold;">{new_user.get('email', 'N/A')}</td>
237:                 </tr>
238:                 <tr>
239:                     <td style="padding: 8px 0; color: #666;">Phone:</td>
240:                     <td style="padding: 8px 0; font-weight: bold;">{new_user.get('phone', 'N/A')}</td>
241:                 </tr>
242:                 <tr>
243:                     <td style="padding: 8px 0; color: #666;">Signup Time:</td>
244:                     <td style="padding: 8px 0; font-weight: bold;">{new_user.get('signup_time', 'N/A')}</td>
245:                 </tr>
246:             </table>
247:         </div>
248:         <p style="font-size: 14px; color: #666;">
249:             Once the user completes email and phone verification, you can approve or reject their account from the admin dashboard.
250:         </p>
251:         <div style="text-align: center; margin: 30px 0;">
252:             <a href="{admin_dashboard_link}" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px; display: inline-block;">
253:                 Review in Admin Dashboard
254:             </a>
255:         </div>
256:         <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 30px 0;">
257:         <p style="font-size: 12px; color: #999; text-align: center;">
258:             This is an automated notification from {self.settings.totp_issuer}.
259:         </p>
260:     </div>
261: </body>
262: </html>
263: """
264:         text_body = f"""
265: New User Registration
266: A new user has registered and is awaiting approval.
267: User Details:
268: - Username: {new_user.get('username', 'N/A')}
269: - Full Name: {new_user.get('full_name', 'N/A')}
270: - Email: {new_user.get('email', 'N/A')}
271: - Phone: {new_user.get('phone', 'N/A')}
272: - Signup Time: {new_user.get('signup_time', 'N/A')}
273: Once the user completes email and phone verification, you can approve or reject their account from the admin dashboard.
274: Review in Admin Dashboard: {admin_dashboard_link}
275: This is an automated notification from {self.settings.totp_issuer}.
276: """
277:         try:
278:             # Send to all admin emails
279:             response = self.client.send_email(
280:                 Source=self.settings.ses_sender_email,
281:                 Destination={"ToAddresses": admin_emails},
282:                 Message={
283:                     "Subject": {"Data": subject, "Charset": "UTF-8"},
284:                     "Body": {
285:                         "Text": {"Data": text_body, "Charset": "UTF-8"},
286:                         "Html": {"Data": html_body, "Charset": "UTF-8"},
287:                     },
288:                 },
289:             )
290:             message_id = response.get("MessageId", "unknown")
291:             logger.info(f"Admin notification email sent to {len(admin_emails)} admins, MessageId: {message_id}")
292:             return True, "Admin notification email sent successfully"
293:         except ClientError as e:
294:             error_code = e.response.get("Error", {}).get("Code", "Unknown")
295:             error_message = e.response.get("Error", {}).get("Message", str(e))
296:             logger.error(f"Failed to send admin notification email: {error_code} - {error_message}")
297:             return False, f"Failed to send email: {error_message}"
298:         except Exception as e:
299:             logger.error(f"Unexpected error sending admin notification email: {e}")
300:             return False, f"Failed to send email: {str(e)}"
```

## File: application/frontend/helm/ldap-2fa-frontend/.helmignore
```
 1: # Patterns to ignore when building packages.
 2: # This supports shell glob matching, relative path matching, and
 3: # negation (prefixed with !). Only one pattern per line.
 4: .DS_Store
 5: # Common VCS dirs
 6: .git/
 7: .gitignore
 8: .bzr/
 9: .bzrignore
10: .hg/
11: .hgignore
12: .svn/
13: # Common backup files
14: *.swp
15: *.bak
16: *.tmp
17: *.orig
18: *~
19: # Various IDEs
20: .project
21: .idea/
22: *.tmproj
23: .vscode/
24: .cursor/
25: # General
26: .github/
```

## File: application/frontend/helm/ldap-2fa-frontend/values.yaml
```yaml
  1: # Default values for ldap-2fa-frontend.
  2: # This is a YAML-formatted file.
  3: # Declare variables to be passed into your templates.
  4: # Number of replicas
  5: replicaCount: 2
  6: # Container image configuration
  7: image:
  8:   # ECR repository URL - should be set via CI/CD or ArgoCD
  9:   repository: ""
 10:   pullPolicy: IfNotPresent
 11:   # Image tag - should be set via CI/CD (defaults to Chart appVersion)
 12:   tag: ""
 13: # Secrets for pulling images from private registry
 14: imagePullSecrets: []
 15: # Override chart name
 16: nameOverride: ""
 17: fullnameOverride: ""
 18: # Service account configuration
 19: serviceAccount:
 20:   create: true
 21:   automount: true
 22:   annotations: {}
 23:   name: ""
 24: # Pod annotations and labels
 25: podAnnotations: {}
 26: podLabels: {}
 27: # Pod security context
 28: podSecurityContext:
 29:   fsGroup: 1000
 30: # Container security context
 31: securityContext:
 32:   capabilities:
 33:     drop:
 34:       - ALL
 35:   readOnlyRootFilesystem: false
 36:   runAsNonRoot: true
 37:   runAsUser: 1000
 38:   allowPrivilegeEscalation: false
 39: # Service configuration
 40: service:
 41:   type: ClusterIP
 42:   port: 80
 43: # Ingress configuration for ALB
 44: ingress:
 45:   enabled: true
 46:   className: ""  # Will be set to IngressClass name
 47:   annotations:
 48:     # ALB-specific annotations
 49:     alb.ingress.kubernetes.io/load-balancer-name: ""
 50:     alb.ingress.kubernetes.io/target-type: "ip"
 51:     alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
 52:     alb.ingress.kubernetes.io/ssl-redirect: "443"
 53:     alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"
 54:     # Order annotation for path priority (higher number = lower priority, matches after /api)
 55:     alb.ingress.kubernetes.io/group.order: "20"
 56:   hosts:
 57:     - host: ""  # app.<domain> - set by ArgoCD/values override
 58:       paths:
 59:         - path: /
 60:           pathType: Prefix
 61:   tls: []
 62: # HTTPRoute (Gateway API) - not used
 63: httpRoute:
 64:   enabled: false
 65: # Resource limits and requests
 66: resources:
 67:   limits:
 68:     cpu: 200m
 69:     memory: 128Mi
 70:   requests:
 71:     cpu: 50m
 72:     memory: 64Mi
 73: # Liveness probe configuration
 74: livenessProbe:
 75:   httpGet:
 76:     path: /health
 77:     port: http
 78:   initialDelaySeconds: 5
 79:   periodSeconds: 30
 80:   timeoutSeconds: 5
 81:   failureThreshold: 3
 82: # Readiness probe configuration
 83: readinessProbe:
 84:   httpGet:
 85:     path: /health
 86:     port: http
 87:   initialDelaySeconds: 3
 88:   periodSeconds: 10
 89:   timeoutSeconds: 5
 90:   failureThreshold: 3
 91: # Autoscaling configuration
 92: autoscaling:
 93:   enabled: false
 94:   minReplicas: 2
 95:   maxReplicas: 10
 96:   targetCPUUtilizationPercentage: 80
 97:   targetMemoryUtilizationPercentage: 80
 98: # Additional volumes
 99: volumes: []
100: # Additional volume mounts
101: volumeMounts: []
102: # Node selector
103: nodeSelector: {}
104: # Tolerations
105: tolerations: []
106: # Affinity rules
107: affinity: {}
```

## File: application/helm/redis-values.tpl.yaml
```yaml
 1: # Redis Helm Values Template
 2: # Used by Terraform to configure Bitnami Redis deployment
 3: # for SMS OTP code storage
 4: # Based on official Bitnami Redis Helm chart values structure
 5: # Override default image to use ECR repository
 6: image:
 7:   registry: "${ecr_registry}"
 8:   repository: "${ecr_repository}"
 9:   tag: "${image_tag}"
10:   pullPolicy: IfNotPresent
11: # Standalone architecture (no HA needed for OTP cache)
12: architecture: standalone
13: # Authentication configuration
14: auth:
15:   enabled: true
16:   # Reference Kubernetes secret created by Terraform
17:   # (password sourced from GitHub Secrets → TF_VAR_redis_password)
18:   existingSecret: "${secret_name}"
19:   existingSecretPasswordKey: "redis-password"
20: # Master configuration
21: master:
22:   # Persistence for data recovery across restarts
23:   persistence:
24:     enabled: ${persistence_enabled}
25: %{ if storage_class_name != "" ~}
26:     storageClass: "${storage_class_name}"
27: %{ endif ~}
28:     size: "${storage_size}"
29:   # Resource limits
30:   resources:
31:     requests:
32:       cpu: "${resources_requests_cpu}"
33:       memory: "${resources_requests_memory}"
34:     limits:
35:       cpu: "${resources_limits_cpu}"
36:       memory: "${resources_limits_memory}"
37:   # Security context - run as non-root
38:   containerSecurityContext:
39:     enabled: true
40:     runAsUser: 1001
41:     runAsNonRoot: true
42:     allowPrivilegeEscalation: false
43:   podSecurityContext:
44:     enabled: true
45:     fsGroup: 1001
46:   # Service configuration
47:   service:
48:     type: ClusterIP
49:     ports:
50:       redis: 6379
51: # Disable replicas (standalone mode)
52: replica:
53:   replicaCount: 0
54: # Metrics (optional for production monitoring)
55: metrics:
56:   enabled: ${metrics_enabled}
57: # Redis configuration optimized for OTP cache
58: commonConfiguration: |-
59:   # Enable RDB persistence for data recovery
60:   save 900 1
61:   save 300 10
62:   save 60 10000
63:   # Disable AOF (not needed for OTP cache)
64:   appendonly no
65:   # Max memory policy - evict keys with TTL first
66:   maxmemory-policy volatile-lru
67:   # Connection timeout
68:   timeout 300
```

## File: application/modules/argocd/outputs.tf
```hcl
 1: output "argocd_server_url" {
 2:   description = "Managed Argo CD UI/API endpoint (automatically retrieved via AWS CLI)"
 3:   value       = data.external.argocd_capability.result.server_url != "" ? data.external.argocd_capability.result.server_url : null
 4: }
 5:
 6: output "argocd_capability_name" {
 7:   description = "Name of the ArgoCD capability"
 8:   value       = local.argocd_capability_name
 9: }
10:
11: output "argocd_capability_status" {
12:   description = "Status of the ArgoCD capability (automatically retrieved via AWS CLI)"
13:   value       = data.external.argocd_capability.result.status != "" ? data.external.argocd_capability.result.status : null
14: }
15:
16: output "argocd_iam_role_arn" {
17:   description = "ARN of the IAM role used by ArgoCD capability"
18:   value       = aws_iam_role.argocd_capability.arn
19: }
20:
21: output "argocd_iam_role_name" {
22:   description = "Name of the IAM role used by ArgoCD capability"
23:   value       = aws_iam_role.argocd_capability.name
24: }
25:
26: output "local_cluster_secret_name" {
27:   description = "Name of the Kubernetes secret for local cluster registration"
28:   value       = kubernetes_secret.argocd_local_cluster.metadata[0].name
29: }
30:
31: output "argocd_namespace" {
32:   description = "Kubernetes namespace where ArgoCD resources are deployed"
33:   value       = var.argocd_namespace
34: }
35:
36: output "argocd_project_name" {
37:   description = "ArgoCD project name used for cluster registration"
38:   value       = var.argocd_project_name
39: }
```

## File: application/modules/argocd_app/main.tf
```hcl
 1: resource "kubernetes_manifest" "argocd_app" {
 2:   manifest = {
 3:     apiVersion = "argoproj.io/v1alpha1"
 4:     kind       = "Application"
 5:     metadata = {
 6:       name        = var.app_name
 7:       namespace   = var.argocd_namespace
 8:       labels      = var.app_labels
 9:       annotations = var.app_annotations
10:     }
11:     spec = {
12:       project = var.argocd_project_name
13:
14:       source = {
15:         repoURL        = var.repo_url
16:         targetRevision = var.target_revision
17:         path           = var.repo_path
18:         helm = var.helm_config != null ? {
19:           valueFiles  = var.helm_config.value_files
20:           parameters  = var.helm_config.parameters
21:           releaseName = var.helm_config.release_name
22:         } : null
23:         kustomize = var.kustomize_config != null ? {
24:           images            = var.kustomize_config.images
25:           commonLabels      = var.kustomize_config.common_labels
26:           commonAnnotations = var.kustomize_config.common_annotations
27:           patches           = var.kustomize_config.patches
28:         } : null
29:         directory = var.directory_config != null ? {
30:           recurse = var.directory_config.recurse
31:           include = var.directory_config.include
32:           exclude = var.directory_config.exclude
33:           jsonnet = var.directory_config.jsonnet != null ? {
34:             libs    = var.directory_config.jsonnet.libs
35:             tlas    = var.directory_config.jsonnet.tlas
36:             extVars = var.directory_config.jsonnet.ext_vars
37:           } : null
38:         } : null
39:       }
40:
41:       destination = {
42:         name      = var.cluster_name_in_argo
43:         namespace = var.destination_namespace
44:         server    = var.destination_server != null ? var.destination_server : null
45:       }
46:
47:       syncPolicy = var.sync_policy != null ? {
48:         automated = var.sync_policy.automated != null ? {
49:           prune      = var.sync_policy.automated.prune
50:           selfHeal   = var.sync_policy.automated.self_heal
51:           allowEmpty = var.sync_policy.automated.allow_empty
52:         } : null
53:         syncOptions = var.sync_policy.sync_options
54:         retry = var.sync_policy.retry != null ? {
55:           limit = var.sync_policy.retry.limit
56:           backoff = var.sync_policy.retry.backoff != null ? {
57:             duration    = var.sync_policy.retry.backoff.duration
58:             factor      = var.sync_policy.retry.backoff.factor
59:             maxDuration = var.sync_policy.retry.backoff.max_duration
60:           } : null
61:         } : null
62:       } : null
63:
64:       ignoreDifferences    = length(var.ignore_differences) > 0 ? var.ignore_differences : null
65:       revisionHistoryLimit = var.revision_history_limit
66:     }
67:   }
68: }
```

## File: application/modules/argocd_app/variables.tf
```hcl
  1: variable "app_name" {
  2:   description = "Name of the ArgoCD Application"
  3:   type        = string
  4: }
  5:
  6: variable "argocd_namespace" {
  7:   description = "Kubernetes namespace where ArgoCD Application will be created"
  8:   type        = string
  9:   default     = "argocd"
 10: }
 11:
 12: variable "argocd_project_name" {
 13:   description = "ArgoCD project name for the Application"
 14:   type        = string
 15:   default     = "default"
 16: }
 17:
 18: variable "cluster_name_in_argo" {
 19:   description = "Name of the cluster in ArgoCD (from cluster registration secret)"
 20:   type        = string
 21: }
 22:
 23: variable "repo_url" {
 24:   description = "Git repository URL containing application manifests"
 25:   type        = string
 26: }
 27:
 28: variable "target_revision" {
 29:   description = "Git branch, tag, or commit to sync (default: HEAD)"
 30:   type        = string
 31:   default     = "HEAD"
 32: }
 33:
 34: variable "repo_path" {
 35:   description = "Path within the repository to the application manifests"
 36:   type        = string
 37: }
 38:
 39: variable "destination_namespace" {
 40:   description = "Target Kubernetes namespace for the application"
 41:   type        = string
 42: }
 43:
 44: variable "destination_server" {
 45:   description = "Optional Kubernetes server URL (defaults to cluster_name_in_argo)"
 46:   type        = string
 47:   default     = null
 48: }
 49:
 50: variable "app_labels" {
 51:   description = "Labels to apply to the ArgoCD Application resource"
 52:   type        = map(string)
 53:   default     = {}
 54: }
 55:
 56: variable "app_annotations" {
 57:   description = "Annotations to apply to the ArgoCD Application resource"
 58:   type        = map(string)
 59:   default     = {}
 60: }
 61:
 62: variable "sync_policy" {
 63:   description = "Sync policy configuration for the Application"
 64:   type = object({
 65:     automated = object({
 66:       prune       = bool
 67:       self_heal   = bool
 68:       allow_empty = optional(bool, false)
 69:     })
 70:     sync_options = optional(list(string), ["CreateNamespace=true"])
 71:     retry = optional(object({
 72:       limit = number
 73:       backoff = optional(object({
 74:         duration     = string
 75:         factor       = number
 76:         max_duration = string
 77:       }))
 78:     }))
 79:   })
 80:   default = null
 81: }
 82:
 83: variable "ignore_differences" {
 84:   description = "List of ignore differences configurations"
 85:   type = list(object({
 86:     group                 = optional(string)
 87:     kind                  = optional(string)
 88:     name                  = optional(string)
 89:     namespace             = optional(string)
 90:     jsonPointers          = optional(list(string))
 91:     jqPathExpressions     = optional(list(string))
 92:     managedFieldsManagers = optional(list(string))
 93:   }))
 94:   default = []
 95: }
 96:
 97: variable "revision_history_limit" {
 98:   description = "Number of application revisions to keep in history"
 99:   type        = number
100:   default     = 5
101: }
102:
103: variable "helm_config" {
104:   description = "Helm-specific configuration (for Helm charts)"
105:   type = object({
106:     value_files = optional(list(string), [])
107:     parameters = optional(list(object({
108:       name         = string
109:       value        = string
110:       force_string = optional(bool, false)
111:     })), [])
112:     release_name = optional(string)
113:   })
114:   default = null
115: }
116:
117: variable "kustomize_config" {
118:   description = "Kustomize-specific configuration"
119:   type = object({
120:     images             = optional(list(string), [])
121:     common_labels      = optional(map(string), {})
122:     common_annotations = optional(map(string), {})
123:     patches = optional(list(object({
124:       path  = string
125:       patch = string
126:       target = optional(object({
127:         group     = string
128:         kind      = string
129:         name      = string
130:         namespace = optional(string)
131:       }))
132:     })), [])
133:   })
134:   default = null
135: }
136:
137: variable "directory_config" {
138:   description = "Directory-specific configuration (for plain manifests)"
139:   type = object({
140:     recurse = optional(bool, true)
141:     include = optional(string)
142:     exclude = optional(string)
143:     jsonnet = optional(object({
144:       libs = optional(list(string), [])
145:       tlas = optional(list(object({
146:         name  = string
147:         value = string
148:         code  = optional(bool, false)
149:       })), [])
150:       ext_vars = optional(list(object({
151:         name  = string
152:         value = string
153:         code  = optional(bool, false)
154:       })), [])
155:     }))
156:   })
157:   default = null
158: }
```

## File: application/modules/network-policies/main.tf
```hcl
  1: # Network Policies for securing internal cluster communication
  2: # These policies enforce secure communication between all services in the namespace
  3: # Generic approach: Any service can talk to any service, but only on secure ports
  4:
  5: # Generic Network Policy: Allow secure inter-pod communication within namespace
  6: # This policy applies to ALL pods in the namespace and allows them to communicate
  7: # with each other, but only on secure/encrypted ports
  8: resource "kubernetes_network_policy_v1" "namespace_secure_communication" {
  9:   metadata {
 10:     name      = "namespace-secure-communication"
 11:     namespace = var.namespace
 12:   }
 13:
 14:   spec {
 15:     # Apply to all pods in the namespace
 16:     pod_selector {}
 17:     policy_types = ["Ingress", "Egress"]
 18:
 19:     # Ingress: Allow traffic from any pod in the same namespace on secure ports
 20:     ingress {
 21:       # Allow from any pod in the same namespace
 22:       from {
 23:         pod_selector {}
 24:       }
 25:       ports {
 26:         port     = "443"
 27:         protocol = "TCP"
 28:       }
 29:     }
 30:
 31:     ingress {
 32:       from {
 33:         pod_selector {}
 34:       }
 35:       ports {
 36:         port     = "636"
 37:         protocol = "TCP"
 38:       }
 39:     }
 40:
 41:     # Allow HTTPS on common alternative ports if needed
 42:     ingress {
 43:       from {
 44:         pod_selector {}
 45:       }
 46:       ports {
 47:         port     = "8443"
 48:         protocol = "TCP"
 49:       }
 50:     }
 51:
 52:     # Ingress: Allow traffic from any pod in other namespaces on secure ports
 53:     # This enables cross-namespace communication for LDAP service access
 54:     ingress {
 55:       # Allow from any pod in any namespace
 56:       from {
 57:         namespace_selector {}
 58:       }
 59:       ports {
 60:         port     = "443"
 61:         protocol = "TCP"
 62:       }
 63:     }
 64:
 65:     ingress {
 66:       from {
 67:         namespace_selector {}
 68:       }
 69:       ports {
 70:         port     = "636"
 71:         protocol = "TCP"
 72:       }
 73:     }
 74:
 75:     ingress {
 76:       from {
 77:         namespace_selector {}
 78:       }
 79:       ports {
 80:         port     = "8443"
 81:         protocol = "TCP"
 82:       }
 83:     }
 84:
 85:     # Egress: Allow traffic to any pod in the same namespace on secure ports
 86:     egress {
 87:       # Allow to any pod in the same namespace
 88:       to {
 89:         pod_selector {}
 90:       }
 91:       ports {
 92:         port     = "443"
 93:         protocol = "TCP"
 94:       }
 95:     }
 96:
 97:     egress {
 98:       to {
 99:         pod_selector {}
100:       }
101:       ports {
102:         port     = "636"
103:         protocol = "TCP"
104:       }
105:     }
106:
107:     egress {
108:       to {
109:         pod_selector {}
110:       }
111:       ports {
112:         port     = "8443"
113:         protocol = "TCP"
114:       }
115:     }
116:
117:     # Egress: Allow DNS resolution (required for service discovery)
118:     egress {
119:       to {
120:         namespace_selector {}
121:       }
122:       ports {
123:         port     = "53"
124:         protocol = "UDP"
125:       }
126:     }
127:
128:     egress {
129:       to {
130:         namespace_selector {}
131:       }
132:       ports {
133:         port     = "53"
134:         protocol = "TCP"
135:       }
136:     }
137:
138:     # Egress: Allow HTTPS for external API calls (2FA providers, etc.)
139:     egress {
140:       ports {
141:         port     = "443"
142:         protocol = "TCP"
143:       }
144:     }
145:
146:     # Egress: Allow HTTP for external API calls if needed (though HTTPS is preferred)
147:     # Note: This is included for compatibility, but services should prefer HTTPS
148:     egress {
149:       ports {
150:         port     = "80"
151:         protocol = "TCP"
152:       }
153:     }
154:   }
155: }
156:
157: # Note: We don't need a separate default deny policy because:
158: # 1. The namespace_secure_communication policy above applies to all pods
159: # 2. It only allows specific secure ports (443, 636, 8443)
160: # 3. All other ports are implicitly denied
161: # 4. This approach is simpler and avoids policy conflicts
```

## File: application/modules/route53/main.tf
```hcl
 1: locals {
 2:   domain = var.domain_name
 3:   # Removing trailing dot from domain
 4:   domain_name = trimsuffix(local.domain, ".")
 5:   zone_id     = try(data.aws_route53_zone.this[0].zone_id, aws_route53_zone.this[0].zone_id)
 6: }
 7:
 8: data "aws_route53_zone" "this" {
 9:   count = var.use_existing_route53_zone ? 1 : 0
10:
11:   name         = local.domain_name
12:   private_zone = false
13: }
14:
15: # Create Route53 hosted zone and ACM certificate
16: resource "aws_route53_zone" "this" {
17:   count = var.use_existing_route53_zone ? 0 : 1
18:
19:   name = local.domain_name
20:
21:   tags = {
22:     Name      = local.domain_name
23:     Env       = var.env
24:     Terraform = "true"
25:   }
26: }
27:
28: module "acm" {
29:   source  = "terraform-aws-modules/acm/aws"
30:   version = "6.2.0"
31:
32:   domain_name = local.domain_name
33:   zone_id     = local.zone_id
34:
35:   subject_alternative_names = var.subject_alternative_names
36:
37:   validation_method = "DNS"
38:
39:   wait_for_validation = true
40:   validation_timeout  = "30m"
41:
42:   tags = {
43:     Name      = local.domain_name
44:     Env       = var.env
45:     Terraform = "true"
46:   }
47: }
```

## File: application/modules/route53_record/providers.tf
```hcl
 1: terraform {
 2:   required_providers {
 3:     aws = {
 4:       source                = "hashicorp/aws"
 5:       version               = ">= 6.21.0"
 6:       configuration_aliases = [aws.state_account]
 7:     }
 8:   }
 9: }
10:
11: # Provider alias for state account (inherited from parent module)
12: # This allows Route53 resources to be created in the state account
13: # when Route53 hosted zone is in a different account than deployment account
```

## File: application/modules/ses/main.tf
```hcl
  1: /**
  2:  * SES Module
  3:  *
  4:  * Configures AWS SES for sending verification emails in the LDAP 2FA application.
  5:  * Includes IAM role for IRSA to allow the backend pod to send emails.
  6:  */
  7:
  8: locals {
  9:   role_name = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
 10: }
 11:
 12: # Get EKS cluster data for IRSA
 13: data "aws_eks_cluster" "cluster" {
 14:   name = var.cluster_name
 15: }
 16:
 17: # OIDC provider for IRSA
 18: data "aws_iam_openid_connect_provider" "cluster" {
 19:   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
 20: }
 21:
 22: # Verify sender email address (if not using domain verification)
 23: resource "aws_ses_email_identity" "sender" {
 24:   count = var.sender_domain == null ? 1 : 0
 25:   email = var.sender_email
 26: }
 27:
 28: # Verify sender domain (if domain is provided)
 29: resource "aws_ses_domain_identity" "sender" {
 30:   count  = var.sender_domain != null ? 1 : 0
 31:   domain = var.sender_domain
 32: }
 33:
 34: # Domain verification DNS record (if using domain verification and Route53)
 35: # Note: Provider is passed from parent module via providers block
 36: resource "aws_route53_record" "ses_verification" {
 37:   provider = aws.state_account
 38:   count    = var.sender_domain != null && var.route53_zone_id != null ? 1 : 0
 39:   zone_id  = var.route53_zone_id
 40:   name     = "_amazonses.${var.sender_domain}"
 41:   type     = "TXT"
 42:   ttl      = 600
 43:   records  = [aws_ses_domain_identity.sender[0].verification_token]
 44: }
 45:
 46: # DKIM for domain (if using domain verification)
 47: resource "aws_ses_domain_dkim" "sender" {
 48:   count  = var.sender_domain != null ? 1 : 0
 49:   domain = aws_ses_domain_identity.sender[0].domain
 50: }
 51:
 52: # DKIM DNS records (if using domain verification and Route53)
 53: # Note: Provider is passed from parent module via providers block
 54: resource "aws_route53_record" "ses_dkim" {
 55:   provider = aws.state_account
 56:   count    = var.sender_domain != null && var.route53_zone_id != null ? 3 : 0
 57:   zone_id  = var.route53_zone_id
 58:   name     = "${aws_ses_domain_dkim.sender[0].dkim_tokens[count.index]}._domainkey.${var.sender_domain}"
 59:   type     = "CNAME"
 60:   ttl      = 600
 61:   records  = ["${aws_ses_domain_dkim.sender[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
 62: }
 63:
 64: # IAM policy for SES send email
 65: resource "aws_iam_policy" "ses_send" {
 66:   name        = "${local.role_name}-policy"
 67:   description = "Allow sending emails via SES for LDAP 2FA verification"
 68:
 69:   policy = jsonencode({
 70:     Version = "2012-10-17"
 71:     Statement = [
 72:       {
 73:         Effect = "Allow"
 74:         Action = [
 75:           "ses:SendEmail",
 76:           "ses:SendRawEmail",
 77:         ]
 78:         Resource = "*"
 79:         Condition = {
 80:           StringEquals = {
 81:             "ses:FromAddress" = var.sender_email
 82:           }
 83:         }
 84:       }
 85:     ]
 86:   })
 87:
 88:   tags = var.tags
 89: }
 90:
 91: # IAM role for IRSA
 92: resource "aws_iam_role" "ses_sender" {
 93:   name = local.role_name
 94:
 95:   assume_role_policy = jsonencode({
 96:     Version = "2012-10-17"
 97:     Statement = [
 98:       {
 99:         Effect = "Allow"
100:         Principal = {
101:           Federated = data.aws_iam_openid_connect_provider.cluster.arn
102:         }
103:         Action = "sts:AssumeRoleWithWebIdentity"
104:         Condition = {
105:           StringEquals = {
106:             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"
107:             "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
108:           }
109:         }
110:       }
111:     ]
112:   })
113:
114:   tags = var.tags
115: }
116:
117: # Attach policy to role
118: resource "aws_iam_role_policy_attachment" "ses_send" {
119:   role       = aws_iam_role.ses_sender.name
120:   policy_arn = aws_iam_policy.ses_send.arn
121: }
```

## File: application/modules/ses/providers.tf
```hcl
 1: terraform {
 2:   required_providers {
 3:     aws = {
 4:       source                = "hashicorp/aws"
 5:       version               = ">= 6.21.0"
 6:       configuration_aliases = [aws.state_account]
 7:     }
 8:   }
 9: }
10:
11: # Provider alias for state account (inherited from parent module)
12: # This allows Route53 resources to be created in the state account
13: # when Route53 hosted zone is in a different account than deployment account
```

## File: backend_infra/modules/ebs/outputs.tf
```hcl
1: output "ebs_pvc_name" {
2:   value = kubernetes_persistent_volume_claim_v1.ebs_pvc.metadata[0].name
3: }
4:
5: output "ebs_storage_class_name" {
6:   value = kubernetes_storage_class.ebs.metadata[0].name
7: }
```

## File: backend_infra/modules/ecr/outputs.tf
```hcl
 1: output "ecr_name" {
 2:   value = aws_ecr_repository.ecr.name
 3: }
 4:
 5: output "ecr_arn" {
 6:   value = aws_ecr_repository.ecr.arn
 7: }
 8:
 9: output "ecr_url" {
10:   value = aws_ecr_repository.ecr.repository_url
11: }
12:
13: output "ecr_registry" {
14:   description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
15:   value       = split("/", aws_ecr_repository.ecr.repository_url)[0]
16: }
17:
18: output "ecr_repository" {
19:   description = "ECR repository name (without registry prefix)"
20:   value       = split("/", aws_ecr_repository.ecr.repository_url)[1]
21: }
```

## File: backend_infra/modules/endpoints/main.tf
```hcl
  1: # Create VPC endpoints (Private Links) for SSM Session Manager access to nodes
  2: # and for AWS services used by the 2FA application (SNS, STS)
  3:
  4: resource "aws_security_group" "vpc_endpoint_sg" {
  5:   name        = "${var.prefix}-${var.region}-${var.endpoint_sg_name}-${var.env}"
  6:   description = "Security group for VPC endpoints"
  7:   vpc_id      = var.vpc_id
  8:
  9:   tags = merge(var.tags, {
 10:     Name = "${var.prefix}-${var.region}-${var.endpoint_sg_name}-${var.env}"
 11:   })
 12: }
 13:
 14: resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_sg_ingress" {
 15:   description                  = "Allow EKS Nodes to access VPC Endpoints"
 16:   from_port                    = 443
 17:   to_port                      = 443
 18:   ip_protocol                  = "tcp"
 19:   referenced_security_group_id = var.node_security_group_id
 20:   security_group_id            = aws_security_group.vpc_endpoint_sg.id
 21: }
 22:
 23: # Allow ingress from VPC CIDR for pods that may not use node security group
 24: resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_sg_ingress_vpc" {
 25:   description       = "Allow VPC CIDR to access VPC Endpoints"
 26:   from_port         = 443
 27:   to_port           = 443
 28:   ip_protocol       = "tcp"
 29:   cidr_ipv4         = var.vpc_cidr
 30:   security_group_id = aws_security_group.vpc_endpoint_sg.id
 31: }
 32:
 33: resource "aws_vpc_security_group_egress_rule" "vpc_endpoint_sg_egress" {
 34:   ip_protocol       = "-1"
 35:   cidr_ipv4         = "0.0.0.0/0"
 36:   security_group_id = aws_security_group.vpc_endpoint_sg.id
 37: }
 38:
 39: # SSM Endpoints for Session Manager
 40: resource "aws_vpc_endpoint" "private_link_ssm" {
 41:   vpc_id              = var.vpc_id
 42:   service_name        = "com.amazonaws.${var.region}.ssm"
 43:   vpc_endpoint_type   = "Interface"
 44:   security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
 45:   subnet_ids          = var.private_subnets
 46:   private_dns_enabled = true
 47:
 48:   tags = merge(var.tags, {
 49:     Name = "private-link-ssm"
 50:   })
 51: }
 52:
 53: resource "aws_vpc_endpoint" "private_link_ssmmessages" {
 54:   vpc_id              = var.vpc_id
 55:   service_name        = "com.amazonaws.${var.region}.ssmmessages"
 56:   vpc_endpoint_type   = "Interface"
 57:   security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
 58:   subnet_ids          = var.private_subnets
 59:   private_dns_enabled = true
 60:
 61:   tags = merge(var.tags, {
 62:     Name = "private-link-ssmmessages"
 63:   })
 64: }
 65:
 66: resource "aws_vpc_endpoint" "private_link_ec2messages" {
 67:   vpc_id              = var.vpc_id
 68:   service_name        = "com.amazonaws.${var.region}.ec2messages"
 69:   vpc_endpoint_type   = "Interface"
 70:   security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
 71:   subnet_ids          = var.private_subnets
 72:   private_dns_enabled = true
 73:
 74:   tags = merge(var.tags, {
 75:     Name = "private-link-ec2messages"
 76:   })
 77: }
 78:
 79: # STS Endpoint - Required for IRSA (IAM Roles for Service Accounts)
 80: # Pods need to call STS to assume IAM roles via web identity
 81: resource "aws_vpc_endpoint" "private_link_sts" {
 82:   count = var.enable_sts_endpoint ? 1 : 0
 83:
 84:   vpc_id              = var.vpc_id
 85:   service_name        = "com.amazonaws.${var.region}.sts"
 86:   vpc_endpoint_type   = "Interface"
 87:   security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
 88:   subnet_ids          = var.private_subnets
 89:   private_dns_enabled = true
 90:
 91:   tags = merge(var.tags, {
 92:     Name = "private-link-sts"
 93:   })
 94: }
 95:
 96: # SNS Endpoint - Required for SMS 2FA functionality
 97: # Pods need to call SNS to send SMS verification codes
 98: resource "aws_vpc_endpoint" "private_link_sns" {
 99:   count = var.enable_sns_endpoint ? 1 : 0
100:
101:   vpc_id              = var.vpc_id
102:   service_name        = "com.amazonaws.${var.region}.sns"
103:   vpc_endpoint_type   = "Interface"
104:   security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
105:   subnet_ids          = var.private_subnets
106:   private_dns_enabled = true
107:
108:   tags = merge(var.tags, {
109:     Name = "private-link-sns"
110:   })
111: }
```

## File: backend_infra/modules/endpoints/outputs.tf
```hcl
 1: output "vpc_endpoint_sg_id" {
 2:   description = "Security group ID for VPC endpoints"
 3:   value       = aws_security_group.vpc_endpoint_sg.id
 4: }
 5:
 6: output "vpc_endpoint_ssm_id" {
 7:   description = "VPC endpoint ID for SSM"
 8:   value       = aws_vpc_endpoint.private_link_ssm.id
 9: }
10:
11: output "vpc_endpoint_ssmmessages_id" {
12:   description = "VPC endpoint ID for SSM Messages"
13:   value       = aws_vpc_endpoint.private_link_ssmmessages.id
14: }
15:
16: output "vpc_endpoint_ec2messages_id" {
17:   description = "VPC endpoint ID for EC2 Messages"
18:   value       = aws_vpc_endpoint.private_link_ec2messages.id
19: }
20:
21: output "vpc_endpoint_sts_id" {
22:   description = "VPC endpoint ID for STS (IRSA)"
23:   value       = var.enable_sts_endpoint ? aws_vpc_endpoint.private_link_sts[0].id : null
24: }
25:
26: output "vpc_endpoint_sns_id" {
27:   description = "VPC endpoint ID for SNS (SMS 2FA)"
28:   value       = var.enable_sns_endpoint ? aws_vpc_endpoint.private_link_sns[0].id : null
29: }
30:
31: output "vpc_endpoint_ids" {
32:   description = "List of all VPC endpoint IDs"
33:   value = compact([
34:     aws_vpc_endpoint.private_link_ssm.id,
35:     aws_vpc_endpoint.private_link_ssmmessages.id,
36:     aws_vpc_endpoint.private_link_ec2messages.id,
37:     var.enable_sts_endpoint ? aws_vpc_endpoint.private_link_sts[0].id : null,
38:     var.enable_sns_endpoint ? aws_vpc_endpoint.private_link_sns[0].id : null,
39:   ])
40: }
```

## File: backend_infra/modules/endpoints/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Name added to all resources"
13:   type        = string
14: }
15:
16: variable "endpoint_sg_name" {
17:   description = "The name of the endpoint security group"
18:   type        = string
19: }
20:
21: variable "node_security_group_id" {
22:   description = "The ID of the node security group"
23:   type        = string
24: }
25:
26: variable "vpc_id" {
27:   description = "The ID of the VPC"
28:   type        = string
29: }
30:
31: variable "vpc_cidr" {
32:   description = "The CIDR block of the VPC (for security group rules)"
33:   type        = string
34: }
35:
36: variable "private_subnets" {
37:   description = "The IDs of the private subnets"
38:   type        = list(string)
39: }
40:
41: variable "enable_sts_endpoint" {
42:   description = "Whether to create STS VPC endpoint (required for IRSA)"
43:   type        = bool
44:   default     = true
45: }
46:
47: variable "enable_sns_endpoint" {
48:   description = "Whether to create SNS VPC endpoint (required for SMS 2FA)"
49:   type        = bool
50:   default     = false
51: }
52:
53: variable "tags" {
54:   description = "Tags to add to the resources"
55:   type        = map(string)
56: }
```

## File: backend_infra/destroy-backend.sh
```bash
  1: #!/bin/bash
  2: # Script to configure backend.hcl and variables.tfvars with user-selected region and environment
  3: # and run Terraform destroy commands
  4: # Usage: ./destroy-backend.sh
  5: set -euo pipefail
  6: # Clean up any existing AWS credentials from environment to prevent conflicts
  7: # This ensures the script starts with a clean slate and uses the correct credentials
  8: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
  9: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 10: unset AWS_SESSION_TOKEN 2>/dev/null || true
 11: unset AWS_PROFILE 2>/dev/null || true
 12: # Colors for output
 13: RED='\033[0;31m'
 14: GREEN='\033[0;32m'
 15: YELLOW='\033[1;33m'
 16: NC='\033[0m' # No Color
 17: # Configuration
 18: PLACEHOLDER_FILE="tfstate-backend-values-template.hcl"
 19: BACKEND_FILE="backend.hcl"
 20: VARIABLES_FILE="variables.tfvars"
 21: # Function to print colored messages
 22: print_error() {
 23:     echo -e "${RED}ERROR:${NC} $1" >&2
 24: }
 25: print_success() {
 26:     echo -e "${GREEN}SUCCESS:${NC} $1"
 27: }
 28: print_info() {
 29:     echo -e "${YELLOW}INFO:${NC} $1"
 30: }
 31: print_warning() {
 32:     echo -e "${YELLOW}WARNING:${NC} $1"
 33: }
 34: # Check if AWS CLI is installed
 35: if ! command -v aws &> /dev/null; then
 36:     print_error "AWS CLI is not installed."
 37:     echo "Please install it from: https://aws.amazon.com/cli/"
 38:     exit 1
 39: fi
 40: # Check if Terraform is installed
 41: if ! command -v terraform &> /dev/null; then
 42:     print_error "Terraform is not installed."
 43:     echo "Please install it from: https://www.terraform.io/downloads"
 44:     exit 1
 45: fi
 46: # Check if GitHub CLI is installed
 47: if ! command -v gh &> /dev/null; then
 48:     print_error "GitHub CLI (gh) is not installed."
 49:     echo "Please install it from: https://cli.github.com/"
 50:     exit 1
 51: fi
 52: # Check if user is authenticated with GitHub CLI
 53: if ! gh auth status &> /dev/null; then
 54:     print_error "Not authenticated with GitHub CLI."
 55:     echo "Please run: gh auth login"
 56:     exit 1
 57: fi
 58: # Check if jq is installed (required for gh --jq flag)
 59: if ! command -v jq &> /dev/null; then
 60:     print_error "jq is not installed."
 61:     echo "Please install it:"
 62:     echo "  macOS: brew install jq"
 63:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 64:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 65:     exit 1
 66: fi
 67: # Get repository owner and name
 68: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 69: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 70: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 71:     print_error "Could not determine repository information."
 72:     echo "Please ensure you're in a git repository and have proper permissions."
 73:     exit 1
 74: fi
 75: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 76: # Function to get repository variable using GitHub CLI
 77: get_repo_variable() {
 78:     local var_name=$1
 79:     local value
 80:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 81:     if [ -z "$value" ]; then
 82:         print_error "Repository variable '${var_name}' not found or not accessible."
 83:         return 1
 84:     fi
 85:     echo "$value"
 86: }
 87: # Function to retrieve secret from AWS Secrets Manager
 88: get_aws_secret() {
 89:     local secret_name=$1
 90:     local secret_json
 91:     local exit_code
 92:     # Retrieve secret from AWS Secrets Manager
 93:     # Use AWS_REGION if set, otherwise default to us-east-1
 94:     secret_json=$(aws secretsmanager get-secret-value \
 95:         --secret-id "$secret_name" \
 96:         --region "${AWS_REGION:-us-east-1}" \
 97:         --query SecretString \
 98:         --output text 2>&1)
 99:     # Capture exit code before checking
100:     exit_code=$?
101:     # Validate secret retrieval
102:     if [ $exit_code -ne 0 ]; then
103:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
104:         print_error "Error: $secret_json"
105:         return 1
106:     fi
107:     # Validate JSON can be parsed
108:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
109:         print_error "Secret '${secret_name}' contains invalid JSON"
110:         return 1
111:     fi
112:     echo "$secret_json"
113: }
114: # Function to retrieve plain text secret from AWS Secrets Manager
115: get_aws_plaintext_secret() {
116:     local secret_name=$1
117:     local secret_value
118:     local exit_code
119:     # Retrieve secret from AWS Secrets Manager
120:     # Use AWS_REGION if set, otherwise default to us-east-1
121:     secret_value=$(aws secretsmanager get-secret-value \
122:         --secret-id "$secret_name" \
123:         --region "${AWS_REGION:-us-east-1}" \
124:         --query SecretString \
125:         --output text 2>&1)
126:     # Capture exit code before checking
127:     exit_code=$?
128:     # Validate secret retrieval
129:     if [ $exit_code -ne 0 ]; then
130:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
131:         print_error "Error: $secret_value"
132:         return 1
133:     fi
134:     # Check if secret value is empty
135:     if [ -z "$secret_value" ]; then
136:         print_error "Secret '${secret_name}' is empty"
137:         return 1
138:     fi
139:     echo "$secret_value"
140: }
141: # Function to get key value from secret JSON
142: get_secret_key_value() {
143:     local secret_json=$1
144:     local key_name=$2
145:     local value
146:     # Validate JSON can be parsed
147:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
148:         print_error "Invalid JSON provided to get_secret_key_value"
149:         return 1
150:     fi
151:     # Extract key value using jq
152:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
153:     # Check if jq command succeeded
154:     if [ $? -ne 0 ]; then
155:         print_error "Failed to parse JSON or extract key '${key_name}'"
156:         return 1
157:     fi
158:     # Check if key exists (jq returns "null" for non-existent keys)
159:     if [ "$value" = "null" ] || [ -z "$value" ]; then
160:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
161:         return 1
162:     fi
163:     echo "$value"
164: }
165: # Warning about destructive operation
166: echo ""
167: print_warning "=========================================="
168: print_warning "  DESTRUCTIVE OPERATION WARNING"
169: print_warning "=========================================="
170: print_warning "This script will DESTROY all infrastructure"
171: print_warning "in the selected region and environment."
172: print_warning ""
173: print_warning "This action CANNOT be undone!"
174: print_warning "=========================================="
175: echo ""
176: read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
177: if [ "$confirmation" != "yes" ]; then
178:     print_info "Operation cancelled."
179:     exit 0
180: fi
181: # Interactive prompts
182: echo ""
183: print_info "Select AWS Region:"
184: echo "1) us-east-1: N. Virginia (default)"
185: echo "2) us-east-2: Ohio"
186: read -p "Enter choice [1-2] (default: 1): " region_choice
187: case ${region_choice:-1} in
188:     1)
189:         SELECTED_REGION="us-east-1: N. Virginia"
190:         ;;
191:     2)
192:         SELECTED_REGION="us-east-2: Ohio"
193:         ;;
194:     *)
195:         print_error "Invalid choice. Using default: us-east-1: N. Virginia"
196:         SELECTED_REGION="us-east-1: N. Virginia"
197:         ;;
198: esac
199: # Extract region code (everything before the colon)
200: AWS_REGION="${SELECTED_REGION%%:*}"
201: print_success "Selected region: ${SELECTED_REGION} (${AWS_REGION})"
202: echo ""
203: print_info "Select Environment:"
204: echo "1) prod (default)"
205: echo "2) dev"
206: read -p "Enter choice [1-2] (default: 1): " env_choice
207: case ${env_choice:-1} in
208:     1)
209:         ENVIRONMENT="prod"
210:         ;;
211:     2)
212:         ENVIRONMENT="dev"
213:         ;;
214:     *)
215:         print_error "Invalid choice. Using default: prod"
216:         ENVIRONMENT="prod"
217:         ;;
218: esac
219: print_success "Selected environment: ${ENVIRONMENT}"
220: echo ""
221: # Final confirmation with environment details
222: print_warning "You are about to DESTROY infrastructure in:"
223: print_warning "  Region: ${AWS_REGION}"
224: print_warning "  Environment: ${ENVIRONMENT}"
225: echo ""
226: read -p "Type 'DESTROY' to confirm: " final_confirmation
227: if [ "$final_confirmation" != "DESTROY" ]; then
228:     print_info "Operation cancelled."
229:     exit 0
230: fi
231: # Retrieve all role ARNs from AWS Secrets Manager in a single call
232: # This minimizes AWS CLI calls by fetching all required role ARNs at once
233: print_info "Retrieving role ARNs from AWS Secrets Manager..."
234: SECRET_JSON=$(get_aws_secret "github-role" || echo "")
235: if [ -z "$SECRET_JSON" ]; then
236:     print_error "Failed to retrieve secret from AWS Secrets Manager"
237:     exit 1
238: fi
239: # Extract STATE_ACCOUNT_ROLE_ARN for backend state operations
240: STATE_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
241: if [ -z "$STATE_ROLE_ARN" ]; then
242:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
243:     exit 1
244: fi
245: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
246: # Determine which deployment account role ARN to use based on environment
247: if [ "$ENVIRONMENT" = "prod" ]; then
248:     DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
249: else
250:     DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
251: fi
252: # Extract deployment account role ARN for provider assume_role
253: DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
254: if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
255:     print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
256:     exit 1
257: fi
258: print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"
259: # Use STATE_ROLE_ARN for backend operations
260: ROLE_ARN="$STATE_ROLE_ARN"
261: print_info "Assuming role: $ROLE_ARN"
262: print_info "Region: $AWS_REGION"
263: # Assume the role
264: ROLE_SESSION_NAME="destroy-backend-$(date +%s)"
265: # Assume role and capture output
266: ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
267:     --role-arn "$ROLE_ARN" \
268:     --role-session-name "$ROLE_SESSION_NAME" \
269:     --region "$AWS_REGION" 2>&1)
270: if [ $? -ne 0 ]; then
271:     print_error "Failed to assume role: $ASSUME_ROLE_OUTPUT"
272:     exit 1
273: fi
274: # Extract credentials from JSON output
275: # Try using jq if available (more reliable), otherwise use sed/grep
276: if command -v jq &> /dev/null; then
277:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
278:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
279:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
280: else
281:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
282:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
283:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
284:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
285: fi
286: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
287:     print_error "Failed to extract credentials from assume-role output."
288:     print_error "Output was: $ASSUME_ROLE_OUTPUT"
289:     exit 1
290: fi
291: print_success "Successfully assumed role"
292: # Verify the credentials work
293: CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
294: if [ $? -ne 0 ]; then
295:     print_error "Failed to verify assumed role credentials: $CALLER_ARN"
296:     exit 1
297: fi
298: print_info "Assumed role identity: $CALLER_ARN"
299: echo ""
300: # Retrieve ExternalId from AWS Secrets Manager (plain text secret)
301: # Must be retrieved after assuming role to have AWS credentials
302: print_info "Retrieving ExternalId from AWS Secrets Manager..."
303: EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
304: if [ -z "$EXTERNAL_ID" ]; then
305:     print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
306:     exit 1
307: fi
308: print_success "Retrieved ExternalId"
309: # Retrieve repository variables
310: print_info "Retrieving repository variables..."
311: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
312: print_success "Retrieved BACKEND_BUCKET_NAME"
313: BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX") || exit 1
314: print_success "Retrieved BACKEND_PREFIX"
315: # Check if backend.hcl already exists
316: if [ -f "$BACKEND_FILE" ]; then
317:     print_info "${BACKEND_FILE} already exists. Skipping creation."
318: else
319:     # Check if placeholder file exists
320:     if [ ! -f "$PLACEHOLDER_FILE" ]; then
321:         print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
322:         exit 1
323:     fi
324:     # Copy placeholder to backend file and replace placeholders
325:     print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."
326:     # Copy placeholder file to backend file
327:     cp "$PLACEHOLDER_FILE" "$BACKEND_FILE"
328:     # Replace placeholders (works on macOS and Linux)
329:     if [[ "$OSTYPE" == "darwin"* ]]; then
330:         # macOS sed requires -i '' for in-place editing
331:         sed -i '' "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
332:         sed -i '' "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
333:         sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
334:     else
335:         # Linux sed
336:         sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
337:         sed -i "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
338:         sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
339:     fi
340:     print_success "Created ${BACKEND_FILE}"
341: fi
342: # Update variables.tfvars
343: print_info "Updating ${VARIABLES_FILE} with selected values..."
344: if [ ! -f "$VARIABLES_FILE" ]; then
345:     print_error "Variables file '${VARIABLES_FILE}' not found."
346:     exit 1
347: fi
348: # Update variables.tfvars (works on macOS and Linux)
349: if [[ "$OSTYPE" == "darwin"* ]]; then
350:     # macOS sed requires -i '' for in-place editing
351:     sed -i '' "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
352:     sed -i '' "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
353:     # Add or update deployment_account_role_arn
354:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
355:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
356:     else
357:         sed -i '' "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
358:     fi
359:     # Add or update deployment_account_external_id
360:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
361:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
362:     else
363:         sed -i '' "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
364:     fi
365: else
366:     # Linux sed
367:     sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
368:     sed -i "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
369:     # Add or update deployment_account_role_arn
370:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
371:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
372:     else
373:         sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
374:     fi
375:     # Add or update deployment_account_external_id
376:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
377:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
378:     else
379:         sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
380:     fi
381: fi
382: print_success "Updated ${VARIABLES_FILE}"
383: echo ""
384: print_success "Configuration files updated successfully!"
385: echo ""
386: print_info "Backend file: ${BACKEND_FILE}"
387: print_info "  - bucket: ${BUCKET_NAME}"
388: print_info "  - key: ${BACKEND_PREFIX}"
389: print_info "  - region: ${AWS_REGION}"
390: echo ""
391: print_info "Variables file: ${VARIABLES_FILE}"
392: print_info "  - env: ${ENVIRONMENT}"
393: print_info "  - region: ${AWS_REGION}"
394: echo ""
395: # Terraform workspace name
396: WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"
397: # Terraform init
398: print_info "Running terraform init with backend configuration..."
399: terraform init -backend-config="${BACKEND_FILE}"
400: # Terraform workspace
401: print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
402: terraform workspace select "${WORKSPACE_NAME}" || terraform workspace new "${WORKSPACE_NAME}"
403: # Terraform validate
404: print_info "Running terraform validate..."
405: terraform validate
406: # Terraform plan destroy
407: print_info "Running terraform plan destroy..."
408: terraform plan -var-file="${VARIABLES_FILE}" -destroy -out terraform.tfplan
409: # Terraform apply (destroy)
410: print_warning "Applying destroy plan. This will DESTROY all infrastructure..."
411: terraform apply -auto-approve terraform.tfplan
412: echo ""
413: print_success "Destroy operation completed successfully!"
414: print_info "All infrastructure in ${AWS_REGION} (${ENVIRONMENT}) has been destroyed."
```

## File: tf_backend_state/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Deployment environment"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Name added to all resources"
13:   type        = string
14: }
```

## File: repomix.config.json
```json
 1: {
 2:   "$schema": "https://repomix.com/schemas/latest/schema.json",
 3:   "input": {
 4:     "maxFileSize": 52428800,
 5:     "instructionFilePath": "repomix-instruction.md"
 6:   },
 7:   "output": {
 8:     "filePath": "repomix-output.md",
 9:     "style": "markdown",
10:     "parsableStyle": false,
11:     "fileSummary": true,
12:     "directoryStructure": true,
13:     "files": true,
14:     "removeComments": false,
15:     "removeEmptyLines": true,
16:     "compress": false,
17:     "topFilesLength": 15,
18:     "showLineNumbers": true,
19:     "truncateBase64": false,
20:     "copyToClipboard": false,
21:     "includeFullDirectoryStructure": true,
22:     "tokenCountTree": false,
23:     "git": {
24:       "sortByChanges": true,
25:       "sortByChangesMaxCommits": 100,
26:       "includeDiffs": false,
27:       "includeLogs": false,
28:       "includeLogsCount": 50
29:     }
30:   },
31:   "include": [],
32:   "ignore": {
33:     "useGitignore": true,
34:     "useDotIgnore": true,
35:     "useDefaultPatterns": true,
36:     "customPatterns": []
37:   },
38:   "security": {
39:     "enableSecurityCheck": true
40:   },
41:   "tokenCount": {
42:     "encoding": "o200k_base"
43:   }
44: }
```

## File: .github/workflows/backend_build_push.yaml
```yaml
  1: name: Backend Build and Push
  2: on:
  3:   # push:
  4:   #   branches:
  5:   #     - main
  6:   #   paths:
  7:   #     - 'application/backend/**'
  8:   #     - '.github/workflows/backend_build_push.yaml'
  9:   workflow_dispatch:
 10:     inputs:
 11:       environment:
 12:         description: 'Select Environment'
 13:         required: true
 14:         type: choice
 15:         default: prod
 16:         options:
 17:           - prod
 18:           - dev
 19: env:
 20:   AWS_REGION: us-east-1
 21:   IMAGE_NAME: ldap-2fa-backend
 22: jobs:
 23:   BuildAndPush:
 24:     runs-on: ubuntu-latest
 25:     permissions:
 26:       contents: write
 27:       id-token: write
 28:     outputs:
 29:       image_tag: ${{ steps.build.outputs.image_tag }}
 30:     steps:
 31:       - name: Checkout the repo code
 32:         uses: actions/checkout@v4
 33:         with:
 34:           token: ${{ secrets.GITHUB_TOKEN }}
 35:       - name: Configure AWS credentials
 36:         uses: aws-actions/configure-aws-credentials@v4
 37:         with:
 38:           role-to-assume: ${{ secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN }}
 39:           role-session-name: GitHubActions-BackendBuildPush
 40:           aws-region: ${{ env.AWS_REGION }}
 41:       - name: Login to Amazon ECR
 42:         id: login-ecr
 43:         uses: aws-actions/amazon-ecr-login@v2
 44:       - name: Get ECR Repository URL
 45:         id: ecr-info
 46:         run: |
 47:           # Get ECR repository URL from Terraform outputs or use convention
 48:           ECR_REPO_NAME="${{ vars.ECR_REPOSITORY_NAME }}"
 49:           if [ -z "$ECR_REPO_NAME" ]; then
 50:             ECR_REPO_NAME="${{ vars.PREFIX }}-${{ env.AWS_REGION }}-docker-images-${{ inputs.environment || 'prod' }}"
 51:           fi
 52:           ECR_REGISTRY="${{ steps.login-ecr.outputs.registry }}"
 53:           echo "ecr_registry=${ECR_REGISTRY}" >> $GITHUB_OUTPUT
 54:           echo "ecr_repo_name=${ECR_REPO_NAME}" >> $GITHUB_OUTPUT
 55:           echo "ecr_repo_url=${ECR_REGISTRY}/${ECR_REPO_NAME}" >> $GITHUB_OUTPUT
 56:       - name: Build, tag, and push Docker image
 57:         id: build
 58:         working-directory: ./application/backend
 59:         run: |
 60:           # Generate image tag using commit SHA
 61:           IMAGE_TAG="${{ env.IMAGE_NAME }}-${{ github.sha }}"
 62:           # Build the Docker image
 63:           docker build -t ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG} .
 64:           # Push to ECR
 65:           docker push ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}
 66:           echo "image_tag=${IMAGE_TAG}" >> $GITHUB_OUTPUT
 67:           echo "full_image=${${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}}" >> $GITHUB_OUTPUT
 68:           echo "✅ Pushed image: ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}"
 69:       - name: Update Helm values with new image
 70:         run: |
 71:           # Update the values.yaml with new image repository and tag
 72:           VALUES_FILE="application/backend/helm/ldap-2fa-backend/values.yaml"
 73:           # Update image repository
 74:           sed -i "s|^  repository:.*|  repository: \"${{ steps.ecr-info.outputs.ecr_repo_url }}\"|" ${VALUES_FILE}
 75:           # Update image tag
 76:           sed -i "s|^  tag:.*|  tag: \"${{ steps.build.outputs.image_tag }}\"|" ${VALUES_FILE}
 77:           echo "✅ Updated ${VALUES_FILE} with new image:"
 78:           grep -A 3 "^image:" ${VALUES_FILE}
 79:       - name: Commit and push changes
 80:         run: |
 81:           git config user.name "github-actions[bot]"
 82:           git config user.email "github-actions[bot]@users.noreply.github.com"
 83:           # Check if there are changes to commit
 84:           if git diff --quiet; then
 85:             echo "No changes to commit"
 86:             exit 0
 87:           fi
 88:           git add application/backend/helm/ldap-2fa-backend/values.yaml
 89:           git commit -m "chore(backend): update image tag to ${{ steps.build.outputs.image_tag }}
 90:           Automated update by GitHub Actions workflow.
 91:           Commit: ${{ github.sha }}
 92:           "
 93:           # Push changes
 94:           git push origin main
 95:           echo "✅ Changes committed and pushed"
 96:   NotifyArgoCD:
 97:     runs-on: ubuntu-latest
 98:     permissions:
 99:       contents: read
100:     needs: BuildAndPush
101:     if: success()
102:     steps:
103:       - name: Summary
104:         run: |
105:           echo "## Backend Build Summary" >> $GITHUB_STEP_SUMMARY
106:           echo "" >> $GITHUB_STEP_SUMMARY
107:           echo "✅ **Image Tag:** ${{ needs.BuildAndPush.outputs.image_tag }}" >> $GITHUB_STEP_SUMMARY
108:           echo "" >> $GITHUB_STEP_SUMMARY
109:           echo "ArgoCD will automatically detect the changes and sync the deployment." >> $GITHUB_STEP_SUMMARY
```

## File: .github/workflows/frontend_build_push.yaml
```yaml
  1: name: Frontend Build and Push
  2: on:
  3:   # push:
  4:   #   branches:
  5:   #     - main
  6:   #   paths:
  7:   #     - 'application/frontend/**'
  8:   #     - '.github/workflows/frontend_build_push.yaml'
  9:   workflow_dispatch:
 10:     inputs:
 11:       environment:
 12:         description: 'Select Environment'
 13:         required: true
 14:         type: choice
 15:         default: prod
 16:         options:
 17:           - prod
 18:           - dev
 19: env:
 20:   AWS_REGION: us-east-1
 21:   IMAGE_NAME: ldap-2fa-frontend
 22: jobs:
 23:   BuildAndPush:
 24:     runs-on: ubuntu-latest
 25:     permissions:
 26:       contents: write
 27:       id-token: write
 28:     outputs:
 29:       image_tag: ${{ steps.build.outputs.image_tag }}
 30:     steps:
 31:       - name: Checkout the repo code
 32:         uses: actions/checkout@v4
 33:         with:
 34:           token: ${{ secrets.GITHUB_TOKEN }}
 35:       - name: Configure AWS credentials
 36:         uses: aws-actions/configure-aws-credentials@v4
 37:         with:
 38:           role-to-assume: ${{ secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN }}
 39:           role-session-name: GitHubActions-FrontendBuildPush
 40:           aws-region: ${{ env.AWS_REGION }}
 41:       - name: Login to Amazon ECR
 42:         id: login-ecr
 43:         uses: aws-actions/amazon-ecr-login@v2
 44:       - name: Get ECR Repository URL
 45:         id: ecr-info
 46:         run: |
 47:           # Get ECR repository URL from Terraform outputs or use convention
 48:           ECR_REPO_NAME="${{ vars.ECR_REPOSITORY_NAME }}"
 49:           if [ -z "$ECR_REPO_NAME" ]; then
 50:             ECR_REPO_NAME="${{ vars.PREFIX }}-${{ env.AWS_REGION }}-docker-images-${{ inputs.environment || 'prod' }}"
 51:           fi
 52:           ECR_REGISTRY="${{ steps.login-ecr.outputs.registry }}"
 53:           echo "ecr_registry=${ECR_REGISTRY}" >> $GITHUB_OUTPUT
 54:           echo "ecr_repo_name=${ECR_REPO_NAME}" >> $GITHUB_OUTPUT
 55:           echo "ecr_repo_url=${ECR_REGISTRY}/${ECR_REPO_NAME}" >> $GITHUB_OUTPUT
 56:       - name: Build, tag, and push Docker image
 57:         id: build
 58:         working-directory: ./application/frontend
 59:         run: |
 60:           # Generate image tag using commit SHA
 61:           IMAGE_TAG="${{ env.IMAGE_NAME }}-${{ github.sha }}"
 62:           # Build the Docker image
 63:           docker build -t ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG} .
 64:           # Push to ECR
 65:           docker push ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}
 66:           echo "image_tag=${IMAGE_TAG}" >> $GITHUB_OUTPUT
 67:           echo "full_image=${${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}}" >> $GITHUB_OUTPUT
 68:           echo "✅ Pushed image: ${{ steps.ecr-info.outputs.ecr_repo_url }}:${IMAGE_TAG}"
 69:       - name: Update Helm values with new image
 70:         run: |
 71:           # Update the values.yaml with new image repository and tag
 72:           VALUES_FILE="application/frontend/helm/ldap-2fa-frontend/values.yaml"
 73:           # Update image repository
 74:           sed -i "s|^  repository:.*|  repository: \"${{ steps.ecr-info.outputs.ecr_repo_url }}\"|" ${VALUES_FILE}
 75:           # Update image tag
 76:           sed -i "s|^  tag:.*|  tag: \"${{ steps.build.outputs.image_tag }}\"|" ${VALUES_FILE}
 77:           echo "✅ Updated ${VALUES_FILE} with new image:"
 78:           grep -A 3 "^image:" ${VALUES_FILE}
 79:       - name: Commit and push changes
 80:         run: |
 81:           git config user.name "github-actions[bot]"
 82:           git config user.email "github-actions[bot]@users.noreply.github.com"
 83:           # Check if there are changes to commit
 84:           if git diff --quiet; then
 85:             echo "No changes to commit"
 86:             exit 0
 87:           fi
 88:           git add application/frontend/helm/ldap-2fa-frontend/values.yaml
 89:           git commit -m "chore(frontend): update image tag to ${{ steps.build.outputs.image_tag }}
 90:           Automated update by GitHub Actions workflow.
 91:           Commit: ${{ github.sha }}
 92:           "
 93:           # Push changes
 94:           git push origin main
 95:           echo "✅ Changes committed and pushed"
 96:   NotifyArgoCD:
 97:     runs-on: ubuntu-latest
 98:     needs: BuildAndPush
 99:     if: success()
100:     permissions:
101:       contents: read
102:     steps:
103:       - name: Summary
104:         run: |
105:           echo "## Frontend Build Summary" >> $GITHUB_STEP_SUMMARY
106:           echo "" >> $GITHUB_STEP_SUMMARY
107:           echo "✅ **Image Tag:** ${{ needs.BuildAndPush.outputs.image_tag }}" >> $GITHUB_STEP_SUMMARY
108:           echo "" >> $GITHUB_STEP_SUMMARY
109:           echo "ArgoCD will automatically detect the changes and sync the deployment." >> $GITHUB_STEP_SUMMARY
```

## File: .github/workflows/tfstate_infra_destroying.yaml
```yaml
 1: name: TF Backend State Destroying
 2: on:
 3:   workflow_dispatch:
 4: jobs:
 5:   InfraProvision:
 6:     runs-on: ubuntu-latest
 7:     permissions:
 8:       contents: write
 9:       actions: write
10:       id-token: write
11:     env:
12:       AWS_REGION: ${{ vars.AWS_REGION }}
13:     defaults:
14:       run:
15:         working-directory: ./tf_backend_state
16:     steps:
17:       - name: Checkout the repo code
18:         uses: actions/checkout@v4
19:       - name: Setup terraform
20:         uses: hashicorp/setup-terraform@v3
21:         with:
22:           terraform_version: 1.14.0
23:       - name: Configure AWS credentials (State Account)
24:         uses: aws-actions/configure-aws-credentials@v4
25:         with:
26:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
27:           role-session-name: GitHubActions-TFStateInfraDestroy
28:           aws-region: ${{ env.AWS_REGION }}
29:       - name: Download backend state file from S3
30:         run: |
31:           aws s3 cp \
32:             s3://${{ vars.BACKEND_BUCKET_NAME }}/${{ vars.BACKEND_PREFIX }} \
33:             terraform.tfstate
34:       - name: Terraform init
35:         run: terraform init -backend=false
36:       - name: Terraform validate
37:         run: terraform validate
38:       - name: Terraform plan destroy
39:         run: terraform plan -var-file="variables.tfvars" -destroy -out terraform.tfplan
40:       - name: Destroy backend state
41:         run: terraform apply -auto-approve terraform.tfplan
```

## File: application/backend/helm/ldap-2fa-backend/values.yaml
```yaml
  1: # Default values for ldap-2fa-backend.
  2: # This is a YAML-formatted file.
  3: # Declare variables to be passed into your templates.
  4: # Number of replicas
  5: replicaCount: 2
  6: # Container image configuration
  7: image:
  8:   # ECR repository URL - should be set via CI/CD or ArgoCD
  9:   repository: ""
 10:   pullPolicy: IfNotPresent
 11:   # Image tag - should be set via CI/CD (defaults to Chart appVersion)
 12:   tag: ""
 13: # Secrets for pulling images from private registry
 14: imagePullSecrets: []
 15: # Override chart name
 16: nameOverride: ""
 17: fullnameOverride: ""
 18: # Service account configuration
 19: serviceAccount:
 20:   create: true
 21:   automount: true
 22:   annotations: {}
 23:   name: ""
 24: # Pod annotations and labels
 25: podAnnotations: {}
 26: podLabels: {}
 27: # Pod security context
 28: podSecurityContext:
 29:   fsGroup: 1000
 30: # Container security context
 31: securityContext:
 32:   capabilities:
 33:     drop:
 34:       - ALL
 35:   readOnlyRootFilesystem: false
 36:   runAsNonRoot: true
 37:   runAsUser: 1000
 38:   allowPrivilegeEscalation: false
 39: # Service configuration
 40: service:
 41:   type: ClusterIP
 42:   port: 8000
 43: # Ingress configuration for ALB
 44: ingress:
 45:   enabled: true
 46:   className: ""  # Will be set to IngressClass name
 47:   annotations:
 48:     # ALB-specific annotations
 49:     alb.ingress.kubernetes.io/load-balancer-name: ""
 50:     alb.ingress.kubernetes.io/target-type: "ip"
 51:     alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
 52:     alb.ingress.kubernetes.io/ssl-redirect: "443"
 53:     alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"
 54:     # Order annotation for path priority (lower number = higher priority)
 55:     alb.ingress.kubernetes.io/group.order: "10"
 56:   hosts:
 57:     - host: ""  # app.<domain> - set by ArgoCD/values override
 58:       paths:
 59:         - path: /api
 60:           pathType: Prefix
 61:   tls: []
 62: # HTTPRoute (Gateway API) - not used
 63: httpRoute:
 64:   enabled: false
 65: # Resource limits and requests
 66: resources:
 67:   limits:
 68:     cpu: 500m
 69:     memory: 256Mi
 70:   requests:
 71:     cpu: 100m
 72:     memory: 128Mi
 73: # Liveness probe configuration
 74: livenessProbe:
 75:   httpGet:
 76:     path: /api/healthz
 77:     port: http
 78:   initialDelaySeconds: 10
 79:   periodSeconds: 30
 80:   timeoutSeconds: 5
 81:   failureThreshold: 3
 82: # Readiness probe configuration
 83: readinessProbe:
 84:   httpGet:
 85:     path: /api/healthz
 86:     port: http
 87:   initialDelaySeconds: 5
 88:   periodSeconds: 10
 89:   timeoutSeconds: 5
 90:   failureThreshold: 3
 91: # Autoscaling configuration
 92: autoscaling:
 93:   enabled: false
 94:   minReplicas: 2
 95:   maxReplicas: 10
 96:   targetCPUUtilizationPercentage: 80
 97:   targetMemoryUtilizationPercentage: 80
 98: # Additional volumes
 99: volumes: []
100: # Additional volume mounts
101: volumeMounts: []
102: # Node selector
103: nodeSelector: {}
104: # Tolerations
105: tolerations: []
106: # Affinity rules
107: affinity: {}
108: # =============================================================================
109: # Application-specific configuration
110: # =============================================================================
111: # LDAP configuration (non-sensitive values)
112: ldap:
113:   # LDAP server hostname (Kubernetes service DNS)
114:   host: "openldap-stack-ha.ldap.svc.cluster.local"
115:   # LDAP port
116:   port: 389
117:   # Use SSL/TLS for LDAP connection
118:   useSsl: false
119:   # Base DN for LDAP operations
120:   baseDn: "dc=ldap,dc=talorlik,dc=internal"
121:   # Admin DN for binding (used for user lookups)
122:   adminDn: "cn=admin,dc=ldap,dc=talorlik,dc=internal"
123:   # User search base (relative to baseDn)
124:   userSearchBase: "ou=users"
125:   # User search filter (use {0} as placeholder for username)
126:   userSearchFilter: "(uid={0})"
127: # MFA/TOTP configuration
128: mfa:
129:   # TOTP issuer name (appears in authenticator apps)
130:   issuer: "LDAP-2FA-App"
131:   # Number of digits in TOTP code
132:   digits: 6
133:   # TOTP interval in seconds
134:   interval: 30
135:   # TOTP algorithm (SHA1, SHA256, SHA512)
136:   algorithm: "SHA1"
137: # Application configuration
138: app:
139:   # Application name
140:   name: "LDAP 2FA Backend API"
141:   # Enable debug mode (enables API docs)
142:   debug: false
143:   # Log level (DEBUG, INFO, WARNING, ERROR)
144:   logLevel: "INFO"
145:   # CORS origins (comma-separated, empty for none)
146:   corsOrigins: ""
147: # External secrets configuration
148: # Reference to existing Kubernetes secret for sensitive values
149: externalSecret:
150:   # Enable using external secret for LDAP admin password
151:   enabled: true
152:   # Name of the existing secret containing LDAP admin password
153:   secretName: "ldap-admin-secret"
154:   # Key in the secret containing the admin password
155:   adminPasswordKey: "LDAP_ADMIN_PASSWORD"
156: # =============================================================================
157: # Database Configuration (PostgreSQL)
158: # =============================================================================
159: database:
160:   # PostgreSQL connection URL
161:   # Format: postgresql+asyncpg://user:password@host:port/database
162:   url: "postgresql+asyncpg://ldap2fa:ldap2fa@postgresql.ldap-2fa.svc.cluster.local:5432/ldap2fa"
163:   # Use external secret for database password
164:   externalSecret:
165:     enabled: true
166:     secretName: "postgresql-secret"
167:     passwordKey: "password"
168: # =============================================================================
169: # Email Configuration (AWS SES)
170: # =============================================================================
171: email:
172:   # Enable email verification
173:   enabled: true
174:   # Sender email address (must be verified in SES)
175:   senderEmail: "noreply@example.com"
176:   # Email verification token expiry in hours
177:   verificationExpiryHours: 24
178:   # Application URL for verification links
179:   appUrl: "https://app.example.com"
180: # =============================================================================
181: # LDAP Admin Group Configuration
182: # =============================================================================
183: ldapAdmin:
184:   # Admin group DN for checking admin privileges
185:   groupDn: "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal"
186:   # Default GID for new users
187:   usersGid: 500
188:   # Starting UID for new users
189:   uidStart: 10000
190: # =============================================================================
191: # SMS/SNS Configuration (for SMS-based 2FA)
192: # =============================================================================
193: sms:
194:   # Enable SMS-based 2FA
195:   enabled: false
196:   # AWS region for SNS
197:   awsRegion: "us-east-1"
198:   # SNS topic ARN (optional - for subscriptions/notifications)
199:   snsTopicArn: ""
200:   # SMS sender ID (max 11 alphanumeric chars, may not work in all countries)
201:   senderId: "2FA"
202:   # SMS type: Transactional (higher priority) or Promotional
203:   smsType: "Transactional"
204:   # Verification code length
205:   codeLength: 6
206:   # Code expiry in seconds
207:   codeExpirySeconds: 300
208:   # Custom message template ({code} placeholder for the code)
209:   messageTemplate: "Your verification code is: {code}. It expires in 5 minutes."
210: # IAM Role for Service Account (IRSA) - required for SNS/SES access
211: serviceAccountIAM:
212:   # IAM role ARN to attach to the service account
213:   # This should include permissions for both SNS (SMS) and SES (Email)
214:   roleArn: ""
215: # =============================================================================
216: # Redis Configuration (SMS OTP Storage)
217: # =============================================================================
218: redis:
219:   # Enable Redis for SMS OTP storage
220:   enabled: false
221:   # Redis service hostname
222:   host: "redis-master.redis.svc.cluster.local"
223:   # Redis service port
224:   port: 6379
225:   # Redis database number
226:   db: 0
227:   # Enable SSL/TLS
228:   ssl: false
229:   # Key prefix for OTP storage
230:   keyPrefix: "sms_otp:"
231:   # External secret for Redis password
232:   existingSecret:
233:     # Enable using external secret for Redis password
234:     enabled: false
235:     # Name of the existing secret containing Redis password
236:     name: "redis-secret"
237:     # Key in the secret containing the password
238:     key: "redis-password"
```

## File: application/backend/src/app/api/routes.py
```python
   1: """API routes for 2FA authentication with user signup and admin management."""
   2: import hmac
   3: import logging
   4: import re
   5: import secrets
   6: import time
   7: import uuid
   8: from datetime import datetime, timedelta, timezone
   9: from enum import Enum
  10: from typing import Optional
  11: import bcrypt
  12: import jwt
  13: from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
  14: from pydantic import BaseModel, EmailStr, Field, field_validator
  15: from sqlalchemy import select, or_, func
  16: from sqlalchemy.ext.asyncio import AsyncSession
  17: from sqlalchemy.orm import selectinload
  18: from app.config import get_settings
  19: from app.database import get_async_session, User, VerificationToken, ProfileStatus, Group, UserGroup
  20: from app.email import EmailClient
  21: from app.ldap import LDAPClient
  22: from app.mfa import TOTPManager
  23: from app.redis import get_otp_client, RedisOTPClient
  24: from app.redis.client import InMemoryOTPStorage
  25: logger = logging.getLogger(__name__)
  26: router = APIRouter(prefix="/api", tags=["authentication"])
  27: # ============================================================================
  28: # Enums and Constants
  29: # ============================================================================
  30: class MFAMethod(str, Enum):
  31:     """Supported MFA methods."""
  32:     TOTP = "totp"
  33:     SMS = "sms"
  34: # In-memory fallback storage for SMS verification codes (used when Redis is disabled)
  35: # Structure: {username: {"code": "...", "expires_at": timestamp, "phone_number": "..."}}
  36: # Note: When Redis is enabled, codes are stored in Redis with automatic TTL expiration
  37: # ============================================================================
  38: # Request/Response Models
  39: # ============================================================================
  40: class HealthResponse(BaseModel):
  41:     """Health check response model."""
  42:     status: str = Field(..., description="Health status")
  43:     service: str = Field(..., description="Service name")
  44:     sms_enabled: bool = Field(..., description="Whether SMS 2FA is enabled")
  45: class SignupRequest(BaseModel):
  46:     """User signup request model."""
  47:     username: str = Field(..., min_length=3, max_length=64, description="Username")
  48:     email: EmailStr = Field(..., description="Email address")
  49:     first_name: str = Field(..., min_length=1, max_length=100, description="First name")
  50:     last_name: str = Field(..., min_length=1, max_length=100, description="Last name")
  51:     phone_country_code: str = Field(..., description="Phone country code (e.g., +1)")
  52:     phone_number: str = Field(..., min_length=5, max_length=20, description="Phone number")
  53:     password: str = Field(..., min_length=8, description="Password")
  54:     mfa_method: MFAMethod = Field(default=MFAMethod.TOTP, description="MFA method")
  55:     @field_validator("username")
  56:     @classmethod
  57:     def validate_username(cls, v):
  58:         """Validate username format."""
  59:         if not re.match(r"^[a-zA-Z][a-zA-Z0-9_-]*$", v):
  60:             raise ValueError("Username must start with a letter and contain only letters, numbers, underscores, and hyphens")
  61:         return v.lower()
  62:     @field_validator("phone_country_code")
  63:     @classmethod
  64:     def validate_country_code(cls, v):
  65:         """Validate phone country code format."""
  66:         if not re.match(r"^\+\d{1,4}$", v):
  67:             raise ValueError("Country code must be in format +X or +XX (e.g., +1, +44)")
  68:         return v
  69:     @field_validator("phone_number")
  70:     @classmethod
  71:     def validate_phone_number(cls, v):
  72:         """Validate phone number format."""
  73:         # Remove any spaces or dashes
  74:         cleaned = re.sub(r"[\s-]", "", v)
  75:         if not re.match(r"^\d{5,15}$", cleaned):
  76:             raise ValueError("Phone number must contain 5-15 digits")
  77:         return cleaned
  78: class SignupResponse(BaseModel):
  79:     """Signup response model."""
  80:     success: bool = Field(..., description="Whether signup was successful")
  81:     message: str = Field(..., description="Response message")
  82:     user_id: Optional[str] = Field(None, description="User ID")
  83:     email_verification_sent: bool = Field(False, description="Whether email verification was sent")
  84:     phone_verification_sent: bool = Field(False, description="Whether phone verification was sent")
  85: class VerifyEmailRequest(BaseModel):
  86:     """Email verification request model."""
  87:     token: str = Field(..., description="Email verification token")
  88:     username: str = Field(..., description="Username")
  89: class VerifyPhoneRequest(BaseModel):
  90:     """Phone verification request model."""
  91:     username: str = Field(..., description="Username")
  92:     code: str = Field(..., min_length=6, max_length=6, description="6-digit verification code")
  93: class VerificationResponse(BaseModel):
  94:     """Verification response model."""
  95:     success: bool = Field(..., description="Whether verification was successful")
  96:     message: str = Field(..., description="Response message")
  97:     profile_status: Optional[str] = Field(None, description="Updated profile status")
  98: class ResendVerificationRequest(BaseModel):
  99:     """Request to resend verification."""
 100:     username: str = Field(..., description="Username")
 101:     verification_type: str = Field(..., description="Type: 'email' or 'phone'")
 102: class ProfileStatusResponse(BaseModel):
 103:     """User profile status response model."""
 104:     username: str = Field(..., description="Username")
 105:     email: str = Field(..., description="Masked email")
 106:     phone: str = Field(..., description="Masked phone")
 107:     status: str = Field(..., description="Profile status")
 108:     email_verified: bool = Field(..., description="Email verified")
 109:     phone_verified: bool = Field(..., description="Phone verified")
 110:     mfa_method: str = Field(..., description="MFA method")
 111:     created_at: str = Field(..., description="Account creation date")
 112: class EnrollRequest(BaseModel):
 113:     """MFA enrollment request model (for active users)."""
 114:     username: str = Field(..., min_length=1, description="Username")
 115:     password: str = Field(..., min_length=1, description="Password")
 116:     mfa_method: MFAMethod = Field(default=MFAMethod.TOTP, description="MFA method")
 117:     phone_number: Optional[str] = Field(None, description="Phone for SMS")
 118: class EnrollResponse(BaseModel):
 119:     """Enrollment response model."""
 120:     success: bool = Field(..., description="Whether enrollment was successful")
 121:     message: str = Field(..., description="Response message")
 122:     mfa_method: MFAMethod = Field(..., description="Enrolled MFA method")
 123:     otpauth_uri: Optional[str] = Field(None, description="otpauth:// URI for QR code")
 124:     secret: Optional[str] = Field(None, description="TOTP secret for manual entry")
 125:     phone_number: Optional[str] = Field(None, description="Masked phone number")
 126: class LoginRequest(BaseModel):
 127:     """Login request model."""
 128:     username: str = Field(..., min_length=1, description="Username")
 129:     password: str = Field(..., min_length=1, description="Password")
 130:     verification_code: str = Field(..., min_length=6, max_length=6, description="6-digit code")
 131: class LoginResponse(BaseModel):
 132:     """Login response model."""
 133:     success: bool = Field(..., description="Whether login was successful")
 134:     message: str = Field(..., description="Response message")
 135:     is_admin: bool = Field(False, description="Whether user is admin")
 136:     token: Optional[str] = Field(None, description="JWT access token")
 137:     username: Optional[str] = Field(None, description="Logged in username")
 138: class SMSSendCodeRequest(BaseModel):
 139:     """Request to send SMS verification code."""
 140:     username: str = Field(..., min_length=1, description="Username")
 141:     password: str = Field(..., min_length=1, description="Password")
 142: class SMSSendCodeResponse(BaseModel):
 143:     """Response after sending SMS code."""
 144:     success: bool = Field(..., description="Whether code was sent")
 145:     message: str = Field(..., description="Response message")
 146:     phone_number: Optional[str] = Field(None, description="Masked phone number")
 147:     expires_in_seconds: Optional[int] = Field(None, description="Seconds until expiry")
 148: class MFAMethodsResponse(BaseModel):
 149:     """Response with available MFA methods."""
 150:     methods: list[str] = Field(..., description="Available MFA methods")
 151:     sms_enabled: bool = Field(..., description="Whether SMS is enabled")
 152: class UserMFAStatusResponse(BaseModel):
 153:     """Response with user's MFA enrollment status."""
 154:     enrolled: bool = Field(..., description="Whether user is enrolled")
 155:     mfa_method: Optional[str] = Field(None, description="Enrolled MFA method")
 156:     phone_number: Optional[str] = Field(None, description="Masked phone")
 157: # Admin models
 158: class AdminUserListResponse(BaseModel):
 159:     """Admin user list response."""
 160:     users: list[dict] = Field(..., description="List of users")
 161:     total: int = Field(..., description="Total count")
 162: class AdminActivateRequest(BaseModel):
 163:     """Admin user activation request."""
 164:     admin_username: str = Field(..., description="Admin username")
 165:     admin_password: str = Field(..., description="Admin password")
 166: class AdminActivateResponse(BaseModel):
 167:     """Admin activation response."""
 168:     success: bool = Field(..., description="Whether activation was successful")
 169:     message: str = Field(..., description="Response message")
 170: # Profile Models
 171: class ProfileResponse(BaseModel):
 172:     """User profile response model."""
 173:     id: str = Field(..., description="User ID")
 174:     username: str = Field(..., description="Username")
 175:     email: str = Field(..., description="Email address")
 176:     first_name: str = Field(..., description="First name")
 177:     last_name: str = Field(..., description="Last name")
 178:     phone_country_code: str = Field(..., description="Phone country code")
 179:     phone_number: str = Field(..., description="Phone number")
 180:     email_verified: bool = Field(..., description="Email verified")
 181:     phone_verified: bool = Field(..., description="Phone verified")
 182:     mfa_method: str = Field(..., description="MFA method")
 183:     status: str = Field(..., description="Profile status")
 184:     created_at: str = Field(..., description="Creation date")
 185:     groups: list[dict] = Field(default_factory=list, description="User's groups")
 186: class ProfileUpdateRequest(BaseModel):
 187:     """Profile update request model."""
 188:     first_name: Optional[str] = Field(None, min_length=1, max_length=100)
 189:     last_name: Optional[str] = Field(None, min_length=1, max_length=100)
 190:     email: Optional[EmailStr] = Field(None)
 191:     phone_country_code: Optional[str] = Field(None)
 192:     phone_number: Optional[str] = Field(None)
 193:     @field_validator("phone_country_code")
 194:     @classmethod
 195:     def validate_country_code(cls, v):
 196:         if v is not None and not re.match(r"^\+\d{1,4}$", v):
 197:             raise ValueError("Country code must be in format +X or +XX")
 198:         return v
 199:     @field_validator("phone_number")
 200:     @classmethod
 201:     def validate_phone_number(cls, v):
 202:         if v is not None:
 203:             cleaned = re.sub(r"[\s-]", "", v)
 204:             if not re.match(r"^\d{5,15}$", cleaned):
 205:                 raise ValueError("Phone number must contain 5-15 digits")
 206:             return cleaned
 207:         return v
 208: # Group Models
 209: class GroupCreateRequest(BaseModel):
 210:     """Group creation request."""
 211:     name: str = Field(..., min_length=1, max_length=100, description="Group name")
 212:     description: Optional[str] = Field(None, max_length=500, description="Group description")
 213: class GroupUpdateRequest(BaseModel):
 214:     """Group update request."""
 215:     name: Optional[str] = Field(None, min_length=1, max_length=100)
 216:     description: Optional[str] = Field(None, max_length=500)
 217: class GroupResponse(BaseModel):
 218:     """Group response model."""
 219:     id: str = Field(..., description="Group ID")
 220:     name: str = Field(..., description="Group name")
 221:     description: Optional[str] = Field(None, description="Group description")
 222:     ldap_dn: str = Field(..., description="LDAP DN")
 223:     member_count: int = Field(..., description="Number of members")
 224:     created_at: str = Field(..., description="Creation date")
 225: class GroupListResponse(BaseModel):
 226:     """Group list response."""
 227:     groups: list[GroupResponse] = Field(..., description="List of groups")
 228:     total: int = Field(..., description="Total count")
 229: class GroupDetailResponse(GroupResponse):
 230:     """Group detail response with members."""
 231:     members: list[dict] = Field(default_factory=list, description="Group members")
 232: # User-Group Assignment Models
 233: class UserGroupAssignRequest(BaseModel):
 234:     """Request to assign user to groups."""
 235:     group_ids: list[str] = Field(..., description="List of group IDs to assign")
 236: class UserGroupResponse(BaseModel):
 237:     """User's groups response."""
 238:     user_id: str = Field(..., description="User ID")
 239:     username: str = Field(..., description="Username")
 240:     groups: list[dict] = Field(..., description="Assigned groups")
 241: # Enhanced Admin User List
 242: class AdminUserListRequest(BaseModel):
 243:     """Admin user list query parameters."""
 244:     status_filter: Optional[str] = Field(None, description="Filter by status")
 245:     group_filter: Optional[str] = Field(None, description="Filter by group ID")
 246:     search: Optional[str] = Field(None, description="Search term")
 247:     sort_by: Optional[str] = Field("created_at", description="Sort field")
 248:     sort_order: Optional[str] = Field("desc", description="Sort order (asc/desc)")
 249: # ============================================================================
 250: # Helper Functions
 251: # ============================================================================
 252: def _mask_phone_number(phone: str) -> str:
 253:     """Mask phone number for display."""
 254:     if len(phone) > 4:
 255:         return "*" * (len(phone) - 4) + phone[-4:]
 256:     return phone
 257: def _mask_email(email: str) -> str:
 258:     """Mask email for display."""
 259:     if "@" not in email:
 260:         return email
 261:     local, domain = email.split("@", 1)
 262:     if len(local) > 2:
 263:         masked = local[0] + "*" * (len(local) - 2) + local[-1]
 264:     else:
 265:         masked = "*" * len(local)
 266:     return f"{masked}@{domain}"
 267: def _hash_password(password: str) -> str:
 268:     """Hash password using bcrypt."""
 269:     return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
 270: def _verify_password(password: str, hashed: str) -> bool:
 271:     """Verify password against hash."""
 272:     return bcrypt.checkpw(password.encode(), hashed.encode())
 273: def _get_sms_client():
 274:     """Get SMS client (lazy import)."""
 275:     from app.sms import SMSClient
 276:     return SMSClient()
 277: def _generate_verification_code(length: int = 6) -> str:
 278:     """Generate a numeric verification code."""
 279:     return "".join(secrets.choice("0123456789") for _ in range(length))
 280: async def _get_user_by_username(session: AsyncSession, username: str) -> Optional[User]:
 281:     """Get user by username."""
 282:     result = await session.execute(
 283:         select(User).where(User.username == username.lower())
 284:     )
 285:     return result.scalar_one_or_none()
 286: async def _get_user_by_email(session: AsyncSession, email: str) -> Optional[User]:
 287:     """Get user by email."""
 288:     result = await session.execute(
 289:         select(User).where(User.email == email.lower())
 290:     )
 291:     return result.scalar_one_or_none()
 292: async def _create_verification_token(
 293:     session: AsyncSession,
 294:     user_id: uuid.UUID,
 295:     token_type: str,
 296:     expiry_hours: int = 24,
 297: ) -> str:
 298:     """Create a verification token."""
 299:     # Invalidate existing tokens of the same type
 300:     result = await session.execute(
 301:         select(VerificationToken).where(
 302:             VerificationToken.user_id == user_id,
 303:             VerificationToken.token_type == token_type,
 304:             VerificationToken.used == False,
 305:         )
 306:     )
 307:     for old_token in result.scalars():
 308:         old_token.used = True
 309:     # Create new token
 310:     if token_type == "email":
 311:         token = str(uuid.uuid4())
 312:     else:
 313:         token = _generate_verification_code(6)
 314:     verification_token = VerificationToken(
 315:         user_id=user_id,
 316:         token_type=token_type,
 317:         token=token,
 318:         expires_at=datetime.now(timezone.utc) + timedelta(hours=expiry_hours),
 319:     )
 320:     session.add(verification_token)
 321:     await session.flush()
 322:     return token
 323: # ============================================================================
 324: # JWT Helper Functions
 325: # ============================================================================
 326: def _create_jwt_token(
 327:     user_id: str,
 328:     username: str,
 329:     is_admin: bool,
 330:     expires_delta: Optional[timedelta] = None,
 331: ) -> str:
 332:     """Create a JWT token for authenticated sessions."""
 333:     settings = get_settings()
 334:     if expires_delta is None:
 335:         expires_delta = timedelta(minutes=settings.jwt_expiry_minutes)
 336:     expire = datetime.now(timezone.utc) + expires_delta
 337:     payload = {
 338:         "sub": user_id,
 339:         "username": username,
 340:         "is_admin": is_admin,
 341:         "exp": expire,
 342:         "iat": datetime.now(timezone.utc),
 343:     }
 344:     return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
 345: def _decode_jwt_token(token: str) -> dict:
 346:     """Decode and validate a JWT token."""
 347:     settings = get_settings()
 348:     try:
 349:         payload = jwt.decode(
 350:             token,
 351:             settings.jwt_secret_key,
 352:             algorithms=[settings.jwt_algorithm]
 353:         )
 354:         return payload
 355:     except jwt.ExpiredSignatureError:
 356:         raise HTTPException(
 357:             status_code=status.HTTP_401_UNAUTHORIZED,
 358:             detail="Token has expired",
 359:         )
 360:     except jwt.InvalidTokenError:
 361:         raise HTTPException(
 362:             status_code=status.HTTP_401_UNAUTHORIZED,
 363:             detail="Invalid token",
 364:         )
 365: async def _get_current_user(
 366:     authorization: Optional[str] = Header(None),
 367:     session: AsyncSession = Depends(get_async_session),
 368: ) -> dict:
 369:     """Get current user from JWT token."""
 370:     if not authorization or not authorization.startswith("Bearer "):
 371:         raise HTTPException(
 372:             status_code=status.HTTP_401_UNAUTHORIZED,
 373:             detail="Missing or invalid authorization header",
 374:         )
 375:     token = authorization.split(" ")[1]
 376:     payload = _decode_jwt_token(token)
 377:     user = await _get_user_by_username(session, payload["username"])
 378:     if not user:
 379:         raise HTTPException(
 380:             status_code=status.HTTP_401_UNAUTHORIZED,
 381:             detail="User not found",
 382:         )
 383:     return {
 384:         "user": user,
 385:         "user_id": payload["sub"],
 386:         "username": payload["username"],
 387:         "is_admin": payload["is_admin"],
 388:     }
 389: async def _require_admin(
 390:     authorization: Optional[str] = Header(None),
 391:     session: AsyncSession = Depends(get_async_session),
 392: ) -> dict:
 393:     """Require admin privileges for an endpoint."""
 394:     current = await _get_current_user(authorization, session)
 395:     if not current["is_admin"]:
 396:         raise HTTPException(
 397:             status_code=status.HTTP_403_FORBIDDEN,
 398:             detail="Admin privileges required",
 399:         )
 400:     return current
 401: async def _send_admin_notification(user: User) -> None:
 402:     """Send notification email to admins about new user signup."""
 403:     try:
 404:         ldap_client = LDAPClient()
 405:         admin_emails = ldap_client.get_admin_emails()
 406:         if not admin_emails:
 407:             logger.warning("No admin emails found for notification")
 408:             return
 409:         email_client = EmailClient()
 410:         new_user_data = {
 411:             "username": user.username,
 412:             "full_name": user.full_name,
 413:             "email": user.email,
 414:             "phone": user.full_phone_number,
 415:             "signup_time": user.created_at.isoformat() if user.created_at else datetime.now(timezone.utc).isoformat(),
 416:         }
 417:         success, msg = email_client.send_admin_notification_email(admin_emails, new_user_data)
 418:         if success:
 419:             logger.info(f"Admin notification sent for new user {user.username}")
 420:         else:
 421:             logger.error(f"Failed to send admin notification: {msg}")
 422:     except Exception as e:
 423:         logger.error(f"Error sending admin notification: {e}")
 424: # ============================================================================
 425: # Health Check
 426: # ============================================================================
 427: @router.get("/healthz", response_model=HealthResponse)
 428: async def health_check() -> HealthResponse:
 429:     """Liveness/readiness probe endpoint."""
 430:     settings = get_settings()
 431:     return HealthResponse(
 432:         status="healthy",
 433:         service=settings.app_name,
 434:         sms_enabled=settings.enable_sms_2fa,
 435:     )
 436: # ============================================================================
 437: # Signup Endpoints
 438: # ============================================================================
 439: @router.post(
 440:     "/auth/signup",
 441:     response_model=SignupResponse,
 442:     responses={
 443:         400: {"description": "Validation error or user exists"},
 444:         500: {"description": "Internal server error"},
 445:     },
 446: )
 447: async def signup(
 448:     request: SignupRequest,
 449:     session: AsyncSession = Depends(get_async_session),
 450: ) -> SignupResponse:
 451:     """
 452:     Register a new user account.
 453:     Creates user in PENDING state and sends verification emails/SMS.
 454:     """
 455:     settings = get_settings()
 456:     # Check if username exists
 457:     if await _get_user_by_username(session, request.username):
 458:         raise HTTPException(
 459:             status_code=status.HTTP_400_BAD_REQUEST,
 460:             detail="Username already taken",
 461:         )
 462:     # Check if email exists
 463:     if await _get_user_by_email(session, request.email):
 464:         raise HTTPException(
 465:             status_code=status.HTTP_400_BAD_REQUEST,
 466:             detail="Email already registered",
 467:         )
 468:     # Validate SMS method is enabled if selected
 469:     if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
 470:         raise HTTPException(
 471:             status_code=status.HTTP_400_BAD_REQUEST,
 472:             detail="SMS 2FA is not enabled",
 473:         )
 474:     # Generate TOTP secret if needed
 475:     totp_secret = None
 476:     if request.mfa_method == MFAMethod.TOTP:
 477:         totp_manager = TOTPManager()
 478:         totp_secret = totp_manager.generate_secret()
 479:     # Create user
 480:     user = User(
 481:         username=request.username.lower(),
 482:         email=request.email.lower(),
 483:         first_name=request.first_name,
 484:         last_name=request.last_name,
 485:         phone_country_code=request.phone_country_code,
 486:         phone_number=request.phone_number,
 487:         password_hash=_hash_password(request.password),
 488:         mfa_method=request.mfa_method.value,
 489:         totp_secret=totp_secret,
 490:         status=ProfileStatus.PENDING.value,
 491:     )
 492:     session.add(user)
 493:     await session.flush()
 494:     email_sent = False
 495:     phone_sent = False
 496:     # Send email verification
 497:     if settings.enable_email_verification:
 498:         try:
 499:             email_token = await _create_verification_token(
 500:                 session, user.id, "email",
 501:                 settings.email_verification_expiry_hours
 502:             )
 503:             email_client = EmailClient()
 504:             success, _ = email_client.send_verification_email(
 505:                 to_email=user.email,
 506:                 token=email_token,
 507:                 username=user.username,
 508:                 first_name=user.first_name,
 509:             )
 510:             email_sent = success
 511:         except Exception as e:
 512:             logger.error(f"Failed to send verification email: {e}")
 513:     # Send phone verification
 514:     try:
 515:         phone_token = await _create_verification_token(
 516:             session, user.id, "phone",
 517:             expiry_hours=1,  # Phone codes expire faster
 518:         )
 519:         sms_client = _get_sms_client()
 520:         full_phone = f"{user.phone_country_code}{user.phone_number}"
 521:         success, _, _ = sms_client.send_verification_code(full_phone, phone_token)
 522:         phone_sent = success
 523:     except Exception as e:
 524:         logger.error(f"Failed to send verification SMS: {e}")
 525:     await session.commit()
 526:     # Send admin notification asynchronously (don't block response)
 527:     await _send_admin_notification(user)
 528:     logger.info(f"User {user.username} signed up successfully")
 529:     return SignupResponse(
 530:         success=True,
 531:         message="Account created. Please verify your email and phone number.",
 532:         user_id=str(user.id),
 533:         email_verification_sent=email_sent,
 534:         phone_verification_sent=phone_sent,
 535:     )
 536: # ============================================================================
 537: # Verification Endpoints
 538: # ============================================================================
 539: @router.post(
 540:     "/auth/verify-email",
 541:     response_model=VerificationResponse,
 542:     responses={
 543:         400: {"description": "Invalid or expired token"},
 544:         404: {"description": "User not found"},
 545:     },
 546: )
 547: async def verify_email(
 548:     request: VerifyEmailRequest,
 549:     session: AsyncSession = Depends(get_async_session),
 550: ) -> VerificationResponse:
 551:     """Verify user's email address."""
 552:     user = await _get_user_by_username(session, request.username)
 553:     if not user:
 554:         raise HTTPException(
 555:             status_code=status.HTTP_404_NOT_FOUND,
 556:             detail="User not found",
 557:         )
 558:     if user.email_verified:
 559:         return VerificationResponse(
 560:             success=True,
 561:             message="Email already verified",
 562:             profile_status=user.status,
 563:         )
 564:     # Find valid token
 565:     result = await session.execute(
 566:         select(VerificationToken).where(
 567:             VerificationToken.user_id == user.id,
 568:             VerificationToken.token_type == "email",
 569:             VerificationToken.token == request.token,
 570:             VerificationToken.used == False,
 571:         )
 572:     )
 573:     token = result.scalar_one_or_none()
 574:     if not token:
 575:         raise HTTPException(
 576:             status_code=status.HTTP_400_BAD_REQUEST,
 577:             detail="Invalid verification token",
 578:         )
 579:     if token.expires_at < datetime.now(timezone.utc):
 580:         raise HTTPException(
 581:             status_code=status.HTTP_400_BAD_REQUEST,
 582:             detail="Verification token has expired. Please request a new one.",
 583:         )
 584:     # Mark as verified
 585:     token.used = True
 586:     user.email_verified = True
 587:     user.update_status_if_complete()
 588:     await session.commit()
 589:     logger.info(f"User {user.username} verified email")
 590:     return VerificationResponse(
 591:         success=True,
 592:         message="Email verified successfully",
 593:         profile_status=user.status,
 594:     )
 595: @router.post(
 596:     "/auth/verify-phone",
 597:     response_model=VerificationResponse,
 598:     responses={
 599:         400: {"description": "Invalid or expired code"},
 600:         404: {"description": "User not found"},
 601:     },
 602: )
 603: async def verify_phone(
 604:     request: VerifyPhoneRequest,
 605:     session: AsyncSession = Depends(get_async_session),
 606: ) -> VerificationResponse:
 607:     """Verify user's phone number."""
 608:     user = await _get_user_by_username(session, request.username)
 609:     if not user:
 610:         raise HTTPException(
 611:             status_code=status.HTTP_404_NOT_FOUND,
 612:             detail="User not found",
 613:         )
 614:     if user.phone_verified:
 615:         return VerificationResponse(
 616:             success=True,
 617:             message="Phone already verified",
 618:             profile_status=user.status,
 619:         )
 620:     # Find valid token
 621:     result = await session.execute(
 622:         select(VerificationToken).where(
 623:             VerificationToken.user_id == user.id,
 624:             VerificationToken.token_type == "phone",
 625:             VerificationToken.used == False,
 626:         ).order_by(VerificationToken.created_at.desc())
 627:     )
 628:     token = result.scalar_one_or_none()
 629:     if not token:
 630:         raise HTTPException(
 631:             status_code=status.HTTP_400_BAD_REQUEST,
 632:             detail="No verification code found. Please request a new one.",
 633:         )
 634:     if token.expires_at < datetime.now(timezone.utc):
 635:         raise HTTPException(
 636:             status_code=status.HTTP_400_BAD_REQUEST,
 637:             detail="Verification code has expired. Please request a new one.",
 638:         )
 639:     # Constant-time comparison
 640:     if not hmac.compare_digest(request.code, token.token):
 641:         raise HTTPException(
 642:             status_code=status.HTTP_400_BAD_REQUEST,
 643:             detail="Invalid verification code",
 644:         )
 645:     # Mark as verified
 646:     token.used = True
 647:     user.phone_verified = True
 648:     user.update_status_if_complete()
 649:     await session.commit()
 650:     logger.info(f"User {user.username} verified phone")
 651:     return VerificationResponse(
 652:         success=True,
 653:         message="Phone verified successfully",
 654:         profile_status=user.status,
 655:     )
 656: @router.post(
 657:     "/auth/resend-verification",
 658:     response_model=VerificationResponse,
 659:     responses={
 660:         400: {"description": "Invalid request"},
 661:         404: {"description": "User not found"},
 662:     },
 663: )
 664: async def resend_verification(
 665:     request: ResendVerificationRequest,
 666:     session: AsyncSession = Depends(get_async_session),
 667: ) -> VerificationResponse:
 668:     """Resend verification email or SMS."""
 669:     settings = get_settings()
 670:     user = await _get_user_by_username(session, request.username)
 671:     if not user:
 672:         raise HTTPException(
 673:             status_code=status.HTTP_404_NOT_FOUND,
 674:             detail="User not found",
 675:         )
 676:     if request.verification_type == "email":
 677:         if user.email_verified:
 678:             return VerificationResponse(
 679:                 success=True,
 680:                 message="Email already verified",
 681:                 profile_status=user.status,
 682:             )
 683:         token = await _create_verification_token(
 684:             session, user.id, "email",
 685:             settings.email_verification_expiry_hours
 686:         )
 687:         email_client = EmailClient()
 688:         success, msg = email_client.send_verification_email(
 689:             to_email=user.email,
 690:             token=token,
 691:             username=user.username,
 692:             first_name=user.first_name,
 693:         )
 694:         await session.commit()
 695:         if not success:
 696:             raise HTTPException(
 697:                 status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
 698:                 detail=msg,
 699:             )
 700:         return VerificationResponse(
 701:             success=True,
 702:             message="Verification email sent",
 703:             profile_status=user.status,
 704:         )
 705:     elif request.verification_type == "phone":
 706:         if user.phone_verified:
 707:             return VerificationResponse(
 708:                 success=True,
 709:                 message="Phone already verified",
 710:                 profile_status=user.status,
 711:             )
 712:         token = await _create_verification_token(
 713:             session, user.id, "phone", expiry_hours=1
 714:         )
 715:         sms_client = _get_sms_client()
 716:         full_phone = f"{user.phone_country_code}{user.phone_number}"
 717:         success, msg, _ = sms_client.send_verification_code(full_phone, token)
 718:         await session.commit()
 719:         if not success:
 720:             raise HTTPException(
 721:                 status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
 722:                 detail=msg,
 723:             )
 724:         return VerificationResponse(
 725:             success=True,
 726:             message="Verification code sent",
 727:             profile_status=user.status,
 728:         )
 729:     else:
 730:         raise HTTPException(
 731:             status_code=status.HTTP_400_BAD_REQUEST,
 732:             detail="Invalid verification type. Use 'email' or 'phone'.",
 733:         )
 734: # ============================================================================
 735: # Profile Status
 736: # ============================================================================
 737: @router.get(
 738:     "/profile/status/{username}",
 739:     response_model=ProfileStatusResponse,
 740:     responses={404: {"description": "User not found"}},
 741: )
 742: async def get_profile_status(
 743:     username: str,
 744:     session: AsyncSession = Depends(get_async_session),
 745: ) -> ProfileStatusResponse:
 746:     """Get user's profile status."""
 747:     user = await _get_user_by_username(session, username)
 748:     if not user:
 749:         raise HTTPException(
 750:             status_code=status.HTTP_404_NOT_FOUND,
 751:             detail="User not found",
 752:         )
 753:     return ProfileStatusResponse(
 754:         username=user.username,
 755:         email=_mask_email(user.email),
 756:         phone=user.masked_phone,
 757:         status=user.status,
 758:         email_verified=user.email_verified,
 759:         phone_verified=user.phone_verified,
 760:         mfa_method=user.mfa_method,
 761:         created_at=user.created_at.isoformat(),
 762:     )
 763: # ============================================================================
 764: # MFA Methods
 765: # ============================================================================
 766: @router.get("/mfa/methods", response_model=MFAMethodsResponse)
 767: async def get_mfa_methods() -> MFAMethodsResponse:
 768:     """Get available MFA methods."""
 769:     settings = get_settings()
 770:     methods = ["totp"]
 771:     if settings.enable_sms_2fa:
 772:         methods.append("sms")
 773:     return MFAMethodsResponse(methods=methods, sms_enabled=settings.enable_sms_2fa)
 774: @router.get("/mfa/status/{username}", response_model=UserMFAStatusResponse)
 775: async def get_mfa_status(
 776:     username: str,
 777:     session: AsyncSession = Depends(get_async_session),
 778: ) -> UserMFAStatusResponse:
 779:     """Get user's MFA enrollment status."""
 780:     user = await _get_user_by_username(session, username)
 781:     if not user:
 782:         return UserMFAStatusResponse(enrolled=False)
 783:     phone_number = None
 784:     if user.mfa_method == "sms":
 785:         phone_number = user.masked_phone
 786:     return UserMFAStatusResponse(
 787:         enrolled=user.totp_secret is not None or user.mfa_method == "sms",
 788:         mfa_method=user.mfa_method,
 789:         phone_number=phone_number,
 790:     )
 791: # ============================================================================
 792: # MFA Enrollment (for re-enrollment)
 793: # ============================================================================
 794: @router.post(
 795:     "/auth/enroll",
 796:     response_model=EnrollResponse,
 797:     responses={
 798:         400: {"description": "Bad request"},
 799:         401: {"description": "Invalid credentials"},
 800:         403: {"description": "User not active"},
 801:     },
 802: )
 803: async def enroll(
 804:     request: EnrollRequest,
 805:     session: AsyncSession = Depends(get_async_session),
 806: ) -> EnrollResponse:
 807:     """
 808:     Enroll or re-enroll for MFA (for active users only).
 809:     """
 810:     settings = get_settings()
 811:     user = await _get_user_by_username(session, request.username)
 812:     if not user:
 813:         raise HTTPException(
 814:             status_code=status.HTTP_404_NOT_FOUND,
 815:             detail="User not found",
 816:         )
 817:     # Verify password
 818:     if not _verify_password(request.password, user.password_hash):
 819:         raise HTTPException(
 820:             status_code=status.HTTP_401_UNAUTHORIZED,
 821:             detail="Invalid password",
 822:         )
 823:     # Only active users can re-enroll
 824:     if user.status != ProfileStatus.ACTIVE.value:
 825:         raise HTTPException(
 826:             status_code=status.HTTP_403_FORBIDDEN,
 827:             detail="Only active users can update MFA enrollment",
 828:         )
 829:     # Validate SMS is enabled
 830:     if request.mfa_method == MFAMethod.SMS and not settings.enable_sms_2fa:
 831:         raise HTTPException(
 832:             status_code=status.HTTP_400_BAD_REQUEST,
 833:             detail="SMS 2FA is not enabled",
 834:         )
 835:     if request.mfa_method == MFAMethod.TOTP:
 836:         totp_manager = TOTPManager()
 837:         secret = totp_manager.generate_secret()
 838:         otpauth_uri = totp_manager.generate_otpauth_uri(
 839:             secret=secret,
 840:             username=user.username,
 841:         )
 842:         user.mfa_method = "totp"
 843:         user.totp_secret = secret
 844:         await session.commit()
 845:         logger.info(f"User {user.username} re-enrolled for TOTP MFA")
 846:         return EnrollResponse(
 847:             success=True,
 848:             message="MFA enrollment updated. Scan the QR code.",
 849:             mfa_method=MFAMethod.TOTP,
 850:             otpauth_uri=otpauth_uri,
 851:             secret=secret,
 852:         )
 853:     else:
 854:         # SMS enrollment
 855:         if not request.phone_number:
 856:             phone = user.full_phone_number
 857:         else:
 858:             phone = request.phone_number
 859:         sms_client = _get_sms_client()
 860:         is_valid, error = sms_client.validate_phone_number(phone)
 861:         if not is_valid:
 862:             raise HTTPException(
 863:                 status_code=status.HTTP_400_BAD_REQUEST,
 864:                 detail=error,
 865:             )
 866:         user.mfa_method = "sms"
 867:         if request.phone_number:
 868:             # Parse the new phone number
 869:             if request.phone_number.startswith("+"):
 870:                 # Extract country code (assume 1-4 digits after +)
 871:                 match = re.match(r"^(\+\d{1,4})(\d+)$", request.phone_number)
 872:                 if match:
 873:                     user.phone_country_code = match.group(1)
 874:                     user.phone_number = match.group(2)
 875:         await session.commit()
 876:         logger.info(f"User {user.username} re-enrolled for SMS MFA")
 877:         return EnrollResponse(
 878:             success=True,
 879:             message="MFA enrollment updated for SMS.",
 880:             mfa_method=MFAMethod.SMS,
 881:             phone_number=user.masked_phone,
 882:         )
 883: # ============================================================================
 884: # Login
 885: # ============================================================================
 886: @router.post(
 887:     "/auth/login",
 888:     response_model=LoginResponse,
 889:     responses={
 890:         401: {"description": "Invalid credentials"},
 891:         403: {"description": "Profile incomplete or not activated"},
 892:     },
 893: )
 894: async def login(
 895:     request: LoginRequest,
 896:     session: AsyncSession = Depends(get_async_session),
 897: ) -> LoginResponse:
 898:     """
 899:     Authenticate user with username, password, and verification code.
 900:     """
 901:     user = await _get_user_by_username(session, request.username)
 902:     # Check if user exists
 903:     if not user:
 904:         raise HTTPException(
 905:             status_code=status.HTTP_403_FORBIDDEN,
 906:             detail="User not found. Please sign up first.",
 907:         )
 908:     # Check profile status
 909:     if user.status == ProfileStatus.PENDING.value:
 910:         missing = []
 911:         if not user.email_verified:
 912:             missing.append("email")
 913:         if not user.phone_verified:
 914:             missing.append("phone")
 915:         raise HTTPException(
 916:             status_code=status.HTTP_403_FORBIDDEN,
 917:             detail=f"Profile incomplete. Please verify your: {', '.join(missing)}",
 918:         )
 919:     if user.status == ProfileStatus.COMPLETE.value:
 920:         raise HTTPException(
 921:             status_code=status.HTTP_403_FORBIDDEN,
 922:             detail="Your profile is awaiting admin approval. Please wait for activation.",
 923:         )
 924:     # Only ACTIVE users can login - verify against LDAP
 925:     ldap_client = LDAPClient()
 926:     auth_success, auth_message = ldap_client.authenticate(
 927:         request.username, request.password
 928:     )
 929:     if not auth_success:
 930:         logger.warning(f"Login failed for {request.username}: {auth_message}")
 931:         raise HTTPException(
 932:             status_code=status.HTTP_401_UNAUTHORIZED,
 933:             detail="Invalid username or password",
 934:         )
 935:     # Verify MFA code
 936:     if user.mfa_method == "totp":
 937:         if not user.totp_secret:
 938:             raise HTTPException(
 939:                 status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
 940:                 detail="TOTP not configured",
 941:             )
 942:         totp_manager = TOTPManager()
 943:         if not totp_manager.verify_totp(user.totp_secret, request.verification_code):
 944:             logger.warning(f"Login failed for {request.username}: Invalid TOTP")
 945:             raise HTTPException(
 946:                 status_code=status.HTTP_401_UNAUTHORIZED,
 947:                 detail="Invalid verification code",
 948:             )
 949:     elif user.mfa_method == "sms":
 950:         # Verify SMS code (from Redis or in-memory fallback)
 951:         otp_client = get_otp_client()
 952:         sms_code_data = None
 953:         if otp_client.is_enabled and otp_client.is_connected:
 954:             # Use Redis for OTP retrieval
 955:             sms_code_data = otp_client.get_code(request.username)
 956:             if not sms_code_data:
 957:                 raise HTTPException(
 958:                     status_code=status.HTTP_401_UNAUTHORIZED,
 959:                     detail="No verification code sent. Please request a code first.",
 960:                 )
 961:             # Redis handles TTL expiration automatically, but we still get None if expired
 962:             if not hmac.compare_digest(
 963:                 request.verification_code, sms_code_data["code"]
 964:             ):
 965:                 logger.warning(
 966:                     f"Login failed for {request.username}: Invalid SMS code"
 967:                 )
 968:                 raise HTTPException(
 969:                     status_code=status.HTTP_401_UNAUTHORIZED,
 970:                     detail="Invalid verification code",
 971:                 )
 972:             # Delete code after successful verification
 973:             otp_client.delete_code(request.username)
 974:         else:
 975:             # Fallback to in-memory storage
 976:             sms_code_data = InMemoryOTPStorage.get_code(request.username)
 977:             if not sms_code_data:
 978:                 raise HTTPException(
 979:                     status_code=status.HTTP_401_UNAUTHORIZED,
 980:                     detail="No verification code sent. Please request a code first.",
 981:                 )
 982:             if time.time() > sms_code_data["expires_at"]:
 983:                 InMemoryOTPStorage.delete_code(request.username)
 984:                 raise HTTPException(
 985:                     status_code=status.HTTP_401_UNAUTHORIZED,
 986:                     detail="Verification code expired. Please request a new one.",
 987:                 )
 988:             if not hmac.compare_digest(
 989:                 request.verification_code, sms_code_data["code"]
 990:             ):
 991:                 logger.warning(
 992:                     f"Login failed for {request.username}: Invalid SMS code"
 993:                 )
 994:                 raise HTTPException(
 995:                     status_code=status.HTTP_401_UNAUTHORIZED,
 996:                     detail="Invalid verification code",
 997:                 )
 998:             InMemoryOTPStorage.delete_code(request.username)
 999:     # Check if user is admin
1000:     is_admin = ldap_client.is_admin(request.username)
1001:     # Generate JWT token
1002:     token = _create_jwt_token(
1003:         user_id=str(user.id),
1004:         username=user.username,
1005:         is_admin=is_admin,
1006:     )
1007:     logger.info(f"User {request.username} logged in successfully")
1008:     return LoginResponse(
1009:         success=True,
1010:         message="Login successful",
1011:         is_admin=is_admin,
1012:         token=token,
1013:         username=user.username,
1014:     )
1015: @router.post(
1016:     "/auth/sms/send-code",
1017:     response_model=SMSSendCodeResponse,
1018:     responses={
1019:         401: {"description": "Invalid credentials"},
1020:         403: {"description": "User not enrolled for SMS"},
1021:     },
1022: )
1023: async def send_sms_code(
1024:     request: SMSSendCodeRequest,
1025:     session: AsyncSession = Depends(get_async_session),
1026: ) -> SMSSendCodeResponse:
1027:     """Send SMS verification code for login."""
1028:     settings = get_settings()
1029:     if not settings.enable_sms_2fa:
1030:         raise HTTPException(
1031:             status_code=status.HTTP_400_BAD_REQUEST,
1032:             detail="SMS 2FA is not enabled",
1033:         )
1034:     user = await _get_user_by_username(session, request.username)
1035:     if not user:
1036:         raise HTTPException(
1037:             status_code=status.HTTP_404_NOT_FOUND,
1038:             detail="User not found",
1039:         )
1040:     # For active users, verify against LDAP
1041:     if user.status == ProfileStatus.ACTIVE.value:
1042:         ldap_client = LDAPClient()
1043:         auth_success, _ = ldap_client.authenticate(request.username, request.password)
1044:         if not auth_success:
1045:             raise HTTPException(
1046:                 status_code=status.HTTP_401_UNAUTHORIZED,
1047:                 detail="Invalid username or password",
1048:             )
1049:     else:
1050:         # For non-active users, verify against stored password
1051:         if not _verify_password(request.password, user.password_hash):
1052:             raise HTTPException(
1053:                 status_code=status.HTTP_401_UNAUTHORIZED,
1054:                 detail="Invalid username or password",
1055:             )
1056:     if user.mfa_method != "sms":
1057:         raise HTTPException(
1058:             status_code=status.HTTP_403_FORBIDDEN,
1059:             detail="User not enrolled for SMS MFA",
1060:         )
1061:     # Generate and send code
1062:     sms_client = _get_sms_client()
1063:     code = _generate_verification_code(settings.sms_code_length)
1064:     success, message, _ = sms_client.send_verification_code(
1065:         user.full_phone_number, code
1066:     )
1067:     if not success:
1068:         raise HTTPException(
1069:             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
1070:             detail=f"Failed to send SMS: {message}",
1071:         )
1072:     # Store code for verification (Redis or in-memory fallback)
1073:     otp_client = get_otp_client()
1074:     if otp_client.is_enabled and otp_client.is_connected:
1075:         # Use Redis for OTP storage
1076:         stored = otp_client.store_code(
1077:             username=request.username,
1078:             code=code,
1079:             phone_number=user.full_phone_number,
1080:             ttl_seconds=settings.sms_code_expiry_seconds,
1081:         )
1082:         if not stored:
1083:             logger.error(f"Failed to store OTP code in Redis for {request.username}")
1084:             raise HTTPException(
1085:                 status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
1086:                 detail="Failed to store verification code. Please try again.",
1087:             )
1088:     else:
1089:         # Fallback to in-memory storage
1090:         InMemoryOTPStorage.store_code(
1091:             username=request.username,
1092:             code=code,
1093:             phone_number=user.full_phone_number,
1094:             expires_at=time.time() + settings.sms_code_expiry_seconds,
1095:         )
1096:     logger.info(f"SMS code sent to user {request.username}")
1097:     return SMSSendCodeResponse(
1098:         success=True,
1099:         message="Verification code sent",
1100:         phone_number=user.masked_phone,
1101:         expires_in_seconds=settings.sms_code_expiry_seconds,
1102:     )
1103: # ============================================================================
1104: # Admin Endpoints
1105: # ============================================================================
1106: @router.post(
1107:     "/admin/login",
1108:     response_model=LoginResponse,
1109:     responses={
1110:         401: {"description": "Invalid credentials"},
1111:         403: {"description": "Not an admin"},
1112:     },
1113: )
1114: async def admin_login(
1115:     request: LoginRequest,
1116:     session: AsyncSession = Depends(get_async_session),
1117: ) -> LoginResponse:
1118:     """Admin login - same as regular login but verifies admin status."""
1119:     # Use regular login flow
1120:     response = await login(request, session)
1121:     if not response.is_admin:
1122:         raise HTTPException(
1123:             status_code=status.HTTP_403_FORBIDDEN,
1124:             detail="Access denied. Admin privileges required.",
1125:         )
1126:     return response
1127: @router.get(
1128:     "/admin/users",
1129:     response_model=AdminUserListResponse,
1130:     responses={401: {"description": "Invalid credentials"}, 403: {"description": "Not admin"}},
1131: )
1132: async def admin_list_users(
1133:     admin_username: str,
1134:     admin_password: str,
1135:     status_filter: Optional[str] = None,
1136:     session: AsyncSession = Depends(get_async_session),
1137: ) -> AdminUserListResponse:
1138:     """List users (admin only)."""
1139:     # Verify admin credentials
1140:     ldap_client = LDAPClient()
1141:     auth_success, _ = ldap_client.authenticate(admin_username, admin_password)
1142:     if not auth_success:
1143:         raise HTTPException(
1144:             status_code=status.HTTP_401_UNAUTHORIZED,
1145:             detail="Invalid admin credentials",
1146:         )
1147:     if not ldap_client.is_admin(admin_username):
1148:         raise HTTPException(
1149:             status_code=status.HTTP_403_FORBIDDEN,
1150:             detail="Admin privileges required",
1151:         )
1152:     # Build query
1153:     query = select(User)
1154:     if status_filter:
1155:         query = query.where(User.status == status_filter)
1156:     query = query.order_by(User.created_at.desc())
1157:     result = await session.execute(query)
1158:     users = result.scalars().all()
1159:     user_list = [
1160:         {
1161:             "id": str(u.id),
1162:             "username": u.username,
1163:             "email": u.email,
1164:             "first_name": u.first_name,
1165:             "last_name": u.last_name,
1166:             "phone": u.full_phone_number,
1167:             "status": u.status,
1168:             "email_verified": u.email_verified,
1169:             "phone_verified": u.phone_verified,
1170:             "mfa_method": u.mfa_method,
1171:             "created_at": u.created_at.isoformat(),
1172:             "activated_at": u.activated_at.isoformat() if u.activated_at else None,
1173:             "activated_by": u.activated_by,
1174:         }
1175:         for u in users
1176:     ]
1177:     return AdminUserListResponse(users=user_list, total=len(user_list))
1178: @router.post(
1179:     "/admin/users/{user_id}/activate",
1180:     response_model=AdminActivateResponse,
1181:     responses={
1182:         401: {"description": "Invalid credentials"},
1183:         403: {"description": "Not admin or user not ready"},
1184:         404: {"description": "User not found"},
1185:     },
1186: )
1187: async def admin_activate_user(
1188:     user_id: str,
1189:     request: AdminActivateRequest,
1190:     session: AsyncSession = Depends(get_async_session),
1191: ) -> AdminActivateResponse:
1192:     """Activate a user (create in LDAP)."""
1193:     # Verify admin credentials
1194:     ldap_client = LDAPClient()
1195:     auth_success, _ = ldap_client.authenticate(
1196:         request.admin_username, request.admin_password
1197:     )
1198:     if not auth_success:
1199:         raise HTTPException(
1200:             status_code=status.HTTP_401_UNAUTHORIZED,
1201:             detail="Invalid admin credentials",
1202:         )
1203:     if not ldap_client.is_admin(request.admin_username):
1204:         raise HTTPException(
1205:             status_code=status.HTTP_403_FORBIDDEN,
1206:             detail="Admin privileges required",
1207:         )
1208:     # Get user
1209:     try:
1210:         user_uuid = uuid.UUID(user_id)
1211:     except ValueError:
1212:         raise HTTPException(
1213:             status_code=status.HTTP_400_BAD_REQUEST,
1214:             detail="Invalid user ID format",
1215:         )
1216:     result = await session.execute(select(User).where(User.id == user_uuid))
1217:     user = result.scalar_one_or_none()
1218:     if not user:
1219:         raise HTTPException(
1220:             status_code=status.HTTP_404_NOT_FOUND,
1221:             detail="User not found",
1222:         )
1223:     if user.status != ProfileStatus.COMPLETE.value:
1224:         raise HTTPException(
1225:             status_code=status.HTTP_403_FORBIDDEN,
1226:             detail=f"User cannot be activated. Current status: {user.status}",
1227:         )
1228:     # Create user in LDAP
1229:     # We need to get the plain password, but we only have the hash
1230:     # The admin will need to set a temporary password or we use a token-based approach
1231:     # For now, we'll generate a temporary password and require the user to reset it
1232:     temp_password = secrets.token_urlsafe(16)
1233:     success, message = ldap_client.create_user(
1234:         username=user.username,
1235:         password=temp_password,
1236:         first_name=user.first_name,
1237:         last_name=user.last_name,
1238:         email=user.email,
1239:     )
1240:     if not success:
1241:         raise HTTPException(
1242:             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
1243:             detail=f"Failed to create LDAP user: {message}",
1244:         )
1245:     # Update user status
1246:     user.status = ProfileStatus.ACTIVE.value
1247:     user.activated_at = datetime.now(timezone.utc)
1248:     user.activated_by = request.admin_username
1249:     # Update password hash to match the temp password (user will use this until LDAP password reset)
1250:     user.password_hash = _hash_password(temp_password)
1251:     await session.commit()
1252:     # Send welcome email
1253:     try:
1254:         email_client = EmailClient()
1255:         email_client.send_welcome_email(
1256:             to_email=user.email,
1257:             username=user.username,
1258:             first_name=user.first_name,
1259:         )
1260:     except Exception as e:
1261:         logger.error(f"Failed to send welcome email: {e}")
1262:     logger.info(f"User {user.username} activated by {request.admin_username}")
1263:     return AdminActivateResponse(
1264:         success=True,
1265:         message=f"User {user.username} activated successfully. A temporary password has been set.",
1266:     )
1267: @router.post(
1268:     "/admin/users/{user_id}/reject",
1269:     response_model=AdminActivateResponse,
1270:     responses={
1271:         401: {"description": "Invalid credentials"},
1272:         403: {"description": "Not admin"},
1273:         404: {"description": "User not found"},
1274:     },
1275: )
1276: async def admin_reject_user(
1277:     user_id: str,
1278:     request: AdminActivateRequest,
1279:     session: AsyncSession = Depends(get_async_session),
1280: ) -> AdminActivateResponse:
1281:     """Reject and delete a user."""
1282:     # Verify admin credentials
1283:     ldap_client = LDAPClient()
1284:     auth_success, _ = ldap_client.authenticate(
1285:         request.admin_username, request.admin_password
1286:     )
1287:     if not auth_success:
1288:         raise HTTPException(
1289:             status_code=status.HTTP_401_UNAUTHORIZED,
1290:             detail="Invalid admin credentials",
1291:         )
1292:     if not ldap_client.is_admin(request.admin_username):
1293:         raise HTTPException(
1294:             status_code=status.HTTP_403_FORBIDDEN,
1295:             detail="Admin privileges required",
1296:         )
1297:     # Get user
1298:     try:
1299:         user_uuid = uuid.UUID(user_id)
1300:     except ValueError:
1301:         raise HTTPException(
1302:             status_code=status.HTTP_400_BAD_REQUEST,
1303:             detail="Invalid user ID format",
1304:         )
1305:     result = await session.execute(select(User).where(User.id == user_uuid))
1306:     user = result.scalar_one_or_none()
1307:     if not user:
1308:         raise HTTPException(
1309:             status_code=status.HTTP_404_NOT_FOUND,
1310:             detail="User not found",
1311:         )
1312:     username = user.username
1313:     await session.delete(user)
1314:     await session.commit()
1315:     logger.info(f"User {username} rejected/deleted by {request.admin_username}")
1316:     return AdminActivateResponse(
1317:         success=True,
1318:         message=f"User {username} has been rejected and removed.",
1319:     )
1320: # ============================================================================
1321: # Profile Endpoints
1322: # ============================================================================
1323: @router.get(
1324:     "/profile/{username}",
1325:     response_model=ProfileResponse,
1326:     responses={
1327:         401: {"description": "Not authenticated"},
1328:         403: {"description": "Not authorized"},
1329:         404: {"description": "User not found"},
1330:     },
1331: )
1332: async def get_profile(
1333:     username: str,
1334:     authorization: Optional[str] = Header(None),
1335:     session: AsyncSession = Depends(get_async_session),
1336: ) -> ProfileResponse:
1337:     """Get user profile. Users can only view their own profile unless admin."""
1338:     current = await _get_current_user(authorization, session)
1339:     # Check authorization - users can only view their own profile
1340:     if current["username"] != username.lower() and not current["is_admin"]:
1341:         raise HTTPException(
1342:             status_code=status.HTTP_403_FORBIDDEN,
1343:             detail="You can only view your own profile",
1344:         )
1345:     user = await _get_user_by_username(session, username)
1346:     if not user:
1347:         raise HTTPException(
1348:             status_code=status.HTTP_404_NOT_FOUND,
1349:             detail="User not found",
1350:         )
1351:     # Get user's groups
1352:     result = await session.execute(
1353:         select(UserGroup).where(UserGroup.user_id == user.id).options(
1354:             selectinload(UserGroup.group)
1355:         )
1356:     )
1357:     user_groups = result.scalars().all()
1358:     groups = [
1359:         {"id": str(ug.group_id), "name": ug.group.name}
1360:         for ug in user_groups if ug.group
1361:     ]
1362:     return ProfileResponse(
1363:         id=str(user.id),
1364:         username=user.username,
1365:         email=user.email,
1366:         first_name=user.first_name,
1367:         last_name=user.last_name,
1368:         phone_country_code=user.phone_country_code,
1369:         phone_number=user.phone_number,
1370:         email_verified=user.email_verified,
1371:         phone_verified=user.phone_verified,
1372:         mfa_method=user.mfa_method,
1373:         status=user.status,
1374:         created_at=user.created_at.isoformat() if user.created_at else "",
1375:         groups=groups,
1376:     )
1377: @router.put(
1378:     "/profile/{username}",
1379:     response_model=ProfileResponse,
1380:     responses={
1381:         401: {"description": "Not authenticated"},
1382:         403: {"description": "Not authorized or field not editable"},
1383:         404: {"description": "User not found"},
1384:     },
1385: )
1386: async def update_profile(
1387:     username: str,
1388:     request: ProfileUpdateRequest,
1389:     authorization: Optional[str] = Header(None),
1390:     session: AsyncSession = Depends(get_async_session),
1391: ) -> ProfileResponse:
1392:     """
1393:     Update user profile.
1394:     - Users can only update their own profile
1395:     - Email can only be changed if not verified
1396:     - Phone can only be changed if not verified
1397:     """
1398:     current = await _get_current_user(authorization, session)
1399:     # Check authorization - users can only update their own profile
1400:     if current["username"] != username.lower():
1401:         raise HTTPException(
1402:             status_code=status.HTTP_403_FORBIDDEN,
1403:             detail="You can only update your own profile",
1404:         )
1405:     user = await _get_user_by_username(session, username)
1406:     if not user:
1407:         raise HTTPException(
1408:             status_code=status.HTTP_404_NOT_FOUND,
1409:             detail="User not found",
1410:         )
1411:     # Update allowed fields
1412:     if request.first_name is not None:
1413:         user.first_name = request.first_name
1414:     if request.last_name is not None:
1415:         user.last_name = request.last_name
1416:     # Email can only be changed if not verified
1417:     if request.email is not None:
1418:         if user.email_verified:
1419:             raise HTTPException(
1420:                 status_code=status.HTTP_403_FORBIDDEN,
1421:                 detail="Email cannot be changed after verification",
1422:             )
1423:         # Check if email is already taken
1424:         existing = await _get_user_by_email(session, request.email)
1425:         if existing and existing.id != user.id:
1426:             raise HTTPException(
1427:                 status_code=status.HTTP_400_BAD_REQUEST,
1428:                 detail="Email already in use",
1429:             )
1430:         user.email = request.email.lower()
1431:     # Phone can only be changed if not verified
1432:     if request.phone_country_code is not None or request.phone_number is not None:
1433:         if user.phone_verified:
1434:             raise HTTPException(
1435:                 status_code=status.HTTP_403_FORBIDDEN,
1436:                 detail="Phone cannot be changed after verification",
1437:             )
1438:         if request.phone_country_code is not None:
1439:             user.phone_country_code = request.phone_country_code
1440:         if request.phone_number is not None:
1441:             user.phone_number = request.phone_number
1442:     await session.commit()
1443:     # Get user's groups for response
1444:     result = await session.execute(
1445:         select(UserGroup).where(UserGroup.user_id == user.id).options(
1446:             selectinload(UserGroup.group)
1447:         )
1448:     )
1449:     user_groups = result.scalars().all()
1450:     groups = [
1451:         {"id": str(ug.group_id), "name": ug.group.name}
1452:         for ug in user_groups if ug.group
1453:     ]
1454:     logger.info(f"Profile updated for user {username}")
1455:     return ProfileResponse(
1456:         id=str(user.id),
1457:         username=user.username,
1458:         email=user.email,
1459:         first_name=user.first_name,
1460:         last_name=user.last_name,
1461:         phone_country_code=user.phone_country_code,
1462:         phone_number=user.phone_number,
1463:         email_verified=user.email_verified,
1464:         phone_verified=user.phone_verified,
1465:         mfa_method=user.mfa_method,
1466:         status=user.status,
1467:         created_at=user.created_at.isoformat() if user.created_at else "",
1468:         groups=groups,
1469:     )
1470: # ============================================================================
1471: # Group Management Endpoints (Admin)
1472: # ============================================================================
1473: @router.get(
1474:     "/admin/groups",
1475:     response_model=GroupListResponse,
1476:     responses={401: {"description": "Not authenticated"}, 403: {"description": "Not admin"}},
1477: )
1478: async def admin_list_groups(
1479:     search: Optional[str] = Query(None, description="Search term"),
1480:     sort_by: Optional[str] = Query("name", description="Sort field"),
1481:     sort_order: Optional[str] = Query("asc", description="Sort order"),
1482:     authorization: Optional[str] = Header(None),
1483:     session: AsyncSession = Depends(get_async_session),
1484: ) -> GroupListResponse:
1485:     """List all groups (admin only)."""
1486:     await _require_admin(authorization, session)
1487:     query = select(Group)
1488:     # Apply search
1489:     if search:
1490:         search_term = f"%{search}%"
1491:         query = query.where(
1492:             or_(
1493:                 Group.name.ilike(search_term),
1494:                 Group.description.ilike(search_term),
1495:             )
1496:         )
1497:     # Apply sorting
1498:     if sort_by == "name":
1499:         order_col = Group.name
1500:     elif sort_by == "created_at":
1501:         order_col = Group.created_at
1502:     else:
1503:         order_col = Group.name
1504:     if sort_order == "desc":
1505:         query = query.order_by(order_col.desc())
1506:     else:
1507:         query = query.order_by(order_col.asc())
1508:     result = await session.execute(query.options(selectinload(Group.user_groups)))
1509:     groups = result.scalars().all()
1510:     group_list = [
1511:         GroupResponse(
1512:             id=str(g.id),
1513:             name=g.name,
1514:             description=g.description,
1515:             ldap_dn=g.ldap_dn,
1516:             member_count=len(g.user_groups) if g.user_groups else 0,
1517:             created_at=g.created_at.isoformat() if g.created_at else "",
1518:         )
1519:         for g in groups
1520:     ]
1521:     return GroupListResponse(groups=group_list, total=len(group_list))
1522: @router.post(
1523:     "/admin/groups",
1524:     response_model=GroupResponse,
1525:     responses={
1526:         401: {"description": "Not authenticated"},
1527:         403: {"description": "Not admin"},
1528:         400: {"description": "Group already exists"},
1529:     },
1530: )
1531: async def admin_create_group(
1532:     request: GroupCreateRequest,
1533:     authorization: Optional[str] = Header(None),
1534:     session: AsyncSession = Depends(get_async_session),
1535: ) -> GroupResponse:
1536:     """Create a new group (admin only)."""
1537:     await _require_admin(authorization, session)
1538:     # Check if group name exists
1539:     existing = await session.execute(
1540:         select(Group).where(Group.name == request.name)
1541:     )
1542:     if existing.scalar_one_or_none():
1543:         raise HTTPException(
1544:             status_code=status.HTTP_400_BAD_REQUEST,
1545:             detail="Group name already exists",
1546:         )
1547:     # Create LDAP group
1548:     ldap_client = LDAPClient()
1549:     success, message, ldap_dn = ldap_client.create_group(
1550:         name=request.name,
1551:         description=request.description or "",
1552:     )
1553:     if not success:
1554:         raise HTTPException(
1555:             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
1556:             detail=f"Failed to create LDAP group: {message}",
1557:         )
1558:     # Create database record
1559:     group = Group(
1560:         name=request.name,
1561:         description=request.description,
1562:         ldap_dn=ldap_dn,
1563:     )
1564:     session.add(group)
1565:     await session.commit()
1566:     logger.info(f"Group {request.name} created")
1567:     return GroupResponse(
1568:         id=str(group.id),
1569:         name=group.name,
1570:         description=group.description,
1571:         ldap_dn=group.ldap_dn,
1572:         member_count=0,
1573:         created_at=group.created_at.isoformat() if group.created_at else "",
1574:     )
1575: @router.get(
1576:     "/admin/groups/{group_id}",
1577:     response_model=GroupDetailResponse,
1578:     responses={
1579:         401: {"description": "Not authenticated"},
1580:         403: {"description": "Not admin"},
1581:         404: {"description": "Group not found"},
1582:     },
1583: )
1584: async def admin_get_group(
1585:     group_id: str,
1586:     authorization: Optional[str] = Header(None),
1587:     session: AsyncSession = Depends(get_async_session),
1588: ) -> GroupDetailResponse:
1589:     """Get group details (admin only)."""
1590:     await _require_admin(authorization, session)
1591:     try:
1592:         group_uuid = uuid.UUID(group_id)
1593:     except ValueError:
1594:         raise HTTPException(
1595:             status_code=status.HTTP_400_BAD_REQUEST,
1596:             detail="Invalid group ID format",
1597:         )
1598:     result = await session.execute(
1599:         select(Group).where(Group.id == group_uuid).options(
1600:             selectinload(Group.user_groups).selectinload(UserGroup.user)
1601:         )
1602:     )
1603:     group = result.scalar_one_or_none()
1604:     if not group:
1605:         raise HTTPException(
1606:             status_code=status.HTTP_404_NOT_FOUND,
1607:             detail="Group not found",
1608:         )
1609:     members = [
1610:         {
1611:             "id": str(ug.user.id),
1612:             "username": ug.user.username,
1613:             "full_name": ug.user.full_name,
1614:             "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
1615:             "assigned_by": ug.assigned_by,
1616:         }
1617:         for ug in group.user_groups if ug.user
1618:     ]
1619:     return GroupDetailResponse(
1620:         id=str(group.id),
1621:         name=group.name,
1622:         description=group.description,
1623:         ldap_dn=group.ldap_dn,
1624:         member_count=len(members),
1625:         created_at=group.created_at.isoformat() if group.created_at else "",
1626:         members=members,
1627:     )
1628: @router.put(
1629:     "/admin/groups/{group_id}",
1630:     response_model=GroupResponse,
1631:     responses={
1632:         401: {"description": "Not authenticated"},
1633:         403: {"description": "Not admin"},
1634:         404: {"description": "Group not found"},
1635:     },
1636: )
1637: async def admin_update_group(
1638:     group_id: str,
1639:     request: GroupUpdateRequest,
1640:     authorization: Optional[str] = Header(None),
1641:     session: AsyncSession = Depends(get_async_session),
1642: ) -> GroupResponse:
1643:     """Update a group (admin only)."""
1644:     await _require_admin(authorization, session)
1645:     try:
1646:         group_uuid = uuid.UUID(group_id)
1647:     except ValueError:
1648:         raise HTTPException(
1649:             status_code=status.HTTP_400_BAD_REQUEST,
1650:             detail="Invalid group ID format",
1651:         )
1652:     result = await session.execute(
1653:         select(Group).where(Group.id == group_uuid).options(
1654:             selectinload(Group.user_groups)
1655:         )
1656:     )
1657:     group = result.scalar_one_or_none()
1658:     if not group:
1659:         raise HTTPException(
1660:             status_code=status.HTTP_404_NOT_FOUND,
1661:             detail="Group not found",
1662:         )
1663:     # Update LDAP group
1664:     if request.description is not None:
1665:         ldap_client = LDAPClient()
1666:         success, message = ldap_client.update_group(
1667:             group_dn=group.ldap_dn,
1668:             description=request.description,
1669:         )
1670:         if not success:
1671:             logger.warning(f"Failed to update LDAP group: {message}")
1672:     # Update database
1673:     if request.name is not None:
1674:         # Check if name already exists
1675:         existing = await session.execute(
1676:             select(Group).where(Group.name == request.name, Group.id != group_uuid)
1677:         )
1678:         if existing.scalar_one_or_none():
1679:             raise HTTPException(
1680:                 status_code=status.HTTP_400_BAD_REQUEST,
1681:                 detail="Group name already exists",
1682:             )
1683:         group.name = request.name
1684:     if request.description is not None:
1685:         group.description = request.description
1686:     await session.commit()
1687:     logger.info(f"Group {group.name} updated")
1688:     return GroupResponse(
1689:         id=str(group.id),
1690:         name=group.name,
1691:         description=group.description,
1692:         ldap_dn=group.ldap_dn,
1693:         member_count=len(group.user_groups) if group.user_groups else 0,
1694:         created_at=group.created_at.isoformat() if group.created_at else "",
1695:     )
1696: @router.delete(
1697:     "/admin/groups/{group_id}",
1698:     response_model=AdminActivateResponse,
1699:     responses={
1700:         401: {"description": "Not authenticated"},
1701:         403: {"description": "Not admin"},
1702:         404: {"description": "Group not found"},
1703:     },
1704: )
1705: async def admin_delete_group(
1706:     group_id: str,
1707:     authorization: Optional[str] = Header(None),
1708:     session: AsyncSession = Depends(get_async_session),
1709: ) -> AdminActivateResponse:
1710:     """Delete a group (admin only)."""
1711:     await _require_admin(authorization, session)
1712:     try:
1713:         group_uuid = uuid.UUID(group_id)
1714:     except ValueError:
1715:         raise HTTPException(
1716:             status_code=status.HTTP_400_BAD_REQUEST,
1717:             detail="Invalid group ID format",
1718:         )
1719:     result = await session.execute(select(Group).where(Group.id == group_uuid))
1720:     group = result.scalar_one_or_none()
1721:     if not group:
1722:         raise HTTPException(
1723:             status_code=status.HTTP_404_NOT_FOUND,
1724:             detail="Group not found",
1725:         )
1726:     group_name = group.name
1727:     ldap_dn = group.ldap_dn
1728:     # Delete from LDAP
1729:     ldap_client = LDAPClient()
1730:     success, message = ldap_client.delete_group(ldap_dn)
1731:     if not success:
1732:         logger.warning(f"Failed to delete LDAP group: {message}")
1733:     # Delete from database (cascades to user_groups)
1734:     await session.delete(group)
1735:     await session.commit()
1736:     logger.info(f"Group {group_name} deleted")
1737:     return AdminActivateResponse(
1738:         success=True,
1739:         message=f"Group {group_name} deleted successfully",
1740:     )
1741: # ============================================================================
1742: # User-Group Assignment Endpoints (Admin)
1743: # ============================================================================
1744: @router.get(
1745:     "/admin/users/{user_id}/groups",
1746:     response_model=UserGroupResponse,
1747:     responses={
1748:         401: {"description": "Not authenticated"},
1749:         403: {"description": "Not admin"},
1750:         404: {"description": "User not found"},
1751:     },
1752: )
1753: async def admin_get_user_groups(
1754:     user_id: str,
1755:     authorization: Optional[str] = Header(None),
1756:     session: AsyncSession = Depends(get_async_session),
1757: ) -> UserGroupResponse:
1758:     """Get user's group assignments (admin only)."""
1759:     await _require_admin(authorization, session)
1760:     try:
1761:         user_uuid = uuid.UUID(user_id)
1762:     except ValueError:
1763:         raise HTTPException(
1764:             status_code=status.HTTP_400_BAD_REQUEST,
1765:             detail="Invalid user ID format",
1766:         )
1767:     result = await session.execute(
1768:         select(User).where(User.id == user_uuid)
1769:     )
1770:     user = result.scalar_one_or_none()
1771:     if not user:
1772:         raise HTTPException(
1773:             status_code=status.HTTP_404_NOT_FOUND,
1774:             detail="User not found",
1775:         )
1776:     # Get user's groups
1777:     result = await session.execute(
1778:         select(UserGroup).where(UserGroup.user_id == user_uuid).options(
1779:             selectinload(UserGroup.group)
1780:         )
1781:     )
1782:     user_groups = result.scalars().all()
1783:     groups = [
1784:         {
1785:             "id": str(ug.group_id),
1786:             "name": ug.group.name if ug.group else "",
1787:             "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
1788:             "assigned_by": ug.assigned_by,
1789:         }
1790:         for ug in user_groups
1791:     ]
1792:     return UserGroupResponse(
1793:         user_id=str(user.id),
1794:         username=user.username,
1795:         groups=groups,
1796:     )
1797: @router.post(
1798:     "/admin/users/{user_id}/groups",
1799:     response_model=UserGroupResponse,
1800:     responses={
1801:         401: {"description": "Not authenticated"},
1802:         403: {"description": "Not admin"},
1803:         404: {"description": "User or group not found"},
1804:     },
1805: )
1806: async def admin_assign_user_groups(
1807:     user_id: str,
1808:     request: UserGroupAssignRequest,
1809:     authorization: Optional[str] = Header(None),
1810:     session: AsyncSession = Depends(get_async_session),
1811: ) -> UserGroupResponse:
1812:     """Assign user to groups (admin only). Adds to existing assignments."""
1813:     current = await _require_admin(authorization, session)
1814:     try:
1815:         user_uuid = uuid.UUID(user_id)
1816:     except ValueError:
1817:         raise HTTPException(
1818:             status_code=status.HTTP_400_BAD_REQUEST,
1819:             detail="Invalid user ID format",
1820:         )
1821:     result = await session.execute(select(User).where(User.id == user_uuid))
1822:     user = result.scalar_one_or_none()
1823:     if not user:
1824:         raise HTTPException(
1825:             status_code=status.HTTP_404_NOT_FOUND,
1826:             detail="User not found",
1827:         )
1828:     ldap_client = LDAPClient()
1829:     for group_id in request.group_ids:
1830:         try:
1831:             group_uuid = uuid.UUID(group_id)
1832:         except ValueError:
1833:             continue
1834:         # Get group
1835:         result = await session.execute(select(Group).where(Group.id == group_uuid))
1836:         group = result.scalar_one_or_none()
1837:         if not group:
1838:             continue
1839:         # Check if already assigned
1840:         result = await session.execute(
1841:             select(UserGroup).where(
1842:                 UserGroup.user_id == user_uuid,
1843:                 UserGroup.group_id == group_uuid,
1844:             )
1845:         )
1846:         if result.scalar_one_or_none():
1847:             continue
1848:         # Add to LDAP group (only for active users)
1849:         if user.status == ProfileStatus.ACTIVE.value:
1850:             success, msg = ldap_client.add_user_to_group(user.username, group.ldap_dn)
1851:             if not success:
1852:                 logger.warning(f"Failed to add {user.username} to LDAP group: {msg}")
1853:         # Add database assignment
1854:         user_group = UserGroup(
1855:             user_id=user_uuid,
1856:             group_id=group_uuid,
1857:             assigned_by=current["username"],
1858:         )
1859:         session.add(user_group)
1860:     await session.commit()
1861:     # Return updated groups
1862:     result = await session.execute(
1863:         select(UserGroup).where(UserGroup.user_id == user_uuid).options(
1864:             selectinload(UserGroup.group)
1865:         )
1866:     )
1867:     user_groups = result.scalars().all()
1868:     groups = [
1869:         {
1870:             "id": str(ug.group_id),
1871:             "name": ug.group.name if ug.group else "",
1872:             "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
1873:             "assigned_by": ug.assigned_by,
1874:         }
1875:         for ug in user_groups
1876:     ]
1877:     logger.info(f"Groups assigned to user {user.username}")
1878:     return UserGroupResponse(
1879:         user_id=str(user.id),
1880:         username=user.username,
1881:         groups=groups,
1882:     )
1883: @router.put(
1884:     "/admin/users/{user_id}/groups",
1885:     response_model=UserGroupResponse,
1886:     responses={
1887:         401: {"description": "Not authenticated"},
1888:         403: {"description": "Not admin"},
1889:         404: {"description": "User not found"},
1890:     },
1891: )
1892: async def admin_replace_user_groups(
1893:     user_id: str,
1894:     request: UserGroupAssignRequest,
1895:     authorization: Optional[str] = Header(None),
1896:     session: AsyncSession = Depends(get_async_session),
1897: ) -> UserGroupResponse:
1898:     """Replace all user's group assignments (admin only)."""
1899:     current = await _require_admin(authorization, session)
1900:     try:
1901:         user_uuid = uuid.UUID(user_id)
1902:     except ValueError:
1903:         raise HTTPException(
1904:             status_code=status.HTTP_400_BAD_REQUEST,
1905:             detail="Invalid user ID format",
1906:         )
1907:     result = await session.execute(select(User).where(User.id == user_uuid))
1908:     user = result.scalar_one_or_none()
1909:     if not user:
1910:         raise HTTPException(
1911:             status_code=status.HTTP_404_NOT_FOUND,
1912:             detail="User not found",
1913:         )
1914:     ldap_client = LDAPClient()
1915:     # Get current assignments
1916:     result = await session.execute(
1917:         select(UserGroup).where(UserGroup.user_id == user_uuid).options(
1918:             selectinload(UserGroup.group)
1919:         )
1920:     )
1921:     current_assignments = result.scalars().all()
1922:     # Remove from LDAP groups (for active users)
1923:     if user.status == ProfileStatus.ACTIVE.value:
1924:         for ug in current_assignments:
1925:             if ug.group:
1926:                 ldap_client.remove_user_from_group(user.username, ug.group.ldap_dn)
1927:     # Delete all current assignments
1928:     for ug in current_assignments:
1929:         await session.delete(ug)
1930:     # Add new assignments
1931:     for group_id in request.group_ids:
1932:         try:
1933:             group_uuid = uuid.UUID(group_id)
1934:         except ValueError:
1935:             continue
1936:         result = await session.execute(select(Group).where(Group.id == group_uuid))
1937:         group = result.scalar_one_or_none()
1938:         if not group:
1939:             continue
1940:         # Add to LDAP group (for active users)
1941:         if user.status == ProfileStatus.ACTIVE.value:
1942:             ldap_client.add_user_to_group(user.username, group.ldap_dn)
1943:         user_group = UserGroup(
1944:             user_id=user_uuid,
1945:             group_id=group_uuid,
1946:             assigned_by=current["username"],
1947:         )
1948:         session.add(user_group)
1949:     await session.commit()
1950:     # Return updated groups
1951:     result = await session.execute(
1952:         select(UserGroup).where(UserGroup.user_id == user_uuid).options(
1953:             selectinload(UserGroup.group)
1954:         )
1955:     )
1956:     user_groups = result.scalars().all()
1957:     groups = [
1958:         {
1959:             "id": str(ug.group_id),
1960:             "name": ug.group.name if ug.group else "",
1961:             "assigned_at": ug.assigned_at.isoformat() if ug.assigned_at else "",
1962:             "assigned_by": ug.assigned_by,
1963:         }
1964:         for ug in user_groups
1965:     ]
1966:     logger.info(f"Groups replaced for user {user.username}")
1967:     return UserGroupResponse(
1968:         user_id=str(user.id),
1969:         username=user.username,
1970:         groups=groups,
1971:     )
1972: @router.delete(
1973:     "/admin/users/{user_id}/groups/{group_id}",
1974:     response_model=AdminActivateResponse,
1975:     responses={
1976:         401: {"description": "Not authenticated"},
1977:         403: {"description": "Not admin"},
1978:         404: {"description": "User or assignment not found"},
1979:     },
1980: )
1981: async def admin_remove_user_from_group(
1982:     user_id: str,
1983:     group_id: str,
1984:     authorization: Optional[str] = Header(None),
1985:     session: AsyncSession = Depends(get_async_session),
1986: ) -> AdminActivateResponse:
1987:     """Remove user from a specific group (admin only)."""
1988:     await _require_admin(authorization, session)
1989:     try:
1990:         user_uuid = uuid.UUID(user_id)
1991:         group_uuid = uuid.UUID(group_id)
1992:     except ValueError:
1993:         raise HTTPException(
1994:             status_code=status.HTTP_400_BAD_REQUEST,
1995:             detail="Invalid ID format",
1996:         )
1997:     # Get user
1998:     result = await session.execute(select(User).where(User.id == user_uuid))
1999:     user = result.scalar_one_or_none()
2000:     if not user:
2001:         raise HTTPException(
2002:             status_code=status.HTTP_404_NOT_FOUND,
2003:             detail="User not found",
2004:         )
2005:     # Get assignment
2006:     result = await session.execute(
2007:         select(UserGroup).where(
2008:             UserGroup.user_id == user_uuid,
2009:             UserGroup.group_id == group_uuid,
2010:         ).options(selectinload(UserGroup.group))
2011:     )
2012:     user_group = result.scalar_one_or_none()
2013:     if not user_group:
2014:         raise HTTPException(
2015:             status_code=status.HTTP_404_NOT_FOUND,
2016:             detail="User is not assigned to this group",
2017:         )
2018:     # Remove from LDAP (for active users)
2019:     if user.status == ProfileStatus.ACTIVE.value and user_group.group:
2020:         ldap_client = LDAPClient()
2021:         ldap_client.remove_user_from_group(user.username, user_group.group.ldap_dn)
2022:     group_name = user_group.group.name if user_group.group else "Unknown"
2023:     await session.delete(user_group)
2024:     await session.commit()
2025:     logger.info(f"User {user.username} removed from group {group_name}")
2026:     return AdminActivateResponse(
2027:         success=True,
2028:         message=f"User removed from group {group_name}",
2029:     )
2030: # ============================================================================
2031: # User Revoke Endpoint (Admin)
2032: # ============================================================================
2033: @router.post(
2034:     "/admin/users/{user_id}/revoke",
2035:     response_model=AdminActivateResponse,
2036:     responses={
2037:         401: {"description": "Not authenticated"},
2038:         403: {"description": "Not admin or user not active"},
2039:         404: {"description": "User not found"},
2040:     },
2041: )
2042: async def admin_revoke_user(
2043:     user_id: str,
2044:     authorization: Optional[str] = Header(None),
2045:     session: AsyncSession = Depends(get_async_session),
2046: ) -> AdminActivateResponse:
2047:     """
2048:     Revoke an active user.
2049:     - Removes user from all LDAP groups
2050:     - Deletes user from LDAP
2051:     - Updates status to REVOKED
2052:     """
2053:     current = await _require_admin(authorization, session)
2054:     try:
2055:         user_uuid = uuid.UUID(user_id)
2056:     except ValueError:
2057:         raise HTTPException(
2058:             status_code=status.HTTP_400_BAD_REQUEST,
2059:             detail="Invalid user ID format",
2060:         )
2061:     result = await session.execute(
2062:         select(User).where(User.id == user_uuid).options(
2063:             selectinload(User.user_groups).selectinload(UserGroup.group)
2064:         )
2065:     )
2066:     user = result.scalar_one_or_none()
2067:     if not user:
2068:         raise HTTPException(
2069:             status_code=status.HTTP_404_NOT_FOUND,
2070:             detail="User not found",
2071:         )
2072:     if user.status != ProfileStatus.ACTIVE.value:
2073:         raise HTTPException(
2074:             status_code=status.HTTP_403_FORBIDDEN,
2075:             detail="Only active users can be revoked",
2076:         )
2077:     ldap_client = LDAPClient()
2078:     # Remove from all LDAP groups
2079:     for ug in user.user_groups:
2080:         if ug.group:
2081:             success, msg = ldap_client.remove_user_from_group(
2082:                 user.username, ug.group.ldap_dn
2083:             )
2084:             if not success:
2085:                 logger.warning(f"Failed to remove {user.username} from LDAP group: {msg}")
2086:     # Delete from LDAP
2087:     success, message = ldap_client.delete_user(user.username)
2088:     if not success:
2089:         logger.warning(f"Failed to delete LDAP user: {message}")
2090:     # Update status to revoked
2091:     user.status = ProfileStatus.REVOKED.value
2092:     # Remove all group assignments from database
2093:     for ug in user.user_groups:
2094:         await session.delete(ug)
2095:     await session.commit()
2096:     logger.info(f"User {user.username} revoked by {current['username']}")
2097:     return AdminActivateResponse(
2098:         success=True,
2099:         message=f"User {user.username} has been revoked",
2100:     )
2101: # ============================================================================
2102: # Enhanced Admin User List with Sorting/Filtering/Search
2103: # ============================================================================
2104: @router.get(
2105:     "/admin/users/enhanced",
2106:     response_model=AdminUserListResponse,
2107:     responses={401: {"description": "Not authenticated"}, 403: {"description": "Not admin"}},
2108: )
2109: async def admin_list_users_enhanced(
2110:     status_filter: Optional[str] = Query(None, description="Filter by status"),
2111:     group_filter: Optional[str] = Query(None, description="Filter by group ID"),
2112:     search: Optional[str] = Query(None, description="Search term"),
2113:     sort_by: Optional[str] = Query("created_at", description="Sort field"),
2114:     sort_order: Optional[str] = Query("desc", description="Sort order"),
2115:     authorization: Optional[str] = Header(None),
2116:     session: AsyncSession = Depends(get_async_session),
2117: ) -> AdminUserListResponse:
2118:     """List users with sorting, filtering, and search (admin only)."""
2119:     await _require_admin(authorization, session)
2120:     query = select(User).options(
2121:         selectinload(User.user_groups).selectinload(UserGroup.group)
2122:     )
2123:     # Apply status filter
2124:     if status_filter:
2125:         query = query.where(User.status == status_filter)
2126:     # Apply search
2127:     if search:
2128:         search_term = f"%{search}%"
2129:         query = query.where(
2130:             or_(
2131:                 User.username.ilike(search_term),
2132:                 User.email.ilike(search_term),
2133:                 User.first_name.ilike(search_term),
2134:                 User.last_name.ilike(search_term),
2135:             )
2136:         )
2137:     # Apply sorting
2138:     if sort_by == "username":
2139:         order_col = User.username
2140:     elif sort_by == "email":
2141:         order_col = User.email
2142:     elif sort_by == "first_name":
2143:         order_col = User.first_name
2144:     elif sort_by == "status":
2145:         order_col = User.status
2146:     else:
2147:         order_col = User.created_at
2148:     if sort_order == "asc":
2149:         query = query.order_by(order_col.asc())
2150:     else:
2151:         query = query.order_by(order_col.desc())
2152:     result = await session.execute(query)
2153:     users = result.scalars().all()
2154:     # Filter by group if specified
2155:     if group_filter:
2156:         try:
2157:             group_uuid = uuid.UUID(group_filter)
2158:             users = [
2159:                 u for u in users
2160:                 if any(ug.group_id == group_uuid for ug in u.user_groups)
2161:             ]
2162:         except ValueError:
2163:             pass
2164:     user_list = [
2165:         {
2166:             "id": str(u.id),
2167:             "username": u.username,
2168:             "email": u.email,
2169:             "first_name": u.first_name,
2170:             "last_name": u.last_name,
2171:             "phone": u.full_phone_number,
2172:             "status": u.status,
2173:             "email_verified": u.email_verified,
2174:             "phone_verified": u.phone_verified,
2175:             "mfa_method": u.mfa_method,
2176:             "created_at": u.created_at.isoformat() if u.created_at else "",
2177:             "activated_at": u.activated_at.isoformat() if u.activated_at else None,
2178:             "activated_by": u.activated_by,
2179:             "groups": [
2180:                 {"id": str(ug.group_id), "name": ug.group.name if ug.group else ""}
2181:                 for ug in u.user_groups
2182:             ],
2183:         }
2184:         for u in users
2185:     ]
2186:     return AdminUserListResponse(users=user_list, total=len(user_list))
```

## File: application/backend/src/app/config.py
```python
 1: """Configuration module for the 2FA Backend API."""
 2: import os
 3: from functools import lru_cache
 4: from pydantic_settings import BaseSettings
 5: class Settings(BaseSettings):
 6:     """Application settings loaded from environment variables."""
 7:     # LDAP Configuration
 8:     ldap_host: str = os.getenv("LDAP_HOST", "openldap-stack-ha.ldap.svc.cluster.local")
 9:     ldap_port: int = int(os.getenv("LDAP_PORT", "389"))
10:     ldap_use_ssl: bool = os.getenv("LDAP_USE_SSL", "false").lower() == "true"
11:     ldap_base_dn: str = os.getenv("LDAP_BASE_DN", "dc=ldap,dc=talorlik,dc=internal")
12:     ldap_admin_dn: str = os.getenv(
13:         "LDAP_ADMIN_DN", "cn=admin,dc=ldap,dc=talorlik,dc=internal"
14:     )
15:     ldap_admin_password: str = os.getenv("LDAP_ADMIN_PASSWORD", "")
16:     ldap_user_search_base: str = os.getenv("LDAP_USER_SEARCH_BASE", "ou=users")
17:     ldap_user_search_filter: str = os.getenv("LDAP_USER_SEARCH_FILTER", "(uid={0})")
18:     ldap_admin_group_dn: str = os.getenv(
19:         "LDAP_ADMIN_GROUP_DN", "cn=admins,ou=groups,dc=ldap,dc=talorlik,dc=internal"
20:     )
21:     ldap_group_search_base: str = os.getenv("LDAP_GROUP_SEARCH_BASE", "ou=groups")
22:     ldap_users_gid: int = int(os.getenv("LDAP_USERS_GID", "500"))
23:     ldap_uid_start: int = int(os.getenv("LDAP_UID_START", "10000"))
24:     # MFA/TOTP Configuration
25:     totp_issuer: str = os.getenv("TOTP_ISSUER", "LDAP-2FA-App")
26:     totp_digits: int = int(os.getenv("TOTP_DIGITS", "6"))
27:     totp_interval: int = int(os.getenv("TOTP_INTERVAL", "30"))
28:     totp_algorithm: str = os.getenv("TOTP_ALGORITHM", "SHA1")
29:     # SMS/SNS Configuration
30:     enable_sms_2fa: bool = os.getenv("ENABLE_SMS_2FA", "false").lower() == "true"
31:     aws_region: str = os.getenv("AWS_REGION", "us-east-1")
32:     sns_topic_arn: str = os.getenv("SNS_TOPIC_ARN", "")
33:     sms_sender_id: str = os.getenv("SMS_SENDER_ID", "2FA")
34:     sms_type: str = os.getenv("SMS_TYPE", "Transactional")
35:     sms_code_length: int = int(os.getenv("SMS_CODE_LENGTH", "6"))
36:     sms_code_expiry_seconds: int = int(os.getenv("SMS_CODE_EXPIRY_SECONDS", "300"))
37:     sms_message_template: str = os.getenv(
38:         "SMS_MESSAGE_TEMPLATE",
39:         "Your verification code is: {code}. It expires in 5 minutes."
40:     )
41:     # Redis Configuration (for SMS OTP storage)
42:     redis_enabled: bool = os.getenv("REDIS_ENABLED", "false").lower() == "true"
43:     redis_host: str = os.getenv("REDIS_HOST", "redis-master.redis.svc.cluster.local")
44:     redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
45:     redis_password: str = os.getenv("REDIS_PASSWORD", "")
46:     redis_db: int = int(os.getenv("REDIS_DB", "0"))
47:     redis_ssl: bool = os.getenv("REDIS_SSL", "false").lower() == "true"
48:     redis_key_prefix: str = os.getenv("REDIS_KEY_PREFIX", "sms_otp:")
49:     # Database Configuration (PostgreSQL)
50:     database_url: str = os.getenv(
51:         "DATABASE_URL",
52:         "postgresql+asyncpg://ldap2fa:ldap2fa@localhost:5432/ldap2fa"
53:     )
54:     # Email/SES Configuration
55:     enable_email_verification: bool = os.getenv(
56:         "ENABLE_EMAIL_VERIFICATION", "true"
57:     ).lower() == "true"
58:     ses_sender_email: str = os.getenv("SES_SENDER_EMAIL", "noreply@example.com")
59:     email_verification_expiry_hours: int = int(
60:         os.getenv("EMAIL_VERIFICATION_EXPIRY_HOURS", "24")
61:     )
62:     app_url: str = os.getenv("APP_URL", "http://localhost:8080")
63:     # Application Configuration
64:     app_name: str = os.getenv("APP_NAME", "LDAP 2FA Backend API")
65:     debug: bool = os.getenv("DEBUG", "false").lower() == "true"
66:     log_level: str = os.getenv("LOG_LEVEL", "INFO")
67:     # JWT Configuration
68:     jwt_secret_key: str = os.getenv("JWT_SECRET_KEY", "change-me-in-production-use-secure-random-key")
69:     jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
70:     jwt_expiry_minutes: int = int(os.getenv("JWT_EXPIRY_MINUTES", "60"))
71:     jwt_refresh_expiry_days: int = int(os.getenv("JWT_REFRESH_EXPIRY_DAYS", "7"))
72:     # CORS Configuration (for local development)
73:     cors_origins: list[str] = os.getenv("CORS_ORIGINS", "").split(",") if os.getenv(
74:         "CORS_ORIGINS"
75:     ) else []
76:     class Config:
77:         """Pydantic settings configuration."""
78:         env_file = ".env"
79:         env_file_encoding = "utf-8"
80: @lru_cache
81: def get_settings() -> Settings:
82:     """Get cached settings instance."""
83:     return Settings()
```

## File: application/backend/src/app/main.py
```python
 1: """Main entry point for the 2FA Backend API."""
 2: import logging
 3: import sys
 4: from fastapi import FastAPI
 5: from fastapi.middleware.cors import CORSMiddleware
 6: from app.api import router
 7: from app.config import get_settings
 8: from app.database import init_db, close_db
 9: # Configure logging
10: settings = get_settings()
11: logging.basicConfig(
12:     level=getattr(logging, settings.log_level.upper()),
13:     format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
14:     handlers=[logging.StreamHandler(sys.stdout)],
15: )
16: logger = logging.getLogger(__name__)
17: # Create FastAPI application
18: app = FastAPI(
19:     title=settings.app_name,
20:     description="Two-Factor Authentication API with LDAP, TOTP, and user signup support",
21:     version="2.0.0",
22:     docs_url="/api/docs",
23:     redoc_url="/api/redoc",
24:     openapi_url="/api/openapi.json",
25: )
26: # Add CORS middleware if origins are configured (for local development)
27: if settings.cors_origins:
28:     app.add_middleware(
29:         CORSMiddleware,
30:         allow_origins=settings.cors_origins,
31:         allow_credentials=True,
32:         allow_methods=["*"],
33:         allow_headers=["*"],
34:     )
35:     logger.info(f"CORS enabled for origins: {settings.cors_origins}")
36: # Include API routes
37: app.include_router(router)
38: @app.on_event("startup")
39: async def startup_event():
40:     """Initialize application on startup."""
41:     logger.info(f"Starting {settings.app_name}")
42:     # Initialize database
43:     try:
44:         await init_db()
45:         logger.info("Database connection established")
46:     except Exception as e:
47:         logger.error(f"Failed to initialize database: {e}")
48:         raise
49:     logger.info(f"LDAP Host: {settings.ldap_host}:{settings.ldap_port}")
50:     logger.info(f"TOTP Issuer: {settings.totp_issuer}")
51:     logger.info(f"Email verification: {'enabled' if settings.enable_email_verification else 'disabled'}")
52:     logger.info(f"SMS 2FA: {'enabled' if settings.enable_sms_2fa else 'disabled'}")
53:     logger.info(f"Debug mode: {settings.debug}")
54: @app.on_event("shutdown")
55: async def shutdown_event():
56:     """Cleanup on shutdown."""
57:     logger.info(f"Shutting down {settings.app_name}")
58:     # Close database connection
59:     await close_db()
60:     logger.info("Database connection closed")
61: if __name__ == "__main__":
62:     import uvicorn
63:     uvicorn.run(
64:         "app.main:app",
65:         host="0.0.0.0",
66:         port=8000,
67:         reload=settings.debug,
68:         log_level=settings.log_level.lower(),
69:     )
```

## File: application/backend/src/requirements.txt
```
 1: # Core framework
 2: fastapi==0.115.6
 3: uvicorn[standard]==0.34.0
 4: gunicorn==23.0.0
 5:
 6: # Settings management
 7: pydantic==2.10.4
 8: pydantic-settings==2.7.1
 9:
10: # LDAP
11: ldap3==2.9.1
12:
13: # AWS SDK for SNS (SMS) and SES (Email)
14: boto3==1.35.81
15:
16: # Database (PostgreSQL)
17: sqlalchemy[asyncio]==2.0.36
18: asyncpg==0.30.0
19: alembic==1.14.0
20:
21: # Redis for SMS OTP storage
22: redis==5.2.1
23:
24: # Password hashing
25: bcrypt==4.2.1
26:
27: # JWT for session management
28: PyJWT==2.10.1
29:
30: # Email validation
31: email-validator==2.2.0
32:
33: # Production server
34: python-multipart==0.0.20
```

## File: application/frontend/src/css/styles.css
```css
   1: /* CSS Variables for theming */
   2: :root {
   3:     --primary-color: #4f46e5;
   4:     --primary-hover: #4338ca;
   5:     --secondary-color: #64748b;
   6:     --success-color: #22c55e;
   7:     --error-color: #ef4444;
   8:     --warning-color: #f59e0b;
   9:     --info-color: #3b82f6;
  10:     --background-color: #f8fafc;
  11:     --card-background: #ffffff;
  12:     --text-primary: #1e293b;
  13:     --text-secondary: #64748b;
  14:     --border-color: #e2e8f0;
  15:     --input-background: #f1f5f9;
  16:     --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  17:     --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1);
  18:     --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1);
  19:     --border-radius: 12px;
  20:     --transition: all 0.2s ease-in-out;
  21: }
  22: /* Reset and base styles */
  23: *, *::before, *::after {
  24:     box-sizing: border-box;
  25:     margin: 0;
  26:     padding: 0;
  27: }
  28: body {
  29:     font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  30:     background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  31:     min-height: 100vh;
  32:     display: flex;
  33:     align-items: center;
  34:     justify-content: center;
  35:     padding: 20px;
  36:     color: var(--text-primary);
  37:     line-height: 1.6;
  38: }
  39: /* Main container */
  40: .container {
  41:     background: var(--card-background);
  42:     border-radius: var(--border-radius);
  43:     box-shadow: var(--shadow-lg);
  44:     padding: 40px;
  45:     width: 100%;
  46:     max-width: 520px;
  47:     animation: fadeIn 0.5s ease-out;
  48: }
  49: @keyframes fadeIn {
  50:     from {
  51:         opacity: 0;
  52:         transform: translateY(-20px);
  53:     }
  54:     to {
  55:         opacity: 1;
  56:         transform: translateY(0);
  57:     }
  58: }
  59: /* Header */
  60: header {
  61:     text-align: center;
  62:     margin-bottom: 30px;
  63: }
  64: header h1 {
  65:     font-size: 1.75rem;
  66:     font-weight: 700;
  67:     color: var(--text-primary);
  68:     margin-bottom: 8px;
  69: }
  70: header .subtitle {
  71:     color: var(--text-secondary);
  72:     font-size: 0.95rem;
  73: }
  74: /* Tab navigation */
  75: .tabs {
  76:     display: flex;
  77:     gap: 8px;
  78:     margin-bottom: 24px;
  79:     background: var(--input-background);
  80:     padding: 4px;
  81:     border-radius: 10px;
  82:     flex-wrap: wrap;
  83: }
  84: .tab-btn {
  85:     flex: 1;
  86:     padding: 12px 12px;
  87:     border: none;
  88:     background: transparent;
  89:     color: var(--text-secondary);
  90:     font-size: 0.9rem;
  91:     font-weight: 500;
  92:     cursor: pointer;
  93:     border-radius: 8px;
  94:     transition: var(--transition);
  95:     min-width: fit-content;
  96: }
  97: .tab-btn:hover {
  98:     color: var(--text-primary);
  99: }
 100: .tab-btn.active {
 101:     background: var(--card-background);
 102:     color: var(--primary-color);
 103:     box-shadow: var(--shadow-sm);
 104: }
 105: /* Tab content */
 106: .tab-content {
 107:     display: none;
 108: }
 109: .tab-content.active {
 110:     display: block;
 111:     animation: fadeIn 0.3s ease-out;
 112: }
 113: /* Form styles */
 114: .auth-form {
 115:     display: flex;
 116:     flex-direction: column;
 117:     gap: 20px;
 118: }
 119: .form-row {
 120:     display: grid;
 121:     grid-template-columns: 1fr 1fr;
 122:     gap: 16px;
 123: }
 124: .form-group {
 125:     display: flex;
 126:     flex-direction: column;
 127:     gap: 6px;
 128: }
 129: .form-group label {
 130:     font-size: 0.9rem;
 131:     font-weight: 500;
 132:     color: var(--text-primary);
 133: }
 134: .form-group input,
 135: .form-group select {
 136:     padding: 14px 16px;
 137:     border: 2px solid var(--border-color);
 138:     border-radius: 10px;
 139:     font-size: 1rem;
 140:     background: var(--input-background);
 141:     transition: var(--transition);
 142: }
 143: .form-group input:focus,
 144: .form-group select:focus {
 145:     outline: none;
 146:     border-color: var(--primary-color);
 147:     background: var(--card-background);
 148:     box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
 149: }
 150: .form-group input::placeholder {
 151:     color: var(--text-secondary);
 152: }
 153: /* Phone input group */
 154: .phone-input-group {
 155:     display: flex;
 156:     gap: 8px;
 157: }
 158: .phone-input-group select {
 159:     width: 120px;
 160:     flex-shrink: 0;
 161: }
 162: .phone-input-group input {
 163:     flex: 1;
 164: }
 165: /* Button styles */
 166: .btn {
 167:     padding: 14px 24px;
 168:     border: none;
 169:     border-radius: 10px;
 170:     font-size: 1rem;
 171:     font-weight: 600;
 172:     cursor: pointer;
 173:     transition: var(--transition);
 174:     display: flex;
 175:     align-items: center;
 176:     justify-content: center;
 177:     gap: 8px;
 178: }
 179: .btn-primary {
 180:     background: var(--primary-color);
 181:     color: white;
 182: }
 183: .btn-primary:hover {
 184:     background: var(--primary-hover);
 185:     transform: translateY(-1px);
 186:     box-shadow: var(--shadow-md);
 187: }
 188: .btn-primary:active {
 189:     transform: translateY(0);
 190: }
 191: .btn-secondary {
 192:     background: var(--input-background);
 193:     color: var(--text-primary);
 194:     border: 2px solid var(--border-color);
 195: }
 196: .btn-secondary:hover {
 197:     background: var(--border-color);
 198: }
 199: .btn-small {
 200:     padding: 8px 16px;
 201:     font-size: 0.85rem;
 202: }
 203: .btn:disabled {
 204:     opacity: 0.7;
 205:     cursor: not-allowed;
 206:     transform: none;
 207: }
 208: .btn-loading {
 209:     display: none;
 210: }
 211: .btn.loading .btn-text {
 212:     display: none;
 213: }
 214: .btn.loading .btn-loading {
 215:     display: inline;
 216: }
 217: /* Result container */
 218: .result-container {
 219:     margin-top: 24px;
 220:     padding: 20px;
 221:     border-radius: 10px;
 222:     animation: fadeIn 0.3s ease-out;
 223: }
 224: .result-container.success {
 225:     background: rgba(34, 197, 94, 0.1);
 226:     border: 2px solid var(--success-color);
 227: }
 228: .result-container.error {
 229:     background: rgba(239, 68, 68, 0.1);
 230:     border: 2px solid var(--error-color);
 231: }
 232: .result-container h3 {
 233:     font-size: 1.1rem;
 234:     margin-bottom: 8px;
 235: }
 236: .result-container.success h3 {
 237:     color: var(--success-color);
 238: }
 239: .result-container.error h3 {
 240:     color: var(--error-color);
 241: }
 242: .result-container p {
 243:     color: var(--text-secondary);
 244:     font-size: 0.95rem;
 245: }
 246: .admin-badge {
 247:     display: inline-block;
 248:     background: linear-gradient(135deg, #f59e0b 0%, #ef4444 100%);
 249:     color: white;
 250:     padding: 4px 12px;
 251:     border-radius: 20px;
 252:     font-size: 0.85rem;
 253:     font-weight: 600;
 254:     margin-top: 8px;
 255: }
 256: /* QR Code section */
 257: .qr-section {
 258:     text-align: center;
 259: }
 260: .qr-section h3 {
 261:     color: var(--text-primary);
 262:     margin-bottom: 8px;
 263: }
 264: .qr-section > p {
 265:     margin-bottom: 20px;
 266: }
 267: .qr-code {
 268:     display: inline-block;
 269:     padding: 16px;
 270:     background: white;
 271:     border-radius: 12px;
 272:     box-shadow: var(--shadow-md);
 273:     margin-bottom: 20px;
 274: }
 275: .qr-code canvas {
 276:     display: block;
 277: }
 278: .manual-entry {
 279:     padding: 16px;
 280:     background: var(--input-background);
 281:     border-radius: 10px;
 282:     margin-top: 16px;
 283: }
 284: .manual-entry p {
 285:     font-size: 0.85rem;
 286:     margin-bottom: 12px;
 287: }
 288: .manual-entry code {
 289:     display: block;
 290:     padding: 12px;
 291:     background: var(--card-background);
 292:     border: 2px solid var(--border-color);
 293:     border-radius: 8px;
 294:     font-family: 'Monaco', 'Consolas', monospace;
 295:     font-size: 0.9rem;
 296:     word-break: break-all;
 297:     margin-bottom: 12px;
 298:     color: var(--primary-color);
 299: }
 300: /* Status message */
 301: .status-message {
 302:     position: fixed;
 303:     top: 20px;
 304:     left: 50%;
 305:     transform: translateX(-50%);
 306:     padding: 14px 24px;
 307:     border-radius: 10px;
 308:     font-weight: 500;
 309:     box-shadow: var(--shadow-lg);
 310:     z-index: 1000;
 311:     animation: slideDown 0.3s ease-out;
 312: }
 313: @keyframes slideDown {
 314:     from {
 315:         opacity: 0;
 316:         transform: translateX(-50%) translateY(-20px);
 317:     }
 318:     to {
 319:         opacity: 1;
 320:         transform: translateX(-50%) translateY(0);
 321:     }
 322: }
 323: .status-message.success {
 324:     background: var(--success-color);
 325:     color: white;
 326: }
 327: .status-message.error {
 328:     background: var(--error-color);
 329:     color: white;
 330: }
 331: .status-message.warning {
 332:     background: var(--warning-color);
 333:     color: white;
 334: }
 335: /* MFA Method Selector */
 336: .mfa-method-selector {
 337:     display: flex;
 338:     flex-direction: column;
 339:     gap: 12px;
 340: }
 341: .radio-option {
 342:     display: block;
 343:     cursor: pointer;
 344: }
 345: .radio-option input[type="radio"] {
 346:     position: absolute;
 347:     opacity: 0;
 348:     width: 0;
 349:     height: 0;
 350: }
 351: .radio-label {
 352:     display: flex;
 353:     align-items: center;
 354:     gap: 12px;
 355:     padding: 14px 16px;
 356:     border: 2px solid var(--border-color);
 357:     border-radius: 10px;
 358:     background: var(--input-background);
 359:     transition: var(--transition);
 360: }
 361: .radio-option input[type="radio"]:checked + .radio-label {
 362:     border-color: var(--primary-color);
 363:     background: rgba(79, 70, 229, 0.05);
 364: }
 365: .radio-option:hover .radio-label {
 366:     border-color: var(--primary-color);
 367: }
 368: .radio-icon {
 369:     font-size: 1.5rem;
 370: }
 371: .radio-text {
 372:     display: flex;
 373:     flex-direction: column;
 374:     gap: 2px;
 375: }
 376: .radio-text strong {
 377:     font-size: 0.95rem;
 378:     color: var(--text-primary);
 379: }
 380: .radio-text small {
 381:     font-size: 0.8rem;
 382:     color: var(--text-secondary);
 383: }
 384: /* Code Input Group */
 385: .code-input-group {
 386:     display: flex;
 387:     gap: 8px;
 388: }
 389: .code-input-group input {
 390:     flex: 1;
 391: }
 392: .code-input-group .btn {
 393:     white-space: nowrap;
 394: }
 395: /* Form Hint */
 396: .form-hint {
 397:     font-size: 0.8rem;
 398:     color: var(--text-secondary);
 399:     margin-top: 4px;
 400: }
 401: /* SMS Section */
 402: .sms-section {
 403:     text-align: center;
 404:     padding: 20px;
 405: }
 406: .sms-section h3 {
 407:     color: var(--success-color);
 408:     margin-bottom: 12px;
 409: }
 410: .sms-section p {
 411:     margin-bottom: 8px;
 412: }
 413: .sms-section .hint {
 414:     font-size: 0.85rem;
 415:     color: var(--text-secondary);
 416: }
 417: /* Disabled radio option */
 418: .radio-option.disabled {
 419:     opacity: 0.5;
 420:     cursor: not-allowed;
 421: }
 422: .radio-option.disabled .radio-label {
 423:     pointer-events: none;
 424: }
 425: /* Verification Panel */
 426: .verification-panel {
 427:     padding: 24px;
 428:     background: var(--input-background);
 429:     border-radius: 12px;
 430:     margin-top: 20px;
 431: }
 432: .verification-panel h3 {
 433:     font-size: 1.2rem;
 434:     color: var(--text-primary);
 435:     margin-bottom: 8px;
 436: }
 437: .verification-subtitle {
 438:     color: var(--text-secondary);
 439:     margin-bottom: 20px;
 440: }
 441: .verification-items {
 442:     display: flex;
 443:     flex-direction: column;
 444:     gap: 16px;
 445:     margin-bottom: 24px;
 446: }
 447: .verification-item {
 448:     display: flex;
 449:     align-items: center;
 450:     gap: 12px;
 451:     padding: 16px;
 452:     background: var(--card-background);
 453:     border-radius: 10px;
 454:     border: 2px solid var(--border-color);
 455: }
 456: .verification-item .status-icon {
 457:     font-size: 1.5rem;
 458: }
 459: .verification-details {
 460:     flex: 1;
 461: }
 462: .verification-label {
 463:     display: block;
 464:     font-weight: 600;
 465:     color: var(--text-primary);
 466: }
 467: .verification-hint {
 468:     display: block;
 469:     font-size: 0.85rem;
 470:     color: var(--text-secondary);
 471: }
 472: .phone-verify-input {
 473:     margin-bottom: 20px;
 474: }
 475: .verification-complete {
 476:     text-align: center;
 477:     padding: 24px;
 478:     background: rgba(34, 197, 94, 0.1);
 479:     border-radius: 10px;
 480:     border: 2px solid var(--success-color);
 481: }
 482: .verification-complete .success-icon {
 483:     font-size: 3rem;
 484:     margin-bottom: 12px;
 485: }
 486: .verification-complete h4 {
 487:     color: var(--success-color);
 488:     margin-bottom: 8px;
 489: }
 490: .verification-complete p {
 491:     color: var(--text-secondary);
 492: }
 493: /* Admin Styles */
 494: .admin-section {
 495:     animation: fadeIn 0.3s ease-out;
 496: }
 497: .admin-header {
 498:     display: flex;
 499:     justify-content: space-between;
 500:     align-items: center;
 501:     margin-bottom: 20px;
 502: }
 503: .admin-header h3 {
 504:     font-size: 1.2rem;
 505:     color: var(--text-primary);
 506: }
 507: .admin-filters {
 508:     display: flex;
 509:     gap: 12px;
 510:     margin-bottom: 20px;
 511: }
 512: .admin-filters select {
 513:     flex: 1;
 514:     padding: 10px 14px;
 515:     border: 2px solid var(--border-color);
 516:     border-radius: 8px;
 517:     background: var(--input-background);
 518:     font-size: 0.9rem;
 519: }
 520: .admin-users-list {
 521:     display: flex;
 522:     flex-direction: column;
 523:     gap: 16px;
 524:     max-height: 400px;
 525:     overflow-y: auto;
 526: }
 527: .user-card {
 528:     padding: 16px;
 529:     background: var(--input-background);
 530:     border-radius: 10px;
 531:     border: 2px solid var(--border-color);
 532:     transition: var(--transition);
 533: }
 534: .user-card:hover {
 535:     border-color: var(--primary-color);
 536: }
 537: .user-info {
 538:     margin-bottom: 12px;
 539: }
 540: .user-name {
 541:     font-weight: 600;
 542:     color: var(--text-primary);
 543:     font-size: 1.05rem;
 544: }
 545: .user-username {
 546:     color: var(--text-secondary);
 547:     font-size: 0.9rem;
 548: }
 549: .user-details {
 550:     display: flex;
 551:     gap: 16px;
 552:     margin-top: 8px;
 553:     font-size: 0.85rem;
 554:     color: var(--text-secondary);
 555: }
 556: .user-status {
 557:     display: flex;
 558:     align-items: center;
 559:     gap: 12px;
 560:     margin-top: 8px;
 561: }
 562: .status-badge {
 563:     padding: 4px 10px;
 564:     border-radius: 20px;
 565:     font-size: 0.75rem;
 566:     font-weight: 600;
 567:     text-transform: uppercase;
 568: }
 569: .status-pending {
 570:     background: rgba(245, 158, 11, 0.2);
 571:     color: #d97706;
 572: }
 573: .status-complete {
 574:     background: rgba(59, 130, 246, 0.2);
 575:     color: #2563eb;
 576: }
 577: .status-active {
 578:     background: rgba(34, 197, 94, 0.2);
 579:     color: #16a34a;
 580: }
 581: .verification-badges {
 582:     font-size: 0.8rem;
 583:     color: var(--text-secondary);
 584: }
 585: .user-meta {
 586:     font-size: 0.8rem;
 587:     color: var(--text-secondary);
 588:     margin-top: 8px;
 589: }
 590: .user-actions {
 591:     display: flex;
 592:     gap: 8px;
 593: }
 594: .admin-no-users {
 595:     text-align: center;
 596:     padding: 40px 20px;
 597:     color: var(--text-secondary);
 598: }
 599: .loading-spinner {
 600:     text-align: center;
 601:     padding: 40px 20px;
 602:     color: var(--text-secondary);
 603: }
 604: .error-message {
 605:     text-align: center;
 606:     padding: 20px;
 607:     color: var(--error-color);
 608:     background: rgba(239, 68, 68, 0.1);
 609:     border-radius: 10px;
 610: }
 611: /* Hidden utility class */
 612: .hidden {
 613:     display: none !important;
 614: }
 615: /* Footer */
 616: footer {
 617:     margin-top: 30px;
 618:     text-align: center;
 619:     padding-top: 20px;
 620:     border-top: 1px solid var(--border-color);
 621: }
 622: footer p {
 623:     color: var(--text-secondary);
 624:     font-size: 0.85rem;
 625: }
 626: /* Responsive adjustments */
 627: @media (max-width: 540px) {
 628:     body {
 629:         padding: 10px;
 630:     }
 631:     .container {
 632:         padding: 24px;
 633:     }
 634:     header h1 {
 635:         font-size: 1.5rem;
 636:     }
 637:     .tabs {
 638:         flex-direction: column;
 639:     }
 640:     .tab-btn {
 641:         padding: 14px;
 642:     }
 643:     .form-row {
 644:         grid-template-columns: 1fr;
 645:     }
 646:     .phone-input-group {
 647:         flex-direction: column;
 648:     }
 649:     .phone-input-group select {
 650:         width: 100%;
 651:     }
 652:     .admin-filters {
 653:         flex-direction: column;
 654:     }
 655:     .user-details {
 656:         flex-direction: column;
 657:         gap: 4px;
 658:     }
 659:     .user-status {
 660:         flex-direction: column;
 661:         align-items: flex-start;
 662:         gap: 8px;
 663:     }
 664:     .user-actions {
 665:         flex-direction: column;
 666:     }
 667: }
 668: /* Dark mode support */
 669: @media (prefers-color-scheme: dark) {
 670:     :root {
 671:         --background-color: #0f172a;
 672:         --card-background: #1e293b;
 673:         --text-primary: #f1f5f9;
 674:         --text-secondary: #94a3b8;
 675:         --border-color: #334155;
 676:         --input-background: #0f172a;
 677:     }
 678:     body {
 679:         background: linear-gradient(135deg, #1e1b4b 0%, #312e81 100%);
 680:     }
 681:     .form-group input:focus,
 682:     .form-group select:focus {
 683:         background: var(--card-background);
 684:     }
 685:     .qr-code {
 686:         background: white;
 687:     }
 688:     .user-card {
 689:         background: var(--card-background);
 690:     }
 691:     .verification-panel {
 692:         background: var(--card-background);
 693:     }
 694:     .verification-item {
 695:         background: var(--input-background);
 696:     }
 697: }
 698: /* Loading spinner */
 699: @keyframes spin {
 700:     to {
 701:         transform: rotate(360deg);
 702:     }
 703: }
 704: .spinner {
 705:     width: 20px;
 706:     height: 20px;
 707:     border: 2px solid transparent;
 708:     border-top-color: currentColor;
 709:     border-radius: 50%;
 710:     animation: spin 0.8s linear infinite;
 711:     display: inline-block;
 712:     margin-right: 8px;
 713: }
 714: /* Scrollbar styling */
 715: .admin-users-list::-webkit-scrollbar {
 716:     width: 8px;
 717: }
 718: .admin-users-list::-webkit-scrollbar-track {
 719:     background: var(--input-background);
 720:     border-radius: 4px;
 721: }
 722: .admin-users-list::-webkit-scrollbar-thumb {
 723:     background: var(--border-color);
 724:     border-radius: 4px;
 725: }
 726: .admin-users-list::-webkit-scrollbar-thumb:hover {
 727:     background: var(--text-secondary);
 728: }
 729: /* ============================================
 730:    Top Navigation Bar
 731:    ============================================ */
 732: .top-bar {
 733:     position: fixed;
 734:     top: 0;
 735:     left: 0;
 736:     right: 0;
 737:     height: 60px;
 738:     background: var(--card-background);
 739:     box-shadow: var(--shadow-md);
 740:     z-index: 1000;
 741: }
 742: .top-bar-content {
 743:     max-width: 1200px;
 744:     margin: 0 auto;
 745:     height: 100%;
 746:     display: flex;
 747:     align-items: center;
 748:     justify-content: space-between;
 749:     padding: 0 24px;
 750: }
 751: .top-bar-brand {
 752:     display: flex;
 753:     align-items: center;
 754:     gap: 10px;
 755:     font-size: 1.25rem;
 756:     font-weight: 700;
 757:     color: var(--primary-color);
 758: }
 759: .brand-icon {
 760:     font-size: 1.5rem;
 761: }
 762: .top-bar-user {
 763:     position: relative;
 764: }
 765: .user-menu-btn {
 766:     display: flex;
 767:     align-items: center;
 768:     gap: 8px;
 769:     padding: 8px 16px;
 770:     border: 2px solid var(--border-color);
 771:     border-radius: 8px;
 772:     background: var(--input-background);
 773:     cursor: pointer;
 774:     font-size: 0.9rem;
 775:     font-weight: 500;
 776:     color: var(--text-primary);
 777:     transition: var(--transition);
 778: }
 779: .user-menu-btn:hover {
 780:     border-color: var(--primary-color);
 781: }
 782: .dropdown-arrow {
 783:     font-size: 0.7rem;
 784:     color: var(--text-secondary);
 785: }
 786: .user-dropdown {
 787:     position: absolute;
 788:     top: calc(100% + 8px);
 789:     right: 0;
 790:     min-width: 200px;
 791:     background: var(--card-background);
 792:     border: 2px solid var(--border-color);
 793:     border-radius: 10px;
 794:     box-shadow: var(--shadow-lg);
 795:     overflow: hidden;
 796: }
 797: .dropdown-item {
 798:     display: flex;
 799:     align-items: center;
 800:     gap: 10px;
 801:     padding: 12px 16px;
 802:     color: var(--text-primary);
 803:     text-decoration: none;
 804:     transition: var(--transition);
 805: }
 806: .dropdown-item:hover {
 807:     background: var(--input-background);
 808: }
 809: .dropdown-icon {
 810:     font-size: 1rem;
 811: }
 812: .dropdown-divider {
 813:     border: none;
 814:     border-top: 1px solid var(--border-color);
 815:     margin: 0;
 816: }
 817: /* ============================================
 818:    Logged In Container
 819:    ============================================ */
 820: .container.logged-in {
 821:     margin-top: 80px;
 822:     max-width: 1000px;
 823: }
 824: .container.logged-in header:first-child {
 825:     display: none;
 826: }
 827: /* ============================================
 828:    Section Headers
 829:    ============================================ */
 830: .section-header {
 831:     display: flex;
 832:     justify-content: space-between;
 833:     align-items: center;
 834:     margin-bottom: 24px;
 835: }
 836: .section-header h2 {
 837:     font-size: 1.5rem;
 838:     font-weight: 700;
 839:     color: var(--text-primary);
 840:     margin: 0;
 841: }
 842: /* ============================================
 843:    Admin Controls
 844:    ============================================ */
 845: .admin-controls {
 846:     display: flex;
 847:     flex-wrap: wrap;
 848:     gap: 12px;
 849:     margin-bottom: 20px;
 850: }
 851: .search-box {
 852:     flex: 1;
 853:     min-width: 200px;
 854: }
 855: .search-input {
 856:     width: 100%;
 857:     padding: 10px 14px;
 858:     border: 2px solid var(--border-color);
 859:     border-radius: 8px;
 860:     background: var(--input-background);
 861:     font-size: 0.9rem;
 862:     color: var(--text-primary);
 863: }
 864: .search-input:focus {
 865:     outline: none;
 866:     border-color: var(--primary-color);
 867: }
 868: .filter-controls {
 869:     display: flex;
 870:     gap: 8px;
 871:     flex-wrap: wrap;
 872: }
 873: .filter-select {
 874:     padding: 10px 14px;
 875:     border: 2px solid var(--border-color);
 876:     border-radius: 8px;
 877:     background: var(--input-background);
 878:     font-size: 0.9rem;
 879:     color: var(--text-primary);
 880:     min-width: 150px;
 881: }
 882: /* ============================================
 883:    Data Tables
 884:    ============================================ */
 885: .data-table-container {
 886:     overflow-x: auto;
 887:     margin-bottom: 20px;
 888: }
 889: .data-table {
 890:     width: 100%;
 891:     border-collapse: collapse;
 892:     font-size: 0.9rem;
 893: }
 894: .data-table th,
 895: .data-table td {
 896:     padding: 12px 16px;
 897:     text-align: left;
 898:     border-bottom: 1px solid var(--border-color);
 899: }
 900: .data-table th {
 901:     background: var(--input-background);
 902:     font-weight: 600;
 903:     color: var(--text-secondary);
 904:     white-space: nowrap;
 905: }
 906: .data-table th.sortable {
 907:     cursor: pointer;
 908:     user-select: none;
 909: }
 910: .data-table th.sortable:hover {
 911:     color: var(--primary-color);
 912: }
 913: .data-table th.sortable::after {
 914:     content: '⇅';
 915:     margin-left: 8px;
 916:     opacity: 0.3;
 917: }
 918: .data-table th.sort-asc::after {
 919:     content: '↑';
 920:     opacity: 1;
 921: }
 922: .data-table th.sort-desc::after {
 923:     content: '↓';
 924:     opacity: 1;
 925: }
 926: .data-table tbody tr:hover {
 927:     background: var(--input-background);
 928: }
 929: .action-buttons {
 930:     display: flex;
 931:     gap: 8px;
 932:     flex-wrap: wrap;
 933: }
 934: .btn-xs {
 935:     padding: 4px 10px;
 936:     font-size: 0.75rem;
 937: }
 938: .btn-danger {
 939:     background: var(--error-color);
 940:     color: white;
 941: }
 942: .btn-danger:hover {
 943:     background: #dc2626;
 944: }
 945: /* ============================================
 946:    Group Badges
 947:    ============================================ */
 948: .group-badges {
 949:     display: flex;
 950:     flex-wrap: wrap;
 951:     gap: 8px;
 952: }
 953: .group-badge {
 954:     display: inline-block;
 955:     padding: 4px 12px;
 956:     background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
 957:     color: white;
 958:     border-radius: 20px;
 959:     font-size: 0.8rem;
 960:     font-weight: 500;
 961: }
 962: .group-badge-small {
 963:     display: inline-block;
 964:     padding: 2px 8px;
 965:     background: var(--primary-color);
 966:     color: white;
 967:     border-radius: 12px;
 968:     font-size: 0.7rem;
 969:     font-weight: 500;
 970: }
 971: .no-groups {
 972:     color: var(--text-secondary);
 973:     font-style: italic;
 974: }
 975: /* ============================================
 976:    Profile Page
 977:    ============================================ */
 978: .readonly-input {
 979:     background: var(--input-background) !important;
 980:     color: var(--text-secondary) !important;
 981:     cursor: not-allowed;
 982: }
 983: /* ============================================
 984:    Modals
 985:    ============================================ */
 986: .modal-overlay {
 987:     position: fixed;
 988:     top: 0;
 989:     left: 0;
 990:     right: 0;
 991:     bottom: 0;
 992:     background: rgba(0, 0, 0, 0.5);
 993:     display: flex;
 994:     align-items: center;
 995:     justify-content: center;
 996:     z-index: 2000;
 997:     padding: 20px;
 998: }
 999: .modal {
1000:     background: var(--card-background);
1001:     border-radius: var(--border-radius);
1002:     box-shadow: var(--shadow-lg);
1003:     width: 100%;
1004:     max-width: 500px;
1005:     max-height: 90vh;
1006:     overflow-y: auto;
1007:     animation: fadeIn 0.2s ease-out;
1008: }
1009: .modal-header {
1010:     display: flex;
1011:     justify-content: space-between;
1012:     align-items: center;
1013:     padding: 20px 24px;
1014:     border-bottom: 1px solid var(--border-color);
1015: }
1016: .modal-header h3 {
1017:     margin: 0;
1018:     font-size: 1.25rem;
1019:     color: var(--text-primary);
1020: }
1021: .modal-close {
1022:     background: none;
1023:     border: none;
1024:     font-size: 1.5rem;
1025:     color: var(--text-secondary);
1026:     cursor: pointer;
1027:     padding: 0;
1028:     line-height: 1;
1029: }
1030: .modal-close:hover {
1031:     color: var(--text-primary);
1032: }
1033: .modal-body {
1034:     padding: 24px;
1035: }
1036: .modal-footer {
1037:     display: flex;
1038:     justify-content: flex-end;
1039:     gap: 12px;
1040:     padding: 16px 24px;
1041:     border-top: 1px solid var(--border-color);
1042: }
1043: /* ============================================
1044:    Checkbox List
1045:    ============================================ */
1046: .checkbox-list {
1047:     display: flex;
1048:     flex-direction: column;
1049:     gap: 8px;
1050:     max-height: 200px;
1051:     overflow-y: auto;
1052: }
1053: .checkbox-option {
1054:     display: flex;
1055:     align-items: center;
1056:     gap: 10px;
1057:     padding: 10px 14px;
1058:     border: 2px solid var(--border-color);
1059:     border-radius: 8px;
1060:     cursor: pointer;
1061:     transition: var(--transition);
1062: }
1063: .checkbox-option:hover {
1064:     border-color: var(--primary-color);
1065: }
1066: .checkbox-option input[type="checkbox"] {
1067:     width: 18px;
1068:     height: 18px;
1069:     accent-color: var(--primary-color);
1070: }
1071: /* ============================================
1072:    Members List
1073:    ============================================ */
1074: .members-list {
1075:     display: flex;
1076:     flex-direction: column;
1077:     gap: 8px;
1078:     max-height: 300px;
1079:     overflow-y: auto;
1080: }
1081: .member-item {
1082:     display: flex;
1083:     justify-content: space-between;
1084:     align-items: center;
1085:     padding: 12px 16px;
1086:     background: var(--input-background);
1087:     border-radius: 8px;
1088: }
1089: .member-name {
1090:     font-weight: 600;
1091:     color: var(--text-primary);
1092: }
1093: .member-username {
1094:     font-size: 0.85rem;
1095:     color: var(--text-secondary);
1096: }
1097: /* ============================================
1098:    Empty & Loading States
1099:    ============================================ */
1100: .empty-state {
1101:     text-align: center;
1102:     padding: 40px 20px;
1103:     color: var(--text-secondary);
1104: }
1105: .warning-message {
1106:     padding: 12px 16px;
1107:     background: rgba(245, 158, 11, 0.1);
1108:     border: 1px solid var(--warning-color);
1109:     border-radius: 8px;
1110:     color: var(--warning-color);
1111: }
1112: /* ============================================
1113:    Status Badge - Revoked
1114:    ============================================ */
1115: .status-revoked {
1116:     background: rgba(107, 114, 128, 0.2);
1117:     color: #6b7280;
1118: }
1119: /* ============================================
1120:    Textarea
1121:    ============================================ */
1122: textarea {
1123:     width: 100%;
1124:     padding: 14px 16px;
1125:     border: 2px solid var(--border-color);
1126:     border-radius: 10px;
1127:     font-size: 1rem;
1128:     font-family: inherit;
1129:     background: var(--input-background);
1130:     color: var(--text-primary);
1131:     resize: vertical;
1132:     transition: var(--transition);
1133: }
1134: textarea:focus {
1135:     outline: none;
1136:     border-color: var(--primary-color);
1137:     background: var(--card-background);
1138: }
1139: /* ============================================
1140:    Dark Mode Extensions
1141:    ============================================ */
1142: @media (prefers-color-scheme: dark) {
1143:     .top-bar {
1144:         background: var(--card-background);
1145:         border-bottom: 1px solid var(--border-color);
1146:     }
1147:     .user-dropdown {
1148:         background: var(--card-background);
1149:     }
1150:     .modal {
1151:         background: var(--card-background);
1152:     }
1153:     .data-table th {
1154:         background: rgba(0, 0, 0, 0.2);
1155:     }
1156: }
1157: /* ============================================
1158:    Responsive - New Components
1159:    ============================================ */
1160: @media (max-width: 768px) {
1161:     .top-bar-content {
1162:         padding: 0 16px;
1163:     }
1164:     .brand-text {
1165:         display: none;
1166:     }
1167:     .admin-controls {
1168:         flex-direction: column;
1169:     }
1170:     .filter-controls {
1171:         width: 100%;
1172:     }
1173:     .filter-select {
1174:         flex: 1;
1175:     }
1176:     .data-table {
1177:         font-size: 0.8rem;
1178:     }
1179:     .data-table th,
1180:     .data-table td {
1181:         padding: 8px 10px;
1182:     }
1183:     .action-buttons {
1184:         flex-direction: column;
1185:     }
1186: }
```

## File: application/frontend/src/js/api.js
```javascript
  1: /**
  2:  * API client for LDAP 2FA Backend
  3:  * Uses relative URLs to work with single-domain routing pattern
  4:  */
  5: const API = {
  6:     /**
  7:      * Base API path
  8:      */
  9:     basePath: '/api',
 10:     /**
 11:      * JWT token storage key
 12:      */
 13:     tokenKey: 'ldap2fa_token',
 14:     /**
 15:      * Get stored JWT token
 16:      */
 17:     getToken() {
 18:         return localStorage.getItem(this.tokenKey);
 19:     },
 20:     /**
 21:      * Store JWT token
 22:      */
 23:     setToken(token) {
 24:         if (token) {
 25:             localStorage.setItem(this.tokenKey, token);
 26:         } else {
 27:             localStorage.removeItem(this.tokenKey);
 28:         }
 29:     },
 30:     /**
 31:      * Clear JWT token (logout)
 32:      */
 33:     clearToken() {
 34:         localStorage.removeItem(this.tokenKey);
 35:     },
 36:     /**
 37:      * Make an API request
 38:      * @param {string} endpoint - API endpoint (e.g., '/auth/login')
 39:      * @param {Object} options - Fetch options
 40:      * @param {boolean} auth - Whether to include auth token
 41:      * @returns {Promise<Object>} Response data
 42:      */
 43:     async request(endpoint, options = {}, auth = false) {
 44:         const url = `${this.basePath}${endpoint}`;
 45:         const defaultOptions = {
 46:             headers: {
 47:                 'Content-Type': 'application/json',
 48:             },
 49:         };
 50:         // Add auth header if requested and token exists
 51:         if (auth) {
 52:             const token = this.getToken();
 53:             if (token) {
 54:                 defaultOptions.headers['Authorization'] = `Bearer ${token}`;
 55:             }
 56:         }
 57:         const mergedOptions = {
 58:             ...defaultOptions,
 59:             ...options,
 60:             headers: {
 61:                 ...defaultOptions.headers,
 62:                 ...options.headers,
 63:             },
 64:         };
 65:         try {
 66:             const response = await fetch(url, mergedOptions);
 67:             const data = await response.json();
 68:             if (!response.ok) {
 69:                 throw new APIError(
 70:                     data.detail || 'An error occurred',
 71:                     response.status,
 72:                     data
 73:                 );
 74:             }
 75:             return data;
 76:         } catch (error) {
 77:             if (error instanceof APIError) {
 78:                 throw error;
 79:             }
 80:             // Network or other errors
 81:             throw new APIError(
 82:                 error.message || 'Network error. Please check your connection.',
 83:                 0,
 84:                 null
 85:             );
 86:         }
 87:     },
 88:     /**
 89:      * Make an authenticated API request
 90:      */
 91:     async authRequest(endpoint, options = {}) {
 92:         return this.request(endpoint, options, true);
 93:     },
 94:     /**
 95:      * Health check endpoint
 96:      * @returns {Promise<Object>} Health status
 97:      */
 98:     async healthCheck() {
 99:         return this.request('/healthz');
100:     },
101:     /**
102:      * Get available MFA methods
103:      * @returns {Promise<Object>} MFA methods response
104:      */
105:     async getMfaMethods() {
106:         return this.request('/mfa/methods');
107:     },
108:     /**
109:      * Get user's MFA enrollment status
110:      * @param {string} username - Username
111:      * @returns {Promise<Object>} MFA status response
112:      */
113:     async getMfaStatus(username) {
114:         return this.request(`/mfa/status/${encodeURIComponent(username)}`);
115:     },
116:     // =========================================================================
117:     // Signup & Verification
118:     // =========================================================================
119:     /**
120:      * Sign up a new user
121:      * @param {Object} userData - User signup data
122:      * @returns {Promise<Object>} Signup response
123:      */
124:     async signup(userData) {
125:         return this.request('/auth/signup', {
126:             method: 'POST',
127:             body: JSON.stringify({
128:                 username: userData.username,
129:                 email: userData.email,
130:                 first_name: userData.firstName,
131:                 last_name: userData.lastName,
132:                 phone_country_code: userData.phoneCountryCode,
133:                 phone_number: userData.phoneNumber,
134:                 password: userData.password,
135:                 mfa_method: userData.mfaMethod || 'totp',
136:             }),
137:         });
138:     },
139:     /**
140:      * Verify email address
141:      * @param {string} username - Username
142:      * @param {string} token - Email verification token
143:      * @returns {Promise<Object>} Verification response
144:      */
145:     async verifyEmail(username, token) {
146:         return this.request('/auth/verify-email', {
147:             method: 'POST',
148:             body: JSON.stringify({ username, token }),
149:         });
150:     },
151:     /**
152:      * Verify phone number
153:      * @param {string} username - Username
154:      * @param {string} code - 6-digit verification code
155:      * @returns {Promise<Object>} Verification response
156:      */
157:     async verifyPhone(username, code) {
158:         return this.request('/auth/verify-phone', {
159:             method: 'POST',
160:             body: JSON.stringify({ username, code }),
161:         });
162:     },
163:     /**
164:      * Resend verification email or SMS
165:      * @param {string} username - Username
166:      * @param {string} type - 'email' or 'phone'
167:      * @returns {Promise<Object>} Response
168:      */
169:     async resendVerification(username, type) {
170:         return this.request('/auth/resend-verification', {
171:             method: 'POST',
172:             body: JSON.stringify({
173:                 username,
174:                 verification_type: type,
175:             }),
176:         });
177:     },
178:     /**
179:      * Get user's profile status
180:      * @param {string} username - Username
181:      * @returns {Promise<Object>} Profile status response
182:      */
183:     async getProfileStatus(username) {
184:         return this.request(`/profile/status/${encodeURIComponent(username)}`);
185:     },
186:     // =========================================================================
187:     // MFA Enrollment
188:     // =========================================================================
189:     /**
190:      * Enroll a user for MFA
191:      * @param {string} username - Username
192:      * @param {string} password - Password
193:      * @param {string} mfaMethod - MFA method ('totp' or 'sms')
194:      * @param {string} phoneNumber - Phone number (required for SMS)
195:      * @returns {Promise<Object>} Enrollment response with otpauth_uri and secret
196:      */
197:     async enroll(username, password, mfaMethod = 'totp', phoneNumber = null) {
198:         const body = { username, password, mfa_method: mfaMethod };
199:         if (phoneNumber) {
200:             body.phone_number = phoneNumber;
201:         }
202:         return this.request('/auth/enroll', {
203:             method: 'POST',
204:             body: JSON.stringify(body),
205:         });
206:     },
207:     // =========================================================================
208:     // Login
209:     // =========================================================================
210:     /**
211:      * Send SMS verification code for login
212:      * @param {string} username - Username
213:      * @param {string} password - Password
214:      * @returns {Promise<Object>} SMS send response
215:      */
216:     async sendSmsCode(username, password) {
217:         return this.request('/auth/sms/send-code', {
218:             method: 'POST',
219:             body: JSON.stringify({ username, password }),
220:         });
221:     },
222:     /**
223:      * Login with credentials and verification code
224:      * @param {string} username - Username
225:      * @param {string} password - Password
226:      * @param {string} verificationCode - 6-digit verification code
227:      * @returns {Promise<Object>} Login response
228:      */
229:     async login(username, password, verificationCode) {
230:         return this.request('/auth/login', {
231:             method: 'POST',
232:             body: JSON.stringify({
233:                 username,
234:                 password,
235:                 verification_code: verificationCode,
236:             }),
237:         });
238:     },
239:     // =========================================================================
240:     // Admin
241:     // =========================================================================
242:     /**
243:      * Admin login
244:      * @param {string} username - Admin username
245:      * @param {string} password - Admin password
246:      * @param {string} verificationCode - 6-digit verification code
247:      * @returns {Promise<Object>} Login response
248:      */
249:     async adminLogin(username, password, verificationCode) {
250:         return this.request('/admin/login', {
251:             method: 'POST',
252:             body: JSON.stringify({
253:                 username,
254:                 password,
255:                 verification_code: verificationCode,
256:             }),
257:         });
258:     },
259:     /**
260:      * List users (admin only)
261:      * @param {string} adminUsername - Admin username
262:      * @param {string} adminPassword - Admin password
263:      * @param {string} statusFilter - Optional status filter
264:      * @returns {Promise<Object>} User list response
265:      */
266:     async adminListUsers(adminUsername, adminPassword, statusFilter = null) {
267:         let url = `/admin/users?admin_username=${encodeURIComponent(adminUsername)}&admin_password=${encodeURIComponent(adminPassword)}`;
268:         if (statusFilter) {
269:             url += `&status_filter=${encodeURIComponent(statusFilter)}`;
270:         }
271:         return this.request(url);
272:     },
273:     /**
274:      * Activate a user (admin only)
275:      * @param {string} userId - User ID to activate
276:      * @param {string} adminUsername - Admin username
277:      * @param {string} adminPassword - Admin password
278:      * @returns {Promise<Object>} Activation response
279:      */
280:     async adminActivateUser(userId, adminUsername, adminPassword) {
281:         return this.request(`/admin/users/${encodeURIComponent(userId)}/activate`, {
282:             method: 'POST',
283:             body: JSON.stringify({
284:                 admin_username: adminUsername,
285:                 admin_password: adminPassword,
286:             }),
287:         });
288:     },
289:     /**
290:      * Reject/delete a user (admin only)
291:      * @param {string} userId - User ID to reject
292:      * @param {string} adminUsername - Admin username
293:      * @param {string} adminPassword - Admin password
294:      * @returns {Promise<Object>} Rejection response
295:      */
296:     async adminRejectUser(userId, adminUsername, adminPassword) {
297:         return this.request(`/admin/users/${encodeURIComponent(userId)}/reject`, {
298:             method: 'POST',
299:             body: JSON.stringify({
300:                 admin_username: adminUsername,
301:                 admin_password: adminPassword,
302:             }),
303:         });
304:     },
305:     // =========================================================================
306:     // Profile (Authenticated)
307:     // =========================================================================
308:     /**
309:      * Get user profile
310:      * @param {string} username - Username
311:      * @returns {Promise<Object>} Profile response
312:      */
313:     async getProfile(username) {
314:         return this.authRequest(`/profile/${encodeURIComponent(username)}`);
315:     },
316:     /**
317:      * Update user profile
318:      * @param {string} username - Username
319:      * @param {Object} updates - Profile updates
320:      * @returns {Promise<Object>} Updated profile response
321:      */
322:     async updateProfile(username, updates) {
323:         return this.authRequest(`/profile/${encodeURIComponent(username)}`, {
324:             method: 'PUT',
325:             body: JSON.stringify(updates),
326:         });
327:     },
328:     // =========================================================================
329:     // Groups (Admin, Authenticated)
330:     // =========================================================================
331:     /**
332:      * List all groups
333:      * @param {Object} params - Query parameters (search, sort_by, sort_order)
334:      * @returns {Promise<Object>} Groups list response
335:      */
336:     async listGroups(params = {}) {
337:         const query = new URLSearchParams();
338:         if (params.search) query.set('search', params.search);
339:         if (params.sort_by) query.set('sort_by', params.sort_by);
340:         if (params.sort_order) query.set('sort_order', params.sort_order);
341:         const queryStr = query.toString();
342:         return this.authRequest(`/admin/groups${queryStr ? '?' + queryStr : ''}`);
343:     },
344:     /**
345:      * Create a new group
346:      * @param {string} name - Group name
347:      * @param {string} description - Group description
348:      * @returns {Promise<Object>} Created group response
349:      */
350:     async createGroup(name, description = '') {
351:         return this.authRequest('/admin/groups', {
352:             method: 'POST',
353:             body: JSON.stringify({ name, description }),
354:         });
355:     },
356:     /**
357:      * Get group details
358:      * @param {string} groupId - Group ID
359:      * @returns {Promise<Object>} Group details response
360:      */
361:     async getGroup(groupId) {
362:         return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`);
363:     },
364:     /**
365:      * Update a group
366:      * @param {string} groupId - Group ID
367:      * @param {Object} updates - Group updates
368:      * @returns {Promise<Object>} Updated group response
369:      */
370:     async updateGroup(groupId, updates) {
371:         return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`, {
372:             method: 'PUT',
373:             body: JSON.stringify(updates),
374:         });
375:     },
376:     /**
377:      * Delete a group
378:      * @param {string} groupId - Group ID
379:      * @returns {Promise<Object>} Deletion response
380:      */
381:     async deleteGroup(groupId) {
382:         return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`, {
383:             method: 'DELETE',
384:         });
385:     },
386:     // =========================================================================
387:     // User-Group Assignment (Admin, Authenticated)
388:     // =========================================================================
389:     /**
390:      * Get user's groups
391:      * @param {string} userId - User ID
392:      * @returns {Promise<Object>} User groups response
393:      */
394:     async getUserGroups(userId) {
395:         return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`);
396:     },
397:     /**
398:      * Assign user to groups
399:      * @param {string} userId - User ID
400:      * @param {string[]} groupIds - Array of group IDs to assign
401:      * @returns {Promise<Object>} Assignment response
402:      */
403:     async assignUserGroups(userId, groupIds) {
404:         return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`, {
405:             method: 'POST',
406:             body: JSON.stringify({ group_ids: groupIds }),
407:         });
408:     },
409:     /**
410:      * Replace user's groups
411:      * @param {string} userId - User ID
412:      * @param {string[]} groupIds - Array of group IDs to set
413:      * @returns {Promise<Object>} Assignment response
414:      */
415:     async replaceUserGroups(userId, groupIds) {
416:         return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`, {
417:             method: 'PUT',
418:             body: JSON.stringify({ group_ids: groupIds }),
419:         });
420:     },
421:     /**
422:      * Remove user from a group
423:      * @param {string} userId - User ID
424:      * @param {string} groupId - Group ID
425:      * @returns {Promise<Object>} Removal response
426:      */
427:     async removeUserFromGroup(userId, groupId) {
428:         return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups/${encodeURIComponent(groupId)}`, {
429:             method: 'DELETE',
430:         });
431:     },
432:     // =========================================================================
433:     // Enhanced Admin (Authenticated)
434:     // =========================================================================
435:     /**
436:      * List users with enhanced filtering/sorting/search
437:      * @param {Object} params - Query parameters
438:      * @returns {Promise<Object>} Users list response
439:      */
440:     async adminListUsersEnhanced(params = {}) {
441:         const query = new URLSearchParams();
442:         if (params.status_filter) query.set('status_filter', params.status_filter);
443:         if (params.group_filter) query.set('group_filter', params.group_filter);
444:         if (params.search) query.set('search', params.search);
445:         if (params.sort_by) query.set('sort_by', params.sort_by);
446:         if (params.sort_order) query.set('sort_order', params.sort_order);
447:         const queryStr = query.toString();
448:         return this.authRequest(`/admin/users/enhanced${queryStr ? '?' + queryStr : ''}`);
449:     },
450:     /**
451:      * Revoke an active user
452:      * @param {string} userId - User ID
453:      * @returns {Promise<Object>} Revoke response
454:      */
455:     async revokeUser(userId) {
456:         return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/revoke`, {
457:             method: 'POST',
458:         });
459:     },
460: };
461: /**
462:  * Custom API Error class
463:  */
464: class APIError extends Error {
465:     constructor(message, statusCode, data) {
466:         super(message);
467:         this.name = 'APIError';
468:         this.statusCode = statusCode;
469:         this.data = data;
470:     }
471:     /**
472:      * Check if error is due to authentication failure
473:      */
474:     isAuthError() {
475:         return this.statusCode === 401;
476:     }
477:     /**
478:      * Check if error is due to forbidden action (not enrolled, not active, etc.)
479:      */
480:     isForbidden() {
481:         return this.statusCode === 403;
482:     }
483:     /**
484:      * Check if error is due to user not being enrolled
485:      */
486:     isNotEnrolled() {
487:         return this.statusCode === 403;
488:     }
489:     /**
490:      * Check if error is a not found error
491:      */
492:     isNotFound() {
493:         return this.statusCode === 404;
494:     }
495:     /**
496:      * Check if error is a server error
497:      */
498:     isServerError() {
499:         return this.statusCode >= 500;
500:     }
501:     /**
502:      * Check if error is a validation error
503:      */
504:     isValidationError() {
505:         return this.statusCode === 400 || this.statusCode === 422;
506:     }
507: }
508: // Export for use in other modules
509: window.API = API;
510: window.APIError = APIError;
```

## File: application/frontend/src/js/main.js
```javascript
   1: /**
   2:  * Main application logic for LDAP 2FA Frontend
   3:  */
   4: document.addEventListener('DOMContentLoaded', () => {
   5:     // Initialize the application
   6:     App.init();
   7: });
   8: /**
   9:  * Escape HTML to prevent XSS attacks
  10:  * Uses string replacement to avoid DOM-based escaping
  11:  * @param {string} str - String to escape
  12:  * @returns {string} Escaped string
  13:  */
  14: function escapeHtml(str) {
  15:     if (!str) return '';
  16:     return String(str)
  17:         .replace(/&/g, '&amp;')
  18:         .replace(/</g, '&lt;')
  19:         .replace(/>/g, '&gt;')
  20:         .replace(/"/g, '&quot;')
  21:         .replace(/'/g, '&#039;');
  22: }
  23: const App = {
  24:     // State
  25:     smsEnabled: false,
  26:     userMfaMethod: null,
  27:     currentUser: null, // Store current signup user for verification
  28:     session: null, // Store logged in session { username, isAdmin, token }
  29:     groups: [], // Cache of groups for admin
  30:     users: [], // Cache of users for admin
  31:     sortState: { field: 'created_at', order: 'desc' },
  32:     /**
  33:      * Initialize the application
  34:      */
  35:     async init() {
  36:         this.setupTabs();
  37:         this.setupLoginForm();
  38:         this.setupSignupForm();
  39:         this.setupEnrollForm();
  40:         this.setupCopySecret();
  41:         this.setupMfaMethodSelector();
  42:         this.setupVerification();
  43:         this.setupTopBar();
  44:         this.setupProfile();
  45:         this.setupAdminUsers();
  46:         this.setupAdminGroups();
  47:         this.setupModals();
  48:         // Check if SMS is enabled
  49:         await this.checkMfaMethods();
  50:         // Check for email verification token in URL
  51:         this.checkEmailVerificationToken();
  52:         // Check for existing session
  53:         this.checkSession();
  54:     },
  55:     /**
  56:      * Check for existing session from stored token
  57:      */
  58:     checkSession() {
  59:         const token = API.getToken();
  60:         if (token) {
  61:             try {
  62:                 // Decode JWT payload (without verification)
  63:                 const payload = JSON.parse(atob(token.split('.')[1]));
  64:                 // Check if token is expired
  65:                 if (payload.exp * 1000 < Date.now()) {
  66:                     API.clearToken();
  67:                     return;
  68:                 }
  69:                 // Restore session
  70:                 this.session = {
  71:                     username: payload.username,
  72:                     isAdmin: payload.is_admin,
  73:                     token: token,
  74:                 };
  75:                 this.showLoggedInState();
  76:             } catch (e) {
  77:                 API.clearToken();
  78:             }
  79:         }
  80:     },
  81:     /**
  82:      * Show logged in state with top bar
  83:      */
  84:     showLoggedInState() {
  85:         // Show top bar
  86:         document.getElementById('top-bar').classList.remove('hidden');
  87:         document.getElementById('user-display-name').textContent = this.session.username;
  88:         // Show admin menu items if admin
  89:         if (this.session.isAdmin) {
  90:             document.getElementById('admin-menu-items').classList.remove('hidden');
  91:         }
  92:         // Hide auth header and tabs
  93:         document.getElementById('auth-header').classList.add('hidden');
  94:         document.getElementById('auth-tabs').classList.add('hidden');
  95:         // Show profile by default
  96:         this.showSection('profile');
  97:         // Adjust container for logged in state
  98:         document.getElementById('main-container').classList.add('logged-in');
  99:     },
 100:     /**
 101:      * Show logged out state
 102:      */
 103:     showLoggedOutState() {
 104:         // Hide top bar
 105:         document.getElementById('top-bar').classList.add('hidden');
 106:         document.getElementById('admin-menu-items').classList.add('hidden');
 107:         // Show auth header and tabs
 108:         document.getElementById('auth-header').classList.remove('hidden');
 109:         document.getElementById('auth-tabs').classList.remove('hidden');
 110:         // Hide all sections, show login
 111:         this.hideAllSections();
 112:         document.getElementById('login-tab').classList.add('active');
 113:         // Adjust container
 114:         document.getElementById('main-container').classList.remove('logged-in');
 115:         // Clear session
 116:         this.session = null;
 117:         API.clearToken();
 118:     },
 119:     /**
 120:      * Show a specific section
 121:      */
 122:     showSection(section) {
 123:         this.hideAllSections();
 124:         switch (section) {
 125:             case 'profile':
 126:                 document.getElementById('profile-section').classList.remove('hidden');
 127:                 this.loadProfile();
 128:                 break;
 129:             case 'admin-users':
 130:                 document.getElementById('admin-users-section').classList.remove('hidden');
 131:                 this.loadAdminUsers();
 132:                 break;
 133:             case 'admin-groups':
 134:                 document.getElementById('admin-groups-section').classList.remove('hidden');
 135:                 this.loadAdminGroups();
 136:                 break;
 137:         }
 138:     },
 139:     /**
 140:      * Hide all content sections
 141:      */
 142:     hideAllSections() {
 143:         document.querySelectorAll('.tab-content').forEach(el => {
 144:             el.classList.remove('active');
 145:             el.classList.add('hidden');
 146:         });
 147:     },
 148:     /**
 149:      * Setup top bar functionality
 150:      */
 151:     setupTopBar() {
 152:         const userMenuBtn = document.getElementById('user-menu-btn');
 153:         const userDropdown = document.getElementById('user-dropdown');
 154:         // Toggle dropdown
 155:         userMenuBtn.addEventListener('click', (e) => {
 156:             e.stopPropagation();
 157:             userDropdown.classList.toggle('hidden');
 158:         });
 159:         // Close dropdown when clicking outside
 160:         document.addEventListener('click', () => {
 161:             userDropdown.classList.add('hidden');
 162:         });
 163:         // Menu item handlers
 164:         document.getElementById('menu-profile').addEventListener('click', (e) => {
 165:             e.preventDefault();
 166:             userDropdown.classList.add('hidden');
 167:             this.showSection('profile');
 168:         });
 169:         document.getElementById('menu-admin-users').addEventListener('click', (e) => {
 170:             e.preventDefault();
 171:             userDropdown.classList.add('hidden');
 172:             this.showSection('admin-users');
 173:         });
 174:         document.getElementById('menu-admin-groups').addEventListener('click', (e) => {
 175:             e.preventDefault();
 176:             userDropdown.classList.add('hidden');
 177:             this.showSection('admin-groups');
 178:         });
 179:         document.getElementById('menu-logout').addEventListener('click', (e) => {
 180:             e.preventDefault();
 181:             userDropdown.classList.add('hidden');
 182:             this.logout();
 183:         });
 184:     },
 185:     /**
 186:      * Logout
 187:      */
 188:     logout() {
 189:         this.showLoggedOutState();
 190:         this.showStatus('Logged out successfully', 'success');
 191:     },
 192:     /**
 193:      * Check available MFA methods
 194:      */
 195:     async checkMfaMethods() {
 196:         try {
 197:             const response = await API.getMfaMethods();
 198:             this.smsEnabled = response.sms_enabled;
 199:             // Update SMS options in all forms
 200:             this.updateSmsOptions();
 201:         } catch (error) {
 202:             console.warn('Could not fetch MFA methods:', error.message);
 203:             this.smsEnabled = false;
 204:         }
 205:     },
 206:     /**
 207:      * Update SMS options based on availability
 208:      */
 209:     updateSmsOptions() {
 210:         const smsOptions = document.querySelectorAll('#sms-option, #signup-sms-option');
 211:         smsOptions.forEach(option => {
 212:             if (!this.smsEnabled) {
 213:                 option.classList.add('disabled');
 214:                 option.querySelector('input').disabled = true;
 215:                 option.querySelector('small').textContent = 'SMS not available';
 216:             } else {
 217:                 option.classList.remove('disabled');
 218:                 option.querySelector('input').disabled = false;
 219:             }
 220:         });
 221:     },
 222:     /**
 223:      * Check for email verification token in URL
 224:      */
 225:     async checkEmailVerificationToken() {
 226:         const urlParams = new URLSearchParams(window.location.search);
 227:         const token = urlParams.get('token');
 228:         const username = urlParams.get('username');
 229:         if (token && username) {
 230:             try {
 231:                 const response = await API.verifyEmail(username, token);
 232:                 this.showStatus('Email verified successfully!', 'success');
 233:                 // Clear URL params
 234:                 window.history.replaceState({}, document.title, window.location.pathname);
 235:                 // If user was signing up, update verification status
 236:                 if (this.currentUser && this.currentUser.username === username) {
 237:                     this.updateVerificationStatus(response.profile_status);
 238:                 }
 239:             } catch (error) {
 240:                 this.showStatus(error.message, 'error');
 241:             }
 242:         }
 243:     },
 244:     /**
 245:      * Setup tab navigation
 246:      */
 247:     setupTabs() {
 248:         const tabButtons = document.querySelectorAll('.tab-btn');
 249:         const tabContents = document.querySelectorAll('.tab-content');
 250:         tabButtons.forEach(button => {
 251:             button.addEventListener('click', () => {
 252:                 const targetTab = button.dataset.tab;
 253:                 // Update button states
 254:                 tabButtons.forEach(btn => btn.classList.remove('active'));
 255:                 button.classList.add('active');
 256:                 // Update content visibility
 257:                 tabContents.forEach(content => {
 258:                     content.classList.remove('active');
 259:                     content.classList.add('hidden');
 260:                     if (content.id === `${targetTab}-tab`) {
 261:                         content.classList.add('active');
 262:                         content.classList.remove('hidden');
 263:                     }
 264:                 });
 265:                 // Clear previous results
 266:                 this.clearResults();
 267:             });
 268:         });
 269:     },
 270:     /**
 271:      * Setup MFA method selector
 272:      */
 273:     setupMfaMethodSelector() {
 274:         // Enroll form
 275:         const enrollMethodRadios = document.querySelectorAll('input[name="mfa_method"]');
 276:         const phoneGroup = document.getElementById('phone-group');
 277:         const phoneInput = document.getElementById('enroll-phone');
 278:         enrollMethodRadios.forEach(radio => {
 279:             radio.addEventListener('change', () => {
 280:                 if (radio.value === 'sms') {
 281:                     phoneGroup.classList.remove('hidden');
 282:                     phoneInput.required = true;
 283:                 } else {
 284:                     phoneGroup.classList.add('hidden');
 285:                     phoneInput.required = false;
 286:                     phoneInput.value = '';
 287:                 }
 288:             });
 289:         });
 290:     },
 291:     /**
 292:      * Setup login form handling
 293:      */
 294:     setupLoginForm() {
 295:         const form = document.getElementById('login-form');
 296:         const resultContainer = document.getElementById('login-result');
 297:         const sendSmsBtn = document.getElementById('send-sms-btn');
 298:         const smsStatus = document.getElementById('sms-status');
 299:         // Send SMS code button
 300:         sendSmsBtn.addEventListener('click', async () => {
 301:             const username = form.querySelector('#login-username').value.trim();
 302:             const password = form.querySelector('#login-password').value;
 303:             if (!username || !password) {
 304:                 this.showStatus('Please enter username and password first', 'warning');
 305:                 return;
 306:             }
 307:             sendSmsBtn.disabled = true;
 308:             sendSmsBtn.textContent = 'Sending...';
 309:             try {
 310:                 const response = await API.sendSmsCode(username, password);
 311:                 smsStatus.textContent = `Code sent to ${response.phone_number}. Expires in ${response.expires_in_seconds}s`;
 312:                 smsStatus.classList.remove('hidden');
 313:                 this.showStatus('Verification code sent!', 'success');
 314:                 this.startSmsCountdown(sendSmsBtn, response.expires_in_seconds);
 315:             } catch (error) {
 316:                 this.showStatus(error.message, 'error');
 317:                 sendSmsBtn.disabled = false;
 318:                 sendSmsBtn.textContent = 'Send SMS';
 319:             }
 320:         });
 321:         // Check MFA status when username is entered
 322:         let mfaCheckTimeout;
 323:         form.querySelector('#login-username').addEventListener('blur', async (e) => {
 324:             const username = e.target.value.trim();
 325:             if (!username) return;
 326:             clearTimeout(mfaCheckTimeout);
 327:             mfaCheckTimeout = setTimeout(async () => {
 328:                 try {
 329:                     const status = await API.getMfaStatus(username);
 330:                     this.userMfaMethod = status.mfa_method;
 331:                     // Show/hide SMS button based on user's MFA method
 332:                     if (status.enrolled && status.mfa_method === 'sms') {
 333:                         sendSmsBtn.classList.remove('hidden');
 334:                         smsStatus.textContent = `SMS will be sent to ${status.phone_number}`;
 335:                         smsStatus.classList.remove('hidden');
 336:                     } else {
 337:                         sendSmsBtn.classList.add('hidden');
 338:                         smsStatus.classList.add('hidden');
 339:                     }
 340:                 } catch (error) {
 341:                     sendSmsBtn.classList.add('hidden');
 342:                     smsStatus.classList.add('hidden');
 343:                 }
 344:             }, 500);
 345:         });
 346:         form.addEventListener('submit', async (e) => {
 347:             e.preventDefault();
 348:             const submitBtn = form.querySelector('button[type="submit"]');
 349:             const username = form.querySelector('#login-username').value.trim();
 350:             const password = form.querySelector('#login-password').value;
 351:             const verificationCode = form.querySelector('#login-code').value.trim();
 352:             if (!/^\d{6}$/.test(verificationCode)) {
 353:                 this.showStatus('Please enter a valid 6-digit code', 'error');
 354:                 return;
 355:             }
 356:             submitBtn.classList.add('loading');
 357:             submitBtn.disabled = true;
 358:             resultContainer.classList.add('hidden');
 359:             try {
 360:                 const response = await API.login(username, password, verificationCode);
 361:                 // Store session
 362:                 if (response.token) {
 363:                     API.setToken(response.token);
 364:                     this.session = {
 365:                         username: response.username || username,
 366:                         isAdmin: response.is_admin,
 367:                         token: response.token,
 368:                     };
 369:                     this.showStatus('Login successful!', 'success');
 370:                     form.reset();
 371:                     sendSmsBtn.classList.add('hidden');
 372:                     smsStatus.classList.add('hidden');
 373:                     // Show logged in state
 374:                     this.showLoggedInState();
 375:                 } else {
 376:                     resultContainer.innerHTML = `
 377:                         <h3>✅ Login Successful!</h3>
 378:                         <p>${response.message}</p>
 379:                     `;
 380:                     resultContainer.className = 'result-container success';
 381:                     resultContainer.classList.remove('hidden');
 382:                 }
 383:             } catch (error) {
 384:                 resultContainer.innerHTML = `
 385:                     <h3>❌ Login Failed</h3>
 386:                     <p>${escapeHtml(error.message)}</p>
 387:                 `;
 388:                 resultContainer.className = 'result-container error';
 389:                 resultContainer.classList.remove('hidden');
 390:                 this.showStatus(error.message, 'error');
 391:             } finally {
 392:                 submitBtn.classList.remove('loading');
 393:                 submitBtn.disabled = false;
 394:             }
 395:         });
 396:     },
 397:     /**
 398:      * Setup signup form handling
 399:      */
 400:     setupSignupForm() {
 401:         const form = document.getElementById('signup-form');
 402:         const resultContainer = document.getElementById('signup-result');
 403:         const verificationPanel = document.getElementById('verification-status');
 404:         form.addEventListener('submit', async (e) => {
 405:             e.preventDefault();
 406:             const submitBtn = form.querySelector('button[type="submit"]');
 407:             const password = form.querySelector('#signup-password').value;
 408:             const confirmPassword = form.querySelector('#signup-confirm-password').value;
 409:             // Validate passwords match
 410:             if (password !== confirmPassword) {
 411:                 this.showStatus('Passwords do not match', 'error');
 412:                 return;
 413:             }
 414:             const userData = {
 415:                 username: form.querySelector('#signup-username').value.trim().toLowerCase(),
 416:                 email: form.querySelector('#signup-email').value.trim().toLowerCase(),
 417:                 firstName: form.querySelector('#signup-firstname').value.trim(),
 418:                 lastName: form.querySelector('#signup-lastname').value.trim(),
 419:                 phoneCountryCode: form.querySelector('#signup-country-code').value,
 420:                 phoneNumber: form.querySelector('#signup-phone').value.trim(),
 421:                 password: password,
 422:                 mfaMethod: form.querySelector('input[name="signup_mfa_method"]:checked').value,
 423:             };
 424:             submitBtn.classList.add('loading');
 425:             submitBtn.disabled = true;
 426:             resultContainer.classList.add('hidden');
 427:             verificationPanel.classList.add('hidden');
 428:             try {
 429:                 const response = await API.signup(userData);
 430:                 this.currentUser = {
 431:                     username: userData.username,
 432:                     email: userData.email,
 433:                 };
 434:                 // Show verification panel
 435:                 form.classList.add('hidden');
 436:                 verificationPanel.classList.remove('hidden');
 437:                 // Update verification hints
 438:                 if (response.email_verification_sent) {
 439:                     document.getElementById('email-verify-hint').textContent =
 440:                         `Check ${userData.email} for verification link`;
 441:                 }
 442:                 if (response.phone_verification_sent) {
 443:                     document.getElementById('phone-verify-hint').textContent =
 444:                         `Enter code sent to ${userData.phoneCountryCode}${userData.phoneNumber}`;
 445:                 }
 446:                 this.showStatus('Account created! Please verify your email and phone.', 'success');
 447:             } catch (error) {
 448:                 resultContainer.innerHTML = `
 449:                     <h3>❌ Signup Failed</h3>
 450:                     <p>${escapeHtml(error.message)}</p>
 451:                 `;
 452:                 resultContainer.className = 'result-container error';
 453:                 resultContainer.classList.remove('hidden');
 454:                 this.showStatus(error.message, 'error');
 455:             } finally {
 456:                 submitBtn.classList.remove('loading');
 457:                 submitBtn.disabled = false;
 458:             }
 459:         });
 460:     },
 461:     /**
 462:      * Setup verification functionality
 463:      */
 464:     setupVerification() {
 465:         const resendEmailBtn = document.getElementById('resend-email-btn');
 466:         const resendPhoneBtn = document.getElementById('resend-phone-btn');
 467:         const verifyPhoneBtn = document.getElementById('verify-phone-btn');
 468:         const phoneCodeInput = document.getElementById('phone-verify-code');
 469:         // Resend email verification
 470:         resendEmailBtn.addEventListener('click', async () => {
 471:             if (!this.currentUser) return;
 472:             resendEmailBtn.disabled = true;
 473:             resendEmailBtn.textContent = 'Sending...';
 474:             try {
 475:                 await API.resendVerification(this.currentUser.username, 'email');
 476:                 this.showStatus('Verification email sent!', 'success');
 477:                 // Countdown before allowing another resend
 478:                 this.startResendCountdown(resendEmailBtn, 60);
 479:             } catch (error) {
 480:                 this.showStatus(error.message, 'error');
 481:                 resendEmailBtn.disabled = false;
 482:                 resendEmailBtn.textContent = 'Resend';
 483:             }
 484:         });
 485:         // Resend phone verification
 486:         resendPhoneBtn.addEventListener('click', async () => {
 487:             if (!this.currentUser) return;
 488:             resendPhoneBtn.disabled = true;
 489:             resendPhoneBtn.textContent = 'Sending...';
 490:             try {
 491:                 await API.resendVerification(this.currentUser.username, 'phone');
 492:                 this.showStatus('Verification code sent!', 'success');
 493:                 this.startResendCountdown(resendPhoneBtn, 60);
 494:             } catch (error) {
 495:                 this.showStatus(error.message, 'error');
 496:                 resendPhoneBtn.disabled = false;
 497:                 resendPhoneBtn.textContent = 'Resend';
 498:             }
 499:         });
 500:         // Verify phone
 501:         verifyPhoneBtn.addEventListener('click', async () => {
 502:             if (!this.currentUser) return;
 503:             const code = phoneCodeInput.value.trim();
 504:             if (!/^\d{6}$/.test(code)) {
 505:                 this.showStatus('Please enter a valid 6-digit code', 'error');
 506:                 return;
 507:             }
 508:             verifyPhoneBtn.disabled = true;
 509:             verifyPhoneBtn.textContent = 'Verifying...';
 510:             try {
 511:                 const response = await API.verifyPhone(this.currentUser.username, code);
 512:                 document.getElementById('phone-verify-status').textContent = '✅';
 513:                 document.getElementById('phone-verify-hint').textContent = 'Verified!';
 514:                 phoneCodeInput.disabled = true;
 515:                 verifyPhoneBtn.classList.add('hidden');
 516:                 this.showStatus('Phone verified successfully!', 'success');
 517:                 this.updateVerificationStatus(response.profile_status);
 518:             } catch (error) {
 519:                 this.showStatus(error.message, 'error');
 520:                 verifyPhoneBtn.disabled = false;
 521:                 verifyPhoneBtn.textContent = 'Verify';
 522:             }
 523:         });
 524:     },
 525:     /**
 526:      * Update verification status display
 527:      */
 528:     updateVerificationStatus(status) {
 529:         if (status === 'complete') {
 530:             // All verifications complete
 531:             document.getElementById('email-verify-status').textContent = '✅';
 532:             document.getElementById('phone-verify-status').textContent = '✅';
 533:             document.getElementById('verification-complete').classList.remove('hidden');
 534:             document.querySelector('.phone-verify-input').classList.add('hidden');
 535:             document.querySelectorAll('.verification-item button').forEach(btn => {
 536:                 btn.classList.add('hidden');
 537:             });
 538:         }
 539:     },
 540:     /**
 541:      * Start countdown for resend buttons
 542:      */
 543:     startResendCountdown(button, seconds) {
 544:         let remaining = seconds;
 545:         button.disabled = true;
 546:         const interval = setInterval(() => {
 547:             remaining--;
 548:             button.textContent = `Resend (${remaining}s)`;
 549:             if (remaining <= 0) {
 550:                 clearInterval(interval);
 551:                 button.textContent = 'Resend';
 552:                 button.disabled = false;
 553:             }
 554:         }, 1000);
 555:     },
 556:     /**
 557:      * Start countdown for SMS resend button
 558:      */
 559:     startSmsCountdown(button, seconds) {
 560:         let remaining = seconds;
 561:         button.disabled = true;
 562:         const interval = setInterval(() => {
 563:             remaining--;
 564:             button.textContent = `Resend (${remaining}s)`;
 565:             if (remaining <= 0) {
 566:                 clearInterval(interval);
 567:                 button.textContent = 'Send SMS';
 568:                 button.disabled = false;
 569:             }
 570:         }, 1000);
 571:     },
 572:     /**
 573:      * Setup enrollment form handling
 574:      */
 575:     setupEnrollForm() {
 576:         const form = document.getElementById('enroll-form');
 577:         const resultContainer = document.getElementById('enroll-result');
 578:         const qrSection = document.getElementById('qr-section');
 579:         const smsSection = document.getElementById('sms-enroll-section');
 580:         const qrCodeDiv = document.getElementById('qr-code');
 581:         const secretCode = document.getElementById('secret-code');
 582:         const enrolledPhone = document.getElementById('enrolled-phone');
 583:         form.addEventListener('submit', async (e) => {
 584:             e.preventDefault();
 585:             const submitBtn = form.querySelector('button[type="submit"]');
 586:             const username = form.querySelector('#enroll-username').value.trim();
 587:             const password = form.querySelector('#enroll-password').value;
 588:             const mfaMethod = form.querySelector('input[name="mfa_method"]:checked').value;
 589:             const phoneNumber = form.querySelector('#enroll-phone').value.trim();
 590:             if (mfaMethod === 'sms' && !phoneNumber) {
 591:                 this.showStatus('Please enter a phone number for SMS verification', 'error');
 592:                 return;
 593:             }
 594:             submitBtn.classList.add('loading');
 595:             submitBtn.disabled = true;
 596:             resultContainer.classList.add('hidden');
 597:             qrSection.classList.add('hidden');
 598:             smsSection.classList.add('hidden');
 599:             try {
 600:                 const response = await API.enroll(username, password, mfaMethod, phoneNumber);
 601:                 if (response.success) {
 602:                     resultContainer.classList.remove('hidden');
 603:                     if (response.mfa_method === 'totp' && response.otpauth_uri) {
 604:                         qrCodeDiv.innerHTML = '';
 605:                         await QRCode.toCanvas(qrCodeDiv, response.otpauth_uri, {
 606:                             width: 200,
 607:                             margin: 2,
 608:                             color: {
 609:                                 dark: '#1e293b',
 610:                                 light: '#ffffff'
 611:                             }
 612:                         });
 613:                         secretCode.textContent = response.secret;
 614:                         qrSection.classList.remove('hidden');
 615:                         this.showStatus('MFA enrollment successful! Scan the QR code.', 'success');
 616:                     } else if (response.mfa_method === 'sms') {
 617:                         enrolledPhone.textContent = response.phone_number;
 618:                         smsSection.classList.remove('hidden');
 619:                         this.showStatus('SMS verification setup complete!', 'success');
 620:                     }
 621:                     form.querySelector('#enroll-password').value = '';
 622:                 } else {
 623:                     throw new Error(response.message || 'Enrollment failed');
 624:                 }
 625:             } catch (error) {
 626:                 resultContainer.innerHTML = `
 627:                     <div class="result-container error">
 628:                         <h3>❌ Enrollment Failed</h3>
 629:                         <p>${escapeHtml(error.message)}</p>
 630:                     </div>
 631:                 `;
 632:                 resultContainer.classList.remove('hidden');
 633:                 qrSection.classList.add('hidden');
 634:                 smsSection.classList.add('hidden');
 635:                 this.showStatus(error.message, 'error');
 636:             } finally {
 637:                 submitBtn.classList.remove('loading');
 638:                 submitBtn.disabled = false;
 639:             }
 640:         });
 641:     },
 642:     /**
 643:      * Setup copy secret button
 644:      */
 645:     setupCopySecret() {
 646:         const copyBtn = document.getElementById('copy-secret');
 647:         const secretCode = document.getElementById('secret-code');
 648:         copyBtn.addEventListener('click', async () => {
 649:             const secret = secretCode.textContent;
 650:             try {
 651:                 await navigator.clipboard.writeText(secret);
 652:                 this.showStatus('Secret copied to clipboard!', 'success');
 653:                 const originalText = copyBtn.textContent;
 654:                 copyBtn.textContent = 'Copied!';
 655:                 setTimeout(() => {
 656:                     copyBtn.textContent = originalText;
 657:                 }, 2000);
 658:             } catch (err) {
 659:                 // Fallback for older browsers
 660:                 const textArea = document.createElement('textarea');
 661:                 textArea.value = secret;
 662:                 document.body.appendChild(textArea);
 663:                 textArea.select();
 664:                 document.execCommand('copy');
 665:                 document.body.removeChild(textArea);
 666:                 this.showStatus('Secret copied to clipboard!', 'success');
 667:             }
 668:         });
 669:     },
 670:     /**
 671:      * Setup profile functionality
 672:      */
 673:     setupProfile() {
 674:         const form = document.getElementById('profile-form');
 675:         form.addEventListener('submit', async (e) => {
 676:             e.preventDefault();
 677:             if (!this.session) return;
 678:             const submitBtn = form.querySelector('button[type="submit"]');
 679:             submitBtn.classList.add('loading');
 680:             submitBtn.disabled = true;
 681:             const updates = {};
 682:             const firstName = document.getElementById('profile-firstname').value.trim();
 683:             const lastName = document.getElementById('profile-lastname').value.trim();
 684:             const email = document.getElementById('profile-email').value.trim();
 685:             const phoneCountryCode = document.getElementById('profile-country-code').value;
 686:             const phoneNumber = document.getElementById('profile-phone').value.trim();
 687:             if (firstName) updates.first_name = firstName;
 688:             if (lastName) updates.last_name = lastName;
 689:             if (email && !document.getElementById('profile-email').readOnly) {
 690:                 updates.email = email;
 691:             }
 692:             if (!document.getElementById('profile-phone').readOnly) {
 693:                 updates.phone_country_code = phoneCountryCode;
 694:                 updates.phone_number = phoneNumber;
 695:             }
 696:             try {
 697:                 await API.updateProfile(this.session.username, updates);
 698:                 this.showStatus('Profile updated successfully', 'success');
 699:             } catch (error) {
 700:                 this.showStatus(error.message, 'error');
 701:             } finally {
 702:                 submitBtn.classList.remove('loading');
 703:                 submitBtn.disabled = false;
 704:             }
 705:         });
 706:     },
 707:     /**
 708:      * Load profile data
 709:      */
 710:     async loadProfile() {
 711:         if (!this.session) return;
 712:         try {
 713:             const profile = await API.getProfile(this.session.username);
 714:             document.getElementById('profile-username').value = profile.username;
 715:             document.getElementById('profile-firstname').value = profile.first_name;
 716:             document.getElementById('profile-lastname').value = profile.last_name;
 717:             document.getElementById('profile-email').value = profile.email;
 718:             document.getElementById('profile-country-code').value = profile.phone_country_code;
 719:             document.getElementById('profile-phone').value = profile.phone_number;
 720:             document.getElementById('profile-mfa').value = profile.mfa_method.toUpperCase();
 721:             document.getElementById('profile-status').value = profile.status.toUpperCase();
 722:             // Set read-only based on verification status
 723:             const emailInput = document.getElementById('profile-email');
 724:             const phoneInput = document.getElementById('profile-phone');
 725:             const countryCodeSelect = document.getElementById('profile-country-code');
 726:             if (profile.email_verified) {
 727:                 emailInput.readOnly = true;
 728:                 emailInput.classList.add('readonly-input');
 729:                 document.getElementById('profile-email-hint').textContent = 'Email cannot be changed after verification';
 730:             } else {
 731:                 emailInput.readOnly = false;
 732:                 emailInput.classList.remove('readonly-input');
 733:                 document.getElementById('profile-email-hint').textContent = '';
 734:             }
 735:             if (profile.phone_verified) {
 736:                 phoneInput.readOnly = true;
 737:                 phoneInput.classList.add('readonly-input');
 738:                 countryCodeSelect.disabled = true;
 739:                 document.getElementById('profile-phone-hint').textContent = 'Phone cannot be changed after verification';
 740:             } else {
 741:                 phoneInput.readOnly = false;
 742:                 phoneInput.classList.remove('readonly-input');
 743:                 countryCodeSelect.disabled = false;
 744:                 document.getElementById('profile-phone-hint').textContent = '';
 745:             }
 746:             // Display groups
 747:             const groupsContainer = document.getElementById('profile-groups');
 748:             if (profile.groups && profile.groups.length > 0) {
 749:                 groupsContainer.innerHTML = profile.groups.map(g =>
 750:                     `<span class="group-badge">${g.name}</span>`
 751:                 ).join('');
 752:             } else {
 753:                 groupsContainer.innerHTML = '<span class="no-groups">No groups assigned</span>';
 754:             }
 755:         } catch (error) {
 756:             this.showStatus('Failed to load profile', 'error');
 757:         }
 758:     },
 759:     /**
 760:      * Setup admin users functionality
 761:      */
 762:     setupAdminUsers() {
 763:         const searchInput = document.getElementById('users-search');
 764:         const statusFilter = document.getElementById('users-status-filter');
 765:         const groupFilter = document.getElementById('users-group-filter');
 766:         const refreshBtn = document.getElementById('users-refresh-btn');
 767:         // Search
 768:         let searchTimeout;
 769:         searchInput.addEventListener('input', () => {
 770:             clearTimeout(searchTimeout);
 771:             searchTimeout = setTimeout(() => this.loadAdminUsers(), 300);
 772:         });
 773:         // Filters
 774:         statusFilter.addEventListener('change', () => this.loadAdminUsers());
 775:         groupFilter.addEventListener('change', () => this.loadAdminUsers());
 776:         // Refresh
 777:         refreshBtn.addEventListener('click', () => this.loadAdminUsers());
 778:         // Sortable headers
 779:         document.querySelectorAll('#users-table th.sortable').forEach(th => {
 780:             th.addEventListener('click', () => {
 781:                 const field = th.dataset.sort;
 782:                 if (this.sortState.field === field) {
 783:                     this.sortState.order = this.sortState.order === 'asc' ? 'desc' : 'asc';
 784:                 } else {
 785:                     this.sortState.field = field;
 786:                     this.sortState.order = 'asc';
 787:                 }
 788:                 this.updateSortIndicators('users-table');
 789:                 this.loadAdminUsers();
 790:             });
 791:         });
 792:     },
 793:     /**
 794:      * Load admin users list
 795:      */
 796:     async loadAdminUsers() {
 797:         if (!this.session || !this.session.isAdmin) return;
 798:         const tableBody = document.getElementById('users-table-body');
 799:         const loading = document.getElementById('users-loading');
 800:         const empty = document.getElementById('users-empty');
 801:         loading.classList.remove('hidden');
 802:         empty.classList.add('hidden');
 803:         tableBody.innerHTML = '';
 804:         try {
 805:             const params = {
 806:                 status_filter: document.getElementById('users-status-filter').value || undefined,
 807:                 group_filter: document.getElementById('users-group-filter').value || undefined,
 808:                 search: document.getElementById('users-search').value || undefined,
 809:                 sort_by: this.sortState.field,
 810:                 sort_order: this.sortState.order,
 811:             };
 812:             const response = await API.adminListUsersEnhanced(params);
 813:             this.users = response.users;
 814:             // Also load groups for filter dropdown
 815:             await this.loadGroupsForFilter();
 816:             if (response.users.length === 0) {
 817:                 empty.classList.remove('hidden');
 818:             } else {
 819:                 tableBody.innerHTML = response.users.map(user => `
 820:                     <tr>
 821:                         <td>${user.first_name} ${user.last_name}</td>
 822:                         <td>${user.username}</td>
 823:                         <td>${user.email}</td>
 824:                         <td><span class="status-badge status-${user.status}">${user.status.toUpperCase()}</span></td>
 825:                         <td>${user.groups.map(g => `<span class="group-badge-small">${g.name}</span>`).join(' ') || '-'}</td>
 826:                         <td>${new Date(user.created_at).toLocaleDateString()}</td>
 827:                         <td class="action-buttons">
 828:                             ${user.status === 'complete' ? `
 829:                                 <button class="btn btn-primary btn-xs" onclick="App.showApproveModal('${user.id}', '${user.username}')">Approve</button>
 830:                                 <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Reject this user?', () => App.rejectUser('${user.id}'))">Reject</button>
 831:                             ` : ''}
 832:                             ${user.status === 'active' ? `
 833:                                 <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Revoke this user?', () => App.revokeUser('${user.id}'))">Revoke</button>
 834:                             ` : ''}
 835:                         </td>
 836:                     </tr>
 837:                 `).join('');
 838:             }
 839:         } catch (error) {
 840:             this.showStatus(error.message, 'error');
 841:         } finally {
 842:             loading.classList.add('hidden');
 843:         }
 844:     },
 845:     /**
 846:      * Load groups for filter dropdown
 847:      */
 848:     async loadGroupsForFilter() {
 849:         try {
 850:             const response = await API.listGroups();
 851:             this.groups = response.groups;
 852:             const filterSelect = document.getElementById('users-group-filter');
 853:             const currentValue = filterSelect.value;
 854:             // Keep first option, update rest
 855:             filterSelect.innerHTML = '<option value="">All Groups</option>' +
 856:                 response.groups.map(g => `<option value="${g.id}">${g.name}</option>`).join('');
 857:             filterSelect.value = currentValue;
 858:         } catch (error) {
 859:             console.warn('Could not load groups for filter', error);
 860:         }
 861:     },
 862:     /**
 863:      * Setup admin groups functionality
 864:      */
 865:     setupAdminGroups() {
 866:         const searchInput = document.getElementById('groups-search');
 867:         const createBtn = document.getElementById('create-group-btn');
 868:         // Search
 869:         let searchTimeout;
 870:         searchInput.addEventListener('input', () => {
 871:             clearTimeout(searchTimeout);
 872:             searchTimeout = setTimeout(() => this.loadAdminGroups(), 300);
 873:         });
 874:         // Create button
 875:         createBtn.addEventListener('click', () => this.showGroupModal());
 876:         // Sortable headers
 877:         document.querySelectorAll('#groups-table th.sortable').forEach(th => {
 878:             th.addEventListener('click', () => {
 879:                 const field = th.dataset.sort;
 880:                 if (this.sortState.field === field) {
 881:                     this.sortState.order = this.sortState.order === 'asc' ? 'desc' : 'asc';
 882:                 } else {
 883:                     this.sortState.field = field;
 884:                     this.sortState.order = 'asc';
 885:                 }
 886:                 this.updateSortIndicators('groups-table');
 887:                 this.loadAdminGroups();
 888:             });
 889:         });
 890:     },
 891:     /**
 892:      * Load admin groups list
 893:      */
 894:     async loadAdminGroups() {
 895:         if (!this.session || !this.session.isAdmin) return;
 896:         const tableBody = document.getElementById('groups-table-body');
 897:         const loading = document.getElementById('groups-loading');
 898:         const empty = document.getElementById('groups-empty');
 899:         loading.classList.remove('hidden');
 900:         empty.classList.add('hidden');
 901:         tableBody.innerHTML = '';
 902:         try {
 903:             const params = {
 904:                 search: document.getElementById('groups-search').value || undefined,
 905:                 sort_by: this.sortState.field,
 906:                 sort_order: this.sortState.order,
 907:             };
 908:             const response = await API.listGroups(params);
 909:             this.groups = response.groups;
 910:             if (response.groups.length === 0) {
 911:                 empty.classList.remove('hidden');
 912:             } else {
 913:                 tableBody.innerHTML = response.groups.map(group => `
 914:                     <tr>
 915:                         <td><strong>${group.name}</strong></td>
 916:                         <td>${group.description || '-'}</td>
 917:                         <td>
 918:                             <a href="#" onclick="App.showGroupMembers('${group.id}', '${group.name}'); return false;">
 919:                                 ${group.member_count} members
 920:                             </a>
 921:                         </td>
 922:                         <td>${new Date(group.created_at).toLocaleDateString()}</td>
 923:                         <td class="action-buttons">
 924:                             <button class="btn btn-secondary btn-xs" onclick="App.showGroupModal('${group.id}')">Edit</button>
 925:                             <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Delete this group?', () => App.deleteGroup('${group.id}'))">Delete</button>
 926:                         </td>
 927:                     </tr>
 928:                 `).join('');
 929:             }
 930:         } catch (error) {
 931:             this.showStatus(error.message, 'error');
 932:         } finally {
 933:             loading.classList.add('hidden');
 934:         }
 935:     },
 936:     /**
 937:      * Update sort indicators in table headers
 938:      */
 939:     updateSortIndicators(tableId) {
 940:         document.querySelectorAll(`#${tableId} th.sortable`).forEach(th => {
 941:             th.classList.remove('sort-asc', 'sort-desc');
 942:             if (th.dataset.sort === this.sortState.field) {
 943:                 th.classList.add(`sort-${this.sortState.order}`);
 944:             }
 945:         });
 946:     },
 947:     /**
 948:      * Setup modals
 949:      */
 950:     setupModals() {
 951:         const overlay = document.getElementById('modal-overlay');
 952:         // Close buttons
 953:         document.querySelectorAll('[data-close-modal]').forEach(btn => {
 954:             btn.addEventListener('click', () => this.closeModals());
 955:         });
 956:         // Close on overlay click
 957:         overlay.addEventListener('click', (e) => {
 958:             if (e.target === overlay) {
 959:                 this.closeModals();
 960:             }
 961:         });
 962:         // Group modal form
 963:         document.getElementById('group-modal-form').addEventListener('submit', async (e) => {
 964:             e.preventDefault();
 965:             await this.saveGroup();
 966:         });
 967:         // Approve modal form
 968:         document.getElementById('approve-modal-form').addEventListener('submit', async (e) => {
 969:             e.preventDefault();
 970:             await this.approveUser();
 971:         });
 972:     },
 973:     /**
 974:      * Close all modals
 975:      */
 976:     closeModals() {
 977:         document.getElementById('modal-overlay').classList.add('hidden');
 978:         document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
 979:     },
 980:     /**
 981:      * Show group create/edit modal
 982:      */
 983:     async showGroupModal(groupId = null) {
 984:         const modal = document.getElementById('group-modal');
 985:         const title = document.getElementById('group-modal-title');
 986:         const nameInput = document.getElementById('group-name');
 987:         const descInput = document.getElementById('group-description');
 988:         if (groupId) {
 989:             title.textContent = 'Edit Group';
 990:             try {
 991:                 const group = await API.getGroup(groupId);
 992:                 nameInput.value = group.name;
 993:                 descInput.value = group.description || '';
 994:                 modal.dataset.groupId = groupId;
 995:             } catch (error) {
 996:                 this.showStatus(error.message, 'error');
 997:                 return;
 998:             }
 999:         } else {
1000:             title.textContent = 'Create Group';
1001:             nameInput.value = '';
1002:             descInput.value = '';
1003:             delete modal.dataset.groupId;
1004:         }
1005:         document.getElementById('modal-overlay').classList.remove('hidden');
1006:         modal.classList.remove('hidden');
1007:         nameInput.focus();
1008:     },
1009:     /**
1010:      * Save group (create or update)
1011:      */
1012:     async saveGroup() {
1013:         const modal = document.getElementById('group-modal');
1014:         const groupId = modal.dataset.groupId;
1015:         const name = document.getElementById('group-name').value.trim();
1016:         const description = document.getElementById('group-description').value.trim();
1017:         if (!name) {
1018:             this.showStatus('Group name is required', 'error');
1019:             return;
1020:         }
1021:         try {
1022:             if (groupId) {
1023:                 await API.updateGroup(groupId, { name, description });
1024:                 this.showStatus('Group updated successfully', 'success');
1025:             } else {
1026:                 await API.createGroup(name, description);
1027:                 this.showStatus('Group created successfully', 'success');
1028:             }
1029:             this.closeModals();
1030:             this.loadAdminGroups();
1031:         } catch (error) {
1032:             this.showStatus(error.message, 'error');
1033:         }
1034:     },
1035:     /**
1036:      * Delete group
1037:      */
1038:     async deleteGroup(groupId) {
1039:         try {
1040:             await API.deleteGroup(groupId);
1041:             this.showStatus('Group deleted successfully', 'success');
1042:             this.loadAdminGroups();
1043:         } catch (error) {
1044:             this.showStatus(error.message, 'error');
1045:         }
1046:     },
1047:     /**
1048:      * Show group members modal
1049:      */
1050:     async showGroupMembers(groupId, groupName) {
1051:         const modal = document.getElementById('members-modal');
1052:         const title = document.getElementById('members-modal-title');
1053:         const membersList = document.getElementById('members-list');
1054:         title.textContent = `Members of ${groupName}`;
1055:         membersList.innerHTML = '<div class="loading-spinner">Loading...</div>';
1056:         document.getElementById('modal-overlay').classList.remove('hidden');
1057:         modal.classList.remove('hidden');
1058:         try {
1059:             const group = await API.getGroup(groupId);
1060:             if (group.members.length === 0) {
1061:                 membersList.innerHTML = '<div class="empty-state">No members in this group</div>';
1062:             } else {
1063:                 membersList.innerHTML = group.members.map(m => `
1064:                     <div class="member-item">
1065:                         <span class="member-name">${m.full_name}</span>
1066:                         <span class="member-username">@${m.username}</span>
1067:                     </div>
1068:                 `).join('');
1069:             }
1070:         } catch (error) {
1071:             membersList.innerHTML = `<div class="error-message">${escapeHtml(error.message)}</div>`;
1072:         }
1073:     },
1074:     /**
1075:      * Show approve user modal with group selection
1076:      */
1077:     async showApproveModal(userId, username) {
1078:         const modal = document.getElementById('approve-modal');
1079:         const userNameEl = document.getElementById('approve-user-name');
1080:         const groupsList = document.getElementById('approve-groups-list');
1081:         userNameEl.textContent = username;
1082:         modal.dataset.userId = userId;
1083:         // Load groups
1084:         groupsList.innerHTML = '<div class="loading-spinner">Loading groups...</div>';
1085:         document.getElementById('modal-overlay').classList.remove('hidden');
1086:         modal.classList.remove('hidden');
1087:         try {
1088:             const response = await API.listGroups();
1089:             if (response.groups.length === 0) {
1090:                 groupsList.innerHTML = '<div class="warning-message">No groups available. Please create a group first.</div>';
1091:             } else {
1092:                 groupsList.innerHTML = response.groups.map(g => `
1093:                     <label class="checkbox-option">
1094:                         <input type="checkbox" name="approve_group" value="${g.id}">
1095:                         <span>${g.name}</span>
1096:                     </label>
1097:                 `).join('');
1098:             }
1099:         } catch (error) {
1100:             groupsList.innerHTML = `<div class="error-message">${escapeHtml(error.message)}</div>`;
1101:         }
1102:     },
1103:     /**
1104:      * Approve user (from modal)
1105:      */
1106:     async approveUser() {
1107:         const modal = document.getElementById('approve-modal');
1108:         const userId = modal.dataset.userId;
1109:         const selectedGroups = Array.from(
1110:             document.querySelectorAll('input[name="approve_group"]:checked')
1111:         ).map(cb => cb.value);
1112:         if (selectedGroups.length === 0) {
1113:             this.showStatus('Please select at least one group', 'error');
1114:             return;
1115:         }
1116:         try {
1117:             // First assign groups
1118:             await API.assignUserGroups(userId, selectedGroups);
1119:             // Then activate (using the old API since we don't have JWT-based activation yet)
1120:             // For now, we need to use the legacy admin credentials
1121:             // This would need to be updated to use JWT-based activation
1122:             this.showStatus('User approved and assigned to groups. Please complete activation via legacy admin panel.', 'warning');
1123:             this.closeModals();
1124:             this.loadAdminUsers();
1125:         } catch (error) {
1126:             this.showStatus(error.message, 'error');
1127:         }
1128:     },
1129:     /**
1130:      * Reject user
1131:      */
1132:     async rejectUser(userId) {
1133:         try {
1134:             // Note: This uses legacy auth - would need JWT-based version
1135:             this.showStatus('Please use legacy admin panel to reject users for now.', 'warning');
1136:         } catch (error) {
1137:             this.showStatus(error.message, 'error');
1138:         }
1139:     },
1140:     /**
1141:      * Revoke user
1142:      */
1143:     async revokeUser(userId) {
1144:         try {
1145:             await API.revokeUser(userId);
1146:             this.showStatus('User revoked successfully', 'success');
1147:             this.loadAdminUsers();
1148:         } catch (error) {
1149:             this.showStatus(error.message, 'error');
1150:         }
1151:     },
1152:     /**
1153:      * Show confirmation dialog
1154:      */
1155:     confirmAction(message, callback) {
1156:         const modal = document.getElementById('confirm-modal');
1157:         const messageEl = document.getElementById('confirm-modal-message');
1158:         const okBtn = document.getElementById('confirm-modal-ok');
1159:         messageEl.textContent = message;
1160:         // Remove old event listener
1161:         const newOkBtn = okBtn.cloneNode(true);
1162:         okBtn.parentNode.replaceChild(newOkBtn, okBtn);
1163:         newOkBtn.addEventListener('click', () => {
1164:             this.closeModals();
1165:             callback();
1166:         });
1167:         document.getElementById('modal-overlay').classList.remove('hidden');
1168:         modal.classList.remove('hidden');
1169:     },
1170:     /**
1171:      * Show status message
1172:      * @param {string} message - Message to display
1173:      * @param {string} type - Message type (success, error, warning)
1174:      */
1175:     showStatus(message, type = 'success') {
1176:         const statusEl = document.getElementById('status-message');
1177:         statusEl.textContent = message;
1178:         statusEl.className = `status-message ${type}`;
1179:         statusEl.classList.remove('hidden');
1180:         setTimeout(() => {
1181:             statusEl.classList.add('hidden');
1182:         }, 4000);
1183:     },
1184:     /**
1185:      * Clear all result containers
1186:      */
1187:     clearResults() {
1188:         document.getElementById('login-result').classList.add('hidden');
1189:         document.getElementById('signup-result').classList.add('hidden');
1190:         document.getElementById('enroll-result').classList.add('hidden');
1191:         document.getElementById('qr-section').classList.add('hidden');
1192:         document.getElementById('sms-enroll-section').classList.add('hidden');
1193:         // Reset SMS button state
1194:         const sendSmsBtn = document.getElementById('send-sms-btn');
1195:         const smsStatus = document.getElementById('sms-status');
1196:         sendSmsBtn.classList.add('hidden');
1197:         smsStatus.classList.add('hidden');
1198:     }
1199: };
1200: // Export for use in console/testing
1201: window.App = App;
```

## File: application/frontend/src/index.html
```html
  1: <!DOCTYPE html>
  2: <html lang="en">
  3: <head>
  4:     <meta charset="UTF-8">
  5:     <meta name="viewport" content="width=device-width, initial-scale=1.0">
  6:     <meta name="description" content="LDAP 2FA Authentication Application">
  7:     <title>LDAP 2FA Authentication</title>
  8:     <link rel="stylesheet" href="/css/styles.css">
  9:     <!-- QR Code Library -->
 10:     <script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"></script>
 11: </head>
 12: <body>
 13:     <!-- Top Navigation Bar (shown when logged in) -->
 14:     <header id="top-bar" class="top-bar hidden">
 15:         <div class="top-bar-content">
 16:             <div class="top-bar-brand">
 17:                 <span class="brand-icon">🔐</span>
 18:                 <span class="brand-text">LDAP 2FA</span>
 19:             </div>
 20:             <div class="top-bar-user">
 21:                 <button id="user-menu-btn" class="user-menu-btn">
 22:                     <span id="user-display-name" class="user-name">User</span>
 23:                     <span class="dropdown-arrow">▼</span>
 24:                 </button>
 25:                 <div id="user-dropdown" class="user-dropdown hidden">
 26:                     <a href="#" id="menu-profile" class="dropdown-item">
 27:                         <span class="dropdown-icon">👤</span> Profile
 28:                     </a>
 29:                     <div id="admin-menu-items" class="hidden">
 30:                         <hr class="dropdown-divider">
 31:                         <a href="#" id="menu-admin-users" class="dropdown-item">
 32:                             <span class="dropdown-icon">👥</span> User Management
 33:                         </a>
 34:                         <a href="#" id="menu-admin-groups" class="dropdown-item">
 35:                             <span class="dropdown-icon">📁</span> Group Management
 36:                         </a>
 37:                     </div>
 38:                     <hr class="dropdown-divider">
 39:                     <a href="#" id="menu-logout" class="dropdown-item">
 40:                         <span class="dropdown-icon">🚪</span> Logout
 41:                     </a>
 42:                 </div>
 43:             </div>
 44:         </div>
 45:     </header>
 46:     <!-- Main Container -->
 47:     <div id="main-container" class="container">
 48:         <header id="auth-header">
 49:             <h1>🔐 LDAP 2FA Authentication</h1>
 50:             <p class="subtitle">Secure two-factor authentication for your LDAP account</p>
 51:         </header>
 52:         <!-- Tab Navigation (pre-login) -->
 53:         <nav id="auth-tabs" class="tabs">
 54:             <button class="tab-btn active" data-tab="login">Login</button>
 55:             <button class="tab-btn" data-tab="signup">Sign Up</button>
 56:             <button class="tab-btn" data-tab="enroll">Enroll MFA</button>
 57:         </nav>
 58:         <!-- Login Tab -->
 59:         <section id="login-tab" class="tab-content active">
 60:             <form id="login-form" class="auth-form">
 61:                 <div class="form-group">
 62:                     <label for="login-username">Username</label>
 63:                     <input type="text" id="login-username" name="username" required
 64:                            placeholder="Enter your username" autocomplete="username">
 65:                 </div>
 66:                 <div class="form-group">
 67:                     <label for="login-password">Password</label>
 68:                     <input type="password" id="login-password" name="password" required
 69:                            placeholder="Enter your password" autocomplete="current-password">
 70:                 </div>
 71:                 <div class="form-group">
 72:                     <label for="login-code">Verification Code</label>
 73:                     <div class="code-input-group">
 74:                         <input type="text" id="login-code" name="verification_code" required
 75:                                placeholder="Enter 6-digit code" maxlength="6" pattern="[0-9]{6}"
 76:                                autocomplete="one-time-code" inputmode="numeric">
 77:                         <button type="button" id="send-sms-btn" class="btn btn-secondary btn-small hidden">
 78:                             Send SMS
 79:                         </button>
 80:                     </div>
 81:                     <small id="sms-status" class="form-hint hidden"></small>
 82:                 </div>
 83:                 <button type="submit" class="btn btn-primary">
 84:                     <span class="btn-text">Login</span>
 85:                     <span class="btn-loading hidden">Authenticating...</span>
 86:                 </button>
 87:             </form>
 88:             <div id="login-result" class="result-container hidden"></div>
 89:         </section>
 90:         <!-- Signup Tab -->
 91:         <section id="signup-tab" class="tab-content">
 92:             <form id="signup-form" class="auth-form">
 93:                 <div class="form-row">
 94:                     <div class="form-group">
 95:                         <label for="signup-firstname">First Name</label>
 96:                         <input type="text" id="signup-firstname" name="first_name" required
 97:                                placeholder="First name" autocomplete="given-name">
 98:                     </div>
 99:                     <div class="form-group">
100:                         <label for="signup-lastname">Last Name</label>
101:                         <input type="text" id="signup-lastname" name="last_name" required
102:                                placeholder="Last name" autocomplete="family-name">
103:                     </div>
104:                 </div>
105:                 <div class="form-group">
106:                     <label for="signup-username">Username</label>
107:                     <input type="text" id="signup-username" name="username" required
108:                            placeholder="Choose a username" autocomplete="username"
109:                            pattern="[a-zA-Z][a-zA-Z0-9_-]*" minlength="3" maxlength="64">
110:                     <small class="form-hint">Letters, numbers, underscores, and hyphens only</small>
111:                 </div>
112:                 <div class="form-group">
113:                     <label for="signup-email">Email</label>
114:                     <input type="email" id="signup-email" name="email" required
115:                            placeholder="your@email.com" autocomplete="email">
116:                 </div>
117:                 <div class="form-group">
118:                     <label for="signup-phone">Phone Number</label>
119:                     <div class="phone-input-group">
120:                         <select id="signup-country-code" name="phone_country_code" required>
121:                             <option value="+1">🇺🇸 +1</option>
122:                             <option value="+44">🇬🇧 +44</option>
123:                             <option value="+49">🇩🇪 +49</option>
124:                             <option value="+33">🇫🇷 +33</option>
125:                             <option value="+39">🇮🇹 +39</option>
126:                             <option value="+34">🇪🇸 +34</option>
127:                             <option value="+31">🇳🇱 +31</option>
128:                             <option value="+32">🇧🇪 +32</option>
129:                             <option value="+41">🇨🇭 +41</option>
130:                             <option value="+43">🇦🇹 +43</option>
131:                             <option value="+46">🇸🇪 +46</option>
132:                             <option value="+47">🇳🇴 +47</option>
133:                             <option value="+45">🇩🇰 +45</option>
134:                             <option value="+358">🇫🇮 +358</option>
135:                             <option value="+48">🇵🇱 +48</option>
136:                             <option value="+351">🇵🇹 +351</option>
137:                             <option value="+353">🇮🇪 +353</option>
138:                             <option value="+972">🇮🇱 +972</option>
139:                             <option value="+971">🇦🇪 +971</option>
140:                             <option value="+966">🇸🇦 +966</option>
141:                             <option value="+91">🇮🇳 +91</option>
142:                             <option value="+86">🇨🇳 +86</option>
143:                             <option value="+81">🇯🇵 +81</option>
144:                             <option value="+82">🇰🇷 +82</option>
145:                             <option value="+65">🇸🇬 +65</option>
146:                             <option value="+61">🇦🇺 +61</option>
147:                             <option value="+64">🇳🇿 +64</option>
148:                             <option value="+55">🇧🇷 +55</option>
149:                             <option value="+52">🇲🇽 +52</option>
150:                             <option value="+54">🇦🇷 +54</option>
151:                             <option value="+27">🇿🇦 +27</option>
152:                             <option value="+234">🇳🇬 +234</option>
153:                             <option value="+254">🇰🇪 +254</option>
154:                             <option value="+20">🇪🇬 +20</option>
155:                         </select>
156:                         <input type="tel" id="signup-phone" name="phone_number" required
157:                                placeholder="Phone number" autocomplete="tel-national"
158:                                pattern="[0-9]{5,15}" minlength="5" maxlength="15">
159:                     </div>
160:                     <small class="form-hint">Enter your phone number without the country code</small>
161:                 </div>
162:                 <div class="form-group">
163:                     <label for="signup-password">Password</label>
164:                     <input type="password" id="signup-password" name="password" required
165:                            placeholder="Create a password" autocomplete="new-password"
166:                            minlength="8">
167:                     <small class="form-hint">Minimum 8 characters</small>
168:                 </div>
169:                 <div class="form-group">
170:                     <label for="signup-confirm-password">Confirm Password</label>
171:                     <input type="password" id="signup-confirm-password" name="confirm_password" required
172:                            placeholder="Confirm your password" autocomplete="new-password">
173:                 </div>
174:                 <!-- MFA Method Selection -->
175:                 <div class="form-group">
176:                     <label>MFA Method</label>
177:                     <div class="mfa-method-selector">
178:                         <label class="radio-option">
179:                             <input type="radio" name="signup_mfa_method" value="totp" checked>
180:                             <span class="radio-label">
181:                                 <span class="radio-icon">📱</span>
182:                                 <span class="radio-text">
183:                                     <strong>Authenticator App</strong>
184:                                     <small>Google Authenticator, Authy, etc.</small>
185:                                 </span>
186:                             </span>
187:                         </label>
188:                         <label class="radio-option" id="signup-sms-option">
189:                             <input type="radio" name="signup_mfa_method" value="sms">
190:                             <span class="radio-label">
191:                                 <span class="radio-icon">💬</span>
192:                                 <span class="radio-text">
193:                                     <strong>SMS</strong>
194:                                     <small>Receive codes via text message</small>
195:                                 </span>
196:                             </span>
197:                         </label>
198:                     </div>
199:                 </div>
200:                 <button type="submit" class="btn btn-primary">
201:                     <span class="btn-text">Create Account</span>
202:                     <span class="btn-loading hidden">Creating Account...</span>
203:                 </button>
204:             </form>
205:             <!-- Verification Status (shown after signup) -->
206:             <div id="verification-status" class="verification-panel hidden">
207:                 <h3>📋 Complete Your Registration</h3>
208:                 <p class="verification-subtitle">Please verify your email and phone to continue</p>
209:                 <div class="verification-items">
210:                     <div class="verification-item">
211:                         <span class="status-icon" id="email-verify-status">⏳</span>
212:                         <div class="verification-details">
213:                             <span class="verification-label">Email Verification</span>
214:                             <span class="verification-hint" id="email-verify-hint">Check your inbox</span>
215:                         </div>
216:                         <button type="button" id="resend-email-btn" class="btn btn-secondary btn-small">
217:                             Resend
218:                         </button>
219:                     </div>
220:                     <div class="verification-item">
221:                         <span class="status-icon" id="phone-verify-status">⏳</span>
222:                         <div class="verification-details">
223:                             <span class="verification-label">Phone Verification</span>
224:                             <span class="verification-hint" id="phone-verify-hint">Enter code sent to your phone</span>
225:                         </div>
226:                         <button type="button" id="resend-phone-btn" class="btn btn-secondary btn-small">
227:                             Resend
228:                         </button>
229:                     </div>
230:                 </div>
231:                 <!-- Phone verification code input -->
232:                 <div class="phone-verify-input">
233:                     <div class="form-group">
234:                         <label for="phone-verify-code">Phone Verification Code</label>
235:                         <div class="code-input-group">
236:                             <input type="text" id="phone-verify-code"
237:                                    placeholder="Enter 6-digit code" maxlength="6"
238:                                    pattern="[0-9]{6}" inputmode="numeric">
239:                             <button type="button" id="verify-phone-btn" class="btn btn-primary btn-small">
240:                                 Verify
241:                             </button>
242:                         </div>
243:                     </div>
244:                 </div>
245:                 <div id="verification-complete" class="verification-complete hidden">
246:                     <div class="success-icon">✅</div>
247:                     <h4>Verification Complete!</h4>
248:                     <p>Your account is now awaiting admin approval. You will receive an email once activated.</p>
249:                 </div>
250:             </div>
251:             <div id="signup-result" class="result-container hidden"></div>
252:         </section>
253:         <!-- Enroll Tab -->
254:         <section id="enroll-tab" class="tab-content">
255:             <form id="enroll-form" class="auth-form">
256:                 <div class="form-group">
257:                     <label for="enroll-username">Username</label>
258:                     <input type="text" id="enroll-username" name="username" required
259:                            placeholder="Enter your username" autocomplete="username">
260:                 </div>
261:                 <div class="form-group">
262:                     <label for="enroll-password">Password</label>
263:                     <input type="password" id="enroll-password" name="password" required
264:                            placeholder="Enter your password" autocomplete="current-password">
265:                 </div>
266:                 <!-- MFA Method Selection -->
267:                 <div class="form-group">
268:                     <label>MFA Method</label>
269:                     <div class="mfa-method-selector">
270:                         <label class="radio-option">
271:                             <input type="radio" name="mfa_method" value="totp" checked>
272:                             <span class="radio-label">
273:                                 <span class="radio-icon">📱</span>
274:                                 <span class="radio-text">
275:                                     <strong>Authenticator App</strong>
276:                                     <small>Google Authenticator, Authy, etc.</small>
277:                                 </span>
278:                             </span>
279:                         </label>
280:                         <label class="radio-option" id="sms-option">
281:                             <input type="radio" name="mfa_method" value="sms">
282:                             <span class="radio-label">
283:                                 <span class="radio-icon">💬</span>
284:                                 <span class="radio-text">
285:                                     <strong>SMS</strong>
286:                                     <small>Receive codes via text message</small>
287:                                 </span>
288:                             </span>
289:                         </label>
290:                     </div>
291:                 </div>
292:                 <!-- Phone Number (for SMS) -->
293:                 <div class="form-group hidden" id="phone-group">
294:                     <label for="enroll-phone">Phone Number</label>
295:                     <input type="tel" id="enroll-phone" name="phone_number"
296:                            placeholder="+1234567890 (E.164 format)"
297:                            pattern="\+[1-9]\d{1,14}">
298:                     <small class="form-hint">
299:                         Enter phone number with country code (e.g., +1 for US)
300:                     </small>
301:                 </div>
302:                 <button type="submit" class="btn btn-primary">
303:                     <span class="btn-text">Enroll for MFA</span>
304:                     <span class="btn-loading hidden">Enrolling...</span>
305:                 </button>
306:             </form>
307:             <div id="enroll-result" class="result-container hidden">
308:                 <!-- TOTP QR Section -->
309:                 <div id="qr-section" class="qr-section hidden">
310:                     <h3>Scan QR Code</h3>
311:                     <p>Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)</p>
312:                     <div id="qr-code" class="qr-code"></div>
313:                     <div class="manual-entry">
314:                         <p>Or manually enter this secret:</p>
315:                         <code id="secret-code"></code>
316:                         <button id="copy-secret" class="btn btn-secondary btn-small">Copy Secret</button>
317:                     </div>
318:                 </div>
319:                 <!-- SMS Enrollment Success -->
320:                 <div id="sms-enroll-section" class="sms-section hidden">
321:                     <h3>📱 SMS Verification Setup</h3>
322:                     <p>A verification code has been sent to <strong id="enrolled-phone"></strong></p>
323:                     <p class="hint">You can now use SMS codes to log in. Each code expires in 5 minutes.</p>
324:                 </div>
325:             </div>
326:         </section>
327:         <!-- Profile Section (shown when logged in) -->
328:         <section id="profile-section" class="tab-content hidden">
329:             <div class="section-header">
330:                 <h2>👤 My Profile</h2>
331:             </div>
332:             <form id="profile-form" class="auth-form">
333:                 <div class="form-group">
334:                     <label>Username</label>
335:                     <input type="text" id="profile-username" readonly class="readonly-input">
336:                 </div>
337:                 <div class="form-row">
338:                     <div class="form-group">
339:                         <label for="profile-firstname">First Name</label>
340:                         <input type="text" id="profile-firstname" name="first_name">
341:                     </div>
342:                     <div class="form-group">
343:                         <label for="profile-lastname">Last Name</label>
344:                         <input type="text" id="profile-lastname" name="last_name">
345:                     </div>
346:                 </div>
347:                 <div class="form-group">
348:                     <label for="profile-email">Email</label>
349:                     <input type="email" id="profile-email" name="email">
350:                     <small id="profile-email-hint" class="form-hint"></small>
351:                 </div>
352:                 <div class="form-group">
353:                     <label for="profile-phone">Phone Number</label>
354:                     <div class="phone-input-group">
355:                         <select id="profile-country-code" name="phone_country_code">
356:                             <option value="+1">🇺🇸 +1</option>
357:                             <option value="+44">🇬🇧 +44</option>
358:                             <option value="+49">🇩🇪 +49</option>
359:                             <option value="+33">🇫🇷 +33</option>
360:                             <option value="+91">🇮🇳 +91</option>
361:                         </select>
362:                         <input type="tel" id="profile-phone" name="phone_number">
363:                     </div>
364:                     <small id="profile-phone-hint" class="form-hint"></small>
365:                 </div>
366:                 <div class="form-group">
367:                     <label>MFA Method</label>
368:                     <input type="text" id="profile-mfa" readonly class="readonly-input">
369:                 </div>
370:                 <div class="form-group">
371:                     <label>Account Status</label>
372:                     <input type="text" id="profile-status" readonly class="readonly-input">
373:                 </div>
374:                 <div class="form-group">
375:                     <label>Groups</label>
376:                     <div id="profile-groups" class="group-badges"></div>
377:                 </div>
378:                 <button type="submit" class="btn btn-primary">
379:                     <span class="btn-text">Save Changes</span>
380:                     <span class="btn-loading hidden">Saving...</span>
381:                 </button>
382:             </form>
383:         </section>
384:         <!-- Admin Users Section -->
385:         <section id="admin-users-section" class="tab-content hidden">
386:             <div class="section-header">
387:                 <h2>👥 User Management</h2>
388:             </div>
389:             <div class="admin-controls">
390:                 <div class="search-box">
391:                     <input type="text" id="users-search" placeholder="Search users..." class="search-input">
392:                 </div>
393:                 <div class="filter-controls">
394:                     <select id="users-status-filter" class="filter-select">
395:                         <option value="">All Statuses</option>
396:                         <option value="pending">Pending</option>
397:                         <option value="complete">Awaiting Approval</option>
398:                         <option value="active">Active</option>
399:                         <option value="revoked">Revoked</option>
400:                     </select>
401:                     <select id="users-group-filter" class="filter-select">
402:                         <option value="">All Groups</option>
403:                     </select>
404:                     <button type="button" id="users-refresh-btn" class="btn btn-secondary btn-small">
405:                         🔄 Refresh
406:                     </button>
407:                 </div>
408:             </div>
409:             <div class="data-table-container">
410:                 <table class="data-table" id="users-table">
411:                     <thead>
412:                         <tr>
413:                             <th class="sortable" data-sort="first_name">Name</th>
414:                             <th class="sortable" data-sort="username">Username</th>
415:                             <th class="sortable" data-sort="email">Email</th>
416:                             <th class="sortable" data-sort="status">Status</th>
417:                             <th>Groups</th>
418:                             <th class="sortable" data-sort="created_at">Created</th>
419:                             <th>Actions</th>
420:                         </tr>
421:                     </thead>
422:                     <tbody id="users-table-body">
423:                         <!-- Users will be populated here -->
424:                     </tbody>
425:                 </table>
426:             </div>
427:             <div id="users-loading" class="loading-spinner hidden">Loading...</div>
428:             <div id="users-empty" class="empty-state hidden">No users found</div>
429:         </section>
430:         <!-- Admin Groups Section -->
431:         <section id="admin-groups-section" class="tab-content hidden">
432:             <div class="section-header">
433:                 <h2>📁 Group Management</h2>
434:                 <button type="button" id="create-group-btn" class="btn btn-primary btn-small">
435:                     + Create Group
436:                 </button>
437:             </div>
438:             <div class="admin-controls">
439:                 <div class="search-box">
440:                     <input type="text" id="groups-search" placeholder="Search groups..." class="search-input">
441:                 </div>
442:             </div>
443:             <div class="data-table-container">
444:                 <table class="data-table" id="groups-table">
445:                     <thead>
446:                         <tr>
447:                             <th class="sortable" data-sort="name">Name</th>
448:                             <th>Description</th>
449:                             <th>Members</th>
450:                             <th class="sortable" data-sort="created_at">Created</th>
451:                             <th>Actions</th>
452:                         </tr>
453:                     </thead>
454:                     <tbody id="groups-table-body">
455:                         <!-- Groups will be populated here -->
456:                     </tbody>
457:                 </table>
458:             </div>
459:             <div id="groups-loading" class="loading-spinner hidden">Loading...</div>
460:             <div id="groups-empty" class="empty-state hidden">No groups found</div>
461:         </section>
462:         <!-- Status Messages -->
463:         <div id="status-message" class="status-message hidden"></div>
464:         <footer>
465:             <p>💡 Need help? Contact your system administrator.</p>
466:         </footer>
467:     </div>
468:     <!-- Modals -->
469:     <div id="modal-overlay" class="modal-overlay hidden">
470:         <!-- Group Create/Edit Modal -->
471:         <div id="group-modal" class="modal hidden">
472:             <div class="modal-header">
473:                 <h3 id="group-modal-title">Create Group</h3>
474:                 <button type="button" class="modal-close" data-close-modal>&times;</button>
475:             </div>
476:             <form id="group-modal-form">
477:                 <div class="modal-body">
478:                     <div class="form-group">
479:                         <label for="group-name">Group Name</label>
480:                         <input type="text" id="group-name" required placeholder="Enter group name">
481:                     </div>
482:                     <div class="form-group">
483:                         <label for="group-description">Description</label>
484:                         <textarea id="group-description" rows="3" placeholder="Enter description"></textarea>
485:                     </div>
486:                 </div>
487:                 <div class="modal-footer">
488:                     <button type="button" class="btn btn-secondary" data-close-modal>Cancel</button>
489:                     <button type="submit" class="btn btn-primary">Save</button>
490:                 </div>
491:             </form>
492:         </div>
493:         <!-- Approve User Modal (with group selection) -->
494:         <div id="approve-modal" class="modal hidden">
495:             <div class="modal-header">
496:                 <h3>Approve User</h3>
497:                 <button type="button" class="modal-close" data-close-modal>&times;</button>
498:             </div>
499:             <form id="approve-modal-form">
500:                 <div class="modal-body">
501:                     <p>Approve user <strong id="approve-user-name"></strong> and assign to groups:</p>
502:                     <div class="form-group">
503:                         <label>Select Groups (at least one required)</label>
504:                         <div id="approve-groups-list" class="checkbox-list">
505:                             <!-- Groups will be populated here -->
506:                         </div>
507:                     </div>
508:                 </div>
509:                 <div class="modal-footer">
510:                     <button type="button" class="btn btn-secondary" data-close-modal>Cancel</button>
511:                     <button type="submit" class="btn btn-primary">Approve</button>
512:                 </div>
513:             </form>
514:         </div>
515:         <!-- Group Members Modal -->
516:         <div id="members-modal" class="modal hidden">
517:             <div class="modal-header">
518:                 <h3 id="members-modal-title">Group Members</h3>
519:                 <button type="button" class="modal-close" data-close-modal>&times;</button>
520:             </div>
521:             <div class="modal-body">
522:                 <div id="members-list" class="members-list">
523:                     <!-- Members will be populated here -->
524:                 </div>
525:             </div>
526:             <div class="modal-footer">
527:                 <button type="button" class="btn btn-secondary" data-close-modal>Close</button>
528:             </div>
529:         </div>
530:         <!-- Confirm Modal -->
531:         <div id="confirm-modal" class="modal hidden">
532:             <div class="modal-header">
533:                 <h3 id="confirm-modal-title">Confirm</h3>
534:                 <button type="button" class="modal-close" data-close-modal>&times;</button>
535:             </div>
536:             <div class="modal-body">
537:                 <p id="confirm-modal-message"></p>
538:             </div>
539:             <div class="modal-footer">
540:                 <button type="button" class="btn btn-secondary" data-close-modal>Cancel</button>
541:                 <button type="button" id="confirm-modal-ok" class="btn btn-danger">Confirm</button>
542:             </div>
543:         </div>
544:     </div>
545:     <script src="/js/api.js"></script>
546:     <script src="/js/main.js"></script>
547: </body>
548: </html>
```

## File: application/modules/alb/variables.tf
```hcl
 1: variable "env" {
 2:   description = "Environment suffix used to name resources"
 3:   type        = string
 4: }
 5:
 6: variable "region" {
 7:   description = "Deployment region"
 8:   type        = string
 9: }
10:
11: variable "prefix" {
12:   description = "Prefix used to name resources"
13:   type        = string
14: }
15:
16: variable "app_name" {
17:   description = "Application name"
18:   type        = string
19: }
20:
21: variable "cluster_name" {
22:   description = "Name of EKS Cluster where ALB is to be deployed"
23:   type        = string
24: }
25:
26: # variable "ingress_alb_name" {
27: #   description = "Name component for ingress ALB resource (between prefix and env)"
28: #   type        = string
29: # }
30:
31: # variable "service_alb_name" {
32: #   description = "Name component for service ALB resource (between prefix and env)"
33: #   type        = string
34: # }
35:
36: variable "ingressclass_alb_name" {
37:   description = "Name component for ingressclass ALB resource (between prefix and env)"
38:   type        = string
39: }
40:
41: variable "ingressclassparams_alb_name" {
42:   description = "Name component for ingressclassparams ALB resource (between prefix and env)"
43:   type        = string
44: }
45:
46: variable "acm_certificate_arn" {
47:   description = "ACM certificate ARN for HTTPS/TLS termination at ALB"
48:   type        = string
49:   default     = null
50: }
51:
52: variable "alb_scheme" {
53:   description = "ALB scheme: internet-facing or internal"
54:   type        = string
55:   default     = "internet-facing"
56:   validation {
57:     condition     = contains(["internet-facing", "internal"], var.alb_scheme)
58:     error_message = "ALB scheme must be either 'internet-facing' or 'internal'"
59:   }
60: }
61:
62: variable "alb_ip_address_type" {
63:   description = "ALB IP address type: ipv4 or dualstack"
64:   type        = string
65:   default     = "ipv4"
66:   validation {
67:     condition     = contains(["ipv4", "dualstack"], var.alb_ip_address_type)
68:     error_message = "ALB IP address type must be either 'ipv4' or 'dualstack'"
69:   }
70: }
71:
72: variable "alb_group_name" {
73:   description = "ALB group name for grouping multiple Ingress resources to share a single ALB. This is an internal Kubernetes identifier (max 63 characters)."
74:   type        = string
75:   default     = null # If null, will be derived from app_name
76: }
77:
78: variable "kubernetes_master" {
79:   description = "Kubernetes API server endpoint (KUBERNETES_MASTER environment variable). Set by set-k8s-env.sh or GitHub workflow."
80:   type        = string
81:   default     = null
82:   nullable    = true
83: }
84:
85: variable "kube_config_path" {
86:   description = "Path to kubeconfig file (KUBE_CONFIG_PATH environment variable). Set by set-k8s-env.sh or GitHub workflow."
87:   type        = string
88:   default     = null
89:   nullable    = true
90: }
91:
92: variable "wait_for_crd" {
93:   description = "Whether to wait for EKS Auto Mode CRD to be available before creating IngressClassParams. Set to true for initial cluster deployments, false after cluster is established."
94:   type        = bool
95:   default     = false
96: }
```

## File: application/destroy-application.sh
```bash
  1: #!/bin/bash
  2: # Script to configure backend.hcl and variables.tfvars with user-selected region and environment
  3: # and run Terraform destroy commands
  4: # Usage: ./destroy-application.sh
  5: set -euo pipefail
  6: # Clean up any existing AWS credentials from environment to prevent conflicts
  7: # This ensures the script starts with a clean slate and uses the correct credentials
  8: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
  9: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 10: unset AWS_SESSION_TOKEN 2>/dev/null || true
 11: unset AWS_PROFILE 2>/dev/null || true
 12: # Colors for output
 13: RED='\033[0;31m'
 14: GREEN='\033[0;32m'
 15: YELLOW='\033[1;33m'
 16: NC='\033[0m' # No Color
 17: # Configuration
 18: PLACEHOLDER_FILE="tfstate-backend-values-template.hcl"
 19: BACKEND_FILE="backend.hcl"
 20: VARIABLES_FILE="variables.tfvars"
 21: # Export configuration variables for use by sourced scripts
 22: export BACKEND_FILE
 23: export VARIABLES_FILE
 24: # Function to print colored messages
 25: print_error() {
 26:     echo -e "${RED}ERROR:${NC} $1" >&2
 27: }
 28: print_success() {
 29:     echo -e "${GREEN}SUCCESS:${NC} $1"
 30: }
 31: print_info() {
 32:     echo -e "${YELLOW}INFO:${NC} $1"
 33: }
 34: print_warning() {
 35:     echo -e "${YELLOW}WARNING:${NC} $1"
 36: }
 37: # Check if AWS CLI is installed
 38: if ! command -v aws &> /dev/null; then
 39:     print_error "AWS CLI is not installed."
 40:     echo "Please install it from: https://aws.amazon.com/cli/"
 41:     exit 1
 42: fi
 43: # Check if Terraform is installed
 44: if ! command -v terraform &> /dev/null; then
 45:     print_error "Terraform is not installed."
 46:     echo "Please install it from: https://www.terraform.io/downloads"
 47:     exit 1
 48: fi
 49: # Check if GitHub CLI is installed
 50: if ! command -v gh &> /dev/null; then
 51:     print_error "GitHub CLI (gh) is not installed."
 52:     echo "Please install it from: https://cli.github.com/"
 53:     exit 1
 54: fi
 55: # Check if user is authenticated with GitHub CLI
 56: if ! gh auth status &> /dev/null; then
 57:     print_error "Not authenticated with GitHub CLI."
 58:     echo "Please run: gh auth login"
 59:     exit 1
 60: fi
 61: # Check if jq is installed (required for gh --jq flag)
 62: if ! command -v jq &> /dev/null; then
 63:     print_error "jq is not installed."
 64:     echo "Please install it:"
 65:     echo "  macOS: brew install jq"
 66:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 67:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 68:     exit 1
 69: fi
 70: # Get repository owner and name
 71: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 72: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 73: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 74:     print_error "Could not determine repository information."
 75:     echo "Please ensure you're in a git repository and have proper permissions."
 76:     exit 1
 77: fi
 78: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 79: # Function to get repository variable using GitHub CLI
 80: get_repo_variable() {
 81:     local var_name=$1
 82:     local value
 83:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 84:     if [ -z "$value" ]; then
 85:         print_error "Repository variable '${var_name}' not found or not accessible."
 86:         return 1
 87:     fi
 88:     echo "$value"
 89: }
 90: # Function to retrieve secret from AWS Secrets Manager
 91: get_aws_secret() {
 92:     local secret_name=$1
 93:     local secret_json
 94:     local exit_code
 95:     # Retrieve secret from AWS Secrets Manager
 96:     # Use AWS_REGION if set, otherwise default to us-east-1
 97:     secret_json=$(aws secretsmanager get-secret-value \
 98:         --secret-id "$secret_name" \
 99:         --region "${AWS_REGION:-us-east-1}" \
100:         --query SecretString \
101:         --output text 2>&1)
102:     # Capture exit code before checking
103:     exit_code=$?
104:     # Validate secret retrieval
105:     if [ $exit_code -ne 0 ]; then
106:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
107:         print_error "Error: $secret_json"
108:         return 1
109:     fi
110:     # Validate JSON can be parsed
111:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
112:         print_error "Secret '${secret_name}' contains invalid JSON"
113:         return 1
114:     fi
115:     echo "$secret_json"
116: }
117: # Function to retrieve plain text secret from AWS Secrets Manager
118: get_aws_plaintext_secret() {
119:     local secret_name=$1
120:     local secret_value
121:     local exit_code
122:     # Retrieve secret from AWS Secrets Manager
123:     # Use AWS_REGION if set, otherwise default to us-east-1
124:     secret_value=$(aws secretsmanager get-secret-value \
125:         --secret-id "$secret_name" \
126:         --region "${AWS_REGION:-us-east-1}" \
127:         --query SecretString \
128:         --output text 2>&1)
129:     # Capture exit code before checking
130:     exit_code=$?
131:     # Validate secret retrieval
132:     if [ $exit_code -ne 0 ]; then
133:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
134:         print_error "Error: $secret_value"
135:         return 1
136:     fi
137:     # Check if secret value is empty
138:     if [ -z "$secret_value" ]; then
139:         print_error "Secret '${secret_name}' is empty"
140:         return 1
141:     fi
142:     echo "$secret_value"
143: }
144: # Function to get key value from secret JSON
145: get_secret_key_value() {
146:     local secret_json=$1
147:     local key_name=$2
148:     local value
149:     # Validate JSON can be parsed
150:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
151:         print_error "Invalid JSON provided to get_secret_key_value"
152:         return 1
153:     fi
154:     # Extract key value using jq
155:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
156:     # Check if jq command succeeded
157:     if [ $? -ne 0 ]; then
158:         print_error "Failed to parse JSON or extract key '${key_name}'"
159:         return 1
160:     fi
161:     # Check if key exists (jq returns "null" for non-existent keys)
162:     if [ "$value" = "null" ] || [ -z "$value" ]; then
163:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
164:         return 1
165:     fi
166:     echo "$value"
167: }
168: # Function to assume an AWS IAM role and export credentials
169: # Usage: assume_aws_role <role_arn> [external_id] [role_description] [session_name_suffix]
170: #   role_arn: The ARN of the role to assume (required)
171: #   external_id: Optional external ID for cross-account role assumption
172: #   role_description: Optional description for logging (defaults to "role")
173: #   session_name_suffix: Optional suffix for session name (defaults to "destroy-application")
174: assume_aws_role() {
175:     local role_arn=$1
176:     local external_id=${2:-}
177:     local role_description=${3:-"role"}
178:     local session_name_suffix=${4:-"destroy-application"}
179:     if [ -z "$role_arn" ]; then
180:         print_error "Role ARN is required for assume_aws_role"
181:         return 1
182:     fi
183:     print_info "Assuming ${role_description}: $role_arn"
184:     print_info "Region: $AWS_REGION"
185:     # Assume the role
186:     local role_session_name="${session_name_suffix}-$(date +%s)"
187:     local assume_role_output
188:     # Assume role and capture output
189:     # Add external ID if provided
190:     if [ -n "$external_id" ]; then
191:         assume_role_output=$(aws sts assume-role \
192:             --role-arn "$role_arn" \
193:             --role-session-name "$role_session_name" \
194:             --external-id "$external_id" \
195:             --region "$AWS_REGION" 2>&1)
196:     else
197:         assume_role_output=$(aws sts assume-role \
198:             --role-arn "$role_arn" \
199:             --role-session-name "$role_session_name" \
200:             --region "$AWS_REGION" 2>&1)
201:     fi
202:     if [ $? -ne 0 ]; then
203:         print_error "Failed to assume ${role_description}: $assume_role_output"
204:         return 1
205:     fi
206:     # Extract credentials from JSON output
207:     # Try using jq if available (more reliable), otherwise use sed/grep
208:     local access_key_id
209:     local secret_access_key
210:     local session_token
211:     if command -v jq &> /dev/null; then
212:         access_key_id=$(echo "$assume_role_output" | jq -r '.Credentials.AccessKeyId')
213:         secret_access_key=$(echo "$assume_role_output" | jq -r '.Credentials.SecretAccessKey')
214:         session_token=$(echo "$assume_role_output" | jq -r '.Credentials.SessionToken')
215:     else
216:         # Fallback: use sed for JSON parsing (works on both macOS and Linux)
217:         access_key_id=$(echo "$assume_role_output" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
218:         secret_access_key=$(echo "$assume_role_output" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
219:         session_token=$(echo "$assume_role_output" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
220:     fi
221:     if [ -z "$access_key_id" ] || [ -z "$secret_access_key" ] || [ -z "$session_token" ]; then
222:         print_error "Failed to extract credentials from assume-role output."
223:         print_error "Output was: $assume_role_output"
224:         return 1
225:     fi
226:     # Export credentials to environment variables
227:     export AWS_ACCESS_KEY_ID="$access_key_id"
228:     export AWS_SECRET_ACCESS_KEY="$secret_access_key"
229:     export AWS_SESSION_TOKEN="$session_token"
230:     print_success "Successfully assumed ${role_description}"
231:     # Verify the credentials work
232:     local caller_arn
233:     caller_arn=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
234:     if [ $? -ne 0 ]; then
235:         print_error "Failed to verify assumed role credentials: $caller_arn"
236:         return 1
237:     fi
238:     print_info "${role_description} identity: $caller_arn"
239:     return 0
240: }
241: # Warning about destructive operation
242: echo ""
243: print_warning "=========================================="
244: print_warning "  DESTRUCTIVE OPERATION WARNING"
245: print_warning "=========================================="
246: print_warning "This script will DESTROY all application"
247: print_warning "infrastructure in the selected region and environment."
248: print_warning ""
249: print_warning "This action CANNOT be undone!"
250: print_warning "=========================================="
251: echo ""
252: read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
253: if [ "$confirmation" != "yes" ]; then
254:     print_info "Operation cancelled."
255:     exit 0
256: fi
257: # Interactive prompts
258: echo ""
259: print_info "Select AWS Region:"
260: echo "1) us-east-1: N. Virginia (default)"
261: echo "2) us-east-2: Ohio"
262: read -p "Enter choice [1-2] (default: 1): " region_choice
263: case ${region_choice:-1} in
264:     1)
265:         SELECTED_REGION="us-east-1: N. Virginia"
266:         ;;
267:     2)
268:         SELECTED_REGION="us-east-2: Ohio"
269:         ;;
270:     *)
271:         print_error "Invalid choice. Using default: us-east-1: N. Virginia"
272:         SELECTED_REGION="us-east-1: N. Virginia"
273:         ;;
274: esac
275: # Extract region code (everything before the colon)
276: AWS_REGION="${SELECTED_REGION%%:*}"
277: export AWS_REGION
278: print_success "Selected region: ${SELECTED_REGION} (${AWS_REGION})"
279: echo ""
280: print_info "Select Environment:"
281: echo "1) prod (default)"
282: echo "2) dev"
283: read -p "Enter choice [1-2] (default: 1): " env_choice
284: case ${env_choice:-1} in
285:     1)
286:         ENVIRONMENT="prod"
287:         ;;
288:     2)
289:         ENVIRONMENT="dev"
290:         ;;
291:     *)
292:         print_error "Invalid choice. Using default: prod"
293:         ENVIRONMENT="prod"
294:         ;;
295: esac
296: print_success "Selected environment: ${ENVIRONMENT}"
297: export ENVIRONMENT
298: echo ""
299: # Final confirmation with environment details
300: print_warning "You are about to DESTROY application infrastructure in:"
301: print_warning "  Region: ${AWS_REGION}"
302: print_warning "  Environment: ${ENVIRONMENT}"
303: echo ""
304: read -p "Type 'DESTROY' to confirm: " final_confirmation
305: if [ "$final_confirmation" != "DESTROY" ]; then
306:     print_info "Operation cancelled."
307:     exit 0
308: fi
309: # Retrieve role ARNs from AWS Secrets Manager in a single call
310: # This minimizes AWS CLI calls by fetching all required role ARNs at once
311: print_info "Retrieving role ARNs from AWS Secrets Manager..."
312: ROLE_SECRET_JSON=$(get_aws_secret "github-role" || echo "")
313: if [ -z "$ROLE_SECRET_JSON" ]; then
314:     print_error "Failed to retrieve 'github-role' secret from AWS Secrets Manager"
315:     exit 1
316: fi
317: # Extract STATE_ACCOUNT_ROLE_ARN for backend state operations
318: STATE_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
319: if [ -z "$STATE_ROLE_ARN" ]; then
320:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
321:     exit 1
322: fi
323: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
324: # Determine which deployment account role ARN to use based on environment
325: if [ "$ENVIRONMENT" = "prod" ]; then
326:     DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
327: else
328:     DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
329: fi
330: # Extract deployment account role ARN for provider assume_role
331: DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
332: if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
333:     print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
334:     exit 1
335: fi
336: export DEPLOYMENT_ROLE_ARN
337: print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"
338: # Retrieve ExternalId from AWS Secrets Manager (plain text secret)
339: print_info "Retrieving ExternalId from AWS Secrets Manager..."
340: EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
341: if [ -z "$EXTERNAL_ID" ]; then
342:     print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
343:     exit 1
344: fi
345: export EXTERNAL_ID
346: print_success "Retrieved ExternalId"
347: # Retrieve Terraform variables from AWS Secrets Manager in a single call
348: print_info "Retrieving Terraform variables from AWS Secrets Manager..."
349: TF_VARS_SECRET_JSON=$(get_aws_secret "tf-vars" || echo "")
350: if [ -z "$TF_VARS_SECRET_JSON" ]; then
351:     print_error "Failed to retrieve 'tf-vars' secret from AWS Secrets Manager"
352:     exit 1
353: fi
354: # Extract OpenLDAP password values from tf-vars secret
355: TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_ADMIN_PASSWORD" || echo "")
356: if [ -z "$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE" ]; then
357:     print_error "Failed to retrieve TF_VAR_OPENLDAP_ADMIN_PASSWORD from secret"
358:     exit 1
359: fi
360: print_success "Retrieved TF_VAR_OPENLDAP_ADMIN_PASSWORD"
361: TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_CONFIG_PASSWORD" || echo "")
362: if [ -z "$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE" ]; then
363:     print_error "Failed to retrieve TF_VAR_OPENLDAP_CONFIG_PASSWORD from secret"
364:     exit 1
365: fi
366: print_success "Retrieved TF_VAR_OPENLDAP_CONFIG_PASSWORD"
367: # Extract PostgreSQL password from tf-vars secret
368: TF_VAR_POSTGRESQL_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_POSTGRESQL_PASSWORD" || echo "")
369: if [ -z "$TF_VAR_POSTGRESQL_PASSWORD_VALUE" ]; then
370:     print_error "Failed to retrieve TF_VAR_POSTGRESQL_PASSWORD from secret"
371:     exit 1
372: fi
373: print_success "Retrieved TF_VAR_POSTGRESQL_PASSWORD"
374: # Extract Redis password from tf-vars secret
375: TF_VAR_REDIS_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_REDIS_PASSWORD" || echo "")
376: if [ -z "$TF_VAR_REDIS_PASSWORD_VALUE" ]; then
377:     print_error "Failed to retrieve TF_VAR_REDIS_PASSWORD from secret"
378:     exit 1
379: fi
380: print_success "Retrieved TF_VAR_REDIS_PASSWORD"
381: # Export as environment variables for Terraform
382: # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
383: # Secrets in AWS/GitHub remain uppercase, but environment variables must be lowercase
384: export TF_VAR_openldap_admin_password="$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE"
385: export TF_VAR_openldap_config_password="$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE"
386: export TF_VAR_postgresql_database_password="$TF_VAR_POSTGRESQL_PASSWORD_VALUE"
387: export TF_VAR_redis_password="$TF_VAR_REDIS_PASSWORD_VALUE"
388: print_success "Retrieved and exported all secrets from AWS Secrets Manager"
389: echo ""
390: # Retrieve repository variables
391: print_info "Retrieving repository variables..."
392: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
393: print_success "Retrieved BACKEND_BUCKET_NAME"
394: APPLICATION_PREFIX=$(get_repo_variable "APPLICATION_PREFIX") || exit 1
395: print_success "Retrieved APPLICATION_PREFIX"
396: # Check if backend.hcl already exists
397: if [ -f "$BACKEND_FILE" ]; then
398:     print_info "${BACKEND_FILE} already exists. Skipping creation."
399: else
400:     # Check if placeholder file exists
401:     if [ ! -f "$PLACEHOLDER_FILE" ]; then
402:         print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
403:         exit 1
404:     fi
405:     # Copy placeholder to backend file and replace placeholders
406:     print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."
407:     # Copy placeholder file to backend file
408:     cp "$PLACEHOLDER_FILE" "$BACKEND_FILE"
409:     # Replace placeholders (works on macOS and Linux)
410:     if [[ "$OSTYPE" == "darwin"* ]]; then
411:         # macOS sed requires -i '' for in-place editing
412:         sed -i '' "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
413:         sed -i '' "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
414:         sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
415:     else
416:         # Linux sed
417:         sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
418:         sed -i "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
419:         sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
420:     fi
421:     print_success "Created ${BACKEND_FILE}"
422: fi
423: print_success "Configuration files updated successfully!"
424: echo ""
425: print_info "Backend file: ${BACKEND_FILE}"
426: print_info "  - bucket: ${BUCKET_NAME}"
427: print_info "  - key: ${APPLICATION_PREFIX}"
428: print_info "  - region: ${AWS_REGION}"
429: echo ""
430: # Assume State Account role for backend operations
431: if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "destroy-application"; then
432:     exit 1
433: fi
434: echo ""
435: # Terraform workspace name
436: WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"
437: # Terraform init
438: print_info "Running terraform init with backend configuration..."
439: terraform init -backend-config="${BACKEND_FILE}"
440: # Terraform workspace
441: print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
442: terraform workspace select "${WORKSPACE_NAME}" 2>/dev/null || terraform workspace new "${WORKSPACE_NAME}"
443: # Terraform validate
444: print_info "Running terraform validate..."
445: terraform validate
446: # Set Kubernetes environment variables
447: print_info "Setting Kubernetes environment variables..."
448: if [ ! -f "set-k8s-env.sh" ]; then
449:     print_error "set-k8s-env.sh not found."
450:     exit 1
451: fi
452: # Make sure the script is executable
453: chmod +x ./set-k8s-env.sh
454: # Source the script to set environment variables
455: # The script uses environment variables (Deployment Account credentials for EKS, State Account credentials for S3)
456: source ./set-k8s-env.sh
457: if [ -z "$KUBERNETES_MASTER" ]; then
458:     print_error "Failed to set KUBERNETES_MASTER environment variable."
459:     exit 1
460: fi
461: print_success "Kubernetes environment variables set"
462: print_info "  - KUBERNETES_MASTER: ${KUBERNETES_MASTER}"
463: print_info "  - KUBE_CONFIG_PATH: ${KUBE_CONFIG_PATH}"
464: # Export as TF_VAR_ environment variables for Terraform
465: export TF_VAR_kubernetes_master="$KUBERNETES_MASTER"
466: export TF_VAR_kube_config_path="$KUBE_CONFIG_PATH"
467: print_info "  - TF_VAR_kubernetes_master: ${TF_VAR_kubernetes_master}"
468: print_info "  - TF_VAR_kube_config_path: ${TF_VAR_kube_config_path}"
469: echo ""
470: # Assume State Account role again for Terraform operations
471: if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "destroy-application"; then
472:     exit 1
473: fi
474: echo ""
475: # Terraform plan destroy
476: print_info "Running terraform plan destroy..."
477: terraform plan -var-file="${VARIABLES_FILE}" -destroy -out terraform.tfplan
478: # Terraform apply (destroy)
479: print_warning "Applying destroy plan. This will DESTROY all application infrastructure..."
480: terraform apply -auto-approve terraform.tfplan
481: echo ""
482: print_success "Destroy operation completed successfully!"
483: print_info "All application infrastructure in ${AWS_REGION} (${ENVIRONMENT}) has been destroyed."
```

## File: application/mirror-images-to-ecr.sh
```bash
  1: #!/bin/bash
  2: # Script to mirror third-party container images (Redis, PostgreSQL, OpenLDAP) from Docker Hub to ECR
  3: # This eliminates Docker Hub rate limiting and external dependencies during deployments
  4: # Only mirrors images that don't already exist in ECR
  5: #
  6: # Usage: ./mirror-images-to-ecr.sh
  7: #   Requires Docker to be installed and running
  8: #   Uses AWS credentials from environment variables (set by setup-application.sh)
  9: #   Retrieves ECR information from backend_infra Terraform state
 10: set -euo pipefail
 11: cd "$(dirname "$0")"
 12: # Colors for output (if not already defined by sourcing script)
 13: if [ -z "${RED:-}" ]; then
 14:     RED='\033[0;31m'
 15:     GREEN='\033[0;32m'
 16:     YELLOW='\033[1;33m'
 17:     BLUE='\033[0;34m'
 18:     NC='\033[0m' # No Color
 19: fi
 20: # Function to print colored messages (if not already defined by sourcing script)
 21: if ! declare -f print_error > /dev/null; then
 22:     print_error() {
 23:         echo -e "${RED}ERROR:${NC} $1" >&2
 24:     }
 25: fi
 26: if ! declare -f print_success > /dev/null; then
 27:     print_success() {
 28:         echo -e "${GREEN}SUCCESS:${NC} $1"
 29:     }
 30: fi
 31: if ! declare -f print_info > /dev/null; then
 32:     print_info() {
 33:         echo -e "${YELLOW}INFO:${NC} $1"
 34:     }
 35: fi
 36: info() { echo -e "${BLUE}[INFO]${NC} $*"; }
 37: # Check required tools
 38: for cmd in docker jq; do
 39:   if ! command -v "$cmd" &> /dev/null; then
 40:     print_error "$cmd is required but not installed."
 41:     exit 1
 42:   fi
 43: done
 44: # Check if Docker daemon is running
 45: if ! docker info &> /dev/null 2>&1; then
 46:   print_error "Docker daemon is not running. Please start Docker and try again."
 47:   exit 1
 48: fi
 49: info "Starting ECR image mirroring process..."
 50: echo ""
 51: # Get AWS account ID
 52: AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
 53: info "AWS Account ID: $AWS_ACCOUNT_ID"
 54: # Use AWS_REGION from environment (set by setup-application.sh)
 55: if [ -z "${AWS_REGION:-}" ]; then
 56:     print_error "AWS_REGION is not set. Run ./setup-application.sh first."
 57:     exit 1
 58: fi
 59: info "AWS Region: $AWS_REGION"
 60: # Use BACKEND_FILE from environment if available, otherwise default to backend.hcl
 61: BACKEND_FILE="${BACKEND_FILE:-backend.hcl}"
 62: # Check if backend file exists
 63: if [ ! -f "$BACKEND_FILE" ]; then
 64:     print_error "$BACKEND_FILE not found. Run ./setup-application.sh first."
 65:     exit 1
 66: fi
 67: # Parse backend configuration
 68: BACKEND_BUCKET=$(grep 'bucket' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')
 69: BACKEND_KEY="backend_state/terraform.tfstate"
 70: info "Backend S3 bucket: $BACKEND_BUCKET"
 71: # Get current workspace to fetch correct state
 72: WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
 73: info "Terraform workspace: $WORKSPACE"
 74: # Determine state key based on workspace
 75: if [ "$WORKSPACE" = "default" ]; then
 76:     STATE_KEY="$BACKEND_KEY"
 77: else
 78:     STATE_KEY="env:/$WORKSPACE/$BACKEND_KEY"
 79: fi
 80: info "Fetching ECR repository information from s3://$BACKEND_BUCKET/$STATE_KEY"
 81: # Fetch ECR URL from backend_infra state using State Account credentials
 82: ECR_URL=$(aws s3 cp "s3://$BACKEND_BUCKET/$STATE_KEY" - 2>/dev/null | jq -r '.outputs.ecr_url.value' || echo "")
 83: if [ -z "$ECR_URL" ] || [ "$ECR_URL" = "null" ]; then
 84:     print_error "Could not retrieve ECR URL from backend_infra state."
 85:     print_error "Make sure backend_infra has been deployed and outputs ecr_url."
 86:     exit 1
 87: fi
 88: info "ECR Repository URL: $ECR_URL"
 89: # Extract ECR repository name from URL (format: account.dkr.ecr.region.amazonaws.com/repo-name)
 90: ECR_REPO_NAME=$(echo "$ECR_URL" | awk -F'/' '{print $NF}')
 91: info "ECR Repository Name: $ECR_REPO_NAME"
 92: echo ""
 93: # ECR is in the Deployment Account, so we need to assume the Deployment Account role
 94: # Check if DEPLOYMENT_ROLE_ARN and EXTERNAL_ID are set (from setup-application.sh)
 95: if [ -z "${DEPLOYMENT_ROLE_ARN:-}" ]; then
 96:     print_error "DEPLOYMENT_ROLE_ARN is not set. Run ./setup-application.sh first."
 97:     exit 1
 98: fi
 99: if [ -z "${EXTERNAL_ID:-}" ]; then
100:     print_error "EXTERNAL_ID is not set. Run ./setup-application.sh first."
101:     exit 1
102: fi
103: print_info "Assuming Deployment Account role for ECR operations: $DEPLOYMENT_ROLE_ARN"
104: print_info "Region: $AWS_REGION"
105: # Assume deployment account role with ExternalId
106: DEPLOYMENT_ROLE_SESSION_NAME="mirror-images-$(date +%s)"
107: DEPLOYMENT_ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
108:     --role-arn "$DEPLOYMENT_ROLE_ARN" \
109:     --role-session-name "$DEPLOYMENT_ROLE_SESSION_NAME" \
110:     --external-id "$EXTERNAL_ID" \
111:     --region "$AWS_REGION" 2>&1)
112: if [ $? -ne 0 ]; then
113:     print_error "Failed to assume Deployment Account role: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
114:     exit 1
115: fi
116: # Extract Deployment Account credentials from JSON output
117: if command -v jq &> /dev/null; then
118:     export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
119:     export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
120:     export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
121: else
122:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
123:     export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
124:     export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
125:     export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
126: fi
127: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
128:     print_error "Failed to extract Deployment Account credentials from assume-role output."
129:     print_error "Output was: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
130:     exit 1
131: fi
132: # Verify the Deployment Account credentials work
133: DEPLOYMENT_CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
134: if [ $? -ne 0 ]; then
135:     print_error "Failed to verify Deployment Account role credentials: $DEPLOYMENT_CALLER_ARN"
136:     exit 1
137: fi
138: # Extract Deployment Account ID from the ARN
139: DEPLOYMENT_ACCOUNT_ID=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Account' --output text 2>&1)
140: if [ $? -ne 0 ]; then
141:     print_error "Failed to get Deployment Account ID: $DEPLOYMENT_ACCOUNT_ID"
142:     exit 1
143: fi
144: print_success "Successfully assumed Deployment Account role"
145: print_info "Deployment Account role identity: $DEPLOYMENT_CALLER_ARN"
146: print_info "Deployment Account ID: $DEPLOYMENT_ACCOUNT_ID"
147: echo ""
148: # Function to check if an image tag exists in ECR
149: check_ecr_image_exists() {
150:   local tag=$1
151:   # Query ECR for the specific image tag
152:   local result
153:   result=$(aws ecr describe-images \
154:     --repository-name "$ECR_REPO_NAME" \
155:     --region "$AWS_REGION" \
156:     --image-ids imageTag="$tag" \
157:     --query 'imageDetails[0].imageTags[0]' \
158:     --output text 2>/dev/null || echo "None")
159:   if [ "$result" != "None" ] && [ -n "$result" ]; then
160:     return 0  # Image exists
161:   else
162:     return 1  # Image does not exist
163:   fi
164: }
165: # Authenticate Docker to ECR (using Deployment Account ID since ECR is in Deployment Account)
166: info "Authenticating Docker to ECR..."
167: if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$DEPLOYMENT_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" 2>/dev/null; then
168:   print_success "Docker authenticated to ECR"
169: else
170:   print_error "Failed to authenticate Docker to ECR"
171:   exit 1
172: fi
173: echo ""
174: # Define images to mirror with specific tags
175: # Format: "source_image:tag ecr_tag"
176: # Note: Using 'latest' tag for Bitnami images as other tags use SHA values
177: IMAGES=(
178:   "bitnami/redis:latest redis-latest"
179:   "bitnami/postgresql:latest postgresql-latest"
180:   "osixia/openldap:1.5.0 openldap-1.5.0"
181: )
182: info "Checking which images need to be mirrored..."
183: echo ""
184: IMAGES_TO_MIRROR=()
185: IMAGES_ALREADY_EXIST=()
186: for image_spec in "${IMAGES[@]}"; do
187:   read -r SOURCE_IMAGE ECR_TAG <<< "$image_spec"
188:   if check_ecr_image_exists "$ECR_TAG"; then
189:     info "✓ Image already exists in ECR: $ECR_TAG"
190:     IMAGES_ALREADY_EXIST+=("$ECR_TAG")
191:   else
192:     info "✗ Image not found in ECR: $ECR_TAG (will be mirrored)"
193:     IMAGES_TO_MIRROR+=("$image_spec")
194:   fi
195: done
196: echo ""
197: if [ ${#IMAGES_ALREADY_EXIST[@]} -gt 0 ]; then
198:   print_success "${#IMAGES_ALREADY_EXIST[@]} image(s) already exist in ECR - skipping"
199: fi
200: if [ ${#IMAGES_TO_MIRROR[@]} -eq 0 ]; then
201:   print_success "All required images already exist in ECR. No mirroring needed."
202:   echo ""
203:   exit 0
204: fi
205: info "${#IMAGES_TO_MIRROR[@]} image(s) need to be mirrored to ECR..."
206: echo ""
207: for image_spec in "${IMAGES_TO_MIRROR[@]}"; do
208:   read -r SOURCE_IMAGE ECR_TAG <<< "$image_spec"
209:   info "Processing: $SOURCE_IMAGE -> $ECR_TAG"
210:   # Pull image from Docker Hub
211:   info "  Pulling $SOURCE_IMAGE from Docker Hub..."
212:   if ! docker pull --platform linux/amd64 "$SOURCE_IMAGE"; then
213:     print_error "  Failed to pull $SOURCE_IMAGE"
214:     exit 1
215:   fi
216:   print_success "  Successfully pulled $SOURCE_IMAGE"
217:   # Tag for ECR
218:   ECR_IMAGE="$ECR_URL:$ECR_TAG"
219:   info "  Tagging as $ECR_IMAGE..."
220:   docker tag "$SOURCE_IMAGE" "$ECR_IMAGE"
221:   # Push to ECR
222:   info "  Pushing to ECR..."
223:   if ! docker push "$ECR_IMAGE"; then
224:     print_error "  Failed to push $ECR_IMAGE"
225:     exit 1
226:   fi
227:   print_success "  Successfully pushed $ECR_IMAGE"
228:   # Clean up local images to save space
229:   info "  Cleaning up local images..."
230:   docker rmi "$SOURCE_IMAGE" "$ECR_IMAGE" 2>/dev/null || true
231:   echo ""
232: done
233: print_success "Image mirroring complete!"
234: echo ""
235: # List all images in ECR repository
236: info "Current images in ECR repository '$ECR_REPO_NAME':"
237: aws ecr describe-images --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" \
238:   --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
239:   --output table 2>/dev/null || print_info "Could not list ECR images"
240: echo ""
241: print_success "ECR images are ready for deployment"
```

## File: tf_backend_state/get-state.sh
```bash
  1: #!/bin/bash
  2: # Script to assume AWS role and download Terraform state file from S3 if it exists
  3: # ROLE_ARN is retrieved from GitHub repository secret 'AWS_STATE_ACCOUNT_ROLE_ARN'
  4: # REGION is retrieved from GitHub repository variable 'AWS_REGION' (defaults to 'us-east-1' if not set)
  5: # Bucket name and prefix are retrieved from GitHub repository variables
  6: set -euo pipefail
  7: # Clean up any existing AWS credentials from environment to prevent conflicts
  8: # This ensures the script starts with a clean slate and uses the correct credentials
  9: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
 10: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 11: unset AWS_SESSION_TOKEN 2>/dev/null || true
 12: unset AWS_PROFILE 2>/dev/null || true
 13: # Colors for output
 14: RED='\033[0;31m'
 15: GREEN='\033[0;32m'
 16: YELLOW='\033[1;33m'
 17: NC='\033[0m' # No Color
 18: # Function to print colored messages
 19: print_error() {
 20:     echo -e "${RED}ERROR:${NC} $1" >&2
 21: }
 22: print_success() {
 23:     echo -e "${GREEN}SUCCESS:${NC} $1"
 24: }
 25: print_info() {
 26:     echo -e "${YELLOW}INFO:${NC} $1"
 27: }
 28: # Check if AWS CLI is installed
 29: if ! command -v aws &> /dev/null; then
 30:     print_error "AWS CLI is not installed."
 31:     echo "Please install it from: https://aws.amazon.com/cli/"
 32:     exit 1
 33: fi
 34: # Check if GitHub CLI is installed
 35: if ! command -v gh &> /dev/null; then
 36:     print_error "GitHub CLI (gh) is not installed."
 37:     echo "Please install it from: https://cli.github.com/"
 38:     echo ""
 39:     echo "Or use the alternative method with curl (requires GITHUB_TOKEN environment variable):"
 40:     echo "  export GITHUB_TOKEN=your_token"
 41:     exit 1
 42: fi
 43: # Check if user is authenticated with GitHub CLI
 44: if ! gh auth status &> /dev/null; then
 45:     print_error "Not authenticated with GitHub CLI."
 46:     echo "Please run: gh auth login"
 47:     exit 1
 48: fi
 49: # Check if jq is installed (required for gh --jq flag)
 50: if ! command -v jq &> /dev/null; then
 51:     print_error "jq is not installed."
 52:     echo "Please install it:"
 53:     echo "  macOS: brew install jq"
 54:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 55:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 56:     exit 1
 57: fi
 58: # Get repository owner and name
 59: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 60: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 61: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 62:     print_error "Could not determine repository information."
 63:     echo "Please ensure you're in a git repository and have proper permissions."
 64:     exit 1
 65: fi
 66: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 67: # Function to get repository variable using GitHub CLI
 68: get_repo_variable() {
 69:     local var_name=$1
 70:     local value
 71:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 72:     if [ -z "$value" ]; then
 73:         return 1
 74:     fi
 75:     echo "$value"
 76: }
 77: # Function to retrieve secret from AWS Secrets Manager
 78: get_aws_secret() {
 79:     local secret_name=$1
 80:     local secret_json
 81:     local exit_code
 82:     # Retrieve secret from AWS Secrets Manager
 83:     # Use AWS_REGION if set, otherwise default to us-east-1
 84:     secret_json=$(aws secretsmanager get-secret-value \
 85:         --secret-id "$secret_name" \
 86:         --region "${AWS_REGION:-us-east-1}" \
 87:         --query SecretString \
 88:         --output text 2>&1)
 89:     # Capture exit code before checking
 90:     exit_code=$?
 91:     # Validate secret retrieval
 92:     if [ $exit_code -ne 0 ]; then
 93:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
 94:         print_error "Error: $secret_json"
 95:         return 1
 96:     fi
 97:     # Validate JSON can be parsed
 98:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
 99:         print_error "Secret '${secret_name}' contains invalid JSON"
100:         return 1
101:     fi
102:     echo "$secret_json"
103: }
104: # Function to get key value from secret JSON
105: get_secret_key_value() {
106:     local secret_json=$1
107:     local key_name=$2
108:     local value
109:     # Validate JSON can be parsed
110:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
111:         print_error "Invalid JSON provided to get_secret_key_value"
112:         return 1
113:     fi
114:     # Extract key value using jq
115:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
116:     # Check if jq command succeeded
117:     if [ $? -ne 0 ]; then
118:         print_error "Failed to parse JSON or extract key '${key_name}'"
119:         return 1
120:     fi
121:     # Check if key exists (jq returns "null" for non-existent keys)
122:     if [ "$value" = "null" ] || [ -z "$value" ]; then
123:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
124:         return 1
125:     fi
126:     echo "$value"
127: }
128: # Retrieve ROLE_ARN from AWS Secrets Manager
129: print_info "Retrieving AWS_STATE_ACCOUNT_ROLE_ARN from AWS Secrets Manager..."
130: SECRET_JSON=$(get_aws_secret "github-role" || echo "")
131: if [ -z "$SECRET_JSON" ]; then
132:     print_error "Failed to retrieve secret from AWS Secrets Manager"
133:     exit 1
134: fi
135: ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
136: if [ -z "$ROLE_ARN" ]; then
137:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
138:     exit 1
139: fi
140: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
141: # Retrieve REGION from repository variable
142: print_info "Retrieving AWS_REGION from repository variables..."
143: REGION=$(get_repo_variable "AWS_REGION" || echo "")
144: if [ -z "$REGION" ]; then
145:     print_info "AWS_REGION not found in repository variables, defaulting to 'us-east-1'"
146:     REGION="us-east-1"
147: else
148:     print_success "Retrieved AWS_REGION: $REGION"
149: fi
150: print_info "Assuming role: $ROLE_ARN"
151: print_info "Region: $REGION"
152: # Assume the role first
153: ROLE_SESSION_NAME="get-state-$(date +%s)"
154: # Assume role and capture output
155: ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
156:     --role-arn "$ROLE_ARN" \
157:     --role-session-name "$ROLE_SESSION_NAME" \
158:     --region "$REGION" 2>&1)
159: if [ $? -ne 0 ]; then
160:     print_error "Failed to assume role: $ASSUME_ROLE_OUTPUT"
161:     exit 1
162: fi
163: # Extract credentials from JSON output
164: # Try using jq if available (more reliable), otherwise use sed/grep
165: if command -v jq &> /dev/null; then
166:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
167:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
168:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
169: else
170:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
171:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
172:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
173:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
174: fi
175: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
176:     print_error "Failed to extract credentials from assume-role output."
177:     print_error "Output was: $ASSUME_ROLE_OUTPUT"
178:     exit 1
179: fi
180: print_success "Successfully assumed role"
181: # Verify the credentials work
182: CALLER_ARN=$(aws sts get-caller-identity --region "$REGION" --query 'Arn' --output text 2>&1)
183: if [ $? -ne 0 ]; then
184:     print_error "Failed to verify assumed role credentials: $CALLER_ARN"
185:     exit 1
186: fi
187: print_info "Assumed role identity: $CALLER_ARN"
188: # Retrieve repository variables
189: print_info "Retrieving repository variables from GitHub..."
190: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME" || echo "")
191: if [ -z "$BUCKET_NAME" ]; then
192:     print_info "BACKEND_BUCKET_NAME not found in repository variables."
193:     print_info "This means the infrastructure has not been provisioned yet."
194:     print_info "There is no existing state file to download."
195:     print_success "Script completed successfully (no state file exists)"
196:     exit 0
197: fi
198: print_success "Retrieved BACKEND_BUCKET_NAME: $BUCKET_NAME"
199: BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX" || echo "")
200: if [ -z "$BACKEND_PREFIX" ]; then
201:     print_error "BACKEND_PREFIX not found in repository variables."
202:     echo "Please ensure BACKEND_PREFIX is set in GitHub repository variables."
203:     exit 1
204: fi
205: print_success "Retrieved BACKEND_PREFIX: $BACKEND_PREFIX"
206: # Check if state file exists in S3
207: S3_PATH="s3://${BUCKET_NAME}/${BACKEND_PREFIX}"
208: print_info "Checking for state file at: $S3_PATH"
209: # Use aws s3 ls to check if the file exists
210: # This command will return 0 if the file exists, non-zero if it doesn't
211: if aws s3 ls "$S3_PATH" --region "$REGION" &>/dev/null; then
212:     print_success "State file exists, downloading..."
213:     # Download the state file
214:     if aws s3 cp "$S3_PATH" terraform.tfstate --region "$REGION"; then
215:         print_success "State file downloaded successfully to terraform.tfstate"
216:     else
217:         print_error "Failed to download state file"
218:         exit 1
219:     fi
220: else
221:     print_info "State file does not exist at $S3_PATH"
222:     print_info "This is expected if this is the first time provisioning the infrastructure."
223:     # Don't exit with error - just inform the user
224: fi
225: print_success "Script completed successfully"
```

## File: tf_backend_state/main.tf
```hcl
 1: # Get current AWS account ID and caller identity for unique bucket naming and dynamic principal
 2: data "aws_caller_identity" "current" {}
 3:
 4: resource "aws_s3_bucket" "terraform_state" {
 5:   # Include account ID in bucket name to ensure global uniqueness
 6:   bucket        = "${var.prefix}-${data.aws_caller_identity.current.account_id}-s3-tfstate"
 7:   force_destroy = true
 8:
 9:   tags = {
10:     Name      = "${var.prefix}-${data.aws_caller_identity.current.account_id}-s3-tfstate"
11:     Env       = var.env
12:     Terraform = true
13:   }
14: }
15:
16: resource "aws_s3_bucket_acl" "terraform_state_acl" {
17:   bucket     = aws_s3_bucket.terraform_state.bucket
18:   acl        = "private"
19:   depends_on = [aws_s3_bucket_ownership_controls.terraform_state_acl_ownership]
20: }
21:
22: # Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
23: resource "aws_s3_bucket_ownership_controls" "terraform_state_acl_ownership" {
24:   bucket = aws_s3_bucket.terraform_state.bucket
25:   rule {
26:     object_ownership = "ObjectWriter"
27:   }
28: }
29:
30: resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
31:   bucket = aws_s3_bucket.terraform_state.bucket
32:   versioning_configuration {
33:     status = "Enabled"
34:   }
35: }
36:
37: # Block public access to the state bucket
38: resource "aws_s3_bucket_public_access_block" "terraform_state_public_block" {
39:   bucket = aws_s3_bucket.terraform_state.bucket
40:
41:   block_public_acls       = true
42:   block_public_policy     = true
43:   ignore_public_acls      = true
44:   restrict_public_buckets = true
45: }
46:
47: resource "aws_s3_bucket_policy" "terraform_state_policy" {
48:   bucket = aws_s3_bucket.terraform_state.bucket
49:   depends_on = [
50:     aws_s3_bucket.terraform_state,
51:     aws_s3_bucket_public_access_block.terraform_state_public_block
52:   ]
53:   policy = jsonencode({
54:     Version = "2012-10-17"
55:     Statement = [
56:       {
57:         Sid    = "ListGetPutDeleteBucketContents"
58:         Effect = "Allow"
59:         Action = [
60:           "s3:ListBucket",
61:           "s3:GetObject",
62:           "s3:PutObject",
63:           "s3:DeleteObject"
64:         ]
65:         Principal = {
66:           AWS = data.aws_caller_identity.current.arn
67:         }
68:         Resource = [
69:           "arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}",
70:           "arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"
71:         ]
72:       }
73:     ]
74:   })
75: }
76:
77: # Add bucket encryption to hide sensitive state data
78: resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
79:   bucket = aws_s3_bucket.terraform_state.bucket
80:   rule {
81:     apply_server_side_encryption_by_default {
82:       sse_algorithm = "AES256"
83:     }
84:   }
85: }
```

## File: .github/workflows/tfstate_infra_provisioning.yaml
```yaml
  1: name: TF Backend State Provisioning
  2: on:
  3:   workflow_dispatch:
  4: jobs:
  5:   InfraProvision:
  6:     runs-on: ubuntu-latest
  7:     permissions:
  8:       contents: write
  9:       actions: write
 10:       id-token: write
 11:     env:
 12:       AWS_REGION: ${{ vars.AWS_REGION }}
 13:     defaults:
 14:       run:
 15:         working-directory: ./tf_backend_state
 16:     steps:
 17:       - name: Checkout the repo code
 18:         uses: actions/checkout@v4
 19:       - name: Setup terraform
 20:         uses: hashicorp/setup-terraform@v3
 21:         with:
 22:           terraform_version: 1.14.0
 23:       - name: Configure AWS credentials (State Account)
 24:         uses: aws-actions/configure-aws-credentials@v4
 25:         with:
 26:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
 27:           role-session-name: GitHubActions-TFStateInfraProvision
 28:           aws-region: ${{ env.AWS_REGION }}
 29:       - name: Check for existing state file
 30:         uses: actions/github-script@v7
 31:         id: check_state
 32:         with:
 33:           github-token: ${{ secrets.GH_TOKEN }}
 34:           script: |
 35:             const repo = context.repo;
 36:             let bucketName = '';
 37:             let exists = 'false';
 38:             try {
 39:               // Try to get existing BACKEND_BUCKET_NAME variable
 40:               const response = await github.rest.actions.getRepoVariable({
 41:                 owner: repo.owner,
 42:                 repo: repo.repo,
 43:                 name: 'BACKEND_BUCKET_NAME'
 44:               });
 45:               bucketName = response.data.value || '';
 46:               if (bucketName) {
 47:                 console.log(`Found existing BACKEND_BUCKET_NAME: ${bucketName}`);
 48:                 exists = 'true';
 49:               } else {
 50:                 console.log('BACKEND_BUCKET_NAME variable exists but is empty');
 51:                 exists = 'false';
 52:               }
 53:             } catch (error) {
 54:               if (error.status === 404) {
 55:                 console.log('BACKEND_BUCKET_NAME variable does not exist, proceeding with new provisioning');
 56:                 exists = 'false';
 57:               } else {
 58:                 console.error('Error checking repository variable:', error.message);
 59:                 throw error;
 60:               }
 61:             }
 62:             // Always set outputs to avoid linter warnings
 63:             core.setOutput('bucket_name', bucketName);
 64:             core.setOutput('exists', exists);
 65:       - name: Download existing state file if available
 66:         # Outputs are always set by check_state step (see line 70-71)
 67:         if: steps.check_state.outputs.exists == 'true' && steps.check_state.outputs.bucket_name != ''
 68:         env:
 69:           BUCKET_NAME: ${{ steps.check_state.outputs.bucket_name }}
 70:           BACKEND_PREFIX: ${{ vars.BACKEND_PREFIX }}
 71:         run: |
 72:           if [ -z "$BUCKET_NAME" ] || [ -z "$BACKEND_PREFIX" ]; then
 73:             echo "Bucket name or prefix is empty, skipping state file download"
 74:             exit 0
 75:           fi
 76:           S3_PATH="s3://${BUCKET_NAME}/${BACKEND_PREFIX}"
 77:           echo "Attempting to download state file from: ${S3_PATH}"
 78:           if aws s3 ls "$S3_PATH" 2>/dev/null | grep -q .; then
 79:             echo "State file exists, downloading..."
 80:             aws s3 cp "$S3_PATH" terraform.tfstate
 81:             echo "State file downloaded successfully"
 82:           else
 83:             echo "State file does not exist in S3, proceeding with new provisioning"
 84:           fi
 85:       - name: Terraform init
 86:         run: terraform init -backend=false
 87:       - name: Terraform validate
 88:         run: terraform validate
 89:       - name: Terraform plan
 90:         run: terraform plan -var-file="variables.tfvars" -out terraform.tfplan
 91:       - name: Provision backend state
 92:         id: provision_backend
 93:         run: |
 94:           terraform apply -auto-approve terraform.tfplan
 95:           BUCKET_NAME=$(terraform output -raw bucket_name)
 96:           echo "bucket_name=$BUCKET_NAME" >> $GITHUB_OUTPUT
 97:       - name: Save bucket name to GitHub repository variable
 98:         uses: actions/github-script@v7
 99:         env:
100:           BUCKET_NAME: ${{ steps.provision_backend.outputs.bucket_name }}
101:         with:
102:           github-token: ${{ secrets.GH_TOKEN }}
103:           script: |
104:             const bucketName = process.env.BUCKET_NAME;
105:             const repo = context.repo;
106:             if (!bucketName || bucketName.trim() === '') {
107:               throw new Error('BUCKET_NAME is not set or is empty');
108:             }
109:             console.log(`Saving bucket name: ${bucketName}`);
110:             try {
111:               // Try to get existing bucket name variable
112:               try {
113:                 await github.rest.actions.getRepoVariable({
114:                   owner: repo.owner,
115:                   repo: repo.repo,
116:                   name: 'BACKEND_BUCKET_NAME'
117:                 });
118:                 // Update existing bucket name variable
119:                 await github.rest.actions.updateRepoVariable({
120:                   owner: repo.owner,
121:                   repo: repo.repo,
122:                   name: 'BACKEND_BUCKET_NAME',
123:                   value: bucketName
124:                 });
125:                 console.log('Updated repository variable BACKEND_BUCKET_NAME');
126:               } catch (error) {
127:                 if (error.status === 404) {
128:                   // Variable doesn't exist, create it
129:                   await github.rest.actions.createRepoVariable({
130:                     owner: repo.owner,
131:                     repo: repo.repo,
132:                     name: 'BACKEND_BUCKET_NAME',
133:                     value: bucketName
134:                   });
135:                   console.log('Created repository variable BACKEND_BUCKET_NAME');
136:                 } else {
137:                   throw error;
138:                 }
139:               }
140:             } catch (error) {
141:               console.error('Error saving repository variable:', error.message);
142:               console.error('Note: GITHUB_TOKEN may need write permissions for repository variables.');
143:               console.error('Please ensure "Allow GitHub Actions to create and approve pull requests" is enabled in repository settings.');
144:               throw error;
145:             }
146:       - name: Upload backend state file to S3
147:         # Always upload state file to ensure synchronization
148:         env:
149:           BUCKET_NAME: ${{ steps.provision_backend.outputs.bucket_name }}
150:           BACKEND_PREFIX: ${{ vars.BACKEND_PREFIX }}
151:         run: |
152:           if [ -z "$BUCKET_NAME" ] || [ -z "$BACKEND_PREFIX" ]; then
153:             echo "Error: BUCKET_NAME or BACKEND_PREFIX is empty"
154:             exit 1
155:           fi
156:           echo "Uploading state file to s3://${BUCKET_NAME}/${BACKEND_PREFIX}"
157:           aws s3 cp terraform.tfstate s3://${BUCKET_NAME}/${BACKEND_PREFIX}
158:           echo "State file uploaded successfully"
```

## File: application/backend/src/app/ldap/client.py
```python
  1: """LDAP client for user authentication and management."""
  2: import logging
  3: from typing import Optional
  4: import ldap3
  5: from ldap3 import ALL, MODIFY_ADD, MODIFY_DELETE, MODIFY_REPLACE, Connection, Server
  6: from ldap3.core.exceptions import LDAPException
  7: from ldap3.utils.dn import escape_rdn
  8: from app.config import Settings, get_settings
  9: logger = logging.getLogger(__name__)
 10: class LDAPClient:
 11:     """Client for LDAP authentication and user management operations."""
 12:     def __init__(self, settings: Optional[Settings] = None):
 13:         """Initialize LDAP client with settings."""
 14:         self.settings = settings or get_settings()
 15:         self._server: Optional[Server] = None
 16:     @property
 17:     def server(self) -> Server:
 18:         """Get or create LDAP server connection."""
 19:         if self._server is None:
 20:             self._server = Server(
 21:                 host=self.settings.ldap_host,
 22:                 port=self.settings.ldap_port,
 23:                 use_ssl=self.settings.ldap_use_ssl,
 24:                 get_info=ALL,
 25:             )
 26:         return self._server
 27:     def _get_admin_connection(self) -> Connection:
 28:         """Get an admin connection to LDAP."""
 29:         return Connection(
 30:             self.server,
 31:             user=self.settings.ldap_admin_dn,
 32:             password=self.settings.ldap_admin_password,
 33:             auto_bind=True,
 34:             raise_exceptions=True,
 35:         )
 36:     def _get_user_search_base(self) -> str:
 37:         """Get the full user search base DN."""
 38:         user_search_base = self.settings.ldap_user_search_base
 39:         if not user_search_base.endswith(self.settings.ldap_base_dn):
 40:             user_search_base = f"{user_search_base},{self.settings.ldap_base_dn}"
 41:         return user_search_base
 42:     def _get_user_dn(self, username: str) -> str:
 43:         """Construct the user DN from username."""
 44:         return f"uid={username},{self._get_user_search_base()}"
 45:     def _get_group_search_base(self) -> str:
 46:         """Get the full group search base DN."""
 47:         group_search_base = self.settings.ldap_group_search_base
 48:         if not group_search_base.endswith(self.settings.ldap_base_dn):
 49:             group_search_base = f"{group_search_base},{self.settings.ldap_base_dn}"
 50:         return group_search_base
 51:     def _get_group_dn(self, group_name: str) -> str:
 52:         """Construct the group DN from group name."""
 53:         return f"cn={group_name},{self._get_group_search_base()}"
 54:     def _get_next_uid_number(self, conn: Connection) -> int:
 55:         """Get the next available UID number."""
 56:         try:
 57:             conn.search(
 58:                 search_base=self._get_user_search_base(),
 59:                 search_filter="(objectClass=posixAccount)",
 60:                 attributes=["uidNumber"],
 61:             )
 62:             max_uid = self.settings.ldap_uid_start
 63:             for entry in conn.entries:
 64:                 if hasattr(entry, "uidNumber") and entry.uidNumber.value:
 65:                     uid = int(entry.uidNumber.value)
 66:                     if uid >= max_uid:
 67:                         max_uid = uid + 1
 68:             return max_uid
 69:         except Exception as e:
 70:             logger.warning(f"Error getting next UID, using default: {e}")
 71:             return self.settings.ldap_uid_start
 72:     def authenticate(self, username: str, password: str) -> tuple[bool, str]:
 73:         """
 74:         Authenticate a user against LDAP.
 75:         Args:
 76:             username: The username to authenticate
 77:             password: The user's password
 78:         Returns:
 79:             Tuple of (success: bool, message: str)
 80:         """
 81:         if not password:
 82:             return False, "Password cannot be empty"
 83:         user_dn = self._get_user_dn(username)
 84:         logger.debug(f"Attempting to authenticate user DN: {user_dn}")
 85:         try:
 86:             conn = Connection(
 87:                 self.server,
 88:                 user=user_dn,
 89:                 password=password,
 90:                 auto_bind=True,
 91:                 raise_exceptions=True,
 92:             )
 93:             conn.unbind()
 94:             logger.info(f"Successfully authenticated user: {username}")
 95:             return True, "Authentication successful"
 96:         except ldap3.core.exceptions.LDAPBindError as e:
 97:             logger.warning(f"Authentication failed for user {username}: {e}")
 98:             return False, "Invalid username or password"
 99:         except LDAPException as e:
100:             logger.error(f"LDAP error during authentication: {e}")
101:             return False, f"LDAP error: {e!s}"
102:         except Exception as e:
103:             logger.error(f"Unexpected error during authentication: {e}")
104:             return False, f"Authentication error: {e!s}"
105:     def user_exists(self, username: str) -> bool:
106:         """
107:         Check if a user exists in LDAP.
108:         Args:
109:             username: The username to check
110:         Returns:
111:             True if user exists, False otherwise
112:         """
113:         try:
114:             conn = self._get_admin_connection()
115:             search_filter = self.settings.ldap_user_search_filter.format(username)
116:             conn.search(
117:                 search_base=self._get_user_search_base(),
118:                 search_filter=search_filter,
119:                 attributes=["uid"],
120:             )
121:             exists = len(conn.entries) > 0
122:             conn.unbind()
123:             return exists
124:         except LDAPException as e:
125:             logger.error(f"LDAP error checking user existence: {e}")
126:             return False
127:     def get_user_attribute(
128:         self, username: str, attribute: str
129:     ) -> Optional[str]:
130:         """
131:         Get a user attribute from LDAP.
132:         Args:
133:             username: The username
134:             attribute: The attribute name to retrieve
135:         Returns:
136:             The attribute value or None if not found
137:         """
138:         try:
139:             conn = self._get_admin_connection()
140:             search_filter = self.settings.ldap_user_search_filter.format(username)
141:             conn.search(
142:                 search_base=self._get_user_search_base(),
143:                 search_filter=search_filter,
144:                 attributes=[attribute],
145:             )
146:             if conn.entries:
147:                 entry = conn.entries[0]
148:                 if hasattr(entry, attribute):
149:                     value = getattr(entry, attribute).value
150:                     conn.unbind()
151:                     return value
152:             conn.unbind()
153:             return None
154:         except LDAPException as e:
155:             logger.error(f"LDAP error getting user attribute: {e}")
156:             return None
157:     def create_user(
158:         self,
159:         username: str,
160:         password: str,
161:         first_name: str,
162:         last_name: str,
163:         email: str,
164:     ) -> tuple[bool, str]:
165:         """
166:         Create a new user in LDAP.
167:         Args:
168:             username: The username (uid)
169:             password: The user's password
170:             first_name: User's first name
171:             last_name: User's last name
172:             email: User's email address
173:         Returns:
174:             Tuple of (success: bool, message: str)
175:         """
176:         user_dn = self._get_user_dn(username)
177:         try:
178:             conn = self._get_admin_connection()
179:             # Check if user already exists
180:             if self.user_exists(username):
181:                 conn.unbind()
182:                 return False, f"User {username} already exists in LDAP"
183:             # Get next available UID number
184:             uid_number = self._get_next_uid_number(conn)
185:             # Build user attributes
186:             # Using inetOrgPerson + posixAccount for compatibility
187:             attributes = {
188:                 "objectClass": [
189:                     "inetOrgPerson",
190:                     "posixAccount",
191:                     "shadowAccount",
192:                     "top",
193:                 ],
194:                 "uid": username,
195:                 "cn": f"{first_name} {last_name}",
196:                 "sn": last_name,
197:                 "givenName": first_name,
198:                 "mail": email,
199:                 "userPassword": password,
200:                 "uidNumber": str(uid_number),
201:                 "gidNumber": str(self.settings.ldap_users_gid),
202:                 "homeDirectory": f"/home/{username}",
203:                 "loginShell": "/bin/bash",
204:             }
205:             # Create the user
206:             success = conn.add(user_dn, attributes=attributes)
207:             if success:
208:                 logger.info(f"Created LDAP user: {username} (UID: {uid_number})")
209:                 conn.unbind()
210:                 return True, f"User {username} created successfully"
211:             else:
212:                 error_msg = conn.result.get("description", "Unknown error")
213:                 logger.error(f"Failed to create LDAP user {username}: {error_msg}")
214:                 conn.unbind()
215:                 return False, f"Failed to create user: {error_msg}"
216:         except LDAPException as e:
217:             logger.error(f"LDAP error creating user {username}: {e}")
218:             return False, f"LDAP error: {e!s}"
219:         except Exception as e:
220:             logger.error(f"Unexpected error creating user {username}: {e}")
221:             return False, f"Error creating user: {e!s}"
222:     def delete_user(self, username: str) -> tuple[bool, str]:
223:         """
224:         Delete a user from LDAP.
225:         Args:
226:             username: The username to delete
227:         Returns:
228:             Tuple of (success: bool, message: str)
229:         """
230:         user_dn = self._get_user_dn(username)
231:         try:
232:             conn = self._get_admin_connection()
233:             success = conn.delete(user_dn)
234:             if success:
235:                 logger.info(f"Deleted LDAP user: {username}")
236:                 conn.unbind()
237:                 return True, f"User {username} deleted successfully"
238:             else:
239:                 error_msg = conn.result.get("description", "Unknown error")
240:                 logger.error(f"Failed to delete LDAP user {username}: {error_msg}")
241:                 conn.unbind()
242:                 return False, f"Failed to delete user: {error_msg}"
243:         except LDAPException as e:
244:             logger.error(f"LDAP error deleting user {username}: {e}")
245:             return False, f"LDAP error: {e!s}"
246:         except Exception as e:
247:             logger.error(f"Unexpected error deleting user {username}: {e}")
248:             return False, f"Error deleting user: {e!s}"
249:     def is_admin(self, username: str) -> bool:
250:         """
251:         Check if a user is a member of the admin group.
252:         Args:
253:             username: The username to check
254:         Returns:
255:             True if user is an admin, False otherwise
256:         """
257:         try:
258:             conn = self._get_admin_connection()
259:             admin_group_dn = self.settings.ldap_admin_group_dn
260:             # Search for the admin group and check membership
261:             # Groups typically use 'member' or 'memberUid' attribute
262:             conn.search(
263:                 search_base=admin_group_dn,
264:                 search_filter="(objectClass=*)",
265:                 attributes=["member", "memberUid", "uniqueMember"],
266:             )
267:             if not conn.entries:
268:                 logger.debug(f"Admin group not found: {admin_group_dn}")
269:                 conn.unbind()
270:                 return False
271:             entry = conn.entries[0]
272:             user_dn = self._get_user_dn(username)
273:             # Check different membership attribute types
274:             # member/uniqueMember uses full DN
275:             if hasattr(entry, "member") and entry.member.values:
276:                 if user_dn.lower() in [m.lower() for m in entry.member.values]:
277:                     conn.unbind()
278:                     return True
279:             if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
280:                 if user_dn.lower() in [m.lower() for m in entry.uniqueMember.values]:
281:                     conn.unbind()
282:                     return True
283:             # memberUid uses just the username
284:             if hasattr(entry, "memberUid") and entry.memberUid.values:
285:                 if username.lower() in [m.lower() for m in entry.memberUid.values]:
286:                     conn.unbind()
287:                     return True
288:             conn.unbind()
289:             return False
290:         except LDAPException as e:
291:             logger.error(f"LDAP error checking admin status for {username}: {e}")
292:             return False
293:         except Exception as e:
294:             logger.error(f"Unexpected error checking admin status for {username}: {e}")
295:             return False
296:     def add_user_to_group(self, username: str, group_dn: str) -> tuple[bool, str]:
297:         """
298:         Add a user to an LDAP group.
299:         Args:
300:             username: The username to add
301:             group_dn: The DN of the group
302:         Returns:
303:             Tuple of (success: bool, message: str)
304:         """
305:         user_dn = self._get_user_dn(username)
306:         try:
307:             conn = self._get_admin_connection()
308:             # Try to add as member (for groupOfNames/groupOfUniqueNames)
309:             success = conn.modify(
310:                 group_dn,
311:                 {"member": [(MODIFY_ADD, [user_dn])]}
312:             )
313:             if not success:
314:                 # Try memberUid instead (for posixGroup)
315:                 success = conn.modify(
316:                     group_dn,
317:                     {"memberUid": [(MODIFY_ADD, [username])]}
318:                 )
319:             if success:
320:                 logger.info(f"Added user {username} to group {group_dn}")
321:                 conn.unbind()
322:                 return True, f"User added to group successfully"
323:             else:
324:                 error_msg = conn.result.get("description", "Unknown error")
325:                 logger.error(f"Failed to add {username} to group: {error_msg}")
326:                 conn.unbind()
327:                 return False, f"Failed to add to group: {error_msg}"
328:         except LDAPException as e:
329:             logger.error(f"LDAP error adding user to group: {e}")
330:             return False, f"LDAP error: {e!s}"
331:         except Exception as e:
332:             logger.error(f"Unexpected error adding user to group: {e}")
333:             return False, f"Error: {e!s}"
334:     def remove_user_from_group(self, username: str, group_dn: str) -> tuple[bool, str]:
335:         """
336:         Remove a user from an LDAP group.
337:         Args:
338:             username: The username to remove
339:             group_dn: The DN of the group
340:         Returns:
341:             Tuple of (success: bool, message: str)
342:         """
343:         user_dn = self._get_user_dn(username)
344:         try:
345:             conn = self._get_admin_connection()
346:             # Try to remove as member (for groupOfNames/groupOfUniqueNames)
347:             success = conn.modify(
348:                 group_dn,
349:                 {"member": [(MODIFY_DELETE, [user_dn])]}
350:             )
351:             if not success:
352:                 # Try memberUid instead (for posixGroup)
353:                 success = conn.modify(
354:                     group_dn,
355:                     {"memberUid": [(MODIFY_DELETE, [username])]}
356:                 )
357:             if success:
358:                 logger.info(f"Removed user {username} from group {group_dn}")
359:                 conn.unbind()
360:                 return True, "User removed from group successfully"
361:             else:
362:                 error_msg = conn.result.get("description", "Unknown error")
363:                 logger.error(f"Failed to remove {username} from group: {error_msg}")
364:                 conn.unbind()
365:                 return False, f"Failed to remove from group: {error_msg}"
366:         except LDAPException as e:
367:             logger.error(f"LDAP error removing user from group: {e}")
368:             return False, f"LDAP error: {e!s}"
369:         except Exception as e:
370:             logger.error(f"Unexpected error removing user from group: {e}")
371:             return False, f"Error: {e!s}"
372:     def list_groups(self) -> list[dict]:
373:         """
374:         List all LDAP groups.
375:         Returns:
376:             List of group dictionaries with dn, name, description, and members
377:         """
378:         groups = []
379:         try:
380:             conn = self._get_admin_connection()
381:             # Search for all groups
382:             conn.search(
383:                 search_base=self._get_group_search_base(),
384:                 search_filter="(|(objectClass=groupOfNames)(objectClass=groupOfUniqueNames)(objectClass=posixGroup))",
385:                 attributes=["cn", "description", "member", "memberUid", "uniqueMember"],
386:             )
387:             for entry in conn.entries:
388:                 group_data = {
389:                     "dn": str(entry.entry_dn),
390:                     "name": entry.cn.value if hasattr(entry, "cn") else "",
391:                     "description": entry.description.value if hasattr(entry, "description") and entry.description.value else "",
392:                     "members": [],
393:                 }
394:                 # Get members from different attribute types
395:                 if hasattr(entry, "member") and entry.member.values:
396:                     group_data["members"].extend(entry.member.values)
397:                 if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
398:                     group_data["members"].extend(entry.uniqueMember.values)
399:                 if hasattr(entry, "memberUid") and entry.memberUid.values:
400:                     group_data["members"].extend(entry.memberUid.values)
401:                 groups.append(group_data)
402:             conn.unbind()
403:             logger.info(f"Listed {len(groups)} LDAP groups")
404:             return groups
405:         except LDAPException as e:
406:             logger.error(f"LDAP error listing groups: {e}")
407:             return []
408:         except Exception as e:
409:             logger.error(f"Unexpected error listing groups: {e}")
410:             return []
411:     def create_group(
412:         self,
413:         name: str,
414:         description: str = "",
415:     ) -> tuple[bool, str, Optional[str]]:
416:         """
417:         Create a new LDAP group.
418:         Args:
419:             name: The group name (cn)
420:             description: Group description
421:         Returns:
422:             Tuple of (success: bool, message: str, group_dn: Optional[str])
423:         """
424:         # Escape the group name before using it in a DN or as the cn attribute
425:         safe_name = escape_rdn(name)
426:         group_dn = self._get_group_dn(safe_name)
427:         try:
428:             conn = self._get_admin_connection()
429:             # Check if group already exists
430:             conn.search(
431:                 search_base=group_dn,
432:                 search_filter="(objectClass=*)",
433:                 attributes=["cn"],
434:             )
435:             if conn.entries:
436:                 conn.unbind()
437:                 return False, f"Group {name} already exists", None
438:             # Create group with groupOfNames objectClass
439:             # Note: groupOfNames requires at least one member, using admin as placeholder
440:             attributes = {
441:                 "objectClass": ["groupOfNames", "top"],
442:                 "cn": safe_name,
443:                 "description": description or f"Group: {name}",
444:                 "member": [self.settings.ldap_admin_dn],  # Required initial member
445:             }
446:             success = conn.add(group_dn, attributes=attributes)
447:             if success:
448:                 logger.info(f"Created LDAP group: {name}")
449:                 conn.unbind()
450:                 return True, f"Group {name} created successfully", group_dn
451:             else:
452:                 error_msg = conn.result.get("description", "Unknown error")
453:                 logger.error(f"Failed to create LDAP group {name}: {error_msg}")
454:                 conn.unbind()
455:                 return False, f"Failed to create group: {error_msg}", None
456:         except LDAPException as e:
457:             logger.error(f"LDAP error creating group {name}: {e}")
458:             return False, f"LDAP error: {e!s}", None
459:         except Exception as e:
460:             logger.error(f"Unexpected error creating group {name}: {e}")
461:             return False, f"Error creating group: {e!s}", None
462:     def delete_group(self, group_dn: str) -> tuple[bool, str]:
463:         """
464:         Delete an LDAP group.
465:         Args:
466:             group_dn: The DN of the group to delete
467:         Returns:
468:             Tuple of (success: bool, message: str)
469:         """
470:         try:
471:             conn = self._get_admin_connection()
472:             success = conn.delete(group_dn)
473:             if success:
474:                 logger.info(f"Deleted LDAP group: {group_dn}")
475:                 conn.unbind()
476:                 return True, "Group deleted successfully"
477:             else:
478:                 error_msg = conn.result.get("description", "Unknown error")
479:                 logger.error(f"Failed to delete LDAP group {group_dn}: {error_msg}")
480:                 conn.unbind()
481:                 return False, f"Failed to delete group: {error_msg}"
482:         except LDAPException as e:
483:             logger.error(f"LDAP error deleting group {group_dn}: {e}")
484:             return False, f"LDAP error: {e!s}"
485:         except Exception as e:
486:             logger.error(f"Unexpected error deleting group {group_dn}: {e}")
487:             return False, f"Error deleting group: {e!s}"
488:     def update_group(
489:         self,
490:         group_dn: str,
491:         description: Optional[str] = None,
492:     ) -> tuple[bool, str]:
493:         """
494:         Update an LDAP group's description.
495:         Args:
496:             group_dn: The DN of the group
497:             description: New description (if provided)
498:         Returns:
499:             Tuple of (success: bool, message: str)
500:         """
501:         try:
502:             conn = self._get_admin_connection()
503:             modifications = {}
504:             if description is not None:
505:                 modifications["description"] = [(MODIFY_REPLACE, [description])]
506:             if not modifications:
507:                 conn.unbind()
508:                 return True, "No changes to apply"
509:             success = conn.modify(group_dn, modifications)
510:             if success:
511:                 logger.info(f"Updated LDAP group: {group_dn}")
512:                 conn.unbind()
513:                 return True, "Group updated successfully"
514:             else:
515:                 error_msg = conn.result.get("description", "Unknown error")
516:                 logger.error(f"Failed to update LDAP group {group_dn}: {error_msg}")
517:                 conn.unbind()
518:                 return False, f"Failed to update group: {error_msg}"
519:         except LDAPException as e:
520:             logger.error(f"LDAP error updating group {group_dn}: {e}")
521:             return False, f"LDAP error: {e!s}"
522:         except Exception as e:
523:             logger.error(f"Unexpected error updating group {group_dn}: {e}")
524:             return False, f"Error updating group: {e!s}"
525:     def get_user_groups(self, username: str) -> list[dict]:
526:         """
527:         Get all groups a user belongs to.
528:         Args:
529:             username: The username to check
530:         Returns:
531:             List of group dictionaries with dn and name
532:         """
533:         user_dn = self._get_user_dn(username)
534:         groups = []
535:         try:
536:             conn = self._get_admin_connection()
537:             # Search for groups containing this user
538:             # Check both member (DN) and memberUid (username)
539:             search_filter = f"(|(member={user_dn})(memberUid={username})(uniqueMember={user_dn}))"
540:             conn.search(
541:                 search_base=self._get_group_search_base(),
542:                 search_filter=search_filter,
543:                 attributes=["cn", "description"],
544:             )
545:             for entry in conn.entries:
546:                 groups.append({
547:                     "dn": str(entry.entry_dn),
548:                     "name": entry.cn.value if hasattr(entry, "cn") else "",
549:                     "description": entry.description.value if hasattr(entry, "description") and entry.description.value else "",
550:                 })
551:             conn.unbind()
552:             logger.debug(f"User {username} belongs to {len(groups)} groups")
553:             return groups
554:         except LDAPException as e:
555:             logger.error(f"LDAP error getting user groups for {username}: {e}")
556:             return []
557:         except Exception as e:
558:             logger.error(f"Unexpected error getting user groups for {username}: {e}")
559:             return []
560:     def get_admin_emails(self) -> list[str]:
561:         """
562:         Get email addresses of all admin group members.
563:         Returns:
564:             List of email addresses
565:         """
566:         emails = []
567:         try:
568:             conn = self._get_admin_connection()
569:             admin_group_dn = self.settings.ldap_admin_group_dn
570:             # Get admin group members
571:             conn.search(
572:                 search_base=admin_group_dn,
573:                 search_filter="(objectClass=*)",
574:                 attributes=["member", "memberUid", "uniqueMember"],
575:             )
576:             if not conn.entries:
577:                 logger.warning(f"Admin group not found: {admin_group_dn}")
578:                 conn.unbind()
579:                 return []
580:             entry = conn.entries[0]
581:             member_dns = []
582:             member_uids = []
583:             # Collect member DNs
584:             if hasattr(entry, "member") and entry.member.values:
585:                 member_dns.extend(entry.member.values)
586:             if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
587:                 member_dns.extend(entry.uniqueMember.values)
588:             if hasattr(entry, "memberUid") and entry.memberUid.values:
589:                 member_uids.extend(entry.memberUid.values)
590:             # Fetch email for each member DN
591:             for member_dn in member_dns:
592:                 try:
593:                     conn.search(
594:                         search_base=member_dn,
595:                         search_filter="(objectClass=*)",
596:                         attributes=["mail"],
597:                     )
598:                     if conn.entries and hasattr(conn.entries[0], "mail"):
599:                         mail = conn.entries[0].mail.value
600:                         if mail:
601:                             emails.append(mail)
602:                 except Exception as e:
603:                     logger.debug(f"Could not fetch email for {member_dn}: {e}")
604:             # Fetch email for each memberUid
605:             for uid in member_uids:
606:                 try:
607:                     search_filter = self.settings.ldap_user_search_filter.format(uid)
608:                     conn.search(
609:                         search_base=self._get_user_search_base(),
610:                         search_filter=search_filter,
611:                         attributes=["mail"],
612:                     )
613:                     if conn.entries and hasattr(conn.entries[0], "mail"):
614:                         mail = conn.entries[0].mail.value
615:                         if mail:
616:                             emails.append(mail)
617:                 except Exception as e:
618:                     logger.debug(f"Could not fetch email for uid {uid}: {e}")
619:             conn.unbind()
620:             # Remove duplicates while preserving order
621:             seen = set()
622:             unique_emails = []
623:             for email in emails:
624:                 if email not in seen:
625:                     seen.add(email)
626:                     unique_emails.append(email)
627:             logger.info(f"Found {len(unique_emails)} admin email addresses")
628:             return unique_emails
629:         except LDAPException as e:
630:             logger.error(f"LDAP error getting admin emails: {e}")
631:             return []
632:         except Exception as e:
633:             logger.error(f"Unexpected error getting admin emails: {e}")
634:             return []
635:     def get_group_members(self, group_dn: str) -> list[str]:
636:         """
637:         Get all members of a group.
638:         Args:
639:             group_dn: The DN of the group
640:         Returns:
641:             List of member usernames
642:         """
643:         members = []
644:         try:
645:             conn = self._get_admin_connection()
646:             conn.search(
647:                 search_base=group_dn,
648:                 search_filter="(objectClass=*)",
649:                 attributes=["member", "memberUid", "uniqueMember"],
650:             )
651:             if not conn.entries:
652:                 conn.unbind()
653:                 return []
654:             entry = conn.entries[0]
655:             # Get members from different attribute types
656:             if hasattr(entry, "memberUid") and entry.memberUid.values:
657:                 members.extend(entry.memberUid.values)
658:             # Extract username from DN for member/uniqueMember
659:             if hasattr(entry, "member") and entry.member.values:
660:                 for member_dn in entry.member.values:
661:                     # Extract uid from DN like "uid=username,ou=users,..."
662:                     if member_dn.lower().startswith("uid="):
663:                         parts = member_dn.split(",")
664:                         if parts:
665:                             uid = parts[0].split("=")[1] if "=" in parts[0] else ""
666:                             if uid:
667:                                 members.append(uid)
668:             if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
669:                 for member_dn in entry.uniqueMember.values:
670:                     if member_dn.lower().startswith("uid="):
671:                         parts = member_dn.split(",")
672:                         if parts:
673:                             uid = parts[0].split("=")[1] if "=" in parts[0] else ""
674:                             if uid:
675:                                 members.append(uid)
676:             conn.unbind()
677:             # Remove duplicates
678:             return list(set(members))
679:         except LDAPException as e:
680:             logger.error(f"LDAP error getting group members for {group_dn}: {e}")
681:             return []
682:         except Exception as e:
683:             logger.error(f"Unexpected error getting group members for {group_dn}: {e}")
684:             return []
```

## File: application/backend/src/app/sms/client.py
```python
  1: """SMS client for sending verification codes via AWS SNS."""
  2: import logging
  3: import random
  4: import re
  5: import string
  6: from typing import Optional
  7: import hashlib
  8: import boto3
  9: from botocore.exceptions import BotoCoreError, ClientError
 10: from app.config import Settings, get_settings
 11: logger = logging.getLogger(__name__)
 12: class SMSClient:
 13:     """Client for SMS operations using AWS SNS."""
 14:     # E.164 phone number format regex
 15:     E164_PATTERN = re.compile(r"^\+[1-9]\d{1,14}$")
 16:     def __init__(self, settings: Optional[Settings] = None):
 17:         """Initialize SMS client with settings."""
 18:         self.settings = settings or get_settings()
 19:         self._sns_client = None
 20:     @property
 21:     def sns_client(self):
 22:         """Get or create SNS client."""
 23:         if self._sns_client is None:
 24:             self._sns_client = boto3.client(
 25:                 "sns",
 26:                 region_name=self.settings.aws_region,
 27:             )
 28:         return self._sns_client
 29:     def validate_phone_number(self, phone_number: str) -> tuple[bool, str]:
 30:         """
 31:         Validate phone number format (E.164).
 32:         Args:
 33:             phone_number: Phone number to validate
 34:         Returns:
 35:             Tuple of (is_valid, error_message)
 36:         """
 37:         if not phone_number:
 38:             return False, "Phone number is required"
 39:         # Check E.164 format
 40:         if not self.E164_PATTERN.match(phone_number):
 41:             return False, (
 42:                 "Invalid phone number format. "
 43:                 "Use E.164 format: +[country code][number] (e.g., +14155552671)"
 44:             )
 45:         return True, ""
 46:     def generate_verification_code(self, length: int = 6) -> str:
 47:         """
 48:         Generate a random numeric verification code.
 49:         Args:
 50:             length: Length of the code (default: 6)
 51:         Returns:
 52:             Verification code string
 53:         """
 54:         return "".join(random.choices(string.digits, k=length))
 55:     def send_verification_code(
 56:         self,
 57:         phone_number: str,
 58:         code: str,
 59:         sender_id: Optional[str] = None,
 60:     ) -> tuple[bool, str, Optional[str]]:
 61:         """
 62:         Send a verification code via SMS.
 63:         Args:
 64:             phone_number: Recipient phone number (E.164 format)
 65:             code: Verification code to send
 66:             sender_id: Optional sender ID override
 67:         Returns:
 68:             Tuple of (success, message, message_id)
 69:         """
 70:         # Validate phone number
 71:         is_valid, error = self.validate_phone_number(phone_number)
 72:         if not is_valid:
 73:             return False, error, None
 74:         # Format message
 75:         message = self.settings.sms_message_template.format(code=code)
 76:         try:
 77:             # Set message attributes
 78:             message_attributes = {
 79:                 "AWS.SNS.SMS.SMSType": {
 80:                     "DataType": "String",
 81:                     "StringValue": self.settings.sms_type,
 82:                 }
 83:             }
 84:             # Add sender ID if provided or configured
 85:             effective_sender_id = sender_id or self.settings.sms_sender_id
 86:             if effective_sender_id:
 87:                 message_attributes["AWS.SNS.SMS.SenderID"] = {
 88:                     "DataType": "String",
 89:                     "StringValue": effective_sender_id,
 90:                 }
 91:             # Send SMS directly to phone number
 92:             response = self.sns_client.publish(
 93:                 PhoneNumber=phone_number,
 94:                 Message=message,
 95:                 MessageAttributes=message_attributes,
 96:             )
 97:             message_id = response.get("MessageId")
 98:             logger.info(
 99:                 f"SMS sent successfully. MessageId: {message_id}"
100:             )
101:             return True, "Verification code sent", message_id
102:         except ClientError as e:
103:             error_code = e.response.get("Error", {}).get("Code", "Unknown")
104:             error_message = e.response.get("Error", {}).get("Message", str(e))
105:             logger.error(f"SNS ClientError sending SMS: {error_code} - {error_message}")
106:             # Handle specific error codes
107:             if error_code == "InvalidParameter":
108:                 return False, "Invalid phone number", None
109:             elif error_code == "OptedOut":
110:                 return False, "Phone number has opted out of SMS", None
111:             elif error_code == "InternalError":
112:                 return False, "SMS service temporarily unavailable", None
113:             else:
114:                 return False, f"Failed to send SMS: {error_message}", None
115:         except BotoCoreError as e:
116:             logger.error(f"BotoCoreError sending SMS: {e}")
117:             return False, "SMS service error", None
118:         except Exception as e:
119:             logger.error(f"Unexpected error sending SMS: {e}")
120:             return False, "Failed to send verification code", None
121:     def subscribe_phone_number(
122:         self,
123:         phone_number: str,
124:         topic_arn: Optional[str] = None,
125:     ) -> tuple[bool, str, Optional[str]]:
126:         """
127:         Subscribe a phone number to the SNS topic.
128:         Args:
129:             phone_number: Phone number to subscribe (E.164 format)
130:             topic_arn: Optional topic ARN override
131:         Returns:
132:             Tuple of (success, message, subscription_arn)
133:         """
134:         # Validate phone number
135:         is_valid, error = self.validate_phone_number(phone_number)
136:         if not is_valid:
137:             return False, error, None
138:         effective_topic_arn = topic_arn or self.settings.sns_topic_arn
139:         if not effective_topic_arn:
140:             return False, "SNS topic not configured", None
141:         try:
142:             response = self.sns_client.subscribe(
143:                 TopicArn=effective_topic_arn,
144:                 Protocol="sms",
145:                 Endpoint=phone_number,
146:                 ReturnSubscriptionArn=True,
147:             )
148:             subscription_arn = response.get("SubscriptionArn")
149:             logger.info(f"Phone number subscribed with ARN: {subscription_arn}")
150:             return True, "Phone number subscribed successfully", subscription_arn
151:         except ClientError as e:
152:             error_code = e.response.get("Error", {}).get("Code", "Unknown")
153:             error_message = e.response.get("Error", {}).get("Message", str(e))
154:             logger.error(f"SNS subscribe error: {error_code} - {error_message}")
155:             return False, f"Failed to subscribe: {error_message}", None
156:         except Exception as e:
157:             logger.error(f"Unexpected error subscribing phone: {e}")
158:             return False, "Failed to subscribe phone number", None
159:     def unsubscribe(self, subscription_arn: str) -> tuple[bool, str]:
160:         """
161:         Unsubscribe from the SNS topic.
162:         Args:
163:             subscription_arn: Subscription ARN to unsubscribe
164:         Returns:
165:             Tuple of (success, message)
166:         """
167:         try:
168:             self.sns_client.unsubscribe(SubscriptionArn=subscription_arn)
169:             logger.info(f"Unsubscribed: {subscription_arn}")
170:             return True, "Unsubscribed successfully"
171:         except ClientError as e:
172:             error_message = e.response.get("Error", {}).get("Message", str(e))
173:             logger.error(f"SNS unsubscribe error: {error_message}")
174:             return False, f"Failed to unsubscribe: {error_message}"
175:         except Exception as e:
176:             logger.error(f"Unexpected error unsubscribing: {e}")
177:             return False, "Failed to unsubscribe"
178:     def check_opt_out_status(self, phone_number: str) -> tuple[bool, bool]:
179:         """
180:         Check if a phone number has opted out of SMS.
181:         Args:
182:             phone_number: Phone number to check
183:         Returns:
184:             Tuple of (success, is_opted_out)
185:         """
186:         try:
187:             response = self.sns_client.check_if_phone_number_is_opted_out(
188:                 phoneNumber=phone_number
189:             )
190:             return True, response.get("isOptedOut", False)
191:         except Exception as e:
192:             logger.error(f"Error checking opt-out status: {e}")
193:             return False, False
194:     def opt_in_phone_number(self, phone_number: str) -> tuple[bool, str]:
195:         """
196:         Opt in a phone number that was previously opted out.
197:         Args:
198:             phone_number: Phone number to opt in
199:         Returns:
200:             Tuple of (success, message)
201:         """
202:         try:
203:             self.sns_client.opt_in_phone_number(phoneNumber=phone_number)
204:             phone_hash = hashlib.sha256(phone_number.encode("utf-8")).hexdigest()[:8]
205:             logger.info(f"Phone number opted in (hash={phone_hash})")
206:             return True, "Phone number opted in successfully"
207:         except ClientError as e:
208:             error_message = e.response.get("Error", {}).get("Message", str(e))
209:             logger.error(f"SNS opt-in error: {error_message}")
210:             return False, f"Failed to opt in: {error_message}"
211:         except Exception as e:
212:             logger.error(f"Unexpected error opting in phone: {e}")
213:             return False, "Failed to opt in phone number"
```

## File: application/modules/cert-manager/main.tf
```hcl
  1: # cert-manager for automated TLS certificate management
  2: # This creates self-signed certificates for OpenLDAP internal TLS
  3:
  4: # Install cert-manager via Helm
  5: resource "helm_release" "cert_manager" {
  6:   name             = "cert-manager"
  7:   repository       = "https://charts.jetstack.io"
  8:   chart            = "cert-manager"
  9:   version          = "v1.13.2"
 10:   namespace        = "cert-manager"
 11:   create_namespace = true
 12:
 13:   set {
 14:     name  = "installCRDs"
 15:     value = "true"
 16:   }
 17:
 18:   set {
 19:     name  = "webhook.timeoutSeconds"
 20:     value = "30"
 21:   }
 22:
 23:   set {
 24:     name  = "prometheus.enabled"
 25:     value = "false"
 26:   }
 27:
 28:   atomic          = true
 29:   cleanup_on_fail = true
 30:   recreate_pods   = true
 31:   force_update    = true
 32:   # Wait for cert-manager to be ready before proceeding
 33:   wait            = true
 34:   wait_for_jobs   = true
 35:   upgrade_install = true
 36: }
 37:
 38: # Wait for cert-manager webhook to be fully ready before creating certificates
 39: # This ensures the webhook can validate certificate resources
 40: resource "time_sleep" "wait_for_cert_manager_webhook" {
 41:   depends_on      = [helm_release.cert_manager]
 42:   create_duration = "30s"
 43: }
 44:
 45: # Create a self-signed ClusterIssuer
 46: resource "kubernetes_manifest" "selfsigned_issuer" {
 47:   depends_on = [time_sleep.wait_for_cert_manager_webhook]
 48:
 49:   manifest = {
 50:     apiVersion = "cert-manager.io/v1"
 51:     kind       = "ClusterIssuer"
 52:     metadata = {
 53:       name = "selfsigned-issuer"
 54:     }
 55:     spec = {
 56:       selfSigned = {}
 57:     }
 58:   }
 59:
 60:   wait {
 61:     fields = {
 62:       "status.conditions[?(@.type=='Ready')].status" = "True"
 63:     }
 64:   }
 65: }
 66:
 67: # Create Certificate Authority (CA) certificate
 68: resource "kubernetes_manifest" "openldap_ca" {
 69:   depends_on = [kubernetes_manifest.selfsigned_issuer]
 70:
 71:   manifest = {
 72:     apiVersion = "cert-manager.io/v1"
 73:     kind       = "Certificate"
 74:     metadata = {
 75:       name      = "openldap-ca"
 76:       namespace = var.namespace
 77:     }
 78:     spec = {
 79:       secretName  = "openldap-ca-secret"
 80:       duration    = "87600h" # 10 years
 81:       renewBefore = "720h"   # 30 days
 82:       isCA        = true
 83:       commonName  = "OpenLDAP CA"
 84:       privateKey = {
 85:         algorithm = "RSA"
 86:         size      = 2048
 87:       }
 88:       issuerRef = {
 89:         name = "selfsigned-issuer"
 90:         kind = "ClusterIssuer"
 91:       }
 92:     }
 93:   }
 94:
 95:   wait {
 96:     fields = {
 97:       "status.conditions[?(@.type=='Ready')].status" = "True"
 98:     }
 99:   }
100: }
101:
102: # Create Issuer based on the CA certificate
103: resource "kubernetes_manifest" "openldap_ca_issuer" {
104:   depends_on = [kubernetes_manifest.openldap_ca]
105:
106:   manifest = {
107:     apiVersion = "cert-manager.io/v1"
108:     kind       = "Issuer"
109:     metadata = {
110:       name      = "openldap-ca-issuer"
111:       namespace = var.namespace
112:     }
113:     spec = {
114:       ca = {
115:         secretName = "openldap-ca-secret"
116:       }
117:     }
118:   }
119:
120:   wait {
121:     fields = {
122:       "status.conditions[?(@.type=='Ready')].status" = "True"
123:     }
124:   }
125: }
126:
127: # Create TLS certificate for OpenLDAP
128: resource "kubernetes_manifest" "openldap_tls" {
129:   depends_on = [kubernetes_manifest.openldap_ca_issuer]
130:
131:   manifest = {
132:     apiVersion = "cert-manager.io/v1"
133:     kind       = "Certificate"
134:     metadata = {
135:       name      = "openldap-tls"
136:       namespace = var.namespace
137:     }
138:     spec = {
139:       secretName  = "openldap-tls"
140:       duration    = "87600h" # 10 years
141:       renewBefore = "720h"   # 30 days
142:       isCA        = false
143:       privateKey = {
144:         algorithm = "RSA"
145:         size      = 2048
146:       }
147:       dnsNames = [
148:         "openldap-stack-ha",
149:         "openldap-stack-ha.${var.namespace}",
150:         "openldap-stack-ha.${var.namespace}.svc",
151:         "openldap-stack-ha.${var.namespace}.svc.cluster.local",
152:         "openldap-stack-ha-headless",
153:         "openldap-stack-ha-headless.${var.namespace}",
154:         "openldap-stack-ha-headless.${var.namespace}.svc",
155:         "openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
156:         "openldap-stack-ha-0.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
157:         "openldap-stack-ha-1.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
158:         "openldap-stack-ha-2.openldap-stack-ha-headless.${var.namespace}.svc.cluster.local",
159:         "*.${var.domain_name}",
160:         var.domain_name
161:       ]
162:       issuerRef = {
163:         name = "openldap-ca-issuer"
164:         kind = "Issuer"
165:       }
166:     }
167:   }
168:
169:   wait {
170:     fields = {
171:       "status.conditions[?(@.type=='Ready')].status" = "True"
172:     }
173:   }
174: }
```

## File: application/modules/openldap/outputs.tf
```hcl
 1: output "namespace" {
 2:   description = "Kubernetes namespace for OpenLDAP"
 3:   value       = kubernetes_namespace.openldap.metadata[0].name
 4: }
 5:
 6: output "secret_name" {
 7:   description = "Name of the Kubernetes secret for OpenLDAP passwords"
 8:   value       = kubernetes_secret.openldap_passwords.metadata[0].name
 9: }
10:
11: output "helm_release_name" {
12:   description = "Name of the Helm release"
13:   value       = helm_release.openldap.name
14: }
15:
16: output "phpldapadmin_ingress_hostname" {
17:   description = "Hostname from phpLDAPadmin ingress (ALB DNS name)"
18:   value       = try(data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname, null)
19: }
20:
21: output "ltb_passwd_ingress_hostname" {
22:   description = "Hostname from ltb-passwd ingress (ALB DNS name)"
23:   value       = try(data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname, null)
24: }
25:
26: output "alb_dns_name" {
27:   description = "ALB DNS name (from either ingress)"
28:   value = try(
29:     data.kubernetes_ingress_v1.phpldapadmin.status[0].load_balancer[0].ingress[0].hostname,
30:     data.kubernetes_ingress_v1.ltb_passwd.status[0].load_balancer[0].ingress[0].hostname,
31:     ""
32:   )
33: }
34:
35:
36: ##################### Network Policies ##########################
37: output "network_policy_name" {
38:   description = "Name of the network policy for secure namespace communication"
39:   value       = var.enable_network_policies ? module.network_policies[0].network_policy_name : null
40: }
41:
42: output "network_policy_namespace" {
43:   description = "Namespace where the network policy is applied"
44:   value       = var.enable_network_policies ? module.network_policies[0].network_policy_namespace : null
45: }
46:
47: output "network_policy_uid" {
48:   description = "UID of the network policy resource"
49:   value       = var.enable_network_policies ? module.network_policies[0].network_policy_uid : null
50: }
```

## File: application/modules/openldap/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name prefix for resources"
 13:   type        = string
 14: }
 15:
 16: variable "app_name" {
 17:   description = "Full application name (computed in parent module as prefix-region-app_name-env)"
 18:   type        = string
 19: }
 20:
 21: variable "openldap_ldap_domain" {
 22:   description = "OpenLDAP domain (e.g., ldap.talorlik.internal)"
 23:   type        = string
 24: }
 25:
 26: variable "openldap_admin_password" {
 27:   description = "OpenLDAP admin password. MUST be set via TF_VAR_OPENLDAP_ADMIN_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
 28:   type        = string
 29:   sensitive   = true
 30: }
 31:
 32: variable "openldap_config_password" {
 33:   description = "OpenLDAP config password. MUST be set via TF_VAR_OPENLDAP_CONFIG_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
 34:   type        = string
 35:   sensitive   = true
 36: }
 37:
 38: variable "openldap_secret_name" {
 39:   description = "Name of the Kubernetes secret for OpenLDAP passwords"
 40:   type        = string
 41: }
 42:
 43: variable "storage_class_name" {
 44:   description = "Name of the Kubernetes StorageClass to use for OpenLDAP PVC"
 45:   type        = string
 46: }
 47:
 48: variable "namespace" {
 49:   description = "Kubernetes namespace for OpenLDAP"
 50:   type        = string
 51:   default     = "ldap"
 52: }
 53:
 54: variable "phpldapadmin_host" {
 55:   description = "Hostname for phpLDAPadmin ingress (e.g., phpldapadmin.talorlik.com). Derived from domain_name if not provided."
 56:   type        = string
 57: }
 58:
 59: variable "ltb_passwd_host" {
 60:   description = "Hostname for ltb-passwd ingress (e.g., passwd.talorlik.com). Derived from domain_name if not provided."
 61:   type        = string
 62: }
 63:
 64: variable "use_alb" {
 65:   description = "Whether to use ALB for ingress"
 66:   type        = bool
 67:   default     = true
 68: }
 69:
 70: variable "ingress_class_name" {
 71:   description = "Name of the IngressClass for ALB (from ALB module)"
 72:   type        = string
 73:   default     = null
 74: }
 75:
 76: variable "alb_load_balancer_name" {
 77:   description = "Custom name for the AWS ALB (appears in AWS console). Must be ≤ 32 characters per AWS constraints."
 78:   type        = string
 79: }
 80:
 81: variable "alb_target_type" {
 82:   description = "ALB target type: ip or instance"
 83:   type        = string
 84:   default     = "ip"
 85:   validation {
 86:     condition     = contains(["ip", "instance"], var.alb_target_type)
 87:     error_message = "ALB target type must be either 'ip' or 'instance'"
 88:   }
 89: }
 90:
 91: variable "acm_cert_arn" {
 92:   description = "ARN of the ACM certificate for HTTPS"
 93:   type        = string
 94: }
 95:
 96: variable "alb_ssl_policy" {
 97:   description = "ALB SSL policy for HTTPS listeners"
 98:   type        = string
 99: }
100:
101:
102: variable "tags" {
103:   description = "Tags to apply to resources"
104:   type        = map(string)
105:   default     = {}
106: }
107:
108: variable "helm_chart_version" {
109:   description = "OpenLDAP Helm chart version"
110:   type        = string
111:   default     = "4.0.1"
112: }
113:
114: variable "helm_chart_repository" {
115:   description = "Helm chart repository URL"
116:   type        = string
117:   default     = "https://jp-gouin.github.io/helm-openldap"
118: }
119:
120: variable "helm_chart_name" {
121:   description = "Helm chart name"
122:   type        = string
123:   default     = "openldap-stack-ha"
124: }
125:
126: variable "helm_release_name" {
127:   description = "Helm release name"
128:   type        = string
129:   default     = "openldap-stack-ha"
130: }
131:
132: variable "values_template_path" {
133:   description = "Path to the OpenLDAP values template file"
134:   type        = string
135:   default     = null
136: }
137:
138: variable "enable_network_policies" {
139:   description = "Whether to enable network policies for the OpenLDAP namespace"
140:   type        = bool
141:   default     = true
142: }
143:
144: variable "ecr_registry" {
145:   description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
146:   type        = string
147: }
148:
149: variable "ecr_repository" {
150:   description = "ECR repository name"
151:   type        = string
152: }
153:
154: variable "openldap_image_tag" {
155:   description = "OpenLDAP image tag in ECR"
156:   type        = string
157:   default     = "openldap-1.5.0"
158: }
```

## File: application/set-k8s-env.sh
```bash
  1: #!/bin/bash
  2: # Script to set Kubernetes environment variables for Terraform Helm/Kubernetes providers
  3: # Fetches cluster name from backend_infra Terraform state
  4: # Works for both local development and CI/CD
  5: #
  6: # Usage: source ./set-k8s-env.sh
  7: #   Uses AWS credentials from environment variables (set by setup-application.sh or CI/CD workflow)
  8: set -e
  9: cd "$(dirname "$0")"
 10: # Colors for output (if not already defined by sourcing script)
 11: if [ -z "${RED:-}" ]; then
 12:     RED='\033[0;31m'
 13:     GREEN='\033[0;32m'
 14:     YELLOW='\033[1;33m'
 15:     NC='\033[0m' # No Color
 16: fi
 17: # Function to print colored messages (if not already defined by sourcing script)
 18: if ! declare -f print_error > /dev/null; then
 19:     print_error() {
 20:         echo -e "${RED}ERROR:${NC} $1" >&2
 21:     }
 22: fi
 23: if ! declare -f print_success > /dev/null; then
 24:     print_success() {
 25:         echo -e "${GREEN}SUCCESS:${NC} $1"
 26:     }
 27: fi
 28: if ! declare -f print_info > /dev/null; then
 29:     print_info() {
 30:         echo -e "${YELLOW}INFO:${NC} $1"
 31:     }
 32: fi
 33: echo "Using AWS credentials from environment variables"
 34: echo "Fetching cluster name from backend_infra Terraform state..."
 35: # Use BACKEND_FILE from environment if available, otherwise default to backend.hcl
 36: BACKEND_FILE="${BACKEND_FILE:-backend.hcl}"
 37: # Check if backend file exists
 38: if [ ! -f "$BACKEND_FILE" ]; then
 39:     echo "ERROR: $BACKEND_FILE not found. Run ./setup-application.sh or the application_infra_provisioning GitHub workflow first."
 40:     exit 1
 41: fi
 42: # Parse backend configuration
 43: BACKEND_BUCKET=$(grep 'bucket' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')
 44: BACKEND_REGION=$(grep 'region' "$BACKEND_FILE" | sed 's/.*"\(.*\)".*/\1/')
 45: BACKEND_KEY="backend_state/terraform.tfstate"
 46: echo "Backend S3 bucket: $BACKEND_BUCKET"
 47: echo "Backend region: $BACKEND_REGION"
 48: # Get current workspace to fetch correct state
 49: WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
 50: echo "Terraform workspace: $WORKSPACE"
 51: # Fetch cluster name from backend_infra state
 52: if [ "$WORKSPACE" = "default" ]; then
 53:     STATE_KEY="$BACKEND_KEY"
 54: else
 55:     STATE_KEY="env:/$WORKSPACE/$BACKEND_KEY"
 56: fi
 57: echo "Fetching cluster name from s3://$BACKEND_BUCKET/$STATE_KEY"
 58: # Use current credentials (State Account credentials)
 59: CLUSTER_NAME=$(aws s3 cp "s3://$BACKEND_BUCKET/$STATE_KEY" - 2>/dev/null | jq -r '.outputs.cluster_name.value' || echo "")
 60: if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
 61:     echo "ERROR: Could not retrieve cluster name from backend_infra state."
 62:     echo "Make sure backend_infra has been deployed and outputs cluster_name."
 63:     exit 1
 64: fi
 65: echo "Cluster name: $CLUSTER_NAME"
 66: # Assume Deployment Account role for EKS cluster access
 67: # This is needed for aws eks describe-cluster to access the EKS cluster
 68: # Use AWS_REGION from environment if available, otherwise use BACKEND_REGION
 69: AWS_REGION="${AWS_REGION:-$BACKEND_REGION}"
 70: if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
 71:     print_error "DEPLOYMENT_ROLE_ARN is not set. Run ./setup-application.sh first."
 72:     exit 1
 73: fi
 74: if [ -z "$EXTERNAL_ID" ]; then
 75:     print_error "EXTERNAL_ID is not set. Run ./setup-application.sh first."
 76:     exit 1
 77: fi
 78: print_info "Assuming Deployment Account role: $DEPLOYMENT_ROLE_ARN"
 79: print_info "Region: $AWS_REGION"
 80: DEPLOYMENT_ROLE_SESSION_NAME="setup-application-deployment-$(date +%s)"
 81: # Assume deployment account role with ExternalId
 82: DEPLOYMENT_ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
 83:     --role-arn "$DEPLOYMENT_ROLE_ARN" \
 84:     --role-session-name "$DEPLOYMENT_ROLE_SESSION_NAME" \
 85:     --external-id "$EXTERNAL_ID" \
 86:     --region "$AWS_REGION" 2>&1)
 87: if [ $? -ne 0 ]; then
 88:     print_error "Failed to assume Deployment Account role: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
 89:     exit 1
 90: fi
 91: # Extract Deployment Account credentials from JSON output
 92: if command -v jq &> /dev/null; then
 93:     export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
 94:     export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
 95:     export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
 96: else
 97:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
 98:     export AWS_ACCESS_KEY_ID=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
 99:     export AWS_SECRET_ACCESS_KEY=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
100:     export AWS_SESSION_TOKEN=$(echo "$DEPLOYMENT_ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
101: fi
102: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
103:     print_error "Failed to extract Deployment Account credentials from assume-role output."
104:     print_error "Output was: $DEPLOYMENT_ASSUME_ROLE_OUTPUT"
105:     exit 1
106: fi
107: # Verify the Deployment Account credentials work
108: DEPLOYMENT_CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
109: if [ $? -ne 0 ]; then
110:     print_error "Failed to verify Deployment Account role credentials: $DEPLOYMENT_CALLER_ARN"
111:     exit 1
112: fi
113: print_success "Successfully assumed Deployment Account role"
114: print_info "Deployment Account role identity: $DEPLOYMENT_CALLER_ARN"
115: echo ""
116: # Use VARIABLES_FILE from environment if available, otherwise default to variables.tfvars
117: VARIABLES_FILE="${VARIABLES_FILE:-variables.tfvars}"
118: # Update variables.tfvars
119: print_info "Updating ${VARIABLES_FILE} with selected values..."
120: if [ ! -f "$VARIABLES_FILE" ]; then
121:     print_error "Variables file '${VARIABLES_FILE}' not found."
122:     exit 1
123: fi
124: # Update variables.tfvars (works on macOS and Linux)
125: if [[ "$OSTYPE" == "darwin"* ]]; then
126:     # macOS sed requires -i '' for in-place editing
127:     sed -i '' "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT:-prod}\"|" "$VARIABLES_FILE"
128:     sed -i '' "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
129:     # Add or update deployment_account_role_arn
130:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
131:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
132:     else
133:         sed -i '' "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
134:     fi
135:     # Add or update deployment_account_external_id
136:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
137:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
138:     else
139:         sed -i '' "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
140:     fi
141:     # Add or update state_account_role_arn (if provided)
142:     if [ -n "${STATE_ACCOUNT_ROLE_ARN:-}" ]; then
143:         if ! grep -q "^state_account_role_arn" "$VARIABLES_FILE"; then
144:             echo "state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
145:         else
146:             sed -i '' "s|^state_account_role_arn[[:space:]]*=.*|state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"|" "$VARIABLES_FILE"
147:         fi
148:     fi
149: else
150:     # Linux sed
151:     sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT:-prod}\"|" "$VARIABLES_FILE"
152:     sed -i "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
153:     # Add or update deployment_account_role_arn
154:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
155:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
156:     else
157:         sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
158:     fi
159:     # Add or update deployment_account_external_id
160:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
161:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
162:     else
163:         sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
164:     fi
165:     # Add or update state_account_role_arn (if provided)
166:     if [ -n "${STATE_ACCOUNT_ROLE_ARN:-}" ]; then
167:         if ! grep -q "^state_account_role_arn" "$VARIABLES_FILE"; then
168:             echo "state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
169:         else
170:             sed -i "s|^state_account_role_arn[[:space:]]*=.*|state_account_role_arn = \"${STATE_ACCOUNT_ROLE_ARN}\"|" "$VARIABLES_FILE"
171:         fi
172:     fi
173: fi
174: print_success "Updated ${VARIABLES_FILE}"
175: echo ""
176: print_info "  - env: ${ENVIRONMENT:-prod}"
177: print_info "  - region: ${AWS_REGION}"
178: echo ""
179: # Get cluster endpoint
180: # IMPORTANT: This command must use credentials for the deployment account where the EKS cluster exists
181: # Credentials are set via environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
182: echo "Fetching cluster endpoint..."
183: KUBERNETES_MASTER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "")
184: if [ -z "$KUBERNETES_MASTER" ]; then
185:     print_error "Could not retrieve cluster endpoint. Make sure the cluster exists and you have AWS credentials configured."
186:     exit 1
187: fi
188: echo "Kubernetes Master: $KUBERNETES_MASTER"
189: # Export environment variables
190: export KUBERNETES_MASTER
191: export KUBE_CONFIG_PATH="${KUBE_CONFIG_PATH:-$HOME/.kube/config}"
192: # Update kubeconfig with latest cluster endpoint
193: # This MUST happen on every run to ensure kubeconfig is current
194: # Use deployment account credentials (already set via environment variables)
195: print_info "Updating kubeconfig for cluster: $CLUSTER_NAME"
196: print_info "Region: $AWS_REGION"
197: # Ensure kubeconfig directory exists
198: KUBE_CONFIG_DIR=$(dirname "$KUBE_CONFIG_PATH")
199: if [ ! -d "$KUBE_CONFIG_DIR" ]; then
200:     mkdir -p "$KUBE_CONFIG_DIR"
201:     print_info "Created kubeconfig directory: $KUBE_CONFIG_DIR"
202: fi
203: # Configure kubeconfig to use AWS CLI exec plugin for dynamic token generation
204: # This ensures kubectl always gets fresh tokens from whatever AWS credentials are in the environment
205: # Terraform's AWS provider will assume the deployment role, and kubectl will inherit those credentials
206: print_info "Configuring kubeconfig with AWS CLI exec plugin for dynamic authentication..."
207: # Fetch cluster certificate authority data
208: CLUSTER_CA_DATA=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.certificateAuthority.data' --output text 2>/dev/null)
209: if [ -z "$CLUSTER_CA_DATA" ]; then
210:     print_error "Failed to retrieve cluster certificate authority data"
211:     exit 1
212: fi
213: # Create/update kubeconfig with exec plugin configuration
214: cat > "$KUBE_CONFIG_PATH" <<'EOF'
215: apiVersion: v1
216: kind: Config
217: clusters:
218: - cluster:
219:     certificate-authority-data: CLUSTER_CA_DATA_PLACEHOLDER
220:     server: KUBERNETES_MASTER_PLACEHOLDER
221:   name: CLUSTER_NAME_PLACEHOLDER
222: contexts:
223: - context:
224:     cluster: CLUSTER_NAME_PLACEHOLDER
225:     user: CLUSTER_NAME_PLACEHOLDER
226:   name: CLUSTER_NAME_PLACEHOLDER
227: current-context: CLUSTER_NAME_PLACEHOLDER
228: users:
229: - name: CLUSTER_NAME_PLACEHOLDER
230:   user:
231:     exec:
232:       apiVersion: client.authentication.k8s.io/v1beta1
233:       command: aws
234:       args:
235:       - eks
236:       - get-token
237:       - --cluster-name
238:       - CLUSTER_NAME_PLACEHOLDER
239:       - --region
240:       - AWS_REGION_PLACEHOLDER
241:       # AWS CLI will automatically use credentials from environment variables
242:       # (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
243:       # These are set by Terraform's AWS provider assume_role block
244:       env: null
245: EOF
246: # Replace placeholders with actual values (avoids shell variable expansion issues)
247: if [[ "$OSTYPE" == "darwin"* ]]; then
248:     # macOS sed
249:     sed -i '' "s|CLUSTER_CA_DATA_PLACEHOLDER|$CLUSTER_CA_DATA|g" "$KUBE_CONFIG_PATH"
250:     sed -i '' "s|KUBERNETES_MASTER_PLACEHOLDER|$KUBERNETES_MASTER|g" "$KUBE_CONFIG_PATH"
251:     sed -i '' "s|CLUSTER_NAME_PLACEHOLDER|$CLUSTER_NAME|g" "$KUBE_CONFIG_PATH"
252:     sed -i '' "s|AWS_REGION_PLACEHOLDER|$AWS_REGION|g" "$KUBE_CONFIG_PATH"
253: else
254:     # Linux sed
255:     sed -i "s|CLUSTER_CA_DATA_PLACEHOLDER|$CLUSTER_CA_DATA|g" "$KUBE_CONFIG_PATH"
256:     sed -i "s|KUBERNETES_MASTER_PLACEHOLDER|$KUBERNETES_MASTER|g" "$KUBE_CONFIG_PATH"
257:     sed -i "s|CLUSTER_NAME_PLACEHOLDER|$CLUSTER_NAME|g" "$KUBE_CONFIG_PATH"
258:     sed -i "s|AWS_REGION_PLACEHOLDER|$AWS_REGION|g" "$KUBE_CONFIG_PATH"
259: fi
260: print_success "Kubeconfig configured with exec plugin"
261: print_info "Kubeconfig path: $KUBE_CONFIG_PATH"
262: print_info "kubectl will dynamically fetch tokens using current AWS credentials"
263: echo ""
264: echo "✅ Environment variables set successfully!"
265: echo ""
266: echo "KUBERNETES_MASTER=$KUBERNETES_MASTER"
267: echo "KUBE_CONFIG_PATH=$KUBE_CONFIG_PATH"
268: echo ""
269: echo "To use these variables in your current shell, run:"
270: echo "  source ./set-k8s-env.sh"
```

## File: docs/dark-theme.css
```css
  1: * {
  2:     margin: 0;
  3:     padding: 0;
  4:     box-sizing: border-box;
  5: }
  6: :root {
  7:     --primary-color: #58a6ff;
  8:     --primary-hover: #79c0ff;
  9:     --bg-color: #0d1117;
 10:     --text-color: #c9d1d9;
 11:     --border-color: #30363d;
 12:     --code-bg: #161b22;
 13:     --nav-bg: #161b22;
 14:     --nav-shadow: rgba(0, 0, 0, 0.5);
 15:     --section-bg: #161b22;
 16:     --link-color: #58a6ff;
 17: }
 18: body {
 19:     font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
 20:     line-height: 1.6;
 21:     color: var(--text-color);
 22:     background-color: var(--bg-color);
 23:     padding-top: 80px; /* Account for sticky nav */
 24: }
 25: /* Sticky Navigation */
 26: .navbar {
 27:     position: fixed;
 28:     top: 0;
 29:     left: 0;
 30:     right: 0;
 31:     background-color: var(--nav-bg);
 32:     border-bottom: 1px solid var(--border-color);
 33:     box-shadow: 0 2px 4px var(--nav-shadow);
 34:     z-index: 1000;
 35:     padding: 5px 20px;
 36: }
 37: .nav-container {
 38:     max-width: 1200px;
 39:     margin: 0 auto;
 40:     padding: 0;
 41:     display: flex;
 42:     justify-content: space-between;
 43:     align-items: center;
 44: }
 45: .nav-logo {
 46:     display: flex;
 47:     align-items: center;
 48:     font-size: 18px;
 49:     font-weight: 600;
 50:     color: var(--text-color);
 51:     text-decoration: none;
 52:     padding: 0;
 53:     margin-right: 20px;
 54: }
 55: .nav-menu {
 56:     display: flex;
 57:     list-style: none;
 58:     gap: 10px;
 59:     align-items: center;
 60:     padding: 0;
 61: }
 62: .nav-menu li {
 63:     display: flex;
 64:     align-items: center;
 65:     padding: 10px 12px;
 66: }
 67: .nav-menu a {
 68:     display: flex;
 69:     align-items: center;
 70:     color: var(--text-color);
 71:     text-decoration: none;
 72:     font-size: 14px;
 73:     transition: color 0.2s;
 74:     border-bottom: 2px solid transparent;
 75: }
 76: .nav-menu a:hover {
 77:     color: var(--primary-color);
 78:     border-bottom-color: var(--primary-color);
 79: }
 80: .nav-menu a.active {
 81:     color: var(--primary-color);
 82:     border-bottom-color: var(--primary-color);
 83: }
 84: .mobile-menu-toggle {
 85:     display: none;
 86:     background: none;
 87:     border: none;
 88:     font-size: 24px;
 89:     cursor: pointer;
 90:     padding: 10px;
 91:     color: var(--text-color);
 92: }
 93: /* Theme Toggle Button */
 94: .theme-toggle {
 95:     background: none;
 96:     border: 1px solid var(--border-color);
 97:     border-radius: 6px;
 98:     color: var(--text-color);
 99:     cursor: pointer;
100:     font-size: 20px;
101:     padding: 4px 10px;
102:     margin-left: 10px;
103:     transition: all 0.2s;
104:     display: flex;
105:     align-items: center;
106:     justify-content: center;
107: }
108: .theme-toggle:hover {
109:     background-color: var(--section-bg);
110:     border-color: var(--primary-color);
111:     color: var(--primary-color);
112: }
113: .theme-toggle:focus {
114:     outline: 2px solid var(--primary-color);
115:     outline-offset: 2px;
116: }
117: .theme-toggle .icon {
118:     display: inline-block;
119:     transition: transform 0.3s;
120: }
121: .theme-toggle .icon.hidden {
122:     display: none;
123: }
124: /* Hero Section */
125: .hero {
126:     color: var(--text-color);
127:     padding: 60px 20px 0 20px;
128:     text-align: center;
129: }
130: .hero h1 {
131:     font-size: 2.5em;
132:     margin-bottom: 20px;
133:     font-weight: 600;
134:     color: var(--text-color);
135: }
136: /* Ensure all headings are properly sized */
137: h1 {
138:     font-size: 2.5em;
139:     font-weight: 600;
140: }
141: h2 {
142:     font-size: 2em;
143:     font-weight: 600;
144: }
145: h3 {
146:     font-size: 1.5em;
147:     font-weight: 600;
148: }
149: h4 {
150:     font-size: 1.25em;
151:     font-weight: 600;
152: }
153: h5 {
154:     font-size: 1.1em;
155:     font-weight: 600;
156: }
157: .hero p {
158:     font-size: 1.2em;
159:     margin-bottom: 30px;
160:     opacity: 0.95;
161:     color: var(--text-color);
162: }
163: .hero-content {
164:     max-width: 1200px;
165:     margin: 0 auto;
166: }
167: .hero-banner {
168:     max-width: 100%;
169:     height: auto;
170:     margin-top: 30px;
171:     border-radius: 8px;
172:     box-shadow: 0 4px 6px rgba(0, 0, 0, 0.5);
173:     filter: brightness(0.9);
174: }
175: /* Sections */
176: section {
177:     max-width: 1200px;
178:     margin: 0 auto;
179:     padding: 40px 20px 0 20px;
180:     scroll-margin-top: 100px; /* Account for sticky nav */
181: }
182: section:last-child {
183:     padding-bottom: 40px;
184: }
185: section h2 {
186:     font-size: 2em;
187:     font-weight: 600;
188:     margin-bottom: 20px;
189:     padding-bottom: 10px;
190:     border-bottom: 2px solid var(--border-color);
191:     color: var(--text-color);
192: }
193: section h3 {
194:     font-size: 1.5em;
195:     font-weight: 600;
196:     margin-top: 30px;
197:     margin-bottom: 15px;
198:     color: var(--text-color);
199: }
200: section h4 {
201:     font-size: 1.25em;
202:     font-weight: 600;
203:     margin-top: 20px;
204:     margin-bottom: 10px;
205:     color: var(--text-color);
206: }
207: section h5 {
208:     font-size: 1.1em;
209:     font-weight: 600;
210:     margin-top: 15px;
211:     margin-bottom: 8px;
212:     color: var(--text-color);
213: }
214: /* Cards */
215: .card {
216:     background: var(--section-bg);
217:     border: 1px solid var(--border-color);
218:     border-radius: 6px;
219:     padding: 20px;
220:     margin-bottom: 20px;
221:     box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
222: }
223: .card h3 {
224:     margin-top: 0;
225:     color: var(--primary-color);
226: }
227: /* Lists */
228: ul, ol {
229:     list-style-position: inside;
230: }
231: ul ul, ol ul {
232:     padding-left: 20px;
233: }
234: li p {
235:     padding-left: 20px;
236:     margin-top: 15px;
237: }
238: /* Links */
239: a {
240:     color: var(--link-color);
241:     text-decoration: none;
242: }
243: a:hover {
244:     text-decoration: underline;
245:     color: var(--primary-hover);
246: }
247: /* Paragraphs */
248: p {
249:     margin-bottom: 15px;
250: }
251: #architecture p {
252:     margin-top: 15px;
253: }
254: #architecture p:first-child {
255:     margin-top: 0;
256: }
257: p:last-child {
258:     margin-bottom: 0;
259: }
260: .deployment-card p:last-child {
261:     margin-top: 15px;
262: }
263: #security p:last-child, #getting-started p:last-child {
264:     margin-top: 15px;
265: }
266: /* Code blocks */
267: code {
268:     background-color: var(--code-bg);
269:     padding: 2px 6px;
270:     border-radius: 3px;
271:     font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
272:     font-size: 0.9em;
273:     color: #f85149;
274:     border: 1px solid var(--border-color);
275: }
276: pre {
277:     background-color: var(--code-bg);
278:     padding: 16px;
279:     border-radius: 6px;
280:     overflow-x: auto;
281:     margin-bottom: 15px;
282:     border: 1px solid var(--border-color);
283: }
284: pre code {
285:     background: none;
286:     padding: 0;
287:     border: none;
288:     color: var(--text-color);
289: }
290: /* Tables */
291: table {
292:     width: 100%;
293:     border-collapse: collapse;
294:     margin-bottom: 20px;
295: }
296: table th, table td {
297:     padding: 12px;
298:     text-align: left;
299:     border: 1px solid var(--border-color);
300:     color: var(--text-color);
301: }
302: table th {
303:     background-color: var(--primary-color);
304:     color: #0d1117;
305:     font-weight: 600;
306: }
307: table tbody tr:nth-child(even) {
308:     background-color: var(--section-bg);
309: }
310: table tbody tr:hover {
311:     background-color: rgba(88, 166, 255, 0.1);
312: }
313: /* Deployment Options */
314: .deployment-options {
315:     display: grid;
316:     grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
317:     gap: 20px;
318:     margin-top: 20px;
319: }
320: .deployment-card {
321:     background: var(--section-bg);
322:     border: 2px solid var(--border-color);
323:     border-radius: 8px;
324:     padding: 25px;
325: }
326: .deployment-card h4 {
327:     margin-top: 0;
328:     color: var(--primary-color);
329: }
330: .deployment-card p,
331: .deployment-card li {
332:     color: var(--text-color);
333: }
334: .deployment-card p {
335:     margin-top: 15px;
336: }
337: /* Documentation Grid */
338: .doc-grid {
339:     display: grid;
340:     grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
341:     gap: 20px;
342:     margin-top: 20px;
343: }
344: .doc-item {
345:     background: var(--section-bg);
346:     border: 1px solid var(--border-color);
347:     border-radius: 6px;
348:     padding: 15px;
349:     transition: transform 0.2s, box-shadow 0.2s, border-color 0.2s;
350: }
351: .doc-item:hover {
352:     transform: translateY(-2px);
353:     box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
354:     border-color: var(--primary-color);
355: }
356: .doc-item a {
357:     font-weight: 500;
358:     display: block;
359:     margin-bottom: 8px;
360:     color: var(--link-color);
361: }
362: .doc-item a:hover {
363:     color: var(--primary-hover);
364: }
365: .doc-item p {
366:     font-size: 0.9em;
367:     color: #8b949e;
368:     margin: 0;
369: }
370: /* Badge */
371: .badge {
372:     display: inline-block;
373:     padding: 4px 8px;
374:     background-color: var(--primary-color);
375:     color: #0d1117;
376:     border-radius: 3px;
377:     font-size: 0.8em;
378:     font-weight: 600;
379:     margin-left: 8px;
380: }
381: /* Footer */
382: footer {
383:     background-color: var(--section-bg);
384:     border-top: 1px solid var(--border-color);
385:     padding: 30px 20px;
386:     text-align: center;
387:     color: #8b949e;
388: }
389: /* Responsive */
390: @media (max-width: 768px) {
391:     .mobile-menu-toggle {
392:         display: block;
393:     }
394:     .nav-menu {
395:         position: fixed;
396:         left: -100%;
397:         top: 60px;
398:         flex-direction: column;
399:         background-color: var(--nav-bg);
400:         width: 100%;
401:         text-align: center;
402:         transition: 0.3s;
403:         box-shadow: 0 10px 27px rgba(0, 0, 0, 0.3);
404:         padding: 20px 0;
405:         border-bottom: 1px solid var(--border-color);
406:     }
407:     .nav-menu.active {
408:         left: 0;
409:     }
410:     .nav-menu li {
411:         width: 100%;
412:     }
413:     .nav-menu a {
414:         padding: 15px;
415:         border-bottom: none;
416:         border-left: 3px solid transparent;
417:     }
418:     .nav-menu a:hover,
419:     .nav-menu a.active {
420:         border-left-color: var(--primary-color);
421:         border-bottom-color: transparent;
422:     }
423:     .theme-toggle {
424:         margin-left: 0;
425:         margin-top: 10px;
426:     }
427:     .hero h1 {
428:         font-size: 2em;
429:     }
430:     .hero p {
431:         font-size: 1em;
432:     }
433:     .deployment-options {
434:         grid-template-columns: 1fr;
435:     }
436:     .doc-grid {
437:         grid-template-columns: 1fr;
438:     }
439:     section h2 {
440:         font-size: 1.5em;
441:     }
442:     section h3 {
443:         font-size: 1.3em;
444:     }
445:     section h4 {
446:         font-size: 1.15em;
447:     }
448:     section h5 {
449:         font-size: 1.05em;
450:     }
451: }
452: /* Smooth scroll */
453: html {
454:     scroll-behavior: smooth;
455: }
456: /* Scroll to Top Button */
457: .scroll-to-top {
458:     position: fixed;
459:     bottom: 30px;
460:     right: 30px;
461:     width: 50px;
462:     height: 50px;
463:     border-radius: 50%;
464:     background-color: rgba(88, 166, 255, 0.15);
465:     backdrop-filter: blur(8px);
466:     -webkit-backdrop-filter: blur(8px);
467:     border: 2px solid rgba(88, 166, 255, 0.3);
468:     color: var(--primary-color);
469:     cursor: pointer;
470:     display: flex;
471:     align-items: center;
472:     justify-content: center;
473:     z-index: 999;
474:     opacity: 0;
475:     visibility: hidden;
476:     pointer-events: none;
477:     transition: opacity 0.3s ease, visibility 0.3s ease, transform 0.3s ease, background-color 0.3s ease, border-color 0.3s ease;
478:     box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
479: }
480: .scroll-to-top.visible {
481:     opacity: 1;
482:     visibility: visible;
483:     pointer-events: auto;
484: }
485: .scroll-to-top:hover {
486:     background-color: rgba(88, 166, 255, 0.25);
487:     border-color: rgba(88, 166, 255, 0.5);
488:     transform: translateY(-3px);
489:     box-shadow: 0 6px 16px rgba(0, 0, 0, 0.4);
490: }
491: .scroll-to-top:active {
492:     transform: translateY(-1px);
493: }
494: .scroll-to-top svg {
495:     width: 24px;
496:     height: 24px;
497: }
498: @media (max-width: 768px) {
499:     .scroll-to-top {
500:         bottom: 20px;
501:         right: 20px;
502:         width: 45px;
503:         height: 45px;
504:     }
505:     .scroll-to-top svg {
506:         width: 20px;
507:         height: 20px;
508:     }
509: }
```

## File: docs/light-theme.css
```css
  1: * {
  2:     margin: 0;
  3:     padding: 0;
  4:     box-sizing: border-box;
  5: }
  6: :root {
  7:     --primary-color: #0366d6;
  8:     --primary-hover: #0256c2;
  9:     --bg-color: #ffffff;
 10:     --text-color: #24292e;
 11:     --border-color: #e1e4e8;
 12:     --code-bg: #f6f8fa;
 13:     --nav-bg: #ffffff;
 14:     --nav-shadow: rgba(0, 0, 0, 0.1);
 15:     --section-bg: #fafbfc;
 16:     --link-color: #0366d6;
 17: }
 18: body {
 19:     font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
 20:     line-height: 1.6;
 21:     color: var(--text-color);
 22:     background-color: var(--bg-color);
 23:     padding-top: 80px; /* Account for sticky nav */
 24: }
 25: /* Sticky Navigation */
 26: .navbar {
 27:     position: fixed;
 28:     top: 0;
 29:     left: 0;
 30:     right: 0;
 31:     background-color: var(--nav-bg);
 32:     border-bottom: 1px solid var(--border-color);
 33:     box-shadow: 0 2px 4px var(--nav-shadow);
 34:     z-index: 1000;
 35:     padding: 5px 20px;
 36: }
 37: .nav-container {
 38:     max-width: 1200px;
 39:     margin: 0 auto;
 40:     padding: 0;
 41:     display: flex;
 42:     justify-content: space-between;
 43:     align-items: center;
 44: }
 45: .nav-logo {
 46:     display: flex;
 47:     align-items: center;
 48:     font-size: 18px;
 49:     font-weight: 600;
 50:     color: var(--text-color);
 51:     text-decoration: none;
 52:     padding: 0;
 53:     margin-right: 20px;
 54: }
 55: .nav-menu {
 56:     display: flex;
 57:     list-style: none;
 58:     gap: 10px;
 59:     align-items: center;
 60:     padding: 0;
 61: }
 62: .nav-menu li {
 63:     display: flex;
 64:     align-items: center;
 65:     padding: 10px 12px;
 66: }
 67: .nav-menu a {
 68:     display: flex;
 69:     align-items: center;
 70:     padding: 15px 12px;
 71:     color: var(--text-color);
 72:     text-decoration: none;
 73:     font-size: 14px;
 74:     transition: color 0.2s;
 75:     border-bottom: 2px solid transparent;
 76: }
 77: .nav-menu a:hover {
 78:     color: var(--primary-color);
 79:     border-bottom-color: var(--primary-color);
 80: }
 81: .nav-menu a.active {
 82:     color: var(--primary-color);
 83:     border-bottom-color: var(--primary-color);
 84: }
 85: .mobile-menu-toggle {
 86:     display: none;
 87:     background: none;
 88:     border: none;
 89:     font-size: 24px;
 90:     cursor: pointer;
 91:     padding: 10px;
 92:     color: var(--text-color);
 93: }
 94: /* Theme Toggle Button */
 95: .theme-toggle {
 96:     background: none;
 97:     border: 1px solid var(--border-color);
 98:     border-radius: 6px;
 99:     color: var(--text-color);
100:     cursor: pointer;
101:     font-size: 20px;
102:     padding: 4px 10px;
103:     margin-left: 10px;
104:     transition: all 0.2s;
105:     display: flex;
106:     align-items: center;
107:     justify-content: center;
108: }
109: .theme-toggle:hover {
110:     background-color: var(--section-bg);
111:     border-color: var(--primary-color);
112:     color: var(--primary-color);
113: }
114: .theme-toggle:focus {
115:     outline: 2px solid var(--primary-color);
116:     outline-offset: 2px;
117: }
118: .theme-toggle .icon {
119:     display: inline-block;
120:     transition: transform 0.3s;
121: }
122: .theme-toggle .icon.hidden {
123:     display: none;
124: }
125: /* Hero Section */
126: .hero {
127:     color: var(--text-color);
128:     padding: 60px 20px 0 20px;
129:     text-align: center;
130: }
131: .hero h1 {
132:     font-size: 2.5em;
133:     margin-bottom: 20px;
134:     font-weight: 600;
135:     color: var(--text-color);
136: }
137: /* Ensure all headings are properly sized */
138: h1 {
139:     font-size: 2.5em;
140:     font-weight: 600;
141: }
142: h2 {
143:     font-size: 2em;
144:     font-weight: 600;
145: }
146: h3 {
147:     font-size: 1.5em;
148:     font-weight: 600;
149: }
150: h4 {
151:     font-size: 1.25em;
152:     font-weight: 600;
153: }
154: h5 {
155:     font-size: 1.1em;
156:     font-weight: 600;
157: }
158: .hero p {
159:     font-size: 1.2em;
160:     margin-bottom: 30px;
161:     opacity: 0.95;
162:     color: var(--text-color);
163: }
164: .hero-content {
165:     max-width: 1200px;
166:     margin: 0 auto;
167: }
168: .hero-banner {
169:     max-width: 100%;
170:     height: auto;
171:     margin-top: 30px;
172:     border-radius: 8px;
173:     box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
174: }
175: /* Sections */
176: section {
177:     max-width: 1200px;
178:     margin: 0 auto;
179:     padding: 40px 20px 0 20px;
180:     scroll-margin-top: 100px; /* Account for sticky nav */
181: }
182: section:last-child {
183:     padding-bottom: 40px;
184: }
185: section h2 {
186:     font-size: 2em;
187:     font-weight: 600;
188:     margin-bottom: 20px;
189:     padding-bottom: 10px;
190:     border-bottom: 2px solid var(--border-color);
191:     color: var(--text-color);
192: }
193: section h3 {
194:     font-size: 1.5em;
195:     font-weight: 600;
196:     margin-top: 30px;
197:     margin-bottom: 15px;
198:     color: var(--text-color);
199: }
200: section h4 {
201:     font-size: 1.25em;
202:     font-weight: 600;
203:     margin-top: 20px;
204:     margin-bottom: 10px;
205:     color: var(--text-color);
206: }
207: section h5 {
208:     font-size: 1.1em;
209:     font-weight: 600;
210:     margin-top: 15px;
211:     margin-bottom: 8px;
212:     color: var(--text-color);
213: }
214: /* Cards */
215: .card {
216:     background: var(--bg-color);
217:     border: 1px solid var(--border-color);
218:     border-radius: 6px;
219:     padding: 20px;
220:     margin-bottom: 20px;
221:     box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
222: }
223: .card h3 {
224:     margin-top: 0;
225:     color: var(--primary-color);
226: }
227: /* Lists */
228: ul, ol {
229:     list-style-position: inside;
230: }
231: ul ul, ol ul {
232:     padding-left: 20px;
233: }
234: li p {
235:     padding-left: 20px;
236:     margin-top: 15px;
237: }
238: /* Links */
239: a {
240:     color: var(--link-color);
241:     text-decoration: none;
242: }
243: a:hover {
244:     text-decoration: underline;
245: }
246: /* Paragraphs */
247: p {
248:     margin-bottom: 15px;
249: }
250: #architecture p {
251:     margin-top: 15px;
252: }
253: #architecture p:first-child {
254:     margin-top: 0;
255: }
256: p:last-child {
257:     margin-bottom: 0;
258: }
259: .deployment-card p:last-child {
260:     margin-top: 15px;
261: }
262: #security p:last-child, #getting-started p:last-child {
263:     margin-top: 15px;
264: }
265: /* Code blocks */
266: code {
267:     background-color: var(--code-bg);
268:     padding: 2px 6px;
269:     border-radius: 3px;
270:     font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
271:     font-size: 0.9em;
272:     color: #d73a49;
273:     border: 1px solid var(--border-color);
274:     font-weight: 500;
275: }
276: pre {
277:     background-color: var(--code-bg);
278:     padding: 16px;
279:     border-radius: 6px;
280:     overflow-x: auto;
281:     margin-bottom: 15px;
282:     border: 1px solid var(--border-color);
283: }
284: pre code {
285:     background: none;
286:     padding: 0;
287:     border: none;
288:     color: var(--text-color);
289:     font-weight: normal;
290: }
291: /* Tables */
292: table {
293:     width: 100%;
294:     border-collapse: collapse;
295:     margin-bottom: 20px;
296: }
297: table th, table td {
298:     padding: 12px;
299:     text-align: left;
300:     border: 1px solid var(--border-color);
301: }
302: table th {
303:     background-color: var(--primary-color);
304:     color: white;
305:     font-weight: 600;
306: }
307: table tbody tr:nth-child(even) {
308:     background-color: var(--section-bg);
309: }
310: /* Deployment Options */
311: .deployment-options {
312:     display: grid;
313:     grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
314:     gap: 20px;
315:     margin-top: 20px;
316: }
317: .deployment-card {
318:     background: var(--section-bg);
319:     border: 2px solid var(--border-color);
320:     border-radius: 8px;
321:     padding: 25px;
322: }
323: .deployment-card h4 {
324:     margin-top: 0;
325:     color: var(--primary-color);
326: }
327: .deployment-card p {
328:     margin-top: 15px;
329: }
330: /* Documentation Grid */
331: .doc-grid {
332:     display: grid;
333:     grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
334:     gap: 20px;
335:     margin-top: 20px;
336: }
337: .doc-item {
338:     background: var(--section-bg);
339:     border: 1px solid var(--border-color);
340:     border-radius: 6px;
341:     padding: 15px;
342:     transition: transform 0.2s, box-shadow 0.2s;
343: }
344: .doc-item:hover {
345:     transform: translateY(-2px);
346:     box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
347: }
348: .doc-item a {
349:     font-weight: 500;
350:     display: block;
351:     margin-bottom: 8px;
352: }
353: .doc-item p {
354:     font-size: 0.9em;
355:     color: #586069;
356:     margin: 0;
357: }
358: /* Badge */
359: .badge {
360:     display: inline-block;
361:     padding: 4px 8px;
362:     background-color: var(--primary-color);
363:     color: white;
364:     border-radius: 3px;
365:     font-size: 0.8em;
366:     font-weight: 600;
367:     margin-left: 8px;
368: }
369: /* Footer */
370: footer {
371:     background-color: var(--section-bg);
372:     border-top: 1px solid var(--border-color);
373:     padding: 30px 20px;
374:     text-align: center;
375:     color: #586069;
376: }
377: /* Responsive */
378: @media (max-width: 768px) {
379:     .mobile-menu-toggle {
380:         display: block;
381:     }
382:     .nav-menu {
383:         position: fixed;
384:         left: -100%;
385:         top: 60px;
386:         flex-direction: column;
387:         background-color: var(--nav-bg);
388:         width: 100%;
389:         text-align: center;
390:         transition: 0.3s;
391:         box-shadow: 0 10px 27px rgba(0, 0, 0, 0.05);
392:         padding: 20px 0;
393:         border-bottom: 1px solid var(--border-color);
394:     }
395:     .nav-menu.active {
396:         left: 0;
397:     }
398:     .nav-menu li {
399:         width: 100%;
400:     }
401:     .nav-menu a {
402:         padding: 15px;
403:         border-bottom: none;
404:         border-left: 3px solid transparent;
405:     }
406:             .nav-menu a:hover,
407:             .nav-menu a.active {
408:                 border-left-color: var(--primary-color);
409:                 border-bottom-color: transparent;
410:             }
411:             .theme-toggle {
412:                 margin-left: 0;
413:                 margin-top: 10px;
414:             }
415:             .hero h1 {
416:                 font-size: 2em;
417:             }
418:     .hero p {
419:         font-size: 1em;
420:     }
421:     .deployment-options {
422:         grid-template-columns: 1fr;
423:     }
424:     .doc-grid {
425:         grid-template-columns: 1fr;
426:     }
427:     section h2 {
428:         font-size: 1.5em;
429:     }
430:     section h3 {
431:         font-size: 1.3em;
432:     }
433:     section h4 {
434:         font-size: 1.15em;
435:     }
436:     section h5 {
437:         font-size: 1.05em;
438:     }
439: }
440: /* Smooth scroll */
441: html {
442:     scroll-behavior: smooth;
443: }
444: /* Scroll to Top Button */
445: .scroll-to-top {
446:     position: fixed;
447:     bottom: 30px;
448:     right: 30px;
449:     width: 50px;
450:     height: 50px;
451:     border-radius: 50%;
452:     background-color: rgba(3, 102, 214, 0.15);
453:     backdrop-filter: blur(8px);
454:     -webkit-backdrop-filter: blur(8px);
455:     border: 2px solid rgba(3, 102, 214, 0.3);
456:     color: var(--primary-color);
457:     cursor: pointer;
458:     display: flex;
459:     align-items: center;
460:     justify-content: center;
461:     z-index: 999;
462:     opacity: 0;
463:     visibility: hidden;
464:     pointer-events: none;
465:     transition: opacity 0.3s ease, visibility 0.3s ease, transform 0.3s ease, background-color 0.3s ease, border-color 0.3s ease;
466:     box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
467: }
468: .scroll-to-top.visible {
469:     opacity: 1;
470:     visibility: visible;
471:     pointer-events: auto;
472: }
473: .scroll-to-top:hover {
474:     background-color: rgba(3, 102, 214, 0.25);
475:     border-color: rgba(3, 102, 214, 0.5);
476:     transform: translateY(-3px);
477:     box-shadow: 0 6px 16px rgba(0, 0, 0, 0.15);
478: }
479: .scroll-to-top:active {
480:     transform: translateY(-1px);
481: }
482: .scroll-to-top svg {
483:     width: 24px;
484:     height: 24px;
485: }
486: @media (max-width: 768px) {
487:     .scroll-to-top {
488:         bottom: 20px;
489:         right: 20px;
490:         width: 45px;
491:         height: 45px;
492:     }
493:     .scroll-to-top svg {
494:         width: 20px;
495:         height: 20px;
496:     }
497: }
```

## File: tf_backend_state/set-state.sh
```bash
  1: #!/bin/bash
  2: # Script to assume AWS role and upload Terraform state file to S3
  3: # ROLE_ARN is retrieved from GitHub repository secret 'AWS_STATE_ACCOUNT_ROLE_ARN'
  4: # REGION is retrieved from GitHub repository variable 'AWS_REGION' (defaults to 'us-east-1' if not set)
  5: # Bucket name is retrieved from Terraform output and saved to GitHub repository variable
  6: # Bucket prefix is retrieved from GitHub repository variables
  7: set -euo pipefail
  8: # Clean up any existing AWS credentials from environment to prevent conflicts
  9: # This ensures the script starts with a clean slate and uses the correct credentials
 10: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
 11: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 12: unset AWS_SESSION_TOKEN 2>/dev/null || true
 13: unset AWS_PROFILE 2>/dev/null || true
 14: # Colors for output
 15: RED='\033[0;31m'
 16: GREEN='\033[0;32m'
 17: YELLOW='\033[1;33m'
 18: NC='\033[0m' # No Color
 19: # Function to print colored messages
 20: print_error() {
 21:     echo -e "${RED}ERROR:${NC} $1" >&2
 22: }
 23: print_success() {
 24:     echo -e "${GREEN}SUCCESS:${NC} $1"
 25: }
 26: print_info() {
 27:     echo -e "${YELLOW}INFO:${NC} $1"
 28: }
 29: # Check if AWS CLI is installed
 30: if ! command -v aws &> /dev/null; then
 31:     print_error "AWS CLI is not installed."
 32:     echo "Please install it from: https://aws.amazon.com/cli/"
 33:     exit 1
 34: fi
 35: # Check if GitHub CLI is installed
 36: if ! command -v gh &> /dev/null; then
 37:     print_error "GitHub CLI (gh) is not installed."
 38:     echo "Please install it from: https://cli.github.com/"
 39:     echo ""
 40:     echo "Or use the alternative method with curl (requires GITHUB_TOKEN environment variable):"
 41:     echo "  export GITHUB_TOKEN=your_token"
 42:     exit 1
 43: fi
 44: # Check if user is authenticated with GitHub CLI
 45: if ! gh auth status &> /dev/null; then
 46:     print_error "Not authenticated with GitHub CLI."
 47:     echo "Please run: gh auth login"
 48:     exit 1
 49: fi
 50: # Check if jq is installed (required for gh --jq flag)
 51: if ! command -v jq &> /dev/null; then
 52:     print_error "jq is not installed."
 53:     echo "Please install it:"
 54:     echo "  macOS: brew install jq"
 55:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 56:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 57:     exit 1
 58: fi
 59: # Check if Terraform is installed
 60: if ! command -v terraform &> /dev/null; then
 61:     print_error "Terraform is not installed."
 62:     echo "Please install it from: https://www.terraform.io/downloads"
 63:     exit 1
 64: fi
 65: # Get repository owner and name
 66: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 67: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 68: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 69:     print_error "Could not determine repository information."
 70:     echo "Please ensure you're in a git repository and have proper permissions."
 71:     exit 1
 72: fi
 73: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 74: # Function to get repository variable using GitHub CLI
 75: get_repo_variable() {
 76:     local var_name=$1
 77:     local value
 78:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 79:     if [ -z "$value" ]; then
 80:         return 1
 81:     fi
 82:     echo "$value"
 83: }
 84: # Function to set repository variable using GitHub CLI
 85: set_repo_variable() {
 86:     local var_name=$1
 87:     local var_value=$2
 88:     if gh variable set "${var_name}" --body "${var_value}" --repo "${REPO_OWNER}/${REPO_NAME}" 2>/dev/null; then
 89:         return 0
 90:     else
 91:         return 1
 92:     fi
 93: }
 94: # Function to retrieve secret from AWS Secrets Manager
 95: get_aws_secret() {
 96:     local secret_name=$1
 97:     local secret_json
 98:     local exit_code
 99:     # Retrieve secret from AWS Secrets Manager
100:     # Use AWS_REGION if set, otherwise default to us-east-1
101:     secret_json=$(aws secretsmanager get-secret-value \
102:         --secret-id "$secret_name" \
103:         --region "${AWS_REGION:-us-east-1}" \
104:         --query SecretString \
105:         --output text 2>&1)
106:     # Capture exit code before checking
107:     exit_code=$?
108:     # Validate secret retrieval
109:     if [ $exit_code -ne 0 ]; then
110:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
111:         print_error "Error: $secret_json"
112:         return 1
113:     fi
114:     # Validate JSON can be parsed
115:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
116:         print_error "Secret '${secret_name}' contains invalid JSON"
117:         return 1
118:     fi
119:     echo "$secret_json"
120: }
121: # Function to get key value from secret JSON
122: get_secret_key_value() {
123:     local secret_json=$1
124:     local key_name=$2
125:     local value
126:     # Validate JSON can be parsed
127:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
128:         print_error "Invalid JSON provided to get_secret_key_value"
129:         return 1
130:     fi
131:     # Extract key value using jq
132:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
133:     # Check if jq command succeeded
134:     if [ $? -ne 0 ]; then
135:         print_error "Failed to parse JSON or extract key '${key_name}'"
136:         return 1
137:     fi
138:     # Check if key exists (jq returns "null" for non-existent keys)
139:     if [ "$value" = "null" ] || [ -z "$value" ]; then
140:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
141:         return 1
142:     fi
143:     echo "$value"
144: }
145: # Retrieve ROLE_ARN from AWS Secrets Manager
146: print_info "Retrieving AWS_STATE_ACCOUNT_ROLE_ARN from AWS Secrets Manager..."
147: SECRET_JSON=$(get_aws_secret "github-role" || echo "")
148: if [ -z "$SECRET_JSON" ]; then
149:     print_error "Failed to retrieve secret from AWS Secrets Manager"
150:     exit 1
151: fi
152: ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
153: if [ -z "$ROLE_ARN" ]; then
154:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
155:     exit 1
156: fi
157: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
158: # Retrieve REGION from repository variable
159: print_info "Retrieving AWS_REGION from repository variables..."
160: REGION=$(get_repo_variable "AWS_REGION" || echo "")
161: if [ -z "$REGION" ]; then
162:     print_info "AWS_REGION not found in repository variables, defaulting to 'us-east-1'"
163:     REGION="us-east-1"
164: else
165:     print_success "Retrieved AWS_REGION: $REGION"
166: fi
167: print_info "Assuming role: $ROLE_ARN"
168: print_info "Region: $REGION"
169: # Assume the role first
170: ROLE_SESSION_NAME="set-state-$(date +%s)"
171: # Assume role and capture output
172: ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
173:     --role-arn "$ROLE_ARN" \
174:     --role-session-name "$ROLE_SESSION_NAME" \
175:     --region "$REGION" 2>&1)
176: if [ $? -ne 0 ]; then
177:     print_error "Failed to assume role: $ASSUME_ROLE_OUTPUT"
178:     exit 1
179: fi
180: # Extract credentials from JSON output
181: # Try using jq if available (more reliable), otherwise use sed/grep
182: if command -v jq &> /dev/null; then
183:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
184:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
185:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
186: else
187:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
188:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
189:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
190:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
191: fi
192: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
193:     print_error "Failed to extract credentials from assume-role output."
194:     print_error "Output was: $ASSUME_ROLE_OUTPUT"
195:     exit 1
196: fi
197: print_success "Successfully assumed role"
198: # Verify the credentials work
199: CALLER_ARN=$(aws sts get-caller-identity --region "$REGION" --query 'Arn' --output text 2>&1)
200: if [ $? -ne 0 ]; then
201:     print_error "Failed to verify assumed role credentials: $CALLER_ARN"
202:     exit 1
203: fi
204: print_info "Assumed role identity: $CALLER_ARN"
205: # Retrieve BACKEND_PREFIX from repository variable (needed for both provisioning and upload)
206: print_info "Retrieving BACKEND_PREFIX from repository variables..."
207: BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX" || echo "")
208: if [ -z "$BACKEND_PREFIX" ]; then
209:     print_error "BACKEND_PREFIX not found in repository variables."
210:     echo "Please ensure BACKEND_PREFIX is set in GitHub repository variables."
211:     exit 1
212: fi
213: print_success "Retrieved BACKEND_PREFIX: $BACKEND_PREFIX"
214: # Check if BACKEND_BUCKET_NAME exists in repository variables
215: print_info "Checking for existing BACKEND_BUCKET_NAME in repository variables..."
216: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME" || echo "")
217: if [ -z "$BUCKET_NAME" ]; then
218:     print_info "BACKEND_BUCKET_NAME not found in repository variables."
219:     print_info "This means the infrastructure has not been provisioned yet."
220:     print_info "Proceeding with Terraform provisioning..."
221:     # Check if variables.tfvars exists
222:     if [ ! -f "variables.tfvars" ]; then
223:         print_error "variables.tfvars file not found in current directory."
224:         echo "Please ensure variables.tfvars exists with required variables."
225:         exit 1
226:     fi
227:     print_success "Found variables.tfvars file"
228:     # Terraform init
229:     print_info "Running terraform init..."
230:     if ! terraform init -backend=false; then
231:         print_error "Terraform init failed."
232:         exit 1
233:     fi
234:     print_success "Terraform initialized"
235:     # Terraform validate
236:     print_info "Running terraform validate..."
237:     if ! terraform validate; then
238:         print_error "Terraform validation failed."
239:         exit 1
240:     fi
241:     print_success "Terraform validation passed"
242:     # Terraform plan
243:     print_info "Running terraform plan..."
244:     if ! terraform plan -var-file="variables.tfvars" -out terraform.tfplan; then
245:         print_error "Terraform plan failed."
246:         exit 1
247:     fi
248:     print_success "Terraform plan completed"
249:     # Terraform apply
250:     print_info "Running terraform apply..."
251:     if ! terraform apply -auto-approve terraform.tfplan; then
252:         print_error "Terraform apply failed."
253:         exit 1
254:     fi
255:     print_success "Terraform apply completed"
256:     # Get bucket name from Terraform output
257:     print_info "Retrieving bucket name from Terraform output..."
258:     BUCKET_NAME=$(terraform output -raw bucket_name 2>/dev/null || echo "")
259:     if [ -z "$BUCKET_NAME" ]; then
260:         print_error "Failed to retrieve bucket name from Terraform output."
261:         echo "Please check Terraform outputs."
262:         exit 1
263:     fi
264:     print_success "Retrieved bucket name: $BUCKET_NAME"
265: else
266:     print_success "Found existing BACKEND_BUCKET_NAME: $BUCKET_NAME"
267:     # Check if state file exists in S3 and download if available
268:     S3_PATH="s3://${BUCKET_NAME}/${BACKEND_PREFIX}"
269:     print_info "Checking for existing state file at: $S3_PATH"
270:     if aws s3 ls "$S3_PATH" --region "$REGION" &>/dev/null; then
271:         print_info "State file exists in S3, downloading..."
272:         if aws s3 cp "$S3_PATH" terraform.tfstate --region "$REGION"; then
273:             print_success "State file downloaded successfully from S3"
274:         else
275:             print_error "Failed to download state file from S3"
276:             exit 1
277:         fi
278:     else
279:         print_info "State file does not exist in S3"
280:         # Check if terraform.tfstate exists locally
281:         if [ ! -f "terraform.tfstate" ]; then
282:             print_error "terraform.tfstate file not found locally and not in S3."
283:             echo "Please ensure you have run 'terraform apply' first to generate the state file."
284:             exit 1
285:         fi
286:         print_success "Found terraform.tfstate file locally"
287:     fi
288:     # Verify bucket name from Terraform output matches
289:     print_info "Verifying bucket name from Terraform output..."
290:     TERRAFORM_BUCKET_NAME=$(terraform output -raw bucket_name 2>/dev/null || echo "")
291:     if [ -n "$TERRAFORM_BUCKET_NAME" ] && [ "$TERRAFORM_BUCKET_NAME" != "$BUCKET_NAME" ]; then
292:         print_error "Bucket name mismatch!"
293:         echo "Repository variable BACKEND_BUCKET_NAME: $BUCKET_NAME"
294:         echo "Terraform output bucket_name: $TERRAFORM_BUCKET_NAME"
295:         echo "Please verify the bucket name is correct."
296:         exit 1
297:     fi
298:     print_success "Bucket name verified"
299: fi
300: print_info "Saving bucket name to GitHub repository variable..."
301: if set_repo_variable "BACKEND_BUCKET_NAME" "$BUCKET_NAME"; then
302:     print_success "Saved BACKEND_BUCKET_NAME to repository variables"
303: else
304:     print_error "Failed to save BACKEND_BUCKET_NAME to repository variables."
305:     echo "Please ensure you have proper permissions to write repository variables."
306:     exit 1
307: fi
308: S3_PATH="s3://${BUCKET_NAME}/${BACKEND_PREFIX}"
309: print_info "Uploading state file to: $S3_PATH"
310: if aws s3 cp terraform.tfstate "$S3_PATH" --region "$REGION"; then
311:     print_success "State file uploaded successfully to $S3_PATH"
312: else
313:     print_error "Failed to upload state file to S3"
314:     exit 1
315: fi
316: print_success "Script completed successfully"
```

## File: application/modules/postgresql/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name prefix for resources"
 13:   type        = string
 14: }
 15:
 16: variable "namespace" {
 17:   description = "Kubernetes namespace for PostgreSQL"
 18:   type        = string
 19:   default     = "ldap-2fa"
 20: }
 21:
 22: variable "secret_name" {
 23:   description = "Name of the Kubernetes secret for PostgreSQL password"
 24:   type        = string
 25:   default     = "postgresql-secret"
 26: }
 27:
 28: variable "chart_version" {
 29:   description = "PostgreSQL Helm chart version"
 30:   type        = string
 31:   default     = "18.1.15"
 32: }
 33:
 34: variable "database_name" {
 35:   description = "Name of the database to create"
 36:   type        = string
 37:   default     = "ldap2fa"
 38: }
 39:
 40: variable "database_username" {
 41:   description = "Database username"
 42:   type        = string
 43:   default     = "ldap2fa"
 44: }
 45:
 46: variable "database_password" {
 47:   description = "Database password"
 48:   type        = string
 49:   sensitive   = true
 50: }
 51:
 52: variable "storage_class" {
 53:   description = "Storage class for PostgreSQL PVC"
 54:   type        = string
 55:   default     = ""
 56: }
 57:
 58: variable "storage_size" {
 59:   description = "Storage size for PostgreSQL PVC"
 60:   type        = string
 61:   default     = "8Gi"
 62: }
 63:
 64: variable "resources" {
 65:   description = "Resource limits and requests for PostgreSQL"
 66:   type = object({
 67:     limits = object({
 68:       cpu    = string
 69:       memory = string
 70:     })
 71:     requests = object({
 72:       cpu    = string
 73:       memory = string
 74:     })
 75:   })
 76:   default = {
 77:     limits = {
 78:       cpu    = "500m"
 79:       memory = "512Mi"
 80:     }
 81:     requests = {
 82:       cpu    = "250m"
 83:       memory = "256Mi"
 84:     }
 85:   }
 86: }
 87:
 88: variable "tags" {
 89:   description = "Tags to apply to resources"
 90:   type        = map(string)
 91:   default     = {}
 92: }
 93:
 94: variable "ecr_registry" {
 95:   description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
 96:   type        = string
 97: }
 98:
 99: variable "ecr_repository" {
100:   description = "ECR repository name"
101:   type        = string
102: }
103:
104: variable "image_tag" {
105:   description = "PostgreSQL image tag in ECR"
106:   type        = string
107:   default     = "postgresql-latest"
108: }
109:
110: variable "values_template_path" {
111:   description = "Path to the PostgreSQL values template file"
112:   type        = string
113:   default     = null
114: }
```

## File: application/modules/redis/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name prefix added to all resources"
 13:   type        = string
 14: }
 15:
 16: variable "enable_redis" {
 17:   description = "Enable Redis deployment"
 18:   type        = bool
 19:   default     = false
 20: }
 21:
 22: variable "namespace" {
 23:   description = "Kubernetes namespace for Redis"
 24:   type        = string
 25:   default     = "redis"
 26: }
 27:
 28: variable "secret_name" {
 29:   description = "Name of the Kubernetes secret for Redis password"
 30:   type        = string
 31:   default     = "redis-secret"
 32: }
 33:
 34: variable "redis_password" {
 35:   description = "Redis authentication password (from GitHub Secrets via TF_VAR_redis_password)"
 36:   type        = string
 37:   sensitive   = true
 38:
 39:   validation {
 40:     condition     = length(var.redis_password) >= 8
 41:     error_message = "Redis password must be at least 8 characters."
 42:   }
 43: }
 44:
 45: variable "chart_version" {
 46:   description = "Bitnami Redis Helm chart version"
 47:   type        = string
 48:   default     = "24.0.9"
 49: }
 50:
 51: variable "storage_class_name" {
 52:   description = "Storage class for Redis PVC"
 53:   type        = string
 54:   default     = ""
 55: }
 56:
 57: variable "storage_size" {
 58:   description = "Storage size for Redis PVC"
 59:   type        = string
 60:   default     = "1Gi"
 61: }
 62:
 63: variable "persistence_enabled" {
 64:   description = "Enable persistence for Redis data"
 65:   type        = bool
 66:   default     = true
 67: }
 68:
 69: variable "resources" {
 70:   description = "Resource limits and requests for Redis"
 71:   type = object({
 72:     limits = object({
 73:       cpu    = string
 74:       memory = string
 75:     })
 76:     requests = object({
 77:       cpu    = string
 78:       memory = string
 79:     })
 80:   })
 81:   default = {
 82:     limits = {
 83:       cpu    = "500m"
 84:       memory = "256Mi"
 85:     }
 86:     requests = {
 87:       cpu    = "100m"
 88:       memory = "128Mi"
 89:     }
 90:   }
 91: }
 92:
 93: variable "metrics_enabled" {
 94:   description = "Enable Prometheus metrics exporter"
 95:   type        = bool
 96:   default     = false
 97: }
 98:
 99: variable "tags" {
100:   description = "Tags to apply to resources"
101:   type        = map(string)
102:   default     = {}
103: }
104:
105: variable "backend_namespace" {
106:   description = "Namespace where the backend pods are deployed (for network policy)"
107:   type        = string
108:   default     = "twofa-backend"
109: }
110:
111: variable "ecr_registry" {
112:   description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
113:   type        = string
114: }
115:
116: variable "ecr_repository" {
117:   description = "ECR repository name"
118:   type        = string
119: }
120:
121: variable "image_tag" {
122:   description = "Redis image tag in ECR"
123:   type        = string
124:   default     = "redis-latest"
125: }
126:
127: variable "values_template_path" {
128:   description = "Path to the Redis values template file"
129:   type        = string
130:   default     = null
131: }
```

## File: .gitignore
```
 1: # Local .terraform directories
 2: **/.terraform/*
 3:
 4: # .tfstate files
 5: *.tfstate
 6: *.tfstate.*
 7:
 8: # Crash log files
 9: crash.log
10: crash.*.log
11:
12: # Exclude all .tfvars files, which are likely to contain sensitive data, such as
13: # password, private keys, and other secrets. These should not be part of version
14: # control as they are data points which are potentially sensitive and subject
15: # to change depending on the environment.
16: # *.tfvars
17: *.tfvars.json
18:
19: # Ignore override files as they are usually used to override resources locally and so
20: # are not checked in
21: override.tf
22: override.tf.json
23: *_override.tf
24: *_override.tf.json
25:
26: # Ignore transient lock info files created by terraform apply
27: .terraform.tfstate.lock.info
28:
29: # Include override files you do wish to add to version control using negated pattern
30: # !example_override.tf
31:
32: # Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
33: # example: *tfplan*
34: *.plan
35: *.tfplan
36:
37: # Ignore CLI configuration files
38: .terraformrc
39: terraform.rc
40:
41: .cursor/
42:
43: .idea/
44:
45: .vscode/
46: # Snyk Security Extension - AI Rules (auto-generated)
47: .cursor/rules/snyk_rules.mdc
48:
49: # Generated backend configuration (created from tfstate-backend-values-template.hcl)
50: backend_infra/backend.hcl
51: application/backend.hcl
52:
53: .env
54:
55: .DS_Store
56:
57: ca-config.json
58: ca.csr
59: ca-cert.pem
```

## File: application/modules/alb/main.tf
```hcl
  1: # *** EKS Auto mode has its own load balancer driver ***
  2: # So there is no need to configure AWS Load Balancer Controller
  3:
  4: # *** EKS Auto Mode takes care of IAM permissions ***
  5: # There is no need to attach AWSLoadBalancerControllerIAMPolicy to the EKS Node IAM Role
  6:
  7: locals {
  8:   # ingress_alb_name            = "${var.prefix}-${var.region}-${var.ingress_alb_name}-${var.env}"
  9:   # service_alb_name            = "${var.prefix}-${var.region}-${var.service_alb_name}-${var.env}"
 10:   ingressclass_alb_name       = "${var.prefix}-${var.region}-${var.ingressclass_alb_name}-${var.env}"
 11:   ingressclassparams_alb_name = "${var.prefix}-${var.region}-${var.ingressclassparams_alb_name}-${var.env}"
 12: }
 13:
 14: # Kubernetes Ingress and Service resources commented out
 15: # These are not needed - OpenLDAP Helm chart creates its own Ingress resources
 16: # which will use the IngressClass defined below
 17:
 18: # resource "kubernetes_ingress_v1" "ingress_alb" {
 19: #   metadata {
 20: #     name      = local.ingress_alb_name
 21: #     namespace = "default"
 22: #     annotations = merge(
 23: #       {
 24: #         "alb.ingress.kubernetes.io/scheme"         = "internet-facing"
 25: #         "alb.ingress.kubernetes.io/tags"          = "Terraform=true,Environment=${var.env}"
 26: #         "alb.ingress.kubernetes.io/target-type"   = "ip"
 27: #         "alb.ingress.kubernetes.io/listen-ports" = var.acm_certificate_arn != null ? "[{\"HTTP\":80},{\"HTTPS\":443}]" : "[{\"HTTP\":80}]"
 28: #       },
 29: #       var.acm_certificate_arn != null ? {
 30: #         "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
 31: #         "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
 32: #         "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"
 33: #       } : {}
 34: #     )
 35: #   }
 36: #
 37: #   spec {
 38: #     # this matches the name of IngressClass.
 39: #     # this can be omitted if you have a default ingressClass in cluster: the one with ingressclass.kubernetes.io/is-default-class: "true"  annotation
 40: #     ingress_class_name = local.ingressclass_alb_name
 41: #
 42: #     rule {
 43: #       http {
 44: #         path {
 45: #           path      = "/"
 46: #           path_type = "Prefix"
 47: #
 48: #           backend {
 49: #             service {
 50: #               name = kubernetes_service_v1.service_alb.metadata[0].name
 51: #               port {
 52: #                 number = 8080
 53: #               }
 54: #             }
 55: #           }
 56: #         }
 57: #       }
 58: #     }
 59: #   }
 60: # }
 61: #
 62: # # Kubernetes Service for the App
 63: # resource "kubernetes_service_v1" "service_alb" {
 64: #   metadata {
 65: #     name      = local.service_alb_name
 66: #     namespace = "default"
 67: #     labels = {
 68: #       app = var.app_name
 69: #     }
 70: #   }
 71: #
 72: #   spec {
 73: #     selector = {
 74: #       app = var.app_name
 75: #     }
 76: #
 77: #     port {
 78: #       port        = 8080
 79: #       target_port = 8080
 80: #     }
 81: #
 82: #     type = "ClusterIP"
 83: #   }
 84: # }
 85:
 86: # The IngressClassParams resource is a custom Kubernetes resource (CRD) provided by EKS Auto Mode.
 87: # We use the `kubernetes_manifest` resource to manage it in a Terraform-native way.
 88: #
 89: # ⚠️ RISKS AND MITIGATION:
 90: #
 91: # 1. CRD Availability Risk:
 92: #    - The IngressClassParams CRD is installed by EKS Auto Mode when the cluster is created
 93: #    - If Terraform runs before Auto Mode finishes initializing, the CRD may not exist
 94: #    - This causes failures during `terraform apply` (not plan, since we can't check CRD existence in plan)
 95: #
 96: # 2. Mitigation Strategies:
 97: #    a) Ensure cluster is fully ready: The Kubernetes provider uses data sources that require
 98: #       the cluster to exist, but doesn't guarantee CRD availability
 99: #    b) Use time_sleep for initial deployments: Adds a delay to allow Auto Mode to initialize
100: #    c) Retry logic: Terraform will retry on apply, but you may need to run apply multiple times
101: #    d) Manual verification: Check CRD exists: `kubectl get crd ingressclassparams.eks.amazonaws.com`
102: #
103: # 3. Alternative Approach:
104: #    If you experience frequent CRD availability issues, consider:
105: #    - Using the original null_resource + kubectl approach (more forgiving)
106: #    - Adding a data source to check CRD existence first (requires kubectl provider)
107: #    - Using a Helm chart that handles CRD installation
108: #
109: # Annotation Strategy (cluster-wide defaults):
110: # - IngressClassParams defines cluster-wide defaults that apply to all Ingresses using this IngressClass
111: # - EKS Auto Mode IngressClassParams supports: scheme, ipAddressType, group.name, and certificateARNs
112: # - Per-Ingress ALB configuration (load-balancer-name, listen-ports, ssl-redirect, target-type)
113: #   should be defined at the Ingress level via annotations
114: # - All Ingresses using this IngressClass inherit cluster-wide settings from IngressClassParams
115:
116: # Optional: Add a delay for initial cluster setup to allow EKS Auto Mode to install CRDs
117: #
118: # IMPORTANT: There is NO Terraform resource that represents "CRD is installed"
119: # The IngressClassParams CRD is installed asynchronously by EKS Auto Mode after cluster creation.
120: # The cluster resource (module.eks in backend_infra) completes before CRDs are guaranteed to exist.
121: #
122: # What we're actually waiting for:
123: # - NOT a Terraform resource (there isn't one for CRD availability)
124: # - The asynchronous EKS Auto Mode process to install the CRD
125: # - This typically happens within seconds of cluster creation, but isn't guaranteed
126: #
127: # Set wait_for_crd = true for initial deployments, false after cluster is established
128: resource "time_sleep" "wait_for_eks_auto_mode" {
129:   # Always create the resource, but use 0s duration when wait_for_crd is false
130:   # This allows us to always reference it in depends_on (which requires a static list)
131:   create_duration = var.wait_for_crd ? "30s" : "0s"
132:
133:   # Trigger recreation if cluster changes (helps with new cluster deployments)
134:   triggers = {
135:     cluster_name = var.cluster_name
136:   }
137: }
138:
139: resource "kubernetes_manifest" "ingressclassparams_alb" {
140:   # Wait for:
141:   # 1. The Kubernetes provider to be configured (implicit via data.aws_eks_cluster)
142:   # 2. Optionally, a delay to allow EKS Auto Mode to install the CRD
143:   #
144:   # Note: We can't explicitly depend on the CRD existing because there's no Terraform
145:   # resource for it. The time_sleep is a workaround for the asynchronous CRD installation.
146:   # When wait_for_crd is false, time_sleep has 0s duration (no actual delay).
147:   depends_on = [time_sleep.wait_for_eks_auto_mode]
148:
149:   manifest = {
150:     apiVersion = "eks.amazonaws.com/v1"
151:     kind       = "IngressClassParams"
152:     metadata = {
153:       name = local.ingressclassparams_alb_name
154:     }
155:     spec = merge(
156:       {
157:         scheme        = var.alb_scheme
158:         ipAddressType = var.alb_ip_address_type
159:         group = {
160:           name = var.alb_group_name
161:         }
162:       },
163:       var.acm_certificate_arn != null && var.acm_certificate_arn != "" ? {
164:         certificateARNs = [var.acm_certificate_arn]
165:       } : {}
166:     )
167:   }
168:
169:   # Wait for the resource to be created and ready
170:   # This ensures the resource exists before dependent resources are created
171:   wait {
172:     fields = {
173:       "metadata.name" = local.ingressclassparams_alb_name
174:     }
175:   }
176:
177:   # Use server-side apply to handle conflicts better
178:   # This is safer for custom resources that might be managed elsewhere
179:   computed_fields = ["metadata.labels", "metadata.annotations"]
180: }
181:
182: # IngressClass binds Ingress resources to EKS Auto Mode controller
183: # and references IngressClassParams for cluster-wide ALB defaults
184: resource "kubernetes_ingress_class_v1" "ingressclass_alb" {
185:   depends_on = [kubernetes_manifest.ingressclassparams_alb]
186:   metadata {
187:     name = local.ingressclass_alb_name
188:
189:     # Use this annotation to set an IngressClass as Default
190:     # If an Ingress doesn't specify a class, it will use the Default
191:     annotations = {
192:       "ingressclass.kubernetes.io/is-default-class" = "true"
193:     }
194:   }
195:
196:   spec {
197:     # Configures the IngressClass to use EKS Auto Mode (built-in load balancer driver)
198:     controller = "eks.amazonaws.com/alb"
199:     parameters {
200:       api_group = "eks.amazonaws.com"
201:       kind      = "IngressClassParams"
202:       # References IngressClassParams which contains cluster-wide defaults (scheme, ipAddressType, group.name, certificateARNs)
203:       name = local.ingressclassparams_alb_name
204:     }
205:   }
206: }
```

## File: application/modules/argocd/main.tf
```hcl
  1: locals {
  2:   argocd_role_name       = "${var.prefix}-${var.region}-${var.argocd_role_name_component}-${var.env}"
  3:   argocd_capability_name = "${var.prefix}-${var.region}-${var.argocd_capability_name_component}-${var.env}"
  4:
  5:   tags = {
  6:     Env       = "${var.env}"
  7:     Terraform = "true"
  8:   }
  9: }
 10:
 11: # IAM Trust Policy for ArgoCD Capability Role
 12: data "aws_iam_policy_document" "argocd_assume_role" {
 13:   statement {
 14:     effect = "Allow"
 15:
 16:     principals {
 17:       type        = "Service"
 18:       identifiers = ["capabilities.eks.amazonaws.com"]
 19:     }
 20:
 21:     actions = [
 22:       "sts:AssumeRole",
 23:       "sts:TagSession",
 24:     ]
 25:   }
 26: }
 27:
 28: # IAM Role for ArgoCD Capability
 29: resource "aws_iam_role" "argocd_capability" {
 30:   name = local.argocd_role_name
 31:
 32:   assume_role_policy = data.aws_iam_policy_document.argocd_assume_role.json
 33:
 34:   tags = merge(
 35:     local.tags,
 36:     {
 37:       Name = local.argocd_role_name
 38:     }
 39:   )
 40:
 41:   # Force replacement if trust policy changes to ensure AWS validates correctly
 42:   lifecycle {
 43:     create_before_destroy = true
 44:   }
 45: }
 46:
 47: # IAM Policy Document for ArgoCD Capability
 48: data "aws_iam_policy_document" "argocd_capability" {
 49:   statement {
 50:     sid    = "EKSDescribe"
 51:     effect = "Allow"
 52:
 53:     actions = [
 54:       "eks:DescribeCluster",
 55:       "eks:ListClusters",
 56:       "eks:DescribeUpdate",
 57:       "eks:ListUpdates"
 58:     ]
 59:
 60:     resources = var.iam_policy_eks_resources
 61:   }
 62:
 63:   statement {
 64:     sid    = "SecretsManager"
 65:     effect = "Allow"
 66:
 67:     actions = [
 68:       "secretsmanager:GetSecretValue",
 69:       "secretsmanager:DescribeSecret",
 70:       "secretsmanager:ListSecrets"
 71:     ]
 72:
 73:     resources = var.iam_policy_secrets_manager_resources
 74:   }
 75:
 76:   statement {
 77:     sid    = "CodeConnections"
 78:     effect = "Allow"
 79:
 80:     actions = [
 81:       "codeconnections:ListConnections",
 82:       "codeconnections:GetConnection"
 83:     ]
 84:
 85:     resources = var.iam_policy_code_connections_resources
 86:   }
 87:
 88:   dynamic "statement" {
 89:     for_each = var.enable_ecr_access ? [1] : []
 90:     content {
 91:       sid    = "ECRAccess"
 92:       effect = "Allow"
 93:
 94:       actions = [
 95:         "ecr:GetAuthorizationToken",
 96:         "ecr:BatchCheckLayerAvailability",
 97:         "ecr:GetDownloadUrlForLayer",
 98:         "ecr:BatchGetImage"
 99:       ]
100:
101:       resources = var.iam_policy_ecr_resources
102:     }
103:   }
104:
105:   dynamic "statement" {
106:     for_each = var.enable_codecommit_access ? [1] : []
107:     content {
108:       sid    = "CodeCommitAccess"
109:       effect = "Allow"
110:
111:       actions = [
112:         "codecommit:GitPull",
113:         "codecommit:GetRepository"
114:       ]
115:
116:       resources = var.iam_policy_codecommit_resources
117:     }
118:   }
119: }
120:
121: # Attach IAM Policy to Role
122: resource "aws_iam_role_policy" "argocd_capability" {
123:   name   = "${local.argocd_role_name}-policy"
124:   role   = aws_iam_role.argocd_capability.id
125:   policy = data.aws_iam_policy_document.argocd_capability.json
126: }
127:
128: # EKS Cluster Data Source
129: data "aws_eks_cluster" "this" {
130:   name = var.cluster_name
131: }
132:
133: # Wait for IAM role to propagate before creating EKS capability
134: resource "time_sleep" "wait_for_iam_propagation" {
135:   depends_on = [
136:     aws_iam_role.argocd_capability,
137:     aws_iam_role_policy.argocd_capability
138:   ]
139:
140:   create_duration = "30s"
141: }
142:
143: # EKS Capability for ArgoCD
144: resource "aws_eks_capability" "argocd" {
145:   cluster_name    = var.cluster_name
146:   capability_name = local.argocd_capability_name
147:   type            = "ARGOCD"
148:
149:   role_arn                  = aws_iam_role.argocd_capability.arn
150:   delete_propagation_policy = var.delete_propagation_policy
151:
152:   configuration {
153:     argo_cd {
154:       namespace = var.argocd_namespace
155:
156:       aws_idc {
157:         idc_instance_arn = var.idc_instance_arn
158:         idc_region       = var.idc_region
159:       }
160:
161:       dynamic "rbac_role_mapping" {
162:         for_each = var.rbac_role_mappings
163:         content {
164:           role = rbac_role_mapping.value.role
165:
166:           dynamic "identity" {
167:             for_each = rbac_role_mapping.value.identities
168:             content {
169:               id   = identity.value.id
170:               type = identity.value.type
171:             }
172:           }
173:         }
174:       }
175:
176:       dynamic "network_access" {
177:         for_each = length(var.argocd_vpce_ids) > 0 ? [1] : []
178:         content {
179:           vpce_ids = var.argocd_vpce_ids
180:         }
181:       }
182:     }
183:   }
184:
185:   tags = merge(
186:     local.tags,
187:     {
188:       Name                 = local.argocd_capability_name
189:       "eks:cluster"        = var.cluster_name
190:       "eks:capabilityType" = "ARGOCD"
191:     }
192:   )
193:
194:   depends_on = [
195:     aws_iam_role.argocd_capability,
196:     aws_iam_role_policy.argocd_capability,
197:     time_sleep.wait_for_iam_propagation
198:   ]
199: }
200:
201: # External data source to query ArgoCD capability details via AWS CLI
202: # This automatically retrieves server_url and status without manual CLI commands
203: data "external" "argocd_capability" {
204:   program = ["bash", "-c", <<-EOT
205:     # Check if jq is available
206:     if ! command -v jq &> /dev/null; then
207:       echo '{"server_url":"","status":"","error":"jq is required but not installed"}' >&2
208:       exit 1
209:     fi
210:
211:     # Query the capability
212:     result=$(aws eks describe-capability \
213:       --cluster-name "${var.cluster_name}" \
214:       --capability-name "${local.argocd_capability_name}" \
215:       --capability-type ARGOCD \
216:       --region "${var.region}" \
217:       2>&1) || {
218:       # If capability doesn't exist yet or command failed, return empty values
219:       echo '{"server_url":"","status":""}'
220:       exit 0
221:     }
222:
223:     # Extract and format as JSON using jq
224:     echo "$result" | jq -c '{
225:       server_url: (.capability.configuration.argoCd.serverUrl // .configuration.argoCd.serverUrl // ""),
226:       status: (.capability.status // .status // "")
227:     }' 2>/dev/null || echo '{"server_url":"","status":""}'
228:   EOT
229:   ]
230:
231:   depends_on = [aws_eks_capability.argocd]
232: }
233:
234: # Cluster Registration Secret
235: resource "kubernetes_secret" "argocd_local_cluster" {
236:   metadata {
237:     name      = var.local_cluster_secret_name
238:     namespace = var.argocd_namespace
239:     labels = {
240:       "argocd.argoproj.io/secret-type" = "cluster"
241:     }
242:   }
243:
244:   data = {
245:     name    = base64encode(var.local_cluster_secret_name)
246:     server  = base64encode(data.aws_eks_cluster.this.arn)
247:     project = base64encode(var.argocd_project_name)
248:   }
249:
250:   type = "Opaque"
251:
252:   depends_on = [
253:     aws_eks_capability.argocd
254:   ]
255: }
```

## File: application/outputs.tf
```hcl
  1: output "alb_dns_name" {
  2:   description = "DNS name of the shared ALB created by Ingress resources"
  3:   value       = var.use_alb ? local.alb_dns_name : null
  4: }
  5:
  6: output "route53_acm_cert_arn" {
  7:   description = "ACM certificate ARN (validated and ready for use)"
  8:   value       = data.aws_acm_certificate.this.arn
  9: }
 10:
 11: output "route53_domain_name" {
 12:   description = "Root domain name"
 13:   value       = var.domain_name
 14: }
 15:
 16: output "route53_zone_id" {
 17:   description = "Route53 hosted zone ID"
 18:   value       = data.aws_route53_zone.this.zone_id
 19: }
 20:
 21: output "route53_name_servers" {
 22:   description = "Route53 name servers (for registrar configuration)"
 23:   value       = data.aws_route53_zone.this.name_servers
 24: }
 25:
 26: ##################### ALB Module ##########################
 27: output "alb_ingress_class_name" {
 28:   description = "Name of the IngressClass for shared ALB"
 29:   value       = var.use_alb ? module.alb[0].ingress_class_name : null
 30: }
 31:
 32: output "alb_ingress_class_params_name" {
 33:   description = "Name of the IngressClassParams for ALB configuration"
 34:   value       = var.use_alb ? module.alb[0].ingress_class_params_name : null
 35: }
 36:
 37: output "alb_scheme" {
 38:   description = "ALB scheme configured in IngressClassParams"
 39:   value       = var.use_alb ? module.alb[0].alb_scheme : null
 40: }
 41:
 42: output "alb_ip_address_type" {
 43:   description = "ALB IP address type configured in IngressClassParams"
 44:   value       = var.use_alb ? module.alb[0].alb_ip_address_type : null
 45: }
 46:
 47: ##################### Network Policies Module ##########################
 48: # Network policies are created within the openldap module
 49: # These outputs expose the network policy information from the openldap module
 50: output "network_policy_name" {
 51:   description = "Name of the network policy for secure namespace communication"
 52:   value       = module.openldap.network_policy_name
 53: }
 54:
 55: output "network_policy_namespace" {
 56:   description = "Namespace where the network policy is applied"
 57:   value       = module.openldap.network_policy_namespace
 58: }
 59:
 60: output "network_policy_uid" {
 61:   description = "UID of the network policy resource"
 62:   value       = module.openldap.network_policy_uid
 63: }
 64:
 65: ##################### PostgreSQL ##########################
 66: output "postgresql_host" {
 67:   description = "PostgreSQL service hostname"
 68:   value       = var.enable_postgresql ? module.postgresql[0].host : null
 69: }
 70:
 71: output "postgresql_connection_url" {
 72:   description = "PostgreSQL connection URL (without password)"
 73:   value       = var.enable_postgresql ? module.postgresql[0].connection_url : null
 74: }
 75:
 76: output "postgresql_database" {
 77:   description = "PostgreSQL database name"
 78:   value       = var.enable_postgresql ? module.postgresql[0].database : null
 79: }
 80:
 81: ##################### SES Email ##########################
 82: output "ses_sender_email" {
 83:   description = "SES verified sender email"
 84:   value       = var.enable_email_verification ? module.ses[0].sender_email : null
 85: }
 86:
 87: output "ses_iam_role_arn" {
 88:   description = "ARN of the IAM role for SES access (for IRSA)"
 89:   value       = var.enable_email_verification ? module.ses[0].iam_role_arn : null
 90: }
 91:
 92: output "ses_verification_status" {
 93:   description = "SES verification status/instructions"
 94:   value       = var.enable_email_verification ? module.ses[0].verification_status : null
 95: }
 96:
 97: ##################### SNS SMS 2FA ##########################
 98: output "sns_topic_arn" {
 99:   description = "ARN of the SNS topic for SMS 2FA"
100:   value       = var.enable_sms_2fa ? module.sns[0].sns_topic_arn : null
101: }
102:
103: output "sns_topic_name" {
104:   description = "Name of the SNS topic"
105:   value       = var.enable_sms_2fa ? module.sns[0].sns_topic_name : null
106: }
107:
108: output "sns_iam_role_arn" {
109:   description = "ARN of the IAM role for SNS publishing (for IRSA)"
110:   value       = var.enable_sms_2fa ? module.sns[0].iam_role_arn : null
111: }
112:
113: output "sns_service_account_annotation" {
114:   description = "Annotation to add to Kubernetes service account for IRSA"
115:   value       = var.enable_sms_2fa ? module.sns[0].service_account_annotation : null
116: }
117:
118: ##################### Redis SMS OTP Storage ##########################
119: output "redis_host" {
120:   description = "Redis service hostname"
121:   value       = var.enable_redis ? module.redis[0].redis_host : null
122: }
123:
124: output "redis_port" {
125:   description = "Redis service port"
126:   value       = var.enable_redis ? module.redis[0].redis_port : null
127: }
128:
129: output "redis_namespace" {
130:   description = "Kubernetes namespace where Redis is deployed"
131:   value       = var.enable_redis ? module.redis[0].redis_namespace : null
132: }
133:
134: output "redis_password_secret_name" {
135:   description = "Name of the Kubernetes secret containing Redis password"
136:   value       = var.enable_redis ? module.redis[0].redis_password_secret_name : null
137: }
138:
139: output "redis_password_secret_key" {
140:   description = "Key in the secret for Redis password"
141:   value       = var.enable_redis ? module.redis[0].redis_password_secret_key : null
142: }
143:
144: ##################### 2FA Application ##########################
145: output "twofa_app_url" {
146:   description = "URL for the 2FA application (frontend)"
147:   value       = var.twofa_app_host != null ? "https://${var.twofa_app_host}" : null
148: }
149:
150: output "twofa_api_url" {
151:   description = "URL for the 2FA API (backend)"
152:   value       = var.twofa_app_host != null ? "https://${var.twofa_app_host}/api" : null
153: }
154:
155: ##################### ArgoCD Applications ##########################
156: output "argocd_backend_app_name" {
157:   description = "Name of the ArgoCD Application for backend"
158:   value       = var.enable_argocd_apps ? var.argocd_app_backend_name : null
159: }
160:
161: output "argocd_frontend_app_name" {
162:   description = "Name of the ArgoCD Application for frontend"
163:   value       = var.enable_argocd_apps ? var.argocd_app_frontend_name : null
164: }
```

## File: backend_infra/main.tf
```hcl
  1: # Dynamic Account ID
  2: data "aws_caller_identity" "current" {}
  3:
  4: data "aws_availability_zones" "available" {
  5:   state = "available"
  6: }
  7:
  8: # Logging Prefix Pattern
  9: locals {
 10:   current_identity = data.aws_caller_identity.current.arn
 11:   current_account  = data.aws_caller_identity.current.account_id
 12:   azs              = slice(data.aws_availability_zones.available.names, 0, 2)
 13:   vpc_name         = "${var.prefix}-${var.region}-${var.vpc_name}-${var.env}"
 14:   ngw_name         = "${var.prefix}-${var.region}-${var.ngw_name}-${var.env}"
 15:   igw_name         = "${var.prefix}-${var.region}-${var.igw_name}-${var.env}"
 16:   route_table_name = "${var.prefix}-${var.region}-${var.route_table_name}-${var.env}"
 17:   public_subnet_names = [
 18:     "${local.vpc_name}-public-subnet-1",
 19:     "${local.vpc_name}-public-subnet-2"
 20:   ]
 21:   private_subnet_names = [
 22:     "${local.vpc_name}-private-subnet-1",
 23:     "${local.vpc_name}-private-subnet-2"
 24:   ]
 25:   cluster_name = "${var.prefix}-${var.region}-${var.cluster_name}-${var.env}"
 26:   tags = {
 27:     Env       = "${var.env}"
 28:     Terraform = "true"
 29:   }
 30: }
 31:
 32: module "vpc" {
 33:   source  = "terraform-aws-modules/vpc/aws"
 34:   version = "6.5.1"
 35:   name    = local.vpc_name
 36:   cidr    = var.vpc_cidr
 37:   azs     = local.azs
 38:   ### Private Subnets ###
 39:   private_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
 40:   private_subnet_names = local.private_subnet_names
 41:   private_subnet_tags = {
 42:     "kubernetes.io/role/internal-elb"             = 1
 43:     "kubernetes.io/cluster/${local.cluster_name}" = "shared"
 44:   }
 45:   ### Public Subnets ###
 46:   public_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
 47:   public_subnet_names = local.public_subnet_names
 48:   public_subnet_tags = {
 49:     "kubernetes.io/role/elb"                      = 1
 50:     "kubernetes.io/cluster/${local.cluster_name}" = "shared"
 51:   }
 52:
 53:   create_database_subnet_group = false
 54:   # manage_default_network_acl    = false
 55:   # manage_default_route_table    = false
 56:   # manage_default_security_group = false
 57:
 58:   enable_dns_hostnames = true
 59:   enable_dns_support   = true
 60:
 61:   enable_dhcp_options      = true
 62:   dhcp_options_domain_name = "ec2.internal"
 63:
 64:   enable_nat_gateway = true
 65:   single_nat_gateway = true
 66:   nat_gateway_tags = {
 67:     "Name"                                        = "${local.ngw_name}"
 68:     "kubernetes.io/cluster/${local.cluster_name}" = "shared"
 69:   }
 70:
 71:   create_igw             = true
 72:   create_egress_only_igw = false
 73:   enable_vpn_gateway     = false
 74:
 75:   private_route_table_tags = {
 76:     Name = local.route_table_name
 77:   }
 78:
 79:   igw_tags = {
 80:     Name = "${local.igw_name}"
 81:   }
 82:
 83:   tags = local.tags
 84: }
 85:
 86: module "eks" {
 87:   source  = "terraform-aws-modules/eks/aws"
 88:   version = "21.9.0"
 89:
 90:   name                   = local.cluster_name
 91:   kubernetes_version     = var.k8s_version
 92:   endpoint_public_access = true
 93:
 94:   enable_cluster_creator_admin_permissions = true
 95:
 96:   # Enable OIDC provider for IRSA (IAM Roles for Service Accounts)
 97:   # This is required for pods to assume IAM roles (e.g., for SNS access)
 98:   enable_irsa = true
 99:
100:   compute_config = {
101:     enabled    = true
102:     node_pools = ["general-purpose"]
103:   }
104:
105:   vpc_id     = module.vpc.vpc_id
106:   subnet_ids = module.vpc.private_subnets
107:
108:   enabled_log_types           = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
109:   create_cloudwatch_log_group = true
110:
111:   node_iam_role_additional_policies = {
112:     "AmazonSSMManagedInstanceCore" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
113:   }
114:
115:   tags = local.tags
116: }
117:
118: module "endpoints" {
119:   source                 = "./modules/endpoints"
120:   env                    = var.env
121:   region                 = var.region
122:   prefix                 = var.prefix
123:   vpc_id                 = module.vpc.vpc_id
124:   vpc_cidr               = var.vpc_cidr
125:   private_subnets        = module.vpc.private_subnets
126:   endpoint_sg_name       = var.endpoint_sg_name
127:   node_security_group_id = module.eks.node_security_group_id
128:   enable_sts_endpoint    = var.enable_sts_endpoint
129:   enable_sns_endpoint    = var.enable_sns_endpoint
130:   tags                   = local.tags
131: }
132:
133: # module "ebs" {
134: #   source         = "./modules/ebs"
135: #   env            = var.env
136: #   region         = var.region
137: #   prefix         = var.prefix
138: #   ebs_name       = var.ebs_name
139: #   ebs_claim_name = var.ebs_claim_name
140: #
141: #   # Give time for the cluster to complete (controllers, RBAC and IAM propagation)
142: #   depends_on = [module.eks]
143: # }
144:
145: module "ecr" {
146:   source               = "./modules/ecr"
147:   env                  = var.env
148:   region               = var.region
149:   prefix               = var.prefix
150:   ecr_name             = var.ecr_name
151:   image_tag_mutability = var.image_tag_mutability
152:   policy               = jsonencode(var.ecr_lifecycle_policy)
153:   tags                 = local.tags
154: }
```

## File: .github/workflows/backend_infra_destroying.yaml
```yaml
 1: name: Backend Infra Destroying
 2: on:
 3:   workflow_dispatch:
 4:     inputs:
 5:       region:
 6:         description: 'Select AWS Region'
 7:         required: true
 8:         type: choice
 9:         default: 'us-east-1: N. Virginia'
10:         options:
11:           - 'us-east-1: N. Virginia'
12:           - 'us-east-2: Ohio'
13:       environment:
14:         description: 'Select Environment'
15:         required: true
16:         type: choice
17:         default: prod
18:         options:
19:           - prod
20:           - dev
21: jobs:
22:   SetRegion:
23:     runs-on: ubuntu-latest
24:     permissions: {}
25:     outputs:
26:       region_code: ${{ steps.set_region.outputs.region_code }}
27:     steps:
28:       - name: Set Region
29:         id: set_region
30:         run: |
31:           SELECTED_REGION="${{ inputs.region }}"
32:           echo "region_code=${SELECTED_REGION%%:*}" >> $GITHUB_OUTPUT
33:   InfraDestroy:
34:     runs-on: ubuntu-latest
35:     needs:
36:       - SetRegion
37:     permissions:
38:       contents: write
39:       actions: write
40:       id-token: write
41:     env:
42:       AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
43:     defaults:
44:       run:
45:         working-directory: ./backend_infra
46:     steps:
47:       - name: Checkout the repo code
48:         uses: actions/checkout@v4
49:       - name: Setup terraform
50:         uses: hashicorp/setup-terraform@v3
51:         with:
52:           terraform_version: 1.14.0
53:       - name: Configure AWS credentials (State Account)
54:         uses: aws-actions/configure-aws-credentials@v4
55:         with:
56:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
57:           role-session-name: GitHubActions-BackendInfraDestroy
58:           aws-region: ${{ env.AWS_REGION }}
59:       - name: Create backend.hcl from placeholder
60:         run: |
61:           cp tfstate-backend-values-template.hcl backend.hcl
62:           sed -i -e "s|<BACKEND_BUCKET_NAME>|${{ vars.BACKEND_BUCKET_NAME }}|g" \
63:           -e "s|<BACKEND_PREFIX>|${{ vars.BACKEND_PREFIX }}|g" \
64:           -e "s|<AWS_REGION>|${{ env.AWS_REGION }}|g" \
65:           backend.hcl
66:           echo "Created backend.hcl:"
67:           cat backend.hcl
68:       - name: Update variables.tfvars
69:         run: |
70:           sed -i "s|^env[[:space:]]*=.*|env = \"${{ inputs.environment }}\"|" variables.tfvars
71:           sed -i "s|^region[[:space:]]*=.*|region = \"${{ env.AWS_REGION }}\"|" variables.tfvars
72:           # Set deployment account role ARN based on environment
73:           DEPLOYMENT_ROLE_ARN="${{ inputs.environment == 'prod' && secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN || secrets.AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN }}"
74:           if ! grep -q "^deployment_account_role_arn" variables.tfvars; then
75:             echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> variables.tfvars
76:           else
77:             sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" variables.tfvars
78:           fi
79:           # Set ExternalId for cross-account role assumption security
80:           EXTERNAL_ID="${{ secrets.AWS_ASSUME_EXTERNAL_ID }}"
81:           if ! grep -q "^deployment_account_external_id" variables.tfvars; then
82:             echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> variables.tfvars
83:           else
84:             sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" variables.tfvars
85:           fi
86:           echo "Updated variables.tfvars:"
87:           cat variables.tfvars
88:       - name: Terraform init
89:         run: terraform init -backend-config=backend.hcl
90:       - name: Terraform workspace
91:         run: |
92:           WORKSPACE="${{ env.AWS_REGION }}-${{ inputs.environment }}"
93:           terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE
94:       - name: Terraform validate
95:         run: terraform validate
96:       - name: Terraform plan destroy
97:         run: terraform plan -var-file="variables.tfvars" -destroy -out terraform.tfplan
98:       - name: Destroy backend infrastructure
99:         run: terraform apply -auto-approve terraform.tfplan
```

## File: .github/workflows/backend_infra_provisioning.yaml
```yaml
  1: name: Backend Infra Provisioning
  2: on:
  3:   workflow_dispatch:
  4:     inputs:
  5:       region:
  6:         description: 'Select AWS Region'
  7:         required: true
  8:         type: choice
  9:         default: 'us-east-1: N. Virginia'
 10:         options:
 11:           - 'us-east-1: N. Virginia'
 12:           - 'us-east-2: Ohio'
 13:       environment:
 14:         description: 'Select Environment'
 15:         required: true
 16:         type: choice
 17:         default: prod
 18:         options:
 19:           - prod
 20:           - dev
 21: jobs:
 22:   SetRegion:
 23:     runs-on: ubuntu-latest
 24:     permissions:
 25:       contents: read
 26:     outputs:
 27:       region_code: ${{ steps.set_region.outputs.region_code }}
 28:     steps:
 29:       - name: Set Region
 30:         id: set_region
 31:         run: |
 32:           SELECTED_REGION="${{ inputs.region }}"
 33:           echo "region_code=${SELECTED_REGION%%:*}" >> $GITHUB_OUTPUT
 34:   InfraProvision:
 35:     runs-on: ubuntu-latest
 36:     needs:
 37:       - SetRegion
 38:     permissions:
 39:       contents: write
 40:       actions: write
 41:       id-token: write
 42:     env:
 43:       AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
 44:     defaults:
 45:       run:
 46:         working-directory: ./backend_infra
 47:     steps:
 48:       - name: Checkout the repo code
 49:         uses: actions/checkout@v4
 50:       - name: Setup terraform
 51:         uses: hashicorp/setup-terraform@v3
 52:         with:
 53:           terraform_version: 1.14.0
 54:       - name: Configure AWS credentials (State Account)
 55:         uses: aws-actions/configure-aws-credentials@v4
 56:         with:
 57:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
 58:           role-session-name: GitHubActions-BackendInfraProvision
 59:           aws-region: ${{ env.AWS_REGION }}
 60:       - name: Create backend.hcl from placeholder
 61:         run: |
 62:           cp tfstate-backend-values-template.hcl backend.hcl
 63:           sed -i -e "s|<BACKEND_BUCKET_NAME>|${{ vars.BACKEND_BUCKET_NAME }}|g" \
 64:           -e "s|<BACKEND_PREFIX>|${{ vars.BACKEND_PREFIX }}|g" \
 65:           -e "s|<AWS_REGION>|${{ env.AWS_REGION }}|g" \
 66:           backend.hcl
 67:           echo "Created backend.hcl:"
 68:           cat backend.hcl
 69:       - name: Update variables.tfvars
 70:         run: |
 71:           sed -i "s|^env[[:space:]]*=.*|env = \"${{ inputs.environment }}\"|" variables.tfvars
 72:           sed -i "s|^region[[:space:]]*=.*|region = \"${{ env.AWS_REGION }}\"|" variables.tfvars
 73:           # Set deployment account role ARN based on environment
 74:           DEPLOYMENT_ROLE_ARN="${{ inputs.environment == 'prod' && secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN || secrets.AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN }}"
 75:           if ! grep -q "^deployment_account_role_arn" variables.tfvars; then
 76:             echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> variables.tfvars
 77:           else
 78:             sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" variables.tfvars
 79:           fi
 80:           # Set ExternalId for cross-account role assumption security
 81:           EXTERNAL_ID="${{ secrets.AWS_ASSUME_EXTERNAL_ID }}"
 82:           if ! grep -q "^deployment_account_external_id" variables.tfvars; then
 83:             echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> variables.tfvars
 84:           else
 85:             sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" variables.tfvars
 86:           fi
 87:           echo "Updated variables.tfvars:"
 88:           cat variables.tfvars
 89:       - name: Terraform init
 90:         run: terraform init -backend-config=backend.hcl
 91:       - name: Terraform workspace
 92:         run: |
 93:           WORKSPACE="${{ env.AWS_REGION }}-${{ inputs.environment }}"
 94:           terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE
 95:       - name: Terraform validate
 96:         run: terraform validate
 97:       - name: Terraform plan
 98:         run: terraform plan -var-file="variables.tfvars" -out terraform.tfplan
 99:       - name: Provision backend infrastructure
100:         run: terraform apply -auto-approve terraform.tfplan
```

## File: application/modules/openldap/main.tf
```hcl
  1: locals {
  2:   # Determine values template path
  3:   values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/openldap-values.tpl.yaml"
  4:
  5:   openldap_values = templatefile(
  6:     local.values_template_path,
  7:     {
  8:       storage_class_name   = var.storage_class_name
  9:       openldap_ldap_domain = var.openldap_ldap_domain
 10:       openldap_secret_name = var.openldap_secret_name
 11:       app_name             = var.app_name
 12:       # ECR image configuration
 13:       ecr_registry       = var.ecr_registry
 14:       ecr_repository     = var.ecr_repository
 15:       openldap_image_tag = var.openldap_image_tag
 16:       # ALB configuration - IngressClassParams handles scheme and ipAddressType
 17:       ingress_class_name     = var.use_alb && var.ingress_class_name != null ? var.ingress_class_name : "alb"
 18:       alb_load_balancer_name = var.alb_load_balancer_name
 19:       acm_cert_arn           = var.acm_cert_arn
 20:       phpldapadmin_host      = var.phpldapadmin_host
 21:       ltb_passwd_host        = var.ltb_passwd_host
 22:       # Per-Ingress annotations still needed for grouping, TLS, ports, etc.
 23:       alb_target_type = var.alb_target_type
 24:       alb_ssl_policy  = var.alb_ssl_policy
 25:     }
 26:   )
 27: }
 28:
 29: # Create namespace for OpenLDAP
 30: resource "kubernetes_namespace" "openldap" {
 31:   metadata {
 32:     name = var.namespace
 33:
 34:     labels = {
 35:       name        = var.namespace
 36:       environment = var.env
 37:       managed-by  = "terraform"
 38:     }
 39:   }
 40:
 41:   lifecycle {
 42:     # Ignore changes to labels that might be modified by ArgoCD, Helm, or other controllers
 43:     ignore_changes = [
 44:       metadata[0].labels,
 45:       metadata[0].annotations,
 46:     ]
 47:   }
 48: }
 49:
 50: # Create Kubernetes secret for OpenLDAP passwords
 51: # Passwords are sourced from GitHub Secrets via TF_VAR_openldap_admin_password and TF_VAR_openldap_config_password
 52: resource "kubernetes_secret" "openldap_passwords" {
 53:   metadata {
 54:     name      = var.openldap_secret_name
 55:     namespace = kubernetes_namespace.openldap.metadata[0].name
 56:
 57:     labels = {
 58:       app         = "openldap"
 59:       environment = var.env
 60:       managed-by  = "terraform"
 61:     }
 62:   }
 63:
 64:   data = {
 65:     "LDAP_ADMIN_PASSWORD"        = var.openldap_admin_password
 66:     "LDAP_CONFIG_ADMIN_PASSWORD" = var.openldap_config_password
 67:   }
 68:
 69:   type = "Opaque"
 70:
 71:   lifecycle {
 72:     # Ignore changes to labels/annotations that might be modified by ArgoCD, Helm, or other controllers
 73:     # This prevents Terraform from trying to recreate the secret if it's modified externally
 74:     ignore_changes = [
 75:       metadata[0].labels,
 76:       metadata[0].annotations,
 77:     ]
 78:     # Create before destroy to avoid downtime if secret needs to be recreated
 79:     create_before_destroy = true
 80:   }
 81:
 82:   depends_on = [kubernetes_namespace.openldap]
 83: }
 84:
 85: # Helm release for OpenLDAP Stack HA
 86: resource "helm_release" "openldap" {
 87:   name       = var.helm_release_name
 88:   repository = var.helm_chart_repository
 89:   chart      = var.helm_chart_name
 90:   version    = var.helm_chart_version
 91:
 92:   namespace        = kubernetes_namespace.openldap.metadata[0].name
 93:   create_namespace = false
 94:
 95:   atomic          = true
 96:   cleanup_on_fail = true
 97:   # Force recreation on configuration changes
 98:   recreate_pods   = true
 99:   force_update    = true
100:   wait            = true
101:   wait_for_jobs   = true
102:   upgrade_install = true
103:   # 5 minute timeout as requested
104:   timeout = 300 # 5 minutes in seconds
105:
106:   # Allow replacement if name conflict occurs
107:   replace = true
108:
109:   values = [local.openldap_values]
110:
111:   depends_on = [
112:     kubernetes_namespace.openldap,
113:     kubernetes_secret.openldap_passwords,
114:   ]
115: }
116:
117: # Create Network Policies for secure internal cluster communication
118: # Generic policies: Any service can communicate with any service, but only on secure ports
119: module "network_policies" {
120:   source = "../network-policies"
121:
122:   count = var.enable_network_policies ? 1 : 0
123:
124:   namespace = var.namespace
125:
126:   depends_on = [helm_release.openldap]
127: }
128:
129: # Get Ingress resources created by Helm chart to extract ALB DNS names
130: data "kubernetes_ingress_v1" "phpldapadmin" {
131:   metadata {
132:     name      = "${var.helm_release_name}-phpldapadmin"
133:     namespace = var.namespace
134:   }
135:
136:   depends_on = [helm_release.openldap]
137: }
138:
139: data "kubernetes_ingress_v1" "ltb_passwd" {
140:   metadata {
141:     name      = "${var.helm_release_name}-ltb-passwd"
142:     namespace = var.namespace
143:   }
144:
145:   depends_on = [helm_release.openldap]
146: }
```

## File: application/modules/redis/main.tf
```hcl
  1: /**
  2:  * Redis Module
  3:  *
  4:  * Deploys Redis using the Bitnami Helm chart for SMS OTP code storage
  5:  * in the LDAP 2FA application. Provides TTL-based automatic expiration
  6:  * and shared state across backend replicas.
  7:  */
  8:
  9: locals {
 10:   name = "${var.prefix}-${var.region}-redis-${var.env}"
 11:
 12:   # Determine values template path
 13:   values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/redis-values.tpl.yaml"
 14:
 15:   # Build Redis Helm values using templatefile
 16:   # Note: We pass the secret name variable (not resource) to avoid circular dependency
 17:   # The secret resource is created separately with the same name
 18:   redis_values = templatefile(
 19:     local.values_template_path,
 20:     {
 21:       secret_name              = var.secret_name
 22:       persistence_enabled      = var.persistence_enabled
 23:       storage_class_name       = var.storage_class_name
 24:       storage_size             = var.storage_size
 25:       resources_requests_cpu   = var.resources.requests.cpu
 26:       resources_requests_memory = var.resources.requests.memory
 27:       resources_limits_cpu     = var.resources.limits.cpu
 28:       resources_limits_memory  = var.resources.limits.memory
 29:       metrics_enabled          = var.metrics_enabled
 30:       ecr_registry             = var.ecr_registry
 31:       ecr_repository           = var.ecr_repository
 32:       image_tag                = var.image_tag
 33:     }
 34:   )
 35: }
 36:
 37: # Create namespace for Redis
 38: resource "kubernetes_namespace" "redis" {
 39:   count = var.enable_redis ? 1 : 0
 40:
 41:   metadata {
 42:     name = var.namespace
 43:
 44:     labels = {
 45:       name        = var.namespace
 46:       environment = var.env
 47:       managed-by  = "terraform"
 48:     }
 49:   }
 50:
 51:   lifecycle {
 52:     ignore_changes = [metadata[0].labels]
 53:   }
 54: }
 55:
 56: # Create Kubernetes secret for Redis password
 57: # Password is sourced from GitHub Secrets via TF_VAR_redis_password
 58: resource "kubernetes_secret" "redis_password" {
 59:   count = var.enable_redis ? 1 : 0
 60:
 61:   metadata {
 62:     name      = var.secret_name
 63:     namespace = kubernetes_namespace.redis[0].metadata[0].name
 64:
 65:     labels = {
 66:       app         = local.name
 67:       environment = var.env
 68:       managed-by  = "terraform"
 69:     }
 70:   }
 71:
 72:   data = {
 73:     "redis-password" = var.redis_password
 74:   }
 75:
 76:   type = "Opaque"
 77: }
 78:
 79: # Redis Helm release using Bitnami chart
 80: resource "helm_release" "redis" {
 81:   count = var.enable_redis ? 1 : 0
 82:
 83:   name       = local.name
 84:   repository = "https://charts.bitnami.com/bitnami"
 85:   chart      = "redis"
 86:   version    = var.chart_version
 87:   namespace  = kubernetes_namespace.redis[0].metadata[0].name
 88:
 89:   atomic          = true
 90:   cleanup_on_fail = true
 91:   recreate_pods   = true
 92:   force_update    = true
 93:   wait            = true
 94:   wait_for_jobs   = true
 95:   timeout         = 600 # Reduced from 1200 to 600 seconds (10 min) for faster debugging
 96:   upgrade_install = true
 97:
 98:   # Allow replacement if name conflict occurs
 99:   replace = true
100:
101:   # Use templatefile to inject values into the official Bitnami Redis Helm chart values template
102:   # Note: The secret name is passed to the template, and the secret resource is created separately
103:   values = [local.redis_values]
104:
105:   depends_on = [
106:     kubernetes_namespace.redis[0],
107:     kubernetes_secret.redis_password[0],
108:   ]
109: }
110:
111: # Network Policy: Allow backend pods to connect to Redis
112: # This policy restricts Redis access to only the backend namespace/pods
113: resource "kubernetes_network_policy_v1" "allow_backend_to_redis" {
114:   count = var.enable_redis ? 1 : 0
115:
116:   metadata {
117:     name      = "allow-backend-to-redis"
118:     namespace = kubernetes_namespace.redis[0].metadata[0].name
119:
120:     labels = {
121:       app         = local.name
122:       environment = var.env
123:       managed-by  = "terraform"
124:     }
125:   }
126:
127:   spec {
128:     # Apply to Redis pods
129:     pod_selector {
130:       match_labels = {
131:         "app.kubernetes.io/name" = "redis"
132:       }
133:     }
134:
135:     policy_types = ["Ingress"]
136:
137:     # Allow ingress from backend namespace on Redis port
138:     ingress {
139:       from {
140:         namespace_selector {
141:           match_labels = {
142:             name = var.backend_namespace
143:           }
144:         }
145:         pod_selector {
146:           match_labels = {
147:             "app.kubernetes.io/name" = "ldap-2fa-backend"
148:           }
149:         }
150:       }
151:       ports {
152:         protocol = "TCP"
153:         port     = 6379
154:       }
155:     }
156:
157:     # Allow ingress from within the Redis namespace (for Redis probes, etc.)
158:     ingress {
159:       from {
160:         pod_selector {}
161:       }
162:       ports {
163:         protocol = "TCP"
164:         port     = 6379
165:       }
166:     }
167:   }
168:
169:   depends_on = [
170:     kubernetes_namespace.redis[0],
171:     helm_release.redis[0],
172:   ]
173: }
```

## File: application/providers.tf
```hcl
  1: terraform {
  2:   required_providers {
  3:     aws = {
  4:       source  = "hashicorp/aws"
  5:       version = ">= 6.21.0"
  6:     }
  7:     kubernetes = {
  8:       source  = "hashicorp/kubernetes"
  9:       version = "~> 2.0"
 10:     }
 11:     helm = {
 12:       source  = "hashicorp/helm"
 13:       version = "~> 2.0"
 14:     }
 15:     time = {
 16:       source  = "hashicorp/time"
 17:       version = "~> 0.9"
 18:     }
 19:   }
 20:
 21:   backend "s3" {
 22:     # Backend configuration provided via backend.hcl file
 23:     encrypt      = true
 24:     use_lockfile = true
 25:   }
 26:
 27:   required_version = "~> 1.14.0"
 28: }
 29:
 30: provider "aws" {
 31:   region = var.region
 32:
 33:   # Assume role in deployment account (Account B) if role ARN is provided
 34:   # This allows GitHub Actions to authenticate with Account A (for state)
 35:   # while Terraform provider uses Account B (for resource deployment)
 36:   # ExternalId is required for security when assuming cross-account roles
 37:   dynamic "assume_role" {
 38:     for_each = var.deployment_account_role_arn != null ? [1] : []
 39:     content {
 40:       role_arn    = var.deployment_account_role_arn
 41:       external_id = var.deployment_account_external_id
 42:     }
 43:   }
 44: }
 45:
 46: # Provider alias for state account (where Route53 hosted zone and Private CA reside)
 47: provider "aws" {
 48:   alias  = "state_account"
 49:   region = var.region
 50:
 51:   # Assume role in state account if role ARN is provided
 52:   # This allows querying Route53 hosted zones from the state account
 53:   # while deploying resources to the deployment account
 54:   # Note: ACM certificates are in deployment accounts (issued from Private CA in State Account)
 55:   # Note: ExternalId is not used for state account role assumption (by design)
 56:   dynamic "assume_role" {
 57:     for_each = var.state_account_role_arn != null ? [1] : []
 58:     content {
 59:       role_arn = var.state_account_role_arn
 60:     }
 61:   }
 62: }
 63:
 64: # Read backend.hcl to get bucket and region for remote state
 65: data "local_file" "backend_config" {
 66:   filename = "${path.module}/backend.hcl"
 67: }
 68:
 69: locals {
 70:   # Parse backend.hcl to extract bucket, and region
 71:   # backend.hcl format: bucket = "value", region = "value"
 72:   # If backend.hcl doesn't exist, these will be null and remote state won't be used
 73:   backend_bucket = try(
 74:     regex("bucket\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_config.content)[0],
 75:     null
 76:   )
 77:   backend_key = "backend_state/terraform.tfstate" # backend_infra state key
 78:   backend_region = try(
 79:     regex("region\\s*=\\s*\"([^\"]+)\"", data.local_file.backend_config.content)[0],
 80:     var.region
 81:   )
 82:
 83:   # Determine workspace name: use provided variable or derive from region and env
 84:   # This matches the workspace naming convention used in scripts: ${region}-${env}
 85:   # The workspace argument in terraform_remote_state will handle the workspace prefix automatically
 86:   terraform_workspace = coalesce(
 87:     var.terraform_workspace,
 88:     "${var.region}-${var.env}"
 89:   )
 90: }
 91:
 92: # Retrieve cluster name from backend_infra state
 93: # Uses the workspace argument to automatically handle workspace-prefixed state keys
 94: # Reference: https://developer.hashicorp.com/terraform/language/state/remote-state-data
 95: data "terraform_remote_state" "backend_infra" {
 96:   count   = local.backend_bucket != null ? 1 : 0
 97:   backend = "s3"
 98:
 99:   # Use workspace argument to specify which workspace state to access
100:   # For S3 backend: "default" workspace uses base key, other workspaces use env:/${workspace}/${key}
101:   # Always pass the workspace value explicitly to ensure correct state lookup
102:   workspace = local.terraform_workspace
103:
104:   config = merge(
105:     {
106:       bucket = local.backend_bucket
107:       key    = local.backend_key
108:       region = local.backend_region
109:     },
110:     # Add assume_role block to assume state account role when accessing remote state
111:     # This allows cross-account state access without requiring provider configuration
112:     # Note: Terraform 1.6.0+ requires assume_role block instead of top-level role_arn
113:     var.state_account_role_arn != null ? {
114:       assume_role = {
115:         role_arn = var.state_account_role_arn
116:       }
117:     } : {}
118:   )
119: }
120:
121: locals {
122:   # Get cluster name from remote state if available, otherwise use provided value or calculate it
123:   cluster_name = coalesce(
124:     try(data.terraform_remote_state.backend_infra[0].outputs.cluster_name, null),
125:     var.cluster_name,
126:     "${var.prefix}-${var.region}-${var.cluster_name_component}-${var.env}"
127:   )
128: }
129:
130: data "aws_eks_cluster" "cluster" {
131:   name = local.cluster_name
132: }
133:
134: data "aws_eks_cluster_auth" "cluster" {
135:   name = local.cluster_name
136: }
137:
138: provider "kubernetes" {
139:   host                   = data.aws_eks_cluster.cluster.endpoint
140:   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
141:   token                  = data.aws_eks_cluster_auth.cluster.token
142: }
143:
144: provider "helm" {
145:   kubernetes {
146:     host                   = data.aws_eks_cluster.cluster.endpoint
147:     cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
148:     token                  = data.aws_eks_cluster_auth.cluster.token
149:   }
150: }
```

## File: backend_infra/outputs.tf
```hcl
  1: output "aws_account" {
  2:   description = "The AWS Account ID"
  3:   value       = local.current_account
  4: }
  5:
  6: output "region" {
  7:   description = "The AWS region"
  8:   value       = var.region
  9: }
 10:
 11: output "env" {
 12:   description = "The Environment e.g. prod"
 13:   value       = var.env
 14: }
 15:
 16: output "prefix" {
 17:   description = "The prefix to all names"
 18:   value       = var.prefix
 19: }
 20:
 21: ###################### VPC ######################
 22: output "vpc_id" {
 23:   description = "The VPC's ID"
 24:   value       = module.vpc.vpc_id
 25: }
 26:
 27: output "default_security_group_id" {
 28:   description = "The default security group for the VPC"
 29:   value       = module.vpc.default_security_group_id
 30: }
 31:
 32: output "public_subnets" {
 33:   description = "The VPC's associated public subnets."
 34:   value       = module.vpc.public_subnets
 35: }
 36:
 37: output "private_subnets" {
 38:   description = "The VPC's associated private subnets."
 39:   value       = module.vpc.private_subnets
 40: }
 41:
 42: output "igw_id" {
 43:   description = "The Internet Gateway's ID"
 44:   value       = module.vpc.igw_id
 45: }
 46:
 47: ########## Kubernetes Cluster ##############
 48:
 49: output "cluster_name" {
 50:   description = "The Name of Kubernetes Cluster"
 51:   value       = local.cluster_name
 52: }
 53:
 54: output "cluster_endpoint" {
 55:   description = "EKS Cluster API Endpoint"
 56:   value       = module.eks.cluster_endpoint
 57: }
 58:
 59: output "cluster_arn" {
 60:   description = "EKS Cluster ARN"
 61:   value       = module.eks.cluster_arn
 62: }
 63:
 64: output "oidc_provider_arn" {
 65:   description = "OIDC provider ARN for IRSA"
 66:   value       = module.eks.oidc_provider_arn
 67: }
 68:
 69: output "oidc_provider_url" {
 70:   description = "OIDC provider URL (without https://)"
 71:   value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
 72: }
 73:
 74: ##################### VPC Endpoints ##########################
 75: output "vpc_endpoint_sg_id" {
 76:   description = "Security group ID for VPC endpoints"
 77:   value       = module.endpoints.vpc_endpoint_sg_id
 78: }
 79:
 80: output "vpc_endpoint_ssm_id" {
 81:   description = "VPC endpoint ID for SSM"
 82:   value       = module.endpoints.vpc_endpoint_ssm_id
 83: }
 84:
 85: output "vpc_endpoint_ssmmessages_id" {
 86:   description = "VPC endpoint ID for SSM Messages"
 87:   value       = module.endpoints.vpc_endpoint_ssmmessages_id
 88: }
 89:
 90: output "vpc_endpoint_ec2messages_id" {
 91:   description = "VPC endpoint ID for EC2 Messages"
 92:   value       = module.endpoints.vpc_endpoint_ec2messages_id
 93: }
 94:
 95: output "vpc_endpoint_ids" {
 96:   description = "List of all VPC endpoint IDs"
 97:   value       = module.endpoints.vpc_endpoint_ids
 98: }
 99:
100: output "vpc_endpoint_sts_id" {
101:   description = "VPC endpoint ID for STS (IRSA)"
102:   value       = module.endpoints.vpc_endpoint_sts_id
103: }
104:
105: output "vpc_endpoint_sns_id" {
106:   description = "VPC endpoint ID for SNS (SMS 2FA)"
107:   value       = module.endpoints.vpc_endpoint_sns_id
108: }
109:
110: ##################### ECR ##########################
111: output "ecr_name" {
112:   description = "ECR repository name"
113:   value       = module.ecr.ecr_name
114: }
115:
116: output "ecr_arn" {
117:   description = "ECR repository ARN"
118:   value       = module.ecr.ecr_arn
119: }
120:
121: output "ecr_url" {
122:   description = "ECR repository URL"
123:   value       = module.ecr.ecr_url
124: }
125:
126: output "ecr_registry" {
127:   description = "ECR registry URL (e.g., account.dkr.ecr.region.amazonaws.com)"
128:   value       = module.ecr.ecr_registry
129: }
130:
131: output "ecr_repository" {
132:   description = "ECR repository name (without registry prefix)"
133:   value       = module.ecr.ecr_repository
134: }
135:
136: ##################### EBS ##########################
137: # output "ebs_pvc_name" {
138: #   value = module.ebs.ebs_pvc_name
139: # }
140: #
141: # output "ebs_storage_class_name" {
142: #   value = module.ebs.ebs_storage_class_name
143: # }
```

## File: backend_infra/setup-backend.sh
```bash
  1: #!/bin/bash
  2: # Script to configure backend.hcl and variables.tfvars with user-selected region and environment
  3: # and run Terraform commands
  4: # Usage: ./setup-backend.sh
  5: set -euo pipefail
  6: # Clean up any existing AWS credentials from environment to prevent conflicts
  7: # This ensures the script starts with a clean slate and uses the correct credentials
  8: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
  9: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 10: unset AWS_SESSION_TOKEN 2>/dev/null || true
 11: unset AWS_PROFILE 2>/dev/null || true
 12: # Colors for output
 13: RED='\033[0;31m'
 14: GREEN='\033[0;32m'
 15: YELLOW='\033[1;33m'
 16: NC='\033[0m' # No Color
 17: # Configuration
 18: PLACEHOLDER_FILE="tfstate-backend-values-template.hcl"
 19: BACKEND_FILE="backend.hcl"
 20: VARIABLES_FILE="variables.tfvars"
 21: # Function to print colored messages
 22: print_error() {
 23:     echo -e "${RED}ERROR:${NC} $1" >&2
 24: }
 25: print_success() {
 26:     echo -e "${GREEN}SUCCESS:${NC} $1"
 27: }
 28: print_info() {
 29:     echo -e "${YELLOW}INFO:${NC} $1"
 30: }
 31: # Check if AWS CLI is installed
 32: if ! command -v aws &> /dev/null; then
 33:     print_error "AWS CLI is not installed."
 34:     echo "Please install it from: https://aws.amazon.com/cli/"
 35:     exit 1
 36: fi
 37: # Check if Terraform is installed
 38: if ! command -v terraform &> /dev/null; then
 39:     print_error "Terraform is not installed."
 40:     echo "Please install it from: https://www.terraform.io/downloads"
 41:     exit 1
 42: fi
 43: # Check if GitHub CLI is installed
 44: if ! command -v gh &> /dev/null; then
 45:     print_error "GitHub CLI (gh) is not installed."
 46:     echo "Please install it from: https://cli.github.com/"
 47:     exit 1
 48: fi
 49: # Check if user is authenticated with GitHub CLI
 50: if ! gh auth status &> /dev/null; then
 51:     print_error "Not authenticated with GitHub CLI."
 52:     echo "Please run: gh auth login"
 53:     exit 1
 54: fi
 55: # Check if jq is installed (required for gh --jq flag)
 56: if ! command -v jq &> /dev/null; then
 57:     print_error "jq is not installed."
 58:     echo "Please install it:"
 59:     echo "  macOS: brew install jq"
 60:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 61:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 62:     exit 1
 63: fi
 64: # Get repository owner and name
 65: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 66: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 67: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 68:     print_error "Could not determine repository information."
 69:     echo "Please ensure you're in a git repository and have proper permissions."
 70:     exit 1
 71: fi
 72: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 73: # Function to get repository variable using GitHub CLI
 74: get_repo_variable() {
 75:     local var_name=$1
 76:     local value
 77:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 78:     if [ -z "$value" ]; then
 79:         print_error "Repository variable '${var_name}' not found or not accessible."
 80:         return 1
 81:     fi
 82:     echo "$value"
 83: }
 84: # Function to retrieve secret from AWS Secrets Manager
 85: get_aws_secret() {
 86:     local secret_name=$1
 87:     local secret_json
 88:     local exit_code
 89:     # Retrieve secret from AWS Secrets Manager
 90:     # Use AWS_REGION if set, otherwise default to us-east-1
 91:     secret_json=$(aws secretsmanager get-secret-value \
 92:         --secret-id "$secret_name" \
 93:         --region "${AWS_REGION:-us-east-1}" \
 94:         --query SecretString \
 95:         --output text 2>&1)
 96:     # Capture exit code before checking
 97:     exit_code=$?
 98:     # Validate secret retrieval
 99:     if [ $exit_code -ne 0 ]; then
100:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
101:         print_error "Error: $secret_json"
102:         return 1
103:     fi
104:     # Validate JSON can be parsed
105:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
106:         print_error "Secret '${secret_name}' contains invalid JSON"
107:         return 1
108:     fi
109:     echo "$secret_json"
110: }
111: # Function to retrieve plain text secret from AWS Secrets Manager
112: get_aws_plaintext_secret() {
113:     local secret_name=$1
114:     local secret_value
115:     local exit_code
116:     # Retrieve secret from AWS Secrets Manager
117:     # Use AWS_REGION if set, otherwise default to us-east-1
118:     secret_value=$(aws secretsmanager get-secret-value \
119:         --secret-id "$secret_name" \
120:         --region "${AWS_REGION:-us-east-1}" \
121:         --query SecretString \
122:         --output text 2>&1)
123:     # Capture exit code before checking
124:     exit_code=$?
125:     # Validate secret retrieval
126:     if [ $exit_code -ne 0 ]; then
127:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
128:         print_error "Error: $secret_value"
129:         return 1
130:     fi
131:     # Check if secret value is empty
132:     if [ -z "$secret_value" ]; then
133:         print_error "Secret '${secret_name}' is empty"
134:         return 1
135:     fi
136:     echo "$secret_value"
137: }
138: # Function to get key value from secret JSON
139: get_secret_key_value() {
140:     local secret_json=$1
141:     local key_name=$2
142:     local value
143:     # Validate JSON can be parsed
144:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
145:         print_error "Invalid JSON provided to get_secret_key_value"
146:         return 1
147:     fi
148:     # Extract key value using jq
149:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
150:     # Check if jq command succeeded
151:     if [ $? -ne 0 ]; then
152:         print_error "Failed to parse JSON or extract key '${key_name}'"
153:         return 1
154:     fi
155:     # Check if key exists (jq returns "null" for non-existent keys)
156:     if [ "$value" = "null" ] || [ -z "$value" ]; then
157:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
158:         return 1
159:     fi
160:     echo "$value"
161: }
162: # Interactive prompts
163: echo ""
164: print_info "Select AWS Region:"
165: echo "1) us-east-1: N. Virginia (default)"
166: echo "2) us-east-2: Ohio"
167: read -p "Enter choice [1-2] (default: 1): " region_choice
168: case ${region_choice:-1} in
169:     1)
170:         SELECTED_REGION="us-east-1: N. Virginia"
171:         ;;
172:     2)
173:         SELECTED_REGION="us-east-2: Ohio"
174:         ;;
175:     *)
176:         print_error "Invalid choice. Using default: us-east-1: N. Virginia"
177:         SELECTED_REGION="us-east-1: N. Virginia"
178:         ;;
179: esac
180: # Extract region code (everything before the colon)
181: AWS_REGION="${SELECTED_REGION%%:*}"
182: print_success "Selected region: ${SELECTED_REGION} (${AWS_REGION})"
183: echo ""
184: print_info "Select Environment:"
185: echo "1) prod (default)"
186: echo "2) dev"
187: read -p "Enter choice [1-2] (default: 1): " env_choice
188: case ${env_choice:-1} in
189:     1)
190:         ENVIRONMENT="prod"
191:         ;;
192:     2)
193:         ENVIRONMENT="dev"
194:         ;;
195:     *)
196:         print_error "Invalid choice. Using default: prod"
197:         ENVIRONMENT="prod"
198:         ;;
199: esac
200: print_success "Selected environment: ${ENVIRONMENT}"
201: echo ""
202: # Retrieve all role ARNs from AWS Secrets Manager in a single call
203: # This minimizes AWS CLI calls by fetching all required role ARNs at once
204: print_info "Retrieving role ARNs from AWS Secrets Manager..."
205: SECRET_JSON=$(get_aws_secret "github-role" || echo "")
206: if [ -z "$SECRET_JSON" ]; then
207:     print_error "Failed to retrieve secret from AWS Secrets Manager"
208:     exit 1
209: fi
210: # Extract STATE_ACCOUNT_ROLE_ARN for backend state operations
211: STATE_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
212: if [ -z "$STATE_ROLE_ARN" ]; then
213:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
214:     exit 1
215: fi
216: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
217: # Determine which deployment account role ARN to use based on environment
218: if [ "$ENVIRONMENT" = "prod" ]; then
219:     DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
220: else
221:     DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
222: fi
223: # Extract deployment account role ARN for provider assume_role
224: DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
225: if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
226:     print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
227:     exit 1
228: fi
229: print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"
230: # Use STATE_ROLE_ARN for backend operations
231: ROLE_ARN="$STATE_ROLE_ARN"
232: print_info "Assuming role: $ROLE_ARN"
233: print_info "Region: $AWS_REGION"
234: # Assume the role
235: ROLE_SESSION_NAME="setup-backend-$(date +%s)"
236: # Assume role and capture output
237: ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
238:     --role-arn "$ROLE_ARN" \
239:     --role-session-name "$ROLE_SESSION_NAME" \
240:     --region "$AWS_REGION" 2>&1)
241: if [ $? -ne 0 ]; then
242:     print_error "Failed to assume role: $ASSUME_ROLE_OUTPUT"
243:     exit 1
244: fi
245: # Extract credentials from JSON output
246: # Try using jq if available (more reliable), otherwise use sed/grep
247: if command -v jq &> /dev/null; then
248:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
249:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
250:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')
251: else
252:     # Fallback: use sed for JSON parsing (works on both macOS and Linux)
253:     export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
254:     export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
255:     export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
256: fi
257: if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
258:     print_error "Failed to extract credentials from assume-role output."
259:     print_error "Output was: $ASSUME_ROLE_OUTPUT"
260:     exit 1
261: fi
262: print_success "Successfully assumed role"
263: # Verify the credentials work
264: CALLER_ARN=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
265: if [ $? -ne 0 ]; then
266:     print_error "Failed to verify assumed role credentials: $CALLER_ARN"
267:     exit 1
268: fi
269: print_info "Assumed role identity: $CALLER_ARN"
270: echo ""
271: # Retrieve ExternalId from AWS Secrets Manager (plain text secret)
272: # Must be retrieved after assuming role to have AWS credentials
273: print_info "Retrieving ExternalId from AWS Secrets Manager..."
274: EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
275: if [ -z "$EXTERNAL_ID" ]; then
276:     print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
277:     exit 1
278: fi
279: print_success "Retrieved ExternalId"
280: # Retrieve repository variables
281: print_info "Retrieving repository variables..."
282: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
283: print_success "Retrieved BACKEND_BUCKET_NAME"
284: BACKEND_PREFIX=$(get_repo_variable "BACKEND_PREFIX") || exit 1
285: print_success "Retrieved BACKEND_PREFIX"
286: # Check if backend.hcl already exists
287: if [ -f "$BACKEND_FILE" ]; then
288:     print_info "${BACKEND_FILE} already exists. Skipping creation."
289: else
290:     # Check if placeholder file exists
291:     if [ ! -f "$PLACEHOLDER_FILE" ]; then
292:         print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
293:         exit 1
294:     fi
295:     # Copy placeholder to backend file and replace placeholders
296:     print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."
297:     # Copy placeholder file to backend file
298:     cp "$PLACEHOLDER_FILE" "$BACKEND_FILE"
299:     # Replace placeholders (works on macOS and Linux)
300:     if [[ "$OSTYPE" == "darwin"* ]]; then
301:         # macOS sed requires -i '' for in-place editing
302:         sed -i '' "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
303:         sed -i '' "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
304:         sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
305:     else
306:         # Linux sed
307:         sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
308:         sed -i "s|<BACKEND_PREFIX>|${BACKEND_PREFIX}|g" "$BACKEND_FILE"
309:         sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
310:     fi
311:     print_success "Created ${BACKEND_FILE}"
312: fi
313: # Update variables.tfvars
314: print_info "Updating ${VARIABLES_FILE} with selected values..."
315: if [ ! -f "$VARIABLES_FILE" ]; then
316:     print_error "Variables file '${VARIABLES_FILE}' not found."
317:     exit 1
318: fi
319: # Update variables.tfvars (works on macOS and Linux)
320: if [[ "$OSTYPE" == "darwin"* ]]; then
321:     # macOS sed requires -i '' for in-place editing
322:     sed -i '' "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
323:     sed -i '' "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
324:     # Add or update deployment_account_role_arn
325:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
326:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
327:     else
328:         sed -i '' "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
329:     fi
330:     # Add or update deployment_account_external_id
331:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
332:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
333:     else
334:         sed -i '' "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
335:     fi
336: else
337:     # Linux sed
338:     sed -i "s|^env[[:space:]]*=.*|env                    = \"${ENVIRONMENT}\"|" "$VARIABLES_FILE"
339:     sed -i "s|^region[[:space:]]*=.*|region                 = \"${AWS_REGION}\"|" "$VARIABLES_FILE"
340:     # Add or update deployment_account_role_arn
341:     if ! grep -q "^deployment_account_role_arn" "$VARIABLES_FILE"; then
342:         echo "deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"" >> "$VARIABLES_FILE"
343:     else
344:         sed -i "s|^deployment_account_role_arn[[:space:]]*=.*|deployment_account_role_arn = \"${DEPLOYMENT_ROLE_ARN}\"|" "$VARIABLES_FILE"
345:     fi
346:     # Add or update deployment_account_external_id
347:     if ! grep -q "^deployment_account_external_id" "$VARIABLES_FILE"; then
348:         echo "deployment_account_external_id = \"${EXTERNAL_ID}\"" >> "$VARIABLES_FILE"
349:     else
350:         sed -i "s|^deployment_account_external_id[[:space:]]*=.*|deployment_account_external_id = \"${EXTERNAL_ID}\"|" "$VARIABLES_FILE"
351:     fi
352: fi
353: print_success "Updated ${VARIABLES_FILE}"
354: echo ""
355: print_success "Configuration files updated successfully!"
356: echo ""
357: print_info "Backend file: ${BACKEND_FILE}"
358: print_info "  - bucket: ${BUCKET_NAME}"
359: print_info "  - key: ${BACKEND_PREFIX}"
360: print_info "  - region: ${AWS_REGION}"
361: echo ""
362: print_info "Variables file: ${VARIABLES_FILE}"
363: print_info "  - env: ${ENVIRONMENT}"
364: print_info "  - region: ${AWS_REGION}"
365: echo ""
366: # Terraform workspace name
367: WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"
368: # Terraform init
369: print_info "Running terraform init with backend configuration..."
370: terraform init -backend-config="${BACKEND_FILE}"
371: # Terraform workspace
372: print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
373: terraform workspace select "${WORKSPACE_NAME}" || terraform workspace new "${WORKSPACE_NAME}"
374: # Terraform validate
375: print_info "Running terraform validate..."
376: terraform validate
377: # Terraform plan
378: print_info "Running terraform plan..."
379: terraform plan -var-file="${VARIABLES_FILE}" -out terraform.tfplan
380: # Terraform apply
381: print_info "Running terraform apply..."
382: terraform apply -auto-approve terraform.tfplan
383: echo ""
384: print_success "Script completed successfully!"
```

## File: backend_infra/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name added to all resources"
 13:   type        = string
 14: }
 15:
 16: variable "deployment_account_role_arn" {
 17:   description = "ARN of the IAM role to assume in the deployment account (Account B). Required when using GitHub Actions with multi-account setup."
 18:   type        = string
 19:   default     = null
 20:   nullable    = true
 21: }
 22:
 23: variable "deployment_account_external_id" {
 24:   description = "ExternalId for cross-account role assumption security. Required when assuming roles in deployment accounts. Must match the ExternalId configured in the deployment account role's Trust Relationship. Retrieved from AWS Secrets Manager (secret: 'external-id') for local deployment or GitHub secret (AWS_ASSUME_EXTERNAL_ID) for GitHub Actions."
 25:   type        = string
 26:   default     = null
 27:   nullable    = true
 28:   sensitive   = true
 29: }
 30:
 31: ###################### VPC #########################
 32:
 33: variable "vpc_name" {
 34:   description = "The name of the VPC"
 35:   type        = string
 36: }
 37:
 38: variable "vpc_cidr" {
 39:   description = "CIDR block for VPC"
 40:   type        = string
 41: }
 42:
 43: variable "igw_name" {
 44:   description = "The name of the Internet Gateway"
 45:   type        = string
 46: }
 47:
 48: variable "ngw_name" {
 49:   description = "The name of the NAT Gateway"
 50:   type        = string
 51: }
 52:
 53: variable "route_table_name" {
 54:   description = "The name of the route table"
 55:   type        = string
 56: }
 57:
 58: ############ Kubernetes Cluster #################
 59:
 60: variable "k8s_version" {
 61:   description = "The version of Kubernetes to deploy."
 62:   type        = string
 63: }
 64:
 65: variable "cluster_name" {
 66:   description = "The Name of Kubernetes Cluster"
 67:   type        = string
 68: }
 69:
 70: ##################### Endpoints ##########################
 71:
 72: variable "endpoint_sg_name" {
 73:   description = "The name of the endpoint security group"
 74:   type        = string
 75: }
 76:
 77: variable "enable_sts_endpoint" {
 78:   description = "Whether to create STS VPC endpoint (required for IRSA)"
 79:   type        = bool
 80:   default     = true
 81: }
 82:
 83: variable "enable_sns_endpoint" {
 84:   description = "Whether to create SNS VPC endpoint (required for SMS 2FA)"
 85:   type        = bool
 86:   default     = false
 87: }
 88:
 89: ##################### EBS ##########################
 90:
 91: variable "ebs_name" {
 92:   description = "The name of the EBS"
 93:   type        = string
 94: }
 95:
 96: variable "ebs_claim_name" {
 97:   description = "The name of the EBS claim"
 98:   type        = string
 99: }
100:
101: ##################### ECR ##########################
102:
103: variable "ecr_name" {
104:   description = "The name of the ECR"
105:   type        = string
106: }
107:
108: variable "image_tag_mutability" {
109:   description = "The value that determines if the image is overridable"
110:   type        = string
111: }
112:
113: variable "ecr_lifecycle_policy" {}
```

## File: .github/workflows/application_infra_destroying.yaml
```yaml
  1: name: Application Infra Destroying
  2: # Required GitHub Repository Secrets:
  3: # - AWS_STATE_ACCOUNT_ROLE_ARN: IAM role ARN for backend state operations
  4: # - AWS_PRODUCTION_ACCOUNT_ROLE_ARN: IAM role ARN for production deployments
  5: # - AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN: IAM role ARN for development deployments
  6: # - AWS_ASSUME_EXTERNAL_ID: ExternalId for cross-account role assumption security
  7: # - TF_VAR_OPENLDAP_ADMIN_PASSWORD: OpenLDAP admin password
  8: # - TF_VAR_OPENLDAP_CONFIG_PASSWORD: OpenLDAP config password
  9: # - TF_VAR_POSTGRESQL_PASSWORD: PostgreSQL database password
 10: # - TF_VAR_REDIS_PASSWORD: Redis password for SMS OTP storage
 11: #
 12: # Note: GitHub workflows use repository secrets, while bash scripts use AWS Secrets Manager.
 13: # The secrets listed above must be configured in GitHub repository settings.
 14: on:
 15:   workflow_dispatch:
 16:     inputs:
 17:       region:
 18:         description: 'Select AWS Region'
 19:         required: true
 20:         type: choice
 21:         default: 'us-east-1: N. Virginia'
 22:         options:
 23:           - 'us-east-1: N. Virginia'
 24:           - 'us-east-2: Ohio'
 25:       environment:
 26:         description: 'Select Environment'
 27:         required: true
 28:         type: choice
 29:         default: prod
 30:         options:
 31:           - prod
 32:           - dev
 33: jobs:
 34:   SetRegion:
 35:     runs-on: ubuntu-latest
 36:     permissions:
 37:       contents: read
 38:     outputs:
 39:       region_code: ${{ steps.set_region.outputs.region_code }}
 40:     steps:
 41:       - name: Set Region
 42:         id: set_region
 43:         run: |
 44:           SELECTED_REGION="${{ inputs.region }}"
 45:           echo "region_code=${SELECTED_REGION%%:*}" >> $GITHUB_OUTPUT
 46:   InfraDestroy:
 47:     runs-on: ubuntu-latest
 48:     needs:
 49:       - SetRegion
 50:     permissions:
 51:       contents: write
 52:       actions: write
 53:       id-token: write
 54:     env:
 55:       AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
 56:       # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
 57:       # Secrets in GitHub remain uppercase, but environment variables must be lowercase
 58:       TF_VAR_openldap_admin_password: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
 59:       TF_VAR_openldap_config_password: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
 60:       # Redis password for SMS OTP storage
 61:       TF_VAR_redis_password: ${{ secrets.TF_VAR_REDIS_PASSWORD }}
 62:       # PostgreSQL password for User management database
 63:       TF_VAR_postgresql_database_password: ${{ secrets.TF_VAR_POSTGRESQL_PASSWORD }}
 64:     defaults:
 65:       run:
 66:         working-directory: ./application
 67:     steps:
 68:       - name: Checkout the repo code
 69:         uses: actions/checkout@v4
 70:       - name: Setup terraform
 71:         uses: hashicorp/setup-terraform@v3
 72:         with:
 73:           terraform_version: 1.14.0
 74:       - name: Export environment variables for set-k8s-env.sh
 75:         run: |
 76:           # Export required variables for set-k8s-env.sh (matching setup-application.sh)
 77:           echo "BACKEND_FILE=backend.hcl" >> $GITHUB_ENV
 78:           echo "VARIABLES_FILE=variables.tfvars" >> $GITHUB_ENV
 79:           echo "ENVIRONMENT=${{ inputs.environment }}" >> $GITHUB_ENV
 80:           # Determine deployment account role ARN based on environment
 81:           if [ "${{ inputs.environment }}" = "prod" ]; then
 82:             echo "DEPLOYMENT_ROLE_ARN=${{ secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 83:           else
 84:             echo "DEPLOYMENT_ROLE_ARN=${{ secrets.AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 85:           fi
 86:           echo "EXTERNAL_ID=${{ secrets.AWS_ASSUME_EXTERNAL_ID }}" >> $GITHUB_ENV
 87:           # Export state account role ARN for Route53/ACM access
 88:           echo "STATE_ACCOUNT_ROLE_ARN=${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 89:       - name: Configure AWS credentials (State Account)
 90:         uses: aws-actions/configure-aws-credentials@v4
 91:         with:
 92:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
 93:           role-session-name: GitHubActions-ApplicationInfraDestroy-State
 94:           aws-region: ${{ env.AWS_REGION }}
 95:       - name: Create backend.hcl from placeholder
 96:         run: |
 97:           # Only create if it doesn't exist (matching setup-application.sh behavior)
 98:           if [ ! -f "backend.hcl" ]; then
 99:             cp tfstate-backend-values-template.hcl backend.hcl
100:             sed -i -e "s|<BACKEND_BUCKET_NAME>|${{ vars.BACKEND_BUCKET_NAME }}|g" \
101:             -e "s|<APPLICATION_PREFIX>|${{ vars.APPLICATION_PREFIX }}|g" \
102:             -e "s|<AWS_REGION>|${{ env.AWS_REGION }}|g" \
103:             backend.hcl
104:             echo "Created backend.hcl:"
105:             cat backend.hcl
106:           else
107:             echo "backend.hcl already exists. Skipping creation."
108:           fi
109:       - name: Terraform init
110:         run: terraform init -backend-config=backend.hcl
111:       - name: Terraform workspace
112:         run: |
113:           WORKSPACE="${{ env.AWS_REGION }}-${{ inputs.environment }}"
114:           terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE
115:       - name: Terraform validate
116:         run: terraform validate
117:       - name: Set Kubernetes environment variables
118:         run: |
119:           # set-k8s-env.sh expects State Account credentials to be active for S3 operations
120:           # It will assume Deployment Account role internally for EKS operations
121:           chmod +x ./set-k8s-env.sh
122:           source ./set-k8s-env.sh
123:           # Export as TF_VAR_ environment variables for Terraform
124:           echo "TF_VAR_kubernetes_master=$KUBERNETES_MASTER" >> $GITHUB_ENV
125:           echo "TF_VAR_kube_config_path=$KUBE_CONFIG_PATH" >> $GITHUB_ENV
126:       - name: Configure AWS credentials (State Account for Terraform)
127:         uses: aws-actions/configure-aws-credentials@v4
128:         with:
129:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
130:           role-session-name: GitHubActions-ApplicationInfraDestroy-Terraform
131:           aws-region: ${{ env.AWS_REGION }}
132:       - name: Terraform plan destroy
133:         run: terraform plan -var-file="variables.tfvars" -destroy -out terraform.tfplan
134:       - name: Destroy application infrastructure
135:         run: terraform apply -auto-approve terraform.tfplan
```

## File: application/helm/openldap-values.tpl.yaml
```yaml
 1: # High availability configuration with 3 replicas
 2: # Note: StatefulSet creates individual PVCs for each replica, so ReadWriteOnce works fine
 3: replicaCount: 3
 4: # Enable replication for HA multi-master setup
 5: replication:
 6:   enabled: true
 7:   retry: 60
 8:   timeout: 30  # Increased from default 1 second to prevent replication failures
 9:   interval: "00:00:00:10"
10:   starttls: "critical"
11:   tls_reqcert: "never"
12:   clusterName: "cluster.local"
13: # Override default image to use ECR repository
14: image:
15:   registry: "${ecr_registry}"
16:   repository: "${ecr_repository}"
17:   tag: "${openldap_image_tag}"
18:   pullPolicy: IfNotPresent
19: global:
20:   imageRegistry: ""
21:   imagePullSecrets: []
22:   storageClass: "${storage_class_name}"
23:   ldapDomain: "${openldap_ldap_domain}"
24:   existingSecret: "${openldap_secret_name}"
25:   ldapPort: 389
26:   sslLdapPort: 636
27: # Enable TLS with auto-generated certificates for osixia/openldap image
28: # osixia/openldap uses different environment variable names than Bitnami
29: # Note: LDAP_ADMIN_PASSWORD and LDAP_CONFIG_PASSWORD are now sourced from the Kubernetes secret
30: # specified in global.existingSecret
31: env:
32:   LDAP_DOMAIN: "${openldap_ldap_domain}"
33:   # Enable TLS (osixia/openldap will auto-generate certificates if they don't exist)
34:   LDAP_TLS: "true"
35:   # Don't enforce TLS (allows both LDAP and LDAPS connections)
36:   LDAP_TLS_ENFORCE: "false"
37:   # Don't require client certificates
38:   LDAP_TLS_VERIFY_CLIENT: "never"
39:   # Certificate filenames (not full paths) - osixia/openldap expects these in /container/service/slapd/assets/certs/
40:   # If certificates don't exist, osixia/openldap will auto-generate them
41:   LDAP_TLS_CRT_FILENAME: "ldap.crt"
42:   LDAP_TLS_KEY_FILENAME: "ldap.key"
43:   LDAP_TLS_CA_CRT_FILENAME: "ca.crt"
44: persistence:
45:   enabled: true
46:   accessModes:
47:     - ReadWriteOnce
48:   size: 8Gi
49: service:
50:   annotations: {}
51:   externalIPs: []
52:   type: ClusterIP
53:   sessionAffinity: None
54: ltb-passwd:
55:   enabled: true
56:   image:
57:     tag: 5.2.3
58:   podLabels:
59:     app: "${app_name}"
60:   # Allow TLS but don't verify certificates (accept self-signed)
61:   env:
62:     LDAPTLS_REQCERT: "allow"
63:   ingress:
64:     enabled: true
65:     ingressClassName: "${ingress_class_name}"
66:     annotations:
67:       # Note: load-balancer-name is the AWS ALB name (max 32 chars), while group.name is the Kubernetes group identifier (max 63 chars)
68:       alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
69:       alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
70:       alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
71:       alb.ingress.kubernetes.io/ssl-redirect: "443"
72:       alb.ingress.kubernetes.io/ssl-policy: "${alb_ssl_policy}"
73:       # Note: scheme and ipAddressType are inherited from IngressClassParams
74:     path: /
75:     pathType: Prefix
76:     hosts:
77:       - "${ltb_passwd_host}"
78:   ldap:
79:     bindPWKey: LDAP_ADMIN_PASSWORD
80: phpldapadmin:
81:   enabled: true
82:   # Allow StartTLS but don't verify certificates (accept self-signed)
83:   env:
84:     PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: "allow"
85:   podLabels:
86:     app: "${app_name}"
87:   ingress:
88:     enabled: true
89:     ingressClassName: "${ingress_class_name}"
90:     annotations:
91:       alb.ingress.kubernetes.io/load-balancer-name: "${alb_load_balancer_name}"
92:       alb.ingress.kubernetes.io/target-type: "${alb_target_type}"
93:       alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
94:       alb.ingress.kubernetes.io/ssl-redirect: "443"
95:       alb.ingress.kubernetes.io/ssl-policy: "${alb_ssl_policy}"
96:     path: /
97:     pathType: Prefix
98:     hosts:
99:       - "${phpldapadmin_host}"
```

## File: application/modules/postgresql/main.tf
```hcl
  1: /**
  2:  * PostgreSQL Module
  3:  *
  4:  * Deploys PostgreSQL using the Bitnami Helm chart for user storage
  5:  * in the LDAP 2FA application signup system.
  6:  */
  7:
  8: locals {
  9:   name = "${var.prefix}-${var.region}-postgresql-${var.env}"
 10:
 11:   # Determine values template path
 12:   values_template_path = var.values_template_path != null ? var.values_template_path : "${path.module}/../../helm/postgresql-values.tpl.yaml"
 13:
 14:   # Build PostgreSQL Helm values using templatefile
 15:   # Note: We pass the secret name variable (not resource) to avoid circular dependency
 16:   # The secret resource is created separately with the same name
 17:   postgresql_values = templatefile(
 18:     local.values_template_path,
 19:     {
 20:       secret_name              = var.secret_name
 21:       database_name            = var.database_name
 22:       database_username        = var.database_username
 23:       storage_class            = var.storage_class
 24:       storage_size             = var.storage_size
 25:       resources_requests_cpu   = var.resources.requests.cpu
 26:       resources_requests_memory = var.resources.requests.memory
 27:       resources_limits_cpu     = var.resources.limits.cpu
 28:       resources_limits_memory  = var.resources.limits.memory
 29:       ecr_registry             = var.ecr_registry
 30:       ecr_repository           = var.ecr_repository
 31:       image_tag                = var.image_tag
 32:     }
 33:   )
 34: }
 35:
 36: # Create namespace if it doesn't exist
 37: resource "kubernetes_namespace" "postgresql" {
 38:   metadata {
 39:     name = var.namespace
 40:
 41:     labels = {
 42:       name        = var.namespace
 43:       environment = var.env
 44:       managed-by  = "terraform"
 45:     }
 46:   }
 47:
 48:   lifecycle {
 49:     ignore_changes = [metadata[0].labels]
 50:   }
 51: }
 52:
 53: # Create Kubernetes secret for PostgreSQL password
 54: # Password is sourced from GitHub Secrets via TF_VAR_postgresql_database_password
 55: resource "kubernetes_secret" "postgresql_password" {
 56:   metadata {
 57:     name      = var.secret_name
 58:     namespace = kubernetes_namespace.postgresql.metadata[0].name
 59:
 60:     labels = {
 61:       app         = local.name
 62:       environment = var.env
 63:       managed-by  = "terraform"
 64:     }
 65:   }
 66:
 67:   data = {
 68:     "password" = var.database_password
 69:   }
 70:
 71:   type = "Opaque"
 72: }
 73:
 74: # PostgreSQL Helm release
 75: resource "helm_release" "postgresql" {
 76:   name       = local.name
 77:   # repository = "https://charts.bitnami.com/bitnami"
 78:   repository = "oci://registry-1.docker.io/bitnamicharts"
 79:   chart      = "postgresql"
 80:   version    = var.chart_version
 81:   namespace  = kubernetes_namespace.postgresql.metadata[0].name
 82:
 83:   atomic          = true
 84:   cleanup_on_fail = true
 85:   recreate_pods   = true
 86:   force_update    = true
 87:   wait            = true
 88:   wait_for_jobs   = true
 89:   timeout         = 600 # Reduced from 1200 to 600 seconds (10 min) for faster debugging
 90:   upgrade_install = true
 91:
 92:   # Allow replacement if name conflict occurs
 93:   replace = true
 94:
 95:   # Use templatefile to inject values into the official Bitnami PostgreSQL Helm chart values template
 96:   # Note: The secret name is passed to the template, and the secret resource is created separately
 97:   values = [local.postgresql_values]
 98:
 99:   depends_on = [
100:     kubernetes_namespace.postgresql,
101:     kubernetes_secret.postgresql_password,
102:   ]
103: }
```

## File: application/setup-application.sh
```bash
  1: #!/bin/bash
  2: # Script to configure backend.hcl and variables.tfvars with user-selected region and environment
  3: # and run Terraform commands
  4: # Usage: ./setup-application.sh
  5: set -euo pipefail
  6: # Clean up any existing AWS credentials from environment to prevent conflicts
  7: # This ensures the script starts with a clean slate and uses the correct credentials
  8: unset AWS_ACCESS_KEY_ID 2>/dev/null || true
  9: unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
 10: unset AWS_SESSION_TOKEN 2>/dev/null || true
 11: unset AWS_PROFILE 2>/dev/null || true
 12: # Colors for output
 13: RED='\033[0;31m'
 14: GREEN='\033[0;32m'
 15: YELLOW='\033[1;33m'
 16: NC='\033[0m' # No Color
 17: # Configuration
 18: PLACEHOLDER_FILE="tfstate-backend-values-template.hcl"
 19: BACKEND_FILE="backend.hcl"
 20: VARIABLES_FILE="variables.tfvars"
 21: # Export configuration variables for use by sourced scripts
 22: export BACKEND_FILE
 23: export VARIABLES_FILE
 24: # Function to print colored messages
 25: print_error() {
 26:     echo -e "${RED}ERROR:${NC} $1" >&2
 27: }
 28: print_success() {
 29:     echo -e "${GREEN}SUCCESS:${NC} $1"
 30: }
 31: print_info() {
 32:     echo -e "${YELLOW}INFO:${NC} $1"
 33: }
 34: # Check if AWS CLI is installed
 35: if ! command -v aws &> /dev/null; then
 36:     print_error "AWS CLI is not installed."
 37:     echo "Please install it from: https://aws.amazon.com/cli/"
 38:     exit 1
 39: fi
 40: # Check if Terraform is installed
 41: if ! command -v terraform &> /dev/null; then
 42:     print_error "Terraform is not installed."
 43:     echo "Please install it from: https://www.terraform.io/downloads"
 44:     exit 1
 45: fi
 46: # Check if GitHub CLI is installed
 47: if ! command -v gh &> /dev/null; then
 48:     print_error "GitHub CLI (gh) is not installed."
 49:     echo "Please install it from: https://cli.github.com/"
 50:     exit 1
 51: fi
 52: # Check if user is authenticated with GitHub CLI
 53: if ! gh auth status &> /dev/null; then
 54:     print_error "Not authenticated with GitHub CLI."
 55:     echo "Please run: gh auth login"
 56:     exit 1
 57: fi
 58: # Check if jq is installed (required for gh --jq flag)
 59: if ! command -v jq &> /dev/null; then
 60:     print_error "jq is not installed."
 61:     echo "Please install it:"
 62:     echo "  macOS: brew install jq"
 63:     echo "  Linux: sudo apt-get install jq (or use your package manager)"
 64:     echo "  Or visit: https://stedolan.github.io/jq/download/"
 65:     exit 1
 66: fi
 67: # Get repository owner and name
 68: REPO_OWNER=$(gh repo view --json owner --jq '.owner.login' 2>/dev/null || echo "")
 69: REPO_NAME=$(gh repo view --json name --jq '.name' 2>/dev/null || echo "")
 70: if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
 71:     print_error "Could not determine repository information."
 72:     echo "Please ensure you're in a git repository and have proper permissions."
 73:     exit 1
 74: fi
 75: print_info "Repository: ${REPO_OWNER}/${REPO_NAME}"
 76: # Function to get repository variable using GitHub CLI
 77: get_repo_variable() {
 78:     local var_name=$1
 79:     local value
 80:     value=$(gh variable list --repo "${REPO_OWNER}/${REPO_NAME}" --json name,value --jq ".[] | select(.name == \"${var_name}\") | .value" 2>/dev/null || echo "")
 81:     if [ -z "$value" ]; then
 82:         print_error "Repository variable '${var_name}' not found or not accessible."
 83:         return 1
 84:     fi
 85:     echo "$value"
 86: }
 87: # Function to retrieve secret from AWS Secrets Manager
 88: get_aws_secret() {
 89:     local secret_name=$1
 90:     local secret_json
 91:     local exit_code
 92:     # Retrieve secret from AWS Secrets Manager
 93:     # Use AWS_REGION if set, otherwise default to us-east-1
 94:     secret_json=$(aws secretsmanager get-secret-value \
 95:         --secret-id "$secret_name" \
 96:         --region "${AWS_REGION:-us-east-1}" \
 97:         --query SecretString \
 98:         --output text 2>&1)
 99:     # Capture exit code before checking
100:     exit_code=$?
101:     # Validate secret retrieval
102:     if [ $exit_code -ne 0 ]; then
103:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
104:         print_error "Error: $secret_json"
105:         return 1
106:     fi
107:     # Validate JSON can be parsed
108:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
109:         print_error "Secret '${secret_name}' contains invalid JSON"
110:         return 1
111:     fi
112:     echo "$secret_json"
113: }
114: # Function to retrieve plain text secret from AWS Secrets Manager
115: get_aws_plaintext_secret() {
116:     local secret_name=$1
117:     local secret_value
118:     local exit_code
119:     # Retrieve secret from AWS Secrets Manager
120:     # Use AWS_REGION if set, otherwise default to us-east-1
121:     secret_value=$(aws secretsmanager get-secret-value \
122:         --secret-id "$secret_name" \
123:         --region "${AWS_REGION:-us-east-1}" \
124:         --query SecretString \
125:         --output text 2>&1)
126:     # Capture exit code before checking
127:     exit_code=$?
128:     # Validate secret retrieval
129:     if [ $exit_code -ne 0 ]; then
130:         print_error "Failed to retrieve secret '${secret_name}' from AWS Secrets Manager"
131:         print_error "Error: $secret_value"
132:         return 1
133:     fi
134:     # Check if secret value is empty
135:     if [ -z "$secret_value" ]; then
136:         print_error "Secret '${secret_name}' is empty"
137:         return 1
138:     fi
139:     echo "$secret_value"
140: }
141: # Function to get key value from secret JSON
142: get_secret_key_value() {
143:     local secret_json=$1
144:     local key_name=$2
145:     local value
146:     # Validate JSON can be parsed
147:     if ! echo "$secret_json" | jq empty 2>/dev/null; then
148:         print_error "Invalid JSON provided to get_secret_key_value"
149:         return 1
150:     fi
151:     # Extract key value using jq
152:     value=$(echo "$secret_json" | jq -r ".[\"${key_name}\"]" 2>/dev/null)
153:     # Check if jq command succeeded
154:     if [ $? -ne 0 ]; then
155:         print_error "Failed to parse JSON or extract key '${key_name}'"
156:         return 1
157:     fi
158:     # Check if key exists (jq returns "null" for non-existent keys)
159:     if [ "$value" = "null" ] || [ -z "$value" ]; then
160:         print_error "Key '${key_name}' not found in secret JSON or value is empty"
161:         return 1
162:     fi
163:     echo "$value"
164: }
165: # Function to assume an AWS IAM role and export credentials
166: # Usage: assume_aws_role <role_arn> [external_id] [role_description] [session_name_suffix]
167: #   role_arn: The ARN of the role to assume (required)
168: #   external_id: Optional external ID for cross-account role assumption
169: #   role_description: Optional description for logging (defaults to "role")
170: #   session_name_suffix: Optional suffix for session name (defaults to "setup-application")
171: assume_aws_role() {
172:     local role_arn=$1
173:     local external_id=${2:-}
174:     local role_description=${3:-"role"}
175:     local session_name_suffix=${4:-"setup-application"}
176:     if [ -z "$role_arn" ]; then
177:         print_error "Role ARN is required for assume_aws_role"
178:         return 1
179:     fi
180:     print_info "Assuming ${role_description}: $role_arn"
181:     print_info "Region: $AWS_REGION"
182:     # Assume the role
183:     local role_session_name="${session_name_suffix}-$(date +%s)"
184:     local assume_role_output
185:     # Assume role and capture output
186:     # Add external ID if provided
187:     if [ -n "$external_id" ]; then
188:         assume_role_output=$(aws sts assume-role \
189:             --role-arn "$role_arn" \
190:             --role-session-name "$role_session_name" \
191:             --external-id "$external_id" \
192:             --region "$AWS_REGION" 2>&1)
193:     else
194:         assume_role_output=$(aws sts assume-role \
195:             --role-arn "$role_arn" \
196:             --role-session-name "$role_session_name" \
197:             --region "$AWS_REGION" 2>&1)
198:     fi
199:     if [ $? -ne 0 ]; then
200:         print_error "Failed to assume ${role_description}: $assume_role_output"
201:         return 1
202:     fi
203:     # Extract credentials from JSON output
204:     # Try using jq if available (more reliable), otherwise use sed/grep
205:     local access_key_id
206:     local secret_access_key
207:     local session_token
208:     if command -v jq &> /dev/null; then
209:         access_key_id=$(echo "$assume_role_output" | jq -r '.Credentials.AccessKeyId')
210:         secret_access_key=$(echo "$assume_role_output" | jq -r '.Credentials.SecretAccessKey')
211:         session_token=$(echo "$assume_role_output" | jq -r '.Credentials.SessionToken')
212:     else
213:         # Fallback: use sed for JSON parsing (works on both macOS and Linux)
214:         access_key_id=$(echo "$assume_role_output" | sed -n 's/.*"AccessKeyId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
215:         secret_access_key=$(echo "$assume_role_output" | sed -n 's/.*"SecretAccessKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
216:         session_token=$(echo "$assume_role_output" | sed -n 's/.*"SessionToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
217:     fi
218:     if [ -z "$access_key_id" ] || [ -z "$secret_access_key" ] || [ -z "$session_token" ]; then
219:         print_error "Failed to extract credentials from assume-role output."
220:         print_error "Output was: $assume_role_output"
221:         return 1
222:     fi
223:     # Export credentials to environment variables
224:     export AWS_ACCESS_KEY_ID="$access_key_id"
225:     export AWS_SECRET_ACCESS_KEY="$secret_access_key"
226:     export AWS_SESSION_TOKEN="$session_token"
227:     print_success "Successfully assumed ${role_description}"
228:     # Verify the credentials work
229:     local caller_arn
230:     caller_arn=$(aws sts get-caller-identity --region "$AWS_REGION" --query 'Arn' --output text 2>&1)
231:     if [ $? -ne 0 ]; then
232:         print_error "Failed to verify assumed role credentials: $caller_arn"
233:         return 1
234:     fi
235:     print_info "${role_description} identity: $caller_arn"
236:     return 0
237: }
238: # Interactive prompts
239: echo ""
240: print_info "Select AWS Region:"
241: echo "1) us-east-1: N. Virginia (default)"
242: echo "2) us-east-2: Ohio"
243: read -p "Enter choice [1-2] (default: 1): " region_choice
244: case ${region_choice:-1} in
245:     1)
246:         SELECTED_REGION="us-east-1: N. Virginia"
247:         ;;
248:     2)
249:         SELECTED_REGION="us-east-2: Ohio"
250:         ;;
251:     *)
252:         print_error "Invalid choice. Using default: us-east-1: N. Virginia"
253:         SELECTED_REGION="us-east-1: N. Virginia"
254:         ;;
255: esac
256: # Extract region code (everything before the colon)
257: AWS_REGION="${SELECTED_REGION%%:*}"
258: export AWS_REGION
259: print_success "Selected region: ${SELECTED_REGION} (${AWS_REGION})"
260: echo ""
261: print_info "Select Environment:"
262: echo "1) prod (default)"
263: echo "2) dev"
264: read -p "Enter choice [1-2] (default: 1): " env_choice
265: case ${env_choice:-1} in
266:     1)
267:         ENVIRONMENT="prod"
268:         ;;
269:     2)
270:         ENVIRONMENT="dev"
271:         ;;
272:     *)
273:         print_error "Invalid choice. Using default: prod"
274:         ENVIRONMENT="prod"
275:         ;;
276: esac
277: print_success "Selected environment: ${ENVIRONMENT}"
278: export ENVIRONMENT
279: echo ""
280: # Retrieve role ARNs from AWS Secrets Manager in a single call
281: # This minimizes AWS CLI calls by fetching all required role ARNs at once
282: print_info "Retrieving role ARNs from AWS Secrets Manager..."
283: ROLE_SECRET_JSON=$(get_aws_secret "github-role" || echo "")
284: if [ -z "$ROLE_SECRET_JSON" ]; then
285:     print_error "Failed to retrieve 'github-role' secret from AWS Secrets Manager"
286:     exit 1
287: fi
288: # Extract STATE_ACCOUNT_ROLE_ARN for backend state operations and Route53/ACM access
289: STATE_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "AWS_STATE_ACCOUNT_ROLE_ARN" || echo "")
290: if [ -z "$STATE_ROLE_ARN" ]; then
291:     print_error "Failed to retrieve AWS_STATE_ACCOUNT_ROLE_ARN from secret"
292:     exit 1
293: fi
294: export STATE_ACCOUNT_ROLE_ARN="$STATE_ROLE_ARN"
295: print_success "Retrieved AWS_STATE_ACCOUNT_ROLE_ARN"
296: # Determine which deployment account role ARN to use based on environment
297: if [ "$ENVIRONMENT" = "prod" ]; then
298:     DEPLOYMENT_ROLE_ARN_KEY="AWS_PRODUCTION_ACCOUNT_ROLE_ARN"
299: else
300:     DEPLOYMENT_ROLE_ARN_KEY="AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN"
301: fi
302: # Extract deployment account role ARN for provider assume_role
303: DEPLOYMENT_ROLE_ARN=$(get_secret_key_value "$ROLE_SECRET_JSON" "$DEPLOYMENT_ROLE_ARN_KEY" || echo "")
304: if [ -z "$DEPLOYMENT_ROLE_ARN" ]; then
305:     print_error "Failed to retrieve ${DEPLOYMENT_ROLE_ARN_KEY} from secret"
306:     exit 1
307: fi
308: export DEPLOYMENT_ROLE_ARN
309: print_success "Retrieved ${DEPLOYMENT_ROLE_ARN_KEY}"
310: # Retrieve ExternalId from AWS Secrets Manager (plain text secret)
311: print_info "Retrieving ExternalId from AWS Secrets Manager..."
312: EXTERNAL_ID=$(get_aws_plaintext_secret "external-id" || echo "")
313: if [ -z "$EXTERNAL_ID" ]; then
314:     print_error "Failed to retrieve 'external-id' secret from AWS Secrets Manager"
315:     exit 1
316: fi
317: export EXTERNAL_ID
318: print_success "Retrieved ExternalId"
319: # Retrieve Terraform variables from AWS Secrets Manager in a single call
320: print_info "Retrieving Terraform variables from AWS Secrets Manager..."
321: TF_VARS_SECRET_JSON=$(get_aws_secret "tf-vars" || echo "")
322: if [ -z "$TF_VARS_SECRET_JSON" ]; then
323:     print_error "Failed to retrieve 'tf-vars' secret from AWS Secrets Manager"
324:     exit 1
325: fi
326: # Extract OpenLDAP password values from tf-vars secret
327: TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_ADMIN_PASSWORD" || echo "")
328: if [ -z "$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE" ]; then
329:     print_error "Failed to retrieve TF_VAR_OPENLDAP_ADMIN_PASSWORD from secret"
330:     exit 1
331: fi
332: print_success "Retrieved TF_VAR_OPENLDAP_ADMIN_PASSWORD"
333: TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_OPENLDAP_CONFIG_PASSWORD" || echo "")
334: if [ -z "$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE" ]; then
335:     print_error "Failed to retrieve TF_VAR_OPENLDAP_CONFIG_PASSWORD from secret"
336:     exit 1
337: fi
338: print_success "Retrieved TF_VAR_OPENLDAP_CONFIG_PASSWORD"
339: # Extract PostgreSQL password from tf-vars secret
340: TF_VAR_POSTGRESQL_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_POSTGRESQL_PASSWORD" || echo "")
341: if [ -z "$TF_VAR_POSTGRESQL_PASSWORD_VALUE" ]; then
342:     print_error "Failed to retrieve TF_VAR_POSTGRESQL_PASSWORD from secret"
343:     exit 1
344: fi
345: print_success "Retrieved TF_VAR_POSTGRESQL_PASSWORD"
346: # Extract Redis password from tf-vars secret
347: TF_VAR_REDIS_PASSWORD_VALUE=$(get_secret_key_value "$TF_VARS_SECRET_JSON" "TF_VAR_REDIS_PASSWORD" || echo "")
348: if [ -z "$TF_VAR_REDIS_PASSWORD_VALUE" ]; then
349:     print_error "Failed to retrieve TF_VAR_REDIS_PASSWORD from secret"
350:     exit 1
351: fi
352: print_success "Retrieved TF_VAR_REDIS_PASSWORD"
353: # Export as environment variables for Terraform
354: # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
355: # Secrets in AWS/GitHub remain uppercase, but environment variables must be lowercase
356: export TF_VAR_openldap_admin_password="$TF_VAR_OPENLDAP_ADMIN_PASSWORD_VALUE"
357: export TF_VAR_openldap_config_password="$TF_VAR_OPENLDAP_CONFIG_PASSWORD_VALUE"
358: export TF_VAR_postgresql_database_password="$TF_VAR_POSTGRESQL_PASSWORD_VALUE"
359: export TF_VAR_redis_password="$TF_VAR_REDIS_PASSWORD_VALUE"
360: print_success "Retrieved and exported all secrets from AWS Secrets Manager"
361: echo ""
362: # Retrieve repository variables
363: print_info "Retrieving repository variables..."
364: BUCKET_NAME=$(get_repo_variable "BACKEND_BUCKET_NAME") || exit 1
365: print_success "Retrieved BACKEND_BUCKET_NAME"
366: APPLICATION_PREFIX=$(get_repo_variable "APPLICATION_PREFIX") || exit 1
367: print_success "Retrieved APPLICATION_PREFIX"
368: # Check if backend.hcl already exists
369: if [ -f "$BACKEND_FILE" ]; then
370:     print_info "${BACKEND_FILE} already exists. Skipping creation."
371: else
372:     # Check if placeholder file exists
373:     if [ ! -f "$PLACEHOLDER_FILE" ]; then
374:         print_error "Placeholder file '${PLACEHOLDER_FILE}' not found."
375:         exit 1
376:     fi
377:     # Copy placeholder to backend file and replace placeholders
378:     print_info "Creating ${BACKEND_FILE} from ${PLACEHOLDER_FILE} with retrieved values..."
379:     # Copy placeholder file to backend file
380:     cp "$PLACEHOLDER_FILE" "$BACKEND_FILE"
381:     # Replace placeholders (works on macOS and Linux)
382:     if [[ "$OSTYPE" == "darwin"* ]]; then
383:         # macOS sed requires -i '' for in-place editing
384:         sed -i '' "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
385:         sed -i '' "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
386:         sed -i '' "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
387:     else
388:         # Linux sed
389:         sed -i "s|<BACKEND_BUCKET_NAME>|${BUCKET_NAME}|g" "$BACKEND_FILE"
390:         sed -i "s|<APPLICATION_PREFIX>|${APPLICATION_PREFIX}|g" "$BACKEND_FILE"
391:         sed -i "s|<AWS_REGION>|${AWS_REGION}|g" "$BACKEND_FILE"
392:     fi
393:     print_success "Created ${BACKEND_FILE}"
394: fi
395: print_success "Configuration files updated successfully!"
396: echo ""
397: print_info "Backend file: ${BACKEND_FILE}"
398: print_info "  - bucket: ${BUCKET_NAME}"
399: print_info "  - key: ${APPLICATION_PREFIX}"
400: print_info "  - region: ${AWS_REGION}"
401: echo ""
402: # Assume State Account role for backend operations
403: if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "setup-application"; then
404:     exit 1
405: fi
406: echo ""
407: # Terraform workspace name (same as backend_infra)
408: WORKSPACE_NAME="${AWS_REGION}-${ENVIRONMENT}"
409: # Terraform init
410: print_info "Running terraform init with backend configuration..."
411: terraform init -backend-config="${BACKEND_FILE}"
412: # Terraform workspace (create/select before running mirror script)
413: print_info "Selecting or creating workspace: ${WORKSPACE_NAME}..."
414: terraform workspace select "${WORKSPACE_NAME}" 2>/dev/null || terraform workspace new "${WORKSPACE_NAME}"
415: echo ""
416: # Mirror third-party images to ECR (if not already present)
417: print_info "Checking if Docker images need to be mirrored to ECR..."
418: if [ ! -f "mirror-images-to-ecr.sh" ]; then
419:     print_error "mirror-images-to-ecr.sh not found."
420:     exit 1
421: fi
422: # Make sure the script is executable
423: chmod +x ./mirror-images-to-ecr.sh
424: # Run the image mirroring script
425: if ./mirror-images-to-ecr.sh; then
426:     print_success "ECR image mirroring completed"
427: else
428:     print_error "ECR image mirroring failed"
429:     exit 1
430: fi
431: # Terraform validate
432: print_info "Running terraform validate..."
433: terraform validate
434: # Set Kubernetes environment variables
435: print_info "Setting Kubernetes environment variables..."
436: if [ ! -f "set-k8s-env.sh" ]; then
437:     print_error "set-k8s-env.sh not found."
438:     exit 1
439: fi
440: # Make sure the script is executable
441: chmod +x ./set-k8s-env.sh
442: # Source the script to set environment variables
443: # The script uses environment variables (Deployment Account credentials for EKS, State Account credentials for S3)
444: source ./set-k8s-env.sh
445: if [ -z "$KUBERNETES_MASTER" ]; then
446:     print_error "Failed to set KUBERNETES_MASTER environment variable."
447:     exit 1
448: fi
449: print_success "Kubernetes environment variables set"
450: print_info "  - KUBERNETES_MASTER: ${KUBERNETES_MASTER}"
451: print_info "  - KUBE_CONFIG_PATH: ${KUBE_CONFIG_PATH}"
452: # Export as TF_VAR_ environment variables for Terraform
453: export TF_VAR_kubernetes_master="$KUBERNETES_MASTER"
454: export TF_VAR_kube_config_path="$KUBE_CONFIG_PATH"
455: print_info "  - TF_VAR_kubernetes_master: ${TF_VAR_kubernetes_master}"
456: print_info "  - TF_VAR_kube_config_path: ${TF_VAR_kube_config_path}"
457: echo ""
458: # Assume State Account role for backend operations
459: if ! assume_aws_role "$STATE_ROLE_ARN" "" "State Account role" "setup-application"; then
460:     exit 1
461: fi
462: echo ""
463: # Terraform plan
464: print_info "Running terraform plan..."
465: terraform plan -var-file="${VARIABLES_FILE}" -out terraform.tfplan
466: # Terraform apply
467: print_info "Running terraform apply..."
468: terraform apply -auto-approve terraform.tfplan
469: echo ""
470: print_success "Script completed successfully!"
```

## File: backend_infra/providers.tf
```hcl
 1: terraform {
 2:   required_providers {
 3:     aws = {
 4:       source  = "hashicorp/aws"
 5:       version = ">= 6.21.0"
 6:     }
 7:     kubernetes = {
 8:       source  = "hashicorp/kubernetes"
 9:       version = "~> 2.0"
10:     }
11:   }
12:
13:   backend "s3" {
14:     # Backend configuration provided via backend.hcl file
15:     encrypt      = true
16:     use_lockfile = true
17:   }
18:
19:   required_version = "~> 1.14.0"
20: }
21:
22: provider "aws" {
23:   region = var.region
24:
25:   # Assume role in deployment account (Account B) if role ARN is provided
26:   # This allows GitHub Actions to authenticate with Account A (for state)
27:   # while Terraform provider uses Account B (for resource deployment)
28:   # ExternalId is required for security when assuming cross-account roles
29:   dynamic "assume_role" {
30:     for_each = var.deployment_account_role_arn != null ? [1] : []
31:     content {
32:       role_arn    = var.deployment_account_role_arn
33:       external_id = var.deployment_account_external_id
34:     }
35:   }
36: }
37:
38: provider "kubernetes" {
39:   host                   = module.eks.cluster_endpoint
40:   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
41:   token                  = data.aws_eks_cluster_auth.cluster.token
42: }
43:
44: data "aws_eks_cluster_auth" "cluster" {
45:   name = module.eks.cluster_name
46: }
```

## File: .github/workflows/application_infra_provisioning.yaml
```yaml
  1: name: Application Infra Provisioning
  2: # Required GitHub Repository Secrets:
  3: # - AWS_STATE_ACCOUNT_ROLE_ARN: IAM role ARN for backend state operations
  4: # - AWS_PRODUCTION_ACCOUNT_ROLE_ARN: IAM role ARN for production deployments
  5: # - AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN: IAM role ARN for development deployments
  6: # - AWS_ASSUME_EXTERNAL_ID: ExternalId for cross-account role assumption security
  7: # - TF_VAR_OPENLDAP_ADMIN_PASSWORD: OpenLDAP admin password
  8: # - TF_VAR_OPENLDAP_CONFIG_PASSWORD: OpenLDAP config password
  9: # - TF_VAR_POSTGRESQL_PASSWORD: PostgreSQL database password
 10: # - TF_VAR_REDIS_PASSWORD: Redis password for SMS OTP storage
 11: #
 12: # Note: GitHub workflows use repository secrets, while bash scripts use AWS Secrets Manager.
 13: # The secrets listed above must be configured in GitHub repository settings.
 14: on:
 15:   workflow_dispatch:
 16:     inputs:
 17:       region:
 18:         description: 'Select AWS Region'
 19:         required: true
 20:         type: choice
 21:         default: 'us-east-1: N. Virginia'
 22:         options:
 23:           - 'us-east-1: N. Virginia'
 24:           - 'us-east-2: Ohio'
 25:       environment:
 26:         description: 'Select Environment'
 27:         required: true
 28:         type: choice
 29:         default: prod
 30:         options:
 31:           - prod
 32:           - dev
 33: jobs:
 34:   SetRegion:
 35:     runs-on: ubuntu-latest
 36:     permissions:
 37:       contents: read
 38:     outputs:
 39:       region_code: ${{ steps.set_region.outputs.region_code }}
 40:     steps:
 41:       - name: Set Region
 42:         id: set_region
 43:         run: |
 44:           SELECTED_REGION="${{ inputs.region }}"
 45:           echo "region_code=${SELECTED_REGION%%:*}" >> $GITHUB_OUTPUT
 46:   InfraProvision:
 47:     runs-on: ubuntu-latest
 48:     needs:
 49:       - SetRegion
 50:     permissions:
 51:       contents: write
 52:       actions: write
 53:       id-token: write
 54:     env:
 55:       AWS_REGION: ${{ needs.SetRegion.outputs.region_code }}
 56:       # Note: TF_VAR environment variables are case-sensitive and must match variable names in variables.tf
 57:       # Secrets in GitHub remain uppercase, but environment variables must be lowercase
 58:       TF_VAR_openldap_admin_password: ${{ secrets.TF_VAR_OPENLDAP_ADMIN_PASSWORD }}
 59:       TF_VAR_openldap_config_password: ${{ secrets.TF_VAR_OPENLDAP_CONFIG_PASSWORD }}
 60:       # Redis password for SMS OTP storage
 61:       TF_VAR_redis_password: ${{ secrets.TF_VAR_REDIS_PASSWORD }}
 62:       # PostgreSQL password for User management database
 63:       TF_VAR_postgresql_database_password: ${{ secrets.TF_VAR_POSTGRESQL_PASSWORD }}
 64:     defaults:
 65:       run:
 66:         working-directory: ./application
 67:     steps:
 68:       - name: Checkout the repo code
 69:         uses: actions/checkout@v4
 70:       - name: Setup terraform
 71:         uses: hashicorp/setup-terraform@v3
 72:         with:
 73:           terraform_version: 1.14.0
 74:       - name: Export environment variables for set-k8s-env.sh
 75:         run: |
 76:           # Export required variables for set-k8s-env.sh (matching setup-application.sh)
 77:           echo "BACKEND_FILE=backend.hcl" >> $GITHUB_ENV
 78:           echo "VARIABLES_FILE=variables.tfvars" >> $GITHUB_ENV
 79:           echo "ENVIRONMENT=${{ inputs.environment }}" >> $GITHUB_ENV
 80:           # Determine deployment account role ARN based on environment
 81:           if [ "${{ inputs.environment }}" = "prod" ]; then
 82:             echo "DEPLOYMENT_ROLE_ARN=${{ secrets.AWS_PRODUCTION_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 83:           else
 84:             echo "DEPLOYMENT_ROLE_ARN=${{ secrets.AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 85:           fi
 86:           echo "EXTERNAL_ID=${{ secrets.AWS_ASSUME_EXTERNAL_ID }}" >> $GITHUB_ENV
 87:           # Export state account role ARN for Route53/ACM access
 88:           echo "STATE_ACCOUNT_ROLE_ARN=${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}" >> $GITHUB_ENV
 89:       - name: Setup Docker Buildx
 90:         uses: docker/setup-buildx-action@v3
 91:       - name: Configure AWS credentials (State Account)
 92:         uses: aws-actions/configure-aws-credentials@v4
 93:         with:
 94:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
 95:           role-session-name: GitHubActions-ApplicationInfraProvision-State
 96:           aws-region: ${{ env.AWS_REGION }}
 97:       - name: Create backend.hcl from placeholder
 98:         run: |
 99:           # Only create if it doesn't exist (matching setup-application.sh behavior)
100:           if [ ! -f "backend.hcl" ]; then
101:             cp tfstate-backend-values-template.hcl backend.hcl
102:             sed -i -e "s|<BACKEND_BUCKET_NAME>|${{ vars.BACKEND_BUCKET_NAME }}|g" \
103:             -e "s|<APPLICATION_PREFIX>|${{ vars.APPLICATION_PREFIX }}|g" \
104:             -e "s|<AWS_REGION>|${{ env.AWS_REGION }}|g" \
105:             backend.hcl
106:             echo "Created backend.hcl:"
107:             cat backend.hcl
108:           else
109:             echo "backend.hcl already exists. Skipping creation."
110:           fi
111:       - name: Terraform init
112:         run: terraform init -backend-config=backend.hcl
113:       - name: Terraform workspace
114:         run: |
115:           WORKSPACE="${{ env.AWS_REGION }}-${{ inputs.environment }}"
116:           terraform workspace select $WORKSPACE || terraform workspace new $WORKSPACE
117:       - name: Terraform validate
118:         run: terraform validate
119:       - name: Mirror Docker images to ECR
120:         run: |
121:           # Mirror third-party images to ECR (if not already present)
122:           # This script:
123:           # 1. Fetches ECR URL from backend_infra state (using State Account credentials)
124:           # 2. Assumes Deployment Account role for ECR operations
125:           # 3. Checks if images exist, mirrors only missing ones
126:           chmod +x ./mirror-images-to-ecr.sh
127:           ./mirror-images-to-ecr.sh
128:       - name: Set Kubernetes environment variables
129:         run: |
130:           # set-k8s-env.sh expects State Account credentials to be active for S3 operations
131:           # It will assume Deployment Account role internally for EKS operations
132:           chmod +x ./set-k8s-env.sh
133:           source ./set-k8s-env.sh
134:           # Export as TF_VAR_ environment variables for Terraform
135:           echo "TF_VAR_kubernetes_master=$KUBERNETES_MASTER" >> $GITHUB_ENV
136:           echo "TF_VAR_kube_config_path=$KUBE_CONFIG_PATH" >> $GITHUB_ENV
137:       - name: Configure AWS credentials (State Account for Terraform)
138:         uses: aws-actions/configure-aws-credentials@v4
139:         with:
140:           role-to-assume: ${{ secrets.AWS_STATE_ACCOUNT_ROLE_ARN }}
141:           role-session-name: GitHubActions-ApplicationInfraProvision-Terraform
142:           aws-region: ${{ env.AWS_REGION }}
143:       - name: Terraform plan
144:         run: terraform plan -var-file="variables.tfvars" -out terraform.tfplan
145:       - name: Provision application infrastructure
146:         run: terraform apply -auto-approve terraform.tfplan
```

## File: docs/index.html
```html
   1: <!DOCTYPE html>
   2: <html lang="en">
   3: <head>
   4:     <meta charset="UTF-8">
   5:     <meta name="viewport" content="width=device-width, initial-scale=1.0">
   6:     <title>LDAP 2FA on Kubernetes - Documentation</title>
   7:     <link rel="icon" type="image/x-icon" href="favicon.ico">
   8:     <link rel="stylesheet" href="light-theme.css" id="theme-stylesheet">
   9: </head>
  10: <body>
  11:     <!-- Sticky Navigation -->
  12:     <nav class="navbar">
  13:         <div class="nav-container">
  14:             <a href="#hero" class="nav-logo">LDAP 2FA on K8s</a>
  15:             <button class="mobile-menu-toggle" id="mobileMenuToggle">☰</button>
  16:             <ul class="nav-menu" id="navMenu">
  17:                 <li><a href="#content-index">Content Index</a></li>
  18:                 <li><a href="#overview">Overview</a></li>
  19:                 <li><a href="#getting-started">Getting Started</a></li>
  20:                 <li><a href="#architecture">Architecture</a></li>
  21:                 <li><a href="#documentation">Documentation</a></li>
  22:                 <li><a href="#access">Access</a></li>
  23:                 <li><a href="#security">Security</a></li>
  24:                 <li><a href="#support">Support</a></li>
  25:                 <li>
  26:                     <button class="theme-toggle" id="themeToggle" aria-label="Toggle theme">
  27:                         <span class="icon" id="sunIcon" title="Switch to light theme">☀️</span>
  28:                         <span class="icon hidden" id="moonIcon" title="Switch to dark theme">🌙</span>
  29:                     </button>
  30:                 </li>
  31:             </ul>
  32:         </div>
  33:     </nav>
  34:     <!-- Hero Section -->
  35:     <section id="hero" class="hero">
  36:         <div class="hero-content">
  37:             <h1>LDAP Authentication with 2FA on Kubernetes</h1>
  38:             <p>Complete LDAP authentication solution with two-factor authentication, self-service password management, and GitOps capabilities on Amazon EKS</p>
  39:             <img src="header_banner.png" alt="Project Banner" class="hero-banner">
  40:         </div>
  41:     </section>
  42:     <!-- Content Index -->
  43:     <section id="content-index">
  44:         <h2>Content Index</h2>
  45:         <div class="card">
  46:             <ul>
  47:                 <li><a href="#overview">Project Overview</a>
  48:                     <ul>
  49:                         <li><a href="#core-infrastructure">Core Infrastructure</a></li>
  50:                         <li><a href="#ldap-stack">LDAP Stack</a></li>
  51:                         <li><a href="#2fa-application">2FA Application</a></li>
  52:                         <li><a href="#supporting-infrastructure">Supporting Infrastructure</a></li>
  53:                         <li><a href="#devops-security">DevOps & Security</a></li>
  54:                         <li><a href="#key-features">Key Features</a></li>
  55:                     </ul>
  56:                 </li>
  57:                 <li><a href="#getting-started">Getting Started</a>
  58:                     <ul>
  59:                         <li><a href="#prerequisites">Prerequisites</a></li>
  60:                         <li><a href="#deployment-options">Deployment Options</a>
  61:                             <ul>
  62:                                 <li><a href="#local-deployment">Local Deployment</a>
  63:                                     <ul>
  64:                                         <li><a href="#local-step-1">Step 1: Deploy Terraform Backend State Infrastructure</a></li>
  65:                                         <li><a href="#local-step-2">Step 2: Deploy Backend Infrastructure</a></li>
  66:                                         <li><a href="#local-step-3">Step 3: Deploy Application Infrastructure</a></li>
  67:                                         <li><a href="#local-destroy">Destroying Infrastructure (Local)</a></li>
  68:                                     </ul>
  69:                                 </li>
  70:                                 <li><a href="#github-actions-deployment">GitHub Actions Deployment</a>
  71:                                     <ul>
  72:                                         <li><a href="#github-step-1">Step 1: Deploy Terraform Backend State Infrastructure</a></li>
  73:                                         <li><a href="#github-step-2">Step 2: Deploy Backend Infrastructure</a></li>
  74:                                         <li><a href="#github-step-3">Step 3: Deploy Application Infrastructure</a></li>
  75:                                         <li><a href="#github-destroy">Destroying Infrastructure (GitHub Actions)</a></li>
  76:                                     </ul>
  77:                                 </li>
  78:                             </ul>
  79:                         </li>
  80:                         <li><a href="#deployment-comparison">Deployment Comparison</a></li>
  81:                         <li><a href="#deployment-order">Deployment Order</a></li>
  82:                     </ul>
  83:                 </li>
  84:                 <li><a href="#architecture">Architecture</a>
  85:                     <ul>
  86:                         <li><a href="#multi-account-architecture">Multi-Account Architecture</a></li>
  87:                         <li><a href="#how-it-works">How It Works</a></li>
  88:                         <li><a href="#project-structure">Project Structure</a></li>
  89:                         <li><a href="#backend-infrastructure-components">Backend Infrastructure Components</a></li>
  90:                         <li><a href="#application-infrastructure-components">Application Infrastructure Components</a></li>
  91:                     </ul>
  92:                 </li>
  93:                 <li><a href="#documentation">Documentation</a>
  94:                     <ul>
  95:                         <li><a href="#infrastructure-documentation">Infrastructure Documentation</a></li>
  96:                         <li><a href="#application-documentation">Application Documentation</a></li>
  97:                         <li><a href="#module-documentation">Module Documentation</a></li>
  98:                         <li><a href="#configuration-documentation">Configuration Documentation</a></li>
  99:                         <li><a href="#security-operations">Security & Operations</a></li>
 100:                     </ul>
 101:                 </li>
 102:                 <li><a href="#access">Accessing the Services</a>
 103:                     <ul>
 104:                         <li><a href="#2fa-application-access">2FA Application</a></li>
 105:                         <li><a href="#phpldapadmin-access">PhpLdapAdmin</a></li>
 106:                         <li><a href="#ltb-passwd-access">LTB-passwd</a></li>
 107:                         <li><a href="#argocd-access">ArgoCD</a></li>
 108:                         <li><a href="#ldap-service-access">LDAP Service</a></li>
 109:                         <li><a href="#mfa-methods">MFA Methods</a></li>
 110:                     </ul>
 111:                 </li>
 112:                 <li><a href="#security">Security Considerations</a>
 113:                     <ul>
 114:                         <li><a href="#key-security-features">Key Security Features</a></li>
 115:                     </ul>
 116:                 </li>
 117:                 <li><a href="#support">Contributing & Support</a>
 118:                     <ul>
 119:                         <li><a href="#troubleshooting">Troubleshooting</a></li>
 120:                         <li><a href="#repository">Repository</a></li>
 121:                         <li><a href="#license">License</a></li>
 122:                     </ul>
 123:                 </li>
 124:             </ul>
 125:         </div>
 126:     </section>
 127:     <!-- Project Overview -->
 128:     <section id="overview">
 129:         <h2>Project Overview</h2>
 130:         <div class="card">
 131:             <p>This project deploys a complete LDAP authentication solution with two-factor authentication (2FA), self-service password management, and GitOps capabilities on Amazon EKS using Terraform.</p>
 132:         </div>
 133:         <h3 id="core-infrastructure">Core Infrastructure</h3>
 134:         <div class="card">
 135:             <ul>
 136:                 <li><strong>EKS Cluster</strong> (Auto Mode) with IRSA for secure pod-to-AWS-service authentication</li>
 137:                 <li><strong>VPC</strong> with public/private subnets and VPC endpoints for private AWS service access</li>
 138:                 <li><strong>Application Load Balancer (ALB)</strong> via EKS Auto Mode for internet-facing access</li>
 139:                 <li><strong>Route53 DNS</strong> integration for domain management</li>
 140:                 <li><strong>ACM Certificates</strong> for HTTPS/TLS termination</li>
 141:             </ul>
 142:         </div>
 143:         <h3 id="ldap-stack">LDAP Stack</h3>
 144:         <div class="card">
 145:             <ul>
 146:                 <li><strong>OpenLDAP Stack</strong> with high availability and multi-master replication</li>
 147:                 <li><strong>PhpLdapAdmin</strong> web interface for LDAP administration</li>
 148:                 <li><strong>LTB-passwd</strong> self-service password management UI</li>
 149:             </ul>
 150:         </div>
 151:         <h3 id="2fa-application">2FA Application</h3>
 152:         <div class="card">
 153:             <ul>
 154:                 <li><strong>Full-stack 2FA application</strong> with Python FastAPI backend and static HTML/JS/CSS frontend</li>
 155:                 <li><strong>Dual MFA methods</strong>: TOTP (authenticator apps) and SMS (AWS SNS)</li>
 156:                 <li><strong>LDAP integration</strong> for centralized user authentication</li>
 157:                 <li><strong>Self-service user registration</strong> with email/phone verification and profile state management</li>
 158:                 <li><strong>Admin dashboard</strong> for user management, group CRUD operations, and approval workflows</li>
 159:                 <li><strong>User profile management</strong> with edit restrictions for verified fields</li>
 160:                 <li><strong>Interactive API documentation</strong> via Swagger UI and ReDoc (always enabled)</li>
 161:             </ul>
 162:         </div>
 163:         <h3 id="supporting-infrastructure">Supporting Infrastructure</h3>
 164:         <div class="card">
 165:             <ul>
 166:                 <li><strong>PostgreSQL</strong> (Bitnami Helm chart, OCI registry) for user registration data and email verification token storage with persistent EBS-backed storage</li>
 167:                 <li><strong>Redis</strong> (Bitnami Helm chart) for SMS OTP code storage with TTL-based automatic expiration and shared state across replicas</li>
 168:                 <li><strong>AWS SES</strong> for email verification and notifications with IRSA-based access (no hardcoded credentials)</li>
 169:                 <li><strong>AWS SNS</strong> for SMS-based 2FA verification (optional, requires SNS VPC endpoint enabled in backend infrastructure)</li>
 170:             </ul>
 171:         </div>
 172:         <h3 id="devops-security">DevOps & Security</h3>
 173:         <div class="card">
 174:             <ul>
 175:                 <li><strong>ArgoCD</strong> (AWS EKS managed service) for GitOps deployments with AWS Identity Center authentication</li>
 176:                 <li><strong>cert-manager</strong> for automatic TLS certificate management</li>
 177:                 <li><strong>Network Policies</strong> for securing pod-to-pod communication with cross-namespace support</li>
 178:                 <li><strong>IRSA</strong> (IAM Roles for Service Accounts) for secure AWS API access from pods without credentials</li>
 179:                 <li><strong>VPC Endpoints</strong> for private AWS service access (SSM, STS, SNS) without internet exposure</li>
 180:                 <li><strong>Multi-Account Architecture</strong> with separated state storage and deployment accounts</li>
 181:                 <li><strong>S3 File-Based Locking</strong> for Terraform state management (migrated from DynamoDB)</li>
 182:             </ul>
 183:         </div>
 184:         <h3 id="key-features">Key Features</h3>
 185:         <div class="card">
 186:             <ul>
 187:                 <li><strong>EKS Auto Mode</strong>: Simplified cluster management with automatic load balancer provisioning and built-in EBS CSI driver</li>
 188:                 <li><strong>Two-Factor Authentication</strong>: Full-stack 2FA application with dual MFA methods (TOTP and SMS)</li>
 189:                 <li><strong>Self-Service User Registration</strong>: Email and phone verification with profile state management (PENDING → COMPLETE → ACTIVE)</li>
 190:                 <li><strong>Admin Dashboard</strong>: User management, group CRUD operations, approval workflows, and user profile management</li>
 191:                 <li><strong>IRSA Integration</strong>: Secure AWS API access from pods without hardcoded credentials via OIDC</li>
 192:                 <li><strong>High Availability</strong>: Multi-master OpenLDAP replication with persistent storage</li>
 193:                 <li><strong>GitOps Ready</strong>: ArgoCD (AWS managed service) for declarative, Git-driven deployments</li>
 194:                 <li><strong>Multi-Account Architecture</strong>: Separation of state storage (Account A) and resource deployment (Account B) for enhanced security</li>
 195:                 <li><strong>API Documentation</strong>: Interactive Swagger UI and ReDoc always available at <code>/api/docs</code> and <code>/api/redoc</code> (always enabled, not just in debug mode)</li>
 196:                 <li><strong>Secrets Management</strong>: Passwords managed via GitHub repository secrets (for CI/CD) or AWS Secrets Manager (for local deployment) with automated retrieval</li>
 197:                 <li><strong>Public ACM Certificates</strong>: Uses public ACM certificates (Amazon-issued) with DNS validation for browser-trusted certificates (no security warnings)</li>
 198:                 <li><strong>Route53 Record Module</strong>: Dedicated module for Route53 A (alias) records with cross-account support and ALB zone_id mapping</li>
 199:             </ul>
 200:         </div>
 201:     </section>
 202:     <!-- Getting Started -->
 203:     <section id="getting-started">
 204:         <h2>Getting Started</h2>
 205:         <h3 id="prerequisites">Prerequisites</h3>
 206:         <div class="card">
 207:             <ul>
 208:                 <li><strong>AWS Account(s)</strong> with appropriate permissions
 209:                     <ul>
 210:                         <li><strong>State Account (Account A)</strong>: For Terraform state storage (S3)</li>
 211:                         <li><strong>Deployment Account (Account B)</strong>: For infrastructure resources (EKS, ALB, Route53, etc.)</li>
 212:                     </ul>
 213:                 </li>
 214:                 <li><strong>GitHub Account</strong> and repository fork: <a href="https://github.com/talorlik/ldap-2fa-on-k8s.git" target="_blank">ldap-2fa-on-k8s</a></li>
 215:                 <li><strong>AWS SSO/OIDC</strong> configured (see <a href="../README.md#github-repository-configuration">GitHub Repository Configuration</a>)</li>
 216:                 <li><strong>Route53 hosted zone</strong> must already exist (or create it manually)
 217:                     <ul>
 218:                         <li>Can be in State Account (different from deployment account) - automatically accessed via <code>state_account_role_arn</code></li>
 219:                         <li>See <a href="../application/CROSS-ACCOUNT-ACCESS.md">Cross-Account Access Documentation</a> for details</li>
 220:                     </ul>
 221:                 </li>
 222:                 <li><strong>Public ACM Certificate Setup</strong>: Public ACM certificates must be requested in each deployment account and validated using DNS records in the State Account's Route53 hosted zone
 223:                     <ul>
 224:                         <li>See <a href="../application/CROSS-ACCOUNT-ACCESS.md#public-acm-certificate-setup-and-dns-validation">Public ACM Certificate Setup and DNS Validation</a> for detailed setup instructions</li>
 225:                         <li>Includes step-by-step AWS CLI commands for requesting certificates, creating DNS validation records, and verifying certificate status</li>
 226:                         <li>Each deployment account (development, production) has its own public ACM certificate</li>
 227:                         <li>Certificates are automatically renewed by ACM</li>
 228:                     </ul>
 229:                 </li>
 230:                 <li><strong>ACM certificate</strong> must already exist and be validated in the same region as the EKS cluster
 231:                     <ul>
 232:                         <li>Certificate must be a public ACM certificate (Amazon-issued) requested in the Deployment Account</li>
 233:                         <li>Certificate must exist in the Deployment Account (not State Account)</li>
 234:                         <li>Certificate must be validated and in <code>ISSUED</code> status</li>
 235:                         <li>DNS validation records must be created in Route53 hosted zone in the State Account</li>
 236:                         <li>See <a href="../application/CROSS-ACCOUNT-ACCESS.md">Cross-Account Access Documentation</a> for details</li>
 237:                     </ul>
 238:                 </li>
 239:                 <li><strong>GitHub Secrets and Variables</strong> configured (see <a href="../SECRETS_REQUIREMENTS.md">Secrets Requirements</a> for complete details):
 240:                     <ul>
 241:                         <li><strong>Required Secrets:</strong>
 242:                             <ul>
 243:                                 <li><code>AWS_STATE_ACCOUNT_ROLE_ARN</code></li>
 244:                                 <li><code>AWS_PRODUCTION_ACCOUNT_ROLE_ARN</code></li>
 245:                                 <li><code>AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN</code></li>
 246:                                 <li><code>AWS_ASSUME_EXTERNAL_ID</code></li>
 247:                                 <li><code>TF_VAR_OPENLDAP_ADMIN_PASSWORD</code></li>
 248:                                 <li><code>TF_VAR_OPENLDAP_CONFIG_PASSWORD</code></li>
 249:                                 <li><code>TF_VAR_REDIS_PASSWORD</code></li>
 250:                                 <li><code>TF_VAR_POSTGRESQL_PASSWORD</code></li>
 251:                                 <li><code>GH_TOKEN</code></li>
 252:                             </ul>
 253:                         </li>
 254:                         <li><strong>Required Variables:</strong>
 255:                             <ul>
 256:                                 <li><code>AWS_REGION</code></li>
 257:                                 <li><code>BACKEND_PREFIX</code></li>
 258:                                 <li><code>APPLICATION_PREFIX</code></li>
 259:                             </ul>
 260:                         </li>
 261:                     </ul>
 262:                 </li>
 263:                 <li><strong>For Local Deployment:</strong> GitHub CLI (<code>gh</code>), AWS CLI, Terraform, kubectl, and <code>jq</code> installed and configured</li>
 264:                 <li><strong>For Local Deployment:</strong> <strong>Docker</strong> must be installed and running for ECR image mirroring. The <code>mirror-images-to-ecr.sh</code> script requires Docker to pull images from Docker Hub and push them to ECR. This step is automatically executed by <code>setup-application.sh</code> before Terraform operations.</li>
 265:                 <li><strong>For Local Deployment:</strong> AWS Secrets Manager configured with <code>github-role</code>, <code>tf-vars</code>, and <code>external-id</code> secrets (see <a href="../SECRETS_REQUIREMENTS.md">Secrets Requirements</a>)</li>
 266:             </ul>
 267:             <p><strong>For detailed prerequisites and setup:</strong> <a href="../README.md#prerequisites">Prerequisites</a> | <a href="../README.md#secrets-configuration">Secrets Configuration</a> | <a href="../SECRETS_REQUIREMENTS.md">Secrets Requirements</a></p>
 268:         </div>
 269:         <h3 id="deployment-options">Deployment Options</h3>
 270:         <div class="deployment-options">
 271:             <div class="deployment-card">
 272:                 <h4 id="local-deployment">Local Deployment</h4>
 273:                 <p><strong>Recommended for:</strong> Development, testing, and local experimentation</p>
 274:                 <h5 id="local-step-1">Step 1: Deploy Terraform Backend State Infrastructure</h5>
 275:                 <p>Deploy the S3 bucket for Terraform state storage:</p>
 276:                 <pre><code>cd tf_backend_state
 277: ./set-state.sh</code></pre>
 278:                 <p><strong>What the script does:</strong></p>
 279:                 <ul>
 280:                     <li>Retrieves <code>AWS_STATE_ACCOUNT_ROLE_ARN</code> from AWS Secrets Manager</li>
 281:                     <li>Retrieves <code>AWS_REGION</code> and <code>BACKEND_PREFIX</code> from GitHub repository variables</li>
 282:                     <li>Assumes the IAM role and verifies credentials</li>
 283:                     <li>Checks if infrastructure exists (via <code>BACKEND_BUCKET_NAME</code> variable)</li>
 284:                     <li>If new: Runs Terraform init, validate, plan, and apply to create S3 bucket</li>
 285:                     <li>If exists: Downloads existing state file from S3 (if available)</li>
 286:                     <li>Saves/updates <code>BACKEND_BUCKET_NAME</code> to GitHub repository variables</li>
 287:                     <li>Uploads state file to S3</li>
 288:                 </ul>
 289:                 <p><strong>Alternative:</strong> Use <code>./get-state.sh</code> to download existing state file without provisioning</p>
 290:                 <h5 id="local-step-2">Step 2: Deploy Backend Infrastructure</h5>
 291:                 <p>Deploy VPC, EKS cluster, VPC endpoints, IRSA, and ECR:</p>
 292:                 <pre><code>cd backend_infra
 293: ./setup-backend.sh</code></pre>
 294:                 <p><strong>What the script does:</strong></p>
 295:                 <ul>
 296:                     <li>Prompts for AWS region (us-east-1 or us-east-2) and environment (prod or dev)</li>
 297:                     <li>Retrieves repository variables from GitHub (<code>BACKEND_BUCKET_NAME</code>, <code>BACKEND_PREFIX</code>)</li>
 298:                     <li>Retrieves role ARNs from AWS Secrets Manager (<code>github-role</code> secret)</li>
 299:                     <li>Retrieves ExternalId from AWS Secrets Manager (<code>external-id</code> secret)</li>
 300:                     <li>Assumes State Account role for backend operations</li>
 301:                     <li>Generates <code>backend.hcl</code> from template (if it doesn't exist)</li>
 302:                     <li>Updates <code>variables.tfvars</code> with selected region, environment, deployment account role ARN, and ExternalId</li>
 303:                     <li>Runs Terraform init, workspace select/new, validate, plan, and apply</li>
 304:                 </ul>
 305:                 <h5 id="local-step-3">Step 3: Deploy Application Infrastructure</h5>
 306:                 <p>Deploy OpenLDAP stack, 2FA application, ALB, Route53 records, and supporting services:</p>
 307:                 <pre><code>cd application
 308: ./setup-application.sh</code></pre>
 309:                 <p><strong>What the script does:</strong></p>
 310:                 <ul>
 311:                     <li>Prompts for AWS region (us-east-1 or us-east-2) and environment (prod or dev)</li>
 312:                     <li>Retrieves repository variables from GitHub (<code>BACKEND_BUCKET_NAME</code>, <code>APPLICATION_PREFIX</code>)</li>
 313:                     <li><strong>Mirrors Docker images to ECR</strong> (runs <code>mirror-images-to-ecr.sh</code> before Terraform operations):
 314:                         <ul>
 315:                             <li>Checks if images exist in ECR before mirroring (skips if already present)</li>
 316:                             <li>Pulls images from Docker Hub: <code>bitnami/redis:8.4.0-debian-12-r6</code>, <code>bitnami/postgresql:18.1.0-debian-12-r4</code>, <code>osixia/openldap:1.5.0</code></li>
 317:                             <li>Pushes images to ECR with tags: <code>redis-latest</code>, <code>postgresql-latest</code>, <code>openldap-1.5.0</code></li>
 318:                             <li>Uses State Account credentials to fetch ECR URL from backend_infra state</li>
 319:                             <li>Assumes Deployment Account role for ECR operations (with ExternalId)</li>
 320:                             <li>Authenticates Docker to ECR automatically</li>
 321:                             <li>Cleans up local images after pushing to save disk space</li>
 322:                             <li>Requires Docker to be installed and running</li>
 323:                             <li>Requires <code>jq</code> for JSON parsing (with fallback to sed for compatibility)</li>
 324:                         </ul>
 325:                     </li>
 326:                     <li>Retrieves role ARNs and ExternalId from AWS Secrets Manager</li>
 327:                     <li>Retrieves password secrets from AWS Secrets Manager (<code>tf-vars</code> secret) and exports as environment variables:
 328:                         <ul>
 329:                             <li><code>TF_VAR_openldap_admin_password</code></li>
 330:                             <li><code>TF_VAR_openldap_config_password</code></li>
 331:                             <li><code>TF_VAR_postgresql_database_password</code></li>
 332:                             <li><code>TF_VAR_redis_password</code></li>
 333:                         </ul>
 334:                     </li>
 335:                     <li>Assumes State Account role for backend operations</li>
 336:                     <li>Generates <code>backend.hcl</code> from template (if it doesn't exist)</li>
 337:                     <li>Updates <code>variables.tfvars</code> with selected values</li>
 338:                     <li>Sets Kubernetes environment variables using <code>set-k8s-env.sh</code></li>
 339:                     <li>Runs Terraform init, workspace select/new, validate, plan, and apply</li>
 340:                 </ul>
 341:                 <h5 id="local-destroy">Destroying Infrastructure (Local)</h5>
 342:                 <p><strong>⚠️ Warning:</strong> Destroy operations are permanent and cannot be undone. Always destroy in reverse order.</p>
 343:                 <ol>
 344:                     <li><strong>Destroy Application Infrastructure:</strong>
 345:                         <pre><code>cd application
 346: ./destroy-application.sh</code></pre>
 347:                         <p>Script will prompt for region and environment, then require confirmation ('yes', then 'DESTROY')</p>
 348:                     </li>
 349:                     <li><strong>Destroy Backend Infrastructure:</strong>
 350:                         <pre><code>cd backend_infra
 351: ./destroy-backend.sh</code></pre>
 352:                         <p>Script will prompt for region and environment, then require confirmation ('yes', then 'DESTROY')</p>
 353:                     </li>
 354:                     <li><strong>Destroy State Backend (if needed):</strong>
 355:                         <pre><code>cd tf_backend_state
 356: ./get-state.sh  # Download state file first
 357: terraform plan -var-file="variables.tfvars" -destroy -out terraform.tfplan
 358: terraform apply -auto-approve terraform.tfplan</code></pre>
 359:                     </li>
 360:                 </ol>
 361:                 <p><strong>For detailed local setup instructions:</strong> <a href="../README.md#method-2-local-development">Local Development Setup</a> | <a href="../tf_backend_state/README.md#option-2-local-execution">Terraform Backend State Local Execution</a></p>
 362:             </div>
 363:             <div class="deployment-card">
 364:                 <h4 id="github-actions-deployment">GitHub Actions Deployment</h4>
 365:                 <p><strong>Recommended for:</strong> Production deployments, CI/CD pipelines, automated workflows</p>
 366:                 <h5 id="github-step-1">Step 1: Deploy Terraform Backend State Infrastructure</h5>
 367:                 <ol>
 368:                     <li>Go to GitHub → <strong>Actions</strong> tab</li>
 369:                     <li>Select <strong>"TF Backend State Provisioning"</strong> workflow</li>
 370:                     <li>Click <strong>"Run workflow"</strong> → <strong>"Run workflow"</strong></li>
 371:                     <li>Monitor the workflow execution</li>
 372:                 </ol>
 373:                 <p><strong>What the workflow does:</strong></p>
 374:                 <ul>
 375:                     <li>Uses <code>AWS_STATE_ACCOUNT_ROLE_ARN</code> secret for OIDC authentication</li>
 376:                     <li>Validates Terraform configuration</li>
 377:                     <li>Creates S3 bucket with versioning and encryption</li>
 378:                     <li>Saves bucket name as <code>BACKEND_BUCKET_NAME</code> repository variable</li>
 379:                     <li>Uploads state file to S3</li>
 380:                 </ul>
 381:                 <h5 id="github-step-2">Step 2: Deploy Backend Infrastructure</h5>
 382:                 <ol>
 383:                     <li>Go to GitHub → <strong>Actions</strong> tab</li>
 384:                     <li>Select <strong>"Backend Infra Provisioning"</strong> workflow</li>
 385:                     <li>Click <strong>"Run workflow"</strong></li>
 386:                     <li>Select <strong>region</strong> (us-east-1: N. Virginia or us-east-2: Ohio)</li>
 387:                     <li>Select <strong>environment</strong> (prod or dev)</li>
 388:                     <li>Click <strong>"Run workflow"</strong></li>
 389:                     <li>Monitor the workflow execution</li>
 390:                 </ol>
 391:                 <p><strong>What the workflow does:</strong></p>
 392:                 <ul>
 393:                     <li>Uses <code>AWS_STATE_ACCOUNT_ROLE_ARN</code> for backend state operations</li>
 394:                     <li>Uses environment-specific deployment account role ARN (<code>AWS_PRODUCTION_ACCOUNT_ROLE_ARN</code> or <code>AWS_DEVELOPMENT_ACCOUNT_ROLE_ARN</code>)</li>
 395:                     <li>Uses <code>AWS_ASSUME_EXTERNAL_ID</code> for cross-account role assumption</li>
 396:                     <li>Runs Terraform operations to deploy VPC, EKS, VPC endpoints, IRSA, and ECR</li>
 397:                 </ul>
 398:                 <h5 id="github-step-3">Step 3: Deploy Application Infrastructure</h5>
 399:                 <ol>
 400:                     <li>Go to GitHub → <strong>Actions</strong> tab</li>
 401:                     <li>Select <strong>"Application Infra Provisioning"</strong> workflow</li>
 402:                     <li>Click <strong>"Run workflow"</strong></li>
 403:                     <li>Select <strong>region</strong> (us-east-1: N. Virginia or us-east-2: Ohio)</li>
 404:                     <li>Select <strong>environment</strong> (prod or dev)</li>
 405:                     <li>Click <strong>"Run workflow"</strong></li>
 406:                     <li>Monitor the workflow execution</li>
 407:                 </ol>
 408:                 <p><strong>What the workflow does:</strong></p>
 409:                 <ul>
 410:                     <li>Uses <code>AWS_STATE_ACCOUNT_ROLE_ARN</code> for backend state operations</li>
 411:                     <li>Uses environment-specific deployment account role ARN</li>
 412:                     <li>Uses <code>AWS_ASSUME_EXTERNAL_ID</code> for cross-account role assumption</li>
 413:                     <li>Retrieves password secrets from GitHub repository secrets</li>
 414:                     <li>Runs Terraform operations to deploy OpenLDAP, 2FA app, ALB, Route53, and supporting services</li>
 415:                 </ul>
 416:                 <h5 id="github-destroy">Destroying Infrastructure (GitHub Actions)</h5>
 417:                 <p><strong>⚠️ Warning:</strong> Destroy operations are permanent and cannot be undone. Always destroy in reverse order.</p>
 418:                 <ol>
 419:                     <li><strong>Destroy Application Infrastructure:</strong>
 420:                         <ul>
 421:                             <li>Go to GitHub → <strong>Actions</strong> tab</li>
 422:                             <li>Select <strong>"Application Infra Destroying"</strong> workflow</li>
 423:                             <li>Click <strong>"Run workflow"</strong></li>
 424:                             <li>Select environment (prod or dev) and region</li>
 425:                             <li>Click <strong>"Run workflow"</strong></li>
 426:                         </ul>
 427:                     </li>
 428:                     <li><strong>Destroy Backend Infrastructure:</strong>
 429:                         <ul>
 430:                             <li>Go to GitHub → <strong>Actions</strong> tab</li>
 431:                             <li>Select <strong>"Backend Infra Destroying"</strong> workflow</li>
 432:                             <li>Click <strong>"Run workflow"</strong></li>
 433:                             <li>Select environment (prod or dev) and region</li>
 434:                             <li>Click <strong>"Run workflow"</strong></li>
 435:                         </ul>
 436:                     </li>
 437:                     <li><strong>Destroy State Backend (if needed):</strong>
 438:                         <ul>
 439:                             <li>Go to GitHub → <strong>Actions</strong> tab</li>
 440:                             <li>Select <strong>"TF Backend State Destroying"</strong> workflow</li>
 441:                             <li>Click <strong>"Run workflow"</strong> → <strong>"Run workflow"</strong></li>
 442:                         </ul>
 443:                     </li>
 444:                 </ol>
 445:                 <p><strong>For detailed GitHub Actions setup:</strong> <a href="../README.md#github-repository-configuration">GitHub Repository Configuration</a> | <a href="../README.md#method-1-github-actions-cicd">GitHub Actions Deployment</a></p>
 446:             </div>
 447:         </div>
 448:         <h3 id="deployment-comparison">Deployment Comparison</h3>
 449:         <table>
 450:             <thead>
 451:                 <tr>
 452:                     <th>Feature</th>
 453:                     <th>Local Deployment</th>
 454:                     <th>GitHub Actions</th>
 455:                 </tr>
 456:             </thead>
 457:             <tbody>
 458:                 <tr>
 459:                     <td>Setup Complexity</td>
 460:                     <td>Medium (requires local tools)</td>
 461:                     <td>Low (web-based)</td>
 462:                 </tr>
 463:                 <tr>
 464:                     <td>Best For</td>
 465:                     <td>Development, testing</td>
 466:                     <td>Production, CI/CD</td>
 467:                 </tr>
 468:                 <tr>
 469:                     <td>Requires GitHub CLI</td>
 470:                     <td>Yes</td>
 471:                     <td>No</td>
 472:                 </tr>
 473:                 <tr>
 474:                     <td>Requires GitHub Secrets</td>
 475:                     <td>Optional (can use env vars)</td>
 476:                     <td>Required</td>
 477:                 </tr>
 478:                 <tr>
 479:                     <td>Automation Level</td>
 480:                     <td>Script-based</td>
 481:                     <td>Fully automated</td>
 482:                 </tr>
 483:             </tbody>
 484:         </table>
 485:         <h3 id="deployment-order">Deployment Order</h3>
 486:         <div class="card">
 487:             <p>The deployment follows a <strong>three-tier approach</strong> that must be executed in order. Each tier depends on the previous one:</p>
 488:             <ol>
 489:                 <li><strong>Deploy Terraform Backend State Infrastructure</strong>
 490:                     <ul>
 491:                         <li><strong>Purpose:</strong> Creates S3 bucket for storing Terraform state files</li>
 492:                         <li><strong>Components:</strong> S3 bucket with versioning, encryption, and file-based locking</li>
 493:                         <li><strong>Account:</strong> State Account (Account A)</li>
 494:                         <li><strong>Local:</strong> <code>cd tf_backend_state && ./set-state.sh</code></li>
 495:                         <li><strong>GitHub Actions:</strong> "TF Backend State Provisioning" workflow</li>
 496:                         <li><strong>See:</strong> <a href="../tf_backend_state/README.md">Terraform Backend State README</a></li>
 497:                     </ul>
 498:                 </li>
 499:                 <li><strong>Deploy Backend Infrastructure</strong>
 500:                     <ul>
 501:                         <li><strong>Purpose:</strong> Creates foundational AWS infrastructure for Kubernetes workloads</li>
 502:                         <li><strong>Components:</strong> VPC with public/private subnets, EKS cluster (Auto Mode), VPC endpoints (SSM, STS, SNS), IRSA (OIDC provider), ECR repository</li>
 503:                         <li><strong>Account:</strong> Deployment Account (Account B)</li>
 504:                         <li><strong>Prerequisites:</strong> Terraform backend state must be deployed first</li>
 505:                         <li><strong>Local:</strong> <code>cd backend_infra && ./setup-backend.sh</code></li>
 506:                         <li><strong>GitHub Actions:</strong> "Backend Infra Provisioning" workflow</li>
 507:                         <li><strong>See:</strong> <a href="../backend_infra/README.md">Backend Infrastructure README</a></li>
 508:                     </ul>
 509:                 </li>
 510:                 <li><strong>Deploy Application Infrastructure</strong>
 511:                     <ul>
 512:                         <li><strong>Purpose:</strong> Deploys LDAP stack, 2FA application, and supporting services on the EKS cluster</li>
 513:                         <li><strong>Components:</strong> OpenLDAP stack (HA), PhpLdapAdmin, LTB-passwd, 2FA application (backend + frontend), ALB, Route53 records, PostgreSQL, Redis, SES, SNS (optional), ArgoCD (optional)</li>
 514:                         <li><strong>Account:</strong> Deployment Account (Account B)</li>
 515:                         <li><strong>Prerequisites:</strong> Backend infrastructure (EKS cluster) must be deployed first</li>
 516:                         <li><strong>Additional Requirements:</strong> Route53 hosted zone and ACM certificate must exist
 517:                             <ul>
 518:                                 <li>Route53 hosted zone and ACM certificate can be in State Account (different from deployment account)</li>
 519:                                 <li>Automatically accessed via <code>state_account_role_arn</code> (injected by scripts/workflows)</li>
 520:                                 <li>See <a href="../application/CROSS-ACCOUNT-ACCESS.md">Cross-Account Access Documentation</a> for configuration details</li>
 521:                             </ul>
 522:                         </li>
 523:                         <li><strong>Local:</strong> <code>cd application && ./setup-application.sh</code></li>
 524:                         <li><strong>GitHub Actions:</strong> "Application Infra Provisioning" workflow</li>
 525:                         <li><strong>See:</strong> <a href="../application/README.md">Application Infrastructure README</a></li>
 526:                     </ul>
 527:                 </li>
 528:             </ol>
 529:             <p><strong>Destroy Order:</strong> Always destroy in <strong>reverse order</strong>: Application → Backend → State</p>
 530:             <p><strong>For detailed deployment information:</strong> <a href="../README.md#deployment-methods">Deployment Methods</a> | <a href="../README.md#deployment-overview">Deployment Overview</a></p>
 531:         </div>
 532:     </section>
 533:     <!-- Architecture -->
 534:     <section id="architecture">
 535:         <h2>Architecture</h2>
 536:         <h3 id="multi-account-architecture">Multi-Account Architecture</h3>
 537:         <div class="card">
 538:             <p>This project uses a <strong>multi-account architecture</strong> for enhanced security:</p>
 539:             <ul>
 540:                 <li><strong>Account A (State Account)</strong>: Stores Terraform state files in S3
 541:                     <ul>
 542:                         <li>S3 bucket with versioning and server-side encryption (AES256)</li>
 543:                         <li>S3 file-based locking (<code>use_lockfile = true</code>) for state concurrency control</li>
 544:                         <li>GitHub Actions authenticates with Account A via OIDC for backend operations</li>
 545:                         <li>Provides isolation between state storage and resource deployment</li>
 546:                         <li>IAM-based access control with OIDC authentication (no access keys required)</li>
 547:                     </ul>
 548:                 </li>
 549:                 <li><strong>Account B (Deployment Account)</strong>: Contains all infrastructure resources
 550:                     <ul>
 551:                         <li>EKS cluster, VPC, ALB, Route53, and other AWS resources</li>
 552:                         <li>Separate roles for production and development environments</li>
 553:                         <li>Terraform provider assumes Account B role via cross-account role assumption</li>
 554:                         <li>Provides isolation and separation of concerns</li>
 555:                     </ul>
 556:                 </li>
 557:             </ul>
 558:             <p><strong>For detailed architecture documentation:</strong> <a href="../README.md#multi-account-architecture">Multi-Account Architecture</a> | <a href="../tf_backend_state/README.md">Terraform Backend State README</a></p>
 559:         </div>
 560:         <h3 id="how-it-works">How It Works</h3>
 561:         <div class="card">
 562:             <p>The multi-account architecture enables secure separation of concerns:</p>
 563:             <ol>
 564:                 <li><strong>GitHub Actions</strong> authenticates with Account A via OIDC (no access keys required) for Terraform backend access</li>
 565:                 <li><strong>Terraform backend</strong> uses Account A credentials to read/write state files in S3</li>
 566:                 <li><strong>Terraform AWS provider</strong> assumes Account B role (via <code>assume_role</code> with ExternalId) for resource deployment</li>
 567:                 <li><strong>Remote state</strong> data sources use Account A credentials to read state from Account A, enabling cross-tier dependencies</li>
 568:             </ol>
 569:             <p>This architecture ensures state files are isolated in a dedicated account while resource deployment uses separate credentials, providing enhanced security and better compliance capabilities.</p>
 570:         </div>
 571:         <h3 id="project-structure">Project Structure</h3>
 572:         <pre><code>ldap-2fa-on-k8s/
 573: ├── SECRETS_REQUIREMENTS.md  # Secrets management documentation (AWS Secrets Manager & GitHub Secrets)
 574: ├── tf_backend_state/      # Terraform state backend infrastructure (S3) - Account A
 575: ├── backend_infra/         # Core AWS infrastructure (VPC, EKS, VPC endpoints, IRSA) - Account B
 576: ├── application/           # Application infrastructure and deployments - Account B
 577: │   ├── backend/           # 2FA Backend (Python FastAPI)
 578: │   ├── frontend/          # 2FA Frontend (HTML/JS/CSS + nginx)
 579: │   ├── helm/              # Helm values for OpenLDAP stack
 580: │   └── modules/           # Terraform modules (ALB, ArgoCD, SNS, cert-manager, etc.)
 581: └── .github/workflows/     # GitHub Actions workflows for CI/CD</code></pre>
 582:         <h3 id="backend-infrastructure-components">Backend Infrastructure Components</h3>
 583:         <div class="card">
 584:             <ul>
 585:                 <li><strong>VPC</strong> with public and private subnets across multiple availability zones</li>
 586:                 <li><strong>EKS Cluster</strong> in Auto Mode with automatic node provisioning and CloudWatch logging</li>
 587:                 <li><strong>IRSA (IAM Roles for Service Accounts)</strong> for secure pod-to-AWS-service authentication via OIDC</li>
 588:                 <li><strong>VPC Endpoints</strong> for private AWS service access:
 589:                     <ul>
 590:                         <li>SSM endpoints for secure node access (Session Manager)</li>
 591:                         <li>STS endpoint for IRSA (IAM role assumption) - enabled by default</li>
 592:                         <li>SNS endpoint for SMS 2FA (optional, requires <code>enable_sns_endpoint = true</code>)</li>
 593:                     </ul>
 594:                 </li>
 595:                 <li><strong>ECR Repository</strong> for container image storage with lifecycle policies</li>
 596:                 <li><strong>Terraform State Backend</strong> using S3 with file-based locking for state concurrency control (migrated from DynamoDB for simplicity and cost efficiency)</li>
 597:             </ul>
 598:         </div>
 599:         <h3 id="application-infrastructure-components">Application Infrastructure Components</h3>
 600:         <div class="card">
 601:             <ul>
 602:                 <li><strong>OpenLDAP Stack HA</strong> deployed via Helm chart with:
 603:                     <ul>
 604:                         <li>OpenLDAP StatefulSet (3 replicas for high availability)</li>
 605:                         <li>PhpLdapAdmin web interface</li>
 606:                         <li>LTB-passwd self-service password management</li>
 607:                     </ul>
 608:                 </li>
 609:                 <li><strong>2FA Application</strong> with LDAP authentication integration:
 610:                     <ul>
 611:                         <li>Python FastAPI backend with TOTP and SMS MFA support</li>
 612:                         <li>Static HTML/JS/CSS frontend with modern UI</li>
 613:                         <li>Single domain routing (<code>app.&lt;domain&gt;</code>) with path-based access</li>
 614:                         <li>Self-service user registration with email/phone verification</li>
 615:                         <li>Admin dashboard for user management and group operations</li>
 616:                         <li>Interactive API documentation (Swagger UI and ReDoc)</li>
 617:                     </ul>
 618:                 </li>
 619:                 <li><strong>Application Load Balancer (ALB)</strong> via EKS Auto Mode:
 620:                     <ul>
 621:                         <li>Internet-facing ALB with HTTPS/TLS termination</li>
 622:                         <li>Single ALB handles multiple Ingresses via host-based routing</li>
 623:                         <li>Automatic provisioning via IngressClass and IngressClassParams</li>
 624:                         <li>Certificate ARN and group name configured at cluster level</li>
 625:                     </ul>
 626:                 </li>
 627:                 <li><strong>PostgreSQL</strong> (Bitnami Helm chart) for user registration and verification token storage</li>
 628:                 <li><strong>Redis</strong> (Bitnami Helm chart) for SMS OTP code storage with TTL-based expiration</li>
 629:                 <li><strong>AWS SES</strong> integration for email verification and notifications (IRSA-based)</li>
 630:                 <li><strong>ArgoCD</strong> (AWS EKS managed service) for GitOps deployments with AWS Identity Center</li>
 631:                 <li><strong>cert-manager</strong> for automatic TLS certificate management</li>
 632:                 <li><strong>Network Policies</strong> for securing pod-to-pod communication with cross-namespace support</li>
 633:                 <li><strong>SNS Integration</strong> for SMS-based 2FA verification (optional, requires VPC endpoint)</li>
 634:                 <li><strong>Route53 DNS</strong> records for subdomains pointing to ALB</li>
 635:                 <li><strong>Persistent Storage</strong> using EBS-backed StorageClass</li>
 636:             </ul>
 637:             <p><strong>For detailed architecture documentation:</strong> <a href="../backend_infra/README.md">Backend Infrastructure README</a> | <a href="../application/README.md">Application Infrastructure README</a></p>
 638:         </div>
 639:     </section>
 640:     <!-- Documentation Index -->
 641:     <section id="documentation">
 642:         <h2>Documentation</h2>
 643:         <h3 id="infrastructure-documentation">Infrastructure Documentation</h3>
 644:         <div class="doc-grid">
 645:             <div class="doc-item">
 646:                 <a href="../tf_backend_state/README.md">Terraform Backend State</a>
 647:                 <p>S3 state management and GitHub variable configuration</p>
 648:             </div>
 649:             <div class="doc-item">
 650:                 <a href="../backend_infra/README.md">Backend Infrastructure</a>
 651:                 <p>VPC, EKS, IRSA, VPC endpoints, and ECR documentation</p>
 652:             </div>
 653:             <div class="doc-item">
 654:                 <a href="../application/README.md">Application Infrastructure</a>
 655:                 <p>OpenLDAP, 2FA app, ALB, ArgoCD, and deployment instructions</p>
 656:             </div>
 657:         </div>
 658:         <h3 id="application-documentation">Application Documentation</h3>
 659:         <div class="doc-grid">
 660:             <div class="doc-item">
 661:                 <a href="../application/PRD-2FA-APP.md">2FA Application PRD</a>
 662:                 <p>Product requirements for the 2FA application (API specs, frontend architecture, Swagger UI)</p>
 663:             </div>
 664:             <div class="doc-item">
 665:                 <a href="../application/PRD-SIGNUP-MAN.md">User Signup Management PRD</a>
 666:                 <p>Self-service user registration with email/phone verification and profile state management</p>
 667:             </div>
 668:             <div class="doc-item">
 669:                 <a href="../application/PRD-ADMIN-FUNCS.md">Admin Functions PRD</a>
 670:                 <p>Admin dashboard, group CRUD operations, user management, and approval workflows</p>
 671:             </div>
 672:             <div class="doc-item">
 673:                 <a href="../application/PRD-SMS-MAN.md">SMS OTP Management PRD</a>
 674:                 <p>Redis-based SMS OTP storage with TTL-based automatic expiration</p>
 675:             </div>
 676:             <div class="doc-item">
 677:                 <a href="../application/OPENLDAP-README.md">OpenLDAP README</a>
 678:                 <p>OpenLDAP configuration and TLS setup</p>
 679:             </div>
 680:             <div class="doc-item">
 681:                 <a href="../SECRETS_REQUIREMENTS.md">Secrets Requirements</a>
 682:                 <p>Complete guide for managing secrets via GitHub and AWS Secrets Manager</p>
 683:             </div>
 684:         </div>
 685:         <h3 id="module-documentation">Module Documentation</h3>
 686:         <div class="doc-grid">
 687:             <div class="doc-item">
 688:                 <a href="../application/modules/alb/README.md">ALB Module</a>
 689:                 <p>EKS Auto Mode ALB configuration</p>
 690:             </div>
 691:             <div class="doc-item">
 692:                 <a href="../application/modules/argocd/README.md">ArgoCD Module</a>
 693:                 <p>AWS managed ArgoCD setup</p>
 694:             </div>
 695:             <div class="doc-item">
 696:                 <a href="../application/modules/argocd_app/README.md">ArgoCD Application Module</a>
 697:                 <p>GitOps application deployment</p>
 698:             </div>
 699:             <div class="doc-item">
 700:                 <a href="../application/modules/cert-manager/README.md">cert-manager Module</a>
 701:                 <p>TLS certificate management</p>
 702:             </div>
 703:             <div class="doc-item">
 704:                 <a href="../application/modules/network-policies/README.md">Network Policies Module</a>
 705:                 <p>Pod-to-pod security</p>
 706:             </div>
 707:             <div class="doc-item">
 708:                 <a href="../application/modules/postgresql/README.md">PostgreSQL Module</a>
 709:                 <p>User data and verification token storage</p>
 710:             </div>
 711:             <div class="doc-item">
 712:                 <a href="../application/modules/redis/README.md">Redis Module</a>
 713:                 <p>SMS OTP code storage</p>
 714:             </div>
 715:             <div class="doc-item">
 716:                 <a href="../application/modules/ses/README.md">SES Module</a>
 717:                 <p>Email verification and notifications</p>
 718:             </div>
 719:             <div class="doc-item">
 720:                 <a href="../application/modules/sns/README.md">SNS Module</a>
 721:                 <p>SMS 2FA integration</p>
 722:             </div>
 723:             <div class="doc-item">
 724:                 <a href="../application/modules/route53_record/README.md">Route53 Record Module</a>
 725:                 <p>Route53 A (alias) records for ALB</p>
 726:             </div>
 727:             <div class="doc-item">
 728:                 <a href="../backend_infra/modules/endpoints/README.md">VPC Endpoints Module</a>
 729:                 <p>Private AWS service access</p>
 730:             </div>
 731:             <div class="doc-item">
 732:                 <a href="../backend_infra/modules/ecr/README.md">ECR Module</a>
 733:                 <p>Container registry setup</p>
 734:             </div>
 735:             <div class="doc-item">
 736:                 <a href="../backend_infra/modules/ebs/README.md">EBS Module</a>
 737:                 <p>EBS storage configuration</p>
 738:             </div>
 739:         </div>
 740:         <h3 id="configuration-documentation">Configuration Documentation</h3>
 741:         <div class="doc-grid">
 742:             <div class="doc-item">
 743:                 <a href="../application/PRD-ALB.md">ALB Configuration PRD</a>
 744:                 <p>Application Load Balancer configuration details</p>
 745:             </div>
 746:             <div class="doc-item">
 747:                 <a href="../application/PRD-ArgoCD.md">ArgoCD Configuration PRD</a>
 748:                 <p>GitOps deployment configuration</p>
 749:             </div>
 750:             <div class="doc-item">
 751:                 <a href="../application/PRD-DOMAIN.md">Domain Configuration PRD</a>
 752:                 <p>Route53 and domain setup</p>
 753:             </div>
 754:             <div class="doc-item">
 755:                 <a href="../application/PRD.md">Main PRD</a>
 756:                 <p>Application requirements document</p>
 757:             </div>
 758:         </div>
 759:         <h3 id="security-operations">Security & Operations</h3>
 760:         <div class="doc-grid">
 761:             <div class="doc-item">
 762:                 <a href="../application/SECURITY-IMPROVEMENTS.md">Security Improvements</a>
 763:                 <p>Security enhancements and best practices</p>
 764:             </div>
 765:             <div class="doc-item">
 766:                 <a href="../CHANGELOG.md">Project Changelog</a>
 767:                 <p>All project changes including latest features and improvements</p>
 768:             </div>
 769:             <div class="doc-item">
 770:                 <a href="../backend_infra/CHANGELOG.md">Backend Infrastructure Changelog</a>
 771:                 <p>Backend infrastructure changes (VPC, EKS, IRSA, VPC endpoints)</p>
 772:             </div>
 773:             <div class="doc-item">
 774:                 <a href="../application/CHANGELOG.md">Application Infrastructure Changelog</a>
 775:                 <p>Application infrastructure changes (2FA app, OpenLDAP, supporting services)</p>
 776:             </div>
 777:             <div class="doc-item">
 778:                 <a href="../tf_backend_state/CHANGELOG.md">Terraform Backend State Changelog</a>
 779:                 <p>S3 state management changes (v1.0.0 with file-based locking)</p>
 780:             </div>
 781:         </div>
 782:     </section>
 783:     <!-- Access Information -->
 784:     <section id="access">
 785:         <h2>Accessing the Services</h2>
 786:         <p>After deployment, the following services are available:</p>
 787:         <h3 id="2fa-application-access">2FA Application</h3>
 788:         <div class="card">
 789:             <p><strong>URL:</strong> <code>https://app.&lt;your-domain&gt;</code> (e.g., <code>https://app.example.com</code>)</p>
 790:             <p>The full-stack 2FA application provides:</p>
 791:             <ul>
 792:                 <li>Self-service user registration with email/phone verification and profile state management (PENDING → COMPLETE → ACTIVE)</li>
 793:                 <li>Two-factor authentication enrollment and login with dual MFA methods (TOTP and SMS)</li>
 794:                 <li>TOTP setup with QR code generation for authenticator apps</li>
 795:                 <li>SMS verification with 6-digit OTP codes sent via AWS SNS</li>
 796:                 <li>User profile management with edit restrictions for verified fields</li>
 797:                 <li>Admin dashboard for user management, group CRUD operations, and approval workflows (visible to LDAP admin group members only)</li>
 798:                 <li><strong>Interactive API Documentation</strong> (always enabled):
 799:                     <ul>
 800:                         <li><code>/api/docs</code> - Swagger UI for interactive API exploration and testing</li>
 801:                         <li><code>/api/redoc</code> - ReDoc alternative API documentation interface</li>
 802:                         <li><code>/api/openapi.json</code> - OpenAPI schema in JSON format</li>
 803:                     </ul>
 804:                 </li>
 805:             </ul>
 806:         </div>
 807:         <h3 id="phpldapadmin-access">PhpLdapAdmin</h3>
 808:         <div class="card">
 809:             <p><strong>URL:</strong> <code>https://phpldapadmin.&lt;your-domain&gt;</code> (e.g., <code>https://phpldapadmin.example.com</code>)</p>
 810:             <ul>
 811:                 <li>Web-based LDAP administration interface for managing directory entries</li>
 812:                 <li>Internet-facing access via Application Load Balancer with HTTPS/TLS termination</li>
 813:                 <li>Requires OpenLDAP admin credentials for authentication</li>
 814:             </ul>
 815:         </div>
 816:         <h3 id="ltb-passwd-access">LTB-passwd</h3>
 817:         <div class="card">
 818:             <p><strong>URL:</strong> <code>https://passwd.&lt;your-domain&gt;</code> (e.g., <code>https://passwd.example.com</code>)</p>
 819:             <ul>
 820:                 <li>Self-service password management UI for LDAP users</li>
 821:                 <li>Allows users to reset their LDAP passwords without administrator intervention</li>
 822:                 <li>Internet-facing access via Application Load Balancer with HTTPS/TLS termination</li>
 823:             </ul>
 824:         </div>
 825:         <h3 id="argocd-access">ArgoCD</h3>
 826:         <div class="card">
 827:             <p><strong>URL:</strong> Retrieved from Terraform output <code>argocd_server_url</code> (if ArgoCD is enabled)</p>
 828:             <ul>
 829:                 <li>AWS EKS managed ArgoCD service for GitOps deployments</li>
 830:                 <li>Declarative, Git-driven application deployments</li>
 831:                 <li>AWS Identity Center (SSO) authentication for secure access</li>
 832:                 <li>Automatic synchronization and self-healing capabilities</li>
 833:             </ul>
 834:         </div>
 835:         <h3 id="ldap-service-access">LDAP Service</h3>
 836:         <div class="card">
 837:             <p><strong>Access:</strong> Cluster-internal only (ClusterIP service)</p>
 838:             <ul>
 839:                 <li><strong>Port:</strong> 389 (LDAP), 636 (LDAPS)</li>
 840:                 <li><strong>Not Exposed:</strong> LDAP ports are not accessible outside the cluster</li>
 841:             </ul>
 842:         </div>
 843:         <h3 id="mfa-methods">MFA Methods</h3>
 844:         <table>
 845:             <thead>
 846:                 <tr>
 847:                     <th>Method</th>
 848:                     <th>Description</th>
 849:                     <th>Infrastructure Required</th>
 850:                 </tr>
 851:             </thead>
 852:             <tbody>
 853:                 <tr>
 854:                     <td><strong>TOTP</strong></td>
 855:                     <td>Time-based One-Time Password using authenticator apps (Google Authenticator, Authy, etc.)</td>
 856:                     <td>None (codes generated locally)</td>
 857:                 </tr>
 858:                 <tr>
 859:                     <td><strong>SMS</strong></td>
 860:                     <td>Verification codes sent via AWS SNS to user's phone</td>
 861:                     <td>SNS VPC endpoint, IRSA role</td>
 862:                 </tr>
 863:             </tbody>
 864:         </table>
 865:     </section>
 866:     <!-- Security Considerations -->
 867:     <section id="security">
 868:         <h2>Security Considerations</h2>
 869:         <h3 id="key-security-features">Key Security Features</h3>
 870:         <div class="card">
 871:             <p>This project implements defense-in-depth security across multiple layers:</p>
 872:             <ul>
 873:                 <li><strong>Secrets Management</strong>: Passwords managed via GitHub repository secrets (CI/CD) or AWS Secrets Manager (local) with automated retrieval—never committed to version control</li>
 874:                 <li><strong>IRSA (IAM Roles for Service Accounts)</strong>: Pods assume IAM roles via OIDC—no long-lived AWS credentials stored in containers or environment variables</li>
 875:                 <li><strong>VPC Endpoints</strong>: AWS service access (SSM, STS, SNS) routed through private endpoints—no public internet exposure for sensitive operations</li>
 876:                 <li><strong>TLS/HTTPS</strong>: TLS termination at ALB using ACM certificates; internal cluster communication secured via cert-manager</li>
 877:                 <li><strong>LDAP Security</strong>: ClusterIP service only (not exposed externally); cross-namespace access restricted to secure ports (443, 636, 8443)</li>
 878:                 <li><strong>Network Policies</strong>: Kubernetes Network Policies restrict pod-to-pod communication to encrypted ports with cross-namespace support for authorized services</li>
 879:                 <li><strong>Storage Encryption</strong>: EBS volumes encrypted by default; S3 state files encrypted with AES256 server-side encryption</li>
 880:                 <li><strong>Network Isolation</strong>: EKS nodes deployed in private subnets with no public IPs; access via SSM Session Manager</li>
 881:                 <li><strong>Multi-Account Architecture</strong>: State storage (Account A) isolated from resource deployment (Account B) for enhanced security and compliance</li>
 882:                 <li><strong>State Locking</strong>: S3 file-based locking prevents concurrent Terraform operations and state corruption</li>
 883:                 <li><strong>OIDC Authentication</strong>: GitHub Actions authenticates with AWS via OIDC—no access keys required</li>
 884:                 <li><strong>Cross-Account Security</strong>: ExternalId required for cross-account role assumption to prevent confused deputy attacks; bidirectional trust relationships</li>
 885:                 <li><strong>Helm Release Safety</strong>: Comprehensive Helm release attributes (atomic, force_update, replace, cleanup_on_fail, recreate_pods, wait, wait_for_jobs, upgrade_install) for safer deployments</li>
 886:                 <li><strong>ECR Image Support</strong>: All modules (OpenLDAP, PostgreSQL, Redis) use ECR images instead of Docker Hub to prevent rate limiting</li>
 887:                 <li><strong>Kubeconfig Auto-Update</strong>: Automatic kubeconfig updates prevent stale cluster endpoints and DNS lookup errors</li>
 888:             </ul>
 889:             <p><strong>For detailed security documentation:</strong> <a href="../application/SECURITY-IMPROVEMENTS.md">Security Improvements</a></p>
 890:         </div>
 891:     </section>
 892:     <!-- Contributing & Support -->
 893:     <section id="support">
 894:         <h2>Contributing & Support</h2>
 895:         <h3 id="troubleshooting">Troubleshooting</h3>
 896:         <div class="card">
 897:             <p>For troubleshooting guides, see:</p>
 898:             <ul>
 899:                 <li><a href="../backend_infra/README.md#troubleshooting">Backend Infrastructure Troubleshooting</a></li>
 900:                 <li><a href="../application/README.md#troubleshooting">Application Infrastructure Troubleshooting</a></li>
 901:             </ul>
 902:         </div>
 903:         <h3 id="repository">Repository</h3>
 904:         <div class="card">
 905:             <p>GitHub Repository: <a href="https://github.com/talorlik/ldap-2fa-on-k8s" target="_blank">ldap-2fa-on-k8s</a></p>
 906:         </div>
 907:         <h3 id="license">License</h3>
 908:         <div class="card">
 909:             <p>This project is licensed under the <strong>MIT License</strong>.</p>
 910:             <p>See the <a href="../LICENSE">LICENSE</a> file for details.</p>
 911:             <p>Copyright (c) 2025 Tal Orlik</p>
 912:         </div>
 913:     </section>
 914:     <!-- Footer -->
 915:     <footer>
 916:         <p>&copy; 2025 Tal Orlik. Licensed under MIT License.</p>
 917:         <p>LDAP Authentication with 2FA on Kubernetes (EKS)</p>
 918:     </footer>
 919:     <script>
 920:         // Theme management
 921:         const themeStylesheet = document.getElementById('theme-stylesheet');
 922:         const themeToggle = document.getElementById('themeToggle');
 923:         const sunIcon = document.getElementById('sunIcon');
 924:         const moonIcon = document.getElementById('moonIcon');
 925:         // Get saved theme or default to light
 926:         const currentTheme = localStorage.getItem('theme') || 'light';
 927:         function setTheme(theme) {
 928:             if (theme === 'dark') {
 929:                 themeStylesheet.href = 'dark-theme.css';
 930:                 // Show sun icon (to switch to light theme)
 931:                 sunIcon.classList.remove('hidden');
 932:                 moonIcon.classList.add('hidden');
 933:                 themeToggle.setAttribute('aria-label', 'Switch to light theme');
 934:                 themeToggle.setAttribute('title', 'Switch to light theme');
 935:                 localStorage.setItem('theme', 'dark');
 936:             } else {
 937:                 themeStylesheet.href = 'light-theme.css';
 938:                 // Show moon icon (to switch to dark theme)
 939:                 sunIcon.classList.add('hidden');
 940:                 moonIcon.classList.remove('hidden');
 941:                 themeToggle.setAttribute('aria-label', 'Switch to dark theme');
 942:                 themeToggle.setAttribute('title', 'Switch to dark theme');
 943:                 localStorage.setItem('theme', 'light');
 944:             }
 945:         }
 946:         // Initialize theme on page load
 947:         setTheme(currentTheme);
 948:         // Toggle theme on button click
 949:         themeToggle.addEventListener('click', () => {
 950:             const newTheme = themeStylesheet.href.includes('dark-theme.css') ? 'light' : 'dark';
 951:             setTheme(newTheme);
 952:         });
 953:         // Mobile menu toggle
 954:         const mobileMenuToggle = document.getElementById('mobileMenuToggle');
 955:         const navMenu = document.getElementById('navMenu');
 956:         mobileMenuToggle.addEventListener('click', () => {
 957:             navMenu.classList.toggle('active');
 958:         });
 959:         // Close mobile menu when clicking on a link
 960:         const navLinks = document.querySelectorAll('.nav-menu a');
 961:         navLinks.forEach(link => {
 962:             link.addEventListener('click', () => {
 963:                 navMenu.classList.remove('active');
 964:             });
 965:         });
 966:         // Active section highlighting
 967:         const sections = document.querySelectorAll('section[id]');
 968:         const navLinksArray = Array.from(navLinks);
 969:         function highlightActiveSection() {
 970:             const scrollY = window.pageYOffset;
 971:             sections.forEach(section => {
 972:                 const sectionHeight = section.offsetHeight;
 973:                 const sectionTop = section.offsetTop - 150;
 974:                 const sectionId = section.getAttribute('id');
 975:                 if (scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
 976:                     navLinksArray.forEach(link => {
 977:                         link.classList.remove('active');
 978:                         if (link.getAttribute('href') === `#${sectionId}`) {
 979:                             link.classList.add('active');
 980:                         }
 981:                     });
 982:                 }
 983:             });
 984:         }
 985:         window.addEventListener('scroll', highlightActiveSection);
 986:         window.addEventListener('load', highlightActiveSection);
 987:     </script>
 988:     <!-- Scroll to Top Button -->
 989:     <button id="scrollToTopButton" class="scroll-to-top" aria-label="Scroll to top" title="Scroll to top">
 990:         <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
 991:             <circle cx="12" cy="12" r="10"></circle>
 992:             <polyline points="16 12 12 8 8 12"></polyline>
 993:             <line x1="12" y1="8" x2="12" y2="16"></line>
 994:         </svg>
 995:     </button>
 996:     <script>
 997:         // Initialize scroll to top button after DOM is ready
 998:         function initScrollToTop() {
 999:             const scrollToTopButton = document.getElementById('scrollToTopButton');
1000:             if (!scrollToTopButton) {
1001:                 console.error('Scroll to top button not found');
1002:                 return;
1003:             }
1004:             // Check scroll position on load
1005:             function checkScroll() {
1006:                 if (window.pageYOffset > 100 || document.documentElement.scrollTop > 100) {
1007:                     scrollToTopButton.classList.add('visible');
1008:                 } else {
1009:                     scrollToTopButton.classList.remove('visible');
1010:                 }
1011:             }
1012:             // Initial check
1013:             checkScroll();
1014:             // Handle scroll events
1015:             window.addEventListener('scroll', checkScroll);
1016:             // Handle click
1017:             scrollToTopButton.addEventListener('click', (e) => {
1018:                 e.preventDefault();
1019:                 window.scrollTo({
1020:                     top: 0,
1021:                     behavior: 'smooth'
1022:                 });
1023:             });
1024:         }
1025:         // Initialize when DOM is ready
1026:         if (document.readyState === 'loading') {
1027:             document.addEventListener('DOMContentLoaded', initScrollToTop);
1028:         } else {
1029:             initScrollToTop();
1030:         }
1031:         // Smooth scroll for anchor links
1032:         document.querySelectorAll('a[href^="#"]').forEach(anchor => {
1033:             anchor.addEventListener('click', function (e) {
1034:                 e.preventDefault();
1035:                 const target = document.querySelector(this.getAttribute('href'));
1036:                 if (target) {
1037:                     target.scrollIntoView({
1038:                         behavior: 'smooth',
1039:                         block: 'start'
1040:                     });
1041:                 }
1042:             });
1043:         });
1044:     </script>
1045: </body>
1046: </html>
```

## File: application/main.tf
```hcl
  1: locals {
  2:   storage_class_name = "${var.prefix}-${var.region}-${var.storage_class_name}-${var.env}"
  3:
  4:   # Retrieve ECR information from backend_infra state
  5:   ecr_registry   = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_registry, "")
  6:   ecr_repository = try(data.terraform_remote_state.backend_infra[0].outputs.ecr_repository, "")
  7:
  8:   tags = {
  9:     Env       = "${var.env}"
 10:     Terraform = "true"
 11:   }
 12: }
 13:
 14: data "aws_route53_zone" "this" {
 15:   provider     = aws.state_account
 16:   name         = var.domain_name
 17:   private_zone = false
 18: }
 19:
 20: # ACM Certificate must be in the deployment account (not state account)
 21: # EKS Auto Mode ALB controller cannot access cross-account certificates
 22: # The certificate must exist in the same account where the ALB is created
 23: # Certificate is issued from Private CA in State Account but stored in Deployment Account
 24: # Each deployment account (development, production) has its own certificate
 25: data "aws_acm_certificate" "this" {
 26:   # Use default provider (deployment account) instead of state_account
 27:   # EKS Auto Mode ALB controller requires certificate in the same account
 28:   # Certificate is issued from Private CA in State Account but stored here
 29:   domain      = var.domain_name
 30:   most_recent = true
 31:   statuses    = ["ISSUED"]
 32: }
 33:
 34: # Create StorageClass for OpenLDAP PVC
 35: resource "kubernetes_storage_class_v1" "this" {
 36:   metadata {
 37:     name = local.storage_class_name
 38:     annotations = var.storage_class_is_default ? {
 39:       "storageclass.kubernetes.io/is-default-class" = "true"
 40:     } : {}
 41:   }
 42:
 43:   storage_provisioner    = "ebs.csi.eks.amazonaws.com"
 44:   reclaim_policy         = "Delete"
 45:   volume_binding_mode    = "Immediate" # Changed from WaitForFirstConsumer to prevent PVC binding deadlocks
 46:   allow_volume_expansion = true
 47:
 48:   parameters = {
 49:     type      = var.storage_class_type
 50:     encrypted = tostring(var.storage_class_encrypted)
 51:   }
 52:
 53:   depends_on = [data.aws_eks_cluster.cluster]
 54:
 55:   lifecycle {
 56:     # Prevent Terraform from trying to recreate if the resource already exists
 57:     # This helps when the resource exists but isn't in state
 58:     ignore_changes = [
 59:       metadata[0].annotations,
 60:     ]
 61:     # Allow replacement if needed
 62:     replace_triggered_by = []
 63:   }
 64: }
 65:
 66: # module "route53" {
 67: #   source = "./modules/route53"
 68:
 69: #   use_existing_route53_zone = var.use_existing_route53_zone
 70: #   env                       = var.env
 71: #   region                    = var.region
 72: #   prefix                    = var.prefix
 73: #   domain_name               = var.domain_name
 74: #   subject_alternative_names = var.subject_alternative_names
 75: #   tags                      = local.tags
 76: # }
 77:
 78: locals {
 79:   app_name = "${var.prefix}-${var.region}-${var.app_name}-${var.env}"
 80:
 81:   # ALB group name: Kubernetes identifier (max 63 chars) used to group Ingresses
 82:   # If alb_group_name is set, concatenate with prefix, region, and env (truncate to 63 chars if needed)
 83:   # If not set, use app_name (truncate to 63 chars if needed)
 84:   alb_group_name = var.alb_group_name != null ? (
 85:     length("${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}") > 63 ?
 86:     substr("${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}", 0, 63) :
 87:     "${var.prefix}-${var.region}-${var.alb_group_name}-${var.env}"
 88:     ) : (
 89:     length(local.app_name) > 63 ? substr(local.app_name, 0, 63) : local.app_name
 90:   )
 91:
 92:   # ALB load balancer name: AWS resource name (max 32 chars per AWS constraints)
 93:   # If alb_load_balancer_name is set, concatenate with prefix, region, and env (truncate to 32 chars if needed)
 94:   # If not set, use alb_group_name (truncate to 32 chars if needed)
 95:   alb_load_balancer_name = var.alb_load_balancer_name != null ? (
 96:     length("${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}") > 32 ?
 97:     substr("${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}", 0, 32) :
 98:     "${var.prefix}-${var.region}-${var.alb_load_balancer_name}-${var.env}"
 99:     ) : (
100:     length(local.alb_group_name) > 32 ? substr(local.alb_group_name, 0, 32) : local.alb_group_name
101:   )
102:
103:   # ALB zone_id mapping by region (for Route53 alias records)
104:   # These are the canonical hosted zone IDs for Application Load Balancers
105:   alb_zone_ids = {
106:     "us-east-1"      = "Z35SXDOTRQ7X7K"
107:     "us-east-2"      = "Z3AADJGX6KTTL2"
108:     "us-west-1"      = "Z1M58G0W56PQJA"
109:     "us-west-2"      = "Z33MTJ483K6KNU"
110:     "eu-west-1"      = "Z3DZXE0Q2N3XK0"
111:     "eu-west-2"      = "Z3GKZC51ZF0DB4"
112:     "eu-west-3"      = "Z3Q77PNBUNY4FR"
113:     "eu-central-1"   = "Z215JYRZR1TBD5"
114:     "ap-southeast-1" = "Z1LMS91P8CMLE5"
115:     "ap-southeast-2" = "Z1GM3OXH4ZPM65"
116:     "ap-northeast-1" = "Z14GRHDCWA56QT"
117:     "ap-northeast-2" = "Z1W9GUF3Q8Z8BZ"
118:     "sa-east-1"      = "Z2P70J7HTTTPLU"
119:   }
120:   alb_zone_id = lookup(local.alb_zone_ids, var.region, "Z35SXDOTRQ7X7K")
121:
122:   # ALB DNS name: Query AWS directly using the ALB name.
123:   # While this is the preferred approach, we are reliant on the OpenLDAP module
124:   # being fully deployed as this guarantees that an Ingress resource exists, which triggers ALB creation.
125:   # The ALB must exist before this can be queried.
126:   alb_dns_name = var.use_alb ? data.aws_lb.alb[0].dns_name : null
127:
128:   # Derive hostnames from domain_name if not explicitly provided
129:   # These are used for Route53 records and must be non-null
130:   # Note: domain_name is a required variable (not a resource), so no depends_on is needed
131:   # The coalesce ensures we always have a value - either from the variable or derived from domain_name
132:   phpldapadmin_host = coalesce(var.phpldapadmin_host, "phpldapadmin.${var.domain_name}")
133:   ltb_passwd_host   = coalesce(var.ltb_passwd_host, "passwd.${var.domain_name}")
134:   twofa_app_host    = coalesce(var.twofa_app_host, "app.${var.domain_name}")
135: }
136:
137: # ALB module creates IngressClass and IngressClassParams for EKS Auto Mode
138: # The Ingress/Service resources in the module are commented out (not needed)
139: module "alb" {
140:   source = "./modules/alb"
141:
142:   count = var.use_alb ? 1 : 0
143:
144:   env          = var.env
145:   region       = var.region
146:   prefix       = var.prefix
147:   app_name     = local.app_name
148:   cluster_name = local.cluster_name
149:   # ingress_alb_name            = var.ingress_alb_name
150:   # service_alb_name            = var.service_alb_name
151:   ingressclass_alb_name       = var.ingressclass_alb_name
152:   ingressclassparams_alb_name = var.ingressclassparams_alb_name
153:   acm_certificate_arn         = try(data.aws_acm_certificate.this.arn, null)
154:   alb_scheme                  = var.alb_scheme
155:   alb_ip_address_type         = var.alb_ip_address_type
156:   alb_group_name              = local.alb_group_name
157:
158:   wait_for_crd = var.wait_for_crd
159: }
160:
161: ##################### OpenLDAP ##########################
162:
163: # OpenLDAP Module
164: module "openldap" {
165:   source = "./modules/openldap"
166:
167:   env    = var.env
168:   region = var.region
169:   prefix = var.prefix
170:
171:   app_name                 = local.app_name
172:   openldap_ldap_domain     = var.openldap_ldap_domain
173:   openldap_admin_password  = var.openldap_admin_password
174:   openldap_config_password = var.openldap_config_password
175:   openldap_secret_name     = var.openldap_secret_name
176:   storage_class_name       = local.storage_class_name
177:
178:   # ECR image configuration
179:   ecr_registry       = local.ecr_registry
180:   ecr_repository     = local.ecr_repository
181:   openldap_image_tag = var.openldap_image_tag
182:
183:   # Use derived values from locals to ensure non-null values
184:   # These are derived from domain_name if not explicitly provided
185:   phpldapadmin_host = local.phpldapadmin_host
186:   ltb_passwd_host   = local.ltb_passwd_host
187:
188:   use_alb                = var.use_alb
189:   ingress_class_name     = var.use_alb ? module.alb[0].ingress_class_name : null
190:   alb_load_balancer_name = local.alb_load_balancer_name
191:   alb_target_type        = var.alb_target_type
192:   alb_ssl_policy         = var.alb_ssl_policy
193:   acm_cert_arn           = data.aws_acm_certificate.this.arn
194:
195:   tags = local.tags
196:
197:   depends_on = [
198:     kubernetes_storage_class_v1.this,
199:     module.alb,
200:   ]
201: }
202:
203: # Query AWS for ALB DNS name using the load balancer name.
204: # While querying AWS directly is the preferred approach, we are reliant on the OpenLDAP module
205: # being fully deployed as this guarantees that an Ingress resource exists, which triggers ALB creation.
206: data "aws_lb" "alb" {
207:   count = var.use_alb ? 1 : 0
208:   name  = local.alb_load_balancer_name
209:
210:   # Ensure OpenLDAP module is fully deployed (creates Ingress which triggers ALB creation)
211:   depends_on = [module.openldap]
212: }
213:
214: ##################### Route53 Records ##########################
215:
216: # Route53 A (alias) records for all subdomains pointing to ALB
217: # All records use consistent ALB data source approach to avoid timing issues
218:
219: # Route53 record for phpLDAPadmin
220: module "route53_record_phpldapadmin" {
221:   source = "./modules/route53_record"
222:
223:   count = var.use_alb && local.phpldapadmin_host != "" ? 1 : 0
224:
225:   zone_id      = data.aws_route53_zone.this.zone_id
226:   name         = local.phpldapadmin_host
227:   alb_dns_name = data.aws_lb.alb[0].dns_name
228:   alb_zone_id  = local.alb_zone_id
229:
230:   depends_on = [
231:     module.openldap, # Ensures Ingress is created (which triggers ALB creation)
232:     data.aws_lb.alb, # Ensures ALB exists before creating record
233:   ]
234:
235:   providers = {
236:     aws.state_account = aws.state_account
237:   }
238: }
239:
240: # Route53 record for ltb-passwd
241: module "route53_record_ltb_passwd" {
242:   source = "./modules/route53_record"
243:
244:   count = var.use_alb && local.ltb_passwd_host != "" ? 1 : 0
245:
246:   zone_id      = data.aws_route53_zone.this.zone_id
247:   name         = local.ltb_passwd_host
248:   alb_dns_name = data.aws_lb.alb[0].dns_name
249:   alb_zone_id  = local.alb_zone_id
250:
251:   depends_on = [
252:     module.openldap, # Ensures Ingress is created (which triggers ALB creation)
253:     data.aws_lb.alb, # Ensures ALB exists before creating record
254:   ]
255:
256:   providers = {
257:     aws.state_account = aws.state_account
258:   }
259: }
260:
261: # Route53 record for 2FA application
262: module "route53_record_twofa_app" {
263:   source = "./modules/route53_record"
264:
265:   count = var.use_alb && local.twofa_app_host != "" ? 1 : 0
266:
267:   zone_id      = data.aws_route53_zone.this.zone_id
268:   name         = local.twofa_app_host
269:   alb_dns_name = data.aws_lb.alb[0].dns_name
270:   alb_zone_id  = local.alb_zone_id
271:
272:   depends_on = [
273:     module.openldap, # Ensures Ingress is created (which triggers ALB creation)
274:     data.aws_lb.alb, # Ensures ALB exists before creating record
275:   ]
276:
277:   providers = {
278:     aws.state_account = aws.state_account
279:   }
280: }
281:
282: ##################### ArgoCD ##########################
283:
284: # ArgoCD Capability Module
285: # Deployed early to allow other modules to depend on it
286: module "argocd" {
287:   source = "./modules/argocd"
288:
289:   count = var.enable_argocd ? 1 : 0
290:
291:   env    = var.env
292:   region = var.region
293:   prefix = var.prefix
294:
295:   cluster_name = local.cluster_name
296:
297:   argocd_role_name_component       = var.argocd_role_name_component
298:   argocd_capability_name_component = var.argocd_capability_name_component
299:   argocd_namespace                 = var.argocd_namespace
300:   argocd_project_name              = var.argocd_project_name
301:
302:   idc_instance_arn = var.idc_instance_arn
303:   idc_region       = var.idc_region
304:
305:   rbac_role_mappings        = var.argocd_rbac_role_mappings
306:   argocd_vpce_ids           = var.argocd_vpce_ids
307:   delete_propagation_policy = var.argocd_delete_propagation_policy
308: }
309:
310: # Wait for ArgoCD capability to be fully deployed and ACTIVE
311: # This ensures proper deployment ordering when ArgoCD is enabled
312: resource "time_sleep" "wait_for_argocd" {
313:   count = var.enable_argocd ? 1 : 0
314:
315:   create_duration = "3m" # Wait 60 seconds for ArgoCD capability to be ready
316:
317:   depends_on = [module.argocd]
318: }
319:
320: ##################### PostgreSQL for User Storage ##########################
321:
322: # PostgreSQL Module for user signup data storage
323: module "postgresql" {
324:   source = "./modules/postgresql"
325:
326:   count = var.enable_postgresql ? 1 : 0
327:
328:   env    = var.env
329:   region = var.region
330:   prefix = var.prefix
331:
332:   namespace         = var.postgresql_namespace
333:   secret_name       = var.postgresql_secret_name
334:   database_name     = var.postgresql_database_name
335:   database_username = var.postgresql_database_username
336:   database_password = var.postgresql_database_password
337:   storage_class     = local.storage_class_name
338:   storage_size      = var.postgresql_storage_size
339:
340:   # ECR image configuration
341:   ecr_registry   = local.ecr_registry
342:   ecr_repository = local.ecr_repository
343:   image_tag      = var.postgresql_image_tag
344:
345:   tags = local.tags
346:
347:   # Static list: always depends on OpenLDAP
348:   # ArgoCD dependency is handled implicitly through module ordering (ArgoCD is defined before this module)
349:   depends_on = [
350:     module.openldap,
351:     data.aws_lb.alb
352:   ]
353: }
354:
355: ##################### Redis for SMS OTP Storage ##########################
356:
357: # Redis Module for centralized SMS OTP code storage with TTL-based expiration
358: module "redis" {
359:   source = "./modules/redis"
360:
361:   count = var.enable_redis ? 1 : 0
362:
363:   env    = var.env
364:   region = var.region
365:   prefix = var.prefix
366:
367:   enable_redis       = var.enable_redis
368:   namespace          = var.redis_namespace
369:   secret_name        = var.redis_secret_name
370:   redis_password     = var.redis_password
371:   storage_class_name = local.storage_class_name
372:   storage_size       = var.redis_storage_size
373:   chart_version      = var.redis_chart_version
374:
375:   # ECR image configuration
376:   ecr_registry   = local.ecr_registry
377:   ecr_repository = local.ecr_repository
378:   image_tag      = var.redis_image_tag
379:
380:   # Network policy configuration
381:   backend_namespace = var.argocd_app_backend_namespace
382:
383:   tags = local.tags
384:
385:   # Static list: always depends on OpenLDAP
386:   # ArgoCD dependency is handled implicitly through module ordering (ArgoCD is defined before this module)
387:   depends_on = [
388:     module.openldap,
389:     data.aws_lb.alb
390:   ]
391: }
392:
393: ##################### SES for Email Verification ##########################
394:
395: # SES Module for email verification
396: module "ses" {
397:   source = "./modules/ses"
398:
399:   count = var.enable_email_verification ? 1 : 0
400:
401:   env          = var.env
402:   region       = var.region
403:   prefix       = var.prefix
404:   cluster_name = local.cluster_name
405:
406:   sender_email              = var.ses_sender_email
407:   sender_domain             = var.ses_sender_domain
408:   iam_role_name             = var.ses_iam_role_name
409:   service_account_namespace = var.argocd_app_backend_namespace
410:   service_account_name      = "ldap-2fa-backend"
411:   route53_zone_id           = var.ses_route53_zone_id != null ? var.ses_route53_zone_id : data.aws_route53_zone.this.zone_id
412:
413:   tags = local.tags
414:
415:   # Pass state account provider for Route53 resources
416:   # If state_account_role_arn is null, state_account provider uses default credentials
417:   # Note: ses module needs both aws and aws.state_account
418:   providers = {
419:     aws               = aws
420:     aws.state_account = aws.state_account
421:   }
422: }
423:
424: ##################### SNS for SMS 2FA ##########################
425:
426: # SNS Module for SMS-based 2FA verification
427: module "sns" {
428:   source = "./modules/sns"
429:
430:   count = var.enable_sms_2fa ? 1 : 0
431:
432:   env          = var.env
433:   region       = var.region
434:   prefix       = var.prefix
435:   cluster_name = local.cluster_name
436:
437:   sns_topic_name            = var.sns_topic_name
438:   sns_display_name          = var.sns_display_name
439:   iam_role_name             = var.sns_iam_role_name
440:   service_account_namespace = var.argocd_app_backend_namespace
441:   service_account_name      = "ldap-2fa-backend"
442:
443:   configure_sms_preferences = var.configure_sms_preferences
444:   sms_sender_id             = var.sms_sender_id
445:   sms_type                  = var.sms_type
446:   sms_monthly_spend_limit   = var.sms_monthly_spend_limit
447:
448:   tags = local.tags
449: }
450:
451: ##################### ArgoCD Application - Backend
452: module "argocd_app_backend" {
453:   source = "./modules/argocd_app"
454:
455:   count = var.enable_argocd_apps && var.enable_argocd && var.argocd_app_repo_url != null && var.argocd_app_backend_path != null ? 1 : 0
456:
457:   app_name              = var.argocd_app_backend_name
458:   argocd_namespace      = var.argocd_namespace
459:   argocd_project_name   = var.argocd_project_name
460:   cluster_name_in_argo  = module.argocd[0].local_cluster_secret_name
461:   repo_url              = var.argocd_app_repo_url
462:   target_revision       = var.argocd_app_target_revision
463:   repo_path             = var.argocd_app_backend_path
464:   destination_namespace = var.argocd_app_backend_namespace
465:
466:   sync_policy = var.argocd_app_sync_policy_automated ? {
467:     automated = {
468:       prune       = var.argocd_app_sync_policy_prune
469:       self_heal   = var.argocd_app_sync_policy_self_heal
470:       allow_empty = false
471:     }
472:     sync_options = ["CreateNamespace=true"]
473:   } : null
474: }
475:
476: # ArgoCD Application - Frontend
477: module "argocd_app_frontend" {
478:   source = "./modules/argocd_app"
479:
480:   count = var.enable_argocd_apps && var.enable_argocd && var.argocd_app_repo_url != null && var.argocd_app_frontend_path != null ? 1 : 0
481:
482:   app_name              = var.argocd_app_frontend_name
483:   argocd_namespace      = var.argocd_namespace
484:   argocd_project_name   = var.argocd_project_name
485:   cluster_name_in_argo  = module.argocd[0].local_cluster_secret_name
486:   repo_url              = var.argocd_app_repo_url
487:   target_revision       = var.argocd_app_target_revision
488:   repo_path             = var.argocd_app_frontend_path
489:   destination_namespace = var.argocd_app_frontend_namespace
490:
491:   sync_policy = var.argocd_app_sync_policy_automated ? {
492:     automated = {
493:       prune       = var.argocd_app_sync_policy_prune
494:       self_heal   = var.argocd_app_sync_policy_self_heal
495:       allow_empty = false
496:     }
497:     sync_options = ["CreateNamespace=true"]
498:   } : null
499: }
```

## File: application/variables.tf
```hcl
  1: variable "env" {
  2:   description = "Deployment environment"
  3:   type        = string
  4: }
  5:
  6: variable "region" {
  7:   description = "Deployment region"
  8:   type        = string
  9: }
 10:
 11: variable "prefix" {
 12:   description = "Name added to all resources"
 13:   type        = string
 14: }
 15:
 16: variable "deployment_account_role_arn" {
 17:   description = "ARN of the IAM role to assume in the deployment account (Account B). Required when using GitHub Actions with multi-account setup."
 18:   type        = string
 19:   default     = null
 20:   nullable    = true
 21: }
 22:
 23: variable "deployment_account_external_id" {
 24:   description = "ExternalId for cross-account role assumption security. Required when assuming roles in deployment accounts. Must match the ExternalId configured in the deployment account role's Trust Relationship. Retrieved from AWS Secrets Manager (secret: 'external-id') for local deployment or GitHub secret (AWS_ASSUME_EXTERNAL_ID) for GitHub Actions."
 25:   type        = string
 26:   default     = null
 27:   nullable    = true
 28:   sensitive   = true
 29: }
 30:
 31: variable "state_account_role_arn" {
 32:   description = "ARN of the IAM role to assume in the state account (where Route53 hosted zone and ACM certificate reside). Required when Route53 and ACM resources are in a different account than the deployment account."
 33:   type        = string
 34:   default     = null
 35:   nullable    = true
 36: }
 37:
 38: ##################### OpenLDAP ##########################
 39: variable "app_name" {
 40:   description = "Application name"
 41:   type        = string
 42: }
 43:
 44: variable "openldap_ldap_domain" {
 45:   description = "OpenLDAP domain (e.g., ldap.talorlik.internal)"
 46:   type        = string
 47: }
 48:
 49: variable "openldap_admin_password" {
 50:   description = "OpenLDAP admin password. MUST be set via TF_VAR_OPENLDAP_ADMIN_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
 51:   type        = string
 52:   sensitive   = true
 53:   # No default - must be provided via environment variable or .env file
 54: }
 55:
 56: variable "openldap_config_password" {
 57:   description = "OpenLDAP config password. MUST be set via TF_VAR_OPENLDAP_CONFIG_PASSWORD environment variable, .env file, or GitHub Secret. Do NOT set in variables.tfvars."
 58:   type        = string
 59:   sensitive   = true
 60:   # No default - must be provided via environment variable or .env file
 61: }
 62:
 63: variable "openldap_secret_name" {
 64:   description = "Name of the Kubernetes secret for OpenLDAP passwords"
 65:   type        = string
 66:   default     = "openldap-secret"
 67: }
 68:
 69: variable "openldap_image_tag" {
 70:   description = "OpenLDAP image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
 71:   type        = string
 72:   default     = "openldap-1.5.0"
 73: }
 74:
 75: variable "postgresql_image_tag" {
 76:   description = "PostgreSQL image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
 77:   type        = string
 78:   default     = "postgresql-latest"
 79: }
 80:
 81: variable "redis_image_tag" {
 82:   description = "Redis image tag in ECR. Corresponds to the tag created by mirror-images-to-ecr.sh"
 83:   type        = string
 84:   default     = "redis-latest"
 85: }
 86:
 87: ##################### Storage ##########################
 88:
 89: variable "storage_class_name" {
 90:   description = "Name of the Kubernetes StorageClass to create and use for OpenLDAP PVC"
 91:   type        = string
 92: }
 93:
 94: variable "storage_class_type" {
 95:   description = "EBS volume type for the StorageClass (gp2, gp3, io1, io2, etc.)"
 96:   type        = string
 97: }
 98:
 99: variable "storage_class_encrypted" {
100:   description = "Whether to encrypt EBS volumes created by the StorageClass"
101:   type        = bool
102: }
103:
104: variable "storage_class_is_default" {
105:   description = "Whether to mark this StorageClass as the default for the cluster"
106:   type        = bool
107: }
108:
109: ##################### Route53 ##########################
110:
111: variable "domain_name" {
112:   description = "Root domain name for Route53 hosted zone and ACM certificate (e.g., talorlik.com)"
113:   type        = string
114: }
115:
116: # variable "subject_alternative_names" {
117: #   description = "List of subject alternative names for the ACM certificate (e.g., [\"*.talorlik.com\"])"
118: #   type        = list(string)
119: #   default     = []
120: # }
121:
122: # variable "use_existing_route53_zone" {
123: #   description = "Whether to use an existing Route53 zone"
124: #   type        = bool
125: #   default     = false
126: # }
127:
128: # Use ALB - can set this to false for to get NLB
129: ### NLB not yet implemented. If false you get no load balancer
130: variable "use_alb" {
131:   description = "When true, uses AWS Auto to create ALB. When false an NLB is created"
132:   type        = bool
133:   default     = true
134: }
135:
136: # variable "ingress_alb_name" {
137: #   description = "Name component for ingress ALB resource (between prefix and env)"
138: #   type        = string
139: # }
140:
141: # variable "service_alb_name" {
142: #   description = "Name component for service ALB resource (between prefix and env)"
143: #   type        = string
144: # }
145:
146: variable "ingressclass_alb_name" {
147:   description = "Name component for ingressclass ALB resource (between prefix and env)"
148:   type        = string
149: }
150:
151: variable "ingressclassparams_alb_name" {
152:   description = "Name component for ingressclassparams ALB resource (between prefix and env)"
153:   type        = string
154: }
155:
156: ##################### ALB Configuration ##########################
157:
158: variable "alb_group_name" {
159:   description = "ALB group name for grouping multiple Ingress resources to share a single ALB. This is an internal Kubernetes identifier (max 63 characters)."
160:   type        = string
161:   default     = null # If null, will be derived from app_name
162: }
163:
164: variable "alb_load_balancer_name" {
165:   description = "Custom name for the AWS ALB (appears in AWS console). Must be ≤ 32 characters per AWS constraints. If null, defaults to alb_group_name (truncated to 32 chars if needed)."
166:   type        = string
167:   default     = null
168: }
169:
170: variable "phpldapadmin_host" {
171:   description = "Hostname for phpLDAPadmin ingress (e.g., phpldapadmin.talorlik.com). If null, will be derived from domain_name"
172:   type        = string
173:   default     = null
174:   nullable    = true
175: }
176:
177: variable "ltb_passwd_host" {
178:   description = "Hostname for ltb-passwd ingress (e.g., passwd.talorlik.com). If null, will be derived from domain_name"
179:   type        = string
180:   default     = null
181:   nullable    = true
182: }
183:
184: variable "twofa_app_host" {
185:   description = "Hostname for 2FA application ingress (e.g., app.talorlik.com). If null, will be derived from domain_name"
186:   type        = string
187:   default     = null
188: }
189:
190: variable "alb_scheme" {
191:   description = "ALB scheme: internet-facing or internal"
192:   type        = string
193:   default     = "internet-facing"
194:   validation {
195:     condition     = contains(["internet-facing", "internal"], var.alb_scheme)
196:     error_message = "ALB scheme must be either 'internet-facing' or 'internal'"
197:   }
198: }
199:
200: variable "alb_target_type" {
201:   description = "ALB target type: ip or instance"
202:   type        = string
203:   default     = "ip"
204:   validation {
205:     condition     = contains(["ip", "instance"], var.alb_target_type)
206:     error_message = "ALB target type must be either 'ip' or 'instance'"
207:   }
208: }
209:
210: variable "alb_ssl_policy" {
211:   description = "ALB SSL policy for HTTPS listeners"
212:   type        = string
213:   default     = "ELBSecurityPolicy-TLS13-1-0-PQ-2025-09"
214: }
215:
216: variable "alb_ip_address_type" {
217:   description = "ALB IP address type: ipv4 or dualstack"
218:   type        = string
219:   default     = "ipv4"
220:   validation {
221:     condition     = contains(["ipv4", "dualstack"], var.alb_ip_address_type)
222:     error_message = "ALB IP address type must be either 'ipv4' or 'dualstack'"
223:   }
224: }
225:
226: variable "cluster_name" {
227:   description = "Full name of the EKS cluster (will be retrieved from backend_infra remote state if backend.hcl exists, otherwise must be provided)"
228:   type        = string
229:   default     = null
230: }
231:
232: variable "cluster_name_component" {
233:   description = "Name component for cluster (used only if cluster_name not provided and remote state unavailable). Full name format: prefix-region-cluster_name_component-env"
234:   type        = string
235:   default     = "kc"
236: }
237:
238: variable "terraform_workspace" {
239:   description = "Terraform workspace name for remote state lookup. If null, will be derived from region and env as 'region-env'. This ensures the correct workspace state is used when fetching ECR registry information from backend_infra."
240:   type        = string
241:   default     = null
242:   nullable    = true
243: }
244:
245: variable "kubernetes_master" {
246:   description = "Kubernetes API server endpoint (KUBERNETES_MASTER environment variable). Set by set-k8s-env.sh or GitHub workflow. Can be set via TF_VAR_kubernetes_master."
247:   type        = string
248:   default     = null
249:   nullable    = true
250: }
251:
252: variable "kube_config_path" {
253:   description = "Path to kubeconfig file (KUBE_CONFIG_PATH environment variable). Set by set-k8s-env.sh or GitHub workflow. Can be set via TF_VAR_kube_config_path."
254:   type        = string
255:   default     = null
256:   nullable    = true
257: }
258:
259: variable "wait_for_crd" {
260:   description = "Whether to wait for EKS Auto Mode CRD to be available before creating IngressClassParams. Set to true for initial cluster deployments, false after cluster is established."
261:   type        = bool
262:   default     = false
263: }
264:
265: ##################### PostgreSQL User Storage ##########################
266:
267: variable "enable_postgresql" {
268:   description = "Whether to deploy PostgreSQL for user storage"
269:   type        = bool
270:   default     = true
271: }
272:
273: variable "postgresql_namespace" {
274:   description = "Kubernetes namespace for PostgreSQL"
275:   type        = string
276:   default     = "ldap-2fa"
277: }
278:
279: variable "postgresql_database_name" {
280:   description = "PostgreSQL database name"
281:   type        = string
282:   default     = "ldap2fa"
283: }
284:
285: variable "postgresql_database_username" {
286:   description = "PostgreSQL database username"
287:   type        = string
288:   default     = "ldap2fa"
289: }
290:
291: variable "postgresql_database_password" {
292:   description = "PostgreSQL database password. MUST be set via TF_VAR_POSTGRESQL_PASSWORD environment variable or GitHub Secret."
293:   type        = string
294:   sensitive   = true
295: }
296:
297: variable "postgresql_secret_name" {
298:   description = "Name of the Kubernetes secret for PostgreSQL password"
299:   type        = string
300:   default     = "postgresql-secret"
301: }
302:
303: variable "postgresql_storage_size" {
304:   description = "PostgreSQL storage size"
305:   type        = string
306:   default     = "8Gi"
307: }
308:
309: ##################### SES Email Verification ##########################
310:
311: variable "enable_email_verification" {
312:   description = "Whether to enable email verification using SES"
313:   type        = bool
314:   default     = true
315: }
316:
317: variable "ses_sender_email" {
318:   description = "Email address to send verification emails from"
319:   type        = string
320:   default     = "noreply@example.com"
321: }
322:
323: variable "ses_sender_domain" {
324:   description = "Domain to verify in SES (optional, for domain-level verification)"
325:   type        = string
326:   default     = null
327: }
328:
329: variable "ses_iam_role_name" {
330:   description = "Name component for the SES IAM role"
331:   type        = string
332:   default     = "ses-sender"
333: }
334:
335: variable "ses_route53_zone_id" {
336:   description = "Route53 zone ID for SES domain verification (optional, defaults to main domain zone)"
337:   type        = string
338:   default     = null
339: }
340:
341: ##################### SNS SMS 2FA ##########################
342:
343: variable "enable_sms_2fa" {
344:   description = "Whether to enable SMS-based 2FA using SNS"
345:   type        = bool
346:   default     = false
347: }
348:
349: variable "sns_topic_name" {
350:   description = "Name component for the SNS topic"
351:   type        = string
352: }
353:
354: variable "sns_display_name" {
355:   description = "Display name for the SNS topic (appears in SMS sender)"
356:   type        = string
357: }
358:
359: variable "sns_iam_role_name" {
360:   description = "Name component for the SNS IAM role"
361:   type        = string
362: }
363:
364: variable "configure_sms_preferences" {
365:   description = "Whether to configure account-level SMS preferences"
366:   type        = bool
367:   default     = false
368: }
369:
370: variable "sms_sender_id" {
371:   description = "Default sender ID for SMS messages (max 11 alphanumeric characters)"
372:   type        = string
373: }
374:
375: variable "sms_type" {
376:   description = "Default SMS type: Promotional or Transactional"
377:   type        = string
378:   validation {
379:     condition     = contains(["Promotional", "Transactional"], var.sms_type)
380:     error_message = "SMS type must be either 'Promotional' or 'Transactional'"
381:   }
382: }
383:
384: variable "sms_monthly_spend_limit" {
385:   description = "Monthly spend limit for SMS in USD"
386:   type        = number
387: }
388:
389: ##################### Redis SMS OTP Storage ##########################
390:
391: variable "enable_redis" {
392:   description = "Enable Redis deployment for SMS OTP storage"
393:   type        = bool
394:   default     = false
395: }
396:
397: variable "redis_password" {
398:   description = "Redis authentication password (from GitHub Secrets via TF_VAR_REDIS_PASSWORD)"
399:   type        = string
400:   sensitive   = true
401:   default     = ""
402:
403:   validation {
404:     condition     = var.enable_redis == false || length(var.redis_password) >= 8
405:     error_message = "Redis password must be at least 8 characters when Redis is enabled."
406:   }
407: }
408:
409: variable "redis_secret_name" {
410:   description = "Name of the Kubernetes secret for Redis password"
411:   type        = string
412:   default     = "redis-secret"
413: }
414:
415: variable "redis_namespace" {
416:   description = "Kubernetes namespace for Redis"
417:   type        = string
418:   default     = "redis"
419: }
420:
421: variable "redis_storage_size" {
422:   description = "Redis PVC storage size"
423:   type        = string
424:   default     = "1Gi"
425: }
426:
427: variable "redis_chart_version" {
428:   description = "Bitnami Redis Helm chart version"
429:   type        = string
430:   default     = "19.6.4"
431: }
432:
433: ##################### ArgoCD ##########################
434:
435: variable "enable_argocd" {
436:   description = "Whether to enable ArgoCD capability deployment"
437:   type        = bool
438:   default     = false
439: }
440:
441: variable "argocd_role_name_component" {
442:   description = "Name component for ArgoCD IAM role (between prefix and env)"
443:   type        = string
444: }
445:
446: variable "argocd_capability_name_component" {
447:   description = "Name component for ArgoCD capability (between prefix and env)"
448:   type        = string
449: }
450:
451: variable "argocd_namespace" {
452:   description = "Kubernetes namespace for ArgoCD resources"
453:   type        = string
454: }
455:
456: variable "argocd_project_name" {
457:   description = "ArgoCD project name for cluster registration"
458:   type        = string
459: }
460:
461: variable "idc_instance_arn" {
462:   description = "ARN of the AWS Identity Center instance used for Argo CD auth"
463:   type        = string
464:   default     = null
465:   nullable    = true
466: }
467:
468: variable "idc_region" {
469:   description = "Region of the Identity Center instance"
470:   type        = string
471:   default     = null
472:   nullable    = true
473: }
474:
475: variable "argocd_rbac_role_mappings" {
476:   description = "List of RBAC role mappings for Identity Center groups/users"
477:   type = list(object({
478:     role = string
479:     identities = list(object({
480:       id   = string
481:       type = string # SSO_GROUP or SSO_USER
482:     }))
483:   }))
484:   default = []
485: }
486:
487: variable "argocd_vpce_ids" {
488:   description = "Optional list of VPC endpoint IDs for private access to Argo CD"
489:   type        = list(string)
490:   default     = []
491: }
492:
493: variable "argocd_delete_propagation_policy" {
494:   description = "Delete propagation policy for ArgoCD capability (RETAIN or DELETE)"
495:   type        = string
496:   validation {
497:     condition     = contains(["RETAIN", "DELETE"], var.argocd_delete_propagation_policy)
498:     error_message = "Delete propagation policy must be either 'RETAIN' or 'DELETE'"
499:   }
500: }
501:
502: ##################### ArgoCD Applications ##########################
503:
504: variable "enable_argocd_apps" {
505:   description = "Whether to enable ArgoCD Application deployments"
506:   type        = bool
507:   default     = false
508: }
509:
510: variable "argocd_app_repo_url" {
511:   description = "Git repository URL containing application manifests. Supports both HTTPS (https://github.com/user/repo.git) and SSH (git@github.com:user/repo.git) URLs. SSH URLs require SSH key credentials to be configured via a Kubernetes Secret with label 'argocd.argoproj.io/secret-type: repository'"
512:   type        = string
513:   default     = null
514:   nullable    = true
515: }
516:
517: variable "argocd_app_target_revision" {
518:   description = "Git branch, tag, or commit to sync (default: HEAD)"
519:   type        = string
520:   default     = "HEAD"
521: }
522:
523: # Backend App Configuration
524: variable "argocd_app_backend_name" {
525:   description = "Name of the ArgoCD Application for backend"
526:   type        = string
527: }
528:
529: variable "argocd_app_backend_path" {
530:   description = "Path within the repository to the backend application manifests"
531:   type        = string
532:   default     = null
533:   nullable    = true
534: }
535:
536: variable "argocd_app_backend_namespace" {
537:   description = "Target Kubernetes namespace for the backend application"
538:   type        = string
539: }
540:
541: # Frontend App Configuration
542: variable "argocd_app_frontend_name" {
543:   description = "Name of the ArgoCD Application for frontend"
544:   type        = string
545: }
546:
547: variable "argocd_app_frontend_path" {
548:   description = "Path within the repository to the frontend application manifests"
549:   type        = string
550:   default     = null
551:   nullable    = true
552: }
553:
554: variable "argocd_app_frontend_namespace" {
555:   description = "Target Kubernetes namespace for the frontend application"
556:   type        = string
557: }
558:
559: variable "argocd_app_sync_policy_automated" {
560:   description = "Enable automated sync policy for ArgoCD Applications"
561:   type        = bool
562:   default     = true
563: }
564:
565: variable "argocd_app_sync_policy_prune" {
566:   description = "Enable prune for automated sync (delete resources not in Git)"
567:   type        = bool
568:   default     = true
569: }
570:
571: variable "argocd_app_sync_policy_self_heal" {
572:   description = "Enable self-heal for automated sync (auto-sync on drift detection)"
573:   type        = bool
574:   default     = true
575: }
```
