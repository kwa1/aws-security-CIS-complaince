variable "name_prefix" {
  description = "Prefix for Config rule names."
  type        = string
}

variable "deploy_global_rules" {
  description = "Deploy rules that evaluate account-global resources (IAM, root account, CloudTrail). Enable in the home region only."
  type        = bool
  default     = false
}

variable "disabled_rules" {
  description = "Catalog keys of rules to skip (documented exceptions). See local.catalog in main.tf for keys."
  type        = set(string)
  default     = []
}

variable "periodic_frequency" {
  description = "Evaluation frequency for periodic rules."
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.periodic_frequency)
    error_message = "periodic_frequency must be a valid AWS Config frequency."
  }
}

variable "tags" {
  description = "Tags applied to rules."
  type        = map(string)
  default     = {}
}
