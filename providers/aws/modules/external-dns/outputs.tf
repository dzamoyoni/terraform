output "service_account_name" {
  description = "Name of the External DNS service account"
  value       = kubernetes_service_account.external_dns.metadata[0].name
}

output "service_account_namespace" {
  description = "Namespace of the External DNS service account"
  value       = kubernetes_service_account.external_dns.metadata[0].namespace
}

output "deployment_name" {
  description = "Name of the External DNS deployment"
  value       = kubernetes_deployment.external_dns.metadata[0].name
}

output "deployment_namespace" {
  description = "Namespace of the External DNS deployment"
  value       = kubernetes_deployment.external_dns.metadata[0].namespace
}

output "domain_filters" {
  description = "Domain filters configured for External DNS"
  value       = var.domain_filters
}
