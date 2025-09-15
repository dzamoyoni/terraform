# ============================================================================
# 📊 Observability Layer - AF-South-1 Production
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
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
      Project         = "CPTWN-Multi-Client-EKS"
      Environment     = var.environment
      ManagedBy       = "Terraform"
      CriticalInfra   = "true"
      BackupRequired  = "true"
      SecurityLevel   = "High"
      Region          = var.region
      Layer           = "Observability"
      DeploymentPhase = "Phase-3.5"
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

# Configure kubectl provider
provider "kubectl" {
  host                   = data.aws_ssm_parameter.cluster_endpoint.value
  cluster_ca_certificate = base64decode(data.aws_ssm_parameter.cluster_ca_certificate.value)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_ssm_parameter.cluster_name.value]
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Common tags for all resources
  common_tags = {
    Project         = "CPTWN-Multi-Client-EKS"
    Environment     = var.environment
    ManagedBy       = "Terraform"
    CriticalInfra   = "true"
    Layer           = "Observability"
    DeploymentPhase = "Phase-3.5"
    Region          = var.region
  }

  # Common labels for Kubernetes resources
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "observability-stack"
    region                         = var.region
    environment                    = var.environment
  }

  # Tenant configurations based on AF-South-1 setup
  tenant_configs = [
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
      name      = "orange-madagascar-prod"
      namespace = "orange-madagascar-prod"
      labels = {
        tenant = "orange-madagascar-prod"
        client = "orange-madagascar"
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
  source = "../../../../../../../modules/observability-layer"

  # Core Configuration
  project_name            = var.project_name
  environment             = var.environment
  region                  = var.region
  cluster_name            = data.aws_ssm_parameter.cluster_name.value
  cluster_oidc_issuer_arn = data.aws_ssm_parameter.cluster_oidc_issuer_arn.value

  # Tenant Configuration
  tenant_configs = local.tenant_configs

  # Tags and Labels
  common_tags   = local.common_tags
  common_labels = local.common_labels

  # EBS CSI Configuration
  node_group_role_names = ["cptwn-eks-01-mtn-gh-nodes-20250915111530579200000002"]
  enable_gp3_storage    = false  # Use cheaper GP2 for now

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

  # Grafana Tempo Configuration - ENABLED
  enable_tempo = true # ✅ Enabled for distributed tracing with S3 backend
  tempo_resources = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1500m" # Increased for better performance
      memory = "3Gi"   # Increased for trace processing
    }
  }

  # Prometheus Configuration - TERRAFORM MANAGED
  enable_prometheus                = true # ✅ Enabled with fixed remote write configuration
  prometheus_remote_write_url      = var.prometheus_remote_write_url
  prometheus_remote_write_username = var.prometheus_remote_write_username
  prometheus_remote_write_password = var.prometheus_remote_write_password
  prometheus_storage_size          = "30Gi" # Increased for production workload
  prometheus_resources = {
    requests = {
      cpu    = "1000m" # Doubled for production
      memory = "2Gi"   # Doubled for production
    }
    limits = {
      cpu    = "2000m" # Doubled for production
      memory = "4Gi"   # Doubled for production
    }
  }

  # Kiali Configuration - TERRAFORM MANAGED  
  enable_kiali            = true    # ✅ Terraform-managed Kiali
  kiali_auth_strategy     = "token" # Enhanced security vs anonymous
  external_prometheus_url = ""      # Will use Terraform-managed Prometheus

  # Cross-region replication (supported variable)
  enable_cross_region_replication = var.enable_cross_region_replication

  # ============================================================================
  # PRODUCTION-GRADE FEATURES - NEW
  # ============================================================================
  
  # AlertManager Configuration
  enable_alertmanager         = var.enable_alertmanager
  alertmanager_storage_class  = var.alertmanager_storage_class
  alertmanager_replicas       = var.alertmanager_replicas
  slack_webhook_url           = var.slack_webhook_url
  alert_email                 = var.alert_email
  
  # Grafana Configuration - TEMPORARY MODE FOR TESTING
  enable_grafana              = var.enable_grafana
  grafana_temporary_mode      = true  # 🧪 Temporary mode - no persistence for testing
  grafana_admin_password      = var.grafana_admin_password
  
  # Enhanced Monitoring
  enable_enhanced_monitoring  = var.enable_enhanced_monitoring
  enable_postgres_monitoring  = var.enable_postgres_monitoring
  postgres_endpoints          = var.postgres_endpoints
  
  # High Availability Configuration
  prometheus_replicas         = var.prometheus_replicas
  enable_prometheus_ha        = var.enable_prometheus_ha
  prometheus_retention        = var.prometheus_retention
  prometheus_retention_size   = var.prometheus_retention_size
  
  # Security Configuration
  enable_network_policies     = var.enable_network_policies
  enable_pod_security_policies = var.enable_pod_security_policies

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
