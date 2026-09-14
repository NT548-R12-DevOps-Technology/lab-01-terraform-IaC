terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = var.public_key

  tags = merge(
    var.tags,
    {
      Name = var.key_name
    }
  )
}

resource "aws_instance" "public" {
  #checkov:skip=CKV_AWS_88: This instance is the bastion host and requires a public IPv4 address for restricted SSH access.
  #checkov:skip=CKV2_AWS_41: The lab instances do not call AWS APIs, so an IAM instance profile is unnecessary.
  count = var.public_instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.public_sg_id]
  associate_public_ip_address = true
  ebs_optimized               = true
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-public-root-${count.index + 1}"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-ec2-${count.index + 1}"
    }
  )
}

resource "aws_instance" "private" {
  #checkov:skip=CKV2_AWS_41: The lab instances do not call AWS APIs, so an IAM instance profile is unnecessary.
  count = var.private_instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.private_sg_id]
  associate_public_ip_address = false
  ebs_optimized               = true
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-private-root-${count.index + 1}"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-ec2-${count.index + 1}"
    }
  )
}

# Preserve the existing public instance when introducing count.
moved {
  from = aws_instance.public
  to   = aws_instance.public[0]
}

# Preserve the existing private instance when introducing count.
moved {
  from = aws_instance.private
  to   = aws_instance.private[0]
}
