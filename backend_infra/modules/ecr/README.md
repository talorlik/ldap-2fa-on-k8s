# ECR Module

This module creates an Amazon Elastic Container Registry (ECR) repository for storing Docker container images.

## Purpose

The ECR module provides a private Docker registry where container images can be pushed, stored, and pulled for deployment to the EKS cluster.

## Key Features

### Repository Configuration

- **Image Tag Mutability**: Configurable to allow or prevent image tag overwrites
- **Force Delete**: Enabled to allow repository deletion even when it contains images
- **Lifecycle Policy**: Configurable policy for automatic image cleanup (e.g., keeping only the last N images)

### Resource Naming

Resources are named using the pattern: `${prefix}-${region}-${ecr_name}-${env}`

## Important Configuration

### Image Tag Mutability

- **MUTABLE**: Allows overwriting existing image tags (useful for development)
- **IMMUTABLE**: Prevents tag overwrites (recommended for production)

### Lifecycle Policy

The lifecycle policy is configured via the `policy` variable and should be a JSON-encoded string. This policy controls:

- How many images to retain
- Which images to expire based on age or count
- Image tag patterns to include/exclude

Example lifecycle policy structure:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

## Variables

- `env`: Deployment environment (e.g., prod, dev)
- `region`: AWS region
- `prefix`: Prefix added to all resource names
- `ecr_name`: Name for the ECR repository
- `image_tag_mutability`: Either `MUTABLE` or `IMMUTABLE`
- `policy`: JSON-encoded lifecycle policy string
- `tags`: Map of tags to apply to resources

## Outputs

- `ecr_name`: Name of the ECR repository
- `ecr_arn`: ARN of the ECR repository
- `ecr_url`: Full URL of the ECR repository (for docker push/pull commands)

## Usage Example

```hcl
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
```

## Pushing Images

After the repository is created, authenticate Docker and push images:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr_url>
docker tag <image>:<tag> <ecr_url>:<tag>
docker push <ecr_url>:<tag>
```

## References

- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [ECR Lifecycle Policies](https://docs.aws.amazon.com/ecr/latest/userguide/lifecycle_policies.html)
