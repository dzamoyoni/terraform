# 🔄 Complete Restructure Plan with Backend Management
## Safe Migration to Multi-Cloud Structure + Backend Config Organization

**Date:** January 21, 2025  
**Priority:** Zero disruption + Clean backend organization  
**Status:** 📋 Ready for execution

---

## 🎯 **Backend Strategy: Keep Working, Organize Better**

Your backend configs are the **lifeline** of your infrastructure. We'll:
- ✅ **Keep all existing backend configs working**  
- ✅ **Organize them for better maintenance**
- ✅ **Make them multi-cloud ready**
- ✅ **Document the patterns clearly**

---

## 📁 **New Structure: Backend-Conscious**

### **Target Structure:**
```
terraform/
├── 🔧 backends/                     🆕 Centralized backend management
│   ├── aws/                         🆕 AWS-specific backends
│   │   ├── production/
│   │   │   ├── af-south-1/
│   │   │   │   ├── foundation.hcl   ✅ Your existing configs
│   │   │   │   ├── platform.hcl     ✅ Your existing configs  
│   │   │   │   ├── databases.hcl    ✅ Your existing configs
│   │   │   │   └── observability.hcl ✅ Your existing configs
│   │   │   └── us-east-1/
│   │   │       └── *.hcl            ✅ Your existing configs
│   │   ├── staging/                 🆕 Future staging backends
│   │   └── development/             🆕 Future dev backends
│   ├── gcp/                         🆕 Future GCP backends
│   │   └── production/
│   ├── azure/                       🆕 Future Azure backends  
│   │   └── production/
│   └── templates/                   🆕 Backend templates for new regions
│
├── providers/
│   └── aws/                         ✅ Your current code moves here
│       ├── regions/
│       │   ├── us-east-1/
│       │   │   └── layers/
│       │   │       ├── 01-foundation/production/
│       │   │       │   ├── main.tf
│       │   │       │   └── backend.tf → references ../../../../../../backends/aws/production/us-east-1/foundation.hcl
│       │   │       ├── 02-platform/production/
│       │   │       └── 03-databases/production/
│       │   └── af-south-1/          ✅ Production - same functionality
│       │       └── layers/
│       │           ├── 01-foundation/production/
│       │           │   ├── main.tf
│       │           │   └── backend.tf → references ../../../../../../backends/aws/production/af-south-1/foundation.hcl
│       │           ├── 02-platform/production/
│       │           ├── 03-databases/production/
│       │           └── 03.5-observability/production/
│       ├── modules/                 ✅ Your proven modules
│       └── shared/
```

---

## 🛡️ **Backend Migration Strategy: Zero Risk**

### **Step 1: Discover Current Backend Configs**
```bash
# Find all current backend configurations
echo "🔍 Discovering current backend configs..."
find . -name "*.hcl" -o -name "*backend*" | grep -E "\.(hcl|tf)$"

# Find terraform blocks with backend configs
grep -r "backend.*s3" --include="*.tf" . | head -10
```

### **Step 2: Create Organized Backend Directory**
```bash
# Create centralized backend structure
mkdir -p backends/aws/production/{af-south-1,us-east-1}
mkdir -p backends/aws/{staging,development}
mkdir -p backends/{gcp,azure}/production
mkdir -p backends/templates

echo "✅ Backend directory structure created"
```

### **Step 3: Move Backend Configs (Preserving Content)**
```bash
# Move existing backend configs to organized structure
# Example for af-south-1 (adjust paths based on your current setup):

# Foundation layer backend
cp shared/backend-configs/foundation-production-afs1.hcl backends/aws/production/af-south-1/foundation.hcl 2>/dev/null || \
cp regions/af-south-1/layers/01-foundation/production/backend.hcl backends/aws/production/af-south-1/foundation.hcl 2>/dev/null || \
echo "# Foundation layer backend config" > backends/aws/production/af-south-1/foundation.hcl

# Platform layer backend  
cp shared/backend-configs/platform-production-afs1.hcl backends/aws/production/af-south-1/platform.hcl 2>/dev/null || \
cp regions/af-south-1/layers/02-platform/production/backend.hcl backends/aws/production/af-south-1/platform.hcl 2>/dev/null || \
echo "# Platform layer backend config" > backends/aws/production/af-south-1/platform.hcl

# Database layer backend
cp shared/backend-configs/databases-production-afs1.hcl backends/aws/production/af-south-1/databases.hcl 2>/dev/null || \
cp regions/af-south-1/layers/03-databases/production/backend.hcl backends/aws/production/af-south-1/databases.hcl 2>/dev/null || \
echo "# Database layer backend config" > backends/aws/production/af-south-1/databases.hcl

# Observability layer backend
cp shared/backend-configs/observability-production-afs1.hcl backends/aws/production/af-south-1/observability.hcl 2>/dev/null || \
cp regions/af-south-1/layers/03.5-observability/production/backend.hcl backends/aws/production/af-south-1/observability.hcl 2>/dev/null || \
echo "# Observability layer backend config" > backends/aws/production/af-south-1/observability.hcl

echo "✅ Backend configs organized"
```

### **Step 4: Verify Backend Configs Content**
```bash
# Check that backend configs have proper content
echo "🔍 Verifying backend configs..."

for config in backends/aws/production/af-south-1/*.hcl; do
  echo "📄 $config:"
  cat "$config"
  echo "---"
done
```

---

## 📋 **Backend Config Templates**

### **Standard AWS Backend Template:**
```hcl
# backends/templates/aws-production-layer.hcl
bucket         = "terraform-state-${region}-production"
key            = "providers/aws/regions/${region}/layers/${layer}/${environment}/terraform.tfstate"  
region         = "${region}"
encrypt        = true
dynamodb_table = "terraform-locks-${region}"

# Additional backend configuration
versioning = true
force_destroy = false
```

### **Example: af-south-1 Platform Backend:**
```hcl
# backends/aws/production/af-south-1/platform.hcl
bucket         = "terraform-state-af-south-1-production"
key            = "providers/aws/regions/af-south-1/layers/02-platform/production/terraform.tfstate"
region         = "af-south-1"  
encrypt        = true
dynamodb_table = "terraform-locks-af-south-1"
```

---

## 🔄 **Complete Migration Steps**

### **Phase 1: Prepare (5 minutes)**
```bash
#!/bin/bash
# 1. Full backup first
echo "📦 Creating backup..."
tar -czf terraform-backup-$(date +%Y%m%d-%H%M%S).tar.gz . --exclude='.terraform' --exclude='*.tfstate*'

# 2. Create new directory structure  
mkdir -p providers/aws
mkdir -p backends/aws/production/{af-south-1,us-east-1}
mkdir -p backends/{gcp,azure,templates}
mkdir -p shared-configs/{client-profiles,networking-standards,security-policies}
mkdir -p orchestration/{client-deployment,monitoring,disaster-recovery}
mkdir -p global/{dns-management,certificate-management,monitoring-aggregation}

echo "✅ Directory structure ready"
```

### **Phase 2: Move Backend Configs (10 minutes)**
```bash
# Organize existing backend configs
echo "🔧 Organizing backend configs..."

# Create backend configs based on your current setup
# (You'll need to adjust these paths based on your actual backend config locations)

# For af-south-1 - create the organized backend configs
cat > backends/aws/production/af-south-1/foundation.hcl << 'EOF'
bucket         = "your-terraform-state-bucket"  # Update with your actual bucket
key            = "providers/aws/regions/af-south-1/layers/01-foundation/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"  # Update with your actual table
EOF

cat > backends/aws/production/af-south-1/platform.hcl << 'EOF'
bucket         = "your-terraform-state-bucket"  # Update with your actual bucket
key            = "providers/aws/regions/af-south-1/layers/02-platform/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"  # Update with your actual table
EOF

# Continue for other layers...

echo "✅ Backend configs organized"
```

### **Phase 3: Copy Infrastructure Code (5 minutes)**
```bash
# Copy current working infrastructure
echo "📂 Copying infrastructure code..."
cp -r regions/ providers/aws/
cp -r modules/ providers/aws/
cp -r shared/ providers/aws/
cp -r kubernetes/ providers/aws/
cp -r examples/ providers/aws/

echo "✅ Infrastructure code copied"
```

### **Phase 4: Update Path References (10 minutes)**
```bash
# Update module source paths in copied files
echo "🔧 Updating module references..."

# Update relative paths to modules
find providers/aws -name "*.tf" -type f -exec sed -i 's|source = "\.\./\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' {} \;
find providers/aws -name "*.tf" -type f -exec sed -i 's|source = "\.\./\.\./\.\./\.\./modules/|source = "\.\./\.\./modules/|g' {} \;
find providers/aws -name "*.tf" -type f -exec sed -i 's|source = "\.\./\.\./\.\./modules/|source = "\.\./modules/|g' {} \;

# Update backend config references in terraform blocks
find providers/aws -name "*.tf" -type f -exec sed -i 's|-backend-config=.*\.hcl|-backend-config=../../../../../../backends/aws/production/af-south-1/\$(layer).hcl|g' {} \;

echo "✅ Path references updated"
```

### **Phase 5: Test New Structure (15 minutes)**
```bash
# Test that everything still works
echo "🧪 Testing new structure..."

# Test af-south-1 platform layer (your production)
cd providers/aws/regions/af-south-1/layers/02-platform/production

# Initialize with new backend config path
terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/platform.hcl

# Plan should show no changes
terraform plan

# If successful, test other layers
cd ../../../01-foundation/production
terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/foundation.hcl
terraform plan

echo "✅ New structure tested and working"
```

### **Phase 6: Clean Up Old Structure (2 minutes)**
```bash
# Only after confirming everything works
echo "🧹 Cleaning up old structure..."

# Remove old directories (only after testing!)
rm -rf regions/ modules/ shared/ kubernetes/ examples/

echo "✅ Restructure complete!"
```

---

## 📊 **Backend Benefits After Restructure**

### **✅ Better Organization:**
- All backend configs in one place: `backends/`
- Clear separation by provider: `backends/aws/`, `backends/gcp/`
- Environment separation: `production/`, `staging/`, `development/`
- Regional organization: `af-south-1/`, `us-east-1/`

### **✅ Easy Maintenance:**
```bash
# View all production backends
ls backends/aws/production/af-south-1/

# Update bucket names across all configs
sed -i 's/old-bucket-name/new-bucket-name/g' backends/aws/production/*/*.hcl

# Add new region backends
mkdir backends/aws/production/eu-west-1/
cp backends/templates/aws-production-layer.hcl backends/aws/production/eu-west-1/platform.hcl
```

### **✅ Multi-Cloud Ready:**
```bash
# When adding GCP
mkdir -p backends/gcp/production/us-central1/
cat > backends/gcp/production/us-central1/platform.hcl << 'EOF'
bucket = "gcp-terraform-state-production"
prefix = "providers/gcp/regions/us-central1/layers/02-platform/production"
EOF
```

---

## 🎯 **Commands to Execute**

```bash
# Complete migration script
#!/bin/bash
set -e

echo "🚀 Starting infrastructure restructure..."

# 1. Backup
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz . --exclude='.terraform'

# 2. Create structure  
mkdir -p providers/aws backends/aws/production/af-south-1

# 3. Copy infrastructure
cp -r regions modules shared kubernetes examples providers/aws/

# 4. Organize backends (update these paths based on your setup)
# You'll need to locate your current backend configs and copy them properly

# 5. Fix paths
find providers/aws -name "*.tf" -exec sed -i 's|../../../modules/|../../modules/|g' {} \;

# 6. Test
cd providers/aws/regions/af-south-1/layers/02-platform/production
terraform init -backend-config=../../../../../../backends/aws/production/af-south-1/platform.hcl
terraform plan

echo "✅ Restructure complete and tested!"
```

**Result: Same production functionality + Clean multi-cloud structure + Well-organized backends!** 🎉
