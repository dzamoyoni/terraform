# CPTWN Shared Services Wrapper Module
# Deploys essential Kubernetes services following CPTWN standards
# Services: Cluster Autoscaler, AWS Load Balancer Controller, Metrics Server, External DNS

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
  }
}

# LOCALS - CPTWN Standards and Configuration
locals {
  # CPTWN standard tags applied to all resources
  cptwn_tags = merge(
    {
      Project            = var.project_name
      Environment        = var.environment
      ManagedBy         = "Terraform"
      CriticalInfra     = "true"
      BackupRequired    = "true"
      SecurityLevel     = "High"
      Region            = var.region
      Layer             = "SharedServices"
      DeploymentPhase   = "Phase-2"
      Company           = "CPTWN"
      Architecture      = "Multi-Client"
    },
    var.additional_tags
  )
  
  # Service naming standards
  cluster_autoscaler_name = "${var.cluster_name}-cluster-autoscaler"
  alb_controller_name     = "${var.cluster_name}-aws-load-balancer-controller"
  external_dns_name       = "${var.cluster_name}-external-dns"
  
  # Extract OIDC provider ID from the ARN
  oidc_provider_id = replace(var.cluster_oidc_issuer_url, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")
}

#  DATA SOURCES
data "aws_caller_identity" "current" {}

# CLUSTER AUTOSCALER
module "cluster_autoscaler" {
  count  = var.enable_cluster_autoscaler ? 1 : 0
  source = "./cluster-autoscaler"
  
  # Core configuration
  cluster_name          = var.cluster_name
  region               = var.region
  environment          = var.environment
  
  # IAM configuration
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_id     = local.oidc_provider_id
  
  # Service configuration
  helm_chart_version   = var.cluster_autoscaler_version
  service_account_name = "${local.cluster_autoscaler_name}-sa"
  
  # Autoscaler behavior
  scale_down_enabled                     = var.cluster_autoscaler_scale_down_enabled
  scale_down_delay_after_add            = var.cluster_autoscaler_scale_down_delay_after_add
  scale_down_unneeded_time              = var.cluster_autoscaler_scale_down_unneeded_time
  skip_nodes_with_local_storage         = var.cluster_autoscaler_skip_nodes_with_local_storage
  
  # CPTWN standards
  tags = local.cptwn_tags
}

# AWS LOAD BALANCER CONTROLLER
module "aws_load_balancer_controller" {
  count  = var.enable_aws_load_balancer_controller ? 1 : 0
  source = "./aws-load-balancer-controller"
  
  # Core configuration
  cluster_name          = var.cluster_name
  region               = var.region
  environment          = var.environment
  vpc_id               = var.vpc_id
  
  # IAM configuration
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_id     = local.oidc_provider_id
  
  # Service configuration
  helm_chart_version   = var.aws_load_balancer_controller_version
  service_account_name = "${local.alb_controller_name}-sa"
  
  # CPTWN standards
  tags = local.cptwn_tags
}

# METRICS SERVER
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0
  
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = "kube-system"
  
  set {
    name  = "metrics.enabled"
    value = "true"
  }
  
  set {
    name  = "serviceMonitor.enabled"
    value = "false"  # Enable when Prometheus is deployed
  }
  
  # Security settings - use standard metrics-server port
  set {
    name  = "args"
    value = "{--cert-dir=/tmp,--secure-port=10250,--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname,--kubelet-use-node-status-port,--metric-resolution=15s}"
  }
  
  # Resource management
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  
  set {
    name  = "resources.requests.memory"
    value = "200Mi"
  }
  
  # Node affinity for stability
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "kubernetes.io/arch"
  }
  
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }
  
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "amd64"
  }
}

# 🌐 EXTERNAL DNS (Optional - Placeholder for future implementation)
# This will be implemented when Route 53 DNS zones are configured
# For now, we just provide a placeholder output
locals {
  external_dns_iam_role_arn = var.enable_external_dns ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-external-dns-role" : null
}
