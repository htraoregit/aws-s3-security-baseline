# AWS S3 Security Baseline

I built this lab to practice deploying and securing AWS
infrastructure with Terraform.

The scenario is based on Northstar, a mock company that
needs secure internal document storage. The infrastructure
consists of two S3 buckets and a KMS key in us-east-2.

## Security Controls

- Public access blocked on both buckets
- ACLs disabled
- KMS encryption with key rotation for document storage
- SSE-S3 encryption for the logging bucket
- HTTPS enforced on both buckets
- TLS 1.2 or higher required on the document bucket
- Versioning, access logging and lifecycle rules

File uploads must specify SSE-KMS and the project KMS key.

## Deployment

Requirements: Terraform and configured AWS credentials
with the necessary S3 and KMS permissions.

```powershell
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Review the plan before applying. Terraform outputs the
bucket names and KMS key ARN.

## Security Testing

I used Checkov to identify misconfigurations and remediate
security findings in the Terraform code.

Final scan results:
- 36 passed
- 0 failed
- 6 skipped

See [scan results](after-scan.txt) and
[security notes](SECURITY_REPORT.md) for details.

## Limitations

Versioning helps recover deleted or overwritten files,
but it is not a replacement for an independent backup.

This is a lab environment. Use sample data only.
AWS charges apply.

To remove the infrastructure, run `terraform destroy`.
Non-empty buckets may need to be emptied first, including
all object versions and delete markers.