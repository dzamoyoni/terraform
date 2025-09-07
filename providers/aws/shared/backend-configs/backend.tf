# Global Backend Configuration
# This file should be copied to each regional deployment

terraform {
  backend "s3" {
    # Update these values for your specific setup
    bucket         = "your-terraform-state-bucket"
    key            = "terraform.tfstate" # This will be overridden in regional configs
    region         = "af-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    # Optional: Use profiles or IAM roles
    # profile = "your-aws-profile"
  }
}

# S3 Bucket for Terraform State (optional - create this separately)
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "your-company-terraform-state-${random_id.bucket_suffix.hex}"
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# # DynamoDB table for state locking
# resource "aws_dynamodb_table" "terraform_state_lock" {
#   name           = "terraform-state-lock"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   tags = {
#     Name        = "Terraform State Lock Table"
#     Environment = "global"
#   }
# }

# Random suffix for unique bucket names
# resource "random_id" "bucket_suffix" {
#   byte_length = 4
# }
