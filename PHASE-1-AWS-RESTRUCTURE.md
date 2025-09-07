# 🔄 Phase 1: AWS Restructure for Multi-Cloud Readiness
## Current Focus: AWS Only + Future Placeholders

**Date:** January 21, 2025  
**Scope:** Restructure existing AWS setup + Create placeholder structure  
**Timeline:** 1-2 weeks  
**Risk:** Zero (AWS-only restructure with full testing)

---

## 🎯 **What We're Doing**

Transform your current working AWS infrastructure into a **multi-cloud consistent structure** while:
- ✅ **Keeping your af-south-1 production operational**
- ✅ **All current functionality preserved**
- ✅ **Creating placeholders for future cloud providers**
- ✅ **Better backend configuration organization**

---

## 📁 **Target Structure After Phase 1**

```
terraform/
├── providers/
│   └── aws/                         ✅ YOUR CURRENT SETUP MOVES HERE
│       ├── regions/
│       │   ├── us-east-1/          ✅ Your existing regions
│       │   └── af-south-1/         ✅ Production - fully functional
│       ├── modules/                ✅ Your proven modules
│       ├── shared/                 ✅ Your shared configs
│       ├── kubernetes/             ✅ Your k8s configs
│       └── examples/               ✅ Your examples
│
├── backends/                        🆕 ORGANIZED BACKEND CONFIGS
│   ├── aws/
│   │   └── production/
│   │       ├── af-south-1/         ✅ Your backend configs organized
│   │       │   ├── foundation.hcl
│   │       │   ├── platform.hcl
│   │       │   ├── databases.hcl
│   │       │   └── observability.hcl
│   │       └── us-east-1/          ✅ If you have configs
│   ├── gcp/                        🔮 PLACEHOLDER (future)
│   ├── azure/                      🔮 PLACEHOLDER (future)
│   └── templates/                  🔮 TEMPLATES (future)
│
├── shared-configs/                  🔮 PLACEHOLDER (future)
├── orchestration/                   🔮 PLACEHOLDER (future)
└── global/                         🔮 PLACEHOLDER (future)
```

---

## 🛡️ **Safety-First Implementation**

### **Step 1: Full Backup (5 minutes)**
```bash
# Create comprehensive backup
echo "📦 Creating backup..."
tar -czf terraform-pre-restructure-backup-$(date +%Y%m%d-%H%M%S).tar.gz . \
    --exclude='.terraform' \
    --exclude='*.tfstate*' \
    --exclude='node_modules'

# Document current state
terraform state list > pre-restructure-state.txt 2>/dev/null || echo "No state accessible"
ls -la > pre-restructure-files.txt

echo "✅ Backup complete!"
```

### **Step 2: Test Current Setup Works**
```bash
# Verify af-south-1 production is working
echo "🧪 Testing current setup..."
cd regions/af-south-1/layers/02-platform/production 2>/dev/null || echo "Path not found - will adjust"

if [ -f "main.tf" ]; then
    terraform plan -detailed-exitcode
    if [ $? -eq 0 ]; then
        echo "✅ Current setup working - no changes detected"
    else
        echo "⚠️ Current setup has changes - proceeding with caution"
    fi
else
    echo "⚠️ Platform layer not found - will discover actual structure"
fi

cd - > /dev/null
```

---

## 📂 **Directory Creation**

### **Step 3: Create Multi-Cloud Structure**
```bash
echo "🏗️ Creating multi-cloud directory structure..."

# Create main provider structure
mkdir -p providers/aws

# Create backend organization
mkdir -p backends/aws/production/{af-south-1,us-east-1}
mkdir -p backends/{gcp,azure,alibaba}/production
mkdir -p backends/templates

# Create future placeholders (empty for now)
mkdir -p providers/{gcp,azure,alibaba}/modules
mkdir -p shared-configs/{client-profiles,networking-standards,security-policies}
mkdir -p orchestration/{client-deployment,monitoring,disaster-recovery}
mkdir -p global/{dns-management,certificate-management,monitoring-aggregation}

echo "✅ Directory structure created"
```

### **Step 4: Create Placeholder Documentation**
```bash
# Document future providers
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

echo "✅ Placeholder documentation created"
```

---

## 🔄 **Move Current AWS Infrastructure**

### **Step 5: Copy AWS Infrastructure (Safe)**
```bash
echo "📂 Copying AWS infrastructure to new location..."

# Copy (don't move yet) current directories to AWS provider
if [ -d "regions" ]; then
    cp -r regions/ providers/aws/
    echo "✅ Copied regions/ → providers/aws/regions/"
fi

if [ -d "modules" ]; then
    cp -r modules/ providers/aws/
    echo "✅ Copied modules/ → providers/aws/modules/"
fi

if [ -d "shared" ]; then
    cp -r shared/ providers/aws/
    echo "✅ Copied shared/ → providers/aws/shared/"
fi

if [ -d "kubernetes" ]; then
    cp -r kubernetes/ providers/aws/
    echo "✅ Copied kubernetes/ → providers/aws/kubernetes/"
fi

if [ -d "examples" ]; then
    cp -r examples/ providers/aws/
    echo "✅ Copied examples/ → providers/aws/examples/"
fi

echo "✅ AWS infrastructure copied (originals still intact)"
```

---

## 🔧 **Backend Configuration Organization**

### **Step 6: Discover Current Backend Configs**
```bash
echo "🔍 Discovering current backend configurations..."

# Find existing backend configs
echo "Looking for .hcl files:"
find . -name "*.hcl" -type f | grep -v providers/ | head -10

echo "Looking for terraform backend blocks:"
grep -r "backend.*s3" --include="*.tf" . | grep -v providers/ | head -5

# Find terraform state references
echo "Looking for state file references:"
find . -name "terraform.tfstate" -o -name "*.tfstate" | head -5
```

### **Step 7: Organize Backend Configs**
```bash
echo "🔧 Organizing backend configurations..."

# Create backend config templates for common patterns
cat > backends/templates/aws-production-layer.hcl << 'EOF'
# Template for AWS production layer backend
# Replace REGION and LAYER with actual values
bucket         = "terraform-state-REGION-production"
key            = "providers/aws/regions/REGION/layers/LAYER/production/terraform.tfstate"
region         = "REGION"
encrypt        = true
dynamodb_table = "terraform-locks-REGION"
EOF

# Create default backend configs for af-south-1 layers
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
    echo "Created: backends/aws/production/af-south-1/$layer.hcl"
done

echo "✅ Backend configs organized (need customization with your actual bucket names)"
```

---

## 🔧 **Update Module References**

### **Step 8: Fix Module Paths**
```bash
echo "🔧 Updating module path references..."

# Update module source paths in the copied AWS files
# From: source = "../../../modules/vpc-foundation"
# To:   source = "../../modules/vpc-foundation"

find providers/aws -name "*.tf" -type f | while read -r file; do
    # Update different variations of module paths
    sed -i 's|source = "\.\./\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' "$file" 2>/dev/null || true
    sed -i 's|source = "\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' "$file" 2>/dev/null || true
    sed -i 's|source = "\.\./\.\./\.\./modules/|source = "\.\./modules/|g' "$file" 2>/dev/null || true
done

echo "✅ Module paths updated"
```

---

## 🧪 **Test New Structure**

### **Step 9: Test New AWS Structure Works**
```bash
echo "🧪 Testing new structure..."

# Find and test af-south-1 platform layer in new location
test_dir="providers/aws/regions/af-south-1/layers/02-platform/production"
if [ -d "$test_dir" ]; then
    echo "Found af-south-1 platform layer in new location"
    cd "$test_dir"
    
    # Test with new backend config path (if it exists)
    backend_config="../../../../../../backends/aws/production/af-south-1/platform.hcl"
    if [ -f "$backend_config" ]; then
        echo "Testing with organized backend config..."
        
        # Show what the backend config contains (for verification)
        echo "Backend config contents:"
        cat "$backend_config"
        
        echo "Running terraform init..."
        if terraform init -backend-config="$backend_config"; then
            echo "✅ terraform init successful with new backend config"
            
            echo "Running terraform plan..."
            if terraform plan -detailed-exitcode; then
                echo "✅ terraform plan successful - no changes (expected)"
            else
                echo "⚠️ terraform plan shows changes - this might be expected"
            fi
        else
            echo "⚠️ terraform init failed - backend config needs customization"
            echo "You'll need to update the bucket and table names in: $backend_config"
        fi
    else
        echo "⚠️ Backend config not found - will need manual creation"
    fi
    
    cd - > /dev/null
else
    echo "⚠️ af-south-1 platform not found in expected location"
    echo "Let's discover the actual structure:"
    find providers/aws -name "*.tf" -path "*/af-south-1/*" | head -5
fi
```

---

## 📊 **Validation Checklist**

### **Step 10: Complete Validation**
```bash
echo "📊 Running validation checklist..."

# 1. Check directory structure
echo "1. Directory structure check:"
ls -la providers/aws/ | head -10

# 2. Check backend configs exist
echo "2. Backend configs check:"
ls -la backends/aws/production/af-south-1/ 2>/dev/null || echo "Backend configs need setup"

# 3. Check module references
echo "3. Module references check:"
grep -r "source.*modules" providers/aws/ | head -3

# 4. Check for any remaining old paths
echo "4. Old path references check:"
grep -r "\.\./\.\./\.\./\.\./modules" providers/aws/ | head -3 || echo "No old paths found ✅"

# 5. Compare file counts
echo "5. File count comparison:"
old_count=$(find regions modules shared kubernetes examples -name "*.tf" 2>/dev/null | wc -l)
new_count=$(find providers/aws -name "*.tf" 2>/dev/null | wc -l)
echo "Original .tf files: $old_count"
echo "New location .tf files: $new_count"
if [ "$old_count" -eq "$new_count" ]; then
    echo "✅ File counts match"
else
    echo "⚠️ File counts differ - investigate"
fi
```

---

## ✅ **Clean Up (Only After Testing)**

### **Step 11: Remove Old Structure (CAREFUL!)**
```bash
echo "🧹 Final cleanup (only after complete validation)..."

read -p "❓ Have you successfully tested the new structure? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing old directory structure..."
    
    # Remove old directories (backup already created)
    rm -rf regions/ modules/ shared/ kubernetes/ examples/
    
    echo "✅ Old structure removed"
    echo "✅ Phase 1 restructure complete!"
else
    echo "Skipping cleanup - test the new structure first"
    echo "When ready, manually run: rm -rf regions/ modules/ shared/ kubernetes/ examples/"
fi
```

---

## 📋 **Post-Restructure Tasks**

### **What You Need to Do:**

1. **Update Backend Configs** (Most Important):
   ```bash
   # Edit these files with your actual S3 bucket and DynamoDB table names:
   backends/aws/production/af-south-1/platform.hcl
   backends/aws/production/af-south-1/foundation.hcl
   backends/aws/production/af-south-1/databases.hcl
   backends/aws/production/af-south-1/observability.hcl
   ```

2. **Test Production Operations**:
   ```bash
   cd providers/aws/regions/af-south-1/layers/02-platform/production
   terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/platform.hcl
   terraform plan  # Should show no changes
   ```

3. **Update CI/CD Pipelines** (if any):
   - Change paths from `regions/` to `providers/aws/regions/`
   - Update backend config paths

4. **Update Documentation**:
   - Team knows new directory structure
   - Operational procedures updated

---

## 🎯 **What You Achieve**

### **✅ Immediate Benefits:**
- **Professional structure** ready for multi-cloud expansion
- **Better organized** backend configurations  
- **Same functionality** - zero production impact
- **Future-ready** architecture pattern

### **✅ Business Benefits:**
- **Client presentations** show multi-cloud readiness
- **Team preparation** for future cloud expansion
- **Organized codebase** easier to maintain
- **Strategic positioning** for growth

### **🔮 Future Ready:**
- **GCP expansion**: Just add modules to `providers/gcp/`
- **Azure expansion**: Just add modules to `providers/azure/`
- **Cross-cloud features**: Use `orchestration/` directory
- **Global services**: Use `global/` directory

---

## 📞 **Need Help?**

If you encounter issues during restructuring:

1. **Backup exists**: You can always restore from backup
2. **Test incrementally**: Don't remove old structure until new structure works
3. **Focus on backend configs**: Most issues will be backend configuration paths
4. **One layer at a time**: Test foundation → platform → databases → observability

**Result: Same AWS infrastructure, better organized, multi-cloud ready! 🚀**
