# AWS S3 Security Baseline

A Terraform lab for Northstar, a mock company that needs private document storage.
It creates a file bucket, a separate access-log bucket, and a KMS encryption key.

## How it works

- Both buckets block public access and disable ACLs. Policies control access.
- Documents use a customer-managed KMS key with annual rotation.
- Uploads must specify KMS encryption and the project key.
- Both buckets require HTTPS. The file bucket also requires TLS 1.2 or later.
- Versioning keeps earlier copies of documents. It does not prevent permanent deletion by an authorized administrator.
- S3 sends access logs to the separate bucket, which uses SSE-S3 encryption.
- Lifecycle rules remove old versions after 30 noncurrent days and incomplete uploads after 7 days. Current logs expire after 90 days.

The default region is `us-east-2`. This project creates no IAM roles or access policies for employees.
The identity uploading or reading documents needs suitable S3 and KMS permissions.

## Check the configuration

Install Terraform 1.17.1 and Python 3.12 to match GitHub Actions:

```powershell
python -m pip install -r requirements-dev.txt
terraform init -backend=false -input=false -lockfile=readonly
terraform fmt -check
terraform validate
python -m checkov.main -d . --framework terraform --skip-download
```

GitHub Actions runs these checks without deploying anything.
See [after-scan.txt](after-scan.txt) for the saved scan and [security notes](SECURITY_REPORT.md) for its exceptions.
Local checks do not verify AWS permissions or log delivery.

## Deploy or update

Sign in to your lab account through AWS CLI, then confirm the identity and review the plan:

```powershell
aws sts get-caller-identity
terraform plan -out=deploy.tfplan
terraform show -no-color deploy.tfplan
terraform apply deploy.tfplan
```

Use the existing Terraform state and deployment settings. Review any replacement or deletion before applying.
State files, saved plans, and credentials must stay out of Git. S3 and KMS charges may apply.

## Test with a sample document

```powershell
$bucket = terraform output -raw bucket_name
$key = terraform output -raw kms_key_arn
Set-Content sample.txt 'Northstar test document'
aws s3api put-object --bucket $bucket --key sample.txt --body sample.txt --server-side-encryption aws:kms --ssekms-key-id $key
aws s3api head-object --bucket $bucket --key sample.txt
aws s3api get-object --bucket $bucket --key sample.txt downloaded.txt
Get-Content downloaded.txt
```

Check that each command succeeds and the metadata shows the project key and a version ID.
Then test the controls:

- Upload without the encryption flags: expect `AccessDenied`.
- Download with `--no-sign-request`: expect `AccessDenied`.
- Overwrite the sample, then download its earlier version from the S3 console.
- Look for logs under `s3-access/` in the log bucket. Delivery can take hours and is best effort.

These are testing instructions; live AWS results have not been verified in this cleanup.

## Clean up

**Both buckets have `force_destroy = true`. Destroying the lab permanently deletes their files and versions.**
Use sample data only, and save anything needed before reviewing a destroy plan:

```powershell
terraform plan -destroy -out=destroy.tfplan
terraform show -no-color destroy.tfplan
terraform apply destroy.tfplan
```

The KMS key is scheduled for deletion after 30 days. Keep it while any needed data remains encrypted with it.
