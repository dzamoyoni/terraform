# ============================================================================
# Foundation Layer Outputs (01-foundation/production)
# ============================================================================

# ============================================================================
# Direct Module Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.foundation.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.foundation.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.foundation.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.foundation.public_subnets
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the private subnets"
  value       = module.foundation.private_subnets_cidr_blocks
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the public subnets"
  value       = module.foundation.public_subnets_cidr_blocks
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = module.foundation.eks_cluster_security_group_id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = module.foundation.database_security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.foundation.alb_security_group_id
}

# ============================================================================
# VPN Outputs
# ============================================================================

output "vpn_enabled" {
  description = "Whether VPN is enabled"
  value       = module.foundation.vpn_enabled
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = module.foundation.vpn_gateway_id
}

# ============================================================================
# Network Infrastructure Outputs
# ============================================================================

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.foundation.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.foundation.nat_gateway_ids
}

# Note: Additional route table and NAT details available via unified module
# but simplified here for import mode compatibility

# ============================================================================
# SSM Parameter Names (for other layers to reference)
# ============================================================================

output "ssm_parameter_names" {
  description = "Map of SSM parameter names for cross-layer reference"
  value       = module.foundation.ssm_parameter_names
}

# ============================================================================
# Summary Outputs
# ============================================================================

output "network_summary" {
  description = "Summary of network configuration"
  value       = module.foundation.network_summary
}

output "security_summary" {
  description = "Summary of security groups created"
  value       = module.foundation.security_summary
}

output "foundation_status" {
  description = "Foundation layer deployment status"
  value = {
    deployed        = true
    version         = "1.0.0"
    environment     = var.environment
    region          = var.aws_region
    vpc_id          = module.foundation.vpc_id
    subnets_created = length(module.foundation.private_subnets) + length(module.foundation.public_subnets)
    vpn_enabled     = var.enable_vpn
  }
}

# ============================================================================
# Migration Helper Outputs (for platform layer integration)
# ============================================================================

output "existing_infrastructure_mapping" {
  description = "Mapping to existing infrastructure for migration"
  value = {
    # Current hardcoded values from platform layer
    current_vpc_id          = "vpc-0ec63df5e5566ea0c"
    current_private_subnets = ["subnet-0a6936df3ff9a4f77", "subnet-0ec8a91aa274caea1"]
    current_public_subnets  = ["subnet-0b97065c0b7e66d5e", "subnet-067cb01bb4e3bb0e7"]
    
    # New foundation layer values
    new_vpc_id          = module.foundation.vpc_id
    new_private_subnets = module.foundation.private_subnets
    new_public_subnets  = module.foundation.public_subnets
    
    # SSM parameter paths for platform layer to use
    vpc_id_ssm          = "/terraform/${var.environment}/foundation/vpc_id"
    private_subnets_ssm = "/terraform/${var.environment}/foundation/private_subnets"
    public_subnets_ssm  = "/terraform/${var.environment}/foundation/public_subnets"
    vpc_cidr_ssm        = "/terraform/${var.environment}/foundation/vpc_cidr"
  }
}
