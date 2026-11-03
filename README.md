# AWS S3 Security Baseline

A small hands-on project I built to get more comfortable with AWS security, Terraform, and automated security scanning.

## What I Did

I started with a basic S3 bucket configuration and used Checkov to find potential security issues. The first scan flagged 7 failed checks.

I then used Terraform to add:

- **S3 Public Access Block** — Prevents accidental public exposure.
- **Versioning** — Helps recover overwritten or deleted objects.
- **KMS Encryption** — Encrypts stored objects.
- **Lifecycle Rules** — Cleans up old versions and incomplete uploads.

I also set up GitHub Actions to automatically run Checkov whenever I push changes.

## Results

| | Before | After |
|---|---|---|
| Passed checks | 5 | 14 |
| Failed checks | 7 | 3 |

The three remaining findings involve cross-region replication, access logging, and event notifications. I left those out of the initial scope and documented them in the security report.

## Tools Used

AWS S3 · Terraform · Checkov · GitHub Actions

## What's Next

I plan to deploy and test the configuration in AWS, then expand into IAM permissions and logging.

This project currently demonstrates Terraform configuration and static security scanning, not a live AWS deployment.
