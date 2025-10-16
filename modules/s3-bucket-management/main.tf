# ============================================================================
# S3 Bucket Management Module - Enterprise Standards
# ============================================================================
# This module provides standardized S3 bucket creation following enterprise patterns:
# - Versioning enabled by default for critical buckets
# - Server-side encryption (AES256 or KMS)
# - Configurable lifecycle policies optimized by bucket purpose
# - Public access blocking for security
# - Consistent tagging following enterprise standards
# - Cross-region replication support
# - Integration with existing infrastructure
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  # S3-safe bucket purpose (replace underscores with hyphens for S3 naming rules)
  bucket_purpose_safe = replace(var.bucket_purpose, "_", "-")
  
  # standard bucket naming convention
  bucket_name = var.custom_bucket_name != "" ? var.custom_bucket_name : "${var.project_name}-${var.region}-${local.bucket_purpose_safe}-${var.environment}"

  # Standard tags applied to all resources
  standard_tags = merge(var.common_tags, {
    Project        = var.project_name
    Environment    = var.environment
    Region         = var.region
    BucketPurpose  = var.bucket_purpose
    ManagedBy      = "Terraform"
    CriticalInfra  = var.bucket_purpose == "backend-state" ? "true" : "false"
    BackupRequired = var.bucket_purpose == "backend-state" ? "true" : "false"
    SecurityLevel  = var.bucket_purpose == "backend-state" ? "Critical" : "High"
    Layer          = "Storage"
    Architecture   = "Multi-Client"
  })

  # Lifecycle policies optimized for each bucket purpose
  lifecycle_policies = {
    backend-state = {
      enabled                    = true
      expiration_days            = 0     # Never expire Terraform state files
      noncurrent_expiration_days = 90    # Keep 90 days of state versions for recovery
      multipart_expiration_days  = 7     # Clean up incomplete uploads quickly
      ia_transition_days         = 0     # State files stay in Standard
      glacier_transition_days    = 0     # No Glacier for state files
      intelligent_tiering        = false # State files don't benefit from tiering
    }
    logs = {
      enabled                    = true
      expiration_days            = var.logs_retention_days > 90 ? var.logs_retention_days : 365 # Ensure expiration > transitions
      noncurrent_expiration_days = 7                                                            # Clean up old log versions quickly
      multipart_expiration_days  = 1                                                            # Clean up incomplete log uploads fast
      ia_transition_days         = 30                                                           # Move logs to IA after 30 days
      glacier_transition_days    = 90                                                           # Archive logs to Glacier after 90 days
      intelligent_tiering        = true                                                         # Logs benefit from automatic tiering
    }
    traces = {
      enabled                    = true
      expiration_days            = var.traces_retention_days > 60 ? var.traces_retention_days : 120 # Ensure expiration > transitions
      noncurrent_expiration_days = 7                                                                # Clean up old trace versions
      multipart_expiration_days  = 1                                                                # Fast cleanup for traces
      ia_transition_days         = 30                                                               # Move traces to IA after 30 days
      glacier_transition_days    = 60                                                               # Archive traces faster than logs
      intelligent_tiering        = true                                                             # Traces benefit from tiering
    }
    backups = {
      enabled                    = true
      expiration_days            = var.backup_retention_days > 90 ? var.backup_retention_days : 2555 # Ensure expiration > transitions
      noncurrent_expiration_days = 30                                                                # Keep backup versions for 30 days
      multipart_expiration_days  = 7                                                                 # Standard cleanup for backups
      ia_transition_days         = 30                                                                # Move backups to IA after 30 days
      glacier_transition_days    = 90                                                                # Long-term backup archive
      intelligent_tiering        = true                                                              # Backups benefit from tiering
    }
    metrics = {
      enabled                    = true
      expiration_days            = var.metrics_retention_days > 60 ? var.metrics_retention_days : 90 # Ensure expiration > transitions
      noncurrent_expiration_days = 7                                                                 # Clean up old metric versions quickly
      multipart_expiration_days  = 1                                                                 # Fast cleanup for metrics
      ia_transition_days         = 30                                                                # Move metrics to IA after 30 days
      glacier_transition_days    = 60                                                                # Archive metrics after 60 days
      intelligent_tiering        = true                                                              # Metrics benefit from tiering
    }
    audit_logs = {
      enabled                    = true
      expiration_days            = var.audit_logs_retention_days > 90 ? var.audit_logs_retention_days : 2555 # Long retention for compliance
      noncurrent_expiration_days = 30                                                                        # Keep audit log versions longer
      multipart_expiration_days  = 7                                                                         # Standard cleanup for audit logs
      ia_transition_days         = 30                                                                        # Move audit logs to IA after 30 days
      glacier_transition_days    = 90                                                                        # Archive audit logs after 90 days
      intelligent_tiering        = true                                                                      # Audit logs benefit from tiering
    }
    application_data = {
      enabled                    = true
      expiration_days            = var.application_data_retention_days > 90 ? var.application_data_retention_days : 730 # 2 years default
      noncurrent_expiration_days = 30                                                                                   # Keep application data versions for 30 days
      multipart_expiration_days  = 7                                                                                    # Standard cleanup for application data
      ia_transition_days         = 30                                                                                   # Move application data to IA after 30 days
      glacier_transition_days    = 90                                                                                   # Archive application data after 90 days
      intelligent_tiering        = true                                                                                 # Application data benefits from tiering
    }
    general = {
      enabled                    = var.enable_lifecycle_policy
      expiration_days            = var.object_expiration_days > max(var.ia_transition_days, var.glacier_transition_days) ? var.object_expiration_days : max(var.glacier_transition_days + 30, 365)
      noncurrent_expiration_days = var.noncurrent_version_expiration_days
      multipart_expiration_days  = var.multipart_upload_expiration_days
      ia_transition_days         = var.ia_transition_days
      glacier_transition_days    = var.glacier_transition_days
      intelligent_tiering        = var.enable_intelligent_tiering
    }
  }

  # Select lifecycle policy based on bucket purpose
  selected_policy = lookup(local.lifecycle_policies, var.bucket_purpose, local.lifecycle_policies.general)

  # S3 Key structure patterns based on bucket purpose
  default_key_patterns = {
    logs = {
      enabled     = var.enable_structured_keys
      pattern     = "logs/cluster=$${cluster_name}/tenant=$${tenant}/service=$${service}/year=%Y/month=%m/day=%d/hour=%H/fluent-bit-logs-%Y%m%d-%H%M%S-$$UUID.gz"
      partitions  = ["cluster_name", "tenant", "service", "year", "month", "day", "hour"]
      description = "Hierarchical log organization with tenant isolation and time partitioning"
    }
    traces = {
      enabled     = var.enable_structured_keys
      pattern     = "traces/cluster=$${cluster_name}/tenant=$${tenant}/service=$${service}/year=%Y/month=%m/day=%d/hour=%H/tempo-traces-%Y%m%d-%H%M%S-$$UUID.gz"
      partitions  = ["cluster_name", "tenant", "service", "year", "month", "day", "hour"]
      description = "Distributed tracing data with service-level partitioning"
    }
    backups = {
      enabled     = var.enable_structured_keys
      pattern     = "backups/database=$${database_name}/backup_type=$${backup_type}/year=%Y/month=%m/day=%d/db-backup-%Y%m%d-%H%M%S-$$UUID.tar.gz"
      partitions  = ["database_name", "backup_type", "year", "month", "day"]
      description = "Database backups organized by database and backup type"
    }
    metrics = {
      enabled     = var.enable_structured_keys
      pattern     = "metrics/cluster=$${cluster_name}/metric_type=$${metric_type}/year=%Y/month=%m/day=%d/hour=%H/metrics-%Y%m%d-%H%M%S-$$UUID.json.gz"
      partitions  = ["cluster_name", "metric_type", "year", "month", "day", "hour"]
      description = "Prometheus and application metrics with hourly partitioning"
    }
    audit_logs = {
      enabled     = var.enable_structured_keys
      pattern     = "audit-logs/cluster=$${cluster_name}/component=$${component}/year=%Y/month=%m/day=%d/hour=%H/audit-%Y%m%d-%H%M%S-$$UUID.json.gz"
      partitions  = ["cluster_name", "component", "year", "month", "day", "hour"]
      description = "Kubernetes and application audit logs with component isolation"
    }
    application_data = {
      enabled     = var.enable_structured_keys
      pattern     = "application-data/tenant=$${tenant}/app=$${app_name}/data_type=$${data_type}/year=%Y/month=%m/day=%d/app-data-%Y%m%d-%H%M%S-$$UUID.parquet"
      partitions  = ["tenant", "app_name", "data_type", "year", "month", "day"]
      description = "Application-generated data with tenant and application partitioning"
    }
    general = {
      enabled     = var.enable_structured_keys
      pattern     = "data/year=%Y/month=%m/day=%d/hour=%H/data-%Y%m%d-%H%M%S-$$UUID"
      partitions  = ["year", "month", "day", "hour"]
      description = "General time-based partitioning for unstructured data"
    }
  }

  # Merge custom patterns with defaults
  bucket_key_patterns = var.bucket_purpose != "backend-state" ? merge(
    lookup(local.default_key_patterns, var.bucket_purpose, local.default_key_patterns.general),
    lookup(var.custom_key_patterns, var.bucket_purpose, {})
  ) : null

  # Dynamic example values for outputs and documentation
  example_values = {
    cluster_name  = coalesce(var.example_cluster_name, "${var.project_name}-eks-01")
    tenant        = coalesce(var.example_tenant, "client-a")
    service       = coalesce(var.example_service, "webapp")
    database_name = coalesce(var.example_database_name, "main-db")
    app_name      = coalesce(var.example_app_name, "app")
    metric_type   = "cpu-usage"
    component     = "api-server"
    backup_type   = "full"
    data_type     = "events"
  }
}

# ============================================================================
# S3 Bucket Creation 
# ============================================================================

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name
  tags   = local.standard_tags
}

# ============================================================================
# Bucket Security Configuration 
# ============================================================================

# Versioning - Always enabled for backend-state, configurable for others
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status     = (var.bucket_purpose == "backend-state" || var.enable_versioning) ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete && var.versioning_mfa_delete ? "Enabled" : "Disabled"
  }
}

# Server-Side Encryption - AES256 default, KMS for sensitive buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }

    # Enable bucket key for cost optimization with KMS
    bucket_key_enabled = var.kms_key_id != "" ? true : false
  }
}

# Public Access Block - Always enabled for security
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Object Ownership Controls - Enforce bucket owner ownership
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = var.object_ownership
  }

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# ============================================================================
# Lifecycle Management - Optimized per Purpose
# ============================================================================

# Enhanced Lifecycle Configuration with Structured Key Pattern Support
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = local.selected_policy.enabled ? 1 : 0
  bucket = aws_s3_bucket.main.id

  # Main lifecycle rule for bucket purpose
  rule {
    id     = "${var.bucket_purpose}_main_lifecycle"
    status = "Enabled"

    filter {
      prefix = var.lifecycle_prefix
    }

    # Object expiration
    dynamic "expiration" {
      for_each = local.selected_policy.expiration_days > 0 ? [1] : []
      content {
        days = local.selected_policy.expiration_days
      }
    }

    # Transition to Standard-IA for cost optimization
    dynamic "transition" {
      for_each = local.selected_policy.ia_transition_days > 0 ? [1] : []
      content {
        days          = local.selected_policy.ia_transition_days
        storage_class = "STANDARD_IA"
      }
    }

    # Transition to Glacier for long-term archiving
    dynamic "transition" {
      for_each = local.selected_policy.glacier_transition_days > 0 ? [1] : []
      content {
        days          = local.selected_policy.glacier_transition_days
        storage_class = "GLACIER"
      }
    }

    # Transition to Glacier Deep Archive for maximum cost savings
    dynamic "transition" {
      for_each = local.selected_policy.glacier_transition_days > 0 && var.enable_deep_archive ? [1] : []
      content {
        days          = local.selected_policy.glacier_transition_days + 90
        storage_class = "DEEP_ARCHIVE"
      }
    }

    # Clean up noncurrent versions
    noncurrent_version_expiration {
      noncurrent_days = local.selected_policy.noncurrent_expiration_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = local.selected_policy.multipart_expiration_days
    }
  }

  # Advanced lifecycle rules based on key patterns
  dynamic "rule" {
    for_each = var.lifecycle_key_patterns
    content {
      id     = "${var.bucket_purpose}_${rule.key}_pattern_lifecycle"
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = lookup(rule.value, "filter_prefix", "")

        dynamic "tag" {
          for_each = lookup(rule.value, "filter_tags", {})
          content {
            key   = tag.key
            value = tag.value
          }
        }
      }

      # Custom transitions for pattern-specific data
      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Pattern-specific expiration
      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration_days", 0) > 0 ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      # Pattern-specific noncurrent version cleanup
      noncurrent_version_expiration {
        noncurrent_days = lookup(rule.value, "noncurrent_expiration_days", 30)
      }

      # Clean up incomplete multipart uploads
      abort_incomplete_multipart_upload {
        days_after_initiation = 1
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# ============================================================================
# Intelligent Tiering - Automatic Cost Optimization
# ============================================================================

resource "aws_s3_bucket_intelligent_tiering_configuration" "main" {
  count  = local.selected_policy.intelligent_tiering && var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "${var.bucket_purpose}-intelligent-tiering"

  filter {
    prefix = var.intelligent_tiering_prefix
    tags   = var.intelligent_tiering_tags
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_archive_days
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_deep_archive_days
  }
}

# ============================================================================
# Cross-Region Replication - Disaster Recovery
# ============================================================================

# IAM Role for Cross-Region Replication
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${local.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = local.standard_tags
}

# IAM Policy for Replication
resource "aws_iam_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0
  name  = "${local.bucket_name}-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${var.replication_destination_bucket_arn}/*"
      }
    ]
  })

  tags = local.standard_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_cross_region_replication ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# Replication Configuration
resource "aws_s3_bucket_replication_configuration" "main" {
  count  = var.enable_cross_region_replication ? 1 : 0
  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.main.id

  rule {
    id       = "${var.bucket_purpose}_replication"
    status   = "Enabled"
    priority = var.replication_priority

    filter {
      prefix = var.replication_prefix
    }

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = var.replication_storage_class

      # Replicate with KMS encryption if specified
      dynamic "encryption_configuration" {
        for_each = var.replication_kms_key_id != "" ? [1] : []
        content {
          replica_kms_key_id = var.replication_kms_key_id
        }
      }

      # Replicate access control translation if specified
      dynamic "access_control_translation" {
        for_each = var.replication_account_id != "" ? [1] : []
        content {
          owner = "Destination"
        }
      }

      # Cross-account replication if specified
      account = var.replication_account_id != "" ? var.replication_account_id : null
    }

    delete_marker_replication {
      status = var.replicate_delete_markers ? "Enabled" : "Disabled"
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# ============================================================================
# Bucket Policy - Custom Access Control
# ============================================================================

resource "aws_s3_bucket_policy" "main" {
  count  = var.bucket_policy != "" ? 1 : 0
  bucket = aws_s3_bucket.main.id
  policy = var.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# ============================================================================
# Monitoring and Notifications
# ============================================================================

# Bucket notifications for monitoring
resource "aws_s3_bucket_notification" "main" {
  count  = var.enable_bucket_notifications ? 1 : 0
  bucket = aws_s3_bucket.main.id

  # CloudWatch Events for bucket monitoring
  eventbridge = var.enable_eventbridge

  # SNS topic notifications
  dynamic "topic" {
    for_each = var.notification_topics
    content {
      topic_arn     = topic.value.arn
      events        = topic.value.events
      filter_prefix = lookup(topic.value, "filter_prefix", "")
      filter_suffix = lookup(topic.value, "filter_suffix", "")
    }
  }

  # SQS queue notifications
  dynamic "queue" {
    for_each = var.notification_queues
    content {
      queue_arn     = queue.value.arn
      events        = queue.value.events
      filter_prefix = lookup(queue.value, "filter_prefix", "")
      filter_suffix = lookup(queue.value, "filter_suffix", "")
    }
  }

  # Lambda function notifications
  dynamic "lambda_function" {
    for_each = var.notification_lambda_functions
    content {
      lambda_function_arn = lambda_function.value.arn
      events              = lambda_function.value.events
      filter_prefix       = lookup(lambda_function.value, "filter_prefix", "")
      filter_suffix       = lookup(lambda_function.value, "filter_suffix", "")
    }
  }
}

# ============================================================================
# Cost Optimization Metrics
# ============================================================================

# CloudWatch dashboard widget data for cost tracking
resource "aws_s3_bucket_metric" "cost_optimization" {
  count  = var.enable_cost_metrics ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "${var.bucket_purpose}-cost-metrics"

  # Only include filter if prefix or tags are provided
  dynamic "filter" {
    for_each = (var.cost_metrics_prefix != "" && var.cost_metrics_prefix != null) || (try(length(var.cost_metrics_tags), 0) > 0) ? [1] : []
    content {
      prefix = (var.cost_metrics_prefix != "" && var.cost_metrics_prefix != null) ? var.cost_metrics_prefix : null
      tags   = try(length(var.cost_metrics_tags), 0) > 0 ? var.cost_metrics_tags : null
    }
  }
}

# ============================================================================
# Access Logging Configuration
# ============================================================================

# Create access logs bucket if enabled and no external bucket specified
resource "aws_s3_bucket" "access_logs" {
  count  = var.enable_access_logging && var.access_logs_bucket == "" ? 1 : 0
  bucket = "${local.bucket_name}-access-logs"
  tags = merge(local.standard_tags, {
    Purpose = "AccessLogs"
  })
}

# Access logging configuration
resource "aws_s3_bucket_logging" "main" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.main.id

  target_bucket = var.access_logs_bucket != "" ? var.access_logs_bucket : aws_s3_bucket.access_logs[0].id
  target_prefix = var.access_logs_prefix != "" ? var.access_logs_prefix : "access-logs/${local.bucket_name}/"
}

# ============================================================================
# Performance Optimization
# ============================================================================

# Transfer Acceleration for global performance
resource "aws_s3_bucket_accelerate_configuration" "main" {
  count  = var.enable_transfer_acceleration ? 1 : 0
  bucket = aws_s3_bucket.main.id
  status = "Enabled"
}

# Request Payer Configuration
resource "aws_s3_bucket_request_payment_configuration" "main" {
  count  = var.enable_request_payer ? 1 : 0
  bucket = aws_s3_bucket.main.id
  payer  = var.request_payer
}

# ============================================================================
# Advanced Monitoring and Analytics
# ============================================================================

# CloudWatch Metrics Configuration
resource "aws_s3_bucket_metric" "detailed_monitoring" {
  count  = var.enable_cloudwatch_metrics ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = var.cloudwatch_metrics_configuration.name

  # Only include filter if prefix or tags are provided with valid values
  dynamic "filter" {
    for_each = (
      (var.cloudwatch_metrics_configuration.prefix != null && var.cloudwatch_metrics_configuration.prefix != "") ||
      (var.cloudwatch_metrics_configuration.tags != null && try(length(var.cloudwatch_metrics_configuration.tags), 0) > 0)
    ) ? [1] : []
    content {
      prefix = (var.cloudwatch_metrics_configuration.prefix != null && var.cloudwatch_metrics_configuration.prefix != "") ? var.cloudwatch_metrics_configuration.prefix : null
      tags   = (var.cloudwatch_metrics_configuration.tags != null && try(length(var.cloudwatch_metrics_configuration.tags), 0) > 0) ? var.cloudwatch_metrics_configuration.tags : null
    }
  }
}

# Analytics Configuration for cost optimization insights
resource "aws_s3_bucket_analytics_configuration" "main" {
  count  = var.enable_analytics_configuration ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "${var.bucket_purpose}-analytics"

  storage_class_analysis {
    data_export {
      output_schema_version = "V_1"

      destination {
        s3_bucket_destination {
          bucket_arn        = var.analytics_destination_bucket != "" ? var.analytics_destination_bucket : aws_s3_bucket.main.arn
          bucket_account_id = data.aws_caller_identity.current.account_id
          prefix            = "analytics-exports/${var.bucket_purpose}/"
          format            = "CSV"
        }
      }
    }
  }
}

# Inventory Configuration for detailed object reporting
resource "aws_s3_bucket_inventory" "main" {
  count                    = var.enable_inventory_configuration ? 1 : 0
  bucket                   = aws_s3_bucket.main.id
  name                     = "${var.bucket_purpose}-inventory"
  included_object_versions = "Current"

  schedule {
    frequency = "Weekly"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = var.inventory_destination_bucket != "" ? var.inventory_destination_bucket : aws_s3_bucket.main.arn
      prefix     = "inventory-reports/${var.bucket_purpose}/"
    }
  }

  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "IsMultipartUploaded",
    "ReplicationStatus",
    "EncryptionStatus"
  ]
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
