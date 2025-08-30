# 📝 Variables for Foundation Layer - AF-South-1 Production

# Project Configuration
variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "cptwn-eks-01"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "af-south-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.16.0.0/16"
  
  validation {
    condition = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# Dual VPN Configuration
variable "enable_vpn" {
  description = "Enable Site-to-Site VPN for on-premises connectivity"
  type        = bool
  default     = true
}

variable "vpn_connections" {
  description = "Multiple VPN connections configuration for redundancy"
  type = map(object({
    enabled               = bool
    customer_gateway_ip   = string
    local_network_cidr    = string
    bgp_asn              = number
    amazon_side_asn      = number
    static_routes_only   = bool
    tunnel1_inside_cidr  = string
    tunnel2_inside_cidr  = string
    description          = string
  }))
  
  default = {
    primary = {
      enabled               = true
      customer_gateway_ip   = "178.162.141.150"    # Your primary customer gateway
      local_network_cidr    = "178.162.141.130/32" # Your primary local network
      bgp_asn              = 65100
      amazon_side_asn      = 65500
      static_routes_only   = true
      tunnel1_inside_cidr  = "169.254.100.0/30"    # Within valid 169.254.0.0/16 range
      tunnel2_inside_cidr  = "169.254.100.4/30"    # Next available /30 block
      description          = "Primary VPN Connection"
    }
    secondary = {
      enabled               = true
      customer_gateway_ip   = "165.90.14.138"      # Your secondary customer gateway
      local_network_cidr    = "165.90.14.138/32"   # Your secondary local network
      bgp_asn              = 65200
      amazon_side_asn      = 65501  # MUST be different from primary (was 65500)
      static_routes_only   = true
      tunnel1_inside_cidr  = "169.254.99.244/30"   # Your specified tunnel 1
      tunnel2_inside_cidr  = "169.254.73.232/30"   # Your specified tunnel 2
      description          = "Secondary VPN Connection"
    }
  }
}

variable "management_cidr_blocks" {
  description = "CIDR blocks for management access (VPN, bastion, etc.)"
  type        = list(string)
  default     = [  
    "178.162.141.130/32",  # Primary connection
    "165.90.14.138/32"     # Secondary connection
  ]
}

variable "tunnel2_preshared_key" {
  description = "Preshared key for tunnel 2"
  type        = string
  default     = null  # AWS will auto-generate if null
  sensitive   = true
}

# Monitoring Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for VPN alarms"
  type        = string
  default     = null
}
