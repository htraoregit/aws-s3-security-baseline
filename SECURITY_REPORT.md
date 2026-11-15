# Security notes

This lab covers private S3 storage, encryption, versioning, and access logging.
It does not configure employee roles, monitoring alerts, CloudTrail, or independent backups.

## Access and encryption

The file bucket rejects HTTP, TLS below 1.2, and uploads without explicit SSE-KMS
headers naming the project key. Reads require S3 permission and KMS decryption permission.
The key policy allows the account to delegate key access through IAM policies; it
does not automatically grant every employee access.

The log bucket uses SSE-S3, as required for this S3 server-access-log destination.
Its policy permits the logging service to write logs for the file bucket in the same account.

## Checkov exceptions

Six resource-specific exceptions are recorded in the Terraform comments and scan:

| Resource | Check | Reason |
|---|---|---|
| File bucket | CKV_AWS_144 | Replication is outside this lab. |
| File bucket | CKV2_AWS_62 | No event consumer is configured. |
| Log bucket | CKV_AWS_145 | The log destination uses SSE-S3. |
| Log bucket | CKV_AWS_18 | Avoid recursive logging of the log bucket. |
| Log bucket | CKV_AWS_144 | Log replication is outside this lab. |
| Log bucket | CKV2_AWS_62 | No log event consumer is configured. |

Skipped checks are scope decisions, not passed checks.

## Recovery and cleanup

Versioning helps recover changed or deleted files, but an authorized administrator
can still delete versions permanently. Old document versions expire after 30 noncurrent
days. Current logs expire after 90 days, and their noncurrent versions after another
30 days. Lifecycle processing is asynchronous.

Both buckets allow Terraform to delete all their contents during destroy. The KMS key
has a 30-day deletion waiting period. Use sample data only and protect the Terraform state.
Changing default encryption does not re-encrypt existing objects.

## Verification

Terraform formatting and validation pass locally. The saved Checkov report is
[after-scan.txt](after-scan.txt). AWS deployment status, effective access, version recovery,
and log delivery have not been verified as part of this cleanup. Server access logging
is best effort and does not provide a complete audit trail.

[AWS logging requirements](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html)
and [S3 KMS permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html).
