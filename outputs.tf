output "bucket_name" {
  value = aws_s3_bucket.demo.id
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "kms_key_arn" {
  value = aws_kms_key.data.arn
}
