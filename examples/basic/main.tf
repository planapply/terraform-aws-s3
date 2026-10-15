# Basic S3 Bucket Example
# Demonstrates the simplest usage of the S3 module

module "basic_bucket" {
  #checkov:skip=CKV_AWS_144:Example does not set up cross-region replication
  source = "../.."

  project_prefix = "example"
  environment    = "dev"
  resource_name  = "basic"
  force_destroy  = true

  tags = {
    Environment = "demo"
    Purpose     = "basic-example"
  }
}
