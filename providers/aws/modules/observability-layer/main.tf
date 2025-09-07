# ============================================================================
# Observability Layer Module
# ============================================================================
# This module provides comprehensive observability infrastructure for
# multi-tenant, multi-region EKS environments with:
# - Fluent Bit for log shipping to S3
# - Grafana Tempo for distributed tracing
# - Prometheus with remote write capabilities  
# - S3 backends for logs and traces
# - Tenant isolation and data partitioning
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
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
}

# ============================================================================
# Local Variables and Configuration
# ============================================================================

locals {
  # Common tags applied to all resources
  common_tags = merge(var.common_tags, {
    Layer       = "Observability"
    ManagedBy   = "Terraform"
    Component   = "Observability-Stack"
    Region      = var.region
    Environment = var.environment
  })

  # Observability namespace
  observability_namespace = "istio-system"

  # S3 bucket naming
  logs_bucket_name   = "${var.project_name}-${var.region}-logs-${var.environment}"
  traces_bucket_name = "${var.project_name}-${var.region}-traces-${var.environment}"
  
  # Service account names
  fluent_bit_sa_name = "fluent-bit"
  tempo_sa_name      = "tempo"
  prometheus_sa_name = "prometheus"

  # Client tenant configurations
  tenant_configs = {
    for tenant in var.tenant_configs : tenant.name => {
      name      = tenant.name
      namespace = tenant.namespace
      labels    = tenant.labels
    }
  }
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# ============================================================================
# S3 Buckets for Logs and Traces
# ============================================================================

# Logs S3 Bucket
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name
  tags   = merge(local.common_tags, {
    Purpose = "Application and Infrastructure Logs"
    Type    = "Logs"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Traces S3 Bucket
resource "aws_s3_bucket" "traces" {
  bucket = local.traces_bucket_name
  tags   = merge(local.common_tags, {
    Purpose = "Distributed Traces"
    Type    = "Traces"
  })
}

resource "aws_s3_bucket_versioning" "traces" {
  bucket = aws_s3_bucket.traces.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traces" {
  bucket = aws_s3_bucket.traces.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "traces" {
  bucket = aws_s3_bucket.traces.id

  rule {
    id     = "traces_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.traces_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ============================================================================
# IAM Roles and Policies for IRSA
# ============================================================================

# Fluent Bit IAM Policy
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
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = local.common_tags
}

# Fluent Bit IAM Role
module "fluent_bit_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-${var.region}-fluent-bit-role"
  role_policy_arns = {
    fluent_bit_policy = aws_iam_policy.fluent_bit_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.cluster_oidc_issuer_arn
      namespace_service_accounts = ["${local.observability_namespace}:${local.fluent_bit_sa_name}"]
    }
  }

  tags = local.common_tags
}

# Tempo IAM Policy
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
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.traces.arn,
          "${aws_s3_bucket.traces.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Tempo IAM Role
module "tempo_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-${var.region}-tempo-role"
  role_policy_arns = {
    tempo_policy = aws_iam_policy.tempo_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.cluster_oidc_issuer_arn
      namespace_service_accounts = ["${local.observability_namespace}:${local.tempo_sa_name}"]
    }
  }

  tags = local.common_tags
}

# ============================================================================
# Kubernetes Configurations
# ============================================================================

# Create ConfigMaps for Fluent Bit
resource "kubernetes_config_map" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = local.observability_namespace
    labels = merge(var.common_labels, {
      app = "fluent-bit"
    })
  }

  data = {
    "fluent-bit.conf" = templatefile("${path.module}/templates/fluent-bit.conf.tpl", {
      cluster_name    = var.cluster_name
      region          = var.region
      s3_bucket_name  = aws_s3_bucket.logs.bucket
      tenant_configs  = local.tenant_configs
    })
    
    "parsers.conf" = file("${path.module}/templates/parsers.conf")
  }

  depends_on = [aws_s3_bucket.logs]
}

# Create Service Account for Fluent Bit
resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = local.fluent_bit_sa_name
    namespace = local.observability_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.fluent_bit_irsa.iam_role_arn
    }
    labels = merge(var.common_labels, {
      app = "fluent-bit"
    })
  }
}

# Create Service Account for Tempo
resource "kubernetes_service_account" "tempo" {
  metadata {
    name      = local.tempo_sa_name
    namespace = local.observability_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.tempo_irsa.iam_role_arn
    }
    labels = merge(var.common_labels, {
      app = "tempo"
    })
  }
}

# ============================================================================
# Helm Charts Deployment
# ============================================================================

# Deploy Fluent Bit
resource "helm_release" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = var.fluent_bit_chart_version
  namespace  = local.observability_namespace

  values = [templatefile("${path.module}/templates/fluent-bit-values.yaml.tpl", {
    service_account_name = kubernetes_service_account.fluent_bit.metadata[0].name
    cluster_name        = var.cluster_name
    region              = var.region
    s3_bucket_name      = aws_s3_bucket.logs.bucket
    image_tag           = var.fluent_bit_image_tag
    resources           = var.fluent_bit_resources
  })]

  depends_on = [
    kubernetes_config_map.fluent_bit_config,
    kubernetes_service_account.fluent_bit,
    module.fluent_bit_irsa
  ]
}

# Deploy Grafana Tempo
resource "helm_release" "tempo" {
  count = var.enable_tempo ? 1 : 0

  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.tempo_chart_version
  namespace  = local.observability_namespace

  values = [templatefile("${path.module}/templates/tempo-values.yaml.tpl", {
    service_account_name = kubernetes_service_account.tempo.metadata[0].name
    s3_bucket_name      = aws_s3_bucket.traces.bucket
    region              = var.region
    cluster_name        = var.cluster_name
    resources           = var.tempo_resources
  })]

  depends_on = [
    kubernetes_service_account.tempo,
    module.tempo_irsa
  ]
}

# Deploy Prometheus with Remote Write
resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_chart_version
  namespace  = local.observability_namespace

  values = [templatefile("${path.module}/templates/prometheus-values.yaml.tpl", {
    cluster_name           = var.cluster_name
    region                = var.region  
    remote_write_url      = var.prometheus_remote_write_url
    remote_write_username = var.prometheus_remote_write_username
    remote_write_password = var.prometheus_remote_write_password
    tenant_configs        = local.tenant_configs
    storage_size          = var.prometheus_storage_size
    resources             = var.prometheus_resources
  })]

  set_sensitive {
    name  = "prometheus.prometheusSpec.remoteWrite[0].basicAuth.password.value"
    value = var.prometheus_remote_write_password
  }
}

# ============================================================================
# Kiali for Service Mesh Visualization
# ============================================================================

resource "helm_release" "kiali" {
  count = var.enable_kiali ? 1 : 0

  name       = "kiali-server"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = var.kiali_chart_version
  namespace  = local.observability_namespace

  values = [templatefile("${path.module}/templates/kiali-values.yaml.tpl", {
    cluster_name = var.cluster_name
    region      = var.region
    auth_strategy = var.kiali_auth_strategy
    prometheus_url = var.enable_prometheus ? "http://prometheus-kube-prometheus-prometheus:9090" : var.external_prometheus_url
  })]

  depends_on = [helm_release.prometheus]
}
