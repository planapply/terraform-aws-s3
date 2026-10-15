# ============================================================================
# Local Values
# ============================================================================

locals {
  # ============================================================================
  # Composable Naming Pattern
  # ============================================================================
  # Implements the new naming convention with backward compatibility

  # Build name prefix from project components
  # If project_prefix already contains the environment (e.g., "acme-uat-west" with environment "uat-west"),
  # don't duplicate it
  name_prefix = var.project_prefix != null && var.environment != null ? (
    endswith(var.project_prefix, "-${var.environment}") ? var.project_prefix : "${var.project_prefix}-${var.environment}"
  ) : null

  # Build name suffix from project_suffix
  name_suffix = var.project_suffix != "" ? "-${var.project_suffix}" : ""

  # Compute the base name using the appropriate pattern
  computed_base_name = (
    # Priority 1: name_override takes precedence
    var.name_override != null ? var.name_override : (
      # Priority 2: New naming pattern (project_prefix + environment + resource_name)
      local.name_prefix != null && var.resource_name != null ?
      "${local.name_prefix}-${var.resource_name}${local.name_suffix}" : (
        # Priority 3: Legacy pattern with bucket_name
        var.bucket_name != null ? var.bucket_name : (
          # Priority 4: Default pattern
          "s3-bucket"
        )
      )
    )
  )

  # ============================================================================
  # Final Bucket Naming with Account ID
  # ============================================================================
  # Format: {computed_base_name}-{account_id}[-{bucket_suffix}]
  # Note: bucket_suffix is only used in legacy mode
  bucket_name = var.bucket_suffix != null && var.bucket_name != null ? (
    "${local.computed_base_name}-${data.aws_caller_identity.current.account_id}-${var.bucket_suffix}"
    ) : (
    "${local.computed_base_name}-${data.aws_caller_identity.current.account_id}"
  )

}

# ============================================================================
# Bucket Policy Statements
# ============================================================================

locals {
  # Resolve source accounts for policies
  cloudtrail_source_accounts = length(var.cloudtrail_source_accounts) > 0 ? var.cloudtrail_source_accounts : [data.aws_caller_identity.current.account_id]
  flowlog_source_accounts    = length(var.flowlog_source_accounts) > 0 ? var.flowlog_source_accounts : [data.aws_caller_identity.current.account_id]
  lb_source_accounts         = length(var.lb_source_accounts) > 0 ? var.lb_source_accounts : [data.aws_caller_identity.current.account_id]
  waf_source_accounts        = length(var.waf_source_accounts) > 0 ? var.waf_source_accounts : [data.aws_caller_identity.current.account_id]

  # log keys are [prefix/]AWSLogs/{account}/..., leading * covers an optional prefix
  lb_log_resources         = [for account in local.lb_source_accounts : "${aws_s3_bucket.main.arn}/*AWSLogs/${account}/*"]
  waf_log_resources        = [for account in local.waf_source_accounts : "${aws_s3_bucket.main.arn}/*AWSLogs/${account}/*"]
  cloudtrail_log_resources = [for account in local.cloudtrail_source_accounts : "${aws_s3_bucket.main.arn}/*AWSLogs/${account}/*"]
  flowlog_log_resources    = [for account in local.flowlog_source_accounts : "${aws_s3_bucket.main.arn}/*AWSLogs/${account}/*"]

  # Default policy statements for secure transport enforcement
  default_policy_statement = [
    {
      Sid    = "DenyUnsecureAccess"
      Effect = "Deny"
      Principal = {
        AWS = "*"
      }
      Action = [
        "s3:*"
      ]
      Resource = [
        aws_s3_bucket.main.arn,
        "${aws_s3_bucket.main.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }
  ]

  # ============================================================================
  # Pre-built Log Delivery Policy Statements
  # ============================================================================
  # Each policy is defined separately to avoid tuple type issues, then combined with concat

  # Classic ELB log delivery policy
  elb_log_delivery_statements = var.attach_elb_log_delivery_policy ? [
    {
      Sid    = "AllowELBLogDelivery"
      Effect = "Allow"
      Principal = {
        AWS = data.aws_elb_service_account.main[0].arn
      }
      Action   = ["s3:PutObject"]
      Resource = ["${aws_s3_bucket.main.arn}/*"]
    }
  ] : []

  # ALB/NLB log delivery policy - ACL check statement
  lb_log_delivery_acl_statements = var.attach_lb_log_delivery_policy ? [
    {
      Sid       = "AllowALBNLBLogDeliveryAclCheck"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:GetBucketAcl"]
      Resource  = [aws_s3_bucket.main.arn]
      Condition = { StringEquals = { "aws:SourceAccount" = local.lb_source_accounts } }
    }
  ] : []

  # ALB log delivery policy - ALB writes as logdelivery.elasticloadbalancing, not delivery.logs
  alb_log_delivery_put_statements = var.attach_lb_log_delivery_policy ? [
    {
      Sid       = "AllowALBLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
      Action    = ["s3:PutObject"]
      Resource  = local.lb_log_resources # account in the key path is how ALB scopes delivery
    }
  ] : []

  # NLB log delivery policy - Put object statement
  lb_log_delivery_put_statements = var.attach_lb_log_delivery_policy ? [
    {
      Sid       = "AllowALBNLBLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:PutObject"]
      Resource  = local.lb_log_resources
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceAccount" = local.lb_source_accounts } }
    }
  ] : []

  # CloudTrail log delivery policy - ACL check statement
  cloudtrail_log_delivery_acl_statements = var.attach_cloudtrail_log_delivery_policy ? [
    {
      Sid       = "AllowCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = ["s3:GetBucketAcl"]
      Resource  = [aws_s3_bucket.main.arn]
    }
  ] : []

  # CloudTrail log delivery policy - Put object statement
  cloudtrail_log_delivery_put_statements = var.attach_cloudtrail_log_delivery_policy ? [
    {
      Sid       = "AllowCloudTrailLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = ["s3:PutObject"]
      Resource  = local.cloudtrail_log_resources
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
    }
  ] : []

  # WAF log delivery policy - ACL check statement
  waf_log_delivery_acl_statements = var.attach_waf_log_delivery_policy ? [
    {
      Sid       = "AllowWAFLogDeliveryAclCheck"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:GetBucketAcl"]
      Resource  = [aws_s3_bucket.main.arn]
      Condition = { StringEquals = { "aws:SourceAccount" = local.waf_source_accounts } }
    }
  ] : []

  # WAF log delivery policy - Put object statement
  waf_log_delivery_put_statements = var.attach_waf_log_delivery_policy ? [
    {
      Sid       = "AllowWAFLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:PutObject"]
      Resource  = local.waf_log_resources
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceAccount" = local.waf_source_accounts } }
    }
  ] : []

  # VPC Flow Logs delivery policy - ACL check statement
  flowlog_log_delivery_acl_statements = var.attach_flowlog_log_delivery_policy ? [
    {
      Sid       = "AllowFlowLogAclCheck"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
      Resource  = [aws_s3_bucket.main.arn]
      Condition = { StringEquals = { "aws:SourceAccount" = local.flowlog_source_accounts } }
    }
  ] : []

  # VPC Flow Logs delivery policy - Put object statement
  flowlog_log_delivery_put_statements = var.attach_flowlog_log_delivery_policy ? [
    {
      Sid       = "AllowFlowLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["s3:PutObject"]
      Resource  = local.flowlog_log_resources
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceAccount" = local.flowlog_source_accounts } }
    }
  ] : []

  # Combine all pre-built log delivery policies
  log_delivery_policy_statements = concat(
    local.elb_log_delivery_statements,
    local.lb_log_delivery_acl_statements,
    local.alb_log_delivery_put_statements,
    local.lb_log_delivery_put_statements,
    local.cloudtrail_log_delivery_acl_statements,
    local.cloudtrail_log_delivery_put_statements,
    local.waf_log_delivery_acl_statements,
    local.waf_log_delivery_put_statements,
    local.flowlog_log_delivery_acl_statements,
    local.flowlog_log_delivery_put_statements,
  )

  # Combine default and additional policy statements
  policy_statements = concat(
    local.default_policy_statement,
    local.log_delivery_policy_statements,
    [for statement in var.additional_policy_statements : merge(
      {
        Sid    = statement.sid
        Effect = statement.effect
        Principal = {
          (statement.principals.type) = statement.principals.identifiers
        }
        Action   = statement.actions
        Resource = statement.resources
      },
      # Add Condition block only if conditions are provided
      length(statement.conditions) > 0 ? {
        # group by test, two StringEquals entries would otherwise be duplicate keys
        Condition = {
          for test in distinct([for condition in statement.conditions : condition.test]) :
          test => {
            for variable in distinct([for condition in statement.conditions : condition.variable if condition.test == test]) :
            variable => distinct(flatten([
              for condition in statement.conditions : condition.values
              if condition.test == test && condition.variable == variable
            ]))
          }
        }
      } : {}
    )]
  )
}

# ============================================================================
# Lifecycle
# ============================================================================

locals {
  # legacy non_current_version_expiration_in_days becomes a plain rule, ignored once lifecycle_rules is set
  lifecycle_rules = length(var.lifecycle_rules) > 0 ? var.lifecycle_rules : (
    var.non_current_version_expiration_in_days == null ? [] : [{
      id                                 = "delete_old_versions"
      status                             = "Enabled"
      filter_prefix                      = ""
      expiration_days                    = null
      noncurrent_version_expiration_days = var.non_current_version_expiration_in_days
      transitions                        = []
      noncurrent_version_transitions     = []
    }]
  )
}
