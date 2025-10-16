# ============================================================================
# Layer 3: Database Layer Variables - US-East-2 Production
# ============================================================================
# Variables for high-availability PostgreSQL database layer with enterprise features
# Supports master-replica setup, encryption, monitoring, and client isolation
# ============================================================================

# ===================================================================================
# CORE CONFIGURATION - Project Identification
# ===================================================================================

variable "project_name" {
  description = "Project name for consistent resource naming"
  type        = string
  default     = "ohio-01-eks"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be: production, staging, or development."
  }
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

# ===================================================================================
# REMOTE STATE CONFIGURATION
# ===================================================================================

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state storage"
  type        = string
  default     = "ohio-01-terraform-state-production"
}

variable "terraform_state_region" {
  description = "AWS region where Terraform state bucket is located"
  type        = string
  default     = "us-east-2"
}

# ===================================================================================
# INFRASTRUCTURE CONFIGURATION - Database Instances
# ===================================================================================

variable "postgres_ami_id" {
  description = "AMI ID for PostgreSQL instances (pre-configured PostgreSQL AMI)"
  type        = string
  default     = "ami-0bb7d855677353076" # PostgreSQL AMI in us-east-2
}

variable "key_name" {
  description = "AWS Key Pair name for EC2 instance access"
  type        = string
  default     = "ohio-01-keypair"
}

variable "master_instance_type" {
  description = "EC2 instance type for PostgreSQL master (memory-optimized for production)"
  type        = string
  default     = "r5.large"

  validation {
    condition = contains([
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge",
      "r6i.large", "r6i.xlarge", "r6i.2xlarge", "r6i.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.master_instance_type)
    error_message = "Instance type must be a supported memory-optimized instance for database workloads."
  }
}

variable "replica_instance_type" {
  description = "EC2 instance type for PostgreSQL replica (can be smaller than master)"
  type        = string
  default     = "r5.large"

  validation {
    condition = contains([
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge",
      "r6i.large", "r6i.xlarge", "r6i.2xlarge", "r6i.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.replica_instance_type)
    error_message = "Instance type must be a supported memory-optimized instance for database workloads."
  }
}

# ===================================================================================
# SECURITY CONFIGURATION - Network Access Control
# ===================================================================================

variable "management_cidr_blocks" {
  description = "CIDR blocks allowed for management access (SSH, monitoring)"
  type        = list(string)
  default     = [
    "102.217.4.85/32",   # Your management IP
    "165.90.14.138/32",  # Backup management IP
    "178.162.141.130/32", # Additional management IP
    "41.72.206.78/32"    # Secondary management IP
  ]
}

# ===================================================================================
# STORAGE CONFIGURATION
# ===================================================================================

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.data_volume_size >= 20 && var.data_volume_size <= 16384
    error_message = "Data volume size must be between 20 and 16384 GB."
  }
}

variable "wal_volume_size" {
  description = "Size of the WAL volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.wal_volume_size >= 10 && var.wal_volume_size <= 1000
    error_message = "WAL volume size must be between 10 and 1000 GB."
  }
}

variable "backup_volume_size" {
  description = "Size of the backup volume in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.backup_volume_size >= 20 && var.backup_volume_size <= 16384
    error_message = "Backup volume size must be between 20 and 16384 GB."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

# ===================================================================================
# CLIENT-SPECIFIC SECRETS (Use sensitive variables)
# ===================================================================================

# EST Test A Database Credentials
variable "est_test_a_db_password" {
  description = "Password for EST Test A database user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.est_test_a_db_password) >= 12
    error_message = "Password must be at least 12 characters long."
  }
}

variable "est_test_a_replication_password" {
  description = "Password for EST Test A replication user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.est_test_a_replication_password) >= 12
    error_message = "Replication password must be at least 12 characters long."
  }
}

# EST Test B Database Credentials (Reserved for future use)
variable "est_test_b_db_password" {
  description = "Password for EST Test B database user (reserved for future use)"
  type        = string
  sensitive   = true
  default     = "TempPassword123!"

  validation {
    condition     = length(var.est_test_b_db_password) >= 12
    error_message = "Password must be at least 12 characters long."
  }
}

variable "est_test_b_replication_password" {
  description = "Password for EST Test B replication user (reserved for future use)"
  type        = string
  sensitive   = true
  default     = "TempReplPassword123!"

  validation {
    condition     = length(var.est_test_b_replication_password) >= 12
    error_message = "Replication password must be at least 12 characters long."
  }
}
