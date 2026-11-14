# AWS S3 Security Baseline

A Terraform project for a fictional company's internal file storage. It builds on a basic S3 bucket by adding security controls and checking the configuration with Checkov.

## Controls

- Public access blocked and ACLs disabled
- Versioning for recovering overwritten or deleted files
- KMS encryption required on uploads
- HTTPS required, with TLS 1.2 or later
- Old versions cleaned up after 30 days; incomplete uploads after 7 days

## Results

Terraform formatting and validation passed locally. Checkov reported 16 passed checks and 3 remaining findings: access logging, cross-region replication, and event notifications. GitHub Actions runs the checks on pushes and pull requests.

AWS deployment and live testing are still pending. This project demonstrates selected security controls, not full NIST or CMMC compliance.

See [main.tf](main.tf) for the configuration, [DEMO.md](DEMO.md) for deployment and testing steps, and [SECURITY_REPORT.md](SECURITY_REPORT.md) for the findings and standards mapping.
