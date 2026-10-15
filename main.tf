# ============================================================================
# Main Orchestration
# ============================================================================
# Main orchestration file for terraform-aws-s3
#
# This module creates an S3 bucket with secure defaults and configurable options.
# The implementation is split one concern per file:
# - data.tf: Data sources
# - locals.tf: Naming and policy locals
# - bucket.tf: The S3 bucket and naming precondition
# - versioning.tf: Versioning and Object Lock
# - encryption.tf: Server-side encryption
# - public_access.tf: Public access block and ownership controls
# - lifecycle.tf: Lifecycle rules
# - logging.tf: Access logging
# - notifications.tf: EventBridge / SQS / SNS / Lambda notifications
# - cors.tf: CORS
# - policy.tf: Bucket policy
# - variables.tf: Input variables, sectioned by concern
# - outputs.tf: Output values
# - versions.tf: Terraform and provider version constraints
