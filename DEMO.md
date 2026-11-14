# Deploy and show it working

Run these PowerShell commands from `C:\Users\apote\cloud-security-s3\aws-s3-security-baseline`. Install AWS CLI v2 first. Use only a lab account and sample data. Stop after any unexpected error.

## 1. Sign in and deploy

Configure your actual organization-provided SSO details. If your account does not use SSO, ask the account owner for an approved temporary-credential method; never deploy as root or put access keys in code.

```powershell
aws configure sso --profile s3-demo
aws sso login --profile s3-demo
$env:AWS_PROFILE = "s3-demo"
aws sts get-caller-identity
terraform init -input=false -lockfile=readonly
terraform plan -out=deploy.tfplan
terraform show -no-color deploy.tfplan
```

Confirm the account and region. For a fresh demo, the plan should create one bucket and its settings, with no IAM or custom KMS resources. If it deletes or replaces existing resources, stop and review the old state and data first. The deployment role needs S3 configuration/policy permissions; uploading and reading also need the relevant S3 and AWS-managed KMS permissions. Existing organization policies can restrict these.

After reviewing the plan and costs:

```powershell
terraform apply deploy.tfplan
$bucket = terraform output -raw bucket_name
```

## 2. Show the controls

```powershell
aws s3api get-public-access-block --bucket $bucket
aws s3api get-bucket-ownership-controls --bucket $bucket
aws s3api get-bucket-encryption --bucket $bucket
aws s3api get-bucket-versioning --bucket $bucket
aws s3api get-bucket-lifecycle-configuration --bucket $bucket
aws s3api get-bucket-policy --bucket $bucket --query Policy --output text
```

Capture the outputs or console screenshots: four public blocks enabled, ACLs disabled, KMS encryption, versioning enabled, cleanup rules and the three deny statements. This inspects configuration; it does not prove lifecycle deletion or every TLS behavior has executed.

## 3. Upload, download and recover

```powershell
Set-Content sample.txt "Northstar demo - first version"
$first = aws s3api put-object --bucket $bucket --key demo/sample.txt --body sample.txt --server-side-encryption aws:kms | ConvertFrom-Json
aws s3api head-object --bucket $bucket --key demo/sample.txt
aws s3api get-object --bucket $bucket --key demo/sample.txt downloaded.txt
Get-Content downloaded.txt

Set-Content sample.txt "Northstar demo - second version"
aws s3api put-object --bucket $bucket --key demo/sample.txt --body sample.txt --server-side-encryption aws:kms
aws s3api list-object-versions --bucket $bucket --prefix demo/sample.txt
aws s3api get-object --bucket $bucket --key demo/sample.txt --version-id $first.VersionId recovered.txt
Get-Content recovered.txt
```

Expected: the object reports `aws:kms`, a KMS key ID and a version ID. The download matches the first text, and recovery returns the first text after the second upload. Save actual outputs. The uploader must send KMS headers because the bucket policy deliberately rejects missing headers.

## 4. Show denied requests

Using the same signed-in identity that successfully uploaded above:

```powershell
aws s3api put-object --bucket $bucket --key demo/rejected.txt --body sample.txt
aws s3api put-object --bucket $bucket --key demo/rejected.txt --body sample.txt --server-side-encryption AES256
aws s3api get-object --bucket $bucket --key demo/sample.txt anonymous.txt --no-sign-request
```

All three should fail. Record the identity, command and error, and investigate any unexpected success. The first two test the encryption requirement against a known working uploader. The anonymous denial demonstrates that this object is not publicly readable; it does not by itself isolate every access control.

## 5. Explain the result

Show the original bucket, Checkov findings, Terraform changes, then the AWS results. Explain why each control exists and name the remaining gaps: object access logging, regional recovery, and event processing. Use the limited standards mapping in `SECURITY_REPORT.md`; do not claim a CMMC certification.

Mark the project **deployed and tested** only after these commands actually succeed in AWS. Until then, report **locally validated; AWS test pending**. Never use a hypothetical output as evidence.

## 6. Clean up

Confirm the account and preserve any required evidence. In the S3 console, empty the demo bucket, including **all versions and delete markers**, and abort unfinished multipart uploads. This permanently removes the sample data. `aws s3 rm --recursive` alone does not empty a versioned bucket.

```powershell
aws sts get-caller-identity
terraform plan -destroy -out=destroy.tfplan
terraform show -no-color destroy.tfplan
terraform apply destroy.tfplan
```

Verify removal in AWS. `force_destroy=false` intentionally prevents Terraform from silently deleting a nonempty bucket. No customer-managed KMS key is created by this simplified demo.
