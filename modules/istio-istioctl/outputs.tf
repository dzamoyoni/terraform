output "istio_version" {
  description = "Version of Istio installed"
  value       = var.istio_version
}

output "istio_namespace" {
  description = "Namespace where Istio is installed"
  value       = var.istio_namespace
}

output "ingress_gateway_enabled" {
  description = "Whether ingress gateway is enabled"
  value       = var.enable_ingress_gateway
}

output "egress_gateway_enabled" {
  description = "Whether egress gateway is enabled"
  value       = var.enable_egress_gateway
}

output "ambient_mode_enabled" {
  description = "Whether ambient mode is enabled"
  value       = var.enable_ambient_mode
}

output "ambient_namespaces" {
  description = "List of namespaces with ambient mode enabled"
  value       = var.ambient_namespaces
}

output "ingress_gateway_service_name" {
  description = "Name of the ingress gateway service"
  value       = var.enable_ingress_gateway ? "istio-ingressgateway" : null
}
