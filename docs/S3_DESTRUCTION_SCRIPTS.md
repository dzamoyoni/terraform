# S3 Bucket Destruction Scripts - Complete Guide

## 🎯 **Overview**

You now have **3 powerful scripts** to safely destroy S3 buckets and related infrastructure, each designed for different scenarios:

### **📜 Available Scripts:**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **`destroy-s3-buckets.sh`** | **General bucket destruction** | Manual cleanup, specific buckets |
| **`terraform-destroy-s3.sh`** | **Terraform-integrated destruction** | Normal Terraform-managed cleanup |
| **`emergency-s3-cleanup.sh`** | **Emergency forceful cleanup** | When Terraform is broken/corrupted |

## 🛠️ **Script 1: General Bucket Destruction**

### **File:** `scripts/destroy-s3-buckets.sh`

**Best for:** Manual cleanup of specific buckets, testing, or when you know exact bucket names.

### **Key Features:**
- ✅ Handles versioned objects and delete markers
- ✅ Cleans up multipart uploads
- ✅ Supports encrypted objects
- ✅ Special handling for backend state buckets
- ✅ Optional backup before deletion
- ✅ Dry run capability

### **Usage Examples:**

```bash
# Destroy all project buckets (with confirmation)
./scripts/destroy-s3-buckets.sh --type all

# Destroy only logs bucket
./scripts/destroy-s3-buckets.sh --type logs --region us-east-1

# Destroy specific bucket by name
./scripts/destroy-s3-buckets.sh --bucket myproject-us-east-1-logs-production

# Test what would be deleted (safe)
./scripts/destroy-s3-buckets.sh --type all --dry-run

# Force delete with backup
./scripts/destroy-s3-buckets.sh --type all --force --backup

# Destroy backend state (requires special confirmation)
./scripts/destroy-s3-buckets.sh --type backend-state
```

### **Options:**
```bash
-r, --region REGION         AWS region (default: us-east-1)
-e, --environment ENV       Environment (default: production)  
-p, --project PROJECT       Project name (default: myproject)
-b, --bucket BUCKET         Specific bucket name
-t, --type TYPE             Bucket type (logs|traces|backups|backend-state|all)

--dry-run                   Show what would be deleted
--force                     Skip safety checks
--skip-confirmation         Skip interactive prompts
--backup                    Backup before deletion
--verbose                   Enable verbose output
```

## 🔧 **Script 2: Terraform-Integrated Destruction**

### **File:** `scripts/terraform-destroy-s3.sh`

**Best for:** Normal infrastructure destruction using Terraform, then cleaning up anything Terraform couldn't handle.

### **Key Features:**
- ✅ Uses `terraform destroy` first (proper approach)
- ✅ Backs up Terraform state automatically
- ✅ Cleans up remaining resources Terraform couldn't delete
- ✅ Integrates with your existing Terraform workflow
- ✅ Supports targeting specific modules
- ✅ Full verification of destruction

### **Process Flow:**
1. **Backup** Terraform state files
2. **Plan** destruction with `terraform plan -destroy`
3. **Execute** `terraform destroy`
4. **Cleanup** remaining objects/versions
5. **Verify** complete destruction

### **Usage Examples:**

```bash
# Destroy all Terraform-managed S3 infrastructure
./scripts/terraform-destroy-s3.sh

# Destroy only the logs bucket module
./scripts/terraform-destroy-s3.sh --target module.logs_bucket

# Dry run to see Terraform destroy plan
./scripts/terraform-destroy-s3.sh --dry-run

# Auto-approve destruction (use with caution!)
./scripts/terraform-destroy-s3.sh --auto-approve

# Use custom Terraform directory
./scripts/terraform-destroy-s3.sh --terraform-dir ./infrastructure/custom-s3
```

### **Options:**
```bash
-d, --terraform-dir DIR     Terraform directory (default: infrastructure/s3-provisioning)
-t, --target TARGET         Specific Terraform target (e.g., module.logs_bucket)

--dry-run                   Show Terraform destroy plan
--auto-approve              Skip Terraform confirmations
--skip-state-backup         Skip backing up state files
--verbose                   Enable verbose output
```

## 🚨 **Script 3: Emergency Cleanup**

### **File:** `scripts/emergency-s3-cleanup.sh`

**Best for:** Emergency situations when Terraform state is corrupted, missing, or when normal destruction fails.

### **⚠️ CRITICAL WARNING:**
This script **bypasses ALL Terraform safety checks** and **forcefully deletes** resources!

### **When to Use:**
- 🚨 Terraform state is corrupted
- 🚨 Normal `terraform destroy` fails
- 🚨 Infrastructure is in inconsistent state
- 🚨 You need to manually force cleanup

### **Key Features:**
- 🔍 Auto-discovers buckets by project pattern
- 💾 Emergency backup capability
- 🧨 Force deletion of everything
- 🗄️ Cleans up related DynamoDB tables
- 🚀 Nuclear option for complete cleanup

### **Usage Examples:**

```bash
# Emergency cleanup with backup (RECOMMENDED)
./scripts/emergency-s3-cleanup.sh --project myproject --backup --dry-run

# Force cleanup without backup (DANGEROUS)
./scripts/emergency-s3-cleanup.sh --project myproject --force

# Nuclear option - delete ALL matching buckets
./scripts/emergency-s3-cleanup.sh --project myproject --nuclear --force

# Test emergency discovery
./scripts/emergency-s3-cleanup.sh --project myproject --dry-run
```

### **Options:**
```bash
-p, --project PROJECT       Project name pattern to match (REQUIRED)
-r, --region REGION         AWS region
-a, --account-id ACCOUNT    AWS account ID for safety validation

--dry-run                   Show what would be deleted
--force                     Force deletion without prompts
--backup                    Backup all contents before deletion
--nuclear                   Delete ALL matching buckets (DANGEROUS!)
--verbose                   Enable verbose output
```

### **Confirmation Requirements:**
- **Normal mode:** Type `EMERGENCY-DELETE-S3-BUCKETS`
- **Nuclear mode:** Type `NUCLEAR-DELETE-EVERYTHING`

## 🎯 **Which Script Should You Use?**

### **🟢 Normal Workflow (RECOMMENDED):**
```bash
# Step 1: Use Terraform-integrated script
./scripts/terraform-destroy-s3.sh --dry-run
./scripts/terraform-destroy-s3.sh
```

### **🟡 Specific Cleanup:**
```bash
# Use general destruction script
./scripts/destroy-s3-buckets.sh --type logs --dry-run
./scripts/destroy-s3-buckets.sh --type logs
```

### **🔴 Emergency Situation:**
```bash
# Use emergency cleanup script
./scripts/emergency-s3-cleanup.sh --project myproject --backup --dry-run
./scripts/emergency-s3-cleanup.sh --project myproject --backup --force
```

## 🔐 **Safety Features Across All Scripts**

### **✅ Built-in Safety Checks:**
1. **AWS CLI validation** - Ensures proper AWS configuration
2. **Account verification** - Confirms you're in the right AWS account
3. **Interactive confirmations** - Prevents accidental deletions
4. **Dry run mode** - Test without making changes
5. **Backup options** - Save data before deletion
6. **Progress logging** - Clear visibility of operations
7. **Error handling** - Graceful handling of failures

### **✅ Special Backend State Protection:**
- **Extra confirmation** required for backend state buckets
- **Automatic backup** of Terraform state files
- **Warning messages** about losing Terraform management capability

## 📁 **What Gets Backed Up?**

When using `--backup` option, scripts save:

### **📦 Bucket Contents:**
- All current object versions
- Object metadata and configurations
- Versioned objects (if versioning enabled)
- Delete markers

### **⚙️ Bucket Configurations:**
- Lifecycle policies
- Versioning settings
- Encryption configurations
- Replication settings
- Notification configurations
- IAM policies and tags

### **💾 Backup Locations:**
- **General script:** `backups/bucket-contents-YYYYMMDD-HHMMSS/`
- **Terraform script:** `backups/terraform-destroy-YYYYMMDD-HHMMSS/`
- **Emergency script:** `backups/emergency-cleanup-YYYYMMDD-HHMMSS/`

## 🧪 **Testing and Validation**

### **Always Test First:**
```bash
# Test with dry run
./scripts/destroy-s3-buckets.sh --type all --dry-run
./scripts/terraform-destroy-s3.sh --dry-run
./scripts/emergency-s3-cleanup.sh --project myproject --dry-run
```

### **Validate AWS Configuration:**
```bash
# Check current AWS identity
aws sts get-caller-identity

# List current S3 buckets
aws s3api list-buckets --query 'Buckets[].Name' --output table
```

## 🔄 **Recovery and Restoration**

### **If You Need to Restore:**

1. **Check backup directory** for saved data
2. **Use AWS CLI** to recreate buckets:
   ```bash
   aws s3 mb s3://bucket-name --region your-region
   ```
3. **Restore objects** from backup:
   ```bash
   aws s3 sync ./backup-path/bucket-name/data/ s3://bucket-name/
   ```
4. **Reconfigure bucket settings** using saved JSON configs

### **If Terraform State is Lost:**
1. **Recreate backend state** bucket
2. **Import existing resources** into new Terraform state:
   ```bash
   terraform import aws_s3_bucket.example bucket-name
   ```

## ⚠️ **Critical Warnings**

### **🚨 NEVER:**
- Run scripts in production without testing first
- Use `--force` or `--nuclear` options carelessly
- Forget to backup critical data
- Ignore the confirmation prompts

### **🚨 ALWAYS:**
- Use `--dry-run` first to see what will happen
- Backup important data before destruction
- Verify you're in the correct AWS account
- Read the script output carefully

### **🚨 REMEMBER:**
- Backend state buckets contain **critical Terraform state**
- Once deleted, **data cannot be recovered** without backups
- Emergency script **bypasses all Terraform safety checks**

## 🆘 **Troubleshooting**

### **Common Issues:**

**❌ "Access Denied" errors:**
```bash
# Check AWS permissions
aws iam get-user
aws sts get-caller-identity
```

**❌ Buckets won't delete:**
```bash
# Check for remaining objects
aws s3api list-objects-v2 --bucket bucket-name
aws s3api list-object-versions --bucket bucket-name
```

**❌ Terraform state issues:**
```bash
# Check Terraform state
terraform state list
terraform state show resource-name
```

**❌ DynamoDB table deletion fails:**
```bash
# Check table status
aws dynamodb describe-table --table-name table-name
```

## 🎉 **Success!**

You now have **enterprise-grade S3 destruction scripts** that handle all the complexities of AWS S3 cleanup:

- ✅ **3 specialized scripts** for different scenarios
- ✅ **Comprehensive safety checks** and confirmations
- ✅ **Backup and recovery** capabilities
- ✅ **Dry run testing** for safe operations
- ✅ **Enterprise-ready** error handling and logging

**These scripts ensure you can safely destroy S3 infrastructure when needed, while protecting against accidental data loss!** 🚀