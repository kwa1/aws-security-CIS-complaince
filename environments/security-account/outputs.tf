output "config_bucket_name" {
  description = "Central AWS Config bucket (give to member-account stacks)."
  value       = var.config_bucket_name
}

output "config_kms_key_arn" {
  description = "KMS key ARN for AWS Config delivery (give to member-account stacks)."
  value       = local.config_kms_key_arn
}

output "alert_topic_arns" {
  description = "SNS alert topic ARNs."
  value       = module.notifications.topic_arns
}
