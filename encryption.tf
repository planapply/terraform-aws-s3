# ============================================================================
# Server-Side Encryption
# ============================================================================
# Supports both KMS (default) and SSE-S3 (AES256) encryption
# Use SSE-S3 for CloudFront OAC access without KMS key policy modifications

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.main.id

  rule {
    # bucket_key_enabled only applies to KMS encryption
    bucket_key_enabled = var.use_sse_s3 ? false : true

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_sse_s3 ? "AES256" : "aws:kms"
      kms_master_key_id = var.use_sse_s3 ? null : (var.encryption_kms_key_arn != null ? var.encryption_kms_key_arn : "alias/aws/s3")
    }
  }
}
