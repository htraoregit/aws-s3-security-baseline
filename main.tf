# Terraform version and AWS provider requirements
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
# Connect Terraform to AWS in the selected region
provider "aws" {
  region = var.region
}
# Default deployment region: Ohio (us-east-2)
variable "region" {
  description = "Region for the demo."
  type        = string
  default     = "us-east-2"
}

# Create the main bucket for storing company documents
resource "aws_s3_bucket" "demo" {
  # Unique bucket name with Northstar prefix
  bucket_prefix = "northstar-files-"
  # LAB ONLY: allows Terraform to delete all files and versions
  force_destroy = true
  # Labels for identifying and organizing resources
  tags = {
    Project     = "s3-security-baseline"
    Company     = "Northstar Demo"
    Environment = "lab"
  }
}

# Public access and ownership
resource "aws_s3_bucket_public_access_block" "secure" {
  bucket                  = aws_s3_bucket.demo.id
  block_public_acls       = true # Reject new public ACLs
  block_public_policy     = true # Reject new public bucket policies
  ignore_public_acls      = true # Ignore existing public ACLs
  restrict_public_buckets = true # Restrict access with public policies
}

# SECURITY: Disable ACLs; bucket owner controls objects
resource "aws_s3_bucket_ownership_controls" "secure" {
  bucket = aws_s3_bucket.demo.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
# RECOVERY: Preserve previous versions of files
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled" # Recover overwritten or deleted files
  }
} # ENCRYPTION: Protect stored documents with AWS KMS
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

# RETENTION: Automatically clean up old data
resource "aws_s3_bucket_lifecycle_configuration" "secure" {
  bucket = aws_s3_bucket.demo.id
  rule {
    id     = "cleanup-old-versions" # Cleanup rule name
    status = "Enabled"              # Activate cleanup
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30 #Remove old versions after 30 days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Remove abandoned uploads
    }
  }
  depends_on = [aws_s3_bucket_versioning.secure] # Enable versioning first
}

# SECURITY Deny insecure connections and unapproved encryption
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.demo.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # RULE 1: Block HTTP; require encrypted connections
        Sid       = "DenyHTTP"
        Effect    = "Deny" # Explicitly reject matching requests
        Principal = "*"    # Applies to all principals
        Action    = "s3:*" # Covers all S3 actions
        Resource  = [aws_s3_bucket.demo.arn, "${aws_s3_bucket.demo.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false" # Deny requests not using HTTPS
            "aws:PrincipalIsAWSService" = "false" # Exempt direct AWS service calls
          }
        }
      },
      { # RULE 2: Reject outdated TLS protocols
        Sid       = "DenyOldTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.demo.arn, "${aws_s3_bucket.demo.arn}/*"]
        Condition = {
          NumericLessThan = { "s3:TlsVersion" = "1.2" } # Minimum TLS version is 1.2
          Bool            = { "aws:PrincipalIsAWSService" = "false" }
        }
      },

      # RULE 3: Require SSE-KMS on every PutObject request

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
        Sid       = "RequireApprovedKey" # RULE 4: Require our specific approved KMS key
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject" # Applies to object uploads
        Resource  = "${aws_s3_bucket.demo.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.data.arn } # Reject uploads without the required KMS encryption header
        }
      }
    ]
  }) # KMS key creates it, enables rotation, allows key access to be managed through IAM
  depends_on = [aws_s3_bucket_public_access_block.secure]
}
# KEY MANAGEMENT: Create and manage our encryption key
resource "aws_kms_key" "data" {
  description             = "Northstar demo file encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  # Let approved IAM policies in this account grant access to this key.
  policy = jsonencode({ # Allow account IAM policies to manage key permissions
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountIAMPolicies"                                                   # Enable IAM permission delegation
      Effect    = "Allow"                                                                      # Allow matching KMS actions
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" } # All KMS actions, subject to IAM permissions
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}
# AUDITING: Identify the current AWS account
data "aws_caller_identity" "current" {}

# AUDITING: Send document-bucket access logs to a separate bucket
resource "aws_s3_bucket_logging" "secure" {
  bucket        = aws_s3_bucket.demo.id # Bucket being monitored
  target_bucket = aws_s3_bucket.logs.id # Separate logging bucket
  target_prefix = "s3-access/"          # Folder-like log prefix
  depends_on = [                        # Configure log destination before enabling delivery
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_ownership_controls.logs,
    aws_s3_bucket_server_side_encryption_configuration.logs,
  ]
}
# LOG STORAGE: Create dedicated bucket for access records
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "northstar-logs-"
  force_destroy = true

  # S3 server-access-log destinations use SSE-S3 and must not log to themselves.
  # checkov:skip=CKV_AWS_145:SSE-S3 is required for this S3 access-log destination.
  # checkov:skip=CKV_AWS_18:Do not enable recursive server access logging; log-bucket access auditing is outside this lab.
  # checkov:skip=CKV_AWS_144:Log replication is outside this lab.
  # checkov:skip=CKV2_AWS_62:No log event consumer in this lab.
}
# SECURITY: Prevent public exposure of access logs
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true # Block public ACLs
  block_public_policy     = true # Block public policies
  ignore_public_acls      = true # Ignore public ACLs
  restrict_public_buckets = true # Restrict public-policy access
}
# OWNERSHIP: Disable ACLs on the log bucket
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
# RECOVERY: Preserve previous versions of logs
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}
# ENCRYPTION: Encrypt access logs using SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Log retention, 30 days old files, 90 days access logs and 7 days incomplete uploads
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-access-logs" # Log cleanup rule
    status = "Enabled"            # Activate retention

    filter {} # Apply to all log objects

    expiration {
      days = 90 # Expire current logs after 90 days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30 # Delete old log versions
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # Clean up incomplete uploads
    }
  }
  # ACCESS CONTROL: Allow S3 to deliver access logs securely
  depends_on = [aws_s3_bucket_versioning.logs]
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # RULE 1: Permit the AWS S3 logging service
        Sid       = "AllowS3ServerAccessLogs"
        Effect    = "Allow"                                  # Permit matching log delivery
        Principal = { Service = "logging.s3.amazonaws.com" } # AWS logging service
        Action    = "s3:PutObject"                           # Allow writing log objects
        Resource  = "${aws_s3_bucket.logs.arn}/s3-access/*"  # Only log prefix
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.demo.arn }                          # Only accept logs from our document bucket
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } # Restrict log delivery to our AWS account
        }
      },
      { # RULE 2: Reject insecure requests to the logging bucket
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
            "aws:SecureTransport"       = "false" # Deny non-HTTPS requests
            "aws:PrincipalIsAWSService" = "false" # Exempt direct AWS service calls
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}
