# 🔒 Backend configuration for Client Layer - US-East-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "us-east-1-cluster-01-terraform-state"
key            = "regions/us-east-1/layers/05-client-nodegroups/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "us-east-1-cluster-01-terraform-locks"
encrypt        = true

# Security Notes:
# - S3 bucket has deletion protection enabled
# - DynamoDB table has deletion protection enabled
# - All access requires HTTPS
# - Full audit logging enabled

# Client layer state management
# This contains client-specific infrastructure and depends on
# foundation and platform layers through SSM parameters
