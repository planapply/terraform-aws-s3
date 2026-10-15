# outputs.tf - terraform-state example

output "bucket_name" {
  description = "Name of the state bucket"
  value       = module.state.bucket_name
}

output "backend_config" {
  description = "Backend settings as an object, for -backend-config or scripting"
  value       = module.state.terraform_backend_config
}

output "backend_hcl" {
  description = "backend \"s3\" block to paste into a consuming configuration"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${module.state.terraform_backend_config.bucket}"
        key          = "${module.state.terraform_backend_config.key}"
        region       = "${module.state.terraform_backend_config.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
