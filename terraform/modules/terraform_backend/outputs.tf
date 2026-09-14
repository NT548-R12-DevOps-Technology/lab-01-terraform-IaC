output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.lock.name
}
