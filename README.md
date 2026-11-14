# AWS S3 Security Baseline

Northstar is a mock company that needs private storage for internal documents. This project uses Terraform to set up an S3 bucket with the following controls:

- Public access blocked
- ACLs disabled so access is managed through policies
- KMS encryption required on uploads
- HTTPS required, with TLS 1.2 or later
- Versioning to help recover overwritten or deleted files
- Cleanup of old versions after 30 days and incomplete uploads after 7 days

Checkov scans the configuration, and GitHub Actions runs the checks when code is pushed.

The code passed local Terraform checks. Deployment and testing in AWS are still pending.
