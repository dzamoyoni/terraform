# Shared Services Layer - US-East-2 Production Configuration
# Terraform variables for Kubernetes shared services deployment

# CORE CONFIGURATION
project_name = "ohio-01-eks"
environment  = "production"
region       = "us-east-2"

# TERRAFORM STATE CONFIGURATION
terraform_state_bucket = "ohio-01-terraform-state-production"
terraform_state_region = "us-east-2"

#  SHARED SERVICES CONFIGURATION
enable_cluster_autoscaler           = true
enable_aws_load_balancer_controller = true
enable_metrics_server               = true
enable_external_dns                 = false # Enable later when you have Route 53 zones

# SERVICE VERSIONS - LATEST PRODUCTION-STABLE (October 2024)
cluster_autoscaler_version           = "9.43.0"    # Latest with improved scaling algorithms
aws_load_balancer_controller_version = "1.9.0"     # Latest with enhanced security features
metrics_server_version               = "3.12.2"    # Latest with performance improvements

#  CLUSTER AUTOSCALER CONFIGURATION
cluster_autoscaler_scale_down_enabled            = true
cluster_autoscaler_scale_down_delay_after_add    = "10m"
cluster_autoscaler_scale_down_unneeded_time      = "10m"
cluster_autoscaler_skip_nodes_with_local_storage = false

#  DNS CONFIGURATION
# Add your Route 53 hosted zone IDs here when you have them
dns_zone_ids = []

# PRODUCTION TAGGING STRATEGY
additional_tags = {
  # Cost Management
  CostCenter      = "IT-Infrastructure"
  BillingGroup    = "Platform-Engineering"
  
  # Operational
  BusinessUnit    = "Platform"
  ServiceTier     = "SharedServices"
  CriticalInfra   = "true"
  BackupRequired  = "true"
  
  # Security & Compliance
  SecurityLevel   = "High"
  DataClassification = "Internal"
  
  # Platform Identification
  PlatformType    = "EKS-SharedServices"
  Architecture    = "Multi-Client"
}

# =============================================================================
#  ISTIO SERVICE MESH CONFIGURATION - PRODUCTION DEPLOYMENT
# =============================================================================

# Enable Istio service mesh deployment
enable_istio_service_mesh = true

# Istio version and mesh configuration (Latest stable - October 2024)
istio_version         = "1.27.2"                    # Latest stable with security fixes
istio_mesh_id         = "mesh-us-east-2"
istio_cluster_network = "us-east-2-network"
istio_trust_domain    = "cluster.local"

# Enable ambient mode (recommended for production multi-client setup)
enable_istio_ambient_mode = true

# Ingress Gateway Configuration (ClusterIP for internal routing)
enable_istio_ingress_gateway   = true
istio_ingress_gateway_replicas = 3

# Ingress Gateway Resources (production-sized)
istio_ingress_gateway_resources = {
  requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

# Ingress Gateway Autoscaling
istio_ingress_gateway_autoscale_enabled = true
istio_ingress_gateway_autoscale_min     = 2
istio_ingress_gateway_autoscale_max     = 10

# Istiod Resources (production-sized for multi-client workloads)
istio_istiod_resources = {
  requests = {
    cpu    = "500m"
    memory = "2Gi"
  }
  limits = {
    cpu    = "1000m"
    memory = "4Gi"
  }
}

# Istiod Autoscaling (High availability)
istio_istiod_autoscale_enabled = true
istio_istiod_autoscale_min     = 2
istio_istiod_autoscale_max     = 5

# Application Namespace Configuration - Multi-Client Setup
# Consistent with foundation layer client naming: est-test-a, est-test-b
istio_application_namespaces = {
  # Client A - Production workloads using ambient mode for performance
  "est-test-a-prod" = {
    dataplane_mode = "ambient"
    client         = "est-test-a"
    tenant         = "est-test-a-prod"
  }

  # Client B - Production workloads using ambient mode
  "est-test-b-prod" = {
    dataplane_mode = "ambient"
    client         = "est-test-b"
    tenant         = "est-test-b-prod"
  }

  # Platform services - Using sidecar for advanced traffic policies
  "platform" = {
    dataplane_mode = "sidecar"
    client         = "platform"
    tenant         = "platform"
  }

  # Shared Analytics namespace - Using ambient for performance
  "analytics" = {
    dataplane_mode = "ambient"
    client         = "shared"
    tenant         = "analytics"
  }
}

# Observability Integration with Layer 03.5 (existing observability stack)
enable_istio_distributed_tracing = true
enable_istio_access_logging      = true
istio_tracing_sampling_rate      = 0.01 # 1% sampling for production

# Monitoring Integration with existing Prometheus/Grafana
enable_istio_service_monitor  = true
enable_istio_prometheus_rules = true

