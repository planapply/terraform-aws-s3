# Basic example

The smallest useful call: a named, versioned bucket with the module defaults.

Creates one bucket named `example-dev-basic-{account_id}` with:

- KMS encryption using the AWS managed `aws/s3` key
- public access blocked, ACLs disabled
- HTTPS-only bucket policy
- versioning enabled
- incomplete multipart uploads aborted after 7 days
- EventBridge notifications on

`force_destroy = true` is set so `terraform destroy` works with objects in the
bucket. Do not copy that into production.

## Run

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

Region is `us-east-1` in `versions.tf`. Credentials come from the usual AWS
provider chain (env vars, `~/.aws`, SSO).
