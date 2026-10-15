# Terraform state example
# A bucket to hold remote state for other configurations, locking via use_lockfile

module "state" {
  #checkov:skip=CKV_AWS_144:Example does not set up cross-region replication
  source = "../.."

  project_prefix = "example"
  environment    = "shared"
  resource_name  = "tfstate"

  is_terraform_backend = true      # forces versioning on, fills terraform_backend_config
  backend_key_prefix   = "network" # state key: network/terraform.tfstate

  # every apply writes a new state version, keep 90 days of history
  non_current_version_expiration_in_days = 90

  # force_destroy left at false, destroying a state bucket should be hard

  tags = {
    Environment = "shared"
    Purpose     = "terraform-state"
  }
}
