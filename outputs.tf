output "bucket_name" {
  description = "Use this name in the AWS checks."
  value       = aws_s3_bucket.demo.id
}
