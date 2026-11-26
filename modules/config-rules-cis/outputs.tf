output "rule_names" {
  description = "Map of catalog key to deployed Config rule name."
  value       = { for key, rule in aws_config_config_rule.cis : key => rule.name }
}

output "rule_arns" {
  description = "Map of catalog key to deployed Config rule ARN."
  value       = { for key, rule in aws_config_config_rule.cis : key => rule.arn }
}
