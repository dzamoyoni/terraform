# 🗃️ Backend configuration for Database Layer (Alt) - US-East-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "us-east-1-cluster-01-terraform-state"
key            = "regions/us-east-1/layers/04-database-layer/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "us-east-1-cluster-01-terraform-locks"
encrypt        = true

# Security Notes:
# - S3 bucket has deletion protection enabled
# - DynamoDB table has deletion protection enabled
# - All access requires HTTPS
# - Full audit logging enabled

# Alternative database layer state management
# This contains additional database resources and configurations
# that depend on foundation layer through SSM parameters
