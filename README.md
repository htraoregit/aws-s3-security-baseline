# AWS S3 Security Baseline

## Overview
A beginner cloud security engineering project demonstrating how Terraform can implement AWS S3 security controls and how Checkov can identify infrastructure misconfigurations before deployment.

## Technologies
- AWS S3
- Terraform
- AWS KMS
- Checkov
- GitHub Actions

## Security Controls
- S3 Block Public Access
- Object Versioning
- Lifecycle Management
- Server-Side Encryption using AWS KMS

## Security Validation
The initial configuration was scanned using Checkov and identified seven failed checks.

Security controls were then added incrementally, with the configuration rescanned after each change.

See `before-scan.txt` and `after-scan.txt` for the actual findings.

## Compliance References
Relevant NIST SP 800-53 control concepts include:

- AC-3 — Access Enforcement
- SC-28 — Protection of Information at Rest
- CM-6 — Configuration Settings

These references are illustrative mappings, not evidence of full regulatory compliance.

## Limitations
This project demonstrates Terraform configuration and static security analysis. It does not establish production security, successful AWS deployment, or complete regulatory compliance.

## Future Improvements
- IAM least-privilege access
- S3 access logging
- CloudTrail data event monitoring
- Terraform deployment validation
- Automated compliance evidence reporting