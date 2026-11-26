# AWS CIS Compliance Governance

Terraform framework that continuously enforces and monitors the **CIS AWS Foundations Benchmark** across an AWS Organization, with a security-first CI/CD pipeline.

| Capability | Implementation |
|---|---|
| Continuous configuration recording | AWS Config recorder per account/region, delivering to one central KMS-encrypted bucket |
| CIS-aligned detective controls | 28 AWS-managed Config rules (IAM, logging, storage, networking) with a per-rule opt-out |
| Central visibility | Organization Config aggregator + Security Hub (CIS 3.0.0 and AWS FSBP) with cross-region finding aggregation |
| Account hardening | EBS default encryption, S3 account-level Block Public Access, IAM password policy |
| Alerting | EventBridge -> SNS (KMS) -> email and optional Slack (webhook in Secrets Manager), DLQs on every hop |
| Remediation | Opt-in SSM Automation for public S3 buckets: *detect only* -> *manual* -> *automatic* |
| Policy-as-code | OPA/Rego gate on every Terraform plan, with unit tests |
| Supply chain | Actions pinned to commit SHAs, hash-locked Python deps, provider lock files, Dependabot |
| Access | GitHub OIDC (no AWS keys), separate read-only plan and approval-gated apply roles |

## Repository layout

```
bootstrap/                  State backend (S3 + KMS, native locking) and CI IAM roles. Run once per state account.
environments/
  security-account/         Central stack: Config storage, aggregator, Security Hub, alerts
  member-account/           Per-account stack: Config baseline, CIS rules, hardening
modules/
  kms-key/                  CMK with rotation
  secure-bucket/            Hardened S3 bucket (TLS-only, versioned, encrypted, logged)
  config-central-storage/   Config bucket + key + access-log bucket
  config-baseline/          Recorder, delivery channel, least-privilege role
  config-rules-cis/         Rule catalog (toggle per rule)
  config-aggregator/        Organization aggregator
  securityhub/              Hub, standards, cross-region aggregation
  account-hardening/        EBS / S3 / IAM account settings
  notifications/            EventBridge, SNS, DLQs, Slack forwarder
  remediation/              SSM Automation + Config remediation
opa/policies, opa/tests     Plan-time guardrails and their tests
.github/workflows           ci.yml, deploy.yml, terraform.yml (reusable), drift.yml
docs/                       Architecture, deployment, runbooks, control mapping
```

## Quick start

1. Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), then follow [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) (bootstrap -> security account -> member accounts).
2. Operate it with [`docs/RUNBOOKS.md`](docs/RUNBOOKS.md). See what each control covers in [`docs/CONTROL-MAPPING.md`](docs/CONTROL-MAPPING.md).

Never apply from a laptop in production. Changes flow: pull request -> CI + plan + OPA gate -> review -> merge -> approval-gated apply.

## Local checks

```bash
terraform fmt -recursive -check
terraform -chdir=modules/secure-bucket init -backend=false && terraform -chdir=modules/secure-bucket test
opa test --v1-compatible opa
python -m pytest modules/notifications/lambda/tests
tflint --init && tflint --recursive
checkov --config-file .checkov.yaml
pre-commit run --all-files   # optional, see .pre-commit-config.yaml
```

## Security

See [`SECURITY.md`](SECURITY.md) for reporting and the security model. Detective controls alert by default; nothing is auto-remediated until you opt in.

## Known limitations

- AWS Config rules and Security Hub are regional: deploy each stack once per governed region, with `is_home_region = true` in exactly one.
- Some CIS controls (e.g. root account usage review, hardware MFA procedures) require process, not just configuration.
- The CI apply role is scoped by resource prefix (`<name_prefix>-*`); resources outside that prefix need a policy update in `bootstrap/`.

## License

GNU General Public License v3.0 - see [`LICENSE`](LICENSE).
