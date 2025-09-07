# 🚀 Shared Services Layer - AF-South-1 Production Configuration
# Terraform variables for Kubernetes shared services deployment

# 🔧 CORE CPTWN CONFIGURATION
project_name = "cptwn-eks-01"
environment  = "production"
region      = "af-south-1"

# 📊 TERRAFORM STATE CONFIGURATION
# Update this with your actual state bucket name
terraform_state_bucket = "cptwn-terraform-state-ezra"
terraform_state_region = "af-south-1"

# 🎛️ SHARED SERVICES CONFIGURATION
enable_cluster_autoscaler           = true
enable_aws_load_balancer_controller = true
enable_metrics_server              = true
enable_external_dns                = false  # Enable later when you have Route 53 zones

# 📦 SERVICE VERSIONS (Latest stable versions)
cluster_autoscaler_version           = "9.37.0"
aws_load_balancer_controller_version = "1.8.1"
metrics_server_version               = "3.12.1"

# 🔐 CLUSTER AUTOSCALER CONFIGURATION
cluster_autoscaler_scale_down_enabled                   = true
cluster_autoscaler_scale_down_delay_after_add          = "10m"
cluster_autoscaler_scale_down_unneeded_time             = "10m"
cluster_autoscaler_skip_nodes_with_local_storage        = false

# 🌐 DNS CONFIGURATION
# Add your Route 53 hosted zone IDs here when you have them
dns_zone_ids = []

# 🏷️ ADDITIONAL TAGS
additional_tags = {
  CostCenter     = "Infrastructure"
  BusinessUnit   = "Platform"
  ServiceTier    = "SharedServices"
}
