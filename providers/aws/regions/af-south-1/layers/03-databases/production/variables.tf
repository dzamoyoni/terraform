variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "af-south-1"
}

variable "project_name" {
  description = "Project name for CPTWN standards"
  type        = string
  default     = "cptwn-eks-01"
}

# Backend configuration
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "cptwn-terraform-state-ezra"
}

variable "terraform_state_region" {
  description = "AWS region for Terraform state bucket"
  type        = string
  default     = "af-south-1"
}

variable "key_name" {
  description = "AWS key pair name for EC2 instances"
  type        = string
  default     = "terraform-key" # Consistent key name across regions
}

# Client-specific configurations
variable "mtn_ghana_config" {
  description = "MTN Ghana database configuration"
  type = object({
    instance_type      = string
    volume_size        = number
    volume_type        = string
    volume_iops        = number
    backup_schedule    = string
    maintenance_window = string
  })
  default = {
    instance_type      = "r5.large"
    volume_size        = 30
    volume_type        = "io2"
    volume_iops        = 10000
    backup_schedule    = "continuous"
    maintenance_window = "sun:01:00-sun:02:00" # UTC
  }
}

# variable "orange_madagascar_config" {
#   description = "Orange Madagascar database configuration"
#   type = object({
#     instance_type    = string
#     volume_size      = number
#     volume_type      = string
#     volume_iops      = number
#     backup_schedule  = string
#     maintenance_window = string
#   })
#   default = {
#     instance_type    = "r5.large"
#     volume_size      = 30
#     volume_type      = "gp3"
#     volume_iops      = 3000
#     backup_schedule  = "hourly"
#     maintenance_window = "sun:04:00-sun:05:00"  # UTC
#   }
# }

# Security and compliance
variable "enable_encryption" {
  description = "Enable encryption for EBS volumes"
  type        = bool
  default     = false # Disabled for initial setup simplicity
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = true
}

# Backup and disaster recovery
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "enable_automated_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

# Database passwords (should be provided via environment variables or tfvars)
variable "mtn_ghana_db_password" {
  description = "MTN Ghana database password"
  type        = string
  sensitive   = true
  default     = "changeme123!" # Default for development, should be overridden
}

variable "mtn_ghana_repl_password" {
  description = "MTN Ghana database replication password"
  type        = string
  sensitive   = true
  default     = "repl_changeme123!" # Default for development, should be overridden
}

variable "orange_madagascar_db_password" {
  description = "Orange Madagascar database password"
  type        = string
  sensitive   = true
  default     = "orange_changeme123!" # Default for development, should be overridden
}

variable "orange_madagascar_repl_password" {
  description = "Orange Madagascar database replication password"
  type        = string
  sensitive   = true
  default     = "orange_repl_changeme123!" # Default for development, should be overridden
}
