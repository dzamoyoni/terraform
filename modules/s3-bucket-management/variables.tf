# ============================================================================
# S3 Bucket Management Module Variables - Enterprise Standards
# ============================================================================

# ============================================================================
# Core Configuration Variables
# ============================================================================

variable "project_name" {
  description = "Name of the project (e.g., myproject-eks-01)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "development", "test"], var.environment)
    error_message = "Environment must be one of: production, staging, development, test."
  }
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
}

variable "bucket_purpose" {
  description = "Purpose of the bucket (backend-state, logs, traces, backups, metrics, audit_logs, application_data, general)"
  type        = string
  validation {
    condition     = contains(["backend-state", "logs", "traces", "backups", "metrics", "audit_logs", "application_data", "general"], var.bucket_purpose)
    error_message = "Bucket purpose must be one of: backend-state, logs, traces, backups, metrics, audit_logs, application_data, general."
  }
}

variable "custom_bucket_name" {
  description = "Custom bucket name (if empty, will use standard naming convention)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Security Configuration Variables
# ============================================================================

variable "enable_versioning" {
  description = "Enable versioning for the bucket (always enabled for backend-state buckets)"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (empty string for AES256)"
  type        = string
  default     = ""
}

variable "prevent_destroy" {
  description = "Prevent destruction of the bucket (automatically true for backend-state buckets)"
  type        = bool
  default     = false
}

variable "bucket_policy" {
  description = "Custom bucket policy JSON"
  type        = string
  default     = ""
}

# ============================================================================
# Lifecycle Policy Variables - Purpose-Specific Defaults
# ============================================================================

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy (automatically determined for known purposes)"
  type        = bool
  default     = true
}

variable "lifecycle_prefix" {
  description = "Prefix for lifecycle policy rules"
  type        = string
  default     = ""
}

# Logs-specific retention
variable "logs_retention_days" {
  description = "Retention period for log objects in days"
  type        = number
  default     = 365 # Changed from 90 to avoid lifecycle conflicts
  validation {
    condition     = var.logs_retention_days >= 1 && var.logs_retention_days <= 3650
    error_message = "Log retention days must be between 1 and 3650 (10 years)."
  }
}

# Traces-specific retention
variable "traces_retention_days" {
  description = "Retention period for trace objects in days"
  type        = number
  default     = 120 # Changed from 30 to avoid lifecycle conflicts (must be > 60 days for Glacier transition)
  validation {
    condition     = var.traces_retention_days >= 1 && var.traces_retention_days <= 365
    error_message = "Trace retention days must be between 1 and 365."
  }
}

# Backup-specific retention
variable "backup_retention_days" {
  description = "Retention period for backup objects in days"
  type        = number
  default     = 2555 # 7 years for compliance
  validation {
    condition     = var.backup_retention_days >= 30 && var.backup_retention_days <= 3650
    error_message = "Backup retention days must be between 30 and 3650 (10 years)."
  }
}

# Metrics-specific retention
variable "metrics_retention_days" {
  description = "Retention period for metrics objects in days"
  type        = number
  default     = 90 # 3 months default for metrics
  validation {
    condition     = var.metrics_retention_days >= 7 && var.metrics_retention_days <= 365
    error_message = "Metrics retention days must be between 7 and 365."
  }
}

# Audit logs-specific retention
variable "audit_logs_retention_days" {
  description = "Retention period for audit log objects in days"
  type        = number
  default     = 2555 # 7 years for compliance
  validation {
    condition     = var.audit_logs_retention_days >= 90 && var.audit_logs_retention_days <= 3650
    error_message = "Audit logs retention days must be between 90 and 3650 (10 years)."
  }
}

# Application data-specific retention
variable "application_data_retention_days" {
  description = "Retention period for application data objects in days"
  type        = number
  default     = 730 # 2 years default for application data
  validation {
    condition     = var.application_data_retention_days >= 30 && var.application_data_retention_days <= 3650
    error_message = "Application data retention days must be between 30 and 3650 (10 years)."
  }
}

# General lifecycle configuration
variable "object_expiration_days" {
  description = "Days after which objects expire (0 = never expire)"
  type        = number
  default     = 365
  validation {
    condition     = var.object_expiration_days >= 0
    error_message = "Object expiration days must be 0 or greater."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent versions expire"
  type        = number
  default     = 30
  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "Noncurrent version expiration days must be 1 or greater."
  }
}

variable "multipart_upload_expiration_days" {
  description = "Days after which incomplete multipart uploads are removed"
  type        = number
  default     = 7
  validation {
    condition     = var.multipart_upload_expiration_days >= 1
    error_message = "Multipart upload expiration days must be 1 or greater."
  }
}

variable "ia_transition_days" {
  description = "Days after which objects transition to Infrequent Access"
  type        = number
  default     = 30
  validation {
    condition     = var.ia_transition_days >= 30 || var.ia_transition_days == 0
    error_message = "IA transition days must be 0 (disabled) or >= 30."
  }
}

variable "glacier_transition_days" {
  description = "Days after which objects transition to Glacier"
  type        = number
  default     = 90
  validation {
    condition     = var.glacier_transition_days >= 90 || var.glacier_transition_days == 0
    error_message = "Glacier transition days must be 0 (disabled) or >= 90."
  }
}

variable "enable_deep_archive" {
  description = "Enable transition to Glacier Deep Archive (90 days after Glacier transition)"
  type        = bool
  default     = false
}

# ============================================================================
# Advanced Security Variables
# ============================================================================

variable "enable_mfa_delete" {
  description = "Enable MFA delete protection for critical buckets (backend-state, audit-logs)"
  type        = bool
  default     = false
}

variable "versioning_mfa_delete" {
  description = "Enable MFA delete for versioned objects (requires MFA device and appropriate IAM permissions)"
  type        = bool
  default     = false
}

variable "enable_object_ownership_controls" {
  description = "Enable S3 object ownership controls"
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "Object ownership setting (BucketOwnerEnforced, BucketOwnerPreferred, ObjectWriter)"
  type        = string
  default     = "BucketOwnerEnforced"
  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "Object ownership must be one of: BucketOwnerEnforced, BucketOwnerPreferred, ObjectWriter."
  }
}

variable "enable_access_logging" {
  description = "Enable S3 access logging for security audit trails"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for access logs (if empty, will create one)"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "Prefix for access logs"
  type        = string
  default     = "access-logs/"
}

# ============================================================================
# Intelligent Tiering Variables
# ============================================================================

variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering"
  type        = bool
  default     = false
}

variable "intelligent_tiering_prefix" {
  description = "Prefix for intelligent tiering configuration"
  type        = string
  default     = ""
}

variable "intelligent_tiering_tags" {
  description = "Tags for intelligent tiering configuration"
  type        = map(string)
  default     = {}
}

variable "intelligent_tiering_archive_days" {
  description = "Days before transitioning to Archive Access tier"
  type        = number
  default     = 90
  validation {
    condition     = var.intelligent_tiering_archive_days >= 90
    error_message = "Archive access tier transition must be >= 90 days."
  }
}

variable "intelligent_tiering_deep_archive_days" {
  description = "Days before transitioning to Deep Archive Access tier"
  type        = number
  default     = 180
  validation {
    condition     = var.intelligent_tiering_deep_archive_days >= 180
    error_message = "Deep archive access tier transition must be >= 180 days."
  }
}

# ============================================================================
# Performance Optimization Variables
# ============================================================================

variable "enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration for global performance"
  type        = bool
  default     = false
}

variable "enable_request_payer" {
  description = "Enable request payer configuration"
  type        = bool
  default     = false
}

variable "request_payer" {
  description = "Who pays for requests (BucketOwner or Requester)"
  type        = string
  default     = "BucketOwner"
  validation {
    condition     = contains(["BucketOwner", "Requester"], var.request_payer)
    error_message = "Request payer must be either BucketOwner or Requester."
  }
}

# ============================================================================
# Monitoring and Analytics Variables
# ============================================================================

variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics for detailed monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_metrics_configuration" {
  description = "CloudWatch metrics configuration"
  type = object({
    name   = string
    prefix = optional(string)
    tags   = optional(map(string))
  })
  default = {
    name   = "bucket-metrics"
    prefix = null
    tags   = null
  }
}

variable "enable_analytics_configuration" {
  description = "Enable S3 analytics for cost optimization insights"
  type        = bool
  default     = false
}

variable "analytics_destination_bucket" {
  description = "Destination bucket for analytics data export"
  type        = string
  default     = ""
}

variable "enable_inventory_configuration" {
  description = "Enable S3 inventory for detailed object reporting"
  type        = bool
  default     = false
}

variable "inventory_destination_bucket" {
  description = "Destination bucket for inventory reports"
  type        = string
  default     = ""
}

# ============================================================================
# Notification Variables
# ============================================================================

variable "enable_bucket_notifications" {
  description = "Enable S3 bucket notifications"
  type        = bool
  default     = false
}

variable "enable_eventbridge" {
  description = "Enable EventBridge integration for S3 events"
  type        = bool
  default     = false
}

variable "notification_topics" {
  description = "SNS topics for bucket notifications"
  type = list(object({
    arn           = string
    events        = list(string)
    filter_prefix = optional(string, "")
    filter_suffix = optional(string, "")
  }))
  default = []
}

variable "notification_events" {
  description = "S3 events to monitor"
  type        = list(string)
  default     = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
}

# ============================================================================
# Cross-Region Replication Variables
# ============================================================================

variable "enable_cross_region_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of destination bucket for replication"
  type        = string
  default     = ""
}

variable "replication_storage_class" {
  description = "Storage class for replicated objects"
  type        = string
  default     = "STANDARD_IA"
  validation {
    condition = contains([
      "STANDARD", "REDUCED_REDUNDANCY", "STANDARD_IA",
      "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE"
    ], var.replication_storage_class)
    error_message = "Invalid replication storage class."
  }
}

variable "replication_kms_key_id" {
  description = "KMS key ID for replication encryption"
  type        = string
  default     = ""
}

variable "replication_account_id" {
  description = "AWS account ID for cross-account replication"
  type        = string
  default     = ""
}

variable "replication_prefix" {
  description = "Prefix for replication rules"
  type        = string
  default     = ""
}

variable "replication_priority" {
  description = "Priority for replication rule (higher numbers = higher priority)"
  type        = number
  default     = 1
  validation {
    condition     = var.replication_priority >= 0 && var.replication_priority <= 1000
    error_message = "Replication priority must be between 0 and 1000."
  }
}

variable "replicate_delete_markers" {
  description = "Replicate delete markers"
  type        = bool
  default     = true
}

# ============================================================================
# Advanced Notification and Lambda Variables
# ============================================================================

variable "notification_queues" {
  description = "SQS queues for bucket notifications"
  type = list(object({
    arn           = string
    events        = list(string)
    filter_prefix = optional(string, "")
    filter_suffix = optional(string, "")
  }))
  default = []
}

variable "notification_lambda_functions" {
  description = "Lambda functions for bucket notifications"
  type = list(object({
    arn           = string
    events        = list(string)
    filter_prefix = optional(string, "")
    filter_suffix = optional(string, "")
  }))
  default = []
}

# ============================================================================
# Cost Optimization Variables
# ============================================================================

variable "enable_cost_metrics" {
  description = "Enable CloudWatch metrics for cost optimization"
  type        = bool
  default     = false
}

variable "cost_metrics_prefix" {
  description = "Prefix for cost metrics configuration"
  type        = string
  default     = ""
}

variable "cost_metrics_tags" {
  description = "Tags for cost metrics configuration"
  type        = map(string)
  default     = {}
}

# ============================================================================
# S3 Key Structure and Organization Variables
# ============================================================================

variable "enable_structured_keys" {
  description = "Enable structured S3 key patterns for better organization"
  type        = bool
  default     = true
}

variable "custom_key_patterns" {
  description = "Custom S3 key patterns for different data types"
  type = object({
    logs = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "logs/cluster=$${cluster_name}/tenant=$${tenant}/service=$${service}/year=%Y/month=%m/day=%d/hour=%H/fluent-bit-logs-%Y%m%d-%H%M%S-$$UUID.gz")
      partitions = optional(list(string), ["cluster_name", "tenant", "service", "year", "month", "day", "hour"])
    }), {})
    traces = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "traces/cluster=$${cluster_name}/tenant=$${tenant}/service=$${service}/year=%Y/month=%m/day=%d/hour=%H/tempo-traces-%Y%m%d-%H%M%S-$$UUID.gz")
      partitions = optional(list(string), ["cluster_name", "tenant", "service", "year", "month", "day", "hour"])
    }), {})
    backups = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "backups/database=$${database_name}/backup_type=$${backup_type}/year=%Y/month=%m/day=%d/db-backup-%Y%m%d-%H%M%S-$$UUID.tar.gz")
      partitions = optional(list(string), ["database_name", "backup_type", "year", "month", "day"])
    }), {})
    metrics = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "metrics/cluster=$${cluster_name}/metric_type=$${metric_type}/year=%Y/month=%m/day=%d/hour=%H/metrics-%Y%m%d-%H%M%S-$$UUID.json.gz")
      partitions = optional(list(string), ["cluster_name", "metric_type", "year", "month", "day", "hour"])
    }), {})
    audit_logs = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "audit-logs/cluster=$${cluster_name}/component=$${component}/year=%Y/month=%m/day=%d/hour=%H/audit-%Y%m%d-%H%M%S-$$UUID.json.gz")
      partitions = optional(list(string), ["cluster_name", "component", "year", "month", "day", "hour"])
    }), {})
    application_data = optional(object({
      enabled    = optional(bool, true)
      pattern    = optional(string, "application-data/tenant=$${tenant}/app=$${app_name}/data_type=$${data_type}/year=%Y/month=%m/day=%d/app-data-%Y%m%d-%H%M%S-$$UUID.parquet")
      partitions = optional(list(string), ["tenant", "app_name", "data_type", "year", "month", "day"])
    }), {})
  })
  default = {}
}

variable "lifecycle_key_patterns" {
  description = "S3 lifecycle rules based on key patterns for structured data"
  type = map(object({
    enabled = bool
    transitions = optional(list(object({
      days          = number
      storage_class = string
      filter_prefix = optional(string, "")
      filter_tags   = optional(map(string), {})
    })), [])
    expiration_days            = optional(number, 0)
    noncurrent_expiration_days = optional(number, 30)
  }))
  default = {}
}

# ============================================================================
# Example Configuration Variables (for outputs and documentation)
# ============================================================================

variable "example_cluster_name" {
  description = "Example cluster name for key pattern demonstrations"
  type        = string
  default     = null
}

variable "example_tenant" {
  description = "Example tenant name for key pattern demonstrations"
  type        = string
  default     = null
}

variable "example_service" {
  description = "Example service name for key pattern demonstrations"
  type        = string
  default     = null
}

variable "example_database_name" {
  description = "Example database name for key pattern demonstrations"
  type        = string
  default     = null
}

variable "example_app_name" {
  description = "Example application name for key pattern demonstrations"
  type        = string
  default     = null
}
