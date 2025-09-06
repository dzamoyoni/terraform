# ============================================================================
# 📊 Observability Layer - US-East-1 Production
# ============================================================================
# This layer provides comprehensive observability for the multi-tenant EKS
# environment with:
# - Fluent Bit for log shipping to S3
# - Grafana Tempo for distributed tracing with S3 backend
# - Prometheus with remote write to central Grafana
# - Kiali for service mesh visualization
# - Tenant isolation and data partitioning
# ============================================================================

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

# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project            = "US-East-1-Multi-Client-EKS"
      Environment        = var.environment
      ManagedBy         = "Terraform"
      CriticalInfra     = "true"
      BackupRequired    = "true"
      SecurityLevel     = "High"
      Region            = var.region
      Layer             = "Observability"
      DeploymentPhase   = "Phase-3.5"
    }
  }
}

# Get cluster information from SSM parameters
data "aws_ssm_parameter" "cluster_name" {
  name = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-name"
}

data "aws_ssm_parameter" "cluster_oidc_issuer_arn" {
  name = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-oidc-issuer-arn"
}

data "aws_ssm_parameter" "cluster_endpoint" {
  name = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-endpoint"
}

data "aws_ssm_parameter" "cluster_ca_certificate" {
  name = "/${var.project_name}/${var.environment}/${var.region}/platform/cluster-certificate-authority-data"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_ssm_parameter.cluster_endpoint.value
  cluster_ca_certificate = base64decode(data.aws_ssm_parameter.cluster_ca_certificate.value)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_ssm_parameter.cluster_name.value]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_ssm_parameter.cluster_endpoint.value
    cluster_ca_certificate = base64decode(data.aws_ssm_parameter.cluster_ca_certificate.value)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_ssm_parameter.cluster_name.value]
    }
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Common tags for all resources
  common_tags = {
    Project            = "US-East-1-Multi-Client-EKS"
    Environment        = var.environment
    ManagedBy         = "Terraform"
    CriticalInfra     = "true"
    Layer             = "Observability"
    DeploymentPhase   = "Phase-3.5"
    Region            = var.region
  }

  # Common labels for Kubernetes resources
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "observability-stack"
    region                         = var.region
    environment                    = var.environment
  }

  # Tenant configurations based on US-East-1 setup
  tenant_configs = [
    {
      name      = "ezra-fintech-prod"
      namespace = "ezra-fintech-prod"
      labels = {
        tenant = "ezra-fintech-prod"
        client = "ezra-fintech"
        tier   = "production"
      }
    },
    {
      name      = "mtn-ghana-prod"
      namespace = "mtn-ghana-prod"
      labels = {
        tenant = "mtn-ghana-prod"
        client = "mtn-ghana"
        tier   = "production"
      }
    },
    {
      name      = "platform"
      namespace = "istio-system"
      labels = {
        tenant = "platform"
        client = "platform"
        tier   = "system"
      }
    }
  ]
}

# ============================================================================
# 📊 Observability Layer Module
# ============================================================================

module "observability" {
  source = "../../../../../modules/observability-layer"

  # Core Configuration
  project_name             = var.project_name
  environment              = var.environment
  region                   = var.region
  cluster_name            = data.aws_ssm_parameter.cluster_name.value
  cluster_oidc_issuer_arn = data.aws_ssm_parameter.cluster_oidc_issuer_arn.value

  # Tenant Configuration
  tenant_configs = local.tenant_configs

  # Tags and Labels
  common_tags   = local.common_tags
  common_labels = local.common_labels

  # S3 Configuration
  logs_retention_days   = var.logs_retention_days
  traces_retention_days = var.traces_retention_days

  # Fluent Bit Configuration
  enable_fluent_bit = true
  fluent_bit_resources = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }

  # Grafana Tempo Configuration
  enable_tempo = true
  tempo_resources = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }

  # Prometheus Configuration with Remote Write
  enable_prometheus                = var.enable_local_prometheus
  prometheus_remote_write_url      = var.prometheus_remote_write_url
  prometheus_remote_write_username = var.prometheus_remote_write_username
  prometheus_remote_write_password = var.prometheus_remote_write_password
  prometheus_storage_size          = "20Gi"  # US-East-1 gets larger storage
  prometheus_resources = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }

  # Kiali Configuration
  enable_kiali         = true
  kiali_auth_strategy  = var.kiali_auth_strategy
  external_prometheus_url = var.external_prometheus_url

  depends_on = [
    data.aws_ssm_parameter.cluster_name,
    data.aws_ssm_parameter.cluster_oidc_issuer_arn
  ]
}

# ============================================================================
# 🔄 LOCALS for computed values
# ============================================================================

locals {
  cluster_name = data.aws_ssm_parameter.cluster_name.value
}
