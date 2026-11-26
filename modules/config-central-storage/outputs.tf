output "bucket_name" {
  description = "Central AWS Config bucket name."
  value       = module.config_bucket.bucket_id
}

output "bucket_arn" {
  description = "Central AWS Config bucket ARN."
  value       = module.config_bucket.bucket_arn
}

output "kms_key_arn" {
  description = "KMS key ARN that members must reference in their delivery channel."
  value       = module.kms.key_arn
}
