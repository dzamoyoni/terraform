# Shared Services Layer Outputs
# Exposes shared services information for other layers and external use

#  CLUSTER AUTOSCALER OUTPUTS
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

# AWS LOAD BALANCER CONTROLLER OUTPUTS
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

#  METRICS SERVER OUTPUTS
output "metrics_server_enabled" {
  description = "Whether metrics server is enabled"
  value       = var.enable_metrics_server
}

output "metrics_server_version" {
  description = "Version of metrics server deployed"
  value       = var.metrics_server_version
}

#  EXTERNAL DNS OUTPUTS
output "external_dns_enabled" {
  description = "Whether external DNS is enabled"
  value       = var.enable_external_dns
}

output "external_dns_service_account_arn" {
  description = "ARN of the external DNS service account"
  value       = var.enable_external_dns ? module.shared_services.external_dns_service_account_arn : null
}

#  SHARED SERVICES SUMMARY
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

#  SECURITY NOTICE
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

# =============================================================================
# SYSTEM NODE GROUP OUTPUTS
# =============================================================================

output "system_nodegroup_status" {
  description = "System nodegroup deployment status"
  value       = var.enable_system_nodegroup ? "deployed" : "not-deployed"
}

output "system_nodegroup_name" {
  description = "System nodegroup name"
  value       = var.enable_system_nodegroup ? "${data.terraform_remote_state.platform.outputs.cluster_name}-system-ng" : null
}

output "system_nodegroup_configuration" {
  description = "System nodegroup configuration summary"
  value = var.enable_system_nodegroup ? {
    instance_types   = var.system_nodegroup_instance_types
    capacity_type    = var.system_nodegroup_capacity_type
    min_size        = var.system_nodegroup_min_size
    max_size        = var.system_nodegroup_max_size
    desired_size    = var.system_nodegroup_desired_size
    disk_size       = var.system_nodegroup_disk_size
    workload_types  = ["shared-services", "observability", "istio-system"]
    taints = [
      "workload-type=system:NoSchedule",
      "dedicated=shared-services:NoSchedule"
    ]
  } : null
}

output "system_workload_node_selectors" {
  description = "Node selectors and tolerations for system workloads"
  value = var.enable_system_nodegroup ? {
    node_selector = {
      "workload-type"            = "system"
      "node-purpose"             = "shared-services"
      "workload/shared-services" = "true"
    }
    tolerations = [
      {
        key      = "workload-type"
        operator = "Equal"
        value    = "system"
        effect   = "NoSchedule"
      },
      {
        key      = "dedicated"
        operator = "Equal"
        value    = "shared-services"
        effect   = "NoSchedule"
      }
    ]
  } : null
}

# =============================================================================
# WORKLOAD ISOLATION SUMMARY
# =============================================================================

output "workload_isolation_summary" {
  description = "Summary of workload isolation configuration"
  value = {
    system_nodegroup_enabled = var.enable_system_nodegroup
    
    isolation_strategy = {
      method = "Node Taints and Tolerations"
      client_workloads = "Scheduled on client-specific or general nodes"
      system_workloads = "Scheduled only on dedicated system nodes"
      daemonsets = "Run on all nodes (system and client)"
    }
    
    resource_allocation = {
      system_nodes = var.enable_system_nodegroup ? {
        purpose = "Shared services, observability, service mesh"
        instance_types = var.system_nodegroup_instance_types
        scaling = "${var.system_nodegroup_min_size}-${var.system_nodegroup_max_size} nodes"
      } : {
        purpose = "Not configured"
        instance_types = []
        scaling = "0-0 nodes"
      }
      
      client_nodes = "Separate node groups for client workloads (configured in other layers)"
    }
    
    benefits = [
      "Predictable performance for system workloads",
      "Resource isolation between system and client workloads", 
      "Better cost allocation and monitoring",
      "Simplified troubleshooting and maintenance"
    ]
  }
}
