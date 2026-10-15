# Complete example
# Exercises most module features in one apply: logging, lifecycle tiers, notifications, policies

# Data sources for dynamic configuration
data "aws_caller_identity" "current" {}

# SQS queue for S3 notifications (example)
resource "aws_sqs_queue" "s3_notifications" {
  #checkov:skip=CKV_AWS_27:Example code - SQS encryption can be enabled via kms_master_key_id parameter
  name = "s3-notifications-${data.aws_caller_identity.current.account_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:s3-notifications-${data.aws_caller_identity.current.account_id}"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::enhanced-example-${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
}

# SNS topic for S3 notifications (example)
resource "aws_sns_topic" "s3_notifications" {
  #checkov:skip=CKV_AWS_26:Example code - SNS encryption can be enabled via kms_master_key_id parameter
  name = "s3-notifications-${data.aws_caller_identity.current.account_id}"
}

resource "aws_sns_topic_policy" "s3_notifications" {
  arn = aws_sns_topic.s3_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.s3_notifications.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::enhanced-example-${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
}

# Access logs bucket, built with this module
module "access_logs" {
  #checkov:skip=CKV_AWS_145:S3 server access logging only delivers to SSE-S3 target buckets
  #checkov:skip=CKV_AWS_144:Example does not set up cross-region replication
  source = "../.."

  bucket_name   = "access-logs"
  bucket_suffix = var.aws_region
  force_destroy = true
  use_sse_s3    = true # server access logging rejects SSE-KMS targets

  # server access logs are written by the S3 logging service, it needs PutObject on the target prefix
  additional_policy_statements = [
    {
      sid       = "S3ServerAccessLogsPolicy"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["arn:aws:s3:::access-logs-${data.aws_caller_identity.current.account_id}-${var.aws_region}/enhanced-example-logs/*"]
      principals = {
        type        = "Service"
        identifiers = ["logging.s3.amazonaws.com"]
      }
      conditions = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:s3:::enhanced-example-${data.aws_caller_identity.current.account_id}"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  ]

  lifecycle_rules = [
    {
      id                                 = "expire_logs"
      status                             = "Enabled"
      expiration_days                    = 90
      noncurrent_version_expiration_days = 30
    }
  ]

  tags = {
    Environment = "development"
    Project     = "enhanced-s3-example"
    Purpose     = "access-log-target"
    ManagedBy   = "terraform"
  }
}

# Enhanced S3 bucket with all new features
module "enhanced_s3_bucket" {
  #checkov:skip=CKV_AWS_144:Example does not set up cross-region replication
  source = "../.."

  # Basic configuration
  bucket_name   = "enhanced-example"
  bucket_suffix = null
  force_destroy = true

  # Security configuration
  versioning_status      = "Enabled"
  encryption_kms_key_arn = null # Uses AWS managed key

  # Enhanced access logging
  enable_access_logging    = true
  access_log_target_bucket = module.access_logs.bucket_id
  access_log_target_prefix = "enhanced-example-logs/"

  # Enhanced lifecycle configuration with multiple rules
  lifecycle_rules = [
    {
      id                                 = "general_lifecycle"
      status                             = "Enabled"
      filter_prefix                      = ""
      expiration_days                    = 365
      noncurrent_version_expiration_days = 90
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 180
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      noncurrent_version_transitions = [
        {
          noncurrent_days = 30
          storage_class   = "STANDARD_IA"
        },
        {
          noncurrent_days = 60
          storage_class   = "GLACIER"
        }
      ]
    },
    {
      id                                 = "temp_files_cleanup"
      status                             = "Enabled"
      filter_prefix                      = "temp/"
      expiration_days                    = 7
      noncurrent_version_expiration_days = 1
      transitions                        = []
      noncurrent_version_transitions     = []
    },
    {
      id                                 = "logs_retention"
      status                             = "Enabled"
      filter_prefix                      = "logs/"
      expiration_days                    = 30
      noncurrent_version_expiration_days = 7
      transitions = [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        }
      ]
      noncurrent_version_transitions = []
    }
  ]

  # Enhanced notification configurations
  notification_configurations = [
    {
      type          = "sqs"
      events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
      arn           = aws_sqs_queue.s3_notifications.arn
      filter_prefix = "uploads/"
      filter_suffix = null
    },
    {
      type          = "sns"
      events        = ["s3:ObjectCreated:Put"]
      arn           = aws_sns_topic_policy.s3_notifications.arn # via the policy so it exists before S3 validates the topic
      filter_prefix = "important/"
      filter_suffix = ".json"
    },
    {
      type          = "sqs"
      events        = ["s3:ReducedRedundancyLostObject"]
      arn           = aws_sqs_queue.s3_notifications.arn
      filter_prefix = null
      filter_suffix = null
    }
  ]

  # EventBridge notifications (backward compatibility)
  enable_event_bridge_notifications = true

  # Additional policy statements
  additional_policy_statements = [
    {
      sid    = "AllowSpecificUserAccess"
      effect = "Allow"
      principals = {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["arn:aws:s3:::enhanced-example-${data.aws_caller_identity.current.account_id}/*"]
      conditions = [
        {
          test     = "StringEquals"
          variable = "s3:x-amz-server-side-encryption"
          values   = ["AES256"]
        }
      ]
    }
  ]

  # Tags
  tags = {
    Environment = "development"
    Project     = "enhanced-s3-example"
    Purpose     = "demonstrate-new-features"
    ManagedBy   = "terraform"
  }

  depends_on = [module.access_logs]
}

# ============================================================================
# CloudFront OAC Example - Custom Bucket Policy
# ============================================================================
# This example demonstrates using custom_bucket_policy for CloudFront Origin
# Access Control (OAC), which requires a specific policy format that cannot
# be achieved with additional_policy_statements alone.

# Create a distribution so the bucket policy can use its actual ARN.
resource "aws_cloudfront_origin_access_control" "example" {
  name                              = "cloudfront-oac-example"
  description                       = "Example OAC for S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  cloudfront_origin_bucket_name = "cloudfront-origin-example-${data.aws_caller_identity.current.account_id}"
}

resource "aws_cloudfront_distribution" "example" {
  #checkov:skip=CKV_AWS_86:Example distribution omits access logging to keep the OAC example focused
  #checkov:skip=CKV_AWS_68:Example distribution omits WAF to avoid unrelated resources and costs
  #checkov:skip=CKV_AWS_310:Example has one origin, so origin failover is not applicable
  #checkov:skip=CKV_AWS_374:Example leaves geographic access unrestricted
  #checkov:skip=CKV2_AWS_42:Example uses the default CloudFront certificate, no custom domain
  #checkov:skip=CKV2_AWS_32:Example omits a response headers policy to keep the OAC example focused
  #checkov:skip=CKV2_AWS_47:Example omits WAF, so there is no WebACL to configure
  #checkov:skip=CKV_AWS_174:Default CloudFront certificate ignores minimum_protocol_version, a custom cert is out of scope here
  enabled             = true
  default_root_object = "index.html"
  comment             = "Example S3 origin using OAC"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = "${local.cloudfront_origin_bucket_name}.s3.${var.aws_region}.amazonaws.com"
    origin_id                = local.cloudfront_origin_bucket_name
    origin_access_control_id = aws_cloudfront_origin_access_control.example.id
  }

  default_cache_behavior {
    target_origin_id       = local.cloudfront_origin_bucket_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

# S3 bucket with custom policy for CloudFront OAC
module "cloudfront_origin_bucket" {
  #checkov:skip=CKV_AWS_145:SSE-S3 so CloudFront OAC can read objects without KMS key policy changes
  #checkov:skip=CKV_AWS_144:Example does not set up cross-region replication
  source = "../.."

  # Basic configuration
  bucket_name   = "cloudfront-origin-example"
  force_destroy = true

  # Security
  versioning_status = "Enabled"
  use_sse_s3        = true

  # Custom bucket policy for CloudFront OAC access
  # This demonstrates the use case where custom_bucket_policy is necessary
  custom_bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${local.cloudfront_origin_bucket_name}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.example.arn
          }
        }
      },
      {
        Sid    = "DenyUnsecureAccess"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.cloudfront_origin_bucket_name}",
          "arn:aws:s3:::${local.cloudfront_origin_bucket_name}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Tags
  tags = {
    Environment = "development"
    Project     = "cloudfront-oac-example"
    Purpose     = "demonstrate-custom-bucket-policy"
    ManagedBy   = "terraform"
  }
}
