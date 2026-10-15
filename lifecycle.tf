# ============================================================================
# Lifecycle Configuration
# ============================================================================

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  count  = 1 # Always create lifecycle configuration for security best practices
  bucket = aws_s3_bucket.main.id

  # The only abort rule. S3 rejects the same action on overlapping prefixes, and "" overlaps everything,
  # so no other rule in this configuration may carry abort_incomplete_multipart_upload.
  rule {
    id     = "abort_incomplete_multipart_uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  # var.lifecycle_rules, or the legacy single rule when only the shortcut is set (locals.tf)
  dynamic "rule" {
    for_each = local.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      filter {
        prefix = rule.value.filter_prefix
      }

      # Current version expiration
      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      # Non-current version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }

      # Current version transitions
      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Non-current version transitions
      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }
    }
  }
}
