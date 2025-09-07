# 🔄 State Migration Plan
## Migrating State Files to New Provider-Based Paths

**Date:** January 21, 2025  
**Goal:** Migrate all state files from old paths to new provider-consistent paths  
**Risk:** Low (using terraform's built-in state migration with backups)

---

## 🎯 **Migration Strategy**

We'll use Terraform's built-in state migration capabilities to move state files from:
- **Old Path**: `regions/af-south-1/layers/...`
- **New Path**: `providers/aws/regions/af-south-1/layers/...`

This ensures our state file locations match our new directory structure.

---

## 📋 **State Files to Migrate**

### **Current State Locations (Old)**
```
S3 Bucket: cptwn-terraform-state-ezra

├── regions/af-south-1/layers/01-foundation/production/terraform.tfstate
├── regions/af-south-1/layers/02-platform/production/terraform.tfstate  
├── regions/af-south-1/layers/03-databases/production/terraform.tfstate
└── regions/af-south-1/layers/03.5-observability/production/terraform.tfstate
```

### **Target State Locations (New)**
```
S3 Bucket: cptwn-terraform-state-ezra

├── providers/aws/regions/af-south-1/layers/01-foundation/production/terraform.tfstate
├── providers/aws/regions/af-south-1/layers/02-platform/production/terraform.tfstate
├── providers/aws/regions/af-south-1/layers/03-databases/production/terraform.tfstate
└── providers/aws/regions/af-south-1/layers/03.5-observability/production/terraform.tfstate
```

---

## 🛡️ **Safety Measures**

### **Before Migration:**
1. ✅ **Backup already exists**: `terraform-phase1-backup-20250907-084848.tar.gz`
2. 🔍 **List current state**: Document what's in each state file
3. 📊 **Validate backends**: Ensure all backend configs are ready

### **During Migration:**
1. 🔄 **Use `-migrate-state`**: Let Terraform safely copy state
2. ✅ **Verify each step**: Check state exists in new location
3. 📋 **Test immediately**: Run `terraform plan` after each migration

### **After Migration:**
1. 🧪 **Full validation**: All layers show "No changes"
2. 🧹 **Clean up**: Remove old state files once confirmed working
3. 📝 **Document**: Update team on new state locations

---

## 🔄 **Migration Steps**

### **Step 1: Update Backend Configs to New Paths**

First, let me update all backend configs to use the new provider-based paths:

```bash
# Update platform backend config
cat > /home/dennis.juma/terraform/backends/aws/production/af-south-1/platform.hcl << 'EOF'
# Backend configuration for af-south-1 platform layer
bucket         = "cptwn-terraform-state-ezra"
key            = "providers/aws/regions/af-south-1/layers/02-platform/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-locks-af-south"
EOF

# Update foundation backend config  
cat > /home/dennis.juma/terraform/backends/aws/production/af-south-1/foundation.hcl << 'EOF'
# Backend configuration for af-south-1 foundation layer
bucket         = "cptwn-terraform-state-ezra"
key            = "providers/aws/regions/af-south-1/layers/01-foundation/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-locks-af-south"
EOF

# Update databases backend config
cat > /home/dennis.juma/terraform/backends/aws/production/af-south-1/databases.hcl << 'EOF'
# Backend configuration for af-south-1 databases layer
bucket         = "cptwn-terraform-state-ezra"
key            = "providers/aws/regions/af-south-1/layers/03-databases/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-locks-af-south"
EOF

# Update observability backend config
cat > /home/dennis.juma/terraform/backends/aws/production/af-south-1/observability.hcl << 'EOF'
# Backend configuration for af-south-1 observability layer
bucket         = "cptwn-terraform-state-ezra"
key            = "providers/aws/regions/af-south-1/layers/03.5-observability/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-locks-af-south"
EOF
```

### **Step 2: Migrate Platform Layer State**

```bash
cd /home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/02-platform/production

# Initialize with old backend to connect to existing state
terraform init -backend-config=../../../../../../../../regions/af-south-1/layers/02-platform/production/backend.hcl

# Check we can access existing state
terraform state list

# Migrate to new backend location
terraform init -migrate-state -backend-config=/home/dennis.juma/terraform/backends/aws/production/af-south-1/platform.hcl

# Verify migration worked
terraform state list
terraform plan  # Should show "No changes"
```

### **Step 3: Migrate Foundation Layer State**

```bash
cd /home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/01-foundation/production

# Connect to existing state
terraform init -backend-config=../../../../../../../../regions/af-south-1/layers/01-foundation/production/backend.hcl

# Migrate to new location
terraform init -migrate-state -backend-config=/home/dennis.juma/terraform/backends/aws/production/af-south-1/foundation.hcl

# Verify
terraform plan  # Should show "No changes"
```

### **Step 4: Migrate Database Layer State**

```bash
cd /home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/03-databases/production

# Connect and migrate
terraform init -backend-config=../../../../../../../../regions/af-south-1/layers/03-databases/production/backend.hcl
terraform init -migrate-state -backend-config=/home/dennis.juma/terraform/backends/aws/production/af-south-1/databases.hcl
terraform plan  # Should show "No changes"
```

### **Step 5: Migrate Observability Layer State**

```bash
cd /home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/03.5-observability/production

# Connect and migrate
terraform init -backend-config=../../../../../../../../regions/af-south-1/layers/03.5-observability/production/backend.hcl
terraform init -migrate-state -backend-config=/home/dennis.juma/terraform/backends/aws/production/af-south-1/observability.hcl
terraform plan  # Should show "No changes"
```

---

## ✅ **Validation Checklist**

After each migration, verify:

1. **State accessible**: `terraform state list` works
2. **No changes**: `terraform plan` shows "No changes"
3. **Resources match**: Resource count matches before migration
4. **Outputs work**: `terraform output` shows expected values

---

## 🧹 **Cleanup After Successful Migration**

Once ALL layers show "No changes":

1. **Document new state locations**
2. **Update team procedures**
3. **Clean up old state files** (optional - S3 versioning keeps backups)

---

## 🎯 **Expected Results**

After migration:
- ✅ All infrastructure shows "No changes" 
- ✅ State files in consistent provider-based paths
- ✅ New directory structure fully functional
- ✅ Ready for future multi-cloud expansion
- ✅ Clean, maintainable state organization

This migration ensures your **existing production infrastructure remains unchanged** while organizing state files to match your new multi-cloud directory structure.
