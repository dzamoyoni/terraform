# 🗄️ Backend Configuration - Database Layer
# Region: US-East-1 | Environment: Production
# CRITICAL: This file configures access to protected Terraform state

bucket         = "us-east-1-cluster-01-terraform-state"
key            = "regions/us-east-1/layers/03-databases/production/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "us-east-1-cluster-01-terraform-locks"
encrypt        = true

# Security Features:
# - S3 bucket versioning enabled with MFA delete
# - DynamoDB table has deletion protection
# - All access requires HTTPS
# - CloudTrail audit logging enabled
# - Cross-region replication for disaster recovery

# Layer Dependencies:
# - Foundation Layer: VPC, subnets, security groups
# - Platform Layer: EKS cluster information
# Integration via remote state and SSM parameters
