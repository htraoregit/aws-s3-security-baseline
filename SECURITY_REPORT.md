# Security notes

The file bucket requires HTTPS, TLS 1.2+, and uploads with explicit SSE-KMS headers
naming the project key. The key policy lets the account grant key access through IAM;
it does not grant access to every user.

The log bucket uses SSE-S3. Only the S3 logging service is granted write access by
its bucket policy, restricted to the file bucket and this account.

## Checkov exceptions

| Resource | Check | Reason |
|---|---|---|
| File bucket | CKV_AWS_144 | Replication is outside this lab. |
| File bucket | CKV2_AWS_62 | No event consumer is configured. |
| Log bucket | CKV_AWS_145 | The log destination uses SSE-S3. |
| Log bucket | CKV_AWS_18 | Avoid recursive logging. |
| Log bucket | CKV_AWS_144 | Replication is outside this lab. |
| Log bucket | CKV2_AWS_62 | No event consumer is configured. |

Saved scan: [after-scan.txt](after-scan.txt). Skipped checks are not passed checks.

## Limits

- Versioning supports recovery, but an authorized user can permanently delete versions.
- Old versions expire after 30 noncurrent days. Current logs expire after 90 days.
- Access logs are best effort, not a complete audit trail.
- Employee roles, alerts, CloudTrail, and independent backups are outside this lab.
- Both buckets use `force_destroy = true`; destroying the lab deletes all files and versions.
- The KMS key has a 30-day deletion waiting period. Keep it while needed data still uses it.

The saved scan checks configuration only; it does not prove live access controls,
version recovery, or log delivery. The README includes manual tests for those.
