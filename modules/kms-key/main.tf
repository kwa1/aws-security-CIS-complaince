data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "this" {
  source_policy_documents = var.additional_policy_documents

  # Standard "enable IAM policies" statement. Access is then governed by IAM
  # policies in this account; it is not a grant to any single principal.
  statement {
    sid       = "EnableAccountIamPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "this" {
  #checkov:skip=CKV_AWS_109:Root-account statement is the AWS-documented pattern that delegates control to IAM.
  #checkov:skip=CKV_AWS_111:Same as above; key policy resource "*" refers to this key only.
  #checkov:skip=CKV_AWS_356:Key policy resource "*" refers to this key only.
  description              = var.description
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = var.deletion_window_in_days
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  policy                   = data.aws_iam_policy_document.this.json
  tags                     = var.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}
