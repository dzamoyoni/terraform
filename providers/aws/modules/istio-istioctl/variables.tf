variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "istio_version" {
  description = "Version of Istio to install"
  type        = string
  default     = "1.24.1"
}

variable "istio_namespace" {
  description = "Namespace for Istio system components"
  type        = string
  default     = "istio-system"
}

variable "enable_ambient_mode" {
  description = "Enable Istio ambient mode"
  type        = bool
  default     = false
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

variable "ambient_namespaces" {
  description = "List of namespaces to enable ambient mode for"
  type        = list(string)
  default     = []
}

variable "gateway_service_type" {
  description = "Service type for Istio gateways (LoadBalancer, NodePort, ClusterIP)"
  type        = string
  default     = "LoadBalancer"
  
  validation {
    condition     = contains(["LoadBalancer", "NodePort", "ClusterIP"], var.gateway_service_type)
    error_message = "Gateway service type must be LoadBalancer, NodePort, or ClusterIP."
  }
}

variable "ingress_gateway_replicas" {
  description = "Number of replicas for the ingress gateway"
  type        = number
  default     = 2
}

variable "istiod_resources" {
  description = "Resource requests and limits for Istiod"
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
      memory = "2048Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2048Mi"
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
      cpu    = "2000m"
      memory = "1024Mi"
    }
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_namespaces" {
  description = "Whether to create namespaces that don't exist"
  type        = bool
  default     = true
}

variable "enable_kiali" {
  description = "Enable Kiali service mesh observability"
  type        = bool
  default     = true
}

variable "enable_jaeger" {
  description = "Enable Jaeger distributed tracing"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana for Istio metrics visualization"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus for Istio metrics collection"
  type        = bool
  default     = true
}

variable "kiali_auth_strategy" {
  description = "Kiali authentication strategy (anonymous, login, openshift, openid, header, token)"
  type        = string
  default     = "anonymous"
}

variable "observability_namespace" {
  description = "Namespace for observability tools (Kiali, Jaeger, Grafana, Prometheus)"
  type        = string
  default     = "istio-system"
}
