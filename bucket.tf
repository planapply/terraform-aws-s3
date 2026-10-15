# ============================================================================
# S3 Bucket
# ============================================================================

resource "aws_s3_bucket" "main" {
  bucket              = local.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags

  lifecycle {
    precondition {
      condition = (
        # Case 1: Using new naming pattern (all required fields present)
        (var.project_prefix != null && var.environment != null && var.resource_name != null && var.bucket_name == null && var.name_override == null) ||
        # Case 2: Using name_override (exclusive)
        (var.name_override != null && var.project_prefix == null && var.environment == null && var.resource_name == null && var.bucket_name == null) ||
        # Case 3: Using legacy naming with bucket_name
        (var.bucket_name != null && var.project_prefix == null && var.environment == null && var.resource_name == null && var.name_override == null) ||
        # Case 4: Using legacy default naming (all null)
        (var.bucket_name == null && var.project_prefix == null && var.environment == null && var.resource_name == null && var.name_override == null)
      )
      error_message = <<-EOT
        Invalid naming pattern combination. Choose ONE of these patterns:
        1. NEW PATTERN: Set project_prefix + environment + resource_name (project_suffix optional)
        2. NAME OVERRIDE: Set name_override only
        3. LEGACY: Set bucket_name (bucket_suffix optional)
        4. DEFAULT: Leave all naming variables null
        Do not mix legacy (bucket_name) with new (project_prefix/environment/resource_name) or name_override.
      EOT
    }
    # per-input validations can't see the account ID, so check the assembled name here
    precondition {
      condition     = length(local.bucket_name) <= 63
      error_message = "Bucket name \"${local.bucket_name}\" is ${length(local.bucket_name)} characters. S3 allows 63, including the 13 used by -{account_id}. Shorten the naming inputs."
    }
  }
}
