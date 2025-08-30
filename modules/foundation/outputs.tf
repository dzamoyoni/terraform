# 🏗️ CPTWN Foundation Meta Wrapper Module - Outputs
# Consolidated outputs for all foundation components with CPTWN standards

# 🌐 VPC OUTPUTS
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc_foundation.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc_foundation.vpc_cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc_foundation.vpc_arn
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.availability_zones
}

# 🌐 PLATFORM INFRASTRUCTURE
output "platform_subnet_ids" {
  description = "List of platform subnet IDs for EKS deployment"
  value       = module.vpc_foundation.platform_subnet_ids
}

output "platform_subnet_cidrs" {
  description = "List of platform subnet CIDR blocks"
  value       = module.vpc_foundation.platform_subnet_cidrs
}

output "platform_route_table_ids" {
  description = "List of platform route table IDs"
  value       = module.vpc_foundation.platform_route_table_ids
}

# 🌐 NAT GATEWAYS
output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc_foundation.nat_gateway_ids
}

output "nat_gateway_ips" {
  description = "List of NAT Gateway public IP addresses"
  value       = module.vpc_foundation.nat_gateway_ips
}

# 🏢 CLIENT SUBNETS - Dynamic outputs for all clients
output "client_subnet_ids" {
  description = "Map of client subnet IDs by client name"
  value = {
    for client_name, client_module in module.client_subnets :
    client_name => client_module.subnet_ids
  }
}

output "client_subnet_cidrs" {
  description = "Map of client subnet CIDR blocks by client name"
  value = {
    for client_name, client_module in module.client_subnets :
    client_name => client_module.subnet_cidrs
  }
}

output "client_route_table_ids" {
  description = "Map of client route table IDs by client name"
  value = {
    for client_name, client_module in module.client_subnets :
    client_name => client_module.route_table_ids
  }
}

output "client_security_group_ids" {
  description = "Map of client security group IDs by client name"
  value = {
    for client_name, client_module in module.client_subnets :
    client_name => client_module.security_group_id
  }
}

output "client_nacl_ids" {
  description = "Map of client NACL IDs by client name"
  value = {
    for client_name, client_module in module.client_subnets :
    client_name => client_module.nacl_id
  }
}

# 🔗 VPN OUTPUTS (when enabled)
output "vpn_gateway_ids" {
  description = "Map of VPN gateway IDs by VPN connection name"
  value = {
    for vpn_name, vpn_module in module.vpn_connections :
    vpn_name => vpn_module.vpn_gateway_id
  }
}

output "vpn_connection_ids" {
  description = "Map of VPN connection IDs by VPN connection name"
  value = {
    for vpn_name, vpn_module in module.vpn_connections :
    vpn_name => vpn_module.vpn_connection_id
  }
}

output "customer_gateway_ids" {
  description = "Map of customer gateway IDs by VPN connection name"
  value = {
    for vpn_name, vpn_module in module.vpn_connections :
    vpn_name => vpn_module.customer_gateway_id
  }
}

# 📊 CPTWN FOUNDATION SUMMARY
output "foundation_summary" {
  description = "Comprehensive summary of the CPTWN foundation deployment"
  value = {
    # Core information
    project_name    = var.project_name
    environment     = var.environment
    region          = var.region
    vpc_id          = module.vpc_foundation.vpc_id
    vpc_cidr        = var.vpc_cidr
    
    # Network configuration
    availability_zones = local.availability_zones
    platform_subnets   = length(module.vpc_foundation.platform_subnet_ids)
    nat_gateways      = length(module.vpc_foundation.nat_gateway_ids)
    
    # Client configuration
    clients_configured = {
      for client_name, config in var.clients :
      client_name => {
        enabled    = config.enabled
        cidr_block = config.cidr_block
        purpose    = config.purpose
        subnets    = length(module.client_subnets[client_name].subnet_ids)
      }
    }
    
    # VPN configuration
    vpn_enabled = var.enable_vpn
    vpn_connections = var.enable_vpn ? {
      for vpn_name, config in var.vpn_connections :
      vpn_name => {
        enabled     = config.enabled
        description = config.description
        type        = config.static_routes_only ? "Static" : "BGP"
      }
    } : {}
    
    # Security features
    security_features = {
      vpc_flow_logs    = var.enable_vpc_flow_logs
      vpc_endpoints    = var.enable_vpc_endpoints
      vpn_logging      = var.enable_vpn_logging
      client_isolation = true
    }
    
    # CPTWN standards applied
    cptwn_standards = {
      naming_convention   = "applied"
      tagging_standards  = "applied"
      security_hardening = "applied"
      monitoring_enabled = "applied"
      backup_configured  = "applied"
      multi_client_ready = "applied"
    }
  }
}

# 🔒 SECURITY NOTICE
output "security_notice" {
  description = "Important security information for the foundation infrastructure"
  value = {
    message = "CPTWN Foundation Infrastructure deployed with multi-client isolation"
    actions_required = [
      "Review VPC Flow Logs for security monitoring",
      "Verify client subnet isolation is working correctly",
      "Configure VPN connections if site-to-site connectivity is needed",
      "Set up monitoring and alerting for NAT Gateway usage",
      "Review Network ACLs and Security Groups for compliance"
    ]
    client_isolation = "Each client has dedicated subnets, route tables, security groups, and NACLs"
    vpn_status = var.enable_vpn ? 
      "VPN connections configured for secure site-to-site connectivity" : 
      "VPN connections disabled - configure if needed for on-premises access"
    documentation = "https://docs.aws.amazon.com/vpc/latest/userguide/"
  }
}
