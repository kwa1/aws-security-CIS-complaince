## What and why

<!-- Describe the change and the control/risk it addresses. -->

## Checklist

- [ ] `terraform fmt`, `validate`, `tflint`, `checkov`, `opa test` pass (CI enforces this)
- [ ] Plan output reviewed; no unexpected destroy/replace of Config recorder, buckets or KMS keys
- [ ] No secrets, account credentials or webhook URLs added to code or tfvars
- [ ] New IAM permissions are least-privilege and justified below
- [ ] Docs / runbooks updated if behaviour changed
- [ ] Rolled out to non-production first (or explain why not)

## Risk and rollback

<!-- Blast radius, and how to roll back. -->
