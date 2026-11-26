locals {
  # Catalog of AWS-managed Config rules mapped to CIS AWS Foundations Benchmark areas.
  #   global   = evaluates account-wide resources; deployed only when var.deploy_global_rules = true
  #   periodic = trigger type is Periodic (needs maximum_execution_frequency)
  #   scope    = resource types for change-triggered rules (null = no scope restriction)
  #   params   = rule input parameters
  # Identifiers and trigger types verified against the AWS Config Developer Guide.
  catalog = {
    # --- IAM (CIS section 1) ---
    root_mfa = {
      identifier = "ROOT_ACCOUNT_MFA_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    root_hardware_mfa = {
      identifier = "ROOT_ACCOUNT_HARDWARE_MFA_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    root_no_access_key = {
      identifier = "IAM_ROOT_ACCESS_KEY_CHECK", global = true, periodic = true, scope = null, params = {}
    }
    iam_password_policy = {
      identifier = "IAM_PASSWORD_POLICY", global = true, periodic = true, scope = null
      params = {
        RequireUppercaseCharacters = "true"
        RequireLowercaseCharacters = "true"
        RequireSymbols             = "true"
        RequireNumbers             = "true"
        MinimumPasswordLength      = "14"
        PasswordReusePrevention    = "24"
        MaxPasswordAge             = "90"
      }
    }
    iam_user_mfa = {
      identifier = "IAM_USER_MFA_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    iam_console_mfa = {
      identifier = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS", global = true, periodic = true, scope = null, params = {}
    }
    iam_no_user_policies = {
      identifier = "IAM_USER_NO_POLICIES_CHECK", global = true, periodic = false, scope = ["AWS::IAM::User"], params = {}
    }
    iam_no_admin_policies = {
      identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS", global = true, periodic = false, scope = ["AWS::IAM::Policy"], params = {}
    }
    iam_unused_credentials = {
      identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK", global = true, periodic = true, scope = null
      params     = { maxCredentialUsageAge = "45" }
    }
    iam_access_key_rotation = {
      identifier = "ACCESS_KEYS_ROTATED", global = true, periodic = true, scope = null
      params     = { maxAccessKeyAge = "90" }
    }

    # --- Logging (CIS section 3) ---
    cloudtrail_enabled = {
      identifier = "CLOUD_TRAIL_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    cloudtrail_multi_region = {
      identifier = "MULTI_REGION_CLOUD_TRAIL_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    cloudtrail_encrypted = {
      identifier = "CLOUD_TRAIL_ENCRYPTION_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    cloudtrail_log_validation = {
      identifier = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED", global = true, periodic = true, scope = null, params = {}
    }
    kms_key_rotation = {
      identifier = "CMK_BACKING_KEY_ROTATION_ENABLED", global = false, periodic = true, scope = null, params = {}
    }
    vpc_flow_logs = {
      identifier = "VPC_FLOW_LOGS_ENABLED", global = false, periodic = true, scope = null
      params     = { trafficType = "REJECT" }
    }

    # --- Storage (CIS section 2) ---
    s3_account_public_block = {
      identifier = "S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS", global = true, periodic = false, scope = null
      params = {
        IgnorePublicAcls      = "true"
        BlockPublicPolicy     = "true"
        BlockPublicAcls       = "true"
        RestrictPublicBuckets = "true"
      }
    }
    s3_public_read = {
      identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED", global = false, periodic = false, scope = ["AWS::S3::Bucket"], params = {}
    }
    s3_public_write = {
      identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED", global = false, periodic = false, scope = ["AWS::S3::Bucket"], params = {}
    }
    s3_ssl_only = {
      identifier = "S3_BUCKET_SSL_REQUESTS_ONLY", global = false, periodic = false, scope = ["AWS::S3::Bucket"], params = {}
    }
    ebs_encrypted_volumes = {
      identifier = "ENCRYPTED_VOLUMES", global = false, periodic = false, scope = ["AWS::EC2::Volume"], params = {}
    }
    ebs_default_encryption = {
      identifier = "EC2_EBS_ENCRYPTION_BY_DEFAULT", global = false, periodic = true, scope = null, params = {}
    }
    rds_encrypted = {
      identifier = "RDS_STORAGE_ENCRYPTED", global = false, periodic = false, scope = ["AWS::RDS::DBInstance"], params = {}
    }
    rds_not_public = {
      identifier = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK", global = false, periodic = false, scope = ["AWS::RDS::DBInstance"], params = {}
    }
    efs_encrypted = {
      identifier = "EFS_ENCRYPTED_CHECK", global = false, periodic = true, scope = null, params = {}
    }

    # --- Networking (CIS section 5) ---
    restricted_ssh = {
      identifier = "INCOMING_SSH_DISABLED", global = false, periodic = false, scope = ["AWS::EC2::SecurityGroup"], params = {}
    }
    restricted_common_ports = {
      identifier = "RESTRICTED_INCOMING_TRAFFIC", global = false, periodic = false, scope = ["AWS::EC2::SecurityGroup"]
      params     = { blockedPort1 = "3389", blockedPort2 = "3306", blockedPort3 = "5432", blockedPort4 = "1433", blockedPort5 = "27017" }
    }
    default_sg_closed = {
      identifier = "VPC_DEFAULT_SECURITY_GROUP_CLOSED", global = false, periodic = false, scope = ["AWS::EC2::SecurityGroup"], params = {}
    }
  }

  selected = {
    for key, rule in local.catalog : key => rule
    if !contains(var.disabled_rules, key) && (var.deploy_global_rules || !rule.global)
  }
}

resource "aws_config_config_rule" "cis" {
  for_each = local.selected

  name        = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  description = "CIS AWS Foundations aligned: ${each.value.identifier}"

  maximum_execution_frequency = each.value.periodic ? var.periodic_frequency : null
  input_parameters            = length(each.value.params) == 0 ? null : jsonencode(each.value.params)

  source {
    owner             = "AWS"
    source_identifier = each.value.identifier
  }

  dynamic "scope" {
    for_each = each.value.scope == null ? [] : [each.value.scope]

    content {
      compliance_resource_types = scope.value
    }
  }

  tags = var.tags
}
