# ============================================================================
# Versioning
# ============================================================================

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    # Force versioning to be enabled if this is a Terraform backend or object lock is enabled
    status = var.is_terraform_backend || var.object_lock_enabled ? "Enabled" : var.versioning_status
  }
}

# ============================================================================
# Object Lock Configuration (WORM Compliance)
# ============================================================================

resource "aws_s3_bucket_object_lock_configuration" "object_lock" {
  count  = var.object_lock_enabled && var.object_lock_mode != null ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    default_retention {
      mode  = var.object_lock_mode
      days  = var.object_lock_retention_days
      years = var.object_lock_retention_years
    }
  }

  depends_on = [aws_s3_bucket_versioning.versioning]

  lifecycle {
    precondition {
      condition     = !(var.object_lock_retention_days != null && var.object_lock_retention_years != null)
      error_message = "Cannot specify both object_lock_retention_days and object_lock_retention_years. Choose one."
    }
    precondition {
      condition     = var.object_lock_mode == null || (var.object_lock_retention_days != null || var.object_lock_retention_years != null)
      error_message = "When object_lock_mode is specified, either object_lock_retention_days or object_lock_retention_years must also be specified."
    }
  }
}
