ARG PY_IMAGE=python:3.12-slim-bookworm

# Stage 1: Build
FROM ${PY_IMAGE} AS builder
WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libldap2-dev \
    libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

COPY src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Stage 2: Runtime
FROM ${PY_IMAGE} AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libldap-2.5-0 \
    libsasl2-2 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r appgroup \
&& useradd -r -g appgroup -m -d /home/appuser -s /usr/sbin/nologin appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY --chown=appuser:appgroup src/app /app/app

ENV LDAP_HOST=openldap-stack-ha.ldap.svc.cluster.local
ENV LDAP_PORT=389
ENV LDAP_USE_SSL=false
ENV LDAP_BASE_DN=dc=ldap,dc=talorlik,dc=internal
ENV LDAP_USER_SEARCH_BASE=ou=users
ENV TOTP_ISSUER=LDAP-2FA-App
ENV TOTP_DIGITS=6
ENV TOTP_INTERVAL=30
ENV TOTP_ALGORITHM=SHA1
ENV APP_NAME=LDAP\ 2FA\ Backend\ API
ENV DEBUG=false
ENV LOG_LEVEL=INFO

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys,urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/healthz', timeout=2); sys.exit(0)"

CMD ["gunicorn", "app.main:app", \
    "--bind", "0.0.0.0:8000", \
    "--workers", "2", \
    "--worker-class", "uvicorn.workers.UvicornWorker", \
    "--access-logfile", "-", \
    "--error-logfile", "-"]
