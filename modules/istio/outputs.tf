output "istio_version" {
  description = "The version of Istio deployed"
  value       = var.istio_version
}

output "istio_revision" {
  description = "The Istio revision deployed"
  value       = var.istio_revision
}

output "istio_namespace" {
  description = "The namespace where Istio is deployed"
  value       = "istio-system"
}

output "ingress_gateway_enabled" {
  description = "Whether the ingress gateway is enabled"
  value       = var.enable_ingress_gateway
}

output "egress_gateway_enabled" {
  description = "Whether the egress gateway is enabled"
  value       = var.enable_egress_gateway
}

output "ambient_mode_enabled" {
  description = "Whether ambient mode is enabled"
  value       = var.enable_ambient_mode
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.enable_monitoring
}

output "mesh_id" {
  description = "The mesh ID for Istio"
  value       = var.mesh_id
}

output "network_name" {
  description = "The network name for Istio"
  value       = var.network_name
}

output "helm_releases" {
  description = "Information about the Istio Helm releases"
  value = {
    base = {
      name      = helm_release.istio_base.name
      namespace = helm_release.istio_base.namespace
      version   = helm_release.istio_base.version
      status    = helm_release.istio_base.status
    }
    istiod = {
      name      = helm_release.istiod.name
      namespace = helm_release.istiod.namespace
      version   = helm_release.istiod.version
      status    = helm_release.istiod.status
    }
    cni = null  # CNI is managed by existing AWS CNI configuration
    ztunnel = length(helm_release.ztunnel) > 0 ? {
      name      = helm_release.ztunnel[0].name
      namespace = helm_release.ztunnel[0].namespace
      version   = helm_release.ztunnel[0].version
      status    = helm_release.ztunnel[0].status
    } : null
    ingress_gateway = length(helm_release.istio_ingress) > 0 ? {
      name      = helm_release.istio_ingress[0].name
      namespace = helm_release.istio_ingress[0].namespace
      version   = helm_release.istio_ingress[0].version
      status    = helm_release.istio_ingress[0].status
    } : null
    egress_gateway = length(helm_release.istio_egress) > 0 ? {
      name      = helm_release.istio_egress[0].name
      namespace = helm_release.istio_egress[0].namespace
      version   = helm_release.istio_egress[0].version
      status    = helm_release.istio_egress[0].status
    } : null
  }
}

output "ingress_gateway_service_name" {
  description = "The name of the ingress gateway service"
  value       = var.enable_ingress_gateway ? "istio-ingressgateway" : null
}

output "egress_gateway_service_name" {
  description = "The name of the egress gateway service"
  value       = var.enable_egress_gateway ? "istio-egressgateway" : null
}

output "ambient_namespaces" {
  description = "List of namespaces with ambient mode enabled"
  value       = var.ambient_namespaces
}

output "istio_components_deployed" {
  description = "Whether Istio components were deployed by this module"
  value       = true
}
