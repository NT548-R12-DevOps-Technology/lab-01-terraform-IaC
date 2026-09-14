variable "name_prefix" {
  description = "Resource name prefix, normally project_name-environment."
  type        = string
}

variable "public_subnet_id" {
  description = "Subnet ID for the public bastion host."
  type        = string
}

variable "private_subnet_id" {
  description = "Subnet ID for the private EC2 instance."
  type        = string
}

variable "public_sg_id" {
  description = "Security Group ID attached to the bastion host."
  type        = string
}

variable "private_sg_id" {
  description = "Security Group ID attached to the private EC2 instance."
  type        = string
}

variable "ami_id" {
  description = "Linux AMI ID in the provider Region, compatible with instance_type and IMDSv2."
  type        = string

  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID."
  }
}

variable "public_instance_count" {
  description = "Number of public EC2 instances."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.public_instance_count >= 0 && floor(var.public_instance_count) == var.public_instance_count
    error_message = "public_instance_count must be a non-negative integer."
  }
}

variable "private_instance_count" {
  description = "Number of private EC2 instances."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.private_instance_count >= 0 && floor(var.private_instance_count) == var.private_instance_count
    error_message = "private_instance_count must be a non-negative integer."
  }
}

variable "instance_type" {
  description = "EC2 instance type used for both instances."
  type        = string
  default     = "t3.micro"
  nullable    = false
}

variable "key_name" {
  description = "Name assigned to the EC2 Key Pair created from the local public key."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must not be empty."
  }
}

variable "public_key" {
  description = "OpenSSH public key material imported into EC2; never pass the private key."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521)) ", trimspace(var.public_key)))
    error_message = "public_key must contain a supported OpenSSH public key."
  }
}

variable "tags" {
  description = "Common tags applied to instances and their root volumes."
  type        = map(string)
  default     = {}
}
