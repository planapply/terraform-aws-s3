# ============================================================================
# Access Logging
# ============================================================================

# Access logging resource - only create if logging is enabled
resource "aws_s3_bucket_logging" "access_logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.main.id

  target_bucket = var.access_log_target_bucket
  target_prefix = var.access_log_target_prefix != null ? var.access_log_target_prefix : "${aws_s3_bucket.main.id}-logs/"
}
