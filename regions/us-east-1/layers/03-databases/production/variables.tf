variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "layer" {
  description = "Infrastructure layer name"
  type        = string
  default     = "databases"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "us-test-cluster-01"
}

# Client-specific configurations
variable "mtn_ghana_config" {
  description = "MTN Ghana database configuration"
  type = object({
    instance_type    = string
    volume_size      = number
    volume_type      = string
    volume_iops      = number
    backup_schedule  = string
    maintenance_window = string
  })
  default = {
    instance_type    = "r5.large"
    volume_size      = 50
    volume_type      = "io2"
    volume_iops      = 10000
    backup_schedule  = "continuous"
    maintenance_window = "sun:01:00-sun:02:00"
  }
}

variable "ezra_config" {
  description = "Ezra database configuration"
  type = object({
    instance_type    = string
    volume_size      = number
    volume_type      = string
    volume_iops      = number
    backup_schedule  = string
    maintenance_window = string
  })
  default = {
    instance_type    = "r5.large"
    volume_size      = 20
    volume_type      = "gp3"
    volume_iops      = 3000
    backup_schedule  = "hourly"
    maintenance_window = "sun:04:00-sun:05:00"
  }
}

# Security and compliance
variable "enable_encryption" {
  description = "Enable encryption for EBS volumes"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = "arn:aws:kms:us-east-1:101886104835:key/882843c1-8ad3-460d-90a0-3cb174c55207"
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
