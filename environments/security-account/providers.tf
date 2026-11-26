terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.74.0, < 7.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.8.1, < 3.0.0"
    }
  }

  # Partial configuration: supply the rest with `-backend-config=<env>.backend.hcl`
  # (see backend.hcl.example). Locking uses S3 native lockfiles (Terraform >= 1.10).
  backend "s3" {}
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}
