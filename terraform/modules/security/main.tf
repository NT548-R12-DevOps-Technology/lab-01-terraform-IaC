terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_security_group" "public" {
  #checkov:skip=CKV2_AWS_5: Attached to public EC2 through the public_sg_id module input; Checkov cannot resolve this module boundary.
  #checkov:skip=CKV_AWS_24: allowed_ssh_cidr is validated in the environment root and rejects 0.0.0.0/0.
  name        = "${var.name_prefix}-public-sg"
  description = "Bastion SSH access from the trusted administrator CIDR"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-sg"
    }
  )
}

resource "aws_security_group" "private" {
  #checkov:skip=CKV2_AWS_5: Attached to private EC2 through the private_sg_id module input; Checkov cannot resolve this module boundary.
  name        = "${var.name_prefix}-private-sg"
  description = "Private EC2 SSH access from the bastion security group only"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-sg"
    }
  )
}

# Keep rules separate; do not mix these resources with inline SG rules.
resource "aws_vpc_security_group_ingress_rule" "public_ssh" {
  security_group_id = aws_security_group.public.id
  description       = "SSH from the trusted administrator IPv4 CIDR"
  cidr_ipv4         = var.allowed_ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-ssh"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "private_ssh" {
  #checkov:skip=CKV_AWS_24: SSH source is the bastion Security Group, not an IPv4 CIDR or 0.0.0.0/0.
  security_group_id            = aws_security_group.private.id
  description                  = "SSH only from instances using the bastion security group"
  referenced_security_group_id = aws_security_group.public.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-ssh"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "public_all" {
  security_group_id = aws_security_group.public.id
  description       = "Allow all outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-egress"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "private_all" {
  security_group_id = aws_security_group.private.id
  description       = "Allow all outbound IPv4 traffic; Internet traffic uses NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-egress"
    }
  )
}
