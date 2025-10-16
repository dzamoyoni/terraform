# ============================================================================
# S3 Bucket Management Module Outputs - Enterprise Standards
# ============================================================================

# ============================================================================
# Bucket Information Outputs
# ============================================================================

output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = aws_s3_bucket.main.hosted_zone_id
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.main.region
}

# ============================================================================
# Configuration Status Outputs
# ============================================================================

output "versioning_enabled" {
  description = "Whether versioning is enabled"
  value       = aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled"
}

output "encryption_algorithm" {
  description = "The server-side encryption algorithm used"
  value       = [for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule.apply_server_side_encryption_by_default[0].sse_algorithm][0]
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption (if any)"
  value       = try([for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule.apply_server_side_encryption_by_default[0].kms_master_key_id][0], null)
}

output "lifecycle_enabled" {
  description = "Whether lifecycle configuration is enabled"
  value       = length(aws_s3_bucket_lifecycle_configuration.main) > 0
}

output "intelligent_tiering_enabled" {
  description = "Whether intelligent tiering is enabled"
  value       = length(aws_s3_bucket_intelligent_tiering_configuration.main) > 0
}

output "replication_enabled" {
  description = "Whether cross-region replication is enabled"
  value       = length(aws_s3_bucket_replication_configuration.main) > 0
}

# ============================================================================
# IAM and Security Outputs
# ============================================================================

output "replication_iam_role_arn" {
  description = "ARN of the IAM role used for replication (if enabled)"
  value       = try(aws_iam_role.replication[0].arn, null)
}

output "replication_iam_role_name" {
  description = "Name of the IAM role used for replication (if enabled)"
  value       = try(aws_iam_role.replication[0].name, null)
}

# ============================================================================
# Cost Optimization Outputs
# ============================================================================

output "lifecycle_policy" {
  description = "Lifecycle policy configuration details"
  value = length(aws_s3_bucket_lifecycle_configuration.main) > 0 ? {
    enabled                    = true
    expiration_days            = local.selected_policy.expiration_days
    noncurrent_expiration_days = local.selected_policy.noncurrent_expiration_days
    ia_transition_days         = local.selected_policy.ia_transition_days
    glacier_transition_days    = local.selected_policy.glacier_transition_days
    intelligent_tiering        = local.selected_policy.intelligent_tiering
  } : null
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost components (informational)"
  value = {
    storage_class_optimized = local.selected_policy.intelligent_tiering || local.selected_policy.ia_transition_days > 0
    lifecycle_optimized     = local.selected_policy.enabled
    deep_archive_enabled    = var.enable_deep_archive
    replication_enabled     = var.enable_cross_region_replication
    bucket_purpose          = var.bucket_purpose
  }
}

# ============================================================================
# Integration Outputs for Other Modules
# ============================================================================

output "bucket_for_backend_config" {
  description = "Bucket configuration for Terraform backend (if bucket_purpose is backend-state)"
  value = var.bucket_purpose == "backend-state" ? {
    bucket             = aws_s3_bucket.main.id
    region             = aws_s3_bucket.main.region
    key                = "terraform.tfstate"
    encrypt            = true
    versioning_enabled = true
  } : null
}

output "bucket_for_observability" {
  description = "Bucket configuration for observability stack (if bucket_purpose is logs or traces)"
  value = contains(["logs", "traces"], var.bucket_purpose) ? {
    bucket_name       = aws_s3_bucket.main.id
    bucket_arn        = aws_s3_bucket.main.arn
    region            = aws_s3_bucket.main.region
    purpose           = var.bucket_purpose
    lifecycle_enabled = length(aws_s3_bucket_lifecycle_configuration.main) > 0
  } : null
}

# ============================================================================
# Standards Compliance Outputs
# ============================================================================

output "compliance_status" {
  description = "Enterprise standards compliance status"
  value = {
    versioning_compliant  = var.bucket_purpose == "backend-state" ? true : var.enable_versioning
    encryption_compliant  = true # Always encrypted
    public_access_blocked = true # Always blocked
    lifecycle_configured  = length(aws_s3_bucket_lifecycle_configuration.main) > 0
    tagging_compliant     = length(local.standard_tags) >= 8 # Minimum required tags
    backup_strategy       = var.bucket_purpose == "backend-state" ? "versioning" : (var.enable_cross_region_replication ? "replication" : "lifecycle")
    cost_optimized        = local.selected_policy.intelligent_tiering || local.selected_policy.ia_transition_days > 0
  }
}

# ============================================================================
# Monitoring and Alerting Outputs
# ============================================================================

output "cloudwatch_metrics_enabled" {
  description = "Whether CloudWatch metrics are enabled"
  value       = var.enable_cost_metrics
}

output "notifications_configured" {
  description = "Notification configuration summary"
  value = var.enable_bucket_notifications ? {
    eventbridge_enabled    = var.enable_eventbridge
    sns_topics_count       = length(var.notification_topics)
    sqs_queues_count       = length(var.notification_queues)
    lambda_functions_count = length(var.notification_lambda_functions)
  } : null
}

# ============================================================================
# Debug and Operational Outputs
# ============================================================================

output "module_version" {
  description = "Version of this S3 bucket management module"
  value       = "1.0.0"
}

output "deployment_timestamp" {
  description = "Timestamp when this bucket was deployed"
  value       = timestamp()
}

output "bucket_purpose" {
  description = "Purpose of this bucket"
  value       = var.bucket_purpose
}

output "bucket_naming_convention" {
  description = "Naming convention used for this bucket"
  value = {
    custom_name_used = var.custom_bucket_name != ""
    standard_pattern = "${var.project_name}-${var.region}-${var.bucket_purpose}-${var.environment}"
    actual_name      = local.bucket_name
  }
}

# ============================================================================
# S3 Key Structure and Organization Outputs
# ============================================================================

output "key_structure" {
  description = "S3 key structure patterns for this bucket"
  value = var.bucket_purpose != "backend-state" && local.bucket_key_patterns != null ? {
    enabled        = local.bucket_key_patterns.enabled
    pattern        = local.bucket_key_patterns.pattern
    partitions     = local.bucket_key_patterns.partitions
    description    = local.bucket_key_patterns.description
    bucket_purpose = var.bucket_purpose
    examples = {
      fluent_bit_config = try(local.bucket_key_patterns.enabled, false) ? {
        s3_key_format = replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(
                        replace(
                          local.bucket_key_patterns.pattern,
                          "$${cluster_name}", local.example_values.cluster_name
                        ),
                        "$${tenant}", local.example_values.tenant
                      ),
                      "$${service}", local.example_values.service
                    ),
                    "$${database_name}", local.example_values.database_name
                  ),
                  "$${app_name}", local.example_values.app_name
                ),
                "$${metric_type}", local.example_values.metric_type
              ),
              "$${component}", local.example_values.component
            ),
            "$${backup_type}", local.example_values.backup_type
          ),
          "$${data_type}", local.example_values.data_type
        )
        description = "Example key format for ${var.bucket_purpose} bucket"
      } : null
      sample_paths = try(local.bucket_key_patterns.enabled, false) ? [
        "${var.bucket_purpose}/cluster=${local.example_values.cluster_name}/tenant=${local.example_values.tenant}/service=${local.example_values.service}/year=2024/month=10/day=13/hour=04/${var.bucket_purpose}-logs-20241013-043000-abc123.gz",
        "${var.bucket_purpose}/cluster=${local.example_values.cluster_name}/tenant=client-b/service=api/year=2024/month=10/day=13/hour=04/${var.bucket_purpose}-logs-20241013-043015-def456.gz"
      ] : []
    }
  } : null
}

output "lifecycle_patterns" {
  description = "Advanced lifecycle patterns configured for this bucket"
  value = {
    main_policy_enabled = local.selected_policy.enabled
    pattern_based_rules = length(var.lifecycle_key_patterns) > 0 ? {
      count = length(var.lifecycle_key_patterns)
      rules = var.lifecycle_key_patterns
    } : null
    bucket_purpose_optimized = {
      purpose                 = var.bucket_purpose
      ia_transition_days      = local.selected_policy.ia_transition_days
      glacier_transition_days = local.selected_policy.glacier_transition_days
      expiration_days         = local.selected_policy.expiration_days
      intelligent_tiering     = local.selected_policy.intelligent_tiering
    }
  }
}

output "query_optimization" {
  description = "Information for optimizing S3 queries with structured keys"
  value = var.bucket_purpose != "backend-state" && local.bucket_key_patterns != null && try(local.bucket_key_patterns.enabled, false) ? {
    athena_projection = {
      enabled = true
      projection_types = {
        year  = "integer"
        month = "integer"
        day   = "integer"
        hour  = "integer"
      }
      partition_keys = try(local.bucket_key_patterns.partitions, [])
      sample_query   = "SELECT * FROM table WHERE year = 2024 AND month = 10 AND tenant = '${local.example_values.tenant}'"
    }
    s3_select_optimization = {
      enabled            = true
      recommended_format = "JSON"
      compression        = "GZIP"
      partition_pruning  = true
    }
  } : null
}
