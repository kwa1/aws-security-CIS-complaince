output "aggregator_arn" {
  description = "ARN of the Config aggregator."
  value       = aws_config_configuration_aggregator.org.arn
}

output "role_arn" {
  description = "ARN of the aggregator's Organizations role."
  value       = aws_iam_role.aggregator.arn
}
