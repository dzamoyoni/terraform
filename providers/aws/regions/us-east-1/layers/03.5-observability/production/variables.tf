# ============================================================================
# 📊 Observability Layer Variables - US-East-1 Production
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "us-east-1-multi-client-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# S3 Configuration
# ============================================================================

variable "logs_retention_days" {
  description = "Number of days to retain logs in S3"
  type        = number
  default     = 90 # US-East-1 primary region gets longer retention
}

variable "traces_retention_days" {
  description = "Number of days to retain traces in S3"
  type        = number
  default     = 14 # Extended trace retention for primary region
}

# ============================================================================
# Prometheus Configuration
# ============================================================================

variable "enable_local_prometheus" {
  description = "Enable local Prometheus instance"
  type        = bool
  default     = true
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
  default     = ""
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
  default     = ""
}

# ============================================================================
# Advanced Configuration
# ============================================================================

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication to af-south-1"
  type        = bool
  default     = false
}

variable "additional_tenant_namespaces" {
  description = "Additional tenant namespaces to monitor"
  type        = list(string)
  default     = []
}
