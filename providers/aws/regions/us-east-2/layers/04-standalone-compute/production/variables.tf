# =============================================================================
# Variables: Standalone Compute Layer - Analytics Instances
# =============================================================================

# =============================================================================
# Core Configuration Variables
# =============================================================================

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Name of the project for resource identification and tagging"
  type        = string
  default     = "ohio-01-eks"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state storage"
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region where Terraform state bucket is located"
  type        = string
  default     = "us-east-2"
}

# =============================================================================
# Client Configuration Variables
# =============================================================================

variable "enabled_clients" {
  description = "List of clients for which analytics instances should be created"
  type        = list(string)
  default     = ["est-test-a"]
  
  validation {
    condition = alltrue([
      for client in var.enabled_clients :
      can(regex("^est-test-[a-z]$", client))
    ])
    error_message = "Client names must follow the pattern 'est-test-[a-z]'."
  }
}

variable "analytics_configs" {
  description = "Configuration for analytics instances per client"
  type = map(object({
    instance_type      = string
    root_volume_size   = number
    data_volume_size   = number
  }))
  
  default = {
    "est-test-a" = {
      instance_type      = "t3.large"
      root_volume_size   = 20
      data_volume_size   = 100
    }
    # "est-test-b" = {
    #   instance_type      = "t3.medium"
    #   root_volume_size   = 20
    #   data_volume_size   = 50
    # }
  }
  
  validation {
    condition = alltrue([
      for config in values(var.analytics_configs) :
      config.root_volume_size >= 8 && config.root_volume_size <= 200
    ])
    error_message = "Root volume size must be between 8 GB and 200 GB."
  }
  
  validation {
    condition = alltrue([
      for config in values(var.analytics_configs) :
      config.data_volume_size >= 20 && config.data_volume_size <= 1000
    ])
    error_message = "Data volume size must be between 20 GB and 1000 GB."
  }
}

