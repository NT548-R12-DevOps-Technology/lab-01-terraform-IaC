variable "name_prefix" {
  description = "Resource name prefix, normally project_name-environment."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC that contains both subnets."
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public IPv4 subnet CIDR inside the VPC, not overlapping the private subnet."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "private_subnet_cidr" {
  description = "Private IPv4 subnet CIDR inside the VPC, not overlapping the public subnet."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "availability_zone" {
  description = "Single Availability Zone used for both subnets."
  type        = string
}

variable "tags" {
  description = "Common tags applied to resources in this module."
  type        = map(string)
  default     = {}
}
