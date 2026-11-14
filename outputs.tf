output "bucket_name" {
  value = aws_s3_bucket.demo.id
}

output "logs_bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "kms_key_arn" {
  value = aws_kms_key.data.arn
}

output "workload_policy_arn" {
  value = aws_iam_policy.workload.arn
}
