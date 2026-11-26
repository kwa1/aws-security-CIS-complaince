variable "enable_cis" {
  description = "Subscribe to the CIS AWS Foundations Benchmark."
  type        = bool
  default     = true
}

variable "cis_version" {
  description = "CIS AWS Foundations Benchmark version."
  type        = string
  default     = "3.0.0"

  validation {
    condition     = contains(["1.4.0", "3.0.0"], var.cis_version)
    error_message = "cis_version must be 1.4.0 or 3.0.0."
  }
}

variable "enable_fsbp" {
  description = "Subscribe to AWS Foundational Security Best Practices."
  type        = bool
  default     = true
}

variable "enable_organization_auto_enable" {
  description = "Delegated-admin account only: auto-enable Security Hub for new organization accounts."
  type        = bool
  default     = false
}

variable "enable_cross_region_aggregation" {
  description = "Create a finding aggregator in this (home) region that pulls findings from all regions."
  type        = bool
  default     = true
}
