variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "aggregator_name" {
  description = "Name of the AWS Config aggregator."
  type        = string
  default     = "org-config-aggregator"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
