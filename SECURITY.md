# Security

This module creates S3 buckets with secure defaults, but it is still
infrastructure code you run with your own credentials. Review a plan before
applying it.

## Reporting a vulnerability

Do not open a public issue for security problems.

Use GitHub's private vulnerability reporting on this repository
(Security tab, "Report a vulnerability"), or email joeespo@gmail.com.

Include the module version, a description of the issue, and a minimal
configuration that reproduces it if you have one. You will get an
acknowledgement, and a fix or a reasoned response before any public
disclosure.

## Scope

In scope: anything in this repository that would make a bucket less secure
than the configuration suggests, such as a policy statement that grants more
than intended, a default that silently weakens encryption or public access
blocking, or a validation gap that lets an unsafe value through.

Out of scope: vulnerabilities in Terraform, the AWS provider, or AWS itself.
Report those upstream.
