# ============================================================================
# Notification Configuration
# ============================================================================

resource "aws_s3_bucket_notification" "enhanced" {
  count  = length(var.notification_configurations) > 0 || var.enable_event_bridge_notifications ? 1 : 0
  bucket = aws_s3_bucket.main.id

  # EventBridge notifications (backward compatibility)
  eventbridge = var.enable_event_bridge_notifications

  # SQS notifications
  dynamic "queue" {
    for_each = [for config in var.notification_configurations : config if config.type == "sqs"]
    content {
      queue_arn     = queue.value.arn
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  # SNS notifications
  dynamic "topic" {
    for_each = [for config in var.notification_configurations : config if config.type == "sns"]
    content {
      topic_arn     = topic.value.arn
      events        = topic.value.events
      filter_prefix = topic.value.filter_prefix
      filter_suffix = topic.value.filter_suffix
    }
  }

  # Lambda notifications
  dynamic "lambda_function" {
    for_each = [for config in var.notification_configurations : config if config.type == "lambda"]
    content {
      lambda_function_arn = lambda_function.value.arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}
