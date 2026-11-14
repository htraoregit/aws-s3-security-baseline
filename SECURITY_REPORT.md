# Security review

## Local results

| Configuration | Passed | Failed | Skipped |
|---|---:|---:|---:|
| Previous single-bucket demo | 16 | 3 | 0 |
| Current two-bucket demo | 36 | 0 | 6 |

Both scans used Checkov 3.4.3. Resource counts and exceptions differ, so these totals are not a security score. The current scan is saved in `after-scan.txt`; the old numbers describe the previous version, not a separate before fixture in this repository.

## Exceptions, in priority order

1. **Audit coverage:** The file bucket has access logging. The log bucket does not log to itself (`CKV_AWS_18`); its own access still needs a separate audit design. S3 access-log delivery is best effort, not a complete audit trail.
2. **Recovery:** Neither bucket has cross-region replication (`CKV_AWS_144`, two exceptions). Versioning is not an immutable backup.
3. **Log encryption:** The log bucket uses SSE-S3 instead of KMS (`CKV_AWS_145`), as required for this S3 server-access-log destination.
4. **Events:** Neither bucket has event notifications (`CKV2_AWS_62`, two exceptions). No event consumer is part of this demo.

These six resource-specific skips are visible in the Terraform comments and scan output. They are lab decisions, not approved customer exceptions.

## Verified vs. pending

**Verified locally:** Terraform formatting and schema validation; Checkov scan. The workflow is configured to repeat these checks; a hosted run is not asserted here.

**Pending in AWS:** Deployment; authorized upload/download; denial of missing encryption headers and wrong keys; anonymous-access rejection; version recovery; actual log delivery. The provisioning and test identities need suitable S3 and KMS permissions; this project creates no workload role or IAM policy.

The key policy allows account IAM policies to grant key access. It does not automatically authorize every employee. This lab assumes a commercial AWS partition and makes no full NIST/CMMC compliance claim.

Replacing an existing AWS-managed encryption default does not re-encrypt old objects. Review the plan and existing data before applying. Both buckets permit destructive cleanup for sample data; KMS deletion is scheduled for 30 days later.

[AWS server access logging requirements and limitations](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html)
