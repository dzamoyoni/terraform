# S3 Lifecycle Policy Rules and Sequencing

## 🎯 **Issue Fixed**

**Problem:** S3 lifecycle configuration error - "Days in Expiration must be greater than Days in Transition"

**Root Cause:** AWS requires that object expiration days must be **greater than** all transition days.

## 📋 **AWS S3 Lifecycle Sequencing Rules**

### **Required Order:**
```
Standard Storage → IA Transition → Glacier Transition → Expiration
     (0 days)    →   (≥30 days)   →    (≥90 days)     → (>Glacier days)
```

### **AWS Validation Rules:**
1. ✅ **IA Transition** ≥ 30 days
2. ✅ **Glacier Transition** ≥ 90 days (and > IA transition)
3. ✅ **Expiration** > ALL transition days
4. ✅ **Deep Archive** ≥ 180 days (and > Glacier transition)

## 🔧 **Fixed Configuration**

### **Before (Causing Errors):**
```hcl
logs = {
  expiration_days = 90        # ❌ Same as glacier_transition_days
  ia_transition_days = 30     # ✅ OK
  glacier_transition_days = 90 # ❌ Same as expiration_days
}

traces = {
  expiration_days = 30        # ❌ Same as ia_transition_days  
  ia_transition_days = 30     # ❌ Same as expiration_days
  glacier_transition_days = 60 # ❌ Greater than expiration_days
}
```

### **After (Fixed):**
```hcl
logs = {
  expiration_days = 365       # ✅ > glacier_transition_days (90)
  ia_transition_days = 30     # ✅ < glacier_transition_days
  glacier_transition_days = 90 # ✅ < expiration_days
}

traces = {
  expiration_days = 120       # ✅ > glacier_transition_days (60)
  ia_transition_days = 30     # ✅ < glacier_transition_days
  glacier_transition_days = 60 # ✅ < expiration_days
}
```

## 📊 **Lifecycle Policies by Bucket Type**

### **1. Backend State Buckets (`backend-state`)**
```hcl
{
  expiration_days = 0           # ✅ NEVER expire (critical data)
  ia_transition_days = 0        # ✅ Stay in Standard (fast access)
  glacier_transition_days = 0   # ✅ No archiving (immediate access)
  noncurrent_expiration_days = 90 # ✅ Keep old versions for recovery
}
```

**Rationale:** State files need immediate access and should never expire.

### **2. Logs Buckets (`logs`)**
```hcl
{
  expiration_days = 365         # ✅ Keep logs for 1 year
  ia_transition_days = 30       # ✅ Move to IA after 30 days
  glacier_transition_days = 90  # ✅ Archive after 90 days
  noncurrent_expiration_days = 7 # ✅ Quick cleanup of old versions
}
```

**Rationale:** Logs accessed frequently initially, then archived for compliance.

### **3. Traces Buckets (`traces`)**
```hcl
{
  expiration_days = 120         # ✅ Traces expire after 4 months
  ia_transition_days = 30       # ✅ Move to IA after 30 days  
  glacier_transition_days = 60  # ✅ Archive after 60 days
  noncurrent_expiration_days = 7 # ✅ Quick cleanup of old versions
}
```

**Rationale:** Traces less valuable long-term, faster archiving.

### **4. Backup Buckets (`backups`)**
```hcl
{
  expiration_days = 2555        # ✅ Keep backups for 7 years (compliance)
  ia_transition_days = 30       # ✅ Move to IA after 30 days
  glacier_transition_days = 90  # ✅ Long-term archival after 90 days
  noncurrent_expiration_days = 30 # ✅ Keep backup versions longer
}
```

**Rationale:** Backups need long retention for compliance and recovery.

## 🛡️ **Smart Defaults with Validation**

### **Dynamic Expiration Logic:**
```hcl
# Logs: Use user value if > 90, otherwise default to 365
expiration_days = var.logs_retention_days > 90 ? var.logs_retention_days : 365

# Traces: Use user value if > 60, otherwise default to 120  
expiration_days = var.traces_retention_days > 60 ? var.traces_retention_days : 120

# General: Ensure expiration > max transition days
expiration_days = var.object_expiration_days > max(var.ia_transition_days, var.glacier_transition_days) 
  ? var.object_expiration_days 
  : max(var.glacier_transition_days + 30, 365)
```

### **Updated Default Values:**
```hcl
# Previous defaults (caused errors)
logs_retention_days = 90    # ❌ Conflicted with glacier (90)
traces_retention_days = 30  # ❌ Conflicted with IA (30)

# New defaults (no conflicts)  
logs_retention_days = 365   # ✅ > glacier_transition_days (90)
traces_retention_days = 120 # ✅ > glacier_transition_days (60)
```

## 💰 **Cost Optimization Timeline**

### **Logs (365-day lifecycle):**
```
Day 0-29:  Standard Storage     ($$$$)
Day 30-89: Standard-IA          ($$$)
Day 90-364: Glacier            ($$)
Day 365:   Deleted             ($0)
```

### **Traces (120-day lifecycle):**
```
Day 0-29:  Standard Storage     ($$$$)
Day 30-59: Standard-IA          ($$$)
Day 60-119: Glacier            ($$)
Day 120:   Deleted             ($0)
```

### **Backups (7-year lifecycle):**
```
Day 0-29:   Standard Storage    ($$$$)
Day 30-89:  Standard-IA         ($$$)
Day 90-2554: Glacier           ($$)
Day 2555:   Deleted            ($0)
```

## 🔍 **Validation Commands**

### **Test Lifecycle Configuration:**
```bash
# Validate Terraform configuration
terraform validate

# Plan to see lifecycle rules
terraform plan | grep -A 20 "lifecycle_configuration"

# Check applied lifecycle rules
aws s3api get-bucket-lifecycle-configuration --bucket BUCKET-NAME
```

### **Expected Output:**
```json
{
  "Rules": [
    {
      "ID": "logs_main_lifecycle",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

## 🎯 **Key Takeaways**

### **✅ Rules to Remember:**
1. **Expiration** > **ALL transitions** (AWS requirement)
2. **Glacier** ≥ 90 days (AWS minimum)
3. **IA** ≥ 30 days (AWS minimum)
4. **Deep Archive** ≥ 180 days (AWS minimum)

### **✅ Best Practices:**
1. **Use smart defaults** - Avoid lifecycle conflicts
2. **Purpose-optimized** - Different rules per bucket type
3. **Cost-aware** - Balance access needs vs storage costs
4. **Compliance-ready** - Long retention for critical data

### **✅ Testing:**
1. Always run `terraform validate`
2. Use `terraform plan` to preview changes
3. Test with non-critical buckets first
4. Monitor costs after implementing lifecycle rules

The lifecycle policies are now **conflict-free**, **cost-optimized**, and **enterprise-ready**! 🚀