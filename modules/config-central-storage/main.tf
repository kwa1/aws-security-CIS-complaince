data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  partition   = data.aws_partition.current.partition
  bucket_arn  = "arn:${local.partition}:s3:::${var.bucket_name}"
  log_bucket  = "${var.bucket_name}-access-logs"
  key_prefix  = var.config_prefix == null ? "" : "${var.config_prefix}/"
  delivery_rn = [for id in var.governed_account_ids : "${local.bucket_arn}/${local.key_prefix}AWSLogs/${id}/Config/*"]
}

# --- KMS key used to encrypt AWS Config data at rest -----------------------------------------

data "aws_iam_policy_document" "key" {
  # AWS Config delivers as the service principal (documented behaviour for cross-account delivery).
  # Access is limited to the governed accounts via aws:SourceAccount (confused-deputy protection).
  statement {
    sid       = "AllowConfigServiceToEncrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.governed_account_ids
    }
  }
}

module "kms" {
  source = "../kms-key"

  alias_name                  = "${var.name_prefix}-config-delivery"
  description                 = "Encrypts AWS Config configuration history and snapshots"
  additional_policy_documents = [data.aws_iam_policy_document.key.json]
  tags                        = var.tags
}

# --- Access log bucket (SSE-S3 is mandatory for S3 server access log targets) ----------------

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "AllowS3LogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:${local.partition}:s3:::${local.log_bucket}/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.bucket_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "access_logs" {
  source = "../secure-bucket"

  bucket_name                        = local.log_bucket
  kms_key_arn                        = null
  access_log_bucket                  = null
  additional_policy_documents        = [data.aws_iam_policy_document.access_logs.json]
  noncurrent_version_expiration_days = 90
  expiration_days                    = 400
  tags                               = var.tags
}

# --- Central AWS Config bucket ---------------------------------------------------------------

data "aws_iam_policy_document" "config_delivery" {
  statement {
    sid       = "AWSConfigBucketPermissionsCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [local.bucket_arn]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.governed_account_ids
    }
  }

  statement {
    sid       = "AWSConfigBucketExistenceCheck"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.governed_account_ids
    }
  }

  statement {
    sid       = "AWSConfigBucketDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = local.delivery_rn

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.governed_account_ids
    }
  }
}

module "config_bucket" {
  source = "../secure-bucket"

  bucket_name                        = var.bucket_name
  kms_key_arn                        = module.kms.key_arn
  access_log_bucket                  = module.access_logs.bucket_id
  access_log_prefix                  = "config-bucket/"
  additional_policy_documents        = [data.aws_iam_policy_document.config_delivery.json]
  noncurrent_version_expiration_days = 365
  tags                               = var.tags
}
