env           = "prod"
region        = "us-east-1"
prefix        = "talo-tf"
principal_arn = "arn:aws:iam::395323424870:user/taladmin"
### VPC ###
vpc_name         = "vpc"
vpc_cidr         = "10.0.0.0/16"
igw_name         = "igw"
ngw_name         = "ngw"
route_table_name = "rtb"
### Kubernetes Cluster ###
k8s_version  = "1.34"
cluster_name = "kc"
