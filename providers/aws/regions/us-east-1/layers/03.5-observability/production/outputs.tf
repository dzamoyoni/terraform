# ============================================================================
# 📊 Observability Layer Outputs - US-East-1 Production
# ============================================================================

output "observability_summary" {
  description = "Summary of deployed observability components"
  value       = module.observability.observability_summary
}

output "s3_buckets" {
  description = "S3 bucket information for logs and traces"
  value = {
    logs   = module.observability.logs_s3_bucket
    traces = module.observability.traces_s3_bucket
  }
}

output "endpoints" {
  description = "Observability component endpoints"
  value = {
    tempo      = module.observability.tempo_endpoint
    prometheus = module.observability.prometheus_endpoint
    kiali      = module.observability.kiali_endpoint
  }
}

output "service_accounts" {
  description = "Service account information"
  value = {
    fluent_bit = module.observability.fluent_bit_service_account
    tempo      = module.observability.tempo_service_account
  }
}

output "iam_roles" {
  description = "IAM role information for IRSA"
  value = {
    fluent_bit = module.observability.fluent_bit_role
    tempo      = module.observability.tempo_role
  }
}

output "helm_releases" {
  description = "Helm release information"
  value = {
    fluent_bit = module.observability.fluent_bit_release
    tempo      = module.observability.tempo_release
    prometheus = module.observability.prometheus_release
    kiali      = module.observability.kiali_release
  }
}

output "tenant_configurations" {
  description = "Configured tenant information"
  value       = module.observability.tenant_configurations
}

output "ssm_parameters" {
  description = "SSM parameter names for integration with other layers"
  value       = module.observability.ssm_parameter_names
}

# ============================================================================
# Integration Information for Other Layers
# ============================================================================

output "integration_info" {
  description = "Information needed by other layers for observability integration"
  value = {
    # For Istio configuration
    tempo_endpoint      = module.observability.tempo_endpoint
    prometheus_endpoint = module.observability.prometheus_endpoint

    # For application instrumentation
    trace_ingestion_endpoints = {
      otlp_grpc     = "http://tempo.istio-system.svc.cluster.local:4317"
      otlp_http     = "http://tempo.istio-system.svc.cluster.local:4318"
      jaeger_grpc   = "http://tempo.istio-system.svc.cluster.local:14250"
      jaeger_thrift = "http://tempo.istio-system.svc.cluster.local:14268"
    }

    # For metrics collection
    prometheus_scrape_configs = {
      istio_proxy  = "istio-proxy"
      applications = "http-metrics"
    }

    # S3 bucket information for external access
    logs_bucket_name   = module.observability.logs_s3_bucket.bucket
    traces_bucket_name = module.observability.traces_s3_bucket.bucket

    # Regional information
    region       = var.region
    cluster_name = local.cluster_name
  }
}
