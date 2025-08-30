# ============================================================================
# Platform Layer Variables
# ============================================================================
# Variables for the platform layer (EKS cluster and shared services)

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# ============================================================================
# EBS CSI Driver Configuration
# ============================================================================

variable "ebs_csi_addon_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = "v1.35.0-eksbuild.1"
}

# ============================================================================
# DNS Configuration  
# ============================================================================

variable "dns_zones" {
  description = "DNS zones to create for different clients"
  type = map(object({
    comment     = string
    environment = string
    client      = string
  }))
  default = {}
}

variable "enable_external_dns" {
  description = "Enable ExternalDNS for automatic DNS management"
  type        = bool
  default     = true
}

# ============================================================================
# IngressClass Configuration
# ============================================================================

variable "alb_ingress_class_name" {
  description = "Name for the ALB IngressClass"
  type        = string
  default     = "alb"
}

variable "set_alb_as_default" {
  description = "Whether to set the ALB IngressClass as default"
  type        = bool
  default     = true
}

variable "create_nlb_ingress_class" {
  description = "Whether to create NLB IngressClass"
  type        = bool
  default     = false
}

variable "nlb_ingress_class_name" {
  description = "Name for the NLB IngressClass"
  type        = string
  default     = "nlb"
}

variable "nlb_scheme" {
  description = "Scheme for NLB (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
  
  validation {
    condition     = contains(["internet-facing", "internal"], var.nlb_scheme)
    error_message = "NLB scheme must be either 'internet-facing' or 'internal'."
  }
}

variable "create_nginx_ingress_class" {
  description = "Whether to create nginx IngressClass"
  type        = bool
  default     = false
}

variable "nginx_ingress_class_name" {
  description = "Name for the nginx IngressClass"
  type        = string
  default     = "nginx"
}

# ============================================================================
# Istio Configuration
# ============================================================================

variable "enable_istio" {
  description = "Enable Istio service mesh deployment"
  type        = bool
  default     = false
}

variable "istio_version" {
  description = "Version of Istio to deploy"
  type        = string
  default     = "1.23.1"
}

variable "istio_ambient_mode" {
  description = "Enable Istio ambient mesh mode"
  type        = bool
  default     = true
}

variable "istio_ingress_gateway" {
  description = "Enable Istio ingress gateway"
  type        = bool
  default     = true
}

variable "istio_egress_gateway" {
  description = "Enable Istio egress gateway"
  type        = bool
  default     = false
}

variable "istio_ingress_gateway_type" {
  description = "Service type for Istio ingress gateway (ClusterIP, LoadBalancer, NodePort)"
  type        = string
  default     = "ClusterIP"
}

variable "istio_monitoring" {
  description = "Enable Istio monitoring with ServiceMonitor resources"
  type        = bool
  default     = false
}

variable "istio_ambient_namespaces" {
  description = "List of namespaces to enable ambient mode for"
  type        = list(string)
  default     = []
}
