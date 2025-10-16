#!/bin/bash
# =============================================================================
# Backend Configuration Update Script - us-east-2
# =============================================================================
# This script updates all backend.hcl files in the us-east-2 region with
# the correct configuration settings.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION_DIR="$(dirname "$SCRIPT_DIR")"
REGION="us-east-2"
BUCKET="ohio-01-terraform-state-production"
DYNAMODB_TABLE="terraform-locks-us-east-2"

echo "=== Backend Configuration Update Script ==="
echo "Region: $REGION"
echo "Bucket: $BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Define layer configurations
declare -A LAYERS=(
    ["01-foundation"]="Foundation"
    ["02-platform"]="Platform"
    ["03-databases"]="Databases"
    ["03-standalone-compute"]="Standalone Compute"
    ["03.5-observability"]="Observability"
    ["04-database-layer"]="Database Layer"
    ["05-client-nodegroups"]="Client Nodegroups"
    ["06-shared-services"]="Shared Services"
)

# Function to create backend.hcl file
create_backend_config() {
    local layer_dir="$1"
    local layer_name="$2"
    local display_name="$3"
    local backend_file="$layer_dir/backend.hcl"
    
    echo "Updating: $layer_name -> $backend_file"
    
    cat > "$backend_file" << EOF
# =============================================================================
# Backend Configuration: $display_name Layer - $REGION production
# =============================================================================
# Auto-generated backend configuration for consistent team usage
# Initialize with: terraform init -backend-config=backend.hcl
# =============================================================================

bucket = "$BUCKET"
key    = "providers/aws/regions/$REGION/layers/$layer_name/production/terraform.tfstate"
region = "$REGION"
encrypt = true
dynamodb_table = "$DYNAMODB_TABLE"

# =============================================================================
# Backend Configuration Notes:
# - This file is version controlled for team consistency
# - No user-specific configuration required
# - Works across all platforms (Linux, macOS, Windows)
# - State is stored in S3 with DynamoDB locking
# =============================================================================
EOF
}

# Update backend configurations for all layers
echo "Updating backend configurations..."
for layer_name in "${!LAYERS[@]}"; do
    layer_dir="$REGION_DIR/layers/$layer_name/production"
    display_name="${LAYERS[$layer_name]}"
    
    if [ -d "$layer_dir" ]; then
        create_backend_config "$layer_dir" "$layer_name" "$display_name"
    else
        echo "Warning: Layer directory not found: $layer_dir"
    fi
done

echo ""
echo "=== Backend Configuration Update Complete ==="
echo ""
echo "Next steps:"
echo "1. Review the updated backend.hcl files"
echo "2. Initialize each layer with: terraform init -backend-config=backend.hcl"
echo "3. Run terraform plan in each layer to validate configuration"
echo ""
echo "Layers updated:"
for layer_name in "${!LAYERS[@]}"; do
    echo "  - $layer_name (${LAYERS[$layer_name]})"
done