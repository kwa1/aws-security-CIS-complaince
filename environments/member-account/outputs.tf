output "config_recorder_name" {
  description = "Name of the AWS Config recorder in this account/region."
  value       = module.config.recorder_name
}

output "config_rule_names" {
  description = "Deployed Config rule names."
  value       = module.rules.rule_names
}
