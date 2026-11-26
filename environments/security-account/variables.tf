variable "account_id" {
  description = "12-digit ID of the security (audit/log-archive) account. The provider refuses to run against any other account."
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
  description = "True for exactly one region per account. Enables global resources: IAM recording, IAM/CloudTrail rules, password policy, S3 account block, central storage, Config aggregator."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix for resource names."
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
  description = "Globally unique name of the central AWS Config bucket."
  type        = string
}

variable "governed_account_ids" {
  description = "All account IDs (this one plus every member account) allowed to deliver AWS Config data."
  type        = list(string)
}

variable "alert_emails" {
  description = "Emails subscribed to alerts (each must confirm)."
  type        = list(string)
  default     = []
}

variable "slack_webhook_secret_arn" {
  description = "ARN of a pre-created Secrets Manager secret holding the Slack webhook URL. Null disables Slack."
  type        = string
  default     = null
}

variable "slack_secret_kms_key_arn" {
  description = "Customer managed KMS key encrypting the Slack secret, if any."
  type        = string
  default     = null
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

variable "enable_organization_auto_enable" {
  description = "Set true only when this account is the Security Hub delegated administrator."
  type        = bool
  default     = false
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
