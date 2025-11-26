locals {
  ecr_name = "${var.prefix}-${var.region}-${var.ecr_name}-${var.env}"
}

resource "aws_ecr_repository" "ecr" {
  name                 = local.ecr_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  tags = merge(
    {
      Name = "${local.ecr_name}"
    },
    var.tags
  )
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.ecr.name
  policy     = var.policy
}