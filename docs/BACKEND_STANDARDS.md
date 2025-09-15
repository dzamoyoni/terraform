# 🔒 Backend Configuration Standards

## 🎯 Overview

All Terraform layers use **direct backend.hcl files** for maximum team collaboration and zero configuration requirements.

## 👥 Team Benefits

### ✅ **Zero Configuration Required**
- **New team members**: Just clone and run - no setup needed
- **Different operating systems**: Works on Linux, macOS, and Windows  
- **CI/CD pipelines**: No special environment variables or path handling
- **IDE integration**: Works with any editor or IDE

### ✅ **Simple Commands**
```bash
# In ANY layer directory:
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### ✅ **Permanent Solution**
- **No user-specific configuration** required
- **No environment variables** to set up
- **Version controlled** - same for everyone
- **Self-documenting** - clear from file contents

## 📂 File Structure

Every production layer has a direct `backend.hcl` file:

```
providers/aws/regions/af-south-1/layers/01-foundation/production/
├── main.tf
├── backend.hcl          ← Backend configuration here
├── variables.tf
└── terraform.tfvars

providers/aws/regions/af-south-1/layers/06-shared-services/production/
├── main.tf
├── backend.hcl          ← Backend configuration here  
├── variables.tf
└── terraform.tfvars
```

## 🏷️ Standardized Naming Convention

All backend configurations follow this pattern:

```hcl
bucket = "cptwn-terraform-state-ezra"  # or "usest1-terraform-state-ezra"
key    = "providers/aws/regions/{region}/layers/{layer}/{environment}/terraform.tfstate"
region = "{region}"
encrypt = true
dynamodb_table = "terraform-locks-{region-short}"
```

### Examples:
- **AF-South Foundation**: `providers/aws/regions/af-south-1/layers/01-foundation/production/terraform.tfstate`
- **US-East Platform**: `providers/aws/regions/us-east-1/layers/02-platform/production/terraform.tfstate`
- **AF-South Shared Services**: `providers/aws/regions/af-south-1/layers/06-shared-services/production/terraform.tfstate`

## 🚀 Quick Start Guide

### For New Team Members:

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd terraform
   ```

2. **Navigate to any layer**:
   ```bash
   cd providers/aws/regions/af-south-1/layers/06-shared-services/production
   ```

3. **Initialize and run**:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform plan
   ```

**That's it!** No additional configuration needed.

## 🔧 Advanced Usage

### For CI/CD Pipelines:
```yaml
# GitHub Actions example
- name: Terraform Init
  run: terraform init -backend-config=backend.hcl
  working-directory: ${{ matrix.layer }}
```

### For Different Environments:
```bash
# Production (default)
terraform init -backend-config=backend.hcl

# Staging (when staging backend.hcl exists)
terraform init -backend-config=backend-staging.hcl
```

## 📊 State Management

### State File Locations:
- **AF-South-1**: `s3://cptwn-terraform-state-ezra/providers/aws/regions/af-south-1/layers/*/production/terraform.tfstate`
- **US-East-1**: `s3://usest1-terraform-state-ezra/providers/aws/regions/us-east-1/layers/*/production/terraform.tfstate`

### Lock Tables:
- **AF-South-1**: `terraform-locks-af-south`
- **US-East-1**: `terraform-locks-us-east-1`

## 🛠️ Maintenance

### Adding New Layers:
1. Create the layer directory structure
2. Run the standardization script:
   ```bash
   /home/dennis.juma/terraform/scripts/standardize-backends.sh
   ```

### Updating Backend Configs:
- **Individual updates**: Edit the specific `backend.hcl` file
- **Bulk updates**: Modify and re-run the standardization script

## ❓ Troubleshooting

### Common Issues:

#### "Backend configuration changed"
```bash
# Solution: Re-initialize with migration
terraform init -backend-config=backend.hcl -migrate-state
```

#### "Access denied to S3 bucket"
```bash
# Solution: Verify AWS credentials
aws sts get-caller-identity
```

#### "DynamoDB table not found"
```bash
# Solution: Verify the table exists in the correct region
aws dynamodb describe-table --table-name terraform-locks-af-south --region af-south-1
```

## 🎯 Why This Approach?

### ✅ **vs Central Backend Configs**:
- **No complex relative paths** (`../../../../../../../shared/backend-configs/...`)
- **No path breakage** when restructuring directories
- **No documentation overhead** for team members
- **No CI/CD complexity** with dynamic paths

### ✅ **vs Hardcoded Backend Blocks**:
- **Flexible**: Can switch between environments
- **Clean**: No sensitive data in code
- **Reusable**: Same pattern across all layers

### ✅ **vs Environment Variables**:
- **No setup required** for new team members
- **Version controlled**: Same configuration for everyone
- **No forgotten exports**: Works immediately after clone

## 🏆 Industry Alignment

This approach aligns with **HashiCorp's recommended practices** and is used by:
- **Netflix**: Direct backend files for service teams
- **Airbnb**: Co-located backend configurations  
- **Uber**: Standardized direct configs with automation

---

## 📞 Support

For questions about backend configurations:
1. Check this document first
2. Review the inline comments in `backend.hcl` files
3. Contact the platform team

**Last Updated**: September 15, 2025  
**Maintained by**: Platform Team
