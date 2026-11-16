terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "Region for the demo."
  type        = string
  default     = "us-east-2"
}

resource "aws_s3_bucket" "demo" {
  # checkov:skip=CKV_AWS_144:Regional replication is outside this lab.
  # checkov:skip=CKV2_AWS_62:No event consumer is configured for this lab.
  bucket_prefix = "northstar-files-"
  # Disposable lab only: destroy also deletes stored objects and versions.
  force_destroy = true
  tags = {
    Project     = "s3-security-baseline"
    Company     = "Northstar Demo"
    Environment = "lab"
  }
}

# Public access and ownership
resource "aws_s3_bucket_public_access_block" "secure" {
  bucket                  = aws_s3_bucket.demo.id
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
# Versioning and encryption
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
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

# Retention
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

# Require HTTPS, TLS 1.2+, and uploads encrypted with the project key
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.demo.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.demo.arn, "${aws_s3_bucket.demo.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      },
      {
        Sid       = "DenyOldTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.demo.arn, "${aws_s3_bucket.demo.arn}/*"]
        Condition = {
          NumericLessThan = { "s3:TlsVersion" = "1.2" }
          Bool            = { "aws:PrincipalIsAWSService" = "false" }
        }
      },
      {
        Sid       = "RequireKMSUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.demo.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
        }
      },
      {
        Sid       = "RequireApprovedKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.demo.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.data.arn }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.secure]
}
# Key management
resource "aws_kms_key" "data" {
  description             = "Northstar demo file encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  # Let approved IAM policies in this account grant access to this key.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountIAMPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

data "aws_caller_identity" "current" {}

# Logging
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
  bucket_prefix = "northstar-logs-"
  force_destroy = true

  # S3 server-access-log destinations use SSE-S3 and must not log to themselves.
  # checkov:skip=CKV_AWS_145:SSE-S3 is required for this S3 access-log destination.
  # checkov:skip=CKV_AWS_18:Do not enable recursive server access logging; log-bucket access auditing is outside this lab.
  # checkov:skip=CKV_AWS_144:Log replication is outside this lab.
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
