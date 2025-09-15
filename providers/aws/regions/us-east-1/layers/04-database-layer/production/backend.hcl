# =============================================================================
# Backend Configuration: database-layer Layer - us-east-1 production
# =============================================================================
# Auto-generated backend configuration for consistent team usage
# Initialize with: terraform init -backend-config=backend.hcl
# =============================================================================

bucket = "usest1-terraform-state-ezra"
key    = "providers/aws/regions/us-east-1/layers/04-database-layer/production/terraform.tfstate"
region = "us-east-1"
encrypt = true
dynamodb_table = "terraform-locks-us-east-1"

# =============================================================================
# Backend Configuration Notes:
# - This file is version controlled for team consistency
# - No user-specific configuration required
# - Works across all platforms (Linux, macOS, Windows)
# - State is stored in S3 with DynamoDB locking
# =============================================================================
