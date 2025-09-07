# Backend Configuration Cleanup Plan

## Current State Analysis

### Existing S3 Buckets:
- `cptwn-terraform-state-ezra` (AF-South-1 region)
- `usest1-terraform-state-ezra` (US-East-1 region)
- `cptwn-terraform-state-ezra-access-logs` (logging bucket)

### Existing DynamoDB Tables:
- `terraform-locks` (US-East-1)
- `terraform-locks-af-south` (AF-South-1)

## Standardization Plan

### ✅ Correct Configurations:
- AF-South-1 files: Use `cptwn-terraform-state-ezra` + `terraform-locks-af-south`
- US-East-1 files: Use `usest1-terraform-state-ezra` + `terraform-locks`

### 🔧 Files to Fix:
1. **us-east-foundation-production.hcl** - ✅ Already correct
2. **us-east-platform-production.hcl** - ✅ Already correct
3. **us-east-database-production.hcl** - ✅ Fixed
4. **us-east-client-production.hcl** - ✅ Already correct

### 🗑️ Files to Remove (Redundant):
1. `databases-production.hcl` (superseded by `us-east-database-production.hcl`)
2. `foundation-production.hcl` (superseded by `us-east-foundation-production.hcl`)
3. `platform-production.hcl` (superseded by `us-east-platform-production.hcl`)
4. `client-production.hcl` (superseded by `us-east-client-production.hcl`)
5. `production.hcl` (generic, not region-specific)

### 📝 Naming Convention:
- Format: `{region}-{layer}-{environment}.hcl`
- Examples:
  - `us-east-foundation-production.hcl`
  - `af-south-database-production.hcl`

### 🔑 Key Format Standardization:
- US-East-1: `regions/us-east-1/layers/{layer-number}-{layer-name}/{environment}/terraform.tfstate`
- AF-South-1: `regions/af-south-1/layers/{layer-number}-{layer-name}/{environment}/terraform.tfstate`

## Implementation Status
- ✅ us-east-database-production.hcl - Updated and validated
- ⏳ Cleanup of redundant files - Pending approval
- ⏳ Update layer configurations to use shared backends - In progress
