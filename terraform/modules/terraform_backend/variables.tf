variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used to store Terraform state."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be 3-63 lowercase characters using letters, digits, dots or hyphens."
  }
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Common tags applied to backend resources."
  type        = map(string)
  default     = {}
}
