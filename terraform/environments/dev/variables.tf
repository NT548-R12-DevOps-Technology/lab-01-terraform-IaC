variable "aws_region" {
  description = "AWS Region in which to deploy the lab."
  type        = string
  default     = "ap-southeast-1"
  nullable    = false
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "terraform-aws-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.project_name))
    error_message = "Use 1-40 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.environment))
    error_message = "Use 1-20 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC; AWS supports prefix lengths from /16 to /28."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "public_subnet_cidr" {
  description = "Public subnet IPv4 CIDR, inside the VPC and not overlapping the private subnet."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "private_subnet_cidr" {
  description = "Private subnet IPv4 CIDR, inside the VPC and not overlapping the public subnet."
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "availability_zone" {
  description = "Single Availability Zone for both subnets; must belong to aws_region."
  type        = string
  default     = "ap-southeast-1a"
  nullable    = false
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
  description = "EC2 instance type for both hosts; its architecture must match the AMI."
  type        = string
  default     = "t3.micro"
  nullable    = false
}

variable "ami_id" {
  description = "Existing Linux AMI ID in aws_region, compatible with instance_type and IMDSv2."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "Replace ami_id with a valid AMI ID, for example ami- followed by 17 hexadecimal characters."
  }
}

variable "key_name" {
  description = "Name used when Terraform imports the local public key into EC2."
  type        = string
  default     = "lab_key"
  nullable    = false

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must not be empty."
  }
}

variable "public_key_path" {
  description = "Path from the lab root to the locally generated SSH public key."
  type        = string
  nullable    = false
}

variable "allowed_ssh_cidr" {
  description = "Trusted public IPv4 CIDR allowed to SSH to the bastion; use your current public IP/32."
  type        = string
  nullable    = false

  validation {
    condition     = try(cidrnetmask(var.allowed_ssh_cidr) != "0.0.0.0", false)
    error_message = "allowed_ssh_cidr must be a valid IPv4 CIDR; /0 is forbidden. Use YOUR_PUBLIC_IP/32."
  }
}
