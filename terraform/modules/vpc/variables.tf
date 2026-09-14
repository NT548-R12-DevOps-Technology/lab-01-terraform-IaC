variable "name_prefix" {
  description = "Resource name prefix, normally project_name-environment."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of the VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/(1[6-9]|2[0-8])$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR with a prefix from /16 to /28."
  }
}

variable "tags" {
  description = "Common tags applied to resources in this module."
  type        = map(string)
  default     = {}
}
