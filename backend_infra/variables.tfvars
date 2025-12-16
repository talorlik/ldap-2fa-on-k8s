env    = "prod"
region = "us-east-1"
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
