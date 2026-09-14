locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  tags                = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  tags             = local.common_tags
}

module "ec2" {
  source = "../../modules/ec2"

  name_prefix            = local.name_prefix
  public_instance_count  = var.public_instance_count
  private_instance_count = var.private_instance_count
  public_subnet_id       = module.networking.public_subnet_id
  private_subnet_id      = module.networking.private_subnet_id
  public_sg_id           = module.security.public_sg_id
  private_sg_id          = module.security.private_sg_id
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  public_key             = file(abspath("${path.root}/../../../${var.public_key_path}"))
  tags                   = local.common_tags
}
