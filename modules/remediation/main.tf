data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "automation" {
  name               = "${var.name_prefix}-remediation-s3-block-public"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "automation" {
  # Bucket names are not known at plan time, so the resource must be a wildcard. Blast radius is
  # limited to a single, non-destructive action that can only make buckets more private.
  statement {
    sid       = "BlockPublicAccessOnBuckets"
    effect    = "Allow"
    actions   = ["s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock"]
    resources = ["arn:${local.partition}:s3:::*"]
  }
}

resource "aws_iam_policy" "automation" {
  name   = "${var.name_prefix}-remediation-s3-block-public"
  policy = data.aws_iam_policy_document.automation.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "automation" {
  role       = aws_iam_role.automation.name
  policy_arn = aws_iam_policy.automation.arn
}

resource "aws_ssm_document" "block_s3_public" {
  name            = "${var.name_prefix}-BlockS3PublicAccess"
  document_type   = "Automation"
  document_format = "JSON"
  tags            = var.tags

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Enable all S3 Block Public Access settings on a bucket."
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      BucketName = {
        type        = "String"
        description = "Name of the bucket to remediate."
        allowedPattern = "^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"
      }
      AutomationAssumeRole = {
        type        = "String"
        description = "IAM role ARN assumed by Automation."
      }
    }
    mainSteps = [{
      name   = "BlockPublicAccess"
      action = "aws:executeAwsApi"
      inputs = {
        Service = "s3"
        Api     = "PutPublicAccessBlock"
        Bucket  = "{{ BucketName }}"
        PublicAccessBlockConfiguration = {
          BlockPublicAcls       = true
          IgnorePublicAcls      = true
          BlockPublicPolicy     = true
          RestrictPublicBuckets = true
        }
      }
    }]
  })
}

resource "aws_config_remediation_configuration" "s3_public" {
  config_rule_name = var.rule_name
  target_type      = "SSM_DOCUMENT"
  target_id        = aws_ssm_document.block_s3_public.name
  target_version   = "$DEFAULT"

  automatic                  = var.automatic
  maximum_automatic_attempts = var.automatic ? var.maximum_automatic_attempts : null
  retry_attempt_seconds      = var.automatic ? var.retry_attempt_seconds : null

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.automation.arn
  }

  execution_controls {
    ssm_controls {
      concurrent_execution_rate_percentage = 10
      error_percentage                     = 20
    }
  }
}
