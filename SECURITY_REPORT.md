# Security notes

## Scope

This is one S3 remediation demo for a pretend company. It supports a discussion of selected security requirements. It does not establish NIST compliance, CMMC certification, or approval to store CUI.

The reference is **NIST SP 800-171**, not 800-71. CMMC Level 2 uses the 110 requirements in SP 800-171 Rev. 2, even though NIST has published Rev. 3. These are illustrative mappings to Rev. 2:

| Area | Related requirement | What this demo shows | What remains |
|---|---|---|---|
| Access | 3.1.1, 3.1.2 | Public-access blocks; ACLs disabled | Approved users, role permissions, MFA and access review |
| Transport | 3.13.8 | Deny HTTP and TLS below 1.2 | Endpoint, client, certificate and cipher evidence |
| Data at rest | 3.13.16 | KMS default encryption; reject uploads without KMS headers | Verify objects, data scope and effective permissions |
| Cryptography | 3.13.11 | Uses AWS KMS for server-side encryption | Confirm applicable FIPS-validated modules and endpoints; KMS alone is not proof |
| Audit | 3.3.1 | No object access audit trail configured | Add appropriate CloudTrail S3 data events or protected access logs and a review process |

SP 800-52 Rev. 2 covers TLS configuration, including TLS 1.2 with FIPS-based cipher suites and TLS 1.3 support. This bucket policy enforces a TLS minimum; it cannot configure or prove every TLS requirement. No complete 800-52 conformance claim is made.

## Remaining decisions

- Logging is the first extension for a customer requiring access evidence. Account-level CloudTrail management events alone do not log all object reads/writes.
- Replication needs a recovery requirement and budget. Versioning is not an immutable backup.
- Notifications need a defined consumer; enabling notifications alone does not create monitoring.
- The 30-day old-version deletion period is only a demo choice. Confirm retention before client use.

These three gaps remain visible in Checkov rather than being described as fixed. A before bucket without explicit controls is not evidence that it was publicly exposed or unencrypted; AWS service defaults also apply.

## Sources

- [NIST SP 800-52 Rev. 2](https://csrc.nist.gov/pubs/sp/800/52/r2/final)
- [NIST SP 800-171 Rev. 2](https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final)
- [DoD CMMC overview](https://dodcio.defense.gov/CMMC/About/)
- [AWS TLS bucket policy examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
