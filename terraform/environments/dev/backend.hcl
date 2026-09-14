# Copy this file to backend.hcl after terraform/bootstrap has been applied.
# Replace the bucket and DynamoDB table with the bootstrap outputs.

bucket         = "lab-01-terraform-state-154370341987-20260914"
key            = "lab-01/dev/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "terraform-aws-lab-dev-terraform-lock"
encrypt        = true
