# terraform-aws-s3
# Usage: just <recipe>

set shell := ["bash", "-cu"]

examples := "examples/basic examples/complete"

# List available recipes
default:
    @just --list

# Format all Terraform files
fmt:
    terraform fmt -recursive

# Check formatting without writing
fmt-check:
    terraform fmt -check -recursive -diff

# terraform validate on the module root and every example
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in . {{examples}}; do
        echo "==> $dir"
        (cd "$dir" && terraform init -backend=false -input=false >/dev/null && terraform validate)
    done

# tflint on the module and examples
lint:
    tflint --init
    tflint --recursive --format compact

# checkov and gitleaks
security:
    checkov -d . --quiet --compact --framework terraform
    gitleaks detect --no-git --source . --redact

# terraform test against the mocked provider in tests/, no AWS credentials needed
test:
    terraform init -backend=false -input=false >/dev/null
    terraform test

# Regenerate the README inputs/outputs tables
docs:
    terraform-docs .

# Fail if the README tables are stale
docs-check:
    terraform-docs --output-check .

# Full pre-commit gate
check: fmt-check validate lint security test docs-check

# Tag and push a release (no 'v' prefix)
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! "{{version}}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        echo "Invalid version '{{version}}'. Use semantic versioning, e.g. 1.2.3"
        exit 1
    fi
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Uncommitted changes, commit or stash first"
        git status --short
        exit 1
    fi
    if git rev-parse "{{version}}" >/dev/null 2>&1; then
        echo "Tag {{version}} already exists"
        exit 1
    fi
    if ! grep -q "^## {{version}}" CHANGELOG.md; then
        echo "CHANGELOG.md has no entry for {{version}}"
        exit 1
    fi
    just check
    git tag -a "{{version}}" -m "Release {{version}}"
    git push origin "{{version}}"

# Remove Terraform working directories
clean:
    find . -type d -name .terraform -prune -exec rm -rf {} +
    find . -name .terraform.lock.hcl -delete
