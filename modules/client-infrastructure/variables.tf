# Variables for Client Infrastructure Module

# ===================================================================================
# CORE CONFIGURATION
# ===================================================================================

variable "client_name" {
  description = "Unique identifier for the client (e.g., mtn-ghana, ezra)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "Client name must be lowercase alphanumeric with hyphens only."
  }
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "aws_region" {
  description = "AWS region for client resources"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# ===================================================================================
# CLIENT CONFIGURATION
# ===================================================================================

variable "client_config" {
  description = "Complete client configuration object"
  type = object({
    enabled = bool
    
    # Basic client information
    full_name       = string
    business_unit   = string
    cost_center     = string
    owner_team      = string
    data_class      = string
    
    # Database configuration
    database = object({
      enabled                = bool
      instance_type          = string
      port                   = number
      root_volume_size       = number
      root_volume_type       = string
      root_volume_encrypted  = bool
      root_volume_iops      = optional(number)
      root_volume_throughput = optional(number)
      project_name          = string
      maintenance_window    = string
      subnet_index          = number
      criticality_level     = string
      
      # Security settings
      security = object({
        disable_api_termination = bool
        disable_api_stop       = bool
        enable_monitoring      = bool
        shutdown_behavior      = string
      })
      
      # Extra volumes for database storage
      extra_volumes = list(object({
        device_name = string
        size        = number
        type        = string
        encrypted   = bool
        iops        = optional(number)
        throughput  = optional(number)
      }))
    })
    
    # Application servers configuration
    applications = map(object({
      enabled               = bool
      instance_type        = string
      root_volume_size     = number
      root_volume_type     = string
      subnet_index         = number
      maintenance_window   = string
      criticality_level    = string
      
      # Extra volumes for applications
      extra_volumes = list(object({
        device_name = string
        size        = number
        type        = string
        encrypted   = bool
        iops        = optional(number)
        throughput  = optional(number)
      }))
    }))
    
    # Custom ports configuration
    custom_ports = list(object({
      port        = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
    }))
    
    # Monitoring configuration
    monitoring = object({
      enabled                = bool
      cloudwatch_detailed    = bool
      custom_metrics        = bool
      alerting_email        = string
    })
    
    # Backup configuration
    backup = object({
      enabled            = bool
      schedule          = string
      time              = string
      retention_days    = number
      cross_region_copy = bool
    })
  })
  
  validation {
    condition     = var.client_config.enabled == true
    error_message = "Client must be enabled to use this module."
  }
}

# ===================================================================================
# NETWORKING CONFIGURATION
# ===================================================================================

variable "vpc_id" {
  description = "ID of the VPC where client resources will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs (if needed)"
  type        = list(string)
  default     = []
}

variable "additional_security_groups" {
  description = "Additional security groups to attach to client resources"
  type        = list(string)
  default     = []
}

# ===================================================================================
# VPN CONFIGURATION (Optional)
# ===================================================================================

variable "enable_vpn_access" {
  description = "Enable VPN access to client resources"
  type        = bool
  default     = false
}

variable "vpn_client_cidrs" {
  description = "CIDR blocks for VPN client access"
  type        = list(string)
  default     = []
}

# ===================================================================================
# EC2 CONFIGURATION
# ===================================================================================

variable "database_ami_id" {
  description = "AMI ID for database servers"
  type        = string
}

variable "application_ami_id" {
  description = "AMI ID for application servers"
  type        = string
}

variable "ec2_key_name" {
  description = "Name of the EC2 key pair for instance access"
  type        = string
}

# ===================================================================================
# BACKUP AND LIFECYCLE
# ===================================================================================

variable "dlm_role_arn" {
  description = "ARN of the DLM (Data Lifecycle Manager) IAM role"
  type        = string
  default     = ""
}

# ===================================================================================
# TAGS AND METADATA
# ===================================================================================

variable "common_tags" {
  description = "Common tags to apply to all client resources"
  type        = map(string)
  default     = {}
}

# ===================================================================================
# FEATURE FLAGS
# ===================================================================================

variable "enable_monitoring_dashboard" {
  description = "Create CloudWatch dashboard for the client"
  type        = bool
  default     = true
}

variable "enable_backup_automation" {
  description = "Enable automated backup policies"
  type        = bool
  default     = true
}

variable "enable_cost_allocation_tags" {
  description = "Add detailed cost allocation tags"
  type        = bool
  default     = true
}

variable "enable_compliance_monitoring" {
  description = "Enable compliance monitoring and alerting"
  type        = bool
  default     = false
}

# ===================================================================================
# ADVANCED CONFIGURATION
# ===================================================================================

variable "client_isolation_level" {
  description = "Level of client isolation (none, basic, strict)"
  type        = string
  default     = "basic"
  
  validation {
    condition     = contains(["none", "basic", "strict"], var.client_isolation_level)
    error_message = "Client isolation level must be one of: none, basic, strict."
  }
}

variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for application servers"
  type        = bool
  default     = false
}

variable "disaster_recovery_enabled" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = false
}

# ===================================================================================
# VALIDATION AND CONSTRAINTS
# ===================================================================================

variable "resource_limits" {
  description = "Resource limits and quotas for the client"
  type = object({
    max_database_instances   = number
    max_application_instances = number
    max_storage_gb          = number
    max_monthly_cost_usd    = number
  })
  default = {
    max_database_instances   = 5
    max_application_instances = 10
    max_storage_gb          = 1000
    max_monthly_cost_usd    = 1000
  }
}

variable "allowed_instance_types" {
  description = "List of allowed EC2 instance types for this client"
  type        = list(string)
  default = [
    "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge",
    "t3a.micro", "t3a.small", "t3a.medium", "t3a.large", "t3a.xlarge",
    "m5.large", "m5.xlarge", "m5.2xlarge",
    "r5.large", "r5.xlarge", "r5.2xlarge",
    "c5.large", "c5.xlarge", "c5.2xlarge"
  ]
}
