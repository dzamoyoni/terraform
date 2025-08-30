# ============================================================================
# Foundation Layer Production Configuration
# ============================================================================
# This file contains the production-specific values for the foundation layer.
# Values are consistent with the regional networking configuration.
# ============================================================================

# ============================================================================
# Foundation Layer IMPORT MODE Configuration
# ============================================================================
# This configuration references your EXISTING infrastructure without any modifications

# General Configuration
environment        = "production"
aws_region         = "us-east-1"
vpc_name          = "existing-production-vpc"  # Just for naming SSM parameters
cluster_name      = "us-test-cluster-01"
availability_zones = ["us-east-1a", "us-east-1b"]

# ============================================================================
# EXISTING Infrastructure (NO MODIFICATIONS WILL BE MADE)
# ============================================================================
# These values reference your current AWS resources


# Your existing VPC and subnets (from platform layer hardcoded values)
existing_vpc_id               = "vpc-0ec63df5e5566ea0c"
existing_private_subnet_ids   = ["subnet-0a6936df3ff9a4f77", "subnet-0ec8a91aa274caea1"]
existing_public_subnet_ids    = ["subnet-0140a7b62fb36dffb", "subnet-00d569fb526980566"]

# Optional: Existing gateways (will auto-discover if left empty)
existing_igw_id              = ""  # Will auto-discover from VPC
existing_nat_gateway_ids     = []  # Will auto-discover from VPC

# VPN Gateway - Your existing VPN setup
existing_vpn_gateway_id      = "vgw-00ea48420a1cf8d13"  # Your existing VPN gateway

# Security Groups - Use your existing ones (NO NEW SECURITY GROUPS CREATED)
existing_eks_cluster_sg_id   = "sg-014caac5c31fbc765"  # From platform layer
existing_database_sg_id      = "sg-067bc5c25980da2cc"  # From database layer  
existing_alb_sg_id           = "sg-0fc956334f67b2f64"  # From database layer

# VPN Configuration (from shared/region-configs/us-east-1/networking.tfvars)
enable_vpn = true

vpn_config = {
  # Primary VPN Connection
  customer_gateway_ip   = "178.162.141.150"
  client_cidr          = "178.162.141.130/32"
  bgp_asn              = 6500
  
  # Secondary VPN Connection  
  secondary_gateway_ip   = "165.90.14.138"
  secondary_client_cidr  = "165.90.14.138/32"
  secondary_bgp_asn      = 6500
}
