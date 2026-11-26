variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "alert_emails" {
  description = "Email addresses subscribed to alert topics (each must confirm the subscription)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "alert_emails must contain valid email addresses."
  }
}

variable "slack_webhook_secret_arn" {
  description = "ARN of an existing Secrets Manager secret whose SecretString is the Slack webhook URL. Null disables Slack. The secret is created out-of-band so the URL never enters Terraform state."
  type        = string
  default     = null
}

variable "slack_secret_kms_key_arn" {
  description = "Customer managed KMS key ARN encrypting the Slack secret (omit if the AWS-managed key is used)."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the notifier Lambda."
  type        = number
  default     = 365

  validation {
    condition     = contains([90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs retention value of at least 90 days."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for the notifier (caps cost and blast radius). Use -1 for no reservation; new accounts with a concurrency limit of 10 cannot reserve any."
  type        = number
  default     = 5

  validation {
    condition     = var.lambda_reserved_concurrency >= -1
    error_message = "lambda_reserved_concurrency must be -1 (unreserved) or a non-negative number."
  }
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
