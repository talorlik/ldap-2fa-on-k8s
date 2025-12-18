# Stage 1: Build stage
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libldap2-dev \
    libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY src/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.12-slim

# Create non-root user for security
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libldap-2.5-0 \
    libsasl2-2 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy installed packages from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY src/app ./app

# Set environment variables
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

# Default environment variables (can be overridden)
ENV LDAP_HOST=openldap-stack-ha.ldap.svc.cluster.local \
    LDAP_PORT=389 \
    LDAP_USE_SSL=false \
    LDAP_BASE_DN=dc=ldap,dc=talorlik,dc=internal \
    LDAP_USER_SEARCH_BASE=ou=users \
    TOTP_ISSUER=LDAP-2FA-App \
    TOTP_DIGITS=6 \
    TOTP_INTERVAL=30 \
    TOTP_ALGORITHM=SHA1 \
    APP_NAME="LDAP 2FA Backend API" \
    DEBUG=false \
    LOG_LEVEL=INFO

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/healthz')" || exit 1

# Run the application with gunicorn for production
CMD ["gunicorn", "app.main:app", \
    "--bind", "0.0.0.0:8000", \
    "--workers", "2", \
    "--worker-class", "uvicorn.workers.UvicornWorker", \
    "--access-logfile", "-", \
    "--error-logfile", "-"]
