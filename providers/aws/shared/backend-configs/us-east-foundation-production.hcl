# 🔒 Backend configuration for Foundation Layer - US-East-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "us-east-1-cluster-01-terraform-state"
key            = "regions/us-east-1/layers/01-foundation/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "us-east-1-cluster-01-terraform-locks"
encrypt        = true

# Security Notes:
# - S3 bucket has deletion protection enabled
# - DynamoDB table has deletion protection enabled
# - All access requires HTTPS
# - Full audit logging enabled

# Foundation layer state management
# This contains the core VPC, networking, and security group infrastructure
# that other layers depend on through SSM parameters
