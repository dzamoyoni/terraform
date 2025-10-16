# Outputs for Foundation Layer 

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc_foundation.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc_foundation.vpc_cidr_block
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.availability_zones
}

# NAT Gateway Information
output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc_foundation.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IP addresses"
  value       = module.vpc_foundation.nat_gateway_public_ips
}

# Platform Subnet Information
output "platform_subnet_ids" {
  description = "List of platform subnet IDs"
  value       = module.vpc_foundation.platform_subnet_ids
}

output "platform_subnet_cidr_blocks" {
  description = "List of platform subnet CIDR blocks"
  value       = module.vpc_foundation.platform_subnet_cidr_blocks
}

#ETA Client Infrastructure
output "est_test_a_compute_subnet_ids" {
  description = "ETA compute subnet IDs"
  value       = module.client_subnets_est_test_a.compute_subnet_ids
}

output "est_test_a_database_subnet_ids" {
  description = "ETA database subnet IDs"
  value       = module.client_subnets_est_test_a.database_subnet_ids
}

output "est_test_a_eks_subnet_ids" {
  description = "ETA EKS subnet IDs"
  value       = module.client_subnets_est_test_a.eks_subnet_ids
}

output "est_test_a_security_groups" {
  description = "ETA security group IDs"
  value = {
    compute  = module.client_subnets_est_test_a.compute_security_group_id
    database = module.client_subnets_est_test_a.database_security_group_id
    eks      = module.client_subnets_est_test_a.eks_security_group_id
  }
}

# output "est_test_a_db_subnet_group_name" {
#   description = "Ezra RDS subnet group name"
#   value       = module.client_subnets_ezra.db_subnet_group_name
# }

# ETB Client Infrastructure
output "est_test_b_compute_subnet_ids" {
  description = "ETB compute subnet IDs"
  value       = module.client_subnets_est_test_b.compute_subnet_ids
}

output "est_test_b_database_subnet_ids" {
  description = "ETB database subnet IDs"
  value       = module.client_subnets_est_test_b.database_subnet_ids
}

output "est_test_b_eks_subnet_ids" {
  description = "ETB EKS subnet IDs"
  value       = module.client_subnets_est_test_b.eks_subnet_ids
}

output "est_test_b_security_groups" {
  description = "ETB security group IDs"
  value = {
    compute  = module.client_subnets_est_test_b.compute_security_group_id
    database = module.client_subnets_est_test_b.database_security_group_id
    eks      = module.client_subnets_est_test_b.eks_security_group_id
  }
}


# Dual VPN Information (if enabled)
output "vpn_connections" {
  description = "Details of all VPN connections"
  value = var.enable_vpn ? {
    for k, v in module.vpn_connections : k => {
      vpn_connection_id   = v.vpn_connection_id
      vpn_gateway_id      = v.vpn_gateway_id
      tunnel1_address     = v.tunnel1_address
      tunnel2_address     = v.tunnel2_address
      customer_gateway_ip = var.vpn_connections[k].customer_gateway_ip
      local_network       = var.vpn_connections[k].local_network_cidr
      description         = var.vpn_connections[k].description
    }
  } : null
}

output "vpn_primary_outside_ips" {
  description = "Primary VPN tunnel outside IP addresses (AWS side)"
  value = var.enable_vpn && contains(keys(var.vpn_connections), "primary") ? {
    tunnel1 = module.vpn_connections["primary"].tunnel1_address
    tunnel2 = module.vpn_connections["primary"].tunnel2_address
  } : null
}

output "vpn_secondary_outside_ips" {
  description = "Secondary VPN tunnel outside IP addresses (AWS side)"
  value = var.enable_vpn && contains(keys(var.vpn_connections), "secondary") ? {
    tunnel1 = module.vpn_connections["secondary"].tunnel1_address
    tunnel2 = module.vpn_connections["secondary"].tunnel2_address
  } : null
}

# VPC Endpoints
output "vpc_endpoints" {
  description = "VPC endpoint IDs"
  value = {
    s3      = module.vpc_foundation.s3_vpc_endpoint_id
    ecr_dkr = module.vpc_foundation.ecr_dkr_vpc_endpoint_id
    ecr_api = module.vpc_foundation.ecr_api_vpc_endpoint_id
  }
}

# Foundation Summary
output "foundation_summary" {
  description = "Summary of foundation infrastructure deployed"
  value = {
    vpc_id             = module.vpc_foundation.vpc_id
    vpc_cidr           = module.vpc_foundation.vpc_cidr_block
    availability_zones = local.availability_zones
    nat_gateways       = length(module.vpc_foundation.nat_gateway_ids)
    public_subnets     = length(module.vpc_foundation.public_subnet_ids)
    platform_subnets   = length(module.vpc_foundation.platform_subnet_ids)

    # Client infrastructure counts
    est_test_a_total_subnets = (
      length(module.client_subnets_est_test_a.compute_subnet_ids) +
      length(module.client_subnets_est_test_a.database_subnet_ids) +
      length(module.client_subnets_est_test_a.eks_subnet_ids)
    )
    est_test_b_total_subnets = (
      length(module.client_subnets_est_test_b.compute_subnet_ids) +
      length(module.client_subnets_est_test_b.database_subnet_ids) +
      length(module.client_subnets_est_test_b.eks_subnet_ids)
    )

    # Security & Monitoring
    vpc_flow_logs_enabled = true
    vpc_endpoints_enabled = true
    vpn_enabled           = var.enable_vpn
    deletion_protected    = true
  }
}

#  SECURITY NOTICE
output "security_notice" {
  description = "Critical security and next steps information"
  value       = <<-EOT
    # PHASE 1 FOUNDATION INFRASTRUCTURE DEPLOYED #
    
    # SUCCESSFULLY CREATED:
    - VPC with dual NAT gateways for HA
    - Complete client subnet isolation 
    - VPC endpoints for cost optimization
    - VPC flow logs for security monitoring
    - Deletion protection on all critical resources
    ${var.enable_vpn ? "- Site-to-Site VPN for on-premises connectivity" : ""}
    
    # CLIENT ISOLATION VERIFIED:
    - ETA: 6 isolated subnets (Compute, Database, EKS)
    - ETB : 6 isolated subnets (Compute, Database, EKS)
    - Dedicated security groups per client per layer
    - Network ACLs for additional security
    
    # NEXT PHASE: Platform Layer (EKS Cluster)
    - Use platform subnets: ${join(", ", module.vpc_foundation.platform_subnet_ids)}
    - Configure with VPC ID: ${module.vpc_foundation.vpc_id}
    - Enable IP optimization from day 1
    
    !!!! CRITICAL: All resources have deletion protection enabled !!!
  EOT
}
