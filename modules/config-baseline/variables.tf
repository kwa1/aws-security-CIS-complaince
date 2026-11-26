variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "config_bucket_name" {
  description = "Central S3 bucket that receives AWS Config data (created by the config-central-storage module)."
  type        = string
}

variable "config_kms_key_arn" {
  description = "KMS key ARN used to encrypt AWS Config data in the central bucket."
  type        = string
}

variable "config_prefix" {
  description = "Optional key prefix inside the central bucket. Must match the config-central-storage module."
  type        = string
  default     = null
}

variable "record_global_resources" {
  description = "Record global resource types (IAM). Enable in exactly ONE region per account (the home region) to avoid duplicates."
  type        = bool
  default     = false
}

variable "snapshot_delivery_frequency" {
  description = "How often AWS Config delivers configuration snapshots."
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.snapshot_delivery_frequency)
    error_message = "snapshot_delivery_frequency must be a valid AWS Config delivery frequency."
  }
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
