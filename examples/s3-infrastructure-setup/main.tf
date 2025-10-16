# ============================================================================
# S3 Infrastructure Management Example - Enterprise Standards
# ============================================================================
# This example demonstrates how to use the new S3 infrastructure management
# system to provision backend state buckets and observability buckets
# following CPTWN standards.
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "af-south-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "myproject"
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project      = "myproject"
    Environment  = "production"
    ManagedBy    = "Terraform"
    Architecture = "Multi-Client"
    Example      = "S3-Infrastructure-Setup"
  }
}

# ============================================================================
# Backend State Infrastructure
# ============================================================================

module "backend_infrastructure" {
  source = "../../modules/terraform-backend-state"

  project_name      = var.project_name
  environment       = var.environment
  region            = var.aws_region
  region_short_name = "af-south"

  # Custom naming following CPTWN conventions
  custom_bucket_name   = "${var.project_name}-terraform-state-${var.environment}"
  custom_dynamodb_name = "terraform-locks-af-south"

  # Security configuration
  prevent_destroy = true

  # Monitoring and alerting
  enable_backend_monitoring = true
  enable_state_monitoring   = true

  # Backend configuration file generation
  generate_backend_configs   = true
  backend_config_output_path = "../../backends/aws"

  # IAM policy creation
  create_access_policy = true

  # Common tags
  common_tags = var.common_tags
}

# ============================================================================
# Observability S3 Buckets
# ============================================================================

# Logs bucket with cost optimization
module "logs_bucket" {
  source = "../../modules/s3-bucket-management"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.aws_region
  bucket_purpose = "logs"

  # Lifecycle configuration optimized for logs
  logs_retention_days        = 90
  enable_intelligent_tiering = true
  enable_cost_metrics        = true

  # Security
  enable_versioning = true

  # Common tags
  common_tags = merge(var.common_tags, {
    Purpose = "Application-and-Infrastructure-Logs"
    Type    = "Logs"
  })
}

# Traces bucket with faster archiving
module "traces_bucket" {
  source = "../../modules/s3-bucket-management"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.aws_region
  bucket_purpose = "traces"

  # Lifecycle configuration optimized for traces
  traces_retention_days      = 30
  enable_intelligent_tiering = true
  enable_cost_metrics        = true

  # Security
  enable_versioning = true

  # Common tags
  common_tags = merge(var.common_tags, {
    Purpose = "Distributed-Traces"
    Type    = "Traces"
  })
}

# ============================================================================
# Backup buckets for different purposes
# ============================================================================

# Database backups with long retention
module "database_backups_bucket" {
  source = "../../modules/s3-bucket-management"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.aws_region
  bucket_purpose = "backups"

  # Long-term retention for compliance
  backup_retention_days      = 2555 # 7 years
  enable_intelligent_tiering = true
  enable_deep_archive        = true
  enable_cost_metrics        = true

  # Enhanced security for backups
  enable_versioning = true

  # Common tags
  common_tags = merge(var.common_tags, {
    Purpose    = "Database-Backups"
    Type       = "Backups"
    Compliance = "7-Year-Retention"
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "backend_infrastructure" {
  description = "Backend infrastructure details"
  value = {
    bucket_name    = module.backend_infrastructure.backend_bucket_name
    bucket_arn     = module.backend_infrastructure.backend_bucket_arn
    dynamodb_table = module.backend_infrastructure.dynamodb_table_name
    region         = var.aws_region
  }
}

output "observability_buckets" {
  description = "Observability buckets details"
  value = {
    logs_bucket = {
      name = module.logs_bucket.bucket_id
      arn  = module.logs_bucket.bucket_arn
    }
    traces_bucket = {
      name = module.traces_bucket.bucket_id
      arn  = module.traces_bucket.bucket_arn
    }
  }
}

output "backup_buckets" {
  description = "Backup buckets details"
  value = {
    database_backups = {
      name = module.database_backups_bucket.bucket_id
      arn  = module.database_backups_bucket.bucket_arn
    }
  }
}

output "compliance_status" {
  description = "Enterprise compliance status for all buckets"
  value = {
    logs_bucket    = module.logs_bucket.compliance_status
    traces_bucket  = module.traces_bucket.compliance_status
    backups_bucket = module.database_backups_bucket.compliance_status
  }
}

output "next_steps" {
  description = "Next steps after infrastructure creation"
  value = {
    backend_configs = "Generated in ../../backends/aws/${var.environment}/${var.aws_region}/"
    usage_command   = "terraform init -backend-config=../../backends/aws/${var.environment}/${var.aws_region}/foundation.hcl"
    documentation   = "See ../../docs/S3_INFRASTRUCTURE_MANAGEMENT.md"
  }
}