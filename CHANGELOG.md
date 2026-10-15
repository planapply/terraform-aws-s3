# Changelog

All notable changes to this module are documented here. Versions follow
semantic versioning without a `v` prefix.

## 1.0.1 - 2026-10-15

- New `examples/terraform-state` example: a remote state bucket with S3 native
  locking, noncurrent version expiry, and a rendered `backend "s3"` block.
- README Terraform state section corrected and linked to the new example.

## 1.0.0 - 2026-10-15

First public release.

- Secure-by-default S3 bucket: KMS or SSE-S3 encryption, public access
  blocked, BucketOwnerEnforced ownership, HTTPS-only bucket policy, versioning
  on, incomplete multipart uploads aborted after 7 days (configurable).
- Composable naming (`project_prefix` + `environment` + `resource_name`),
  `name_override`, and legacy `bucket_name` patterns, all with the account ID
  appended.
- Object Lock (GOVERNANCE or COMPLIANCE), lifecycle rules with transitions,
  access logging, EventBridge/SQS/SNS/Lambda notifications, CORS.
- One-flag bucket policies for ELB, ALB/NLB, CloudTrail, WAF, and VPC Flow
  Logs delivery. Additional policy statements with conditions, or a full
  custom policy.
- Terraform backend helper output with `use_lockfile`.
- Supports Terraform 1.12+ and AWS provider 6.x.
