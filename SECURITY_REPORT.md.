# AWS S3 Security Baseline — Security Review

## What I Built

I wanted to get more hands-on experience with AWS security, Terraform, and automated security scanning.

I started with a basic S3 bucket configuration in Terraform and used Checkov to identify potential security issues before deploying anything to AWS.

The first scan returned 7 failed checks.

## What I Fixed

I worked through the findings and added:

- **Public Access Block:** To reduce the risk of accidentally exposing the bucket.
- **Versioning:** To make it easier to recover overwritten or deleted files.
- **KMS Encryption:** To configure server-side encryption using AWS KMS.
- **Lifecycle Rules:** To clean up older object versions and incomplete uploads.

I ran Checkov again after making changes to verify whether the new configurations addressed the findings.

## Automating the Security Checks

After getting the local scans working, I connected the project to GitHub Actions.

Now, whenever I update the Terraform code on GitHub, Checkov automatically scans it.

I initially ran into some issues getting Checkov to execute correctly in PowerShell. I eventually figured out that I was running commands from the wrong directory and needed to use the correct Python entry point.

## Results

| | Initial scan | Latest scan |
|---|---|---|
| Passed | 5 | 14 |
| Failed | 7 | 3 |

Three checks remain unresolved: cross-region replication, S3 access logging, and event notifications.

I left these out of the initial implementation because I wanted to keep the project focused on basic S3 security controls. For a real client environment, I'd evaluate whether those controls are necessary based on the workload and security requirements.

## What I'd Improve

My next step would be testing the Terraform configuration in an actual AWS environment and validating that the security controls behave as expected.

I'd also like to expand the project to include IAM least privilege and more detailed logging.

**Note:** This project has been validated using Terraform static analysis, not a live AWS deployment.
