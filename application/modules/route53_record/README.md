# Route53 Record Module

This module creates a Route53 A (alias) record pointing to an Application Load
Balancer (ALB). It is designed to support cross-account deployments where the
Route53 hosted zone is in a different AWS account (State Account) than the ALB
(Deployment Account).

## Overview

The Route53 record module creates a single A (alias) record that points a
subdomain to an ALB DNS name. This module is called multiple times in
`application/main.tf` to create separate records for each service:

- `phpldapadmin.<domain>` → ALB
- `passwd.<domain>` → ALB
- `app.<domain>` → ALB

## Features

- **Cross-Account Support**: Uses state account provider to create records in
  State Account while ALB is in Deployment Account
- **ALB Alias Records**: Creates A (alias) records for optimal performance and
  cost efficiency
- **Health Check Integration**: Supports target health evaluation for alias
  records
- **Precondition Validation**: Ensures ALB DNS name is available before record
  creation
- **Safe Updates**: Uses `create_before_destroy` lifecycle to prevent DNS
  downtime

## Architecture

```ascii
┌───────────────────────────────────────────────────────────┐
│                    State Account                          │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │         Route53 Hosted Zone                         │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  A Record: phpldapadmin.<domain>             │   │  │
│  │  │  → ALB DNS (Deployment Account)              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  A Record: passwd.<domain>                   │   │  │
│  │  │  → ALB DNS (Deployment Account)              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  A Record: app.<domain>                      │   │  │
│  │  │  → ALB DNS (Deployment Account)              │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
                          │
                          │ DNS Resolution
                          ▼
┌────────────────────────────────────────────────────────────┐
│                 Deployment Account                         │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Application Load Balancer               │  │
│  │              (Internet-Facing ALB)                   │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## Cross-Account Access

This module uses the `aws.state_account` provider alias to create Route53
records in the State Account, even when the ALB is deployed in a different
account (Deployment Account). This enables:

- Route53 hosted zones managed in a centralized State Account
- ALB resources deployed in separate Deployment Accounts
- Proper separation of concerns and account isolation

The provider configuration is inherited from the parent module
(`application/providers.tf`), which configures the state account provider when
`state_account_role_arn` is provided.

## Usage

### Basic Example

```hcl
module "route53_record_example" {
  source = "./modules/route53_record"

  zone_id       = "Z1234567890ABC"
  name          = "app.example.com"
  alb_dns_name  = "my-alb-123456789.us-east-1.elb.amazonaws.com"
  alb_zone_id   = "Z35SXDOTRQ7X7K"  # us-east-1 ALB zone ID

  providers = {
    aws.state_account = aws.state_account
  }
}
```

### Integration in main.tf

The module is called three times in `application/main.tf`:

```hcl
# Route53 record for phpLDAPadmin
module "route53_record_phpldapadmin" {
  source = "./modules/route53_record"

  count = var.use_alb && local.phpldapadmin_host != "" ? 1 : 0

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = local.phpldapadmin_host
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  depends_on = [
    module.openldap,  # Ensures Ingress is created (which triggers ALB creation)
    data.aws_lb.alb,  # Ensures ALB exists before creating record
  ]

  providers = {
    aws.state_account = aws.state_account
  }
}
```

## Input Variables

| Variable | Description | Type | Required | Default |
| ---------- | ------------- | ------ | ---------- | --------- |
| `zone_id` | Route53 hosted zone ID for creating DNS records | `string` | Yes | - |
| `name` | DNS record name (e.g., `phpldapadmin.talorlik.com`) | `string` | Yes | - |
| `alb_dns_name` | DNS name of the ALB to point the record to | `string` | Yes | - |
| `alb_zone_id` | ALB canonical hosted zone ID for Route53 alias records. This should be computed from the region mapping (see ALB Zone ID Mapping section) | `string` | Yes | - |
| `evaluate_target_health` | Whether to evaluate target health for the alias record | `bool` | No | `true` |

## Outputs

| Output | Description |
| -------- | ------------- |
| `record_name` | Route53 record name |
| `record_fqdn` | Fully qualified domain name (FQDN) of the Route53 record |
| `record_id` | Route53 record ID |

## Dependencies

### Prerequisites

1. **Route53 Hosted Zone**: Must exist in the State Account (or same account)
2. **ALB**: Must be provisioned and have a DNS name available
3. **State Account Provider**: Must be configured in parent module when using
   cross-account access

### Dependency Chain

The module has explicit dependencies to ensure proper ordering:

```hcl
depends_on = [
  module.openldap,  # Ensures Ingress is created (which triggers ALB creation)
  data.aws_lb.alb,  # Ensures ALB exists before creating record
]
```

This ensures:

1. OpenLDAP module creates Ingress resources
2. Ingress resources trigger ALB creation (via EKS Auto Mode)
3. ALB data source can query the ALB DNS name
4. Route53 record can be created with valid ALB DNS name

### Preconditions

The module includes a precondition that validates the ALB DNS name is available:

```hcl
precondition {
  condition     = var.alb_dns_name != null && var.alb_dns_name != ""
  error_message = "ALB DNS name must be available before creating Route53 record. Ensure the ALB has been provisioned."
}
```

This prevents creating Route53 records with invalid ALB DNS names.

## ALB Zone ID Mapping

Application Load Balancers have region-specific canonical hosted zone IDs that
must be used when creating Route53 alias records. The parent module
(`application/main.tf`) includes a comprehensive mapping:

| Region | ALB Zone ID |
| -------- | ------------- |
| us-east-1 (N. Virginia) | `Z35SXDOTRQ7X7K` |
| us-east-2 (Ohio) | `Z3AADJGX6KTTL2` |
| us-west-1 (N. California) | `Z1M58G0W56PQJA` |
| us-west-2 (Oregon) | `Z33MTJ483K6KNU` |
| eu-west-1 (Ireland) | `Z3DZXE0Q2N3XK0` |
| eu-west-2 (London) | `Z3GKZC51ZF0DB4` |
| eu-west-3 (Paris) | `Z3Q77PNBUNY4FR` |
| eu-central-1 (Frankfurt) | `Z215JYRZR1TBD5` |
| ap-southeast-1 (Singapore) | `Z1LMS91P8CMLE5` |
| ap-southeast-2 (Sydney) | `Z1GM3OXH4ZPM65` |
| ap-northeast-1 (Tokyo) | `Z14GRHDCWA56QT` |
| ap-northeast-2 (Seoul) | `Z1W9GUF3Q8Z8BZ` |
| sa-east-1 (São Paulo) | `Z2P70J7HTTTPLU` |

The parent module automatically selects the correct zone ID based on the region
variable using a lookup function.

## Provider Configuration

### State Account Provider

The module requires the `aws.state_account` provider alias to be configured in
the parent module. This is done in `application/providers.tf`:

```hcl
provider "aws" {
  alias = "state_account"

  # Configuration when state_account_role_arn is provided
  # ...
}
```

When `state_account_role_arn` is provided, the provider assumes the State
Account role for Route53 operations. When not provided, it uses default
credentials.

### Provider Passing

The parent module must pass the state account provider to this module:

```hcl
module "route53_record_example" {
  # ...

  providers = {
    aws.state_account = aws.state_account
  }
}
```

## Lifecycle Management

The module uses `create_before_destroy` lifecycle to ensure DNS records are
updated without downtime:

```hcl
lifecycle {
  create_before_destroy = true
}
```

This ensures that when updating a record, Terraform creates the new record
before destroying the old one, preventing DNS resolution gaps.

## Target Health Evaluation

By default, the module enables target health evaluation for alias records
(`evaluate_target_health = true`). This allows Route53 to:

- Route traffic only to healthy ALB targets
- Automatically fail over to healthy targets if some become unhealthy
- Improve overall service availability

You can disable this by setting `evaluate_target_health = false`, but it's
recommended to keep it enabled for production deployments.

## Troubleshooting

### Record Creation Fails with "ALB DNS name must be available"

**Cause**: The ALB has not been provisioned yet, or the ALB data source cannot
find the ALB.

**Solution**:

1. Ensure the OpenLDAP module has been deployed (creates Ingress resources)
2. Verify the ALB exists: `aws elbv2 describe-load-balancers --region <region>`
3. Check the ALB data source in `main.tf` is correctly configured
4. Verify the ALB name matches `local.alb_load_balancer_name`

### Record Points to Wrong ALB

**Cause**: The `alb_dns_name` variable is incorrect or points to a different ALB.

**Solution**:

1. Verify the ALB data source is querying the correct ALB
2. Check the ALB name in `main.tf` matches the actual ALB name
3. Ensure the ALB zone_id matches the region where the ALB is deployed

### Cross-Account Access Issues

**Cause**: The state account provider is not configured correctly, or the role
cannot be assumed.

**Solution**:

1. Verify `state_account_role_arn` is set in `variables.tfvars`
2. Check the state account role trust relationship allows the current identity
3. Ensure the state account provider is correctly configured in `providers.tf`
4. Verify the provider is passed to the module in `main.tf`

## Related Documentation

- [AWS Route53 Alias Records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)
- [Application Load Balancer Zone IDs](https://docs.aws.amazon.com/general/latest/gr/elb.html)
- [Cross-Account Access Documentation](../CROSS-ACCOUNT-ACCESS.md)
- [Application Infrastructure README](../README.md)

## Examples

### Single Record Creation

```hcl
module "route53_record_app" {
  source = "./modules/route53_record"

  zone_id       = "Z1234567890ABC"
  name          = "app.example.com"
  alb_dns_name  = "my-alb-123456789.us-east-1.elb.amazonaws.com"
  alb_zone_id   = "Z35SXDOTRQ7X7K"

  providers = {
    aws.state_account = aws.state_account
  }
}
```

### Multiple Records (as in main.tf)

```hcl
# phpLDAPadmin record
module "route53_record_phpldapadmin" {
  source = "./modules/route53_record"

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = "phpldapadmin.example.com"
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  providers = {
    aws.state_account = aws.state_account
  }
}

# ltb-passwd record
module "route53_record_ltb_passwd" {
  source = "./modules/route53_record"

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = "passwd.example.com"
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  providers = {
    aws.state_account = aws.state_account
  }
}

# 2FA application record
module "route53_record_twofa_app" {
  source = "./modules/route53_record"

  zone_id      = data.aws_route53_zone.this.zone_id
  name         = "app.example.com"
  alb_dns_name = data.aws_lb.alb[0].dns_name
  alb_zone_id  = local.alb_zone_id

  providers = {
    aws.state_account = aws.state_account
  }
}
```

## Notes

- **ALB Zone ID**: The ALB zone ID is region-specific and must match the region
  where the ALB is deployed. The parent module automatically selects the correct
  zone ID based on the region variable.

- **DNS Propagation**: After creating Route53 records, DNS changes typically
  propagate within a few minutes, but can take up to 48 hours in rare cases.

- **Cost**: Route53 alias records pointing to ALBs are free (no charges for
  queries or records).

- **Health Checks**: When `evaluate_target_health = true`, Route53 uses the
  ALB's target health status to determine routing. This requires the ALB to
  have healthy targets.

- **Cross-Account**: This module supports cross-account deployments where
  Route53 is in a different account than the ALB. Ensure proper IAM roles and
  trust relationships are configured.
