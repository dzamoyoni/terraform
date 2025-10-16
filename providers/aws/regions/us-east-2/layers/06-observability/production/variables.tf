# ============================================================================
# Observability Layer Variables - US-East-2 Production
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ohio-01"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# ============================================================================
# S3 Configuration
# ============================================================================

variable "logs_retention_days" {
  description = "Number of days to retain logs in S3"
  type        = number
  default     = 90 # Increased for production workload
}

variable "traces_retention_days" {
  description = "Number of days to retain traces in S3"
  type        = number
  default     = 30 # Increased for production debugging needs
}

variable "tempo_s3_bucket" {
  description = "S3 bucket name for Tempo traces storage"
  type        = string
  default     = "ohio-01-tempo-traces-production"
}

# ============================================================================
# Prometheus Configuration
# ============================================================================

variable "enable_local_prometheus" {
  description = "Enable local Prometheus instance"
  type        = bool
  default     = true # ✅ Enabled for Terraform management
}

variable "prometheus_remote_write_url" {
  description = "Remote write URL for your central on-premises Grafana"
  type        = string
  default     = "" # Set this to your central Grafana URL
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
  default     = "disabled" # Default value to prevent parsing errors
  sensitive   = true
}

# ============================================================================
# Kiali Configuration
# ============================================================================

variable "kiali_auth_strategy" {
  description = "Authentication strategy for Kiali"
  type        = string
  default     = "anonymous"
}

variable "external_prometheus_url" {
  description = "External Prometheus URL if not using local Prometheus"
  type        = string
  default     = "http://prometheus.istio-system.svc.cluster.local:9090"
}

# ============================================================================
# Advanced Configuration
# ============================================================================

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication to us-east-1"
  type        = bool
  default     = false
}

variable "additional_tenant_namespaces" {
  description = "Additional tenant namespaces to monitor"
  type        = list(string)
  default     = []
}

# ============================================================================
# Production Enhancement Variables
# ============================================================================

variable "enable_grafana" {
  description = "Enable Grafana for local dashboards"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Enable AlertManager for production alerting"
  type        = bool
  default     = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = "dennis.juma@ezra.world"
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring features (ServiceMonitors, PrometheusRules)"
  type        = bool
  default     = true
}

variable "enable_postgres_monitoring" {
  description = "Enable PostgreSQL monitoring for client databases"
  type        = bool
  default     = true
}

variable "postgres_endpoints" {
  description = "PostgreSQL endpoints to monitor"
  type = map(object({
    host     = string
    port     = string
    database = string
    client   = string
  }))
  default = {
    mtn_ghana = {
      host     = "172.20.2.33"
      port     = "5433"
      database = "mtn_ghana_prod"
      client   = "mtn-ghana"
    }
    ezra = {
      host     = "172.20.1.153"
      port     = "5433"
      database = "ezra_prod"
      client   = "ezra"
    }
  }
}

# ============================================================================
# MISSING PRODUCTION VARIABLES
# ============================================================================

variable "grafana_admin_password" {
  description = "Admin password for Grafana (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prometheus_replicas" {
  description = "Number of Prometheus replicas for HA"
  type        = number
  default     = 2
}

variable "enable_prometheus_ha" {
  description = "Enable Prometheus high availability"
  type        = bool
  default     = true
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "30d"
}

variable "prometheus_retention_size" {
  description = "Prometheus data retention size"
  type        = string
  default     = "25GB"
}

variable "enable_network_policies" {
  description = "Enable network policies for security"
  type        = bool
  default     = true
}

variable "enable_pod_security_policies" {
  description = "Enable pod security policies"
  type        = bool
  default     = true
}

# ============================================================================
# ALERTMANAGER CONFIGURATION
# ============================================================================

variable "alertmanager_storage_class" {
  description = "Storage class for AlertManager persistent volume"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["gp2", "gp3"], var.alertmanager_storage_class)
    error_message = "AlertManager storage class must be either 'gp2' or 'gp3'."
  }
}

variable "alertmanager_replicas" {
  description = "Number of AlertManager replicas for high availability"
  type        = number
  default     = 2
}

variable "enable_security_context" {
  description = "Enable security context for pods (runAsNonRoot, etc.)"
  type        = bool
  default     = true
}

# ============================================================================
# JAEGER DISTRIBUTED TRACING CONFIGURATION
# ============================================================================

variable "enable_jaeger" {
  description = "Enable Jaeger for distributed tracing (optimized for Java applications)"
  type        = bool
  default     = true
}

variable "jaeger_storage_type" {
  description = "Jaeger storage backend type (cassandra, elasticsearch, memory)"
  type        = string
  default     = "elasticsearch"
  validation {
    condition     = contains(["cassandra", "elasticsearch", "memory"], var.jaeger_storage_type)
    error_message = "Jaeger storage type must be one of: cassandra, elasticsearch, memory."
  }
}

variable "jaeger_s3_export_enabled" {
  description = "Enable S3 export for Jaeger traces (via Tempo)"
  type        = bool
  default     = true
}

variable "jaeger_resources" {
  description = "Resource requests and limits for Jaeger components"
  type = object({
    collector = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    query = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    collector = {
      requests = {
        cpu    = "200m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
    }
    query = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
  }
}

# ============================================================================
# OPENTELEMETRY CONFIGURATION
# ============================================================================

variable "enable_otel_collector" {
  description = "Enable OpenTelemetry Collector for modern observability data collection"
  type        = bool
  default     = true
}

variable "otel_collector_mode" {
  description = "OpenTelemetry Collector deployment mode (daemonset, deployment, sidecar)"
  type        = string
  default     = "daemonset"
  validation {
    condition     = contains(["daemonset", "deployment", "sidecar"], var.otel_collector_mode)
    error_message = "OTEL collector mode must be one of: daemonset, deployment, sidecar."
  }
}

variable "otel_java_instrumentation_enabled" {
  description = "Enable auto-instrumentation for Java applications"
  type        = bool
  default     = true
}

variable "otel_collector_resources" {
  description = "Resource requests and limits for OpenTelemetry Collector"
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
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

# ============================================================================
# S3 EXPORT AND STORAGE CONFIGURATION
# ============================================================================

variable "s3_export_enabled" {
  description = "Enable S3 export for all observability data (logs, metrics, traces)"
  type        = bool
  default     = true
}

variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle policies for cost optimization"
  type        = bool
  default     = true
}

variable "s3_transition_to_ia_days" {
  description = "Days after which to transition S3 objects to Infrequent Access"
  type        = number
  default     = 30
}

variable "s3_transition_to_glacier_days" {
  description = "Days after which to transition S3 objects to Glacier"
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days after which to delete S3 objects (0 = never delete)"
  type        = number
  default     = 365
}

variable "disable_local_storage" {
  description = "Disable local storage on nodes (force S3-only storage)"
  type        = bool
  default     = true
}

# ============================================================================
# TERRAFORM STATE CONFIGURATION
# ============================================================================

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform remote state"
  type        = string
  default     = "terraform-state-ohio-01-eks"
}

variable "terraform_state_region" {
  description = "AWS region where Terraform state bucket is located"
  type        = string
  default     = "us-east-2"
}
