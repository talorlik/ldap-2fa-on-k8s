# LDAP 2FA Backend API

A comprehensive Two-Factor Authentication (2FA) backend API built with FastAPI
that integrates with LDAP for user authentication and management. This backend
provides secure user signup, email/phone verification, TOTP and SMS-based MFA,
and admin user management capabilities.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [API Endpoints](#api-endpoints)
- [Development](#development)
- [Best Practices](#best-practices)
- [Deployment](#deployment)
- [Security](#security)

## Overview

The LDAP 2FA Backend API is a production-ready authentication and user management
system that combines:

- **LDAP Integration**: Authenticates users against an LDAP directory service
- **Two-Factor Authentication**: Supports both TOTP (Time-based One-Time Password)
and SMS-based MFA
- **User Management**: Complete user lifecycle management with email/phone verification
- **Admin Controls**: Admin dashboard for user activation, group management, and
system administration
- **Modern Stack**: Built with FastAPI, PostgreSQL, Redis, and AWS services
(SES, SNS)

## Features

### Authentication & Security

- ✅ LDAP-based user authentication
- ✅ JWT token-based session management
- ✅ TOTP (Google Authenticator, Authy compatible)
- ✅ SMS-based 2FA via AWS SNS
- ✅ Email verification via AWS SES
- ✅ Phone number verification
- ✅ Password hashing with bcrypt
- ✅ Refresh token support

### User Management

- ✅ User signup with profile creation
- ✅ Email and phone verification workflow
- ✅ Profile status management with automatic transitions:
  - **PENDING**: User registered, verification incomplete
  - **COMPLETE**: Both email and phone verified (automatic transition from PENDING)
  - **ACTIVE**: Admin activated with group assignment (required)
- ✅ Login restrictions: PENDING and COMPLETE users cannot log in
- ✅ Admin approval workflow with required group assignment
- ✅ User profile updates
- ✅ User revocation/deletion

### Group Management

- ✅ LDAP group synchronization
- ✅ User-group assignments
- ✅ Group creation, update, and deletion
- ✅ Admin group management

### Infrastructure

- ✅ PostgreSQL database for user data
- ✅ Redis for SMS OTP and login challenge storage (required; no in-memory fallback)
- ✅ Async/await architecture for high performance
- ✅ Health check endpoints for Kubernetes
- ✅ Comprehensive logging
- ✅ Docker containerization
- ✅ Helm charts for Kubernetes deployment

## Architecture

```ascii
┌─────────────┐
│   Frontend  │
└──────┬──────┘
       │ HTTP/REST
       ▼
┌─────────────────────────────────────┐
│      FastAPI Backend (Python)       │
│  ┌───────────────────────────────┐  │
│  │   API Routes (routes.py)      │  │
│  └───────────┬───────────────────┘  │
│              │                      │
│  ┌───────────▼───────────┐          │
│  │   Business Logic      │          │
│  │  - Authentication     │          │
│  │  - User Management    │          │
│  │  - MFA Verification   │          │
│  └───────────┬───────────┘          │
└──────────────┼──────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌─────────┐
│ LDAP   │ │Postgres│ │  Redis  │
│Server  │ │   DB   │ │  Cache  │
└────────┘ └────────┘ └─────────┘
    │          │          │
    └──────────┼──────────┘
               │
    ┌──────────▼──────────┐
    │   AWS Services      │
    │  - SES (Email)      │
    │  - SNS (SMS)        │
    └─────────────────────┘
```

### Key Components

- **`main.py`**: FastAPI application entry point, middleware configuration
- **`api/routes.py`**: All API endpoint definitions and request handlers
- **`config.py`**: Configuration management using Pydantic settings
- **`database/`**: SQLAlchemy models and async database connection management
- **Schema reference**: [PostgreSQL, OpenLDAP, and Redis schema](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/application/databases/SCHEMA.md)
- **`ldap/client.py`**: LDAP client for authentication and user/group management
- **`mfa/totp.py`**: TOTP generation and verification logic
- **`sms/client.py`**: AWS SNS integration for SMS delivery
- **`email/client.py`**: AWS SES integration for email delivery
- **`redis/client.py`**: Redis client for OTP and login challenge storage (shared across replicas)

## Installation

### Prerequisites

- Python 3.11+ (tested with Python 3.15.0a5)
- PostgreSQL 12+
- Redis (required, for SMS OTP and login challenge storage)
- LDAP server (OpenLDAP or compatible)
- AWS account with SES and SNS configured (for email/SMS)

### Local Development Setup

1. **Clone the repository** (if not already done):

    ```bash
    git clone <repository-url>
    cd ldap-2fa-on-k8s/application/backend
    ```

2. **Create a virtual environment**:

    ```bash
    python3 -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```

3. **Install dependencies**:

    ```bash
    pip install -r src/requirements.txt
    ```

4. **Set up environment variables** (create a `.env` file or export variables):

    ```bash
    # See Configuration section for all available variables
    export DATABASE_URL="postgresql+asyncpg://user:password@localhost:5432/ldap2fa"
    export LDAP_HOST="localhost"
    export LDAP_ADMIN_PASSWORD="your-ldap-admin-password"
    export JWT_SECRET_KEY="your-secret-key-here"
    ```

5. **Run database migrations** (if using Alembic):

    ```bash
    alembic upgrade head
    ```

6. **Start the development server**:

    ```bash
    cd src
    python -m app.main
    # Or use uvicorn directly:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
    ```

The API will be available at `http://localhost:8000` with interactive docs at `http://localhost:8000/api/docs`.

### Docker Setup

The Dockerfile uses a multi-stage build process to create an optimized production
image.

#### Build Process

1. **Build Stage**: Installs build dependencies (gcc, libldap2-dev, libsasl2-dev)
and creates a Python virtual environment with all required packages.

2. **Runtime Stage**: Creates a minimal runtime image with only runtime dependencies
(libldap-2.5-0, libsasl2-2) and copies the virtual environment from the build stage.

#### Building the Image

```bash
# Build with default Python image (Python 3.15.0a5-slim-trixie)
docker build -t ldap-2fa-backend .

# Build with custom Python base image
docker build --build-arg PY_IMAGE=python:3.11-slim -t ldap-2fa-backend .
```

#### Running the Container

The container runs as a non-root user (`appuser`) for security. Default environment
variables are set in the Dockerfile, but can be overridden:

```bash
docker run -d \
  -p 8000:8000 \
  -e DATABASE_URL="postgresql+asyncpg://user:pass@host:5432/db" \
  -e LDAP_HOST="openldap.example.com" \
  -e LDAP_ADMIN_PASSWORD="your-ldap-admin-password" \
  -e JWT_SECRET_KEY="your-secret-key" \
  ldap-2fa-backend
```

#### Dockerfile Features

- **Multi-stage build**: Reduces final image size by separating build and runtime
dependencies
- **Non-root user**: Runs as `appuser` user for enhanced security
- **Health check**: Built-in health check endpoint at `/api/healthz` (30s interval,
10s timeout)
- **Production server**: Uses Gunicorn with Uvicorn workers (2 workers by default)
- **Default environment variables**: Pre-configured defaults for LDAP, TOTP,
and application settings
- **Optimized layers**: Efficient layer caching for faster rebuilds

#### Default Environment Variables in Dockerfile

The following environment variables have defaults set in the Dockerfile
(can be overridden):

- `LDAP_HOST`: `openldap-stack-ha.ldap.svc.cluster.local`
- `LDAP_PORT`: `389`
- `LDAP_USE_SSL`: `false`
- `LDAP_BASE_DN`: `dc=ldap,dc=talorlik,dc=internal`
- `LDAP_USER_SEARCH_BASE`: `ou=users`
- `TOTP_ISSUER`: `LDAP-2FA-App`
- `TOTP_DIGITS`: `6`
- `TOTP_INTERVAL`: `30`
- `TOTP_ALGORITHM`: `SHA1`
- `APP_NAME`: `LDAP 2FA Backend API`
- `DEBUG`: `false`
- `LOG_LEVEL`: `INFO`

## Configuration

All configuration is managed through environment variables. The application uses
Pydantic Settings for type-safe configuration management.

### Required Configuration

| Variable | Description | Example |
| ---------- | ------------- | --------- |
| `DATABASE_URL` | PostgreSQL connection string (or use component vars below) | `postgresql+asyncpg://user:pass@host:5432/db` |
| `LDAP_HOST` | LDAP server hostname | `openldap.example.com` |
| `LDAP_ADMIN_PASSWORD` | LDAP admin password | `secret123` |
| `JWT_SECRET_KEY` | Secret key for JWT signing | `use-a-secure-random-key` |

### Database Configuration

The app accepts either a full connection URL or separate connection components
(e.g. when the password is provided via Kubernetes Secret):

| Variable | Description |
| ---------- | ------------- |
| `DATABASE_URL` | Full PostgreSQL URL: `postgresql+asyncpg://user:password@host:port/database`. Used when set and valid. |
| `DATABASE_HOST` | Database host (used with component-based config). |
| `DATABASE_PORT` | Database port (default `5432`). |
| `DATABASE_USER` | Database user. |
| `DATABASE_NAME` | Database name. |
| `DATABASE_PASSWORD` | Database password (from Secret or env). |
| `DATABASE_PASSWORD_FILE` | Path to a file containing the password (e.g. Kubernetes Secret mounted as file). If set, the app reads the password from this file instead of `DATABASE_PASSWORD` so the password is not in the process environment. |

When `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_NAME`, and either `DATABASE_PASSWORD`
or `DATABASE_PASSWORD_FILE` are set, the app builds `DATABASE_URL` from these.
This is the pattern used by the Helm chart when `database.externalSecret` is enabled
with only a password (no full URL in the secret).

### LDAP Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `LDAP_HOST` | `openldap-stack-ha.ldap.svc.cluster.local` | LDAP server hostname |
| `LDAP_PORT` | `389` | LDAP server port |
| `LDAP_USE_SSL` | `false` | Enable SSL/TLS for LDAP |
| `LDAP_BASE_DN` | `dc=ldap,dc=talorlik,dc=internal` | Base DN for LDAP |
| `LDAP_ADMIN_DN` | `cn=admin,dc=ldap,...` | Admin DN for LDAP operations |
| `LDAP_USER_SEARCH_BASE` | `ou=users` | User search base |
| `LDAP_GROUP_SEARCH_BASE` | `ou=groups` | Group search base |
| `LDAP_ADMIN_GROUP_DN` | `cn=admins,ou=groups,...` | Admin group DN |

### MFA/TOTP Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `TOTP_ISSUER` | `LDAP-2FA-App` | TOTP issuer name (shown in authenticator apps) |
| `TOTP_DIGITS` | `6` | Number of digits in TOTP code |
| `TOTP_INTERVAL` | `30` | Time interval in seconds |
| `TOTP_ALGORITHM` | `SHA1` | Hash algorithm (SHA1, SHA256, SHA512) |

### SMS Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `ENABLE_SMS_2FA` | `false` | Enable SMS-based 2FA |
| `AWS_REGION` | `us-east-1` | AWS region for SNS |
| `SNS_TOPIC_ARN` | `` | SNS topic ARN (optional) |
| `SMS_SENDER_ID` | `2FA` | SMS sender ID |
| `SMS_CODE_LENGTH` | `6` | Length of SMS verification code |
| `SMS_CODE_EXPIRY_SECONDS` | `300` | SMS code expiration time (5 minutes) |

### Email Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `ENABLE_EMAIL_VERIFICATION` | `true` | Enable email verification |
| `SES_SENDER_EMAIL` | `noreply@example.com` | Verified SES sender email |
| `EMAIL_VERIFICATION_EXPIRY_HOURS` | `24` | Email verification link expiry |
| `PASSWORD_RESET_EXPIRY_HOURS` | `1` | Password reset link expiry (hours) |
| `APP_URL` | `http://localhost:8080` | Frontend application URL (used in password reset and verification links) |

### Redis Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `REDIS_ENABLED` | `true` | Redis is required for OTP and login challenge storage |
| `REDIS_HOST` | `redis-master.redis.svc.cluster.local` | Redis hostname |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_PASSWORD` | `` | Redis password |
| `REDIS_SSL` | `false` | Enable SSL for Redis |

### Application Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `APP_NAME` | `LDAP 2FA Backend API` | Application name |
| `DEBUG` | `false` | Enable debug mode |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `JWT_EXPIRY_MINUTES` | `60` | JWT token expiration time (default session) |
| `JWT_REFRESH_EXPIRY_DAYS` | `7` | Session expiry when "Remember me" is used (longer-lived JWT) |
| `CORS_ORIGINS` | `` | Comma-separated list of allowed CORS origins |

## API Endpoints

The API is organized into several endpoint groups:

### Authentication Endpoints (two-step login)

- `POST /api/auth/login/start` - Step 1: validate username/password; optional body
field `remember_me` for longer-lived JWT; returns challenge token and MFA options
(`totp_enrolled`, `sms_available`)
- `POST /api/auth/login/totp-setup` - Generate TOTP secret for first-time Authenticator
setup (body: `challenge_token`)
- `POST /api/auth/login/verify` - Step 2: verify MFA code (body: `challenge_token`,
`mfa_method`, `verification_code`); returns JWT (expiry uses `JWT_REFRESH_EXPIRY_DAYS`
if remember_me was set)
- `POST /api/auth/sms/send-code` - Send SMS code (body: `challenge_token` from
login/start, or `username`+`password`)
- `POST /api/auth/forgot-password` - Request password reset link by email
(body: `email`); generic response for security
- `POST /api/auth/reset-password` - Set new password with token from email link
(body: `token`, `username`, `new_password`, `confirm_password`)
- `POST /api/auth/login` - Legacy one-step login (username + password + verification_code)
- `POST /api/auth/signup` - Register a new user

### MFA / Re-enrollment

- `POST /api/auth/enroll` - Re-enroll or change MFA method (active users only;
TOTP or SMS)
- `GET /api/mfa/methods` - List available MFA methods
- `GET /api/mfa/status/{username}` - Get user MFA enrollment status

### Verification Endpoints

- `POST /api/auth/verify-email` - Verify email address with token
- `POST /api/auth/verify-phone` - Verify phone number with code
- `POST /api/auth/resend-verification` - Resend verification email or SMS

Password reset: `forgot-password` sends an email with link to
`APP_URL/#reset-password?token=...&username=...`; `reset-password` accepts that
token and new password, updates LDAP and DB.

### Profile Endpoints

- `GET /api/profile/{username}` - Get user profile
- `PUT /api/profile/{username}` - Update user profile
- `POST /api/profile/request-email-change` - Request email change; sends
  verification link to new address (body: `new_email`)
- `POST /api/profile/request-phone-change` - Request phone change; sends SMS
  code to new number (body: `phone_country_code`, `phone_number`)
- `POST /api/profile/{username}/change-password` - Change password
  (authenticated; body: `current_password`, `new_password`, `confirm_password`)

For verified email/phone changes: use request-email-change or
request-phone-change, complete verification via verify-email or verify-phone,
then save profile again.

### Admin Endpoints

- `POST /api/admin/users/{user_id}/activate` - Activate user account
- `DELETE /api/admin/users/{user_id}` - Reject/delete user
- `GET /api/admin/users` - List all users
- `POST /api/admin/groups` - Create group
- `GET /api/admin/groups` - List all groups
- `PUT /api/admin/groups/{group_id}` - Update group
- `DELETE /api/admin/groups/{group_id}` - Delete group
- `POST /api/admin/users/{user_id}/groups` - Assign groups to user
- `PUT /api/admin/users/{user_id}/groups` - Replace user groups
- `DELETE /api/admin/users/{user_id}/groups/{group_id}` - Remove user from group
- `DELETE /api/admin/users/{user_id}/revoke` - Revoke user access

### Health Check

- `GET /api/healthz` - Health check endpoint for Kubernetes

For detailed API documentation, visit `/api/docs` when the server is running.

## Development

### Project Structure

```bash
backend/
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   └── routes.py          # All API endpoints
│   │   ├── config.py              # Configuration management
│   │   ├── main.py                # FastAPI app entry point
│   │   ├── seed_admin.py          # LDAP admin seed job entry point
│   │   ├── database/
│   │   │   ├── __init__.py
│   │   │   ├── connection.py     # Database connection management
│   │   │   └── models.py         # SQLAlchemy models
│   │   ├── utils/
│   │   │   ├── __init__.py
│   │   │   └── security.py       # Log redaction for secrets
│   │   ├── email/
│   │   │   ├── __init__.py
│   │   │   └── client.py         # AWS SES email client
│   │   ├── ldap/
│   │   │   ├── __init__.py
│   │   │   └── client.py         # LDAP client
│   │   ├── mfa/
│   │   │   ├── __init__.py
│   │   │   └── totp.py           # TOTP manager
│   │   ├── redis/
│   │   │   ├── __init__.py
│   │   │   └── client.py         # Redis OTP client
│   │   └── sms/
│   │       ├── __init__.py
│   │       └── client.py         # AWS SNS SMS client
│   └── requirements.txt
├── Dockerfile
├── pyrightconfig.json             # Pyright/Pylance extraPaths for app imports
├── helm/                          # Kubernetes Helm chart
│   └── ldap-2fa-backend/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── README.md
```

### IDE / Editor

The package lives under `src/app/`. For correct import resolution (`from app.xxx`),
run or open the project from the `backend` directory and ensure `src` is on the
Python path. A `pyrightconfig.json` in the backend root sets `extraPaths: ["src"]`
so Pylance/Pyright resolve `app` correctly. If imports still show as unresolved,
reload the editor window.

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests (from backend root; run from src if your test runner expects it)
cd src && pytest
# or: PYTHONPATH=src pytest
```

### Code Quality

```bash
# Format code
black src/

# Lint code
flake8 src/
pylint src/

# Type checking
mypy src/
```

## Best Practices

This project follows several Python and FastAPI best practices to ensure code quality,
performance, and maintainability.

### 1. Lazy Logging Formatting

**Why it matters**: Using lazy formatting in logging calls improves performance
by only formatting strings when the log level is actually enabled.

**Implementation**:

```python
# ❌ BAD: Always formats the string, even if logging is disabled
logger.debug(f"Processing user {user.username} with {len(items)} items")

# ✅ GOOD: Only formats if DEBUG level is enabled
logger.debug("Processing user %s with %s items", user.username, len(items))
```

**Benefits**:

- **Performance**: Avoids unnecessary string formatting when log levels are disabled
(common in production)
- **Cost**: Reduces CPU usage, especially in high-throughput scenarios
- **Exception Safety**: Prevents exceptions during formatting when logging is disabled
- **Best Practice**: Recommended by Python logging documentation and linters
(pylint, flake8)

**Example from this codebase**:

```python
# All logger calls use lazy % formatting
logger.info("User %s signed up successfully", user.username)
logger.error("Failed to send email to %s: %s - %s", to_email, error_code, error_message)
logger.debug("User %s belongs to %s groups", username, len(groups))
```

### 2. Async/Await Architecture

All database operations and I/O-bound tasks use async/await for better concurrency:

```python
async def get_user(session: AsyncSession, username: str):
  result = await session.execute(select(User).where(User.username == username))
  return result.scalar_one_or_none()
```

### 3. Type Hints

Comprehensive type hints throughout the codebase for better IDE support and type
safety:

```python
def authenticate(self, username: str, password: str) -> tuple[bool, str]:
    ...
```

### 4. Pydantic Models

Request/response validation using Pydantic models:

```python
class SignupRequest(BaseModel):
  username: str = Field(..., min_length=3, max_length=50)
  email: EmailStr
  password: str = Field(..., min_length=8)
  ...
```

### 5. Error Handling

Consistent error handling with appropriate HTTP status codes:

```python
if not user:
  raise HTTPException(
    status_code=status.HTTP_404_NOT_FOUND,
    detail="User not found"
  )
```

### 6. Security Best Practices

- Password hashing with bcrypt
- JWT tokens with expiration
- Input validation and sanitization
- SQL injection prevention via SQLAlchemy ORM
- LDAP injection prevention via parameterized queries
- CORS configuration for API security

### 7. Configuration Management

Centralized configuration using Pydantic Settings with environment variable support:

```python
class Settings(BaseSettings):
  ldap_host: str = os.getenv("LDAP_HOST", "localhost")
  ...
```

### 8. Database Session Management

Proper async session management with dependency injection:

```python
async def get_async_session() -> AsyncGenerator[AsyncSession, None]:
  async with AsyncSessionLocal() as session:
    try:
      yield session
      await session.commit()
    except Exception:
      await session.rollback()
      raise
```

## Deployment

> [!IMPORTANT]
>
> **Deployment Dependency:** The backend application deployment **depends on running
> both** the **Backend Build and Push** (`03-backend_build_push.yaml`) and
> **Frontend Build and Push** (`03-frontend_build_push.yaml`) workflows.
> Both workflows must be completed before ArgoCD can sync the applications or
> manual Helm deployment can succeed. Without both images in ECR, the deployment
> will fail.

### Kubernetes Deployment

The project includes Helm charts for Kubernetes deployment.

**Database credentials from Kubernetes Secret (recommended):** Use `database.externalSecret`
so the password is never in ConfigMap or values. Either store the full URL in the
secret and set `database.externalSecret.urlKey` (e.g. `DATABASE_URL`), or store
only the password and set `database.host`, `database.port`, `database.user`,
`database.name` in values; the chart injects the password from the secret and the
app builds the URL.

- **Full URL in secret:** Set `database.externalSecret.urlKey: "DATABASE_URL"`
and put the full `postgresql+asyncpg://...` string in that secret key.
- **Password only in secret:** Leave `urlKey` unset; set `database.externalSecret.passwordKey`
(e.g. `"password"`) and set `database.host`, `database.port`, `database.user`,
`database.name` in values. Optional:
`database.externalSecret.passwordFile.enabled: true` mounts the password as a
file and sets `DATABASE_PASSWORD_FILE` so the password is not in the process environment.

```bash
# Install using Helm (with external secret for DB password)
helm install ldap-2fa-backend ./helm/ldap-2fa-backend \
  --set database.host="postgresql.ldap-2fa.svc.cluster.local" \
  --set database.user="ldap2fa" \
  --set database.name="ldap2fa" \
  --set ldap.host="..." \
  --set jwt.secretKey="..."
# Ensure the namespace has a Secret (e.g. postgresql-secret) with the DB password.
```

### Environment Variables

Set all required environment variables in your deployment configuration
(ConfigMap/Secrets). Database password should come from a Kubernetes Secret
(see above), not from ConfigMap or plain values.

### Health Checks

The application provides a health check endpoint at `/api/healthz` for Kubernetes
liveness/readiness probes.

### Scaling

The application is stateless and can be horizontally scaled. Use a load balancer
in front of multiple instances.

## Security

### Security Considerations

1. **Secrets Management**: Never commit secrets to version control. Use Kubernetes
Secrets or a secrets management service.
2. **JWT Secret Key**: Use a strong, randomly generated secret key for JWT signing:

    ```bash
    python -c "import secrets; print(secrets.token_urlsafe(32))"
    ```

3. **LDAP Credentials**: Store LDAP admin credentials securely (Kubernetes Secrets).
4. **Database Credentials**: Use strong passwords and restrict database access.
Provide the password only via Kubernetes Secret (env or file mount); the app redacts
connection strings and passwords from startup error logs so they never appear in
log output.
5. **HTTPS**: Always use HTTPS in production. Configure TLS termination at the
ingress level.
6. **CORS**: Restrict CORS origins to only trusted domains in production.
7. **Rate Limiting**: Consider implementing rate limiting for authentication endpoints.
8. **Input Validation**: All user inputs are validated using Pydantic models.
9. **SQL Injection**: Prevented by using SQLAlchemy ORM with parameterized queries.
10. **LDAP Injection**: Prevented by using ldap3 library's built-in escaping.
