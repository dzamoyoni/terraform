#!/bin/bash
# 🔧 Backend Configuration Standardization Script
# Ensures all layers have consistent, direct backend.hcl files

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Standardizing Backend Configurations${NC}"
echo "======================================"

# Function to create standardized backend.hcl
create_backend_config() {
    local region=$1
    local layer=$2
    local environment=$3
    local bucket=$4
    local dynamodb_table=$5
    local layer_path=$6
    
    echo -e "${YELLOW}Creating backend config for: $region/$layer/$environment${NC}"
    
    cat > "$layer_path/backend.hcl" << EOF
# 🔒 Backend Configuration - $layer Layer
# Region: $region | Environment: $environment
# CRITICAL: This file configures access to protected Terraform state

bucket         = "$bucket"
key            = "providers/aws/regions/$region/layers/$layer/$environment/terraform.tfstate"
region         = "$region"
encrypt        = true
dynamodb_table = "$dynamodb_table"

# 🏷️ Standardized Naming Convention:
# - Bucket: Region-specific state bucket
# - Key: providers/aws/regions/{region}/layers/{layer}/{env}/terraform.tfstate
# - DynamoDB: Region-specific lock table
# - Encryption: Always enabled for security

# 🔧 Usage:
# terraform init -backend-config=backend.hcl

# 📝 Team Notes:
# - This file is version controlled
# - No relative paths - works from any location
# - Consistent across all layers and environments
EOF

    echo -e "${GREEN}✅ Created: $layer_path/backend.hcl${NC}"
}

# AF-South-1 configurations
REGION_AF="af-south-1"
BUCKET_AF="cptwn-terraform-state-ezra"
DYNAMODB_AF="terraform-locks-af-south"
BASE_AF="/home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers"

echo -e "\n${BLUE}🌍 Processing AF-South-1 Layers${NC}"
echo "--------------------------------"

# AF-South layers
create_backend_config "$REGION_AF" "01-foundation" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/01-foundation/production"
create_backend_config "$REGION_AF" "02-platform" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/02-platform/production"
create_backend_config "$REGION_AF" "03-databases" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/03-databases/production"
create_backend_config "$REGION_AF" "03.5-observability" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/03.5-observability/production"
create_backend_config "$REGION_AF" "03-standalone-compute" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/03-standalone-compute/production"
create_backend_config "$REGION_AF" "04-database-layer" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/04-database-layer/production"
create_backend_config "$REGION_AF" "05-client-nodegroups" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/05-client-nodegroups/production"
create_backend_config "$REGION_AF" "06-shared-services" "production" "$BUCKET_AF" "$DYNAMODB_AF" "$BASE_AF/06-shared-services/production"

# US-East-1 configurations
REGION_US="us-east-1"
BUCKET_US="usest1-terraform-state-ezra"
DYNAMODB_US="terraform-locks-us-east-1"
BASE_US="/home/dennis.juma/terraform/providers/aws/regions/us-east-1/layers"

echo -e "\n${BLUE}🇺🇸 Processing US-East-1 Layers${NC}"
echo "--------------------------------"

# US-East layers
create_backend_config "$REGION_US" "01-foundation" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/01-foundation/production"
create_backend_config "$REGION_US" "02-platform" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/02-platform/production"
create_backend_config "$REGION_US" "03-databases" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/03-databases/production"
create_backend_config "$REGION_US" "03.5-observability" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/03.5-observability/production"
create_backend_config "$REGION_US" "03-standalone-compute" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/03-standalone-compute/production"
create_backend_config "$REGION_US" "04-database-layer" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/04-database-layer/production"
create_backend_config "$REGION_US" "05-client-nodegroups" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/05-client-nodegroups/production"
create_backend_config "$REGION_US" "06-shared-services" "production" "$BUCKET_US" "$DYNAMODB_US" "$BASE_US/06-shared-services/production"

echo -e "\n${GREEN}🎉 Backend Standardization Complete!${NC}"
echo -e "${BLUE}📋 Summary:${NC}"
echo "- ✅ All layers now have direct backend.hcl files"
echo "- ✅ Standardized naming convention applied"  
echo "- ✅ Consistent across all regions and layers"
echo "- ✅ No relative paths - works from anywhere"
echo -e "\n${YELLOW}🔧 Usage in any layer:${NC}"
echo "terraform init -backend-config=backend.hcl"
echo -e "\n${BLUE}👥 Team Benefits:${NC}"
echo "- Simple, predictable commands"
echo "- No complex relative paths"
echo "- Self-documenting configurations"
echo "- Works across different operating systems"
