terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130: The assignment requires this public subnet to assign public IPv4 addresses for the bastion host.
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-subnet"
    }
  )
}

resource "aws_subnet" "private" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-subnet"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-eip"
    }
  )
}

resource "aws_nat_gateway" "this" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.public.id
  connectivity_type = "public"

  # A public NAT requires an attached IGW, which is not referenced above.
  depends_on = [aws_internet_gateway.this]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-gateway"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-rt"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
