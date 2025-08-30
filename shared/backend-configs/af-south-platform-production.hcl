# 🔒 Backend configuration for Platform Layer - AF-South-1 Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "cptwn-terraform-state-ezra"
key            = "layers/platform/af-south-1/production/terraform.tfstate"
region         = "af-south-1"
dynamodb_table = "terraform-locks-af-south"
encrypt        = true

# Security Notes:
# - S3 bucket has deletion protection enabled
# - DynamoDB table has deletion protection enabled
# - All access requires HTTPS
# - Full audit logging enabled
