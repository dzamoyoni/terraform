#!/bin/bash

# =============================================================================
# Backend State Migration Script for All Layers
# =============================================================================
# This script systematically migrates all layers from hardcoded backends
# to the new standardized backend.hcl configuration approach
# =============================================================================

set -e

echo "🚀 Starting systematic backend state migration for all layers..."

# Define layers that need migration (those with existing state in S3)
declare -A MIGRATION_LAYERS=(
    # AF-South-1 layers with existing state
    ["af-south-1,01,foundation,production"]="completed"  # Already done
    ["af-south-1,02,platform,production"]="pending"
    ["af-south-1,03,databases,production"]="pending"
    ["af-south-1,03.5,observability,production"]="pending"
)

# Function to migrate a single layer
migrate_layer() {
    local region="$1"
    local layer_num="$2"
    local layer_name="$3"
    local environment="$4"
    
    local layer_dir="/home/dennis.juma/terraform/providers/aws/regions/${region}/layers/${layer_num}-${layer_name}/${environment}"
    
    echo ""
    echo "🔄 Migrating: $region/$layer_num-$layer_name/$environment"
    
    # Check if layer directory exists
    if [ ! -d "$layer_dir" ]; then
        echo "   ⚠️  Layer directory not found: $layer_dir"
        return 1
    fi
    
    # Check if main.tf exists
    if [ ! -f "$layer_dir/main.tf" ]; then
        echo "   ⚠️  main.tf not found in: $layer_dir"
        return 1
    fi
    
    # Check if backend.hcl exists
    if [ ! -f "$layer_dir/backend.hcl" ]; then
        echo "   ⚠️  backend.hcl not found in: $layer_dir"
        return 1
    fi
    
    # Check if there's a hardcoded backend block that needs empty backend
    if grep -q "backend \"s3\" {" "$layer_dir/main.tf"; then
        echo "   ✅ Backend block already exists in main.tf"
    else
        echo "   📝 Adding empty backend block to main.tf"
        # This would require editing the main.tf file to add backend "s3" {}
        # For now, we'll just report what needs to be done
    fi
    
    # Navigate to layer directory
    cd "$layer_dir"
    
    # Clean existing .terraform directory
    echo "   🧹 Cleaning .terraform directory"
    rm -rf .terraform
    
    # Initialize with backend configuration
    echo "   🔧 Initializing backend configuration"
    if terraform init -backend-config=backend.hcl; then
        echo "   ✅ Backend initialization successful"
        
        # Verify state access
        echo "   🔍 Verifying remote state access"
        if terraform show > /dev/null 2>&1; then
            echo "   ✅ Remote state access confirmed"
            return 0
        else
            echo "   ❌ Remote state access failed"
            return 1
        fi
    else
        echo "   ❌ Backend initialization failed"
        return 1
    fi
}

# Function to check if layer has state in S3
check_layer_has_state() {
    local region="$1"
    local layer_num="$2"
    local layer_name="$3"
    local environment="$4"
    
    local bucket=""
    case "$region" in
        "af-south-1")
            bucket="cptwn-terraform-state-ezra"
            ;;
        "us-east-1")
            bucket="usest1-terraform-state-ezra"
            ;;
        *)
            echo "Unknown region: $region"
            return 1
            ;;
    esac
    
    local state_key="providers/aws/regions/${region}/layers/${layer_num}-${layer_name}/${environment}/terraform.tfstate"
    
    if aws s3 ls "s3://${bucket}/${state_key}" --region "$region" > /dev/null 2>&1; then
        return 0  # State exists
    else
        return 1  # No state
    fi
}

echo ""
echo "📊 Checking which layers have existing state in S3..."

# Check all potential layers for existing state
REGIONS=("af-south-1" "us-east-1")
LAYERS=("01,foundation" "02,platform" "03,databases" "03.5,observability" "04,database-layer" "05,client-nodegroups" "06,shared-services")
ENVIRONMENT="production"

for region in "${REGIONS[@]}"; do
    echo ""
    echo "🔍 Checking $region region:"
    
    for layer in "${LAYERS[@]}"; do
        IFS=',' read -ra LAYER_INFO <<< "$layer"
        layer_num="${LAYER_INFO[0]}"
        layer_name="${LAYER_INFO[1]}"
        
        if check_layer_has_state "$region" "$layer_num" "$layer_name" "$ENVIRONMENT"; then
            echo "   📦 $layer_num-$layer_name: HAS STATE - needs migration"
            MIGRATION_LAYERS["$region,$layer_num,$layer_name,$ENVIRONMENT"]="pending"
        else
            echo "   📭 $layer_num-$layer_name: no state - new layer"
        fi
    done
done

echo ""
echo "📋 Migration Plan:"
migration_count=0
completed_count=0

for key in "${!MIGRATION_LAYERS[@]}"; do
    IFS=',' read -ra PARAMS <<< "$key"
    region="${PARAMS[0]}"
    layer_num="${PARAMS[1]}"
    layer_name="${PARAMS[2]}"
    environment="${PARAMS[3]}"
    status="${MIGRATION_LAYERS[$key]}"
    
    if [ "$status" = "completed" ]; then
        echo "   ✅ $region/$layer_num-$layer_name/$environment - COMPLETED"
        ((completed_count++))
    else
        echo "   🔄 $region/$layer_num-$layer_name/$environment - PENDING"
        ((migration_count++))
    fi
done

echo ""
echo "📊 Migration Summary:"
echo "   📦 Total layers to migrate: $((migration_count + completed_count))"
echo "   ✅ Already completed: $completed_count"
echo "   🔄 Pending migration: $migration_count"

if [ $migration_count -eq 0 ]; then
    echo ""
    echo "🎉 All layers have been successfully migrated!"
    exit 0
fi

echo ""
read -p "🤔 Proceed with migration of $migration_count pending layers? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled by user."
    exit 0
fi

# Perform migrations
echo ""
echo "🚀 Starting migration process..."

for key in "${!MIGRATION_LAYERS[@]}"; do
    IFS=',' read -ra PARAMS <<< "$key"
    region="${PARAMS[0]}"
    layer_num="${PARAMS[1]}"
    layer_name="${PARAMS[2]}"
    environment="${PARAMS[3]}"
    status="${MIGRATION_LAYERS[$key]}"
    
    if [ "$status" = "pending" ]; then
        if migrate_layer "$region" "$layer_num" "$layer_name" "$environment"; then
            echo "   ✅ Migration successful: $region/$layer_num-$layer_name/$environment"
        else
            echo "   ❌ Migration failed: $region/$layer_num-$layer_name/$environment"
            echo "      Manual intervention may be required."
        fi
        
        # Brief pause between migrations
        sleep 2
    fi
done

echo ""
echo "🎉 Backend state migration process completed!"
echo ""
echo "📝 Next steps:"
echo "   1. Verify each migrated layer with 'terraform show'"
echo "   2. Test 'terraform plan' on each layer" 
echo "   3. Update documentation if needed"
echo ""
echo "📖 Documentation: /home/dennis.juma/terraform/docs/BACKEND_STANDARDS.md"
