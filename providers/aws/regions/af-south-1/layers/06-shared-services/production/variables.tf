# 🚀 Shared Services Layer Variables
# Configuration variables for Kubernetes shared services deployment

# 🔧 CORE CPTWN CONFIGURATION
variable "project_name" {
  description = "Name of the CPTWN project"
  type        = string
  default     = "cptwn-eks-01"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "af-south-1"
}

# 📊 TERRAFORM STATE CONFIGURATION
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform remote state"
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region where Terraform state bucket is located"
  type        = string
  default     = "af-south-1"
}

# 🎛️ SHARED SERVICES CONFIGURATION
variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler deployment"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller deployment"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable metrics server deployment"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external DNS controller deployment"
  type        = bool
  default     = false
}

# 📦 SERVICE VERSIONS
variable "cluster_autoscaler_version" {
  description = "Version of cluster autoscaler Helm chart"
  type        = string
  default     = "9.37.0"
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_version" {
  description = "Version of metrics server Helm chart"
  type        = string
  default     = "3.12.1"
}

# 🌐 DNS CONFIGURATION
variable "dns_zone_ids" {
  description = "List of Route 53 hosted zone IDs for external DNS"
  type        = list(string)
  default     = []
}

# 🔐 CLUSTER AUTOSCALER CONFIGURATION
variable "cluster_autoscaler_scale_down_enabled" {
  description = "Enable scale down for cluster autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  description = "How long after scale up that scale down evaluation resumes"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "How long a node should be unneeded before it is eligible for scale down"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_skip_nodes_with_local_storage" {
  description = "Skip nodes with local storage for scale down"
  type        = bool
  default     = false
}

# 🏷️ ADDITIONAL TAGS
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# 🕸️ ISTIO SERVICE MESH CONFIGURATION
# =============================================================================

variable "enable_istio_service_mesh" {
  description = "Enable Istio service mesh deployment"
  type        = bool
  default     = true
}

variable "istio_version" {
  description = "Version of Istio to deploy"
  type        = string
  default     = "1.27.1"  # Updated to latest stable with ambient improvements
}

variable "istio_mesh_id" {
  description = "Istio mesh ID"
  type        = string
  default     = "cptwn-mesh-af-south-1"
}

variable "istio_cluster_network" {
  description = "Istio cluster network identifier"
  type        = string
  default     = "af-south-1-network"
}

variable "istio_trust_domain" {
  description = "Istio trust domain"
  type        = string
  default     = "cluster.local"
}

# Ambient Mode Configuration
variable "enable_istio_ambient_mode" {
  description = "Enable Istio ambient mode"
  type        = bool
  default     = true
}

# Ingress Gateway Configuration
variable "enable_istio_ingress_gateway" {
  description = "Enable Istio ingress gateway (ClusterIP)"
  type        = bool
  default     = true
}

variable "istio_ingress_gateway_replicas" {
  description = "Number of ingress gateway replicas"
  type        = number
  default     = 3
}

variable "istio_ingress_gateway_resources" {
  description = "Resource configuration for ingress gateway"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "istio_ingress_gateway_autoscale_enabled" {
  description = "Enable autoscaling for ingress gateway"
  type        = bool
  default     = true
}

variable "istio_ingress_gateway_autoscale_min" {
  description = "Minimum replicas for ingress gateway autoscaling"
  type        = number
  default     = 2
}

variable "istio_ingress_gateway_autoscale_max" {
  description = "Maximum replicas for ingress gateway autoscaling"
  type        = number
  default     = 10
}

# Istiod Configuration
variable "istio_istiod_resources" {
  description = "Resource configuration for istiod"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "4Gi"
    }
  }
}

variable "istio_istiod_autoscale_enabled" {
  description = "Enable autoscaling for istiod"
  type        = bool
  default     = true
}

variable "istio_istiod_autoscale_min" {
  description = "Minimum replicas for istiod autoscaling"
  type        = number
  default     = 2
}

variable "istio_istiod_autoscale_max" {
  description = "Maximum replicas for istiod autoscaling"
  type        = number
  default     = 5
}

# Application Namespace Configuration - Multi-Client
variable "istio_application_namespaces" {
  description = "Configuration for application namespaces with different dataplane modes"
  type = map(object({
    dataplane_mode = string # "ambient" or "sidecar"
    client         = optional(string)
    tenant         = optional(string)
  }))
  default = {
    # MTN Ghana - Production workloads using ambient mode
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
    # CPTWN Platform services - Using sidecar for advanced policies
    "cptwn-platform" = {
      dataplane_mode = "sidecar"
      client         = "cptwn"
      tenant         = "platform"
    }
  }
}

# Observability Integration with Layer 03.5
variable "enable_istio_distributed_tracing" {
  description = "Enable distributed tracing integration with existing Tempo"
  type        = bool
  default     = true
}

variable "enable_istio_access_logging" {
  description = "Enable access logging integration with existing Fluent Bit"
  type        = bool
  default     = true
}

variable "istio_tracing_sampling_rate" {
  description = "Tracing sampling rate for production (0.0 to 1.0)"
  type        = number
  default     = 0.01 # 1% sampling for production
}

# Monitoring Integration
variable "enable_istio_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus integration"
  type        = bool
  default     = true
}

variable "enable_istio_prometheus_rules" {
  description = "Enable PrometheusRules for Istio alerting"
  type        = bool
  default     = true
}
