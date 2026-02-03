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
- ✅ Profile status management (PENDING → COMPLETE → ACTIVE)
- ✅ Admin approval workflow
- ✅ User profile updates
- ✅ User revocation/deletion

### Group Management

- ✅ LDAP group synchronization
- ✅ User-group assignments
- ✅ Group creation, update, and deletion
- ✅ Admin group management

### Infrastructure

- ✅ PostgreSQL database for user data
- ✅ Redis for SMS OTP storage (with in-memory fallback)
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
- **`ldap/client.py`**: LDAP client for authentication and user/group management
- **`mfa/totp.py`**: TOTP generation and verification logic
- **`sms/client.py`**: AWS SNS integration for SMS delivery
- **`email/client.py`**: AWS SES integration for email delivery
- **`redis/client.py`**: Redis client for OTP storage with in-memory fallback

## Installation

### Prerequisites

- Python 3.11+ (tested with Python 3.15.0a5)
- PostgreSQL 12+
- Redis (optional, for SMS OTP storage)
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
(libldap2, libsasl2-2) and copies the virtual environment from the build stage.

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
| `DATABASE_URL` | PostgreSQL connection string | `postgresql+asyncpg://user:pass@host:5432/db` |
| `LDAP_HOST` | LDAP server hostname | `openldap.example.com` |
| `LDAP_ADMIN_PASSWORD` | LDAP admin password | `secret123` |
| `JWT_SECRET_KEY` | Secret key for JWT signing | `use-a-secure-random-key` |

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
| `APP_URL` | `http://localhost:8080` | Frontend application URL |

### Redis Configuration

| Variable | Default | Description |
| ---------- | --------- | ------------- |
| `REDIS_ENABLED` | `false` | Enable Redis for OTP storage |
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
| `JWT_EXPIRY_MINUTES` | `60` | JWT token expiration time |
| `JWT_REFRESH_EXPIRY_DAYS` | `7` | Refresh token expiration time |
| `CORS_ORIGINS` | `` | Comma-separated list of allowed CORS origins |

## API Endpoints

The API is organized into several endpoint groups:

### Authentication Endpoints

- `POST /api/auth/signup` - Register a new user
- `POST /api/auth/login` - Authenticate and get JWT tokens
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - Logout and invalidate tokens

### Verification Endpoints

- `POST /api/verify/email` - Verify email address with token
- `POST /api/verify/phone` - Verify phone number with code
- `POST /api/sms/send-code` - Request SMS verification code

### MFA Endpoints

- `POST /api/mfa/enroll` - Enroll in TOTP or SMS MFA
- `GET /api/mfa/qr-code` - Get QR code for TOTP enrollment

### Profile Endpoints

- `GET /api/profile/{username}` - Get user profile
- `PUT /api/profile/{username}` - Update user profile

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
│   │   ├── database/
│   │   │   ├── __init__.py
│   │   │   ├── connection.py      # Database connection management
│   │   │   └── models.py          # SQLAlchemy models
│   │   ├── email/
│   │   │   ├── __init__.py
│   │   │   └── client.py          # AWS SES email client
│   │   ├── ldap/
│   │   │   ├── __init__.py
│   │   │   └── client.py          # LDAP client
│   │   ├── mfa/
│   │   │   ├── __init__.py
│   │   │   └── totp.py            # TOTP manager
│   │   ├── redis/
│   │   │   ├── __init__.py
│   │   │   └── client.py          # Redis OTP client
│   │   └── sms/
│   │       ├── __init__.py
│   │       └── client.py           # AWS SNS SMS client
│   └── requirements.txt
├── Dockerfile
├── helm/                          # Kubernetes Helm charts
└── README.md
```

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests
pytest
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

### Kubernetes Deployment

The project includes Helm charts for Kubernetes deployment:

```bash
# Install using Helm
helm install ldap-2fa-backend ./helm/ldap-2fa-backend \
  --set database.url="postgresql+asyncpg://..." \
  --set ldap.host="..." \
  --set jwt.secretKey="..."
```

### Environment Variables

Set all required environment variables in your deployment configuration (ConfigMap/Secrets).

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
5. **HTTPS**: Always use HTTPS in production. Configure TLS termination at the
ingress level.
6. **CORS**: Restrict CORS origins to only trusted domains in production.
7. **Rate Limiting**: Consider implementing rate limiting for authentication endpoints.
8. **Input Validation**: All user inputs are validated using Pydantic models.
9. **SQL Injection**: Prevented by using SQLAlchemy ORM with parameterized queries.
10. **LDAP Injection**: Prevented by using ldap3 library's built-in escaping.
