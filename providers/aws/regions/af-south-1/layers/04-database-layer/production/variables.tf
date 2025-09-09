# ============================================================================
# Database Layer Variables - AF-South-1 Production
# ============================================================================

# ===================================================================================
# GENERAL CONFIGURATION
# ===================================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "af-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format xx-xxxx-x (e.g., us-west-2)."
  }
}

# ===================================================================================
# INFRASTRUCTURE CONFIGURATION  
# ===================================================================================

variable "postgres_ami_id" {
  description = "AMI ID for PostgreSQL instances (Ubuntu 22.04 LTS recommended)"
  type        = string
  default     = "ami-0c9354388bb36c088" # Ubuntu 22.04 LTS in af-south-1
}

variable "key_name" {
  description = "AWS Key Pair name for EC2 instance access"
  type        = string
}

variable "master_instance_type" {
  description = "EC2 instance type for PostgreSQL master"
  type        = string
  default     = "r5.large"

  validation {
    condition = contains([
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge",
      "r6i.large", "r6i.xlarge", "r6i.2xlarge", "r6i.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.master_instance_type)
    error_message = "Instance type must be a supported memory-optimized instance."
  }
}

variable "replica_instance_type" {
  description = "EC2 instance type for PostgreSQL replica"
  type        = string
  default     = "r5.large"

  validation {
    condition = contains([
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge",
      "r6i.large", "r6i.xlarge", "r6i.2xlarge", "r6i.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge"
    ], var.replica_instance_type)
    error_message = "Instance type must be a supported memory-optimized instance."
  }
}

# ===================================================================================
# SECURITY CONFIGURATION
# ===================================================================================

variable "management_cidr_blocks" {
  description = "CIDR blocks allowed for management access (SSH)"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Adjust based on your management network
}

# ===================================================================================
# STORAGE CONFIGURATION
# ===================================================================================

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.data_volume_size >= 20 && var.data_volume_size <= 16384
    error_message = "Data volume size must be between 20 and 16384 GB."
  }
}

variable "wal_volume_size" {
  description = "Size of the WAL volume in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.wal_volume_size >= 10 && var.wal_volume_size <= 1000
    error_message = "WAL volume size must be between 10 and 1000 GB."
  }
}

variable "backup_volume_size" {
  description = "Size of the backup volume in GB"
  type        = number
  default     = 200

  validation {
    condition     = var.backup_volume_size >= 50 && var.backup_volume_size <= 16384
    error_message = "Backup volume size must be between 50 and 16384 GB."
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

# MTN Ghana Database Credentials
variable "mtn_ghana_db_password" {
  description = "Password for MTN Ghana database user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mtn_ghana_db_password) >= 12
    error_message = "Password must be at least 12 characters long."
  }
}

variable "mtn_ghana_replication_password" {
  description = "Password for MTN Ghana replication user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mtn_ghana_replication_password) >= 12
    error_message = "Replication password must be at least 12 characters long."
  }
}

# Ezra Database Credentials
variable "ezra_db_password" {
  description = "Password for Ezra database user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ezra_db_password) >= 12
    error_message = "Password must be at least 12 characters long."
  }
}

variable "ezra_replication_password" {
  description = "Password for Ezra replication user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ezra_replication_password) >= 12
    error_message = "Replication password must be at least 12 characters long."
  }
}
