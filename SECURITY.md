# Security Policy

## Reporting a vulnerability

Do not open a public issue. Use GitHub **Security -> Report a vulnerability** on this repository, or email the platform security team (replace with your address: `security@example.com`). Expect an acknowledgement within 2 business days.

## Security model

| Concern | Control |
|---|---|
| CI access to AWS | GitHub OIDC only. Plan role trusts `pull_request` and `main`; apply role trusts only the protected GitHub Environment. |
| Privilege escalation via CI | Apply role is limited to `<prefix>-*` resources; may attach only approved policy ARNs; explicit Deny on CI roles, OIDC provider, state bucket settings and bootstrap keys. |
| State | Private, versioned, KMS-encrypted S3 bucket, TLS 1.2+ enforced, access-logged, native lock files. |
| Secrets | None in code or state. The Slack webhook is read from Secrets Manager at runtime. |
| Data in transit | Bucket policies deny non-TLS and TLS < 1.2. |
| Data at rest | Customer managed KMS keys with rotation for state, Config data, SNS, SQS, logs. |
| Supply chain | Actions pinned to SHAs; Python deps hash-locked; provider lock files committed; Dependabot; gitleaks and checkov in CI. |
| Account guard | Every provider sets `allowed_account_ids`, so a wrong credential cannot touch another account. |

## Required repository settings (not enforceable from code)

- Protect `main`: require pull request, required status check **CI gate**, Code Owner review, linear history, no force-push.
- Create GitHub Environments with **required reviewers** (and restrict to `main`) for each name used by `deploy.yml` (e.g. `prod-security`).
- Enable Dependabot alerts, secret scanning and push protection.
- Workflow permissions default: **read-only**.
- Replace `@your-org/...` teams in `.github/CODEOWNERS`.

## Supported versions

Only the `main` branch is supported.
