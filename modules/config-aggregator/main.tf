data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# The aggregator uses this role to enumerate accounts in AWS Organizations.
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "aggregator" {
  name               = "${var.name_prefix}-config-aggregator"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "aggregator" {
  role       = aws_iam_role.aggregator.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_configuration_aggregator" "org" {
  name = var.aggregator_name
  tags = var.tags

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.aggregator.arn
  }

  depends_on = [aws_iam_role_policy_attachment.aggregator]
}
