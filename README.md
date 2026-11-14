# S3 security remediation demo

Northstar Demo is a pretend small company that needs a private bucket for internal files. This project starts with the basic bucket in `before.tf.example`, fixes missing controls, and provides a short AWS test. Use sample text only, not customer data or CUI.

## What changed

- Block public access and disable ACLs.
- Enable versioning to recover an overwritten file.
- Use AWS-managed SSE-KMS encryption and require `aws:kms` on uploads.
- Deny HTTP and TLS versions below 1.2.
- Remove old noncurrent versions after 30 days and unfinished uploads after 7 days.

`main.tf` contains the bucket and its controls. `outputs.tf` prints the bucket name. There are no custom keys, roles, or application services to manage. The uploader still needs approved S3 and KMS permissions. Encryption uses the AWS-managed `aws/s3` key when no key is specified; the policy requires KMS but does not restrict writes to one key.

## Check locally

From this folder, using Terraform and Python 3.12:

```powershell
python -m pip install -r requirements-dev.txt
terraform init -backend=false -input=false -lockfile=readonly
terraform fmt -check
terraform validate
python -m checkov.main -d . --framework terraform --skip-download
```

No AWS account is needed for these checks. Downloads need internet access. Checkov reports three remaining findings: access logging (`CKV_AWS_18`), cross-region replication (`CKV_AWS_144`), and notifications (`CKV2_AWS_62`). They remain visible. CI permits only those finding IDs and fails on other findings. They are demo scope decisions, not customer-approved exceptions.

Historical `before-scan.txt` and `after-scan.txt` describe earlier versions. New local check results are under `evidence/`. Local validation does not prove deployment. See [AWS demo steps](DEMO.md) and [security notes](SECURITY_REPORT.md).

## Before deploying

Resolve AWS account/billing access, install AWS CLI v2, and use an approved lab role with temporary credentials. S3 storage, versions, requests, and KMS requests may cost money. No free deployment is promised.

The bucket name now uses a generated prefix. If any resources are already in Terraform state, review the plan carefully: this simplified version removes the previous log bucket, customer-managed key, and workload policy. Do not apply deletions or replacements to existing data. Keep the old key until any data encrypted with it is no longer needed.

Keep state, saved plans, credentials, and real customer data out of Git. This lab uses local state; protect it. A shared deployment needs a separately managed secure remote backend.
