# =============================================================================
# Terraform Variables: Standalone Compute Layer - Production Environment
# =============================================================================

# =============================================================================
# Core Configuration
# =============================================================================

project_name = "ohio-01-eks"
region       = "us-east-2"
environment  = "production"

# Backend configuration
terraform_state_bucket = "ohio-01-terraform-state-production"
terraform_state_region = "us-east-2"

# =============================================================================
# Client Configuration
# =============================================================================

# Enable analytics instances for these clients
# Add/remove clients here to scale instances up/down
# Note: Only clients with foundation subnets can be enabled
enabled_clients = ["est-test-a"]

# Client-specific analytics instance configurations
# Define configurations for all potential clients, enable via enabled_clients list
analytics_configs = {
  "est-test-a" = {
    instance_type      = "t3.large"      # 2 vCPU, 8 GB RAM
    root_volume_size   = 30              # GB - OS and applications
    data_volume_size   = 30             # GB - Analytics data and workspaces
  }
  
  "est-test-b" = {
    instance_type      = "t3.medium"     # 2 vCPU, 4 GB RAM  
    root_volume_size   = 20              # GB - OS and applications
    data_volume_size   = 50              # GB - Analytics data and workspaces
  }
  
  "est-test-c" = {
    instance_type      = "t3.xlarge"     # 4 vCPU, 16 GB RAM - Higher performance
    root_volume_size   = 40              # GB - OS and applications
    data_volume_size   = 100             # GB - Analytics data and workspaces
  }
}

