data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  state_name = "${var.name_prefix}-tfstate-${local.account_id}"
  oidc_url   = "token.actions.githubusercontent.com"
  oidc_arn   = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.oidc_url}"
  iam_arn    = "arn:${local.partition}:iam::${local.account_id}"
  s3_arn     = "arn:${local.partition}:s3:::"

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
    resources = ["${local.s3_arn}${local.state_name}-logs/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["${local.s3_arn}${local.state_name}"]
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

# --- Read access shared by plan and apply (metadata only; no object or secret data) ----------

data "aws_iam_policy_document" "read_extras" {
  #checkov:skip=CKV_AWS_356:Read-only Describe/Get/List actions; most do not support resource-level permissions.
  statement {
    sid    = "ReadResourceConfiguration"
    effect = "Allow"
    actions = [
      "config:Describe*", "config:ListTagsForResource", "config:GetComplianceDetailsByConfigRule",
      "securityhub:Describe*", "securityhub:GetEnabledStandards", "securityhub:GetFindingAggregator",
      "securityhub:ListTagsForResource", "securityhub:ListStandardsControlAssociations",
      "sns:GetTopicAttributes", "sns:GetSubscriptionAttributes", "sns:ListTagsForResource",
      "sns:ListSubscriptionsByTopic", "sns:ListTopics",
      "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ListQueueTags", "sqs:ListQueues",
      "events:Describe*", "events:ListTagsForResource", "events:ListTargetsByRule", "events:ListRules",
      "lambda:GetFunction", "lambda:GetFunctionConfiguration", "lambda:GetPolicy",
      "lambda:GetFunctionCodeSigningConfig", "lambda:GetRuntimeManagementConfig",
      "lambda:GetFunctionEventInvokeConfig", "lambda:ListVersionsByFunction", "lambda:ListTags",
      "logs:DescribeLogGroups", "logs:ListTagsForResource", "logs:ListTagsLogGroup",
      "ssm:DescribeDocument", "ssm:DescribeDocumentPermission", "ssm:GetDocument",
      "ssm:ListDocuments", "ssm:ListTagsForResource",
      "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListAliases",
      "kms:ListResourceTags", "kms:ListKeys",
      "s3:GetBucketAcl", "s3:GetBucketLocation", "s3:GetBucketLogging", "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy", "s3:GetBucketPublicAccessBlock", "s3:GetBucketTagging", "s3:GetBucketVersioning",
      "s3:GetBucketCORS", "s3:GetBucketWebsite", "s3:GetBucketRequestPayment", "s3:GetBucketObjectLockConfiguration",
      "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:GetAccelerateConfiguration",
      "s3:GetReplicationConfiguration", "s3:GetAccountPublicAccessBlock",
      "s3:ListAllMyBuckets", "s3:ListBucket",
      "ec2:GetEbsEncryptionByDefault", "ec2:GetEbsDefaultKmsKeyId",
      "iam:GetAccountPasswordPolicy", "iam:ListOpenIDConnectProviders", "iam:GetOpenIDConnectProvider",
      "organizations:Describe*", "organizations:List*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "read_extras" {
  name        = "${var.name_prefix}-ci-read"
  description = "Additional read permissions Terraform needs to refresh the governance stacks"
  policy      = data.aws_iam_policy_document.read_extras.json
  tags        = local.tags
}

# --- State access ----------------------------------------------------------------------------

data "aws_iam_policy_document" "state_read" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [module.state.bucket_arn]
  }

  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.state.bucket_arn}/*"]
  }

  # S3 native locking writes and removes a ".tflock" object next to the state file.
  statement {
    sid       = "WriteLockFilesOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.state.bucket_arn}/*.tflock"]
  }

  statement {
    sid       = "UseStateKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.state_kms.key_arn]
  }
}

data "aws_iam_policy_document" "state_write" {
  source_policy_documents = [data.aws_iam_policy_document.state_read.json]

  statement {
    sid       = "WriteState"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.state.bucket_arn}/*"]
  }
}

# --- Plan role: read-only, usable from pull requests -----------------------------------------

resource "aws_iam_role" "plan" {
  name                 = "${var.name_prefix}-ci-plan"
  description          = "Read-only role for terraform plan in pull requests and drift detection"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
  tags                 = local.tags
}

# SecurityAudit grants metadata-only reads (no S3 object or secret values).
resource "aws_iam_role_policy_attachment" "plan_security_audit" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "plan_read_extras" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.read_extras.arn
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_read.json
}

# --- Apply role: scoped to this project's resources, gated by a protected GitHub Environment -

data "aws_iam_policy_document" "apply" {
  #checkov:skip=CKV_AWS_108:Data-read actions are not granted; managed services are scoped to project-prefixed resources.
  #checkov:skip=CKV_AWS_109:IAM permission-management is limited to project-prefixed roles/policies with a PolicyARN condition on attachment.
  #checkov:skip=CKV_AWS_110:Privilege escalation is blocked by the iam:PolicyARN allow-list and the CI-role tamper deny below.
  #checkov:skip=CKV_AWS_111:Write access is scoped by resource prefix, KMS tag conditions, or is required account-level setting.
  #checkov:skip=CKV_AWS_356:AWS Config and Security Hub have no name-scopable ARNs; kms:CreateKey and account settings cannot be resource-scoped.

  # AWS Config and Security Hub resources (recorder, delivery channel, hub) cannot be scoped by name.
  statement {
    sid       = "ConfigAndSecurityHub"
    effect    = "Allow"
    actions   = ["config:*", "securityhub:*"]
    resources = ["*"]
  }

  statement {
    sid     = "ProjectPrefixedResources"
    effect  = "Allow"
    actions = ["sns:*", "sqs:*"]
    resources = [
      "arn:${local.partition}:sns:*:${local.account_id}:${var.name_prefix}-*",
      "arn:${local.partition}:sqs:*:${local.account_id}:${var.name_prefix}-*",
    ]
  }

  statement {
    sid     = "ProjectEventsLambdaSsm"
    effect  = "Allow"
    actions = ["events:*", "lambda:*", "ssm:*"]
    resources = [
      "arn:${local.partition}:events:*:${local.account_id}:rule/${var.name_prefix}-*",
      "arn:${local.partition}:lambda:*:${local.account_id}:function:${var.name_prefix}-*",
      "arn:${local.partition}:ssm:*:${local.account_id}:document/${var.name_prefix}-*",
    ]
  }

  statement {
    sid     = "ProjectLogGroups"
    effect  = "Allow"
    actions = ["logs:*"]
    resources = [
      "arn:${local.partition}:logs:*:${local.account_id}:log-group:/aws/lambda/${var.name_prefix}-*",
      "arn:${local.partition}:logs:*:${local.account_id}:log-group:/aws/lambda/${var.name_prefix}-*:*",
    ]
  }

  statement {
    sid     = "ProjectBuckets"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "${local.s3_arn}${var.name_prefix}-*",
      "${local.s3_arn}${var.name_prefix}-*/*",
    ]
  }

  # Keys cannot be named; they are controlled through the Project tag set at creation.
  statement {
    sid       = "CreateProjectKeys"
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:TagResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = ["aws-cis-governance"]
    }
  }

  statement {
    sid       = "ManageProjectKeys"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["arn:${local.partition}:kms:*:${local.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["aws-cis-governance"]
    }
  }

  statement {
    sid       = "ManageProjectAliases"
    effect    = "Allow"
    actions   = ["kms:CreateAlias", "kms:UpdateAlias", "kms:DeleteAlias"]
    resources = ["arn:${local.partition}:kms:*:${local.account_id}:alias/${var.name_prefix}-*"]
  }

  statement {
    sid    = "AccountLevelSettings"
    effect = "Allow"
    actions = [
      "ec2:EnableEbsEncryptionByDefault",
      "ec2:DisableEbsEncryptionByDefault",
      "iam:UpdateAccountPasswordPolicy",
      "iam:DeleteAccountPasswordPolicy",
      "s3:PutAccountPublicAccessBlock",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProjectRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole", "iam:DetachRolePolicy",
    ]
    resources = ["${local.iam_arn}:role/${var.name_prefix}-*"]
  }

  # Only project policies and the two AWS-managed service-role policies may be attached,
  # so the apply role cannot grant itself or a new role administrator access.
  statement {
    sid       = "AttachApprovedPoliciesOnly"
    effect    = "Allow"
    actions   = ["iam:AttachRolePolicy"]
    resources = ["${local.iam_arn}:role/${var.name_prefix}-*"]

    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values = [
        "${local.iam_arn}:policy/${var.name_prefix}-*",
        "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole",
        "arn:${local.partition}:iam::aws:policy/service-role/AWSConfigRoleForOrganizations",
      ]
    }
  }

  statement {
    sid       = "PassRoleToProjectServices"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["${local.iam_arn}:role/${var.name_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["config.amazonaws.com", "lambda.amazonaws.com", "ssm.amazonaws.com"]
    }
  }

  statement {
    sid    = "ProjectManagedPolicies"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion",
      "iam:ListPolicyVersions", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = ["${local.iam_arn}:policy/${var.name_prefix}-*"]
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
      ]
    }
  }

  # --- Guardrails (explicit Deny always wins) ---

  statement {
    sid       = "DenyCiAccessTampering"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["${local.iam_arn}:role/${var.name_prefix}-ci-*", "${local.iam_arn}:oidc-provider/${local.oidc_url}"]
  }

  statement {
    sid    = "DenyStateBucketAdministration"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration", "s3:PutBucketPublicAccessBlock", "s3:PutLifecycleConfiguration",
      "s3:PutBucketLogging", "s3:DeleteObjectVersion", "s3:PutBucketOwnershipControls",
    ]
    resources = ["${local.s3_arn}${var.name_prefix}-tfstate-*", "${local.s3_arn}${var.name_prefix}-tfstate-*/*"]
  }

  statement {
    sid    = "DenyBootstrapKeyAdministration"
    effect = "Deny"
    actions = [
      "kms:ScheduleKeyDeletion", "kms:DisableKey", "kms:PutKeyPolicy", "kms:DisableKeyRotation",
      "kms:CreateGrant", "kms:RevokeGrant", "kms:RetireGrant",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Stack"
      values   = ["bootstrap"]
    }
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

resource "aws_iam_role_policy_attachment" "apply_security_audit" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "apply_read_extras" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.read_extras.arn
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.state_write.json
}
