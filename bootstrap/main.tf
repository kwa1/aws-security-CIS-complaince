data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  partition   = data.aws_partition.current.partition
  account_id  = data.aws_caller_identity.current.account_id
  state_name  = "${var.name_prefix}-tfstate-${local.account_id}"
  oidc_url    = "token.actions.githubusercontent.com"
  oidc_arn    = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_url}"
  role_prefix = "arn:${local.partition}:iam::${local.account_id}:role/${var.name_prefix}-*"

  tags = {
    Project     = "aws-cis-governance"
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "bootstrap"
  }
}

# --- Terraform state backend -----------------------------------------------------------------

module "state_kms" {
  source = "./../modules/kms-key"

  alias_name  = "${var.name_prefix}-tfstate"
  description = "Encrypts Terraform state for ${var.name_prefix}"
  tags        = local.tags
}

data "aws_iam_policy_document" "state_logs" {
  statement {
    sid       = "AllowS3LogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:${local.partition}:s3:::${local.state_name}-logs/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:s3:::${local.state_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

module "state_logs" {
  source = "./../modules/secure-bucket"

  bucket_name                        = "${local.state_name}-logs"
  additional_policy_documents        = [data.aws_iam_policy_document.state_logs.json]
  noncurrent_version_expiration_days = 90
  expiration_days                    = 400
  tags                               = local.tags
}

module "state" {
  source = "./../modules/secure-bucket"

  bucket_name                        = local.state_name
  kms_key_arn                        = module.state_kms.key_arn
  access_log_bucket                  = module.state_logs.bucket_id
  access_log_prefix                  = "tfstate/"
  noncurrent_version_expiration_days = var.state_noncurrent_retention_days
  tags                               = local.tags
}

# --- GitHub OIDC federation (no long-lived AWS keys in CI) -----------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pull requests and the default branch (scheduled drift detection) only.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values = [
        "repo:${var.github_repository}:pull_request",
        "repo:${var.github_repository}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs bound to the protected GitHub Environment (manual approval gate).
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_apply_environment}"]
    }
  }
}

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [module.state.bucket_arn]
  }

  statement {
    sid       = "ReadWriteStateAndLock"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.state.bucket_arn}/*"]
  }

  statement {
    sid       = "UseStateKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.state_kms.key_arn]
  }
}

resource "aws_iam_role" "plan" {
  name                 = "${var.name_prefix}-ci-plan"
  description          = "Read-only role for terraform plan in pull requests and drift detection"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_access.json
}

# Scoped apply permissions: only the services this repository manages, and IAM limited to
# resources named with the project prefix.
data "aws_iam_policy_document" "apply" {
  statement {
    sid    = "ManagedServices"
    effect = "Allow"
    actions = [
      "config:*",
      "securityhub:*",
      "sns:*",
      "sqs:*",
      "events:*",
      "lambda:*",
      "logs:*",
      "ssm:*",
      "kms:*",
      "s3:*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "xray:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AccountLevelSettings"
    effect = "Allow"
    actions = [
      "ec2:EnableEbsEncryptionByDefault",
      "ec2:DisableEbsEncryptionByDefault",
      "ec2:GetEbsEncryptionByDefault",
      "ec2:GetEbsDefaultKmsKeyId",
      "iam:GetAccountPasswordPolicy",
      "iam:UpdateAccountPasswordPolicy",
      "iam:DeleteAccountPasswordPolicy",
      "s3:PutAccountPublicAccessBlock",
      "s3:GetAccountPublicAccessBlock",
      "organizations:DescribeOrganization",
      "organizations:ListAWSServiceAccessForOrganization",
      "organizations:ListDelegatedAdministrators",
      "organizations:EnableAWSServiceAccess",
      "organizations:RegisterDelegatedAdministrator",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProjectIamOnly"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:PassRole",
    ]
    resources = [local.role_prefix]
  }

  statement {
    sid    = "ProjectManagedPolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion",
      "iam:ListPolicyVersions", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = ["arn:${local.partition}:iam::${local.account_id}:policy/${var.name_prefix}-*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "config.amazonaws.com",
        "securityhub.amazonaws.com",
        "ssm.amazonaws.com",
        "organizations.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "ReadIdentityInfo"
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListRoles", "sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # Guardrail: this role must never be able to change its own trust, or CI access.
  statement {
    sid    = "DenyCiRoleTampering"
    effect = "Deny"
    actions = [
      "iam:*",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:role/${var.name_prefix}-ci-*",
      "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_url}",
    ]
  }
}

resource "aws_iam_policy" "apply" {
  name        = "${var.name_prefix}-ci-apply"
  description = "Scoped permissions for terraform apply of the CIS governance stacks"
  policy      = data.aws_iam_policy_document.apply.json
  tags        = local.tags
}

resource "aws_iam_role" "apply" {
  name                 = "${var.name_prefix}-ci-apply"
  description          = "Applies Terraform after manual approval via the protected GitHub Environment"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "apply" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.apply.arn
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.state_access.json
}
