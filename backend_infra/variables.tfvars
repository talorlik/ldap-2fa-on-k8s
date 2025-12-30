env                    = "prod"
region                 = "us-east-1"
prefix = "talo-tf"
### VPC ###
vpc_name         = "vpc"
vpc_cidr         = "10.0.0.0/16"
igw_name         = "igw"
ngw_name         = "ngw"
route_table_name = "rtb"
### Kubernetes Cluster ###
k8s_version  = "1.34"
cluster_name = "kc"
### Endpoints ###
endpoint_sg_name = "ep-sg"
# STS endpoint is required for IRSA (IAM Roles for Service Accounts)
enable_sts_endpoint = true
# SNS endpoint is required for SMS 2FA functionality
enable_sns_endpoint = true
### EBS ###
ebs_name       = "ebs"
ebs_claim_name = "ebs-claim"
### ECR ###
ecr_name             = "docker-images"
image_tag_mutability = "IMMUTABLE"
ecr_lifecycle_policy = {
  rules = [
    {
      rulePriority = 1
      description  = "Always keep at least the most recent image"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["talo-ldap-auth"]
        countType     = "imageCountMoreThan"
        countNumber   = 1
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2
      description  = "Keep only one untagged image, expire all others"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 1
      }
      action = {
        type = "expire"
      }
    }
  ]
}
deployment_account_role_arn = "arn:aws:iam::944880695150:role/github-role"
deployment_account_external_id = "5f8697f36412ae83d62efc0a2ebd898fbb4a1721f0da986d9fa1ea7769223f47"
