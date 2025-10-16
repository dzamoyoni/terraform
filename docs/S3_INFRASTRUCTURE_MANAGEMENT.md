# S3 Infrastructure Management - Enterprise Standards

This document explains the comprehensive S3 infrastructure management system that provides graceful bucket creation, lifecycle management, and integration with your existing Terraform backend structure.

## 📋 Overview

The S3 infrastructure management system includes:

1. **S3 Bucket Management Module** - Reusable module for creating S3 buckets with enterprise features
2. **Terraform Backend State Module** - Specialized module for Terraform state storage
3. **Automation Script** - One-click provisioning of S3 infrastructure
4. **Refactored Observability Layer** - Using standardized S3 management

## 🏗️ Architecture

```
terraform/
├── modules/
│   ├── s3-bucket-management/         # ← Core S3 management module
│   ├── terraform-backend-state/      # ← Backend state infrastructure
│   └── observability-layer/          # ← Refactored to use S3 management
├── scripts/
│   └── provision-s3-infrastructure.sh # ← Automation script
└── backends/                         # ← Your existing backend configs
    └── aws/
        └── production/
            └── af-south-1/
```

## 🚀 Quick Start

### 1. Provision S3 Infrastructure for New Region

```bash
# Create backend infrastructure for us-east-1
./scripts/provision-s3-infrastructure.sh \
  --region us-east-1 \
  --environment production \
  --project-name myproject

# Create with cross-region replication
./scripts/provision-s3-infrastructure.sh \
  --region eu-west-1 \
  --environment production \
  --with-replication \
  --replica-region us-east-1

# Dry run to see what would be created
./scripts/provision-s3-infrastructure.sh \
  --region ap-southeast-1 \
  --environment staging \
  --dry-run
```

### 2. Create Only Observability Buckets

```bash
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment production \
  --observability-only
```

### 3. Create Only Backend Infrastructure

```bash
./scripts/provision-s3-infrastructure.sh \
  --region us-east-1 \
  --environment staging \
  --backend-only
```

## 📦 S3 Bucket Management Module

### Purpose-Optimized Lifecycle Policies

The module automatically applies optimized lifecycle policies based on bucket purpose:

#### Backend State Buckets
```hcl
backend-state = {
  expiration_days           = 0     # Never expire
  noncurrent_expiration     = 90    # Keep 90 days of versions
  multipart_expiration      = 7     # Clean incomplete uploads
  ia_transition_days        = 0     # Stay in Standard
  glacier_transition_days   = 0     # No Glacier
  intelligent_tiering       = false # No tiering needed
}
```

#### Logs Buckets
```hcl
logs = {
  expiration_days           = var.logs_retention_days
  noncurrent_expiration     = 7     # Fast cleanup
  multipart_expiration      = 1     # Very fast cleanup
  ia_transition_days        = 30    # Move to IA after 30 days
  glacier_transition_days   = 90    # Archive after 90 days
  intelligent_tiering       = true  # Cost optimization
}
```

#### Traces Buckets
```hcl
traces = {
  expiration_days           = var.traces_retention_days
  noncurrent_expiration     = 7     # Fast cleanup
  multipart_expiration      = 1     # Very fast cleanup
  ia_transition_days        = 30    # Move to IA after 30 days
  glacier_transition_days   = 60    # Archive faster than logs
  intelligent_tiering       = true  # Cost optimization
}
```

### Usage Examples

#### Basic S3 Bucket
```hcl
module "app_logs_bucket" {
  source = "./modules/s3-bucket-management"
  
  project_name   = "myproject"
  environment    = "production"
  region        = "af-south-1"
  bucket_purpose = "logs"
  
  logs_retention_days = 90
  enable_intelligent_tiering = true
  
  common_tags = {
    Team = "Platform"
    Cost = "Shared"
  }
}
```

#### Backend State Bucket
```hcl
module "terraform_state" {
  source = "./modules/s3-bucket-management"
  
  project_name     = "myproject"
  environment      = "production" 
  region          = "af-south-1"
  bucket_purpose  = "backend-state"
  
  # Backend state buckets are automatically:
  # - Versioning enabled
  # - Destroy protection enabled
  # - Optimized lifecycle policies applied
  
  # Optional KMS encryption
  kms_key_id = "arn:aws:kms:af-south-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  # Cross-region replication for DR
  enable_cross_region_replication = true
  replication_destination_bucket_arn = "arn:aws:s3:::cptwn-terraform-state-production-replica"
}
```

#### Advanced Configuration
```hcl
module "enterprise_logs" {
  source = "./modules/s3-bucket-management"
  
  project_name   = "cptwn"
  environment    = "production"
  region        = "af-south-1"
  bucket_purpose = "logs"
  
  # Custom lifecycle settings
  logs_retention_days = 180
  enable_intelligent_tiering = true
  enable_deep_archive = true
  
  # Security
  kms_key_id = var.logs_kms_key
  
  # Cross-region replication
  enable_cross_region_replication = true
  replication_destination_bucket_arn = var.replica_bucket_arn
  replication_storage_class = "STANDARD_IA"
  
  # Monitoring
  enable_bucket_notifications = true
  enable_eventbridge = true
  notification_topics = [
    {
      arn    = aws_sns_topic.alerts.arn
      events = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    }
  ]
  
  # Cost optimization
  enable_cost_metrics = true
  enable_intelligent_tiering = true
}
```

## 🔧 Terraform Backend State Module

### Full Backend Infrastructure

```hcl
module "backend_infrastructure" {
  source = "./modules/terraform-backend-state"
  
  project_name       = "cptwn"
  environment        = "production"
  region            = "af-south-1"
  region_short_name = "af-south"
  
  # Follows your naming convention
  custom_bucket_name   = "cptwn-terraform-state-production"
  custom_dynamodb_name = "terraform-locks-af-south"
  
  # Security
  kms_key_id = var.backend_kms_key
  prevent_destroy = true
  
  # Cross-region replication
  enable_cross_region_replication = true
  replication_destination_bucket_arn = "arn:aws:s3:::cptwn-terraform-state-production-replica"
  
  # Monitoring
  enable_backend_monitoring = true
  alarm_sns_topic_arns = [aws_sns_topic.infrastructure_alerts.arn]
  
  # Backend file generation
  generate_backend_configs = true
  backend_config_output_path = "./backends/aws"
}
```

### Generated Backend Files

The module automatically generates backend configuration files:

```
backends/aws/production/af-south-1/
├── foundation.hcl
├── platform.hcl
├── databases.hcl
├── observability.hcl
├── shared-services.hcl
└── README.md
```

Each file follows your existing pattern:
```hcl
# Backend configuration for af-south-1 platform layer
# Generated automatically by terraform-backend-state module
bucket         = "cptwn-terraform-state-production"
key            = "regions/af-south-1/layers/02-platform/production/terraform.tfstate"
region         = "af-south-1"
encrypt        = true
dynamodb_table = "terraform-locks-af-south"
```

## 📊 Refactored Observability Layer

The observability layer now uses the standardized S3 management:

### Before (Manual S3 Resources)
```hcl
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name
  # ... manual configuration
}

resource "aws_s3_bucket_versioning" "logs" {
  # ... manual versioning
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  # ... manual lifecycle
}
```

### After (Standardized S3 Management)
```hcl
module "logs_bucket" {
  source = "../s3-bucket-management"
  
  project_name     = var.project_name
  environment      = var.environment
  region          = var.region
  bucket_purpose  = "logs"
  
  # Automatic optimized configuration
  logs_retention_days = var.logs_retention_days
  enable_intelligent_tiering = var.enable_intelligent_tiering
  enable_cost_metrics = true
  
  # Enhanced security and replication
  kms_key_id = var.logs_kms_key_id
  enable_cross_region_replication = var.enable_cross_region_replication
  
  common_tags = merge(local.common_tags, {
    Purpose = "Application and Infrastructure Logs"
  })
}
```

### New Observability Variables

```hcl
variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = true
}

variable "logs_kms_key_id" {
  description = "KMS key ID for logs bucket encryption"
  type        = string
  default     = ""
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for S3 buckets"
  type        = bool
  default     = false
}
```

## 🎯 Use Cases

### 1. New Region Deployment

When expanding to a new AWS region:

```bash
# Step 1: Provision S3 infrastructure
./scripts/provision-s3-infrastructure.sh \
  --region eu-west-1 \
  --environment production \
  --with-replication \
  --replica-region us-east-1

# Step 2: Deploy your layers using generated backend configs
cd providers/aws/regions/eu-west-1/layers/01-foundation/production
terraform init -backend-config=../../../../../backends/aws/production/eu-west-1/foundation.hcl
terraform plan
terraform apply
```

### 2. Multi-Environment Setup

```bash
# Production
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment production \
  --with-replication \
  --replica-region us-east-1

# Staging  
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment staging \
  --backend-only

# Development
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment development \
  --backend-only
```

### 3. Cost Optimization Setup

```bash
# Create buckets with maximum cost optimization
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment production \
  --observability-only
  
# Buckets will automatically have:
# - Intelligent Tiering enabled
# - Optimized lifecycle policies
# - Cost metrics enabled
# - Deep Archive transitions
```

## 🔍 Monitoring and Observability

### CloudWatch Alarms

The backend state module creates monitoring alarms:

- **DynamoDB Throttles** - Alerts when state locking is throttled
- **S3 Unauthorized Access** - Monitors for unauthorized bucket access
- **Bucket Notifications** - Tracks state file changes

### Cost Optimization

Automatic cost optimization features:

- **Intelligent Tiering** - Automatically moves objects to cost-effective storage classes
- **Lifecycle Policies** - Automatically transitions and expires objects
- **Deep Archive** - Long-term archiving for compliance
- **Cost Metrics** - CloudWatch metrics for cost tracking

### Integration with Existing Infrastructure

The system integrates seamlessly with your existing setup:

- **SSM Parameters** - Stores bucket names and endpoints for other modules
- **Naming Conventions** - Follows your established patterns
- **Backend Structure** - Maintains compatibility with current backend configs
- **Tagging Standards** - Applies CPTWN standard tags

## 🚨 Best Practices

### 1. Always Use Dry Run First
```bash
./scripts/provision-s3-infrastructure.sh --region us-east-1 --dry-run
```

### 2. Enable Cross-Region Replication for Production
```bash
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --environment production \
  --with-replication \
  --replica-region us-east-1
```

### 3. Use KMS Encryption for Sensitive Data
```bash
./scripts/provision-s3-infrastructure.sh \
  --region af-south-1 \
  --kms-key-id arn:aws:kms:af-south-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

### 4. Monitor Costs Regularly
- Enable cost metrics on all buckets
- Review lifecycle policies quarterly
- Monitor intelligent tiering effectiveness

### 5. Test Disaster Recovery
- Verify cross-region replication
- Test state file recovery procedures
- Document backup and restore processes

## 🔧 Troubleshooting

### Common Issues

#### 1. Bucket Already Exists
```
Error: Backend bucket already exists: cptwn-terraform-state-production
```
**Solution:** Use `--force` flag or manually resolve the conflict

#### 2. DynamoDB Table Exists
```
Error: DynamoDB table already exists: terraform-locks-af-south
```
**Solution:** Check if table is from previous deployment or use custom naming

#### 3. Permission Denied
```
Error: Access Denied when creating S3 bucket
```
**Solution:** Verify AWS credentials have S3 and DynamoDB permissions

#### 4. Cross-Region Replication Failed
**Solution:** Ensure destination bucket exists and has proper permissions

### Debug Mode

Enable verbose logging:
```bash
export TF_LOG=DEBUG
./scripts/provision-s3-infrastructure.sh --region us-east-1 --dry-run
```

## 📚 Reference

### Module Outputs

#### S3 Bucket Management Module
- `bucket_id` - The bucket name
- `bucket_arn` - The bucket ARN
- `lifecycle_enabled` - Whether lifecycle is configured
- `compliance_status` - Compliance status with enterprise standards

#### Backend State Module
- `backend_bucket_name` - S3 bucket for state storage
- `dynamodb_table_name` - DynamoDB table for locking
- `access_policy_arn` - IAM policy for backend access

### Script Options

```bash
./scripts/provision-s3-infrastructure.sh --help
```

### Integration Examples

See the refactored `observability-layer` module for examples of integrating with the new S3 management system.

---

## 🎉 Summary

This S3 infrastructure management system provides:

✅ **Graceful bucket creation** when introducing new clusters/regions  
✅ **Automatic lifecycle management** optimized per bucket purpose  
✅ **Enterprise security** with encryption and access controls  
✅ **Cost optimization** through intelligent tiering and lifecycle policies  
✅ **Disaster recovery** via cross-region replication  
✅ **Monitoring and alerting** for operational visibility  
✅ **CPTWN standards compliance** with consistent tagging and naming  
✅ **Seamless integration** with existing Terraform backend structure  

The system eliminates the manual S3 bucket creation gap you identified and provides a production-grade foundation for scaling your infrastructure across regions and environments.