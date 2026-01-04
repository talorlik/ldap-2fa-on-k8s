terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.21.0"
      configuration_aliases = [aws.state_account]
    }
  }
}

# Provider alias for state account (inherited from parent module)
# This allows Route53 resources to be created in the state account
# when Route53 hosted zone is in a different account than deployment account
