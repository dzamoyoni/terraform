# =============================================================================
# Backend Configuration: database-layer Layer - af-south-1 production
# =============================================================================
# Auto-generated backend configuration for consistent team usage
# Initialize with: terraform init -backend-config=backend.hcl
# =============================================================================

bucket = "cptwn-terraform-state-ezra"
key    = "providers/aws/regions/af-south-1/layers/04-database-layer/production/terraform.tfstate"
region = "af-south-1"
encrypt = true
dynamodb_table = "terraform-locks-af-south"

# =============================================================================
# Backend Configuration Notes:
# - This file is version controlled for team consistency
# - No user-specific configuration required
# - Works across all platforms (Linux, macOS, Windows)
# - State is stored in S3 with DynamoDB locking
# =============================================================================
