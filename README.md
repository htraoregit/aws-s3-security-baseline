# AWS S3 security baseline

This started as a basic bucket and a Checkov scan. It now includes separate data and access-log buckets, public-access blocks, disabled ACLs, versioning, lifecycle rules, HTTPS enforcement, and a customer-managed KMS key for the data bucket.

The data policy requires uploads to specify SSE-KMS and the full key ARN. A separate IAM policy allows data reads and writes, with KMS use limited to this bucket through regional S3. It grants no delete access or key administration. By default, it is not attached to a role.

The log bucket uses SSE-S3 because that is required for this S3 server-access-log destination. Its write permission is limited to S3's logging service for the data bucket and account. Logging waits for that policy and the destination configuration.

## Local checks

Use Terraform 1.17.1 and Python 3.12 to match CI. The configuration accepts Terraform >=1.6,<2 and AWS provider `~> 6.0`; the lock file selects 6.73.0.

```text
python -m pip install -r requirements-dev.txt
terraform init -backend=false -input=false -lockfile=readonly
terraform fmt -check -recursive
terraform validate
python scripts/scan.py
```

These checks need no AWS credentials. Initial tool and provider downloads need internet access. The scan script saves the full report in `evidence/` and fails on any failed check or change to the six documented exceptions. Checkov 3.4.3 matches the project's earlier scans; update it deliberately and review changes to the policy catalog. The workflow runs these checks without deploying anything. A hosted workflow run has not been verified here.

The original `before-scan.txt`, `after-scan.txt`, and `before.tf.example` are historical evidence and remain unchanged. They do not describe the current code. The reviewed main.tf is saved as `evidence/reviewed-main.tf.example`; current results are in `evidence/scan-summary.json`.

## Deploy later

Use an approved lab account and temporary credentials. Confirm the cloud offering, region, contractual requirements, role trust and permissions before using client data. No AWS deployment has been performed for this update.

PowerShell, from this directory:

```powershell
aws configure sso --profile s3-baseline-lab
aws sso login --profile s3-baseline-lab
$env:AWS_PROFILE = "s3-baseline-lab"
aws sts get-caller-identity
terraform init -input=false -lockfile=readonly
terraform plan -var="region=us-east-1" -var="deployment_id=demo" -out=deploy.tfplan
terraform show -no-color deploy.tfplan
terraform apply deploy.tfplan
$bucket = terraform output -raw bucket_name
$logs = terraform output -raw logs_bucket_name
$key = terraform output -raw kms_key_arn
```

Use a different `deployment_id` for each independent deployment. Names include region, account and deployment ID; they can still conflict with an existing bucket. This update changes bucket and alias names. If there is existing state or data, stop on any replacement in the plan and make a migration plan first. Resource addresses are preserved, but naming changes still trigger replacement.

To attach the workload policy through Terraform, include `-var="workload_role_name=YOUR_EXISTING_ROLE"` in the plan after reviewing that role's trust and existing permissions. Otherwise the policy remains unattached. Do not use this workload policy as the provisioning role: provisioning also needs S3 configuration, KMS policy/rotation/alias management and IAM policy management permissions.

State is local by default. Protect it and saved plans; neither belongs in Git. Set up an encrypted remote backend with locking separately before team use. Do not store this stack's state in a bucket it manages.

## AWS acceptance checks

Inspect both buckets' public-access blocks, ownership controls, encryption, versioning, lifecycle and policies. Check KMS rotation and the effective permissions of the workload role.

With a profile assuming the workload role, test a small write and read:

```powershell
Set-Content sample.txt "S3 acceptance test"
aws s3api put-object --bucket $bucket --key acceptance/sample.txt --body sample.txt --server-side-encryption aws:kms --ssekms-key-id $key
aws s3api head-object --bucket $bucket --key acceptance/sample.txt
aws s3api get-object --bucket $bucket --key acceptance/sample.txt downloaded.txt
```

Confirm the key ARN, version ID and downloaded contents. Test that uploads without headers, with AES256, or with another authorized KMS key are denied. Verify anonymous reads and public ACLs are rejected. Overwrite an object and recover its previous version. Test multipart and copy operations with the actual application. Generate requests and confirm logs arrive in the destination; delivery can take hours. Preserve actual outputs and identities used. These are planned tests, not completed results.

## Destroy the lab

Use the same region, deployment ID and optional role variable used for deployment. Confirm the account, preserve required data and evidence, then empty **both** versioned buckets through the S3 console, including all versions and delete markers. Abort any incomplete multipart uploads. A recursive `aws s3 rm` alone is not enough to empty a versioned bucket. Both buckets have `force_destroy=false`.

If the policy was attached outside Terraform, detach it from those identities first. Terraform manages the optional attachment declared here.

```powershell
aws sts get-caller-identity
terraform plan -destroy -var="region=us-east-1" -var="deployment_id=demo" -out=destroy.tfplan
terraform show -no-color destroy.tfplan
terraform apply destroy.tfplan
aws kms describe-key --key-id $key
```

Confirm the buckets are gone and the key is pending deletion. KMS deletion is scheduled for 30 days later. Never discard state to bypass a failed destroy.

## Limits and cost

This is a lab configuration, not a complete CUI enclave or CMMC assessment result. Centralized CloudTrail management and S3 data-event logging, protected audit storage, monitoring, identity controls, recovery testing, and client-approved retention remain prerequisites for production. See [security notes](SECURITY_REPORT.md).

The KMS key has a base cost of roughly $1/month plus requests and possible rotation storage charges. S3 storage, versions, logs and requests also cost money. Bucket Keys reduce KMS traffic. No monthly total is claimed without workload estimates. SSE-S3 can be a simpler option when customer key control is not needed; changing to it requires changing the data upload policy too.
