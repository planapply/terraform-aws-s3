# ============================================================================
# Bucket Policy
# ============================================================================
# Statements are assembled in locals.tf

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  # Use custom policy if provided, otherwise use the default policy statements
  policy = var.custom_bucket_policy != null ? var.custom_bucket_policy : jsonencode({
    Version   = "2012-10-17"
    Statement = local.policy_statements
  })

  # Make sure the bucket exists before trying to apply a policy
  depends_on = [aws_s3_bucket.main]
}
