#!/bin/bash

# =============================================================================
# Backend Cleanup and Standardization Script
# =============================================================================
# This script:
# 1. Removes hardcoded backend blocks from main.tf files
# 2. Generates standardized backend.hcl files for all layers
# 3. Ensures consistency across all environments
# =============================================================================

set -e

echo "🔧 Starting backend configuration cleanup and standardization..."

# Array of main.tf files with hardcoded backends to clean
HARDCODED_BACKENDS=(
    "/home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/01-foundation/production/main.tf"
    "/home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/03-databases/production/main.tf"
    "/home/dennis.juma/terraform/providers/aws/regions/us-east-1/layers/01-foundation/production/main.tf"
    "/home/dennis.juma/terraform/providers/aws/regions/us-east-1/layers/02-platform/production/main.tf"
    "/home/dennis.juma/terraform/providers/aws/regions/us-east-1/layers/03-databases/production/main.tf"
)

echo "📝 Step 1: Removing hardcoded backend blocks from main.tf files..."

# Function to remove hardcoded backend block
remove_hardcoded_backend() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  • Processing: $file"
        
        # Create backup
        cp "$file" "$file.backup"
        
        # Remove hardcoded backend block using sed
        # This will match the backend "s3" { ... } block and replace it with a comment
        sed -i '/backend "s3" {/,/}/c\
  # Backend configuration loaded from backend.hcl file\
  # Use: terraform init -backend-config=backend.hcl' "$file"
        
        echo "    ✅ Removed hardcoded backend from $file"
    else
        echo "    ⚠️  File not found: $file"
    fi
}

# Clean up hardcoded backends
for file in "${HARDCODED_BACKENDS[@]}"; do
    remove_hardcoded_backend "$file"
done

echo ""
echo "🏗️  Step 2: Generating standardized backend.hcl files for all layers..."

# Function to generate backend.hcl file
generate_backend_hcl() {
    local region="$1"
    local layer_num="$2" 
    local layer_name="$3"
    local environment="$4"
    
    local layer_dir="/home/dennis.juma/terraform/providers/aws/regions/${region}/layers/${layer_num}-${layer_name}/${environment}"
    
    # Determine bucket and lock table based on region
    local bucket=""
    local lock_table=""
    
    case "$region" in
        "af-south-1")
            bucket="cptwn-terraform-state-ezra"
            lock_table="terraform-locks-af-south"
            ;;
        "us-east-1") 
            bucket="usest1-terraform-state-ezra"
            lock_table="terraform-locks-us-east-1"
            ;;
        *)
            echo "    ❌ Unknown region: $region"
            return 1
            ;;
    esac
    
    # Create directory if it doesn't exist
    mkdir -p "$layer_dir"
    
    # Generate backend.hcl content
    local backend_file="$layer_dir/backend.hcl"
    
    cat > "$backend_file" << EOF
# =============================================================================
# Backend Configuration: ${layer_name} Layer - ${region} ${environment}
# =============================================================================
# Auto-generated backend configuration for consistent team usage
# Initialize with: terraform init -backend-config=backend.hcl
# =============================================================================

bucket = "${bucket}"
key    = "providers/aws/regions/${region}/layers/${layer_num}-${layer_name}/${environment}/terraform.tfstate"
region = "${region}"
encrypt = true
dynamodb_table = "${lock_table}"

# =============================================================================
# Backend Configuration Notes:
# - This file is version controlled for team consistency
# - No user-specific configuration required
# - Works across all platforms (Linux, macOS, Windows)
# - State is stored in S3 with DynamoDB locking
# =============================================================================
EOF

    echo "    ✅ Generated: $backend_file"
}

# Define all layers that need backend.hcl files
declare -A LAYERS=(
    # AF-South-1 layers
    ["af-south-1,01,foundation,production"]="1"
    ["af-south-1,02,platform,production"]="1"
    ["af-south-1,03,databases,production"]="1" 
    ["af-south-1,03.5,observability,production"]="1"
    ["af-south-1,04,database-layer,production"]="1"
    ["af-south-1,05,client-nodegroups,production"]="1"
    ["af-south-1,06,shared-services,production"]="1"
    
    # US-East-1 layers
    ["us-east-1,01,foundation,production"]="1"
    ["us-east-1,02,platform,production"]="1"
    ["us-east-1,03,databases,production"]="1"
    ["us-east-1,03.5,observability,production"]="1"
    ["us-east-1,04,database-layer,production"]="1"
    ["us-east-1,05,client-nodegroups,production"]="1"
    ["us-east-1,06,shared-services,production"]="1"
)

# Generate backend.hcl files for all layers
for key in "${!LAYERS[@]}"; do
    IFS=',' read -ra PARAMS <<< "$key"
    region="${PARAMS[0]}"
    layer_num="${PARAMS[1]}"
    layer_name="${PARAMS[2]}" 
    environment="${PARAMS[3]}"
    
    echo "  • Generating for: $region/$layer_num-$layer_name/$environment"
    generate_backend_hcl "$region" "$layer_num" "$layer_name" "$environment"
done

echo ""
echo "🔍 Step 3: Validating generated backend configurations..."

# Count generated files
backend_count=$(find /home/dennis.juma/terraform/providers/aws/regions -name "backend.hcl" | wc -l)
echo "    📊 Total backend.hcl files: $backend_count"

# List all backend files for verification
echo ""
echo "📋 All backend.hcl files:"
find /home/dennis.juma/terraform/providers/aws/regions -name "backend.hcl" | sort

echo ""
echo "✅ Backend cleanup and standardization completed successfully!"
echo ""
echo "🎯 Next steps:"
echo "   1. Test terraform init in any layer directory"
echo "   2. Command: terraform init -backend-config=backend.hcl"
echo "   3. Verify remote state access"
echo ""
echo "📖 Documentation: /home/dennis.juma/terraform/docs/BACKEND_STANDARDS.md"
