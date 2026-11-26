variable "account_id" {
  description = "12-digit ID of this member account. The provider refuses to run against any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Region this stack instance governs. Deploy once per governed region, each with its own state key."
  type        = string
}

variable "is_home_region" {
  description = "True for exactly one region per account. Enables global resources: IAM recording, IAM/CloudTrail rules, password policy, S3 account block."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix for resource names. Must match the security account's prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 characters: lowercase letters, numbers, hyphens; starting with a letter."
  }
}

variable "environment" {
  description = "Environment label used for tagging."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "config_bucket_name" {
  description = "Central AWS Config bucket (output of the security-account stack)."
  type        = string
}

variable "config_kms_key_arn" {
  description = "KMS key ARN for AWS Config delivery (output of the security-account stack)."
  type        = string
}

variable "disabled_rules" {
  description = "Catalog keys of Config rules to skip (documented exceptions)."
  type        = set(string)
  default     = []
}

variable "cis_version" {
  description = "CIS AWS Foundations Benchmark version for Security Hub."
  type        = string
  default     = "3.0.0"
}

variable "enable_remediation" {
  description = "Deploy the S3 public-access remediation (manual by default)."
  type        = bool
  default     = false
}

variable "remediation_automatic" {
  description = "Run the remediation automatically on NON_COMPLIANT. Validate in non-production first."
  type        = bool
  default     = false
}
