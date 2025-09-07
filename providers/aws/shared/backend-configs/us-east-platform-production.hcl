# 🔒 Backend configuration for Platform Layer - US-East-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "us-east-1-cluster-01-terraform-state"
key            = "regions/us-east-1/layers/02-platform/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "us-east-1-cluster-01-terraform-locks"
encrypt        = true

# Security Notes:
# - S3 bucket has deletion protection enabled
# - DynamoDB table has deletion protection enabled
# - All access requires HTTPS
# - Full audit logging enabled

# Platform layer state management
# This contains the EKS cluster and shared platform services
# that depend on foundation layer through SSM parameters
