terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11: VPC Flow Logs are outside the scope of this introductory networking lab.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# AWS creates this Security Group with every VPC. Managing it here adopts the
# existing group and removes its default self-ingress and allow-all egress rules.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress = []
  egress  = []

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-default-sg"
    }
  )
}

# EC2 instances use the dedicated Security Groups from the security module,
# never this restricted default Security Group.
