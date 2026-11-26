variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "rule_name" {
  description = "Full name of the Config rule (S3 public read/write prohibited) to attach remediation to."
  type        = string
}

variable "automatic" {
  description = "false = remediation is available for manual/approved execution only. true = Config runs it automatically on NON_COMPLIANT. Enable only after validation in non-production."
  type        = bool
  default     = false
}

variable "maximum_automatic_attempts" {
  description = "Maximum automatic remediation attempts."
  type        = number
  default     = 3

  validation {
    condition     = var.maximum_automatic_attempts >= 1 && var.maximum_automatic_attempts <= 25
    error_message = "maximum_automatic_attempts must be between 1 and 25."
  }
}

variable "retry_attempt_seconds" {
  description = "Seconds between automatic attempts."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
