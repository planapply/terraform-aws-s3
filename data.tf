# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ELB service account IDs by region (for Classic ELB logging)
# https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html
data "aws_elb_service_account" "main" {
  count = var.attach_elb_log_delivery_policy ? 1 : 0
}
