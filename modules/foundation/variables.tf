# 🏗️ CPTWN Foundation Meta Wrapper Module - Variables
# Simplified and standardized inputs for consistent foundation deployments

# 🌍 CORE CONFIGURATION
variable "project_name" {
  description = "CPTWN project name for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens only."
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
}

# 🌐 VPC CONFIGURATION
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.16.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for security monitoring"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

# 🏢 MULTI-CLIENT CONFIGURATION
variable "clients" {
  description = "Map of client configurations for isolated subnets"
  type = map(object({
    enabled        = bool
    cidr_block     = string           # Client-specific CIDR block
    purpose        = string           # Client purpose/description
    custom_ports   = list(number)     # Custom application ports
    database_ports = list(number)     # Database ports
  }))
  
  validation {
    condition = alltrue([
      for client_name, config in var.clients :
      can(cidrhost(config.cidr_block, 0))
    ])
    error_message = "All client CIDR blocks must be valid CIDR notation."
  }
  
  # Example configuration
  default = {
    mtn-ghana-prod = {
      enabled        = true
      cidr_block     = "172.16.12.0/22"  # 4,094 IPs
      purpose        = "MTN Ghana Production Environment"
      custom_ports   = [8080, 9000, 3000, 5000]
      database_ports = [5432, 5433, 5434, 5435]
    }
    orange-madagascar-prod = {
      enabled        = true
      cidr_block     = "172.16.16.0/22"  # 4,094 IPs
      purpose        = "Orange Madagascar Production Environment"
      custom_ports   = [8080, 9000, 3000, 5000]
      database_ports = [5432, 5433, 5434, 5435]
    }
  }
}

# 🔐 SECURITY CONFIGURATION
variable "management_cidr_blocks" {
  description = "CIDR blocks for management access"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for cidr in var.management_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All management CIDR blocks must be valid CIDR notation."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for VPC Flow Logs and VPN logs"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# 🔗 VPN CONFIGURATION
variable "enable_vpn" {
  description = "Enable VPN connections for site-to-site connectivity"
  type        = bool
  default     = false
}

variable "vpn_connections" {
  description = "Map of VPN connection configurations"
  type = map(object({
    enabled               = bool
    description          = string
    customer_gateway_ip  = string
    local_network_cidr   = string
    bgp_asn             = number
    amazon_side_asn     = number
    static_routes_only  = bool
    tunnel1_inside_cidr = string
    tunnel2_inside_cidr = string
  }))
  
  default = {}
  
  validation {
    condition = alltrue([
      for vpn_name, config in var.vpn_connections :
      can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", config.customer_gateway_ip))
    ])
    error_message = "Customer gateway IP must be a valid IPv4 address."
  }
}

variable "enable_vpn_logging" {
  description = "Enable VPN connection logging"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for VPN notifications"
  type        = string
  default     = null
}

# 🏷️ ADDITIONAL TAGS
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
