data "aws_partition" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  bucket_arn = "arn:${local.partition}:s3:::${var.config_bucket_name}"
  key_prefix = var.config_prefix == null ? "" : "${var.config_prefix}/"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    # Confused-deputy protection.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name_prefix}-aws-config"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# AWS-managed policy that grants the read access Config needs to describe resources.
resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

data "aws_iam_policy_document" "delivery" {
  statement {
    sid       = "DeliverToCentralBucket"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectAcl"]
    resources = ["${local.bucket_arn}/${local.key_prefix}AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]

    condition {
      test     = "StringLike"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "CheckCentralBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [local.bucket_arn]
  }

  statement {
    sid       = "EncryptWithCentralKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.config_kms_key_arn]
  }
}

resource "aws_iam_policy" "delivery" {
  name   = "${var.name_prefix}-aws-config-delivery"
  policy = data.aws_iam_policy_document.delivery.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "delivery" {
  role       = aws_iam_role.config.name
  policy_arn = aws_iam_policy.delivery.arn
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.record_global_resources
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }

  depends_on = [
    aws_iam_role_policy_attachment.config_managed,
    aws_iam_role_policy_attachment.delivery,
  ]
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-delivery"
  s3_bucket_name = var.config_bucket_name
  s3_key_prefix  = var.config_prefix
  s3_kms_key_arn = var.config_kms_key_arn

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_delivery_frequency
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
