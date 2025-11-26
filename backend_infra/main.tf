# Dynamic Account ID
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Logging Prefix Pattern
locals {
  current_identity = data.aws_caller_identity.current.arn
  current_account  = data.aws_caller_identity.current.account_id
  azs              = slice(data.aws_availability_zones.available.names, 0, 2)
  vpc_name         = "${var.prefix}-${var.region}-${var.vpc_name}-${var.env}"
  ngw_name         = "${var.prefix}-${var.region}-${var.ngw_name}-${var.env}"
  igw_name         = "${var.prefix}-${var.region}-${var.igw_name}-${var.env}"
  route_table_name = "${var.prefix}-${var.region}-${var.route_table_name}-${var.env}"
  public_subnet_names = [
    "${local.vpc_name}-public-subnet-1",
    "${local.vpc_name}-public-subnet-2"
  ]
  private_subnet_names = [
    "${local.vpc_name}-private-subnet-1",
    "${local.vpc_name}-private-subnet-2"
  ]
  cluster_name = "${var.prefix}-${var.region}-${var.cluster_name}-${var.env}"
  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"
  name    = local.vpc_name
  cidr    = var.vpc_cidr
  azs     = local.azs
  ### Private Subnets ###
  private_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  private_subnet_names = local.private_subnet_names
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  ### Public Subnets ###
  public_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  public_subnet_names = local.public_subnet_names
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  create_database_subnet_group = false
  # manage_default_network_acl    = false
  # manage_default_route_table    = false
  # manage_default_security_group = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = "ec2.internal"

  enable_nat_gateway = true
  single_nat_gateway = true
  nat_gateway_tags = {
    "Name"                                        = "${local.ngw_name}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  create_igw             = true
  create_egress_only_igw = false
  enable_vpn_gateway     = false

  private_route_table_tags = {
    Name = local.route_table_name
  }

  igw_tags = {
    Name = "${local.igw_name}"
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.9.0"

  name                   = local.cluster_name
  kubernetes_version     = var.k8s_version
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enabled_log_types           = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  create_cloudwatch_log_group = true

  node_iam_role_additional_policies = {
    "AmazonSSMManagedInstanceCore" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

module "endpoints" {
  source                 = "./modules/endpoints"
  env                    = var.env
  region                 = var.region
  prefix                 = var.prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnets        = module.vpc.private_subnets
  endpoint_sg_name       = var.endpoint_sg_name
  node_security_group_id = module.eks.node_security_group_id
  tags                   = local.tags
}

module "ebs" {
  source         = "./modules/ebs"
  env            = var.env
  region         = var.region
  prefix         = var.prefix
  ebs_name       = var.ebs_name
  ebs_claim_name = var.ebs_claim_name

  # Give time for the cluster to complete (controllers, RBAC and IAM propagation)
  depends_on = [module.eks]
}

module "ecr" {
  source               = "./modules/ecr"
  env                  = var.env
  region               = var.region
  prefix               = var.prefix
  ecr_name             = var.ecr_name
  image_tag_mutability = var.image_tag_mutability
  policy               = jsonencode(var.ecr_lifecycle_policy)
  tags                 = local.tags
}