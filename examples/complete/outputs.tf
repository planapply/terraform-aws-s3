# outputs.tf - complete example

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = module.enhanced_s3_bucket.bucket_name
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = module.enhanced_s3_bucket.bucket_arn
}

output "bucket_domain_name" {
  description = "Domain name of the created S3 bucket"
  value       = module.enhanced_s3_bucket.bucket_domain_name
}

output "access_logging_configuration" {
  description = "Access logging configuration details"
  value = {
    enabled       = module.enhanced_s3_bucket.access_logging_enabled
    target_bucket = module.enhanced_s3_bucket.access_log_target_bucket
    target_prefix = module.enhanced_s3_bucket.access_log_target_prefix
  }
}

output "lifecycle_rules_count" {
  description = "Number of lifecycle rules passed to the module"
  value       = module.enhanced_s3_bucket.lifecycle_rules_count
}

output "notification_configuration" {
  description = "Notification configuration summary"
  value = {
    configurations_count = module.enhanced_s3_bucket.notification_configurations_count
    eventbridge_enabled  = module.enhanced_s3_bucket.eventbridge_notifications_enabled
  }
}

# Supporting resources
output "access_logs_bucket" {
  description = "Access logs bucket information"
  value = {
    name = module.access_logs.bucket_name
    arn  = module.access_logs.bucket_arn
  }
}

output "sqs_queue" {
  description = "SQS queue for notifications"
  value = {
    name = aws_sqs_queue.s3_notifications.name
    arn  = aws_sqs_queue.s3_notifications.arn
    url  = aws_sqs_queue.s3_notifications.url
  }
}

output "sns_topic" {
  description = "SNS topic for notifications"
  value = {
    name = aws_sns_topic.s3_notifications.name
    arn  = aws_sns_topic.s3_notifications.arn
  }
}

output "cloudfront_origin_bucket" {
  description = "Bucket behind the CloudFront OAC distribution"
  value = {
    name   = module.cloudfront_origin_bucket.bucket_name
    domain = aws_cloudfront_distribution.example.domain_name
  }
}
