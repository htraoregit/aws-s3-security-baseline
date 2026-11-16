# AWS S3 Security Baseline

A small Terraform lab for Northstar, a mock company that needs private file storage. It creates a file bucket, a log bucket, and a KMS key in `us-east-2`.

## What's included

- Public access blocked and ACLs disabled on both buckets.
- KMS encryption for files, with key rotation enabled.
- HTTPS required on both buckets; TLS 1.2+ on the file bucket.
- Versioning, access logging, and lifecycle cleanup.

Uploads must specify SSE-KMS and the project key. The log bucket uses SSE-S3.

## Run it

With Terraform installed and AWS credentials configured:

```powershell
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Review the plan before approving. Outputs give you both bucket names and the KMS key ARN. Your AWS identity needs S3 and KMS permissions.

The [saved Checkov scan](after-scan.txt) has 36 passed checks, 0 failed, and 6 skipped. See [security notes](SECURITY_REPORT.md) for the exceptions.

Use sample files only. AWS charges apply. `terraform destroy` deletes both buckets and all file versions, and schedules the KMS key for deletion after 30 days.
