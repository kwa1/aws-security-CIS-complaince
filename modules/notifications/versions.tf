terraform {
  required_version = ">= 1.11.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.8.1, < 3.0.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.74.0, < 7.0.0"
    }
  }
}