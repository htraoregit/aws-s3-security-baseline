terraform {
  required_version = ">= 1.5"
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
  description = "Prefix for the data bucket name; the account ID is appended so the name is globally unique"
  type        = string
  default     = "cloud-security-lab-demo"
}

variable "tags" {
  description = "Tags applied to every resource"
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

locals {
  data_bucket = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}"
  logs_bucket = "${var.bucket_prefix}-logs-${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------
# CONTROL 1: Customer-managed KMS key (encryption at rest)
# NIST 800-53 SC-28, SC-12, SC-13 | 800-171 3.13.16, 3.13.10, 3.13.11
# Why a CMK instead of the default AWS-managed key: we control the key
# policy, rotation, and can audit every use of the key in CloudTrail.
# Cost: ~$1/month per key plus request charges.
# ---------------------------------------------------------------
resource "aws_kms_key" "data" {
  description             = "CMK for the S3 data bucket"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # Explicit key policy: account root delegates access to IAM, so IAM
  # policies decide who can use the key. Tighten to named roles for a client.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIAMPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "data" {
  name          = "alias/s3-security-baseline-data"
  target_key_id = aws_kms_key.data.key_id
}

# ---------------------------------------------------------------
# Data bucket
# ---------------------------------------------------------------
resource "aws_s3_bucket" "demo" {
  bucket = local.data_bucket

  # checkov:skip=CKV_AWS_144:Cross-region replication is a resilience/DR requirement, not confidentiality. Adds cost and data-residency impact; enable only if the client states an RTO/RPO that needs it.
  # checkov:skip=CKV2_AWS_62:Event notifications support workflow automation, not baseline security. Not required for this workload.
}

# CONTROL 2: Block all public access
# NIST 800-53 AC-3, AC-6, SC-7 | 800-171 3.1.1, 3.1.3
resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CONTROL 3: Disable ACLs; the bucket owner owns every object
# NIST 800-53 AC-3 | 800-171 3.1.1
resource "aws_s3_bucket_ownership_controls" "secure" {
  bucket = aws_s3_bucket.demo.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CONTROL 4: Versioning (recovery from overwrite/deletion)
# NIST 800-53 CP-9 | 800-171 (limited coverage)
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CONTROL 5: Lifecycle (cost control; note 30 days limits recoverability)
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

# CONTROL 6: Encrypt with the customer-managed key
resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true # cuts KMS request cost
  }
}

# CONTROL 7: Require TLS for every request
# NIST 800-53 SC-8, SC-13 (config guidance: SP 800-52) | 800-171 3.13.8
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.demo.arn,
        "${aws_s3_bucket.demo.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.secure]
}

# CONTROL 8: Server access logging to a separate bucket
# NIST 800-53 AU-2, AU-12 | 800-171 3.3.1
resource "aws_s3_bucket_logging" "secure" {
  bucket        = aws_s3_bucket.demo.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
}

# ---------------------------------------------------------------
# Log bucket (hardened separately)
# ---------------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket

  # checkov:skip=CKV_AWS_145:S3 server access log delivery does not support SSE-KMS target buckets; SSE-S3 (AES256) is used instead.
  # checkov:skip=CKV_AWS_18:Logging the log bucket would recurse. Not required.
  # checkov:skip=CKV_AWS_144:Replication not required for access logs in this scope.
  # checkov:skip=CKV2_AWS_62:Event notifications not required for access logs.
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
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}
