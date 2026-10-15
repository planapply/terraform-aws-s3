# Basic S3 Bucket Example
# Demonstrates the simplest usage of the S3 module

module "basic_bucket" {
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
