# Shared Services Layer - AF-South-1 Production
# KUBERNETES SHARED SERVICES
# Deploys essential Kubernetes services on top of EKS platform
# Services: Cluster Autoscaler, AWS Load Balancer Controller, Metrics Server

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Backend configuration loaded from file
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project         = "CPTWN-Multi-Client-EKS"
      Environment     = var.environment
      ManagedBy       = "Terraform"
      CriticalInfra   = "true"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      Region          = var.region
      Layer           = "SharedServices"
      DeploymentPhase = "Phase-2"
    }
  }
}

# DATA SOURCES - Foundation and Platform Layer Outputs
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/02-platform/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

# DATA SOURCES - EKS and AWS Account Info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# LOCALS - Platform Layer Data and CPTWN Standards
locals {
  # Platform layer outputs
  cluster_name            = data.terraform_remote_state.platform.outputs.cluster_name
  cluster_endpoint        = data.terraform_remote_state.platform.outputs.cluster_endpoint
  cluster_ca_certificate  = base64decode(data.terraform_remote_state.platform.outputs.cluster_certificate_authority_data)
  oidc_provider_arn       = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = data.terraform_remote_state.platform.outputs.cluster_oidc_issuer_url
  node_security_group_id  = data.terraform_remote_state.platform.outputs.node_security_group_id

  # Foundation layer outputs
  vpc_id = data.terraform_remote_state.foundation.outputs.vpc_id

  # CPTWN standard tags for all services
  cptwn_tags = {
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    CriticalInfra   = "true"
    BackupRequired  = "true"
    SecurityLevel   = "High"
    Region          = var.region
    Layer           = "SharedServices"
    DeploymentPhase = "Phase-2"
    Company         = "CPTWN"
    Architecture    = "Multi-Client"
  }

  # Service configuration
  cluster_autoscaler_name = "${local.cluster_name}-cluster-autoscaler"
  alb_controller_name     = "${local.cluster_name}-aws-load-balancer-controller"
}

#  Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
  }
}

#  Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
    }
  }
}

#  SHARED SERVICES MODULE
module "shared_services" {
  source = "../../../../../../../modules/shared-services"

  # Core CPTWN configuration
  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  # EKS cluster information
  cluster_name            = local.cluster_name
  cluster_endpoint        = local.cluster_endpoint
  cluster_ca_certificate  = local.cluster_ca_certificate
  oidc_provider_arn       = local.oidc_provider_arn
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  vpc_id                  = local.vpc_id

  # Service configuration
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_metrics_server               = var.enable_metrics_server
  enable_external_dns                 = var.enable_external_dns

  # Cluster autoscaler configuration
  cluster_autoscaler_version = var.cluster_autoscaler_version

  # AWS Load Balancer Controller configuration
  aws_load_balancer_controller_version = var.aws_load_balancer_controller_version

  # DNS configuration
  dns_zone_ids = var.dns_zone_ids

  # CPTWN standard tags
  additional_tags = local.cptwn_tags
}

# =============================================================================
# 🕸️ ISTIO SERVICE MESH MODULE - PRODUCTION GRADE
# =============================================================================
# Deploy Istio with ambient mode, ClusterIP ingress, and integration
# with existing observability layer (Layer 03.5)

module "istio_service_mesh" {
  source = "../../../../../../../modules/istio-service-mesh"
  
  # Only deploy if enabled
  count = var.enable_istio_service_mesh ? 1 : 0

  # Core CPTWN configuration
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  cluster_name = local.cluster_name

  # Istio configuration
  istio_version      = var.istio_version
  mesh_id           = var.istio_mesh_id
  cluster_network   = var.istio_cluster_network
  trust_domain      = var.istio_trust_domain

  # Ambient mode configuration
  enable_ambient_mode = var.enable_istio_ambient_mode

  # Ingress gateway configuration - ClusterIP for internal routing
  enable_ingress_gateway = var.enable_istio_ingress_gateway
  ingress_gateway_replicas = var.istio_ingress_gateway_replicas
  ingress_gateway_resources = var.istio_ingress_gateway_resources
  ingress_gateway_autoscale_enabled = var.istio_ingress_gateway_autoscale_enabled
  ingress_gateway_autoscale_min = var.istio_ingress_gateway_autoscale_min
  ingress_gateway_autoscale_max = var.istio_ingress_gateway_autoscale_max
  
  # Production resource configuration
  istiod_resources = var.istio_istiod_resources
  istiod_autoscale_enabled = var.istio_istiod_autoscale_enabled
  istiod_autoscale_min = var.istio_istiod_autoscale_min
  istiod_autoscale_max = var.istio_istiod_autoscale_max

  # Application namespace configuration - Multi-client setup
  application_namespaces = var.istio_application_namespaces

  # Observability integration with existing Layer 03.5
  enable_distributed_tracing = var.enable_istio_distributed_tracing
  enable_access_logging     = var.enable_istio_access_logging
  tracing_sampling_rate     = var.istio_tracing_sampling_rate
  
  # Monitoring integration with existing Prometheus/Grafana
  enable_service_monitor    = var.enable_istio_service_monitor
  enable_prometheus_rules   = var.enable_istio_prometheus_rules

  # CPTWN standard tags
  additional_tags = local.cptwn_tags
  
  # Ensure shared services are deployed first
  depends_on = [module.shared_services]
}
