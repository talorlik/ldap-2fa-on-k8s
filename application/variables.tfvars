env                         = "prod"
region                      = "us-east-1"
prefix                      = "talo-tf"
principal_arn               = "arn:aws:iam::395323424870:user/taladmin"

##################### OpenLDAP ##########################
# OpenLDAP passwords - MUST be set via environment variables:
#   TF_VAR_OPENLDAP_ADMIN_PASSWORD
#   TF_VAR_OPENLDAP_CONFIG_PASSWORD
# Or via .env file (see README for details)
# Do NOT set passwords here in this file

# OpenLDAP domain (e.g., ldap.talorlik.internal)
openldap_ldap_domain = "ldap.talorlik.internal"

##################### Storage ##########################
# StorageClass configuration for OpenLDAP PVC
storage_class_name       = "gp3-ldap"
storage_class_type       = "gp3"
storage_class_encrypted  = true
storage_class_is_default = true

##################### ALB Configuration ##########################
app_name                    = "talo-ldap"
# ingress_alb_name            = "ingress-alb"
# service_alb_name            = "service-alb"
ingressclass_alb_name       = "ic-alb-ldap"
ingressclassparams_alb_name = "icp-alb-ldap"

# ALB group name for grouping multiple Ingress resources (defaults to app_name if not set)
# If set, will be concatenated as: ${prefix}-${region}-${alb_group_name}-${env} (truncated to 63 chars if needed)
# This is an internal Kubernetes identifier (max 63 characters)
# alb_group_name = "alb-group"

# ALB load balancer name - AWS resource name (max 32 characters per AWS constraints)
# If set, will be concatenated as: ${prefix}-${region}-${alb_load_balancer_name}-${env} (truncated to 32 chars if needed)
# If not set, defaults to alb_group_name (truncated to 32 chars if needed)
alb_load_balancer_name = "alb"

# Hostnames for ingress resources (defaults to subdomain.domain_name if not set)
phpldapadmin_host = "phpldapadmin.talorlik.com"
ltb_passwd_host   = "passwd.talorlik.com"

# ALB scheme: internet-facing or internal
alb_scheme = "internet-facing"

# ALB target type: ip or instance
alb_target_type = "ip"

# ALB SSL policy for HTTPS listeners
alb_ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# ALB IP address type: ipv4 or dualstack
alb_ip_address_type = "ipv4"

# EKS Cluster
# Cluster name will be automatically retrieved from backend_infra remote state
# if backend.hcl exists (created via setup-backend.sh script).
# Otherwise, provide cluster name directly:
# cluster_name = "talo-tf-us-east-1-kc-prod"

##################### Route53 ##########################
# Domain name for Route53 hosted zone and ACM certificate
domain_name = "talorlik.com"
# Subject alternative names for ACM certificate (wildcard subdomains)
# subject_alternative_names = ["*.talorlik.com"]
# Whether to use an existing Route53 zone
# use_existing_route53_zone = false
