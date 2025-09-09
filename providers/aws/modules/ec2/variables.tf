# ============================================================================
# EC2 Module Variables
# ============================================================================
# Comprehensive variable definitions for flexible EC2 instance creation
# supporting various workloads: databases, applications, compute nodes
# ============================================================================

# ===================================================================================
# CORE INSTANCE CONFIGURATION
# ===================================================================================

variable "name" {
  description = "Name for the EC2 instance and associated resources"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID of the subnet where the instance will be launched"
  type        = string
}

variable "security_groups" {
  description = "List of security group IDs to attach to the instance"
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = false
}

# ===================================================================================
# STORAGE CONFIGURATION
# ===================================================================================

variable "volume_type" {
  description = "Type of root EBS volume (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 20
}

variable "volume_iops" {
  description = "IOPS for the root volume (only for io1, io2, gp3)"
  type        = number
  default     = null
}

variable "volume_throughput" {
  description = "Throughput for gp3 volumes in MB/s"
  type        = number
  default     = null
}

variable "root_volume_encrypted" {
  description = "Whether to encrypt the root EBS volume"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for EBS volume encryption"
  type        = string
  default     = ""
}

variable "delete_root_on_termination" {
  description = "Whether to delete root volume when instance is terminated"
  type        = bool
  default     = true
}

variable "extra_volumes" {
  description = "List of additional EBS volumes to create and attach"
  type = list(object({
    device_name  = string
    size         = number
    type         = string
    iops         = optional(number)
    throughput   = optional(number)
    encrypted    = optional(bool)
    kms_key_id   = optional(string)
    snapshot_id  = optional(string)
    name         = optional(string)
    force_detach = optional(bool)
    skip_destroy = optional(bool)
    tags         = optional(map(string))
  }))
  default = []
}

# ===================================================================================
# SECURITY AND ACCESS CONFIGURATION
# ===================================================================================

variable "disable_api_termination" {
  description = "Enable EC2 instance termination protection"
  type        = bool
  default     = false
}

variable "disable_api_stop" {
  description = "Enable EC2 instance stop protection"
  type        = bool
  default     = false
}

variable "shutdown_behavior" {
  description = "Shutdown behavior for the instance (stop or terminate)"
  type        = string
  default     = "stop"
  validation {
    condition     = contains(["stop", "terminate"], var.shutdown_behavior)
    error_message = "Shutdown behavior must be either 'stop' or 'terminate'."
  }
}

variable "create_default_security_group" {
  description = "Whether to create a default security group for the instance"
  type        = bool
  default     = false
}

# ===================================================================================
# IAM CONFIGURATION
# ===================================================================================

variable "create_iam_role" {
  description = "Whether to create an IAM role and instance profile"
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "Name of existing IAM instance profile to use (if not creating)"
  type        = string
  default     = ""
}

variable "additional_iam_policies" {
  description = "List of additional IAM policy ARNs to attach to the instance role"
  type        = list(string)
  default     = []
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager access"
  type        = bool
  default     = true
}

# ===================================================================================
# MONITORING AND PERFORMANCE
# ===================================================================================

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "ebs_optimized" {
  description = "Enable EBS optimization for supported instance types"
  type        = bool
  default     = null
}

variable "cpu_credits" {
  description = "Credit specification for burstable performance instances"
  type        = string
  default     = ""
  validation {
    condition = var.cpu_credits == "" || contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "CPU credits must be either empty, 'standard', or 'unlimited'."
  }
}

# ===================================================================================
# USER DATA AND BOOTSTRAPPING
# ===================================================================================

variable "user_data" {
  description = "User data script to run on instance launch (plain text)"
  type        = string
  default     = ""
}

variable "user_data_base64" {
  description = "User data script to run on instance launch (base64 encoded)"
  type        = string
  default     = ""
}

variable "user_data_replace_on_change" {
  description = "Whether to replace the instance when user data changes"
  type        = bool
  default     = false
}

# ===================================================================================
# PLACEMENT AND NETWORKING
# ===================================================================================

variable "placement_group" {
  description = "Name of the placement group to launch the instance in"
  type        = string
  default     = ""
}

variable "tenancy" {
  description = "Tenancy of the instance (default, dedicated, host)"
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "dedicated", "host"], var.tenancy)
    error_message = "Tenancy must be one of: default, dedicated, host."
  }
}

# ===================================================================================
# TAGGING AND METADATA
# ===================================================================================

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
}

variable "service_type" {
  description = "Type of service this instance provides (e.g., database, application, compute)"
  type        = string
  default     = "compute"
}

variable "client_name" {
  description = "Client name for client-isolation tagging (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ===================================================================================
# LIFECYCLE MANAGEMENT
# ===================================================================================
# Note: Terraform lifecycle blocks require static values, not variables.
# If you need prevent_destroy or ignore_changes, implement them in your 
# calling configuration rather than in this module.

# ===================================================================================
# COMPATIBILITY VARIABLES
# ===================================================================================
# These variables provide compatibility with legacy usage patterns

variable "enable_ssm_compat" {
  description = "Compatibility alias for enable_ssm"
  type        = bool
  default     = null
}

variable "volume_size_compat" {
  description = "Compatibility alias for volume_size"
  type        = number
  default     = null
}

variable "security_groups_compat" {
  description = "Compatibility alias for security_groups"
  type        = list(string)
  default     = null
}

# Use compatibility variables if provided, otherwise use main variables
locals {
  # Resolve compatibility variables
  final_enable_ssm      = var.enable_ssm_compat != null ? var.enable_ssm_compat : var.enable_ssm
  final_volume_size     = var.volume_size_compat != null ? var.volume_size_compat : var.volume_size
  final_security_groups = var.security_groups_compat != null ? var.security_groups_compat : var.security_groups
}

# Note: Individual validation blocks are included within their respective variable definitions above
