# Security notes

## What changed

The main fixes are log-destination setup order, partition-aware KMS policy ARNs, distinct deployment names, explicit approved-key enforcement on uploads, and a scoped workload policy. HTTPS denies exclude AWS service principals to avoid blocking service-to-service calls with redacted network context. The existing public-access, ownership, versioning and lifecycle resources are retained.

Comments in main.tf explain decisions and exceptions. Control mappings belong here so they can describe partial coverage without cluttering the configuration.

## Checkov exceptions

The six exceptions are scoped to the two bucket resources. They remain visible as skipped checks. They are lab scope decisions, not client-approved risk acceptance or evidence that a CMMC requirement is inapplicable.

| Resource | Check | Reason / follow-up |
|---|---|---|
| Data bucket | CKV_AWS_144 | No replication. Agree on recovery objectives and backup isolation before client use. |
| Data bucket | CKV2_AWS_62 | No notification consumer. Define a response workflow if needed; notifications do not replace auditing. |
| Log bucket | CKV_AWS_145 | S3 server-access-log delivery requires an SSE-S3 destination. |
| Log bucket | CKV_AWS_18 | Avoid recursive server access logging. Centralized CloudTrail should cover access to audit storage. |
| Log bucket | CKV_AWS_144 | No log replication. Evidence preservation and recovery need an approved design. |
| Log bucket | CKV2_AWS_62 | No log notification consumer. |

## CUI and assessment scope

CMMC Level 2 uses SP 800-171 Rev. 2. The relationships below describe technical support, not completed requirements. SP 800-53 references use Rev. 5 terminology and are not a claim of a formal one-to-one crosswalk.

| Implementation | Related controls | Limit |
|---|---|---|
| KMS default and approved-key write policy | SC-28, SC-12, SC-13; 3.13.16, 3.13.10 | Key ownership, recovery and operating procedures still need evidence. |
| Cryptography | 3.13.11 | Collect applicable FIPS module validation and configuration evidence for the actual services, endpoints and clients. KMS configuration alone does not prove this. |
| Public-access blocks and disabled ACLs | AC-3; partial 3.1.1 | Does not establish least privilege, approved CUI flows or the full security boundary. |
| Scoped workload policy | AC-6; partial 3.1.5 | Review role trust, all other policies, grants, boundaries and organization policies. |
| Versioning | Partial CP-9 | Not an isolated backup or protection against a privileged deletion. 3.8.9 concerns backup confidentiality. |
| HTTPS enforcement | SC-8; partial 3.13.8 | Does not establish complete SP 800-52 or FIPS compliance. |
| Server access logs | Partial AU-2, AU-12; 3.3.1 | Best-effort delivery. Event selection, retention, protection, review and alerting are separate. |

Before any client CUI is uploaded, verify the approved cloud service offering and region, applicable DFARS obligations, shared responsibilities, system boundary and assessment evidence. Commercial AWS is not automatically disallowed, and choosing GovCloud alone does not establish compliance. The code handles partition-specific ARNs but has not been deployed or tested in either partition.

## Remaining operational work

- Identify the owners of access approval, key administration, monitoring, incident response and evidence preservation. The KMS policy enables account IAM delegation; other account policies can widen access. Administrators who can change the key policy can grant themselves data access.
- Configure or document inherited CloudTrail management and relevant S3 data-event logging. Server access logs are best effort. Bucket Keys also mean there is not a KMS CloudTrail event for every object access.
- Protect audit records against unauthorized modification and deletion. The log bucket has versioning, but no immutable archive. Do not add Object Lock to this S3 server-access-log destination; design a separate supported audit archive if needed.
- Approve lifecycle settings. Data versions become eligible for permanent deletion after 30 noncurrent days. Logs expire as current versions at 90 days, then become eligible for deletion after 30 noncurrent days. Processing is asynchronous; these are not precise deletion deadlines or legal retention guarantees.
- Establish protected recovery copies and test restoration. Existing objects are not re-encrypted by changing bucket defaults. SDK uploads and copies must supply the required encryption headers.
- Restrict the Terraform provisioning role, protect state, and review plans. Changing names can replace buckets; key deletion makes retained ciphertext unrecoverable after the waiting period.

## Evidence

Original scan text is preserved at the project root. The reviewed main.tf is in `evidence/reviewed-main.tf.example`; fresh static scan output and a summary are in `evidence/`. Local validation does not establish that AWS accepted the policies or that log delivery works. No AWS plan/apply or hosted GitHub Actions result is claimed.

## References

- [AWS log destination requirements](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [AWS service-principal exclusions for network denies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
- [AWS KMS account delegation](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html)
- [AWS Bucket Keys and audit behavior](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [DoD CMMC overview](https://business.defense.gov/Cyber/)
- [NIST SP 800-171 Rev. 2](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-171r2.pdf)
- [NIST SP 800-53 Rev. 5](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)
- [DFARS 252.204-7012](https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.)
- [AWS KMS pricing](https://aws.amazon.com/kms/pricing/)
