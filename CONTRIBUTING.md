# Contributing

Issues and pull requests are welcome.

## Before you open a PR

```bash
just check
```

That runs `terraform fmt -check`, `terraform validate` on the module and every
example, tflint, checkov, gitleaks, `terraform test`, and a terraform-docs
freshness check. CI runs the same set, so a green `just check` means a green
PR.

Tests live in `tests/` and run against a mocked AWS provider, so they need no
credentials. If you change naming, lifecycle, or bucket policy behavior, add
or update a `run` block there.

If you touched `variables.tf` or `outputs.tf`, run `just docs` and commit the
regenerated README tables.

`pre-commit install` wires the same checks into git if you prefer.

## Tooling

- Terraform 1.12+ (`.terraform-version` matches the version CI pins)
- [just](https://github.com/casey/just)
- [tflint](https://github.com/terraform-linters/tflint)
- [uv](https://github.com/astral-sh/uv), `just check` runs the latest
  [checkov](https://github.com/bridgecrewio/checkov) through `uvx` to match CI
- [gitleaks](https://github.com/gitleaks/gitleaks)
- [terraform-docs](https://github.com/terraform-docs/terraform-docs)

## Conventions

- One concern per file: `bucket.tf`, `versioning.tf`, `encryption.tf`, and so
  on. Add a new file for a new concern and list it in the `main.tf` index.
- Every variable has a `description`, and a `validation` block when its value
  has a format or range to enforce.
- Commit messages: `feat:`, `fix:`, `docs:`, `chore:` prefixes.
- Add a line to `CHANGELOG.md` under the next version for anything a user
  would notice. Summary only, not file by file.
- Keep examples applying cleanly. `examples/complete` is the integration
  test; if you add a feature, exercise it there.

## Breaking changes

Anything that renames or removes a variable or output, changes a default, or
would recreate the bucket is a breaking change. Say so in the PR and the
changelog, and include a `moved` block where one applies.

## Releasing (maintainers)

```bash
just release 1.2.3
```

Checks for a clean tree and a matching `## 1.2.3` heading in `CHANGELOG.md`,
runs `just check`, then tags and pushes. The release workflow turns the tag
into a GitHub release with that changelog section as the notes.
