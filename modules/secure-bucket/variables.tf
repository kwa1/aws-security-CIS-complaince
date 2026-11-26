variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters, lowercase letters, numbers, dots and hyphens."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS. Set to null to use SSE-S3 (required for S3 server access log targets)."
  type        = string
  default     = null
}

variable "access_log_bucket" {
  description = "Name of the bucket receiving S3 server access logs. Null disables access logging (use only for the log bucket itself)."
  type        = string
  default     = null
}

variable "access_log_prefix" {
  description = "Prefix for access log objects."
  type        = string
  default     = "s3-access/"
}

variable "additional_policy_documents" {
  description = "Extra bucket policy documents (JSON) merged with the baseline TLS-only policy."
  type        = list(string)
  default     = []
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions are permanently deleted."
  type        = number
  default     = 365

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "noncurrent_version_expiration_days must be at least 30 to retain recovery capability."
  }
}

variable "expiration_days" {
  description = "Days before current objects expire. Null keeps objects indefinitely."
  type        = number
  default     = null
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket. Keep false for audit data."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
