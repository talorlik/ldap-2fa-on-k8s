# Route53 Module

This module creates a Route53 hosted zone and an ACM certificate with DNS validation
for a domain.

## Purpose

The Route53 module:

- Creates a Route53 hosted zone for domain management
- Optionally uses an existing Route53 hosted zone
- Creates an ACM certificate with DNS validation
- Automatically validates the certificate using Route53 DNS records

## What it Creates

1. **Route53 Hosted Zone** (`aws_route53_zone.this`)
   - Public hosted zone for the domain
   - Only created if `use_existing_route53_zone` is `false`
   - Includes name servers output for registrar configuration

2. **ACM Certificate** (via `terraform-aws-modules/acm/aws`)
   - Certificate for the domain
   - DNS validation method
   - Automatic validation via Route53 DNS records
   - Supports subject alternative names (SANs)
   - Waits for validation to complete (30 minute timeout)

## Usage

### Create New Route53 Zone

```hcl
module "route53" {
  source = "./modules/route53"

  env        = "prod"
  region     = "us-east-1"
  prefix     = "myorg"
  domain_name = "example.com"

  subject_alternative_names = ["*.example.com"]
}
```

### Use Existing Route53 Zone

```hcl
module "route53" {
  source = "./modules/route53"

  env        = "prod"
  region     = "us-east-1"
  prefix     = "myorg"
  domain_name = "example.com"

  use_existing_route53_zone = true
  subject_alternative_names = ["*.example.com"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| env | Deployment environment (for tagging) | `string` | n/a | yes |
| region | Deployment region | `string` | n/a | yes |
| prefix | Prefix for the resources | `string` | n/a | yes |
| domain_name | Root domain name (e.g., talorlik.com) | `string` | n/a | yes |
| subject_alternative_names | List of subject alternative names for the ACM certificate | `list(string)` | `[]` | no |
| use_existing_route53_zone | Whether to use an existing Route53 zone | `bool` | `false` | no |
| tags | Tags to apply to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ------ | ------------- |
| acm_cert_arn | ACM certificate ARN (validated and ready for use) |
| domain_name | Root domain name |
| zone_id | Route53 hosted zone ID |
| name_servers | Route53 name servers for the hosted zone (for registrar configuration) |

## Certificate Validation

The module automatically validates the ACM certificate using DNS validation:

1. ACM creates validation records
2. The module creates Route53 records for validation
3. ACM validates the certificate
4. Certificate becomes ready for use

The module waits up to 30 minutes for validation to complete. If validation fails,
Terraform will show an error.

## Name Server Configuration

When creating a new Route53 hosted zone, you must configure your domain registrar
to use the name servers from the `name_servers` output:

1. Get the name servers from the module output
2. Update your domain registrar's DNS settings
3. Wait for DNS propagation (can take up to 48 hours)

## Subject Alternative Names

You can include multiple domain names in a single certificate using `subject_alternative_names`:

```hcl
subject_alternative_names = [
  "*.example.com",
  "www.example.com",
  "api.example.com"
]
```

## Using Existing Route53 Zone

If you already have a Route53 hosted zone for your domain:

1. Set `use_existing_route53_zone = true`
2. The module will look up the existing zone by domain name
3. The ACM certificate will use the existing zone for validation

## Dependencies

- AWS Route53 service
- AWS Certificate Manager (ACM)
- Terraform AWS provider
- `terraform-aws-modules/acm/aws` module (version 6.2.0)

## Notes

- The module automatically trims trailing dots from domain names
- Certificate validation uses DNS method (not email)
- The certificate is validated automatically via Route53
- Name servers are only available when creating a new zone
- For existing zones, name servers must be configured separately
