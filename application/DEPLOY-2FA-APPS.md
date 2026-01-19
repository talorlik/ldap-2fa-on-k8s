# Deploying the 2FA Application (Backend and Frontend)

This guide provides step-by-step instructions for deploying the backend and frontend
applications after the infrastructure has been successfully deployed.

## Prerequisites

✅ **Infrastructure must be deployed:**

- Backend infrastructure (`backend_infra`) - EKS cluster, VPC, ECR, etc.
- Application infrastructure (`application`) - OpenLDAP, PostgreSQL, Redis, ALB,
Route53, etc.

✅ **Required tools:**

- `kubectl` configured to access your EKS cluster
- `helm` (v3.x)
- `aws` CLI configured with appropriate credentials
- `docker` (for building images, if not using GitHub Actions)

## Overview

The deployment process involves:

1. **Build and push Docker images** to ECR (backend and frontend)
2. **Gather required configuration values** from Terraform outputs
3. **Deploy backend Helm chart** with proper values
4. **Deploy frontend Helm chart** with proper values
5. **Verify deployment**

## Step 1: Build and Push Docker Images

You have two options for building and pushing images:

### Option A: Using GitHub Actions (Recommended)

1. **Build and push backend image:**
   - Go to GitHub → Actions → "Backend Build and Push"
   - Click "Run workflow"
   - Select environment (prod or dev)
   - Click "Run workflow"
   - Wait for the workflow to complete
   - Note the image tag from the workflow output (format: `ldap-2fa-backend-<commit-sha>`)

2. **Build and push frontend image:**
   - Go to GitHub → Actions → "Frontend Build and Push"
   - Click "Run workflow"
   - Select environment (prod or dev)
   - Click "Run workflow"
   - Wait for the workflow to complete
   - Note the image tag from the workflow output (format: `ldap-2fa-frontend-<commit-sha>`)

The GitHub Actions workflows automatically:

- Build Docker images
- Push to ECR
- Update Helm values.yaml files with the new image tags
- Commit changes to the repository

### Option B: Manual Build and Push

If you prefer to build locally:

```bash
# Set variables
export AWS_REGION="us-east-1"
export ECR_REPO_NAME="talo-tf-us-east-1-docker-images-prod"  # Adjust based on your setup
export AWS_ACCOUNT_ID="944880695150"  # Your deployment account ID

# Get ECR login
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build and push backend
cd application/backend
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:ldap-2fa-backend-$(git rev-parse --short HEAD) .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:ldap-2fa-backend-$(git rev-parse --short HEAD)

# Build and push frontend
cd ../frontend
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:ldap-2fa-frontend-$(git rev-parse --short HEAD) .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:ldap-2fa-frontend-$(git rev-parse --short HEAD)
```

## Step 2: Gather Required Configuration Values

Get the required values from Terraform outputs:

```bash
cd application

# Get IngressClass name
INGRESS_CLASS=$(terraform output -raw alb_ingress_class_name)
echo "IngressClass: ${INGRESS_CLASS}"

# Get ALB load balancer name (from variables.tfvars or compute it)
# Format: ${prefix}-${region}-${alb_load_balancer_name}-${env}
PREFIX="talo-tf"
REGION="us-east-1"
ALB_LB_NAME="alb"
ENV="prod"
ALB_NAME="${PREFIX}-${REGION}-${ALB_LB_NAME}-${ENV}"
# Truncate to 32 chars if needed
ALB_NAME=$(echo "${ALB_NAME}" | cut -c1-32)
echo "ALB Name: ${ALB_NAME}"

# Get hostname
HOSTNAME="app.talorlik.com"  # From variables.tfvars: twofa_app_host
echo "Hostname: ${HOSTNAME}"

# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_url 2>/dev/null || echo "")
if [ -z "$ECR_URL" ]; then
  print_error "ECR URL not found in Terraform outputs."
  print_error "Make sure backend_infra has been deployed and outputs ecr_url."
  print_error "Alternatively, ECR_REPOSITORY_NAME GitHub variable should be set automatically"
  print_error "after provisioning backend infrastructure."
  exit 1
fi
echo "ECR URL: ${ECR_URL}"

# Get image tags (from GitHub Actions or latest commit)
BACKEND_TAG="ldap-2fa-backend-$(git rev-parse --short HEAD)"  # Or use tag from GitHub Actions
FRONTEND_TAG="ldap-2fa-frontend-$(git rev-parse --short HEAD)"  # Or use tag from GitHub Actions
echo "Backend Tag: ${BACKEND_TAG}"
echo "Frontend Tag: ${FRONTEND_TAG}"

# Get SES IAM Role ARN (for IRSA)
SES_ROLE_ARN=$(terraform output -raw ses_iam_role_arn 2>/dev/null || echo "")
echo "SES Role ARN: ${SES_ROLE_ARN}"

# Get SNS IAM Role ARN (for IRSA, if SMS 2FA is enabled)
SNS_ROLE_ARN=$(terraform output -raw sns_iam_role_arn 2>/dev/null || echo "")
echo "SNS Role ARN: ${SNS_ROLE_ARN}"

# Get domain name
DOMAIN_NAME=$(terraform output -raw route53_domain_name)
echo "Domain: ${DOMAIN_NAME}"

# Get PostgreSQL connection info
POSTGRES_HOST=$(terraform output -raw postgresql_host)
echo "PostgreSQL Host: ${POSTGRES_HOST}"

# Get Redis connection info
REDIS_HOST=$(terraform output -raw redis_host)
REDIS_PORT=$(terraform output -raw redis_port)
echo "Redis Host: ${REDIS_HOST}:${REDIS_PORT}"

# Get SES sender email
SES_SENDER_EMAIL=$(terraform output -raw ses_sender_email)
echo "SES Sender: ${SES_SENDER_EMAIL}"

# Get SNS topic ARN (if SMS 2FA is enabled)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null || echo "")
echo "SNS Topic ARN: ${SNS_TOPIC_ARN}"
```

## Step 3: Create Namespace

Create the namespace for the 2FA application:

```bash
kubectl create namespace 2fa-app
```

## Step 4: Deploy Backend Application

Create a values file for the backend deployment:

```bash
cat > /tmp/backend-values.yaml <<EOF
# Image configuration
image:
  repository: "${ECR_URL}"
  tag: "${BACKEND_TAG}"

# Ingress configuration
ingress:
  enabled: true
  className: "${INGRESS_CLASS}"
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: "${ALB_NAME}"
  hosts:
    - host: "${HOSTNAME}"
      paths:
        - path: /api
          pathType: Prefix

# Service account with IRSA annotation
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${SES_ROLE_ARN}"  # Use SES role (includes SNS if enabled)

# LDAP configuration (adjust based on your LDAP setup)
ldap:
  host: "openldap-stack-ha.ldap.svc.cluster.local"
  port: 389
  baseDn: "dc=ldap,dc=talorlik,dc=internal"
  adminDn: "cn=admin,dc=ldap,dc=talorlik,dc=internal"

# Database configuration
database:
  url: "postgresql+asyncpg://ldap2fa:CHANGE_ME@${POSTGRES_HOST}:5432/ldap2fa"
  externalSecret:
    enabled: true
    secretName: "postgresql-secret"
    passwordKey: "password"

# Email configuration
email:
  enabled: true
  senderEmail: "${SES_SENDER_EMAIL}"
  appUrl: "https://${HOSTNAME}"

# SMS configuration (if enabled)
sms:
  enabled: true  # Set to false if SMS 2FA is not enabled
  awsRegion: "${REGION}"
  snsTopicArn: "${SNS_TOPIC_ARN}"

# Redis configuration (if SMS is enabled)
redis:
  enabled: true  # Set to false if SMS 2FA is not enabled
  host: "${REDIS_HOST}"
  port: ${REDIS_PORT}
  existingSecret:
    enabled: true
    name: "redis-secret"
    key: "redis-password"
EOF
```

Deploy the backend:

```bash
cd application/backend/helm

helm upgrade --install ldap-2fa-backend ldap-2fa-backend \
  --namespace 2fa-app \
  --create-namespace \
  --values /tmp/backend-values.yaml \
  --wait \
  --timeout 10m
```

## Step 5: Deploy Frontend Application

Create a values file for the frontend deployment:

```bash
cat > /tmp/frontend-values.yaml <<EOF
# Image configuration
image:
  repository: "${ECR_URL}"
  tag: "${FRONTEND_TAG}"

# Ingress configuration
ingress:
  enabled: true
  className: "${INGRESS_CLASS}"
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: "${ALB_NAME}"
  hosts:
    - host: "${HOSTNAME}"
      paths:
        - path: /
          pathType: Prefix
EOF
```

Deploy the frontend:

```bash
cd application/frontend/helm

helm upgrade --install ldap-2fa-frontend ldap-2fa-frontend \
  --namespace 2fa-app \
  --create-namespace \
  --values /tmp/frontend-values.yaml \
  --wait \
  --timeout 10m
```

## Step 6: Verify Deployment

Check the deployment status:

```bash
# Check pods
kubectl get pods -n 2fa-app

# Check services
kubectl get svc -n 2fa-app

# Check ingress
kubectl get ingress -n 2fa-app

# Check backend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-backend --tail=50

# Check frontend logs
kubectl logs -n 2fa-app -l app=ldap-2fa-frontend --tail=50

# Test backend health endpoint
kubectl run -it --rm test-backend --image=curlimages/curl --restart=Never -- \
  curl -k https://${HOSTNAME}/api/healthz

# Check ALB target health
ALB_ARN=$(aws elbv2 describe-load-balancers --region ${REGION} --query "LoadBalancers[?LoadBalancerName=='${ALB_NAME}'].LoadBalancerArn" --output text)
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --region ${REGION} --load-balancer-arn ${ALB_ARN} --query "TargetGroups[?contains(TargetGroupName, 'backend')].TargetGroupArn" --output text | head -1)
aws elbv2 describe-target-health --region ${REGION} --target-group-arn ${TARGET_GROUP_ARN}
```

## Step 7: Access the Application

Once deployed, access the application at:

- **Frontend**: `https://${HOSTNAME}` (e.g., `https://app.talorlik.com`)
- **Backend API**: `https://${HOSTNAME}/api` (e.g., `https://app.talorlik.com/api`)
- **API Documentation**: `https://${HOSTNAME}/api/docs` (Swagger UI)

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n 2fa-app <pod-name>

# Check logs
kubectl logs -n 2fa-app <pod-name>

# Check if secrets exist
kubectl get secrets -n 2fa-app
kubectl get secrets -n ldap-2fa  # PostgreSQL secret
kubectl get secrets -n redis      # Redis secret
```

### Image Pull Errors

```bash
# Verify ECR authentication
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URL%%/*}

# Check if image exists in ECR
aws ecr describe-images --repository-name ${ECR_REPO_NAME} --region ${REGION} --image-ids imageTag=${BACKEND_TAG}
```

### Ingress Not Creating ALB

```bash
# Check Ingress status
kubectl describe ingress -n 2fa-app

# Verify IngressClass exists
kubectl get ingressclass ${INGRESS_CLASS}

# Check IngressClassParams
kubectl get ingressclassparams
```

### Backend Cannot Connect to Services

```bash
# Test LDAP connectivity from backend pod
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('openldap-stack-ha.ldap.svc.cluster.local', 389)); print('LDAP reachable')"

# Test PostgreSQL connectivity
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('${POSTGRES_HOST}', 5432)); print('PostgreSQL reachable')"

# Test Redis connectivity
kubectl exec -n 2fa-app -it <backend-pod-name> -- \
  python -c "import socket; s = socket.socket(); s.connect(('${REDIS_HOST}', ${REDIS_PORT})); print('Redis reachable')"
```

### IRSA Not Working

```bash
# Check service account annotations
kubectl get serviceaccount -n 2fa-app -o yaml

# Verify IAM role exists
aws iam get-role --role-name <role-name>

# Check pod annotations (should have AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE)
kubectl get pod -n 2fa-app -o jsonpath='{.items[0].spec.containers[0].env}' | jq
```

## Updating Deployments

To update the applications after code changes:

1. **Rebuild and push images** (via GitHub Actions or manually)
2. **Update Helm values** with new image tags
3. **Upgrade Helm releases:**

```bash
# Update backend
helm upgrade ldap-2fa-backend application/backend/helm/ldap-2fa-backend \
  --namespace 2fa-app \
  --set image.tag="${NEW_BACKEND_TAG}" \
  --reuse-values

# Update frontend
helm upgrade ldap-2fa-frontend application/frontend/helm/ldap-2fa-frontend \
  --namespace 2fa-app \
  --set image.tag="${NEW_FRONTEND_TAG}" \
  --reuse-values
```

## Alternative: Enable ArgoCD Applications

If you prefer GitOps deployment via ArgoCD:

1. **Enable ArgoCD applications** in `variables.tfvars`:

   ```hcl
   enable_argocd_apps = true
   ```

2. **Configure sync policy** (optional):

   ```hcl
   argocd_app_sync_policy_automated = true
   argocd_app_sync_policy_prune     = true
   argocd_app_sync_policy_self_heal = true
   ```

3. **Apply Terraform changes:**

   ```bash
   cd application
   terraform apply
   ```

4. **ArgoCD will automatically deploy** the applications from Git

## Notes

- The backend and frontend share the same ALB via path-based routing
(`/api` for backend, `/` for frontend)
- Both applications use the same hostname (`app.talorlik.com`)
- The ALB load balancer name is truncated to 32 characters per AWS constraints
- IRSA (IAM Roles for Service Accounts) is used for AWS service access (SES, SNS)
- Secrets (PostgreSQL, Redis, LDAP) are managed by Terraform and referenced by
the Helm charts
- The IngressClass and IngressClassParams are created by Terraform and shared
across all applications
