# Complete example

Exercises most of the module in one apply. Two module calls plus the
supporting resources they need.

## What it creates

`module.enhanced_s3_bucket` (`enhanced-example-{account_id}`):

- access logging to a separate log bucket created in this example
- three lifecycle rules: tiered transitions with 365-day expiry, 7-day
  cleanup under `temp/`, 30-day retention under `logs/`
- SQS and SNS notifications filtered by prefix and suffix, plus EventBridge
- an additional bucket policy statement with a condition

`module.cloudfront_origin_bucket` (`cloudfront-origin-example-{account_id}`):

- `custom_bucket_policy` replacing the module policy, shaped for CloudFront
  Origin Access Control and restricted to the actual distribution ARN created
  by this example. The bucket uses SSE-S3 for CloudFront compatibility.

Supporting resources: an SQS queue and SNS topic with S3 publish permissions,
an encrypted and versioned access log bucket, a CloudFront OAC, and a
CloudFront distribution. CloudFront can incur charges; destroy the example
when finished. The distribution is a minimal OAC demonstration, not a
production configuration: it omits WAF, access logging, and origin failover.

All buckets have `force_destroy = true` so `terraform destroy` succeeds with
objects present.

## Run

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

Region defaults to `us-west-2` via `var.aws_region`.

## Poke at it

```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)

# sqs notification (uploads/ prefix)
aws s3 cp README.md s3://enhanced-example-$ACCT/uploads/README.md
aws sqs receive-message --queue-url $(terraform output -json sqs_queue | jq -r .url)

# access logs land a few minutes later
aws s3 ls s3://access-logs-$ACCT-us-west-2/enhanced-example-logs/
```
