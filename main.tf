terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Lowercase name prefix; keep short enough for the region, account and deployment suffix"
  type        = string
  default     = "cloud-security-lab-demo"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$", var.bucket_prefix))
    error_message = "Use 3-24 lowercase letters, digits or hyphens; start and end with a letter or digit."
  }
}

variable "deployment_id" {
  description = "Short identifier that distinguishes deployments in the same account and region"
  type        = string
  default     = "demo"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,10}[a-z0-9]$", var.deployment_id))
    error_message = "Use 2-12 lowercase letters, digits or hyphens; start and end with a letter or digit."
  }
}

variable "workload_role_name" {
  description = "Existing same-account role to receive the data policy; null leaves it unattached"
  type        = string
  default     = null
}

variable "tags" {
  description = "Default tags for resources that support tagging"
  type        = map(string)
  default = {
    Project     = "s3-security-baseline"
    Environment = "demo"
    Owner       = "security-consulting"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  data_bucket = "${var.bucket_prefix}-${var.region}-${data.aws_caller_identity.current.account_id}-${var.deployment_id}"
  logs_bucket = "${local.data_bucket}-logs"
}

resource "aws_kms_key" "data" {
  description             = "CMK for the S3 data bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # Allow account IAM policies to delegate access; workload permissions are below.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIAMPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "data" {
  name          = "alias/${local.data_bucket}"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_s3_bucket" "demo" {
  bucket        = local.data_bucket
  force_destroy = false

  # Lab exceptions. Revisit recovery and event processing before client use.
  # checkov:skip=CKV_AWS_144:No replication in this lab; recovery design requires client approval.
  # checkov:skip=CKV2_AWS_62:No event consumer in this lab; audit logging is a separate requirement.
  lifecycle {
    precondition {
      condition     = length(local.logs_bucket) <= 63
      error_message = "Shorten bucket_prefix or deployment_id so both bucket names fit the 63-character limit."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "secure" {
  bucket = aws_s3_bucket.demo.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secure" {
  bucket = aws_s3_bucket.demo.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.secure]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true
  }
}

# Writers must send SSE-KMS and the full key ARN; defaults alone allow overrides.
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.demo.arn,
          "${aws_s3_bucket.demo.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      },
      {
        Sid       = "RequireKMS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.demo.arn}/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      },
      {
        Sid       = "RequireApprovedKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.demo.arn}/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.data.arn } }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.secure]
}

resource "aws_s3_bucket_logging" "secure" {
  bucket        = aws_s3_bucket.demo.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_ownership_controls.logs,
    aws_s3_bucket_server_side_encryption_configuration.logs,
  ]
}

resource "aws_s3_bucket" "logs" {
  bucket        = local.logs_bucket
  force_destroy = false

  # S3 server-access-log destinations use SSE-S3 and must not log to themselves.
  # checkov:skip=CKV_AWS_145:SSE-S3 is required for this S3 access-log destination.
  # checkov:skip=CKV_AWS_18:Do not enable recursive server access logging; use centralized CloudTrail for log access.
  # checkov:skip=CKV_AWS_144:No log replication in this lab; agree on evidence retention and recovery before client use.
  # checkov:skip=CKV2_AWS_62:No log event consumer in this lab.

}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ServerAccessLogs"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/s3-access/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.demo.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

resource "aws_iam_policy" "workload" {
  name_prefix = "s3-baseline-${var.deployment_id}-"
  description = "Read and write baseline data without delete or key-administration access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.demo.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = "${aws_s3_bucket.demo.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = aws_kms_key.data.arn
        Condition = {
          StringEquals = { "kms:ViaService" = "s3.${var.region}.${data.aws_partition.current.dns_suffix}" }
          # Bucket Keys use the bucket ARN; objects without them use object ARNs.
          StringLike = { "kms:EncryptionContext:aws:s3:arn" = [aws_s3_bucket.demo.arn, "${aws_s3_bucket.demo.arn}/*"] }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "workload" {
  count      = var.workload_role_name == null ? 0 : 1
  role       = var.workload_role_name
  policy_arn = aws_iam_policy.workload.arn
}
