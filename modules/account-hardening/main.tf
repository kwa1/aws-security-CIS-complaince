# Regional: default EBS encryption (must be applied in every governed region).
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# Global: apply once per account.
resource "aws_s3_account_public_access_block" "this" {
  count = var.manage_s3_account_public_access_block ? 1 : 0

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "this" {
  count = var.manage_password_policy ? 1 : 0

  minimum_password_length        = var.minimum_password_length
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
  hard_expiry                    = false
}
