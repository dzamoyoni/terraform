# S3 Scripts - Project-Agnostic with Auto-Detection

## 🎯 **Overview**

The S3 destruction scripts are now **100% project-agnostic** and **automatically detect** your project configuration from Terraform files, AWS settings, and environment variables. No more hard-coded project names!

## 🤖 **Auto-Detection Features**

### **✅ What Gets Auto-Detected:**
- 🏷️ **Project Name** - From Terraform variables or directory structure
- 🌍 **AWS Region** - From AWS CLI config, environment vars, or Terraform
- 🏢 **Environment** - From Terraform variables or environment vars
- 🆔 **AWS Account ID** - From current AWS credentials

### **🔍 Detection Sources (In Priority Order):**

#### **Project Name Detection:**
1. `project_name` variable in Terraform files
2. Alternative variables: `project`, `app_name`, `application`
3. Current directory name (if not generic)
4. Parent directory name
5. Default fallback: `myproject`

#### **Region Detection:**
1. AWS CLI configuration (`aws configure get region`)
2. Environment variable `AWS_DEFAULT_REGION`
3. Terraform provider configuration
4. Default fallback: `us-east-1`

#### **Environment Detection:**
1. `environment` variable in Terraform files
2. Environment variables `ENVIRONMENT` or `ENV`
3. Default fallback: `production`

## 🧪 **Testing Auto-Detection**

### **Test Configuration Detection:**
```bash
# Test the auto-detection system
./scripts/s3-config.sh
```

**Example Output:**
```
🧪 Testing S3 Configuration Detection
=====================================
🔍 Auto-detecting project configuration...
📋 Detected configuration:
   Project: ohio-01
   Region: us-east-1
   Environment: production
   AWS Account: 630649313435

Standard bucket names:
ohio-01-us-east-1-logs-production
ohio-01-us-east-1-traces-production
ohio-01-us-east-1-backups-production
ohio-01-terraform-state-production
```

## 🚀 **Usage - Now Fully Automatic!**

### **Simple Usage (Auto-Detection):**
```bash
# Auto-detects everything from your Terraform configuration
./scripts/destroy-s3-buckets.sh --type all --dry-run

# Auto-detects and destroys using Terraform
./scripts/terraform-destroy-s3.sh --dry-run

# Emergency cleanup with auto-detected project
./scripts/emergency-s3-cleanup.sh --project $(./scripts/s3-config.sh 2>/dev/null | cut -d',' -f1) --dry-run
```

### **Manual Override (If Needed):**
```bash
# Override auto-detection if needed
./scripts/destroy-s3-buckets.sh --project custom-project --region eu-west-1 --type all --dry-run
```

## 📁 **Auto-Detection Search Paths**

The scripts automatically search these directories for Terraform configuration:

```
./infrastructure/s3-provisioning/     # Primary location
./examples/s3-infrastructure-setup/   # Example configurations
./infrastructure/                     # General infrastructure
./terraform/                         # Terraform root
./                                   # Current directory
```

## 🔧 **Configuration File: `s3-config.sh`**

The new configuration file provides:

### **🎯 Core Functions:**
- `auto_detect_project_configuration()` - Main detection function
- `generate_standard_bucket_names()` - Creates bucket names from project info
- `discover_existing_s3_buckets()` - Finds existing buckets
- `validate_aws_access()` - Checks AWS CLI setup

### **Example Usage in Your Scripts:**
```bash
# Source the configuration
source ./scripts/s3-config.sh

# Auto-detect configuration
IFS=',' read -r project region environment account <<< "$(auto_detect_project_configuration 2>/dev/null)"

# Generate standard bucket names
mapfile -t buckets < <(generate_standard_bucket_names "$project" "$region" "$environment")
```

## 📊 **What Changed from Hard-Coded**

### **Before (Hard-Coded):**
```bash
# Hard-coded values
DEFAULT_PROJECT="ohio-01"
DEFAULT_REGION="us-east-2" 
bucket_patterns=("ohio-01-us-east-2-logs-production")
```

### **After (Auto-Detection):**
```bash
# Auto-detected values
detected_config=$(auto_detect_project_configuration)
IFS=',' read -r project region environment <<< "$detected_config"
bucket_patterns=("${project}-${region}-logs-${environment}")
```

## 🛡️ **Safety Features Enhanced**

### **✅ New Safety Checks:**
- **Account Validation** - Ensures you're in the correct AWS account
- **Configuration Verification** - Shows detected values before proceeding
- **Fallback Defaults** - Sensible defaults if detection fails
- **Multi-Source Detection** - Multiple methods to find configuration

### **⚠️ Confirmation with Detected Values:**
```
🔍 Auto-detecting project configuration...
📋 Detected configuration:
   Project: ohio-01
   Region: us-east-1
   Environment: production
   AWS Account: 630649313435

⚠️  WARNING: This will destroy S3 buckets for project 'ohio-01'
Are you sure you want to continue? (y/N):
```

## 🎯 **Smart Defaults**

If auto-detection fails, the scripts use these sensible defaults:

```bash
DEFAULT_SETTINGS=(
    ["region"]="us-east-1"       # Most common AWS region
    ["environment"]="production"  # Typical environment name
    ["project"]="myproject"      # Generic project name
    ["account_id"]=""            # Detected from AWS credentials
)
```

## 🚀 **Benefits of Auto-Detection**

### **✅ For Developers:**
- 🚫 **No hard-coding** - Works with any project
- 🤖 **Zero configuration** - Detects settings automatically  
- 🔄 **Portable scripts** - Move between projects seamlessly
- 📋 **Consistent naming** - Follows your Terraform conventions

### **✅ For Teams:**
- 👥 **Team-friendly** - Everyone uses same script
- 🏢 **Multi-project support** - Works across all projects
- 🔧 **Easy maintenance** - One script for all environments
- 📖 **Self-documenting** - Shows detected configuration

### **✅ For Operations:**
- 🛡️ **Enhanced safety** - Shows what will be affected
- 🔍 **Better visibility** - Clear detection output
- ⚡ **Faster execution** - No manual parameter entry
- 🎯 **Reduced errors** - Fewer manual mistakes

## 📚 **Complete Example Workflow**

```bash
# 1. Test auto-detection first
./scripts/s3-config.sh

# 2. Test what would be destroyed (safe)
./scripts/terraform-destroy-s3.sh --dry-run

# 3. Execute destruction with auto-detection
./scripts/terraform-destroy-s3.sh

# 4. Verify cleanup completed
aws s3api list-buckets --query 'Buckets[].Name' --output table
```

## 🎉 **Summary**

Your S3 destruction scripts are now **enterprise-ready** and **project-agnostic**:

- ✅ **No more hard-coded project names**
- ✅ **Intelligent auto-detection** from multiple sources
- ✅ **Fallback defaults** for reliability
- ✅ **Enhanced safety checks** with detected values
- ✅ **Portable across any project** or environment
- ✅ **Team-friendly** - works for everyone
- ✅ **Future-proof** - adapts to any project structure

**The scripts now automatically detect your project settings and work seamlessly across any AWS environment!** 🚀