variable "name_prefix" {
  description = "Resource name prefix, normally project_name-environment."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which both Security Groups are created."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Trusted public IPv4 CIDR for SSH to the bastion; normally YOUR_PUBLIC_IP/32."
  type        = string
  nullable    = false

  validation {
    condition     = try(cidrnetmask(var.allowed_ssh_cidr) != "0.0.0.0", false)
    error_message = "allowed_ssh_cidr must be a valid IPv4 CIDR; /0 is forbidden. Use YOUR_PUBLIC_IP/32."
  }
}

variable "tags" {
  description = "Common tags applied to resources in this module."
  type        = map(string)
  default     = {}
}
