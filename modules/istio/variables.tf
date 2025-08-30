variable "istio_version" {
  description = "The version of Istio to install"
  type        = string
  default     = "1.23.1"
}

variable "istio_revision" {
  description = "The Istio revision to use"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

# Note: This module automatically detects existing Istio installations
# and skips installation if Istio components are already present in the cluster.
# This prevents conflicts and makes the module idempotent.

variable "mesh_id" {
  description = "The mesh ID for Istio"
  type        = string
  default     = "cluster.local"
}

variable "network_name" {
  description = "The network name for Istio"
  type        = string
  default     = "network1"
}

variable "enable_ambient_mode" {
  description = "Enable Istio ambient mesh mode"
  type        = bool
  default     = true
}

variable "enable_ingress_gateway" {
  description = "Enable Istio ingress gateway"
  type        = bool
  default     = true
}

variable "enable_egress_gateway" {
  description = "Enable Istio egress gateway"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable Istio monitoring with ServiceMonitor"
  type        = bool
  default     = false
}

variable "ingress_gateway_type" {
  description = "The service type for the ingress gateway (ClusterIP, LoadBalancer, NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "ingress_gateway_annotations" {
  description = "Annotations for the ingress gateway service"
  type        = map(string)
  default     = {}
}

variable "ambient_namespaces" {
  description = "List of namespaces to enable ambient mode for"
  type        = list(string)
  default     = []
}

# Resource configurations
variable "istiod_resources" {
  description = "Resource requests and limits for istiod"
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
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "cni_resources" {
  description = "Resource requests and limits for Istio CNI"
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
      cpu    = "10m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

variable "ztunnel_resources" {
  description = "Resource requests and limits for ztunnel"
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
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

variable "gateway_resources" {
  description = "Resource requests and limits for gateways"
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
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1024Mi"
    }
  }
}

variable "gateway_autoscaling" {
  description = "Autoscaling configuration for gateways"
  type = object({
    enabled      = bool
    min_replicas = number
    max_replicas = number
    target_cpu   = number
  })
  default = {
    enabled      = true
    min_replicas = 1
    max_replicas = 5
    target_cpu   = 80
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
