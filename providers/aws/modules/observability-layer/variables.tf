# ============================================================================
# Observability Layer Module Variables
# ============================================================================

# ============================================================================
# Core Configuration Variables
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  validation {
    condition     = length(var.project_name) > 0
    error_message = "Project name cannot be empty."
  }
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_oidc_issuer_arn" {
  description = "The OIDC issuer ARN for the EKS cluster"
  type        = string
}

# ============================================================================
# Tenant Configuration
# ============================================================================

variable "tenant_configs" {
  description = "List of tenant configurations for multi-tenancy support"
  type = list(object({
    name      = string
    namespace = string
    labels    = map(string)
  }))
  default = []
}

# ============================================================================
# Common Tags and Labels
# ============================================================================

variable "common_tags" {
  description = "Common tags applied to all AWS resources"
  type        = map(string)
  default     = {}
}

variable "common_labels" {
  description = "Common labels applied to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# S3 Configuration
# ============================================================================

variable "logs_retention_days" {
  description = "Number of days to retain logs in S3"
  type        = number
  default     = 90
  validation {
    condition     = var.logs_retention_days > 0 && var.logs_retention_days <= 365
    error_message = "Logs retention days must be between 1 and 365."
  }
}

variable "traces_retention_days" {
  description = "Number of days to retain traces in S3"
  type        = number
  default     = 90
  validation {
    condition     = var.traces_retention_days > 0 && var.traces_retention_days <= 90
    error_message = "Traces retention days must be between 1 and 90."
  }
}

# ============================================================================
# Fluent Bit Configuration
# ============================================================================

variable "enable_fluent_bit" {
  description = "Enable Fluent Bit for log shipping"
  type        = bool
  default     = true
}

variable "fluent_bit_chart_version" {
  description = "Fluent Bit Helm chart version"
  type        = string
  default     = "0.21.7"
}

variable "fluent_bit_image_tag" {
  description = "Fluent Bit Docker image tag"
  type        = string
  default     = "2.2.2"
}

variable "fluent_bit_resources" {
  description = "Resource requests and limits for Fluent Bit"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

# ============================================================================
# Grafana Tempo Configuration
# ============================================================================

variable "enable_tempo" {
  description = "Enable Grafana Tempo for distributed tracing"
  type        = bool
  default     = true
}

variable "tempo_chart_version" {
  description = "Grafana Tempo Helm chart version"
  type        = string
  default     = "1.7.2"
}

variable "tempo_resources" {
  description = "Resource requests and limits for Tempo"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

# ============================================================================
# Prometheus Configuration
# ============================================================================

variable "enable_prometheus" {
  description = "Enable Prometheus for metrics collection"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version"
  type        = string
  default     = "55.5.0"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "10Gi"
}

variable "prometheus_resources" {
  description = "Resource requests and limits for Prometheus"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

# ============================================================================
# Prometheus Remote Write Configuration
# ============================================================================

variable "prometheus_remote_write_url" {
  description = "Remote write URL for Prometheus (your central Grafana)"
  type        = string
  default     = ""
}

variable "prometheus_remote_write_username" {
  description = "Username for Prometheus remote write authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prometheus_remote_write_password" {
  description = "Password for Prometheus remote write authentication"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Kiali Configuration
# ============================================================================

variable "enable_kiali" {
  description = "Enable Kiali for service mesh visualization"
  type        = bool
  default     = true
}

variable "kiali_chart_version" {
  description = "Kiali Helm chart version"
  type        = string
  default     = "1.78.0"
}

variable "kiali_auth_strategy" {
  description = "Authentication strategy for Kiali"
  type        = string
  default     = "anonymous"
  validation {
    condition     = contains(["anonymous", "token", "openshift"], var.kiali_auth_strategy)
    error_message = "Kiali auth strategy must be one of: anonymous, token, openshift."
  }
}

variable "external_prometheus_url" {
  description = "External Prometheus URL if not using local Prometheus"
  type        = string
  default     = ""
}

# ============================================================================
# Advanced Configuration
# ============================================================================

variable "create_namespace" {
  description = "Whether to create the observability namespace"
  type        = bool
  default     = false
}

variable "additional_s3_bucket_policies" {
  description = "Additional S3 bucket policies for cross-region access"
  type        = list(string)
  default     = []
}

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for S3 buckets"
  type        = bool
  default     = false
}

variable "replication_destination_region" {
  description = "Destination region for S3 cross-region replication"
  type        = string
  default     = ""
}
