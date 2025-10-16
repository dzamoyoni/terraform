# =============================================================================
# Platform Layer - Production Environment Configuration
# =============================================================================
# This file contains production-specific variable values for the platform layer
# Adjust values based on production requirements and scaling needs

# Core Configuration
region       = "us-east-2"
environment  = "production"
project_name = "ohio-01-eks"

# Terraform State Management
terraform_state_bucket = "ohio-01-terraform-state-production"
terraform_state_region = "us-east-2"

# EKS Cluster Configuration
cluster_version = "1.31"

# Management Access Configuration
# Add your management IPs here for kubectl access
management_cidr_blocks = [
  # "178.162.141.130/32", # Primary management IP
  # "165.90.14.138/32",   # Secondary management IP  
  # "41.72.206.78/32",    # Additional management IP
  "102.217.4.85/32"     # Your current IP for cluster access
]

# Client Configuration
enable_client_isolation = true

# =============================================================================
# Production-Specific Settings (Uncomment and modify as needed)
# =============================================================================

# Additional management IPs (uncomment to add more)
# management_cidr_blocks = [
#   "178.162.141.130/32",
#   "165.90.14.138/32", 
#   "41.72.206.78/32",
#   "102.217.4.85/32",
#   "10.0.0.0/8",        # Corporate VPN range
#   "172.16.0.0/12"      # Additional corporate range
# ]

# Production cluster version pinning (for stability)
# cluster_version = "1.30"  # Use previous stable version if needed

# Multi-region disaster recovery (future expansion)
# backup_region = "us-west-2"
# enable_cross_region_backup = true

# =============================================================================
# Scaling Configuration Examples (uncomment as needed)
# =============================================================================

# High-traffic production settings
# node_group_scaling = {
#   min_size     = 2
#   max_size     = 10
#   desired_size = 4
# }

# Cost optimization for development
# node_group_scaling = {
#   min_size     = 1
#   max_size     = 3
#   desired_size = 1
# }