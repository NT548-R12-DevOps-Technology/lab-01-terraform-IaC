resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18: Access logs would require a second logging bucket; this single-purpose lab state bucket has no application traffic.
  #checkov:skip=CKV2_AWS_61: State versioning provides recovery; lifecycle retention rules are outside this short-lived lab's scope.
  #checkov:skip=CKV2_AWS_62: Terraform state does not publish application events, so S3 event notifications are unnecessary.
  #checkov:skip=CKV_AWS_144: Cross-region replication is outside the scope and budget of this single-region lab.
  #checkov:skip=CKV_AWS_145: AES256 server-side encryption is sufficient for this lab; a customer-managed KMS key is not required.
  bucket = var.state_bucket_name

  tags = merge(
    var.tags,
    {
      Name = var.state_bucket_name
    }
  )
}

# Retain previous state versions to recover from an accidental state update.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest with Amazon S3 managed encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Terraform state must never be publicly accessible.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Terraform uses the LockID attribute to prevent concurrent state changes.
resource "aws_dynamodb_table" "lock" {
  #checkov:skip=CKV_AWS_119: The lock table uses AWS-managed server-side encryption; a customer-managed KMS key is outside this lab's scope.
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.lock_table_name
    }
  )
}
