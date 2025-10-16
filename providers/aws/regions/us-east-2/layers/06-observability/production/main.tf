# ============================================================================
#  Observability Layer - US-East-2 Production
# ============================================================================
# Comprehensive observability stack for multi-tenant EKS environment:
# - System Node Isolation: Heavy workloads run on dedicated system nodes
# - DaemonSet Monitoring: Light monitoring DaemonSets run on all nodes
# - S3 Storage Backend: All observability data stored in S3
# - Production HA: Multi-replica setup with anti-affinity
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
# Data Sources - Integration with Existing Layers
# ============================================================================

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

data "terraform_remote_state" "shared_services" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/05-shared-services/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}

# AWS Account and Region Information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# EKS Cluster Information from Platform Layer
data "aws_eks_cluster" "main" {
  name = data.terraform_remote_state.platform.outputs.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.platform.outputs.cluster_name
}

# OIDC Provider for IRSA
data "aws_iam_openid_connect_provider" "eks" {
  url = data.terraform_remote_state.platform.outputs.cluster_oidc_issuer_url
}

# ============================================================================
# Enterprise Tagging Standards
# ============================================================================

module "tags" {
  source = "../../../../../../../modules/tagging"
  
  # Core configuration
  project_name = var.project_name
  environment  = var.environment
  layer_name   = "observability"
  region       = var.region
  
  # Layer-specific configuration
  layer_purpose    = "Monitoring, Logging, Tracing, and Alerting"
  deployment_phase = "Phase-5"  # After shared services
  
  # Infrastructure classification
  critical_infrastructure = "true"
  backup_required         = "true"
  security_level          = "High"
  
  # Cost management
  cost_center     = "IT-Infrastructure"
  owner           = "Platform-Engineering"
  chargeback_code = "OBS1-MONITORING-001"
  
  # Operational settings
  sla_tier           = "Gold"
  monitoring_level   = "Enhanced"
  maintenance_window = "Sunday-02:00-04:00-UTC"
  
  # Governance
  compliance_framework = "SOC2-ISO27001"
  data_classification  = "Internal"
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  region = var.region

  default_tags {
    tags = module.tags.standard_tags
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
  load_config_file       = false
}

# ============================================================================
# Local Variables - Platform Integration
# ============================================================================

locals {
  # Platform layer integration
  cluster_name            = data.terraform_remote_state.platform.outputs.cluster_name
  cluster_endpoint        = data.terraform_remote_state.platform.outputs.cluster_endpoint
  cluster_ca_certificate  = base64decode(data.terraform_remote_state.platform.outputs.cluster_certificate_authority_data)
  oidc_provider_arn       = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = data.terraform_remote_state.platform.outputs.cluster_oidc_issuer_url

  # Foundation layer integration
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  platform_subnet_ids = data.terraform_remote_state.foundation.outputs.platform_subnet_ids
  availability_zones  = data.terraform_remote_state.foundation.outputs.availability_zones

  # Standard tags for all resources
  standard_tags = module.tags.standard_tags
  
  # Kubernetes labels for resources - Clean and Dynamic
  common_labels = {
    "app.kubernetes.io/managed-by"  = "terraform"
    "app.kubernetes.io/part-of"     = "observability-stack"
    "app.kubernetes.io/component"   = "monitoring"
    "app.kubernetes.io/version"     = "v1.0.0"
    "managed-by"                    = "terraform"
    "layer"                         = "observability"
    "environment"                   = var.environment
    "region"                        = var.region
    "project"                       = var.project_name
    "deployment-phase"              = "phase-5"
    "workload-isolation"            = "system-nodes"
    "observability-stack"           = "prometheus-grafana-loki-tempo"
  }

  # System Node Group Configuration for Heavy Workloads
  system_node_config = {
    node_selector = {
      "workload-type" = "system"
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
  }

  # DaemonSet Configuration for All-Node Monitoring
  daemonset_config = {
    tolerations = [
      {
        operator = "Exists"
        effect   = ""
      }
    ]
    resources = {
      limits = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }

  # Tenant configurations for monitoring
  tenant_configs = [
    {
      name      = "est-test-a-prod"
      namespace = "est-test-a-prod"
      labels = {
        tenant      = "est-test-a-prod"
        client      = "est-test-a"
        tier        = "production"
        client_code = "ETA"
      }
    },
    {
      name      = "est-test-b-prod"
      namespace = "est-test-b-prod"
      labels = {
        tenant      = "est-test-b-prod"
        client      = "est-test-b"
        tier        = "production"
        client_code = "ETB"
      }
    },
    {
      name      = "analytics"
      namespace = "analytics"
      labels = {
        tenant      = "analytics"
        client      = "shared"
        tier        = "production"
        client_code = "ANA"
      }
    }
  ]
}

# ============================================================================
# Monitoring Namespace
# ============================================================================

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = "monitoring"
    labels = local.common_labels
    
    annotations = {
      "workload-type" = "system"
      "managed-by"    = "terraform"
    }
  }
}

# ============================================================================
# S3 Buckets for Observability Data - Reference Existing Buckets
# ============================================================================
# These buckets were created by provision-s3-infrastructure.sh with proper
# lifecycle policies, versioning, intelligent tiering, and structured keys

# Reference existing Logs S3 Bucket
data "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.region}-logs-${var.environment}"
}

# Reference existing Traces S3 Bucket
data "aws_s3_bucket" "traces" {
  bucket = "${var.project_name}-${var.region}-traces-${var.environment}"
}

# Reference existing Metrics S3 Bucket
data "aws_s3_bucket" "metrics" {
  bucket = "${var.project_name}-${var.region}-metrics-${var.environment}"
}

# Reference existing Audit Logs S3 Bucket
data "aws_s3_bucket" "audit_logs" {
  bucket = "${var.project_name}-${var.region}-audit-logs-${var.environment}"
}

# ============================================================================
# IAM Roles for Service Accounts (IRSA) - Direct Implementation
# ============================================================================

# IAM Role for Fluent Bit
resource "aws_iam_role" "fluent_bit_role" {
  name = "${var.project_name}-${var.region}-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:monitoring:fluent-bit"
            "${replace(local.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.standard_tags
}

# IAM Policy for Fluent Bit
resource "aws_iam_policy" "fluent_bit_policy" {
  name        = "${var.project_name}-${var.region}-fluent-bit-policy"
  description = "Policy for Fluent Bit to access S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.aws_s3_bucket.logs.arn,
          "${data.aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })

  tags = local.standard_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "fluent_bit_policy" {
  role       = aws_iam_role.fluent_bit_role.name
  policy_arn = aws_iam_policy.fluent_bit_policy.arn
}

# IAM Role for Tempo
resource "aws_iam_role" "tempo_role" {
  name = "${var.project_name}-${var.region}-tempo-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:monitoring:tempo"
            "${replace(local.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.standard_tags
}

# IAM Policy for Tempo
resource "aws_iam_policy" "tempo_policy" {
  name        = "${var.project_name}-${var.region}-tempo-policy"
  description = "Policy for Tempo to access S3 for traces storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.aws_s3_bucket.traces.arn,
          "${data.aws_s3_bucket.traces.arn}/*"
        ]
      }
    ]
  })

  tags = local.standard_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "tempo_policy" {
  role       = aws_iam_role.tempo_role.name
  policy_arn = aws_iam_policy.tempo_policy.arn
}

# ============================================================================
# Storage Classes for Observability Workloads
# ============================================================================

resource "kubernetes_storage_class_v1" "gp2_csi" {
  metadata {
    name   = "gp2-csi"
    labels = local.common_labels
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp2"
    fsType = "ext4"
  }
}

# Remove old default storage class
resource "null_resource" "remove_old_default" {
  provisioner "local-exec" {
    command = <<-EOF
      kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=false --overwrite || true
    EOF
  }

  depends_on = [kubernetes_storage_class_v1.gp2_csi]
}