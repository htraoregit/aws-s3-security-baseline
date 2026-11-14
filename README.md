# AWS S3 Security Baseline

Northstar is a mock company that needs private storage for internal documents. Terraform creates a file bucket and a separate bucket for its access logs.

Controls added:

- Public access blocked and ACLs disabled on both buckets
- A customer-managed KMS key with rotation for the file bucket
- Uploads must specify KMS encryption and the approved key
- HTTPS required on both buckets; TLS 1.2 or later required on the file bucket
- Versioning and cleanup of old versions and incomplete uploads
- Access logs delivered to a separate encrypted bucket

Upload a sample file after deploying:

```powershell
$bucket = terraform output -raw bucket_name
$key = terraform output -raw kms_key_arn
aws s3 cp sample.txt "s3://$bucket/sample.txt" --sse aws:kms --sse-kms-key-id $key
```

Terraform validation passed locally. Checkov: **36 passed, 0 failed, 6 skipped**. See [after-scan.txt](after-scan.txt) and [SECURITY_REPORT.md](SECURITY_REPORT.md) for results and exceptions. AWS deployment and live tests are still pending.

This is a disposable lab: destroying it permanently deletes both buckets' files and versions and schedules KMS key deletion after 30 days. Use sample data only. AWS charges may apply.
