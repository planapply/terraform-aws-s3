# ============================================================================
# Input Variables
# ============================================================================
# Grouped by concern, most commonly set first. Backend last.

# ============================================================================
# Naming Convention Variables (New Pattern)
# ============================================================================

variable "project_prefix" {
  description = "Project or org identifier, first part of the composable name: {project_prefix}-{environment}-{resource_name}"
  type        = string
  default     = null
  validation {
    condition     = var.project_prefix == null || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_prefix))
    error_message = "project_prefix must be lowercase alphanumeric with hyphens, starting and ending with alphanumeric characters"
  }
}

variable "environment" {
  description = "Environment name (dev, prod, uat-west, ...), second part of the composable name. Lowercase alphanumeric and hyphens"
  type        = string
  default     = null
  validation {
    condition     = var.environment == null || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.environment))
    error_message = "Environment must be lowercase alphanumeric with hyphens, starting and ending with alphanumeric characters (or null to use legacy naming)"
  }
}

variable "project_suffix" {
  description = "Optional suffix appended to the composable name before the account ID"
  type        = string
  default     = ""
  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_suffix))
    error_message = "project_suffix must be empty or lowercase alphanumeric with hyphens, starting and ending with alphanumeric characters"
  }
}

variable "resource_name" {
  description = "What the bucket holds (app-data, logs, ...), last part of the composable name"
  type        = string
  default     = null
  validation {
    condition     = var.resource_name == null || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.resource_name))
    error_message = "resource_name must be lowercase alphanumeric with hyphens, starting and ending with alphanumeric characters"
  }
}

variable "name_override" {
  description = "Use this exact name instead of the composable or legacy patterns. The account ID is still appended"
  type        = string
  default     = null
  validation {
    condition     = var.name_override == null || (can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.name_override)) && !can(regex("\\.\\.|-\\.|\\.-", var.name_override)))
    error_message = "name_override must be lowercase letters, numbers, hyphens, and periods, start and end with a letter or number, and have no consecutive periods or a period next to a hyphen"
  }
}

# ============================================================================
# Legacy Naming Variables (Backward Compatibility)
# ============================================================================

variable "bucket_name" {
  description = "Legacy naming: base bucket name, becomes {bucket_name}-{account_id}. Prefer the composable pattern for new buckets"
  type        = string
  default     = null
  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,35}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be between 3 and 37 characters (to leave room for -{account_id} and bucket_suffix), contain only lowercase letters, numbers, hyphens, and periods, and start and end with a letter or number."
  }
  validation {
    condition     = var.bucket_name == null || !can(regex("\\.\\.|-\\.", var.bucket_name))
    error_message = "Bucket name cannot contain consecutive periods, or a period adjacent to a hyphen."
  }
  validation {
    condition     = var.bucket_name == null || !can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.bucket_name))
    error_message = "Bucket name cannot be formatted as an IP address."
  }
}

variable "bucket_suffix" {
  description = "Legacy naming: appended after the account ID, {bucket_name}-{account_id}-{bucket_suffix}. Only used with bucket_name"
  type        = string
  default     = null
  validation {
    condition     = var.bucket_suffix == null || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_suffix))
    error_message = "bucket_suffix must contain only lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen."
  }
  validation {
    condition     = var.bucket_suffix == null || try(length(var.bucket_suffix) <= 20, false)
    error_message = "bucket_suffix must be 20 characters or less to ensure total bucket name stays within S3 limits."
  }
}

# ============================================================================
# General
# ============================================================================

variable "tags" {
  description = "Tags applied to the bucket"
  type        = map(string)
  default     = {}
  validation {
    condition = alltrue([
      for key, value in var.tags :
      length(key) <= 128 && length(value) <= 256
    ])
    error_message = "Tag keys must be 128 characters or less, and tag values must be 256 characters or less."
  }
  validation {
    condition = alltrue([
      for key in keys(var.tags) :
      can(regex("^[a-zA-Z0-9+\\-=._:/@\\s]*$", key))
    ])
    error_message = "Tag keys can only contain letters, numbers, spaces, and the following characters: + - = . _ : / @"
  }
}

variable "force_destroy" {
  description = "Delete all objects when the bucket is destroyed. Permanent data loss, keep false in production"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.force_destroy))
    error_message = "force_destroy must be a boolean value (true or false)."
  }
}

variable "object_ownership" {
  description = "Object ownership setting. BucketOwnerEnforced disables ACLs entirely"
  type        = string
  default     = "BucketOwnerEnforced"
  validation {
    condition     = contains(["BucketOwnerPreferred", "ObjectWriter", "BucketOwnerEnforced"], var.object_ownership)
    error_message = "object_ownership must be one of: BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced."
  }
}

# ============================================================================
# Versioning
# ============================================================================

variable "versioning_status" {
  description = "Enabled or Suspended. Forced to Enabled when is_terraform_backend or object_lock_enabled is true"
  type        = string
  default     = "Enabled"
  validation {
    condition     = contains(["Enabled", "Suspended"], var.versioning_status)
    error_message = "versioning_status must be either Enabled or Suspended"
  }
}

# ============================================================================
# Object Locking Configuration (WORM Compliance)
# ============================================================================

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock. Can only be set when the bucket is created and cannot be turned off later"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.object_lock_enabled))
    error_message = "object_lock_enabled must be a boolean value (true or false)."
  }
}

variable "object_lock_mode" {
  description = "Default retention mode for new objects: GOVERNANCE (privileged users can override) or COMPLIANCE (nobody can, including root)"
  type        = string
  default     = null
  validation {
    condition     = var.object_lock_mode == null || contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be either 'GOVERNANCE' or 'COMPLIANCE'."
  }
}

variable "object_lock_retention_days" {
  description = "Default retention period in days (1-36500). Mutually exclusive with object_lock_retention_years"
  type        = number
  default     = null
  validation {
    condition     = var.object_lock_retention_days == null || (var.object_lock_retention_days >= 1 && var.object_lock_retention_days <= 36500)
    error_message = "object_lock_retention_days must be between 1 and 36500 (100 years)."
  }
}

variable "object_lock_retention_years" {
  description = "Default retention period in years (1-100). Mutually exclusive with object_lock_retention_days"
  type        = number
  default     = null
  validation {
    condition     = var.object_lock_retention_years == null || (var.object_lock_retention_years >= 1 && var.object_lock_retention_years <= 100)
    error_message = "object_lock_retention_years must be between 1 and 100."
  }
}

# ============================================================================
# Encryption
# ============================================================================

variable "encryption_kms_key_arn" {
  description = "Customer managed KMS key ARN or alias ARN. Defaults to the AWS managed aws/s3 key. Ignored when use_sse_s3 is true"
  type        = string
  default     = null
  validation {
    condition     = var.encryption_kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.encryption_kms_key_arn)) || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:alias/.+$", var.encryption_kms_key_arn))
    error_message = "KMS key ARN must be a valid AWS KMS key ARN or alias ARN format."
  }
}

variable "use_sse_s3" {
  description = "Use SSE-S3 (AES256) instead of KMS. Needed for CloudFront OAC origins without KMS key policy changes"
  type        = bool
  default     = false
}

# ============================================================================
# Bucket Policy
# ============================================================================

variable "additional_policy_statements" {
  description = "Extra bucket policy statements appended to the default policy. Each supports optional IAM conditions"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
    principals = object({
      type        = string
      identifiers = list(string)
    })
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
  validation {
    condition = alltrue([
      for statement in var.additional_policy_statements :
      contains(["Allow", "Deny"], statement.effect)
    ])
    error_message = "All policy statement effects must be either 'Allow' or 'Deny'."
  }
  validation {
    condition = alltrue([
      for statement in var.additional_policy_statements :
      contains(["AWS", "Service", "Federated", "CanonicalUser"], statement.principals.type)
    ])
    error_message = "All policy statement principal types must be one of: AWS, Service, Federated, CanonicalUser."
  }
  validation {
    condition = alltrue([
      for statement in var.additional_policy_statements :
      length(statement.actions) > 0
    ])
    error_message = "All policy statements must have at least one action."
  }
}

variable "custom_bucket_policy" {
  description = "Complete bucket policy JSON. Replaces the default policy entirely, including the TLS-only deny and any log delivery statements"
  type        = string
  default     = null
  validation {
    condition     = var.custom_bucket_policy == null || can(jsondecode(var.custom_bucket_policy))
    error_message = "custom_bucket_policy must be a valid JSON string or null."
  }
  validation {
    condition     = var.custom_bucket_policy == null || length(var.additional_policy_statements) == 0
    error_message = "Cannot use both custom_bucket_policy and additional_policy_statements. Choose one approach."
  }
}

# ============================================================================
# Pre-built Log Delivery Policies
# ============================================================================

variable "attach_elb_log_delivery_policy" {
  description = "Allow Classic ELB to write access logs to this bucket"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.attach_elb_log_delivery_policy))
    error_message = "attach_elb_log_delivery_policy must be a boolean value (true or false)."
  }
}

variable "attach_lb_log_delivery_policy" {
  description = "Allow ALB and NLB to write access logs to this bucket"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.attach_lb_log_delivery_policy))
    error_message = "attach_lb_log_delivery_policy must be a boolean value (true or false)."
  }
}

variable "lb_source_accounts" {
  description = "Account IDs allowed to deliver ALB and NLB access logs. Defaults to the current account"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for account in var.lb_source_accounts :
      can(regex("^[0-9]{12}$", account))
    ])
    error_message = "All load balancer source accounts must be valid 12-digit AWS account IDs."
  }
}

variable "attach_cloudtrail_log_delivery_policy" {
  description = "Allow CloudTrail to write logs to this bucket"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.attach_cloudtrail_log_delivery_policy))
    error_message = "attach_cloudtrail_log_delivery_policy must be a boolean value (true or false)."
  }
}

variable "cloudtrail_source_accounts" {
  description = "Account IDs allowed to deliver CloudTrail logs. Defaults to the current account"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for account in var.cloudtrail_source_accounts :
      can(regex("^[0-9]{12}$", account))
    ])
    error_message = "All CloudTrail source accounts must be valid 12-digit AWS account IDs."
  }
}

variable "attach_waf_log_delivery_policy" {
  description = "Allow AWS WAF to write logs to this bucket. WAF requires the bucket name to start with aws-waf-logs-"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.attach_waf_log_delivery_policy))
    error_message = "attach_waf_log_delivery_policy must be a boolean value (true or false)."
  }
}

variable "waf_source_accounts" {
  description = "Account IDs allowed to deliver WAF logs. Defaults to the current account"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for account in var.waf_source_accounts :
      can(regex("^[0-9]{12}$", account))
    ])
    error_message = "All WAF source accounts must be valid 12-digit AWS account IDs."
  }
}

variable "attach_flowlog_log_delivery_policy" {
  description = "Allow VPC Flow Logs to write to this bucket"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.attach_flowlog_log_delivery_policy))
    error_message = "attach_flowlog_log_delivery_policy must be a boolean value (true or false)."
  }
}

variable "flowlog_source_accounts" {
  description = "Account IDs allowed to deliver VPC Flow Logs. Defaults to the current account"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for account in var.flowlog_source_accounts :
      can(regex("^[0-9]{12}$", account))
    ])
    error_message = "All Flow Log source accounts must be valid 12-digit AWS account IDs."
  }
}

# ============================================================================
# Lifecycle Configuration
# ============================================================================

variable "non_current_version_expiration_in_days" {
  description = "Shortcut: expire noncurrent versions after this many days. Ignored when lifecycle_rules is set"
  type        = number
  default     = null
  validation {
    condition     = var.non_current_version_expiration_in_days == null || try(var.non_current_version_expiration_in_days >= 1 && var.non_current_version_expiration_in_days <= 3653, false)
    error_message = "non_current_version_expiration_in_days must be between 1 and 3653 days (10 years) or null."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after initiation before an incomplete multipart upload is aborted. Applies bucket-wide"
  type        = number
  default     = 7
  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1 && var.abort_incomplete_multipart_upload_days <= 3653
    error_message = "abort_incomplete_multipart_upload_days must be between 1 and 3653 days (10 years)."
  }
}

variable "lifecycle_rules" {
  description = "Lifecycle rules with expiration, noncurrent expiration, and storage class transitions. Incomplete multipart uploads are handled by the bucket-wide rule, see abort_incomplete_multipart_upload_days"
  type = list(object({
    id                                 = string
    status                             = string
    filter_prefix                      = optional(string, "")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    noncurrent_version_transitions = optional(list(object({
      noncurrent_days = number
      storage_class   = string
    })), [])
  }))
  default = []
  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      contains(["Enabled", "Disabled"], rule.status)
    ])
    error_message = "All lifecycle rule status values must be either 'Enabled' or 'Disabled'."
  }
  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      rule.expiration_days == null || (rule.expiration_days >= 1 && rule.expiration_days <= 3653)
    ])
    error_message = "expiration_days must be between 1 and 3653 days (10 years) or null."
  }
  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      rule.noncurrent_version_expiration_days == null || (rule.noncurrent_version_expiration_days >= 1 && rule.noncurrent_version_expiration_days <= 3653)
    ])
    error_message = "noncurrent_version_expiration_days must be between 1 and 3653 days (10 years) or null."
  }
}

# ============================================================================
# Logging Configuration
# ============================================================================

variable "enable_access_logging" {
  description = "Enable server access logging. Requires access_log_target_bucket"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.enable_access_logging))
    error_message = "enable_access_logging must be a boolean value (true or false)."
  }
}

variable "access_log_target_bucket" {
  description = "Existing bucket that receives access logs. Required when enable_access_logging is true"
  type        = string
  default     = null
  validation {
    condition     = var.access_log_target_bucket == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.access_log_target_bucket))
    error_message = "Target bucket name must be a valid S3 bucket name."
  }
}

variable "access_log_target_prefix" {
  description = "Prefix for access log objects. Defaults to {bucket_name}-logs/"
  type        = string
  default     = null
  validation {
    condition     = var.access_log_target_prefix == null || can(regex("^[a-zA-Z0-9!_.*'()-/]*$", var.access_log_target_prefix))
    error_message = "Access log prefix must contain only valid S3 object key characters."
  }
}

# ============================================================================
# Notification Configuration
# ============================================================================

variable "enable_event_bridge_notifications" {
  description = "Send bucket events to EventBridge"
  type        = bool
  default     = true
  validation {
    condition     = can(tobool(var.enable_event_bridge_notifications))
    error_message = "enable_event_bridge_notifications must be a boolean value (true or false)."
  }
}

# Enhanced Notification Configuration
variable "notification_configurations" {
  description = "SQS, SNS, or Lambda notification targets with event list and optional prefix/suffix filters"
  type = list(object({
    type          = string # sqs, sns, or lambda
    events        = list(string)
    arn           = string
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
  validation {
    condition = alltrue([
      for config in var.notification_configurations :
      contains(["sqs", "sns", "lambda"], config.type)
    ])
    error_message = "Notification type must be one of: sqs, sns, lambda."
  }
  validation {
    condition = alltrue([
      for config in var.notification_configurations :
      length(config.events) > 0
    ])
    error_message = "Each notification configuration must have at least one event."
  }
}

# ============================================================================
# CORS Configuration
# ============================================================================

variable "cors_rules" {
  description = "CORS rules for browser access"
  type = list(object({
    id              = optional(string)
    allowed_headers = optional(list(string), ["*"])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
  validation {
    condition = alltrue([
      for rule in var.cors_rules :
      length(rule.allowed_methods) > 0 && alltrue([
        for method in rule.allowed_methods :
        contains(["GET", "HEAD", "PUT", "POST", "DELETE"], method)
      ])
    ])
    error_message = "Each CORS rule must have at least one allowed_method, and methods must be one of: GET, HEAD, PUT, POST, DELETE."
  }
  validation {
    condition = alltrue([
      for rule in var.cors_rules :
      length(rule.allowed_origins) > 0
    ])
    error_message = "Each CORS rule must have at least one allowed_origin."
  }
  validation {
    condition = alltrue([
      for rule in var.cors_rules :
      rule.max_age_seconds == null || (rule.max_age_seconds >= 0 && rule.max_age_seconds <= 86400)
    ])
    error_message = "max_age_seconds must be between 0 and 86400 (24 hours)."
  }
}

# ============================================================================
# Terraform Backend
# ============================================================================

variable "is_terraform_backend" {
  description = "Mark this bucket as a Terraform state backend. Forces versioning on and populates the terraform_backend_config output"
  type        = bool
  default     = false
  validation {
    condition     = can(tobool(var.is_terraform_backend))
    error_message = "is_terraform_backend must be a boolean value (true or false)."
  }
}

variable "backend_key_prefix" {
  description = "State key prefix, combined as {backend_key_prefix}/terraform.tfstate in terraform_backend_config"
  type        = string
  default     = "s3-module"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_/]*[a-zA-Z0-9]$", var.backend_key_prefix)) || var.backend_key_prefix == ""
    error_message = "Backend key prefix must contain only alphanumeric characters, hyphens, underscores, and forward slashes, and must start and end with alphanumeric characters."
  }
}
