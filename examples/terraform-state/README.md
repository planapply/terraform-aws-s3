# Terraform state example

A bucket for remote Terraform state, with S3 native locking
(`use_lockfile = true`, Terraform 1.10 or newer).

Creates one bucket named `example-shared-tfstate-{account_id}` with:

- everything in the [basic example](../basic/README.md) (KMS encryption,
  public access blocked, HTTPS-only policy)
- versioning forced on by `is_terraform_backend`, so a bad apply can be rolled
  back to an earlier state version
- noncurrent state versions expired after 90 days
- the `terraform_backend_config` output filled in, keyed at
  `network/terraform.tfstate`

`force_destroy` is left at `false`. A state bucket should not be easy to
delete.

## Run

```bash
terraform init
terraform apply
terraform output -raw backend_hcl
```

Region is `us-east-1` in `versions.tf`. Credentials come from the usual AWS
provider chain (env vars, `~/.aws`, SSO).

## Use it from another configuration

Paste the `backend_hcl` output into the consuming configuration:

```hcl
terraform {
  backend "s3" {
    bucket       = "example-shared-tfstate-123456789012"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Backend blocks cannot reference variables. Either keep the values literal, as
above, or leave the block empty (`backend "s3" {}`) and pass them at init:

```bash
terraform init \
  -backend-config="bucket=example-shared-tfstate-123456789012" \
  -backend-config="key=network/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
```

`backend_key_prefix` only sets the key shown in the output. One bucket can
hold state for many configurations, each with its own `key`.

## Permissions

Whoever runs the consuming configuration needs `s3:ListBucket` on the bucket,
plus `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on both the state
key and its lock file (`{key}.tflock`). The default `aws/s3` KMS key allows
any principal in the account to use it through S3. A customer managed key
(`encryption_kms_key_arn`) also needs `kms:Encrypt`, `kms:Decrypt`, and
`kms:GenerateDataKey` in its key policy.

## Bootstrapping

This configuration's own state starts out local, since the bucket does not
exist yet. Once it is applied, you can move that state into the bucket it just
created: add a `backend "s3"` block with a separate key (for example
`bootstrap/terraform.tfstate`) and run:

```bash
terraform init -migrate-state
```

Keep the local `terraform.tfstate` until the migration is confirmed, then
delete it.

## Destroy

`terraform destroy` only succeeds while the bucket is empty. Once it holds
state, every object version has to be removed first, or `force_destroy` set to
`true` and applied before destroying. If you migrated this configuration's own
state into the bucket, move it back to local first
(`terraform init -migrate-state` after removing the backend block).
