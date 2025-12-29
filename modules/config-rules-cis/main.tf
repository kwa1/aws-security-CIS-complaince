locals {
  rules = {
    root_mfa         = "ROOT_ACCOUNT_MFA_ENABLED"
    no_inline_policy = "IAM_USER_NO_POLICIES_CHECK"
    cloudtrail       = "CLOUD_TRAIL_ENABLED"
    restricted_ssh   = "INCOMING_SSH_DISABLED"
    s3_public        = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    ebs_encrypted    = "ENCRYPTED_VOLUMES"
  }
}

resource "aws_config_config_rule" "cis" {
  for_each = local.rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value
  }
}
