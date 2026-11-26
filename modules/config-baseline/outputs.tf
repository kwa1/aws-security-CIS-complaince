output "role_arn" {
  description = "ARN of the IAM role used by the AWS Config recorder."
  value       = aws_iam_role.config.arn
}

output "recorder_name" {
  description = "Name of the configuration recorder."
  value       = aws_config_configuration_recorder.this.name
}
