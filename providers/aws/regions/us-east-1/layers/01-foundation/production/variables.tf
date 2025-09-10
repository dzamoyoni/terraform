# 📝 Variables for Foundation Layer - US-East-1 Production

# Project Configuration
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "us-east-1-cluster-01"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# Dual VPN Configuration
variable "enable_vpn" {
  description = "Enable Site-to-Site VPN for on-premises connectivity"
  type        = bool
  default     = false # Disabled by default for US-East-1
}

variable "vpn_connections" {
  description = "Multiple VPN connections configuration for redundancy"
  type = map(object({
    enabled             = bool
    customer_gateway_ip = string
    local_network_cidr  = string
    bgp_asn             = number
    amazon_side_asn     = number
    static_routes_only  = bool
    tunnel1_inside_cidr = string
    tunnel2_inside_cidr = string
    description         = string
  }))

  default = {
    primary = {
      enabled             = false
      customer_gateway_ip = "203.0.113.12"   # Example IP - replace with actual
      local_network_cidr  = "203.0.113.0/24" # Example CIDR - replace with actual
      bgp_asn             = 65300
      amazon_side_asn     = 65502
      static_routes_only  = true
      tunnel1_inside_cidr = "169.254.101.0/30" # Within valid 169.254.0.0/16 range
      tunnel2_inside_cidr = "169.254.101.4/30" # Next available /30 block
      description         = "US-East-1 Primary VPN Connection"
    }
  }
}

variable "management_cidr_blocks" {
  description = "CIDR blocks for management access (VPN, bastion, etc.)"
  type        = list(string)
  default = [
    "203.0.113.0/24" # Example management CIDR - replace with actual
  ]
}

variable "tunnel2_preshared_key" {
  description = "Preshared key for tunnel 2"
  type        = string
  default     = null # AWS will auto-generate if null
  sensitive   = true
}

# Monitoring Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for VPN alarms"
  type        = string
  default     = null
}
