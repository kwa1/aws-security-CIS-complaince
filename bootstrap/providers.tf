terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.74.0, < 7.0.0"
    }
  }

  # First run uses local state (the bucket does not exist yet). After apply, migrate:
  #   see docs/DEPLOYMENT.md "Bootstrap" - add the s3 backend block and run `terraform init -migrate-state`.
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}
