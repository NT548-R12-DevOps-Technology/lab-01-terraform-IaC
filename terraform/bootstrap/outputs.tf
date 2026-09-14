output "state_bucket_name" {
  description = "S3 bucket name used by the dev Terraform backend."
  value       = module.terraform_backend.state_bucket_name
}

output "lock_table_name" {
  description = "DynamoDB table name used to lock the dev Terraform state."
  value       = module.terraform_backend.lock_table_name
}
