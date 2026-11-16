# Security notes

The goal is simple: keep files private, encrypt them, and keep versions for recovery.

The file bucket rejects HTTP, TLS below 1.2, and uploads that do not specify SSE-KMS with the project key. Access still needs the right S3 and KMS permissions.

## Scan results

[Checkov output](after-scan.txt): **36 passed, 0 failed, 6 skipped.**

The skips are documented in `main.tf`:

- Replication and event notifications are out of scope for both buckets (4 skips).
- The log bucket uses SSE-S3 instead of KMS (1 skip).
- The log bucket does not log to itself (1 skip).

## Limits

Versioning is not a backup: someone with permission can permanently delete versions. Old versions expire after 30 noncurrent days; current logs expire after 90 days.

Access logs are best effort. This lab does not include employee roles, alerts, or CloudTrail. The scan checks configuration, not live AWS behavior.
