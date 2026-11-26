| CIS AWS Foundations area | Control | Mechanism in this repo | Type |
|---|---|---|---|
| 1.4 Root has no access keys | `IAM_ROOT_ACCESS_KEY_CHECK` | config-rules-cis `root_no_access_key` | Detective |
| 1.5 / 1.6 Root MFA / hardware MFA | `ROOT_ACCOUNT_MFA_ENABLED`, `ROOT_ACCOUNT_HARDWARE_MFA_ENABLED` | `root_mfa`, `root_hardware_mfa` | Detective |
| 1.8 / 1.9 Password policy (>= 14, reuse 24) | `IAM_PASSWORD_POLICY` | `iam_password_policy` rule + `account-hardening` sets the policy | Preventive + detective |
| 1.10 MFA for console users | `MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS`, `IAM_USER_MFA_ENABLED` | `iam_console_mfa`, `iam_user_mfa` | Detective |
| 1.12 Unused credentials (45 d) | `IAM_USER_UNUSED_CREDENTIALS_CHECK` | `iam_unused_credentials` | Detective |
| 1.13 Access key rotation (90 d) | `ACCESS_KEYS_ROTATED` | `iam_access_key_rotation` | Detective |
| 1.15 No inline user policies | `IAM_USER_NO_POLICIES_CHECK` | `iam_no_user_policies`; OPA denies `aws_iam_user` / `aws_iam_access_key` | Detective + preventive |
| 1.16 No `*:*` admin policies | `IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS` | `iam_no_admin_policies`; OPA `iam.rego` | Detective + preventive |
| 2.1.x S3 encryption in transit / not public | `S3_BUCKET_SSL_REQUESTS_ONLY`, `S3_BUCKET_PUBLIC_READ/WRITE_PROHIBITED`, `S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS` | rules + `account-hardening` account block + `secure-bucket` + OPA `s3.rego` + opt-in remediation | Preventive + detective + corrective |
| 2.2.1 EBS encryption | `ENCRYPTED_VOLUMES`, `EC2_EBS_ENCRYPTION_BY_DEFAULT` | rules + `account-hardening` default encryption + OPA | Preventive + detective |
| 2.3.x RDS / EFS encryption, no public RDS | `RDS_STORAGE_ENCRYPTED`, `RDS_INSTANCE_PUBLIC_ACCESS_CHECK`, `EFS_ENCRYPTED_CHECK` | rules + OPA `encryption.rego` | Detective + preventive |
| 3.1 / 3.2 CloudTrail enabled, multi-region | `CLOUD_TRAIL_ENABLED`, `MULTI_REGION_CLOUD_TRAIL_ENABLED` | rules | Detective |
| 3.4 / 3.7 Log validation, encryption | `CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED`, `CLOUD_TRAIL_ENCRYPTION_ENABLED` | rules | Detective |
| 3.x AWS Config enabled in all regions | Config recorder per region | `config-baseline` (+ drift workflow detects a stopped recorder) | Preventive |
| 3.8 KMS key rotation | `CMK_BACKING_KEY_ROTATION_ENABLED` | rule; every key this repo creates has rotation on; OPA `aws_kms_key` rule | Detective + preventive |
| 3.9 VPC flow logs | `VPC_FLOW_LOGS_ENABLED` | rule | Detective |
| 5.2 / 5.3 No world-open SSH / RDP | `INCOMING_SSH_DISABLED`, `RESTRICTED_INCOMING_TRAFFIC` | rules + OPA `networking.rego` | Detective + preventive |
| 5.4 Default security group closed | `VPC_DEFAULT_SECURITY_GROUP_CLOSED` | rule | Detective |
| Central findings | Security Hub CIS 3.0.0 + FSBP | `securityhub` | Detective |

## Not covered by Terraform alone (process controls)

- CIS 1.1 Contact details, 1.2 security contact, 1.3 security questions: set in the account/organization configuration.
- CIS 1.7 Avoid root usage: requires monitoring and an operating procedure (CloudTrail metric filter / alarm on root sign-in).
- CIS 4.x CloudWatch metric filters and alarms: Security Hub's CIS standard evaluates these; add a CloudTrail log group and filters in the account that owns the organization trail.
- Support role (1.17), IAM Access Analyzer (1.20): enable per account or via organization policy.

These are surfaced by Security Hub; treat the Security Hub CIS score as the source of truth for gaps.

The CIS section numbers above are indicative groupings; verify numbering against the benchmark version you certify against (Security Hub is subscribed to v3.0.0 by default).
