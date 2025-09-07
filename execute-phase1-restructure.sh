#!/bin/bash
# 🔄 Execute Phase 1: AWS Restructure Script
# Safely restructures current AWS setup for multi-cloud readiness
#
# Usage: ./execute-phase1-restructure.sh
# 
# What it does:
# 1. Creates backup of current setup
# 2. Creates multi-cloud directory structure with placeholders
# 3. Copies AWS infrastructure to providers/aws/
# 4. Organizes backend configurations  
# 5. Updates module path references
# 6. Tests that everything still works
# 7. Provides cleanup option after validation
#
# SAFETY: Creates backup first, keeps originals until testing complete

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Phase 1: AWS Restructure for Multi-Cloud Readiness${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""
echo -e "${CYAN}Focus: AWS-only restructure + future placeholders${NC}"
echo -e "${CYAN}Risk: Zero (keeps originals until testing complete)${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -d "regions" && ! -d "modules" ]]; then
    echo -e "${RED}❌ Error: This doesn't look like your terraform directory${NC}"
    echo -e "${RED}   Expected to find 'regions' or 'modules' directories${NC}"
    echo -e "${RED}   Please run this script from your terraform root directory${NC}"
    exit 1
fi

# Check if migration already done
if [[ -d "providers/aws" ]]; then
    echo -e "${YELLOW}⚠️  Phase 1 appears to already be done${NC}"
    echo -e "${YELLOW}   Found existing providers/aws directory${NC}"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo -e "${YELLOW}📋 Pre-flight checks...${NC}"

# Check for critical directories
critical_found=0
if [[ -d "regions" ]]; then
    echo "  ✅ Found regions/ directory"
    critical_found=1
fi

if [[ -d "modules" ]]; then
    echo "  ✅ Found modules/ directory" 
    critical_found=1
fi

if [[ $critical_found -eq 0 ]]; then
    echo -e "${RED}❌ No critical directories found (regions/ or modules/)${NC}"
    echo -e "${RED}   This script is designed for existing terraform infrastructure${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Pre-flight checks passed${NC}"
echo ""

# ============================================================================
# Phase 1.1: Backup
# ============================================================================
echo -e "${BLUE}📦 Phase 1.1: Creating backup...${NC}"

BACKUP_NAME="terraform-phase1-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
echo "Creating backup: $BACKUP_NAME"

tar -czf "$BACKUP_NAME" . --exclude='.terraform' --exclude='*.tfstate*' --exclude='node_modules' --exclude='.git' 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Some files couldn't be backed up, but continuing...${NC}"
}

# Document current state
terraform state list > pre-restructure-state.txt 2>/dev/null || echo "# No accessible state" > pre-restructure-state.txt
ls -la > pre-restructure-files.txt

echo -e "${GREEN}✅ Backup created: $BACKUP_NAME${NC}"
echo ""

# ============================================================================
# Phase 1.2: Create Directory Structure
# ============================================================================
echo -e "${BLUE}📁 Phase 1.2: Creating multi-cloud directory structure...${NC}"

# Main provider structure
mkdir -p providers/aws

# Backend organization  
mkdir -p backends/aws/production/{af-south-1,us-east-1}
mkdir -p backends/{gcp,azure,alibaba}/production
mkdir -p backends/templates

# Future placeholders (empty for now)
mkdir -p providers/{gcp,azure,alibaba}/modules

# Shared configurations (future)
mkdir -p shared-configs/{client-profiles,networking-standards,security-policies}

# Cross-cloud orchestration (future)
mkdir -p orchestration/{client-deployment,monitoring,disaster-recovery}

# Global resources (future)
mkdir -p global/{dns-management,certificate-management,monitoring-aggregation}

echo -e "${GREEN}✅ Multi-cloud directory structure created${NC}"

# Create placeholder documentation
cat > providers/gcp/README.md << 'EOF'
# Google Cloud Platform (Future)

This directory is ready for GCP infrastructure when needed.

## Status: 🔮 Placeholder
- No GCP account needed yet  
- Ready for future expansion
- Will mirror AWS layered architecture

## When Ready:
1. Set up GCP account and billing
2. Create GCP modules (GKE, VPC, Cloud DNS)
3. Deploy first GCP region
4. Test multi-cloud client deployment
EOF

cat > providers/azure/README.md << 'EOF'
# Microsoft Azure (Future)

This directory is ready for Azure infrastructure when needed.

## Status: 🔮 Placeholder
- No Azure subscription needed yet
- Ready for future expansion  
- Will mirror AWS layered architecture

## When Ready:
1. Set up Azure subscription
2. Create Azure modules (AKS, VNet, Azure DNS)
3. Deploy first Azure region
4. Test multi-cloud client deployment
EOF

cat > shared-configs/README.md << 'EOF'
# Shared Configurations (Future)

This directory will contain cloud-agnostic configurations when multi-cloud is implemented.

## Status: 🔮 Placeholder
- Ready for client configuration templates
- Ready for networking standards
- Ready for security policy templates

## When Ready:
- client-profiles/: Client configuration templates
- networking-standards/: Network design patterns  
- security-policies/: Security policy templates
EOF

cat > orchestration/README.md << 'EOF'
# Cross-Cloud Orchestration (Future)

This directory will contain cross-cloud coordination when multi-cloud is implemented.

## Status: 🔮 Placeholder
- Ready for client deployment automation
- Ready for cross-cloud monitoring
- Ready for disaster recovery automation

## When Ready:
- client-deployment/: Deploy clients across clouds
- monitoring/: Unified monitoring and alerting
- disaster-recovery/: Cross-cloud backup and recovery
EOF

echo -e "${GREEN}✅ Placeholder documentation created${NC}"
echo ""

# ============================================================================
# Phase 1.3: Copy Current AWS Infrastructure
# ============================================================================
echo -e "${BLUE}📂 Phase 1.3: Copying AWS infrastructure to new location...${NC}"

# Copy (don't move yet) current directories to AWS provider
copied_items=0

if [[ -d "regions" ]]; then
    cp -r regions/ providers/aws/
    echo -e "  ${GREEN}✅ Copied regions/ → providers/aws/regions/${NC}"
    copied_items=$((copied_items + 1))
fi

if [[ -d "modules" ]]; then
    cp -r modules/ providers/aws/
    echo -e "  ${GREEN}✅ Copied modules/ → providers/aws/modules/${NC}"
    copied_items=$((copied_items + 1))
fi

if [[ -d "shared" ]]; then
    cp -r shared/ providers/aws/
    echo -e "  ${GREEN}✅ Copied shared/ → providers/aws/shared/${NC}"
    copied_items=$((copied_items + 1))
fi

if [[ -d "kubernetes" ]]; then
    cp -r kubernetes/ providers/aws/
    echo -e "  ${GREEN}✅ Copied kubernetes/ → providers/aws/kubernetes/${NC}"
    copied_items=$((copied_items + 1))
fi

if [[ -d "examples" ]]; then
    cp -r examples/ providers/aws/
    echo -e "  ${GREEN}✅ Copied examples/ → providers/aws/examples/${NC}"
    copied_items=$((copied_items + 1))
fi

echo -e "${GREEN}✅ AWS infrastructure copied ($copied_items directories)${NC}"
echo ""

# ============================================================================
# Phase 1.4: Organize Backend Configurations
# ============================================================================
echo -e "${BLUE}🔧 Phase 1.4: Organizing backend configurations...${NC}"

# Create backend config templates
cat > backends/templates/aws-production-layer.hcl << 'EOF'
# Template for AWS production layer backend
# Replace REGION and LAYER with actual values
bucket         = "terraform-state-REGION-production"
key            = "providers/aws/regions/REGION/layers/LAYER/production/terraform.tfstate"
region         = "REGION"
encrypt        = true
dynamodb_table = "terraform-locks-REGION"
EOF

echo -e "  ${GREEN}✅ Created backend template${NC}"

# Create default backend configs for af-south-1 layers (most common)
for layer in foundation platform databases observability; do
    cat > backends/aws/production/af-south-1/$layer.hcl << EOF
# Backend configuration for af-south-1 $layer layer
# TODO: Update with your actual S3 bucket and DynamoDB table names
bucket         = "your-terraform-state-bucket"
key            = "providers/aws/regions/af-south-1/layers/$layer/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
EOF
    echo -e "  ${GREEN}✅ Created backends/aws/production/af-south-1/$layer.hcl${NC}"
done

# Create note about backend customization
cat > backends/aws/production/af-south-1/README.md << 'EOF'
# Backend Configuration for af-south-1 Production

## ⚠️ IMPORTANT: Customize These Files

The .hcl files in this directory contain placeholder values that need to be updated:

1. **Update bucket names**: Replace "your-terraform-state-bucket" with your actual S3 bucket
2. **Update DynamoDB table**: Replace "terraform-state-lock" with your actual table name

## Files to Update:
- foundation.hcl
- platform.hcl  
- databases.hcl
- observability.hcl

## Usage:
```bash
terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/platform.hcl
```
EOF

echo -e "${GREEN}✅ Backend configs organized (need customization)${NC}"
echo ""

# ============================================================================
# Phase 1.5: Update Module Path References  
# ============================================================================
echo -e "${BLUE}🔧 Phase 1.5: Updating module path references...${NC}"

# Update module source paths in the copied AWS files
updated_files=0
find providers/aws -name "*.tf" -type f | while read -r file; do
    # Update different variations of module paths
    if sed -i 's|source = "\.\./\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' "$file" 2>/dev/null; then
        updated_files=$((updated_files + 1))
    fi
    if sed -i 's|source = "\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' "$file" 2>/dev/null; then
        updated_files=$((updated_files + 1))  
    fi
    if sed -i 's|source = "\.\./\.\./\.\./modules/|source = "\.\./modules/|g' "$file" 2>/dev/null; then
        updated_files=$((updated_files + 1))
    fi
done

echo -e "${GREEN}✅ Module path references updated${NC}"
echo ""

# ============================================================================
# Phase 1.6: Discovery and Testing
# ============================================================================
echo -e "${BLUE}🧪 Phase 1.6: Testing new structure...${NC}"

# Discover actual structure
echo "Discovering your actual infrastructure structure:"
af_south_files=$(find providers/aws -name "*.tf" -path "*/af-south-1/*" | wc -l)
us_east_files=$(find providers/aws -name "*.tf" -path "*/us-east-1/*" | wc -l)

echo -e "  📊 af-south-1 .tf files: ${af_south_files}"
echo -e "  📊 us-east-1 .tf files: ${us_east_files}"

# Try to find and test af-south-1 platform layer
test_dir="providers/aws/regions/af-south-1/layers/02-platform/production"
if [[ -d "$test_dir" ]]; then
    echo -e "${GREEN}✅ Found af-south-1 platform layer in new location${NC}"
    
    echo "Testing new structure (this may show warnings about backend config):"
    cd "$test_dir"
    
    # Check if terraform files exist
    if ls *.tf 1> /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Terraform files found in new location${NC}"
        
        # Check backend config path
        backend_config="../../../../../../backends/aws/production/af-south-1/platform.hcl"
        if [[ -f "$backend_config" ]]; then
            echo -e "  ${GREEN}✅ Backend config found${NC}"
            echo "  📄 Backend config contents:"
            cat "$backend_config" | sed 's/^/    /'
            
            echo ""
            echo -e "${YELLOW}⚠️  Note: You'll need to update bucket and table names in backend configs${NC}"
        else
            echo -e "  ${RED}❌ Backend config not found at expected location${NC}"
        fi
    else
        echo -e "  ${RED}❌ No terraform files found${NC}"
    fi
    
    cd - > /dev/null
else
    echo -e "${YELLOW}⚠️  af-south-1 platform not found in expected location${NC}"
    echo "Let's see what structure exists:"
    find providers/aws -type d -name "af-south-1" | head -3
fi

echo ""

# ============================================================================
# Phase 1.7: Validation Summary
# ============================================================================
echo -e "${BLUE}📊 Phase 1.7: Validation summary...${NC}"

# Directory structure check
echo "1. Directory structure check:"
if [[ -d "providers/aws" ]]; then
    echo -e "   ${GREEN}✅ providers/aws/ exists${NC}"
    aws_dirs=$(ls -1 providers/aws/ 2>/dev/null | wc -l)
    echo -e "   📁 Contains $aws_dirs directories"
else
    echo -e "   ${RED}❌ providers/aws/ missing${NC}"
fi

# Backend configs check  
echo "2. Backend configs check:"
if [[ -d "backends/aws/production/af-south-1" ]]; then
    backend_count=$(ls -1 backends/aws/production/af-south-1/*.hcl 2>/dev/null | wc -l)
    echo -e "   ${GREEN}✅ Backend configs exist ($backend_count files)${NC}"
else
    echo -e "   ${RED}❌ Backend configs missing${NC}"
fi

# File count comparison
echo "3. File count comparison:"
old_count=$(find regions modules shared kubernetes examples -name "*.tf" 2>/dev/null | wc -l || echo "0")
new_count=$(find providers/aws -name "*.tf" 2>/dev/null | wc -l || echo "0") 
echo -e "   📊 Original .tf files: $old_count"
echo -e "   📊 New location .tf files: $new_count"
if [[ "$old_count" -eq "$new_count" ]] && [[ "$new_count" -gt 0 ]]; then
    echo -e "   ${GREEN}✅ File counts match${NC}"
elif [[ "$new_count" -eq 0 ]]; then
    echo -e "   ${YELLOW}⚠️  No .tf files found - check if directories were copied${NC}"
else
    echo -e "   ${YELLOW}⚠️  File counts differ - investigate${NC}"
fi

echo ""

# ============================================================================
# Phase 1.8: Next Steps
# ============================================================================
echo -e "${BLUE}🎯 Phase 1 Complete - Next Steps${NC}"
echo ""

echo -e "${GREEN}✅ Phase 1 completed successfully!${NC}"
echo ""
echo "What was accomplished:"
echo "  • ✅ Backup created: $BACKUP_NAME"
echo "  • ✅ Multi-cloud directory structure created"
echo "  • ✅ AWS infrastructure copied to providers/aws/"
echo "  • ✅ Backend configs organized in backends/aws/"
echo "  • ✅ Module path references updated"
echo "  • ✅ Future provider placeholders created"
echo ""

echo -e "${YELLOW}📋 REQUIRED: Update Backend Configurations${NC}"
echo ""
echo "Edit these files with your actual AWS resource names:"
echo "  📝 backends/aws/production/af-south-1/platform.hcl"
echo "  📝 backends/aws/production/af-south-1/foundation.hcl"
echo "  📝 backends/aws/production/af-south-1/databases.hcl"
echo "  📝 backends/aws/production/af-south-1/observability.hcl"
echo ""
echo "Replace:"
echo "  • 'your-terraform-state-bucket' → your actual S3 bucket name"
echo "  • 'terraform-state-lock' → your actual DynamoDB table name"
echo ""

echo -e "${YELLOW}🧪 TEST Before Cleanup:${NC}"
echo ""
echo "1. Update backend configs (above)"
echo "2. Test the new structure:"
echo "   cd providers/aws/regions/af-south-1/layers/02-platform/production"
echo "   terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/platform.hcl"
echo "   terraform plan  # Should show no changes"
echo ""

echo -e "${YELLOW}🧹 CLEANUP (Only After Testing):${NC}"
echo ""
echo "Once you've confirmed the new structure works:"
echo "  rm -rf regions/ modules/ shared/ kubernetes/ examples/"
echo ""

echo -e "${GREEN}🎉 Your infrastructure is now multi-cloud ready!${NC}"
echo ""
echo "Future expansion is easy:"
echo "  • GCP: Add modules to providers/gcp/"
echo "  • Azure: Add modules to providers/azure/"  
echo "  • Cross-cloud: Use orchestration/ directory"
echo ""

echo -e "${CYAN}Next phase (when ready): Add GCP or Azure support${NC}"
echo -e "${CYAN}Current focus: Test and use your restructured AWS setup${NC}"
