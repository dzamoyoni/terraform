#  Shared Services Layer - AF-South-1 Production Configuration
# Terraform variables for Kubernetes shared services deployment

#  CORE CPTWN CONFIGURATION
project_name = "cptwn-eks-01"
environment  = "production"
region       = "af-south-1"

#  TERRAFORM STATE CONFIGURATION
# Update this with your actual state bucket name
terraform_state_bucket = "cptwn-terraform-state-ezra"
terraform_state_region = "af-south-1"

#  SHARED SERVICES CONFIGURATION
enable_cluster_autoscaler           = true
enable_aws_load_balancer_controller = true
enable_metrics_server               = true
enable_external_dns                 = false # Enable later when you have Route 53 zones

#  SERVICE VERSIONS (Latest stable versions)
cluster_autoscaler_version           = "9.37.0"
aws_load_balancer_controller_version = "1.8.1"
metrics_server_version               = "3.12.1"

#  CLUSTER AUTOSCALER CONFIGURATION
cluster_autoscaler_scale_down_enabled            = true
cluster_autoscaler_scale_down_delay_after_add    = "10m"
cluster_autoscaler_scale_down_unneeded_time      = "10m"
cluster_autoscaler_skip_nodes_with_local_storage = false

#  DNS CONFIGURATION
# Add your Route 53 hosted zone IDs here when you have them
dns_zone_ids = []

#  ADDITIONAL TAGS
additional_tags = {
  CostCenter   = "Infrastructure"
  BusinessUnit = "Platform"
  ServiceTier  = "SharedServices"
}

# =============================================================================
#  ISTIO SERVICE MESH CONFIGURATION - PRODUCTION DEPLOYMENT
# =============================================================================

# Enable Istio service mesh deployment
enable_istio_service_mesh = true

# Istio version and mesh configuration (Latest stable with ambient improvements)
istio_version        = "1.27.1"
istio_mesh_id       = "cptwn-mesh-af-south-1"
istio_cluster_network = "af-south-1-network"
istio_trust_domain  = "cluster.local"

# Enable ambient mode (recommended for production multi-client setup)
enable_istio_ambient_mode = true

# Ingress Gateway Configuration (ClusterIP for internal routing)
enable_istio_ingress_gateway = true
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
istio_application_namespaces = {
  # MTN Ghana - Production workloads using ambient mode for performance
  "mtn-ghana-prod" = {
    dataplane_mode = "ambient"
    client         = "mtn-ghana"
    tenant         = "mtn-ghana-prod"
  }
  
  # Orange Madagascar - Production workloads using ambient mode
  "orange-madagascar-prod" = {
    dataplane_mode = "ambient"
    client         = "orange-madagascar"
    tenant         = "orange-madagascar-prod"
  }
  
  # CPTWN Platform services - Using sidecar for advanced traffic policies
  "cptwn-platform" = {
    dataplane_mode = "sidecar"
    client         = "cptwn"
    tenant         = "platform"
  }
}

# Observability Integration with Layer 03.5 (existing observability stack)
enable_istio_distributed_tracing = true
enable_istio_access_logging     = true
istio_tracing_sampling_rate     = 0.01  # 1% sampling for production

# Monitoring Integration with existing Prometheus/Grafana
enable_istio_service_monitor  = true
enable_istio_prometheus_rules = true
