variable "account_id" {
  description = "12-digit ID of the AWS account being bootstrapped. The provider refuses to run against any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Home region for the state bucket and IAM resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names (e.g. org-sec)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 characters: lowercase letters, numbers, hyphens; starting with a letter."
  }
}

variable "environment" {
  description = "Environment label used for tagging and GitHub Environment names."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, in 'owner/repo' form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like 'owner/repo'."
  }
}

variable "github_apply_environment" {
  description = "GitHub Environment (with required reviewers) whose jobs may assume the apply role."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "state_noncurrent_retention_days" {
  description = "Days to retain previous versions of state files."
  type        = number
  default     = 365
}
