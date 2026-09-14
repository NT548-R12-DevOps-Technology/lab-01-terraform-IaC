locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "TerraformStateBackend"
  }
}

# Apply this root module once before initializing the dev environment.
module "terraform_backend" {
  source = "../modules/terraform_backend"

  state_bucket_name = var.state_bucket_name
  lock_table_name   = "${local.name_prefix}-terraform-lock"
  tags              = local.common_tags
}
