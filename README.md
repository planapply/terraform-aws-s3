# terraform-aws-s3

[![ci](https://github.com/planapply/terraform-aws-s3/actions/workflows/ci.yml/badge.svg)](https://github.com/planapply/terraform-aws-s3/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/planapply/terraform-aws-s3?display_name=tag&sort=semver)](https://github.com/planapply/terraform-aws-s3/releases)
[![license](https://img.shields.io/github/license/planapply/terraform-aws-s3)](LICENSE)

A Terraform module for one AWS S3 bucket that is locked down on the first
apply and does not need a second module when requirements grow: Object Lock,
lifecycle tiers, access logging, event notifications, CORS, and ready-made bucket policies for AWS service log delivery.

Requires Terraform 1.12 or newer and AWS provider 6.x.

## Contents

- [Quick start](#quick-start)
- [What you get by default](#what-you-get-by-default)
- [Naming](#naming)
- [Features](#features)
- [Examples](#examples)
- [Reference](#reference)
- [Development](#development)
- [License](#license)

## Quick start

```hcl
module "app_data" {
  source = "git::https://github.com/planapply/terraform-aws-s3.git?ref=1.0.0"

  project_prefix = "acme"
  environment    = "prod"
  resource_name  = "app-data"

  tags = {
    Environment = "prod"
    Project     = "acme"
  }
}

output "bucket" {
  value = module.app_data.bucket_name # acme-prod-app-data-123456789012
}
```

Pin `ref` to a release tag. Tags are plain semantic versions with no `v`
prefix.

## What you get by default

Every bucket, with no inputs beyond a name:

| Control | Default |
|---|---|
| Encryption | SSE-KMS with the AWS managed `aws/s3` key, bucket keys on |
| Public access | All four public access blocks enabled |
| ACLs | Disabled (`BucketOwnerEnforced`) |
| Transport | Bucket policy denies any request without TLS |
| Versioning | Enabled |
| Multipart uploads | Incomplete uploads aborted after 7 days |
| Notifications | EventBridge on |
| Name | Account ID appended, so the name is globally unique |

## Naming

Choose one pattern. Mixing them is rejected at plan time. The account ID is
always appended.

| Pattern | Set these | Resulting name |
|---|---|---|
| Composable | `project_prefix`, `environment`, `resource_name`, optional `project_suffix` | `{prefix}-{env}-{name}[-{suffix}]-{account_id}` |
| Override | `name_override` | `{name_override}-{account_id}` |
| Legacy | `bucket_name`, optional `bucket_suffix` | `{bucket_name}-{account_id}[-{bucket_suffix}]` |
| Default | nothing | `s3-bucket-{account_id}` |

If `project_prefix` already ends in `-{environment}` the environment is not
repeated, so `project_prefix = "acme-prod"` with `environment = "prod"` gives
`acme-prod-...`, not `acme-prod-prod-...`.

## Features

### Encryption

SSE-KMS with the AWS managed key is the default. Pass `encryption_kms_key_arn`
for a customer managed key. Set `use_sse_s3 = true` to switch to SSE-S3
(AES256), which CloudFront Origin Access Control needs unless you edit the
KMS key policy.

### Object Lock (WORM)

```hcl
object_lock_enabled         = true
object_lock_mode            = "COMPLIANCE" # or GOVERNANCE
object_lock_retention_years = 7
```

Object Lock can only be turned on when the bucket is created and cannot be
turned off later. It forces versioning on. Set `object_lock_retention_days`
or `object_lock_retention_years`, not both.

### Lifecycle rules

```hcl
lifecycle_rules = [
  {
    id                                 = "tiering"
    status                             = "Enabled"
    filter_prefix                      = ""
    expiration_days                    = 365
    noncurrent_version_expiration_days = 90
    transitions = [
      { days = 30, storage_class = "STANDARD_IA" },
      { days = 90, storage_class = "GLACIER" },
    ]
    noncurrent_version_transitions = [
      { noncurrent_days = 30, storage_class = "STANDARD_IA" },
    ]
  },
]
```

A bucket-wide abort-incomplete-multipart rule is always present; tune it with
`abort_incomplete_multipart_upload_days`. S3 rejects the same action on
overlapping prefixes, which is why individual rules cannot carry their own.
The shortcut `non_current_version_expiration_in_days` still works for the
simple case but is ignored once `lifecycle_rules` is set.

### Access logging

```hcl
enable_access_logging    = true
access_log_target_bucket = aws_s3_bucket.logs.id
access_log_target_prefix = "app-data/" # default: {bucket_name}-logs/
```

The target bucket must already exist. The module does not create it.

### Notifications

EventBridge is on by default. Add SQS, SNS, or Lambda targets with
`notification_configurations`:

```hcl
notification_configurations = [
  {
    type          = "sqs"
    arn           = aws_sqs_queue.uploads.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  },
]
```

The queue, topic, or function policy that lets S3 publish is yours to write.
[`examples/complete`](examples/complete/) shows the SQS and SNS versions.

### CORS

```hcl
cors_rules = [
  {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://app.example.com"]
    allowed_headers = ["*"]
    max_age_seconds = 3600
  },
]
```

### Static sites

There is no S3 website hosting. Website endpoints need a public bucket, and
this module always blocks public access. Serve static sites through CloudFront
with Origin Access Control on the bucket's REST endpoint
(`bucket_regional_domain_name`). Use the distribution's default root object for
`/index.html`, and a CloudFront Function if subdirectories need their own index.
`examples/complete` shows the OAC bucket policy.

### Log delivery policies

One flag each adds the bucket policy statements an AWS service needs to write
its logs:

```hcl
attach_lb_log_delivery_policy         = true # ALB and NLB
attach_elb_log_delivery_policy        = true # Classic ELB
attach_cloudtrail_log_delivery_policy = true
attach_waf_log_delivery_policy        = true # bucket name must start with aws-waf-logs-
attach_flowlog_log_delivery_policy    = true
```

The ALB/NLB, CloudTrail, WAF, and Flow Logs statements only accept logs from
the current account, under `[prefix/]AWSLogs/{account_id}/`. Pass
`lb_source_accounts`, `waf_source_accounts`, `cloudtrail_source_accounts`, or
`flowlog_source_accounts` for cross-account delivery. Classic ELB writes as
the regional ELB service account and is granted `s3:PutObject` on the whole
bucket, which is how AWS documents it.

ALB and Classic ELB access logs only support SSE-S3, so set
`use_sse_s3 = true` on their log bucket. NLB accepts SSE-S3 or a customer
managed KMS key, not the AWS managed `aws/s3` default.

### Bucket policy

`additional_policy_statements` appends to the default policy and supports
IAM conditions:

```hcl
additional_policy_statements = [
  {
    sid       = "EncryptedUploadsOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::acme-prod-app-data-123456789012/*"]
    principals = {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:role/uploader"]
    }
    conditions = [
      {
        test     = "StringEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["aws:kms"]
      },
    ]
  },
]
```

`custom_bucket_policy` replaces the whole policy, including the TLS-only
deny and any log delivery statements. Reach for it when the policy shape is
outside what the inputs express (CloudFront OAC is the usual case) and add
the `aws:SecureTransport` deny back yourself.

### Terraform state bucket

```hcl
is_terraform_backend = true
backend_key_prefix   = "network"
```

Versioning is forced on and the `terraform_backend_config` output is a
ready-to-paste `backend "s3"` block using `use_lockfile = true`, so no
DynamoDB table is needed on Terraform 1.10 or newer.

## Examples

| Example | Shows |
|---|---|
| [`basic`](examples/basic/) | A bucket named with the composable pattern and every default. |
| [`complete`](examples/complete/) | Access logging, tiered lifecycle rules, SQS and SNS notifications, additional policy statements, and a second bucket with a custom CloudFront OAC policy. |

Both set `force_destroy = true` so `terraform destroy` works with objects
present. Do not copy that into production.

## Reference

<!-- BEGIN_TF_DOCS -->
<details>
<summary>Requirements, resources, inputs, and outputs (generated by terraform-docs)</summary>

### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.12.0 |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.access_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_notification.enhanced](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_object_lock_configuration.object_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

### Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| abort_incomplete_multipart_upload_days | Days after initiation before an incomplete multipart upload is aborted. Applies bucket-wide | `number` | `7` |
| access_log_target_bucket | Existing bucket that receives access logs. Required when enable_access_logging is true | `string` | `null` |
| access_log_target_prefix | Prefix for access log objects. Defaults to {bucket_name}-logs/ | `string` | `null` |
| additional_policy_statements | Extra bucket policy statements appended to the default policy. Each supports optional IAM conditions | ```list(object({ sid = string effect = string actions = list(string) resources = list(string) principals = object({ type = string identifiers = list(string) }) conditions = optional(list(object({ test = string variable = string values = list(string) })), []) }))``` | `[]` |
| attach_cloudtrail_log_delivery_policy | Allow CloudTrail to write logs to this bucket | `bool` | `false` |
| attach_elb_log_delivery_policy | Allow Classic ELB to write access logs to this bucket | `bool` | `false` |
| attach_flowlog_log_delivery_policy | Allow VPC Flow Logs to write to this bucket | `bool` | `false` |
| attach_lb_log_delivery_policy | Allow ALB and NLB to write access logs to this bucket | `bool` | `false` |
| attach_waf_log_delivery_policy | Allow AWS WAF to write logs to this bucket. WAF requires the bucket name to start with aws-waf-logs- | `bool` | `false` |
| backend_key_prefix | State key prefix, combined as {backend_key_prefix}/terraform.tfstate in terraform_backend_config | `string` | `"s3-module"` |
| bucket_name | Legacy naming: base bucket name, becomes {bucket_name}-{account_id}. Prefer the composable pattern for new buckets | `string` | `null` |
| bucket_suffix | Legacy naming: appended after the account ID, {bucket_name}-{account_id}-{bucket_suffix}. Only used with bucket_name | `string` | `null` |
| cloudtrail_source_accounts | Account IDs allowed to deliver CloudTrail logs. Defaults to the current account | `list(string)` | `[]` |
| cors_rules | CORS rules for browser access | ```list(object({ id = optional(string) allowed_headers = optional(list(string), ["*"]) allowed_methods = list(string) allowed_origins = list(string) expose_headers = optional(list(string), []) max_age_seconds = optional(number, 3000) }))``` | `[]` |
| custom_bucket_policy | Complete bucket policy JSON. Replaces the default policy entirely, including the TLS-only deny and any log delivery statements | `string` | `null` |
| enable_access_logging | Enable server access logging. Requires access_log_target_bucket | `bool` | `false` |
| enable_event_bridge_notifications | Send bucket events to EventBridge | `bool` | `true` |
| encryption_kms_key_arn | Customer managed KMS key ARN or alias ARN. Defaults to the AWS managed aws/s3 key. Ignored when use_sse_s3 is true | `string` | `null` |
| environment | Environment name (dev, prod, uat-west, ...), second part of the composable name. Lowercase alphanumeric and hyphens | `string` | `null` |
| flowlog_source_accounts | Account IDs allowed to deliver VPC Flow Logs. Defaults to the current account | `list(string)` | `[]` |
| force_destroy | Delete all objects when the bucket is destroyed. Permanent data loss, keep false in production | `bool` | `false` |
| is_terraform_backend | Mark this bucket as a Terraform state backend. Forces versioning on and populates the terraform_backend_config output | `bool` | `false` |
| lb_source_accounts | Account IDs allowed to deliver ALB and NLB access logs. Defaults to the current account | `list(string)` | `[]` |
| lifecycle_rules | Lifecycle rules with expiration, noncurrent expiration, and storage class transitions. Incomplete multipart uploads are handled by the bucket-wide rule, see abort_incomplete_multipart_upload_days | ```list(object({ id = string status = string filter_prefix = optional(string, "") expiration_days = optional(number) noncurrent_version_expiration_days = optional(number) transitions = optional(list(object({ days = number storage_class = string })), []) noncurrent_version_transitions = optional(list(object({ noncurrent_days = number storage_class = string })), []) }))``` | `[]` |
| name_override | Use this exact name instead of the composable or legacy patterns. The account ID is still appended | `string` | `null` |
| non_current_version_expiration_in_days | Shortcut: expire noncurrent versions after this many days. Ignored when lifecycle_rules is set | `number` | `null` |
| notification_configurations | SQS, SNS, or Lambda notification targets with event list and optional prefix/suffix filters | ```list(object({ type = string # sqs, sns, or lambda events = list(string) arn = string filter_prefix = optional(string) filter_suffix = optional(string) }))``` | `[]` |
| object_lock_enabled | Enable S3 Object Lock. Can only be set when the bucket is created and cannot be turned off later | `bool` | `false` |
| object_lock_mode | Default retention mode for new objects: GOVERNANCE (privileged users can override) or COMPLIANCE (nobody can, including root) | `string` | `null` |
| object_lock_retention_days | Default retention period in days (1-36500). Mutually exclusive with object_lock_retention_years | `number` | `null` |
| object_lock_retention_years | Default retention period in years (1-100). Mutually exclusive with object_lock_retention_days | `number` | `null` |
| object_ownership | Object ownership setting. BucketOwnerEnforced disables ACLs entirely | `string` | `"BucketOwnerEnforced"` |
| project_prefix | Project or org identifier, first part of the composable name: {project_prefix}-{environment}-{resource_name} | `string` | `null` |
| project_suffix | Optional suffix appended to the composable name before the account ID | `string` | `""` |
| resource_name | What the bucket holds (app-data, logs, ...), last part of the composable name | `string` | `null` |
| tags | Tags applied to the bucket | `map(string)` | `{}` |
| use_sse_s3 | Use SSE-S3 (AES256) instead of KMS. Needed for CloudFront OAC origins without KMS key policy changes | `bool` | `false` |
| versioning_status | Enabled or Suspended. Forced to Enabled when is_terraform_backend or object_lock_enabled is true | `string` | `"Enabled"` |
| waf_source_accounts | Account IDs allowed to deliver WAF logs. Defaults to the current account | `list(string)` | `[]` |

### Outputs

| Name | Description |
| ---- | ----------- |
| access_log_target_bucket | Target bucket for access logs (if logging is enabled) |
| access_log_target_prefix | Target prefix for access logs (if logging is enabled) |
| access_logging_enabled | Whether access logging is enabled for this bucket |
| any_log_delivery_policy_attached | Whether any log delivery policy is attached to this bucket |
| bucket_arn | ARN of the created S3 bucket |
| bucket_domain_name | Domain name of the created S3 bucket |
| bucket_id | ID of the created S3 bucket |
| bucket_name | Name of the created S3 bucket |
| bucket_regional_domain_name | Regional domain name of the created S3 bucket |
| cors_enabled | Whether CORS is configured for this bucket |
| cors_rules_count | Number of CORS rules configured for this bucket |
| eventbridge_notifications_enabled | Whether EventBridge notifications are enabled for this bucket |
| lifecycle_rules_count | Number of lifecycle rules configured for this bucket |
| log_delivery_policies_attached | Summary of log delivery policies attached to this bucket |
| notification_configurations_count | Number of notification configurations for this bucket |
| object_lock_configuration | Object Lock configuration details (if enabled) |
| object_lock_enabled | Whether Object Lock is enabled for this bucket |
| terraform_backend_config | Configuration snippet for Terraform backend configuration (if enabled). Use this configuration with 'use_lockfile = true' for S3-based state locking. |

</details>
<!-- END_TF_DOCS -->

## Development

```bash
just          # list recipes
just check    # fmt-check, validate, tflint, checkov, gitleaks, test, docs-check
just test     # terraform test against a mocked provider, no AWS account needed
just docs     # regenerate the Reference section
```

`pre-commit install` runs the same checks before each commit. CI runs them on
every push and pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for
conventions and the release process, and [SECURITY.md](SECURITY.md) for
reporting vulnerabilities.

## License

[Apache-2.0](LICENSE).
