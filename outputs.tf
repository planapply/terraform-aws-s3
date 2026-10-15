# ============================================================================
# Bucket Outputs
# ============================================================================

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_id" {
  description = "ID of the created S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_domain_name" {
  description = "Domain name of the created S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the created S3 bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

# ============================================================================
# Backend Configuration Outputs
# ============================================================================

output "terraform_backend_config" {
  description = "Configuration snippet for Terraform backend configuration (if enabled). Use this configuration with 'use_lockfile = true' for S3-based state locking."
  value = var.is_terraform_backend ? {
    bucket       = aws_s3_bucket.main.bucket
    key          = "${var.backend_key_prefix}/terraform.tfstate"
    region       = aws_s3_bucket.main.region
    encrypt      = true
    use_lockfile = true
  } : null
}

# ============================================================================
# Feature Outputs
# ============================================================================

output "access_logging_enabled" {
  description = "Whether access logging is enabled for this bucket"
  value       = var.enable_access_logging
}

output "access_log_target_bucket" {
  description = "Target bucket for access logs (if logging is enabled)"
  value       = var.access_log_target_bucket
}
output "access_log_target_prefix" {
  description = "Target prefix for access logs (if logging is enabled)"
  value       = var.access_log_target_prefix != null ? var.access_log_target_prefix : "${aws_s3_bucket.main.id}-logs/"
}
output "lifecycle_rules_count" {
  description = "Number of lifecycle rules configured for this bucket"
  value       = length(var.lifecycle_rules)
}

output "notification_configurations_count" {
  description = "Number of notification configurations for this bucket"
  value       = length(var.notification_configurations)
}

output "eventbridge_notifications_enabled" {
  description = "Whether EventBridge notifications are enabled for this bucket"
  value       = var.enable_event_bridge_notifications
}

# ============================================================================
# Object Lock Outputs
# ============================================================================

output "object_lock_enabled" {
  description = "Whether Object Lock is enabled for this bucket"
  value       = var.object_lock_enabled
}

output "object_lock_configuration" {
  description = "Object Lock configuration details (if enabled)"
  value = var.object_lock_enabled && var.object_lock_mode != null ? {
    mode            = var.object_lock_mode
    retention_days  = var.object_lock_retention_days
    retention_years = var.object_lock_retention_years
  } : null
}

# ============================================================================
# CORS Outputs
# ============================================================================

output "cors_enabled" {
  description = "Whether CORS is configured for this bucket"
  value       = length(var.cors_rules) > 0
}

output "cors_rules_count" {
  description = "Number of CORS rules configured for this bucket"
  value       = length(var.cors_rules)
}

# ============================================================================
# Log Delivery Policy Outputs
# ============================================================================

output "log_delivery_policies_attached" {
  description = "Summary of log delivery policies attached to this bucket"
  value = {
    elb_log_delivery        = var.attach_elb_log_delivery_policy
    lb_log_delivery         = var.attach_lb_log_delivery_policy
    cloudtrail_log_delivery = var.attach_cloudtrail_log_delivery_policy
    waf_log_delivery        = var.attach_waf_log_delivery_policy
    flowlog_log_delivery    = var.attach_flowlog_log_delivery_policy
  }
}

output "any_log_delivery_policy_attached" {
  description = "Whether any log delivery policy is attached to this bucket"
  value = (
    var.attach_elb_log_delivery_policy ||
    var.attach_lb_log_delivery_policy ||
    var.attach_cloudtrail_log_delivery_policy ||
    var.attach_waf_log_delivery_policy ||
    var.attach_flowlog_log_delivery_policy
  )
}
