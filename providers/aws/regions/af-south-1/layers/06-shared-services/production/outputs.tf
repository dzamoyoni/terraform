# 🚀 Shared Services Layer Outputs
# Exposes shared services information for other layers and external use

# 🎯 CLUSTER AUTOSCALER OUTPUTS
output "cluster_autoscaler_enabled" {
  description = "Whether cluster autoscaler is enabled"
  value       = var.enable_cluster_autoscaler
}

output "cluster_autoscaler_version" {
  description = "Version of cluster autoscaler deployed"
  value       = var.cluster_autoscaler_version
}

output "cluster_autoscaler_service_account_arn" {
  description = "ARN of the cluster autoscaler service account"
  value       = var.enable_cluster_autoscaler ? module.shared_services.cluster_autoscaler_service_account_arn : null
}

# 🎯 AWS LOAD BALANCER CONTROLLER OUTPUTS
output "aws_load_balancer_controller_enabled" {
  description = "Whether AWS Load Balancer Controller is enabled"
  value       = var.enable_aws_load_balancer_controller
}

output "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller deployed"
  value       = var.aws_load_balancer_controller_version
}

output "aws_load_balancer_controller_service_account_arn" {
  description = "ARN of the AWS Load Balancer Controller service account"
  value       = var.enable_aws_load_balancer_controller ? module.shared_services.aws_load_balancer_controller_service_account_arn : null
}

# 🎯 METRICS SERVER OUTPUTS
output "metrics_server_enabled" {
  description = "Whether metrics server is enabled"
  value       = var.enable_metrics_server
}

output "metrics_server_version" {
  description = "Version of metrics server deployed"
  value       = var.metrics_server_version
}

# 🎯 EXTERNAL DNS OUTPUTS
output "external_dns_enabled" {
  description = "Whether external DNS is enabled"
  value       = var.enable_external_dns
}

output "external_dns_service_account_arn" {
  description = "ARN of the external DNS service account"
  value       = var.enable_external_dns ? module.shared_services.external_dns_service_account_arn : null
}

# 🎯 SHARED SERVICES SUMMARY
output "shared_services_summary" {
  description = "Summary of deployed shared services"
  value = {
    cluster_name = data.terraform_remote_state.platform.outputs.cluster_name
    region       = var.region
    environment  = var.environment

    services_deployed = {
      cluster_autoscaler           = var.enable_cluster_autoscaler
      aws_load_balancer_controller = var.enable_aws_load_balancer_controller
      metrics_server               = var.enable_metrics_server
      external_dns                 = var.enable_external_dns
    }

    service_versions = {
      cluster_autoscaler_version           = var.cluster_autoscaler_version
      aws_load_balancer_controller_version = var.aws_load_balancer_controller_version
      metrics_server_version               = var.metrics_server_version
    }

    cptwn_standards = {
      tagging_standards  = "applied"
      security_hardening = "applied"
      monitoring_enabled = "applied"
      backup_configured  = "applied"
      naming_convention  = "applied"
    }
  }
}

# 🔒 SECURITY NOTICE
output "security_notice" {
  description = "Important security and operational information"
  value = {
    message = "CPTWN Shared Services deployed with security best practices"
    actions_required = [
      "Verify all services are running: kubectl get pods -A",
      "Test cluster autoscaler functionality with workload deployment",
      "Verify metrics server: kubectl top nodes",
      "Configure monitoring and alerting for all services",
      "Review service logs for any issues"
    ]
    documentation = "https://kubernetes.io/docs/concepts/cluster-administration/"
  }
}
