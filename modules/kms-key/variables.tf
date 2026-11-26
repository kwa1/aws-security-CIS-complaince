variable "alias_name" {
  description = "Key alias without the 'alias/' prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]{1,250}$", var.alias_name)) && !startswith(var.alias_name, "aws/")
    error_message = "alias_name must be 1-250 characters of [a-zA-Z0-9/_-] and must not start with 'aws/'."
  }
}

variable "description" {
  description = "Human readable description of the key's purpose."
  type        = string
}

variable "additional_policy_documents" {
  description = "Extra key policy documents (JSON) merged into the key policy, e.g. service principal grants."
  type        = list(string)
  default     = []
}

variable "deletion_window_in_days" {
  description = "Waiting period before key deletion (7-30)."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Tags applied to the key."
  type        = map(string)
  default     = {}
}
