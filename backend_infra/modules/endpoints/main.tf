# Create VPC endpoints (Private Links) for SSM Session Manager access to nodes
resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "${var.prefix}-${var.region}-${var.endpoint_sg_name}-${var.env}"
  vpc_id = var.vpc_id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoint_sg_ingress" {
  description                  = "Allow EKS Nodes to access VPC Endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.node_security_group_id
  security_group_id            = aws_security_group.vpc_endpoint_sg.id
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoint_sg_egress" {
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.vpc_endpoint_sg.id
}

resource "aws_vpc_endpoint" "private_link_ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = var.private_subnets
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "private-link-ssm"
  })
}

resource "aws_vpc_endpoint" "private_link_ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = var.private_subnets
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "private-link-ssmmessages"
  })
}

resource "aws_vpc_endpoint" "private_link_ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = var.private_subnets
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "private-link-ec2messages"
  })
}
