# ============================================================================
# Observability Layer Outputs - AF-South-1 Production
# ============================================================================

output "observability_summary" {
  description = "Summary of deployed observability components"
  value = {
    namespace           = kubernetes_namespace.monitoring.metadata[0].name
    prometheus_replicas = 2
    grafana_enabled     = true
    components = {
      prometheus_stack = "deployed"
      loki_distributed = "deployed"
      tempo           = "deployed"
      fluent_bit      = "deployed"
      kiali          = "deployed"
    }
  }
  sensitive = true
}

output "s3_buckets" {
  description = "S3 buckets for observability data storage"
  value = {
    logs        = data.aws_s3_bucket.logs.id
    traces      = data.aws_s3_bucket.traces.id
    metrics     = data.aws_s3_bucket.metrics.id
    audit_logs  = data.aws_s3_bucket.audit_logs.id
  }
}

output "endpoints" {
  description = "Observability component endpoints"
  value = {
    tempo      = "http://tempo.monitoring.svc.cluster.local:3100"
    prometheus = "http://prometheus-stack-monitorin-prometheus.monitoring.svc.cluster.local:9090"
    grafana    = "http://prometheus-stack-monitoring-grafana.monitoring.svc.cluster.local"
    kiali      = "http://kiali-server.monitoring.svc.cluster.local:20001"
    loki       = "http://loki-gateway.monitoring.svc.cluster.local"
  }
}

output "helm_releases" {
  description = "Helm release information"
  value = {
    prometheus_stack = helm_release.prometheus_stack.name
    loki_distributed = helm_release.loki_distributed.name
    tempo           = helm_release.tempo.name
    fluent_bit      = helm_release.fluent_bit.name
    kiali          = helm_release.kiali.name
  }
}

output "tenant_configurations" {
  description = "Configured tenant information"
  value = {
    for config in local.tenant_configs : config.name => {
      namespace = config.namespace
      labels    = config.labels
    }
  }
}

# ============================================================================
# Integration Information for Other Layers
# ============================================================================

output "integration_info" {
  description = "Information needed by other layers for observability integration"
  value = {
    # For Istio configuration
    tempo_endpoint      = "http://tempo.monitoring.svc.cluster.local:3100"
    prometheus_endpoint = "http://prometheus-stack-monitorin-prometheus.monitoring.svc.cluster.local:9090"

    # For application instrumentation
    trace_ingestion_endpoints = {
      otlp_grpc     = "http://tempo.monitoring.svc.cluster.local:4317"
      otlp_http     = "http://tempo.monitoring.svc.cluster.local:4318"
      jaeger_grpc   = "http://tempo.monitoring.svc.cluster.local:14250"
      jaeger_thrift = "http://tempo.monitoring.svc.cluster.local:14268"
      zipkin        = "http://tempo.monitoring.svc.cluster.local:9411"
    }

    # For metrics collection
    prometheus_scrape_configs = {
      istio_proxy  = "istio-proxy"
      applications = "http-metrics"
    }

    # S3 bucket information for external access
    logs_bucket_name   = data.aws_s3_bucket.logs.id
    traces_bucket_name = data.aws_s3_bucket.traces.id

    # Regional information
    region       = var.region
    cluster_name = local.cluster_name
  }
  sensitive = true
}
