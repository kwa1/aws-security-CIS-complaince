variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "bucket_name" {
  description = "Name of the central AWS Config delivery bucket."
  type        = string
}

variable "governed_account_ids" {
  description = "All AWS account IDs (including this one) allowed to deliver AWS Config data to the bucket."
  type        = list(string)

  validation {
    condition     = length(var.governed_account_ids) > 0 && alltrue([for id in var.governed_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "governed_account_ids must be a non-empty list of 12-digit AWS account IDs."
  }
}

variable "config_prefix" {
  description = "Optional key prefix under which AWS Config writes. Null writes to the bucket root."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
