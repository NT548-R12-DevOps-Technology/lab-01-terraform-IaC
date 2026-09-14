variable "aws_region" {
  description = "AWS Region in which the backend resources are created."
  type        = string
  default     = "ap-southeast-1"
  nullable    = false
}

variable "project_name" {
  description = "Project name used in backend resource names and tags."
  type        = string
  default     = "terraform-aws-lab"
  nullable    = false
}

variable "environment" {
  description = "Environment name used in backend resource names and tags."
  type        = string
  default     = "dev"
  nullable    = false
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used to store Terraform state."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be 3-63 lowercase characters using letters, digits, dots or hyphens."
  }
}
