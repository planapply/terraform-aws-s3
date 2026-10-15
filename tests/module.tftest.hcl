# terraform test with a mocked aws provider, no credentials or real resources

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-bucket" }
  }
}

run "name_too_long" {
  command = plan
  variables {
    bucket_name   = "abcdefghijabcdefghijabcdefghijabcdefg"
    bucket_suffix = "abcdefghijabcdefghij"
  }
  expect_failures = [aws_s3_bucket.main]
}

run "name_ok" {
  command = plan
  variables {
    project_prefix = "acme"
    environment    = "prod"
    resource_name  = "app-data"
  }
  assert {
    condition     = aws_s3_bucket.main.bucket == "acme-prod-app-data-111122223333"
    error_message = "bad name"
  }
}

run "env_not_doubled" {
  command = plan
  variables {
    project_prefix = "acme-prod"
    environment    = "prod"
    resource_name  = "app-data"
  }
  assert {
    condition     = aws_s3_bucket.main.bucket == "acme-prod-app-data-111122223333"
    error_message = "environment repeated in name"
  }
}

run "mixed_naming_rejected" {
  command = plan
  variables {
    bucket_name    = "legacy"
    project_prefix = "acme"
    environment    = "prod"
    resource_name  = "app-data"
  }
  expect_failures = [aws_s3_bucket.main]
}

# S3 rejects the same lifecycle action on overlapping prefixes, so abort must appear exactly once
run "single_abort_rule_with_lifecycle_rules" {
  command = plan
  variables {
    abort_incomplete_multipart_upload_days = 3
    lifecycle_rules = [
      { id = "all", status = "Enabled", filter_prefix = "", expiration_days = 365 },
      { id = "tmp", status = "Enabled", filter_prefix = "temp/", expiration_days = 7 },
    ]
  }
  assert {
    condition     = length([for r in aws_s3_bucket_lifecycle_configuration.lifecycle[0].rule : r if length(r.abort_incomplete_multipart_upload) > 0]) == 1
    error_message = "expected exactly one rule with abort_incomplete_multipart_upload"
  }
  assert {
    condition     = one([for r in aws_s3_bucket_lifecycle_configuration.lifecycle[0].rule : r.abort_incomplete_multipart_upload[0].days_after_initiation if length(r.abort_incomplete_multipart_upload) > 0]) == 3
    error_message = "abort_incomplete_multipart_upload_days not applied"
  }
  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.lifecycle[0].rule) == 3
    error_message = "expected abort rule plus two user rules"
  }
}

run "single_abort_rule_with_legacy_expiration" {
  command = plan
  variables {
    non_current_version_expiration_in_days = 30
  }
  assert {
    condition     = length([for r in aws_s3_bucket_lifecycle_configuration.lifecycle[0].rule : r if length(r.abort_incomplete_multipart_upload) > 0]) == 1
    error_message = "legacy rule must not carry its own abort action"
  }
  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.lifecycle[0].rule) == 2
    error_message = "expected abort rule plus legacy rule"
  }
}

run "versioning_forced_for_backend" {
  command = plan
  variables {
    is_terraform_backend = true
    versioning_status    = "Suspended"
  }
  assert {
    condition     = aws_s3_bucket_versioning.versioning.versioning_configuration[0].status == "Enabled"
    error_message = "backend bucket must have versioning on"
  }
}

run "merged_conditions_and_scoped_logs" {
  command = apply
  variables {
    attach_lb_log_delivery_policy      = true
    attach_waf_log_delivery_policy     = true
    attach_flowlog_log_delivery_policy = true
    lb_source_accounts                 = ["444455556666"]
    additional_policy_statements = [{
      sid        = "Two"
      effect     = "Deny"
      actions    = ["s3:PutObject"]
      resources  = ["arn:aws:s3:::mock-bucket/*"]
      principals = { type = "AWS", identifiers = ["*"] }
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-server-side-encryption", values = ["aws:kms"] },
        { test = "StringEquals", variable = "aws:PrincipalAccount", values = ["111122223333"] },
      ]
    }]
  }
  assert {
    condition     = length(keys([for s in jsondecode(aws_s3_bucket_policy.main.policy).Statement : s if s.Sid == "Two"][0].Condition.StringEquals)) == 2
    error_message = "StringEquals not merged"
  }
  assert {
    condition     = [for s in jsondecode(aws_s3_bucket_policy.main.policy).Statement : s if s.Sid == "AllowALBLogDelivery"][0].Resource == ["arn:aws:s3:::mock-bucket/*AWSLogs/444455556666/*"]
    error_message = "ALB resource not scoped"
  }
  assert {
    condition     = [for s in jsondecode(aws_s3_bucket_policy.main.policy).Statement : s if s.Sid == "AllowWAFLogDelivery"][0].Condition.StringEquals["aws:SourceAccount"] == ["111122223333"]
    error_message = "WAF source account missing"
  }
  assert {
    condition     = [for s in jsondecode(aws_s3_bucket_policy.main.policy).Statement : s if s.Sid == "DenyUnsecureAccess"][0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "TLS-only deny missing"
  }
}
