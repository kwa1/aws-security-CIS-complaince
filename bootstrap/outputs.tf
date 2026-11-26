output "state_bucket" {
  description = "Terraform state bucket; use as 'bucket' in backend configuration."
  value       = module.state.bucket_id
}

output "state_kms_key_arn" {
  description = "KMS key for state encryption; use as 'kms_key_id' in backend configuration."
  value       = module.state_kms.key_arn
}

output "plan_role_arn" {
  description = "Role ARN for the read-only plan job (GitHub secret/variable AWS_PLAN_ROLE_ARN)."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Role ARN for the gated apply job (GitHub secret/variable AWS_APPLY_ROLE_ARN)."
  value       = aws_iam_role.apply.arn
}
