variable "manage_password_policy" {
  description = "Manage the account IAM password policy (account-global; enable in the home region only)."
  type        = bool
  default     = false
}

variable "manage_s3_account_public_access_block" {
  description = "Manage the account-level S3 Block Public Access settings (account-global; enable in the home region only)."
  type        = bool
  default     = false
}

variable "minimum_password_length" {
  description = "Minimum IAM password length (CIS requires >= 14)."
  type        = number
  default     = 14

  validation {
    condition     = var.minimum_password_length >= 14
    error_message = "CIS AWS Foundations requires a minimum password length of 14."
  }
}
