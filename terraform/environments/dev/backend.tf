# Backend values are supplied by terraform init -backend-config in local setup
# and GitHub Actions. This avoids hard-coding account-specific resource names.
terraform {
  backend "s3" {}
}
