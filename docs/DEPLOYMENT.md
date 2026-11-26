# Deployment guide

## Prerequisites

- AWS Organization with a dedicated **security account** and the member accounts to govern. Production, staging and dev should be separate accounts.
- AWS Config and Security Hub trusted access enabled for the organization (`aws organizations enable-aws-service-access --service-principal config.amazonaws.com`, and for `securityhub.amazonaws.com`), and the security account registered as delegated administrator for Security Hub if you want org auto-enable.
- Terraform >= 1.11 (CI pins 1.17.2). Pick **one** `name_prefix` (for example `org-sec`) and use it everywhere.
- A GitHub repository with branch protection and Environments configured per [`SECURITY.md`](../SECURITY.md).
- An administrator able to run the one-time bootstrap in the state account.

## 1. Bootstrap (once, manually, in the state/security account)

The bootstrap creates the Terraform state bucket, its KMS key, and the GitHub OIDC roles. It is the only stack applied by hand, because CI cannot run before it exists.

```bash
cd bootstrap
cat > bootstrap.tfvars <<'EOF'
account_id               = "111111111111"
aws_region               = "us-east-1"
name_prefix              = "org-sec"
environment              = "prod"
github_repository        = "your-org/aws-security-CIS-complaince"
github_apply_environment = "prod-security"
EOF
terraform init
terraform apply -var-file=bootstrap.tfvars
terraform output
```

Keep the bootstrap state safe: migrate it into the new bucket by adding an `s3` backend block to `bootstrap/providers.tf` (key `bootstrap/terraform.tfstate`) and running `terraform init -migrate-state`. Do not commit `bootstrap.tfvars` if it contains anything you consider sensitive (it does not by default).

If a GitHub OIDC provider already exists in the account, set `create_oidc_provider = false`.

Set the outputs as **repository variables** (Settings -> Secrets and variables -> Actions -> Variables; role ARNs are not secrets):

| Variable | Value |
|---|---|
| `SECURITY_PLAN_ROLE_ARN` | `plan_role_arn` output |
| `SECURITY_APPLY_ROLE_ARN` | `apply_role_arn` output |

## 2. Store the Slack webhook (optional)

Create the secret outside Terraform so the URL never reaches state:

```bash
aws secretsmanager create-secret --name org-sec/slack-webhook \
  --secret-string 'https://hooks.slack.com/services/...' --kms-key-id alias/<your-key>
```

Pass its ARN as `slack_webhook_secret_arn`. The notifier role is granted `GetSecretValue` on that one ARN only.

## 3. Security account stack

```bash
cd environments/security-account
cp backend.hcl.example prod.backend.hcl      # fill bucket + kms key from bootstrap outputs
cp prod.tfvars.example prod.tfvars           # fill account IDs, bucket name, emails
git add prod.backend.hcl prod.tfvars && git commit
```

Open a pull request. CI runs static checks, `deploy.yml` plans against the **plan role**, and the OPA gate evaluates the plan. After review and merge, `deploy.yml` plans again and waits for approval in the `prod-security` environment before applying.

Confirm each email subscription (AWS sends a confirmation message to every address).

### Additional regions

For every other region you govern, copy the target with `is_home_region = false`, a distinct state key (for example `security-account/eu-west-1/terraform.tfstate`), and set `config_kms_key_arn` to the home-region key ARN (output `config_kms_key_arn`). Then add a matrix entry in `deploy.yml` and `drift.yml`. The central bucket is global to the organization and is only created in the home region.

> The Config delivery KMS key must live in the **same Region as the central bucket** (the home region), because S3 performs the SSE-KMS encryption. Recorders in other Regions therefore reference the home-region key ARN, and its key policy trusts `config.amazonaws.com` for every account in `governed_account_ids` (conditioned on `aws:SourceAccount`).

## 4. Member accounts

Each member account (and region) is its own target. Apply the **bootstrap** in the member account too (it creates that account's own plan/apply roles and, optionally, its own state bucket), or deploy members using roles that trust the same OIDC provider.

```bash
cd environments/member-account
cp backend.hcl.example 222222222222-us-east-1.backend.hcl
cp prod.tfvars.example 222222222222-us-east-1.tfvars   # config_bucket_name / config_kms_key_arn come from security-account outputs
```

Uncomment the member entry in `deploy.yml` and `drift.yml`, create the matching GitHub Environment and variables, and open a pull request.

Add each member account ID to `governed_account_ids` in the security stack **first** (otherwise Config cannot deliver to the bucket).

## 5. Rollout order and safety

1. Security account (aggregator, Security Hub, bucket).
2. One non-production member account. Watch Config compliance for a day.
3. Remaining members. Use `disabled_rules` for documented exceptions instead of deleting rules.
4. Remediation: leave `enable_remediation = false` first. Then `true` with `remediation_automatic = false` (manual execution from the Config console). Move to automatic only for rules with a proven, safe fix.

## 6. Verification

```bash
aws configservice describe-configuration-recorder-status
aws configservice describe-compliance-by-config-rule --compliance-types NON_COMPLIANT
aws securityhub get-enabled-standards
```

Trigger a test alert by creating a non-compliant resource in a sandbox account and confirm it reaches email and Slack.

## Destroying

Do not destroy casually. Buckets keep `force_destroy = false`; KMS keys have a 30-day deletion window. Removing the Config recorder stops evidence collection and is a compliance event: record it as a change.
