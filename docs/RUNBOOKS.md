# Runbooks

Names assume `name_prefix = org-sec`. Replace as needed.

## AWS Config is not recording

**Symptoms:** rules show `INSUFFICIENT_DATA`, no new evaluations, stale Security Hub findings.

```bash
aws configservice describe-configuration-recorders
aws configservice describe-configuration-recorder-status
aws configservice describe-delivery-channel-status
```

| Finding | Action |
|---|---|
| `recording: false` | `aws configservice start-configuration-recorder --configuration-recorder-name org-sec-recorder`, then run `terraform plan` to see why it was stopped (manual change = drift). |
| Delivery `FAILURE` / `AccessDenied` | Check the central bucket policy lists the account in `governed_account_ids`; check the KMS key policy; check the account is not in the bucket's `Deny` conditions. |
| `KMS.AccessDeniedException` | The member role needs `kms:GenerateDataKey` on the key in `config_kms_key_arn` (set by `config-baseline`). Confirm the ARN matches the home-region key. |

**Prevention:** the nightly drift workflow flags a stopped recorder.

## A CIS rule is NON_COMPLIANT

1. Identify the resource from the alert (`RuleName`, `ResourceId`, `Account`, `Region`).
2. Decide: **misconfiguration** (fix), **accepted exception**, or **false positive**.
3. Fix the resource, or for the S3 public-access rule run the remediation manually from Config -> Rules -> Remediate.
4. For a documented exception, add the catalog key to `disabled_rules` in a pull request that references the approval. Do not suppress findings informally.
5. Repeated violations from the same team: escalate and consider an SCP.

## Remediation failed

```bash
aws ssm describe-automation-executions --filters Key=DocumentNamePrefix,Values=org-sec-BlockS3PublicAccess
aws ssm get-automation-execution --automation-execution-id <id>
```

Typical causes: bucket is in another account (the role is account-local), bucket deleted, or an SCP denies `s3:PutBucketPublicAccessBlock`. To stop automatic remediation immediately, set `remediation_automatic = false` and apply through CI.

## No alerts arriving

1. EventBridge rule enabled? `aws events describe-rule --name org-sec-config-noncompliant`.
2. DLQ has messages? `aws sqs get-queue-attributes --queue-url <dlq> --attribute-names ApproximateNumberOfMessages`. Messages mean EventBridge could not publish (check topic policy/KMS) - redrive after fixing.
3. Email: subscription confirmed? (`aws sns list-subscriptions-by-topic`). Unconfirmed subscriptions receive nothing.
4. Slack: check `/aws/lambda/org-sec-slack-notifier` logs and the notifier DLQ. `ValueError ... not an https Slack webhook URL` means the secret value is wrong; `ResourceNotFoundException` means the secret ARN is wrong.

## Rotate the Slack webhook

```bash
aws secretsmanager put-secret-value --secret-id org-sec/slack-webhook --secret-string 'https://hooks.slack.com/services/NEW'
```

The Lambda caches the value per container; force a refresh by updating any function setting or waiting for containers to recycle.

## Drift issue opened by the nightly job

Read the run summary. If the change was intentional, codify it in a pull request. If not, apply through CI to revert it and investigate who changed it (CloudTrail `userIdentity` for the resource).

## Break-glass

If CI is unavailable, an administrator may apply from a hardened workstation using SSO and `terraform apply` with the same tfvars/backend config. Record the reason, run `terraform plan` first, and open a retrospective pull request. The apply role's explicit Deny rules do not apply to administrators; use this path sparingly.

## Terraform state recovery

State is versioned. To roll back, list versions with `aws s3api list-object-versions --bucket <state-bucket> --prefix <key>` and restore a prior version by copying it over the current object. Delete a stale lock with `terraform force-unlock <id>` only after confirming no run is active.
