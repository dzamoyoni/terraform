# ============================================================================
# Observability Layer - US-East-2 Production Configuration
# ============================================================================
# Resource-isolated observability stack for ohio-01-eks cluster
# - All heavy workloads run on system nodes only (no resource competition)
# - DaemonSets run on all nodes but with strict resource limits
# - All observability components deployed in 'monitoring' namespace
# - Complete S3 export with no local node storage
# - Java application tracing with Jaeger and OpenTelemetry
# ============================================================================

# Core Project Configuration
project_name = "ohio-01"  # Aligned with existing S3 bucket naming
environment  = "production"
region       = "us-east-2"

# ============================================================================
# RESOURCE ISOLATION - Protect Client Workloads
# ============================================================================
# Ensure observability doesn't compete with client applications for resources

# All observability deployments run on system nodes only
# This prevents resource competition with client applications

# ============================================================================
# S3 EXPORT AND STORAGE - No Local Node Storage
# ============================================================================
s3_export_enabled     = true #  All observability data exported to S3
s3_lifecycle_enabled  = true #  Cost optimization with lifecycle policies
disable_local_storage = true #  No local storage on nodes - S3 only

# S3 Lifecycle Configuration for Cost Optimization
s3_transition_to_ia_days      = 30  # Move to Infrequent Access after 30 days
s3_transition_to_glacier_days = 90  # Move to Glacier after 90 days  
s3_expiration_days            = 365 # Delete after 1 year (adjust as needed)

# ============================================================================
# DATA RETENTION POLICIES
# ============================================================================
logs_retention_days   = 90 # 90 days log retention in S3
traces_retention_days = 30 # 30 days trace retention in S3

# ============================================================================
# JAEGER DISTRIBUTED TRACING - Java Applications
# ============================================================================
enable_jaeger            = true    #  Enable for Java apps
jaeger_storage_type      = "cassandra" # BEST for production: scalable, HA, low overhead 
jaeger_s3_export_enabled = true         # Export traces to S3

# Production storage backend comparison:
# jaeger_storage_type = ""
# - "cassandra"     - RECOMMENDED: Horizontally scalable, HA, optimized for traces
# - "elasticsearch" - Heavy: High resource usage, complex operations
# - "memory"        - DEV ONLY: No persistence, data loss on restart
#
# Cassandra advantages for production:
# - Built for time-series data (perfect for traces)
# - Linear scalability with no single point of failure
# - Lower resource overhead than Elasticsearch
# - Battle-tested for high-volume trace storage

# Tempo Configuration - Use existing traces bucket
tempo_s3_bucket = "ohio-01-us-east-2-traces-production"  # Uses existing traces bucket

# ============================================================================
# OPENTELEMETRY - Modern Observability
# ============================================================================
enable_otel_collector             = true        # Enable OTEL Collector
otel_collector_mode               = "daemonset" # DaemonSet for all nodes
otel_java_instrumentation_enabled = true        # Auto-instrument Java apps

# ============================================================================
# PROMETHEUS - Metrics with S3 Remote Storage
# ============================================================================
prometheus_replicas         = 2      # HA setup on system nodes
enable_prometheus_ha        = true   # High availability
prometheus_retention        = "30d"  # Local retention before S3 export
prometheus_retention_size   = "25GB" # Local storage limit
prometheus_remote_write_url = ""     # Optional: central Grafana URL

# ============================================================================
# GRAFANA - Dashboards and Visualization
# ============================================================================
enable_grafana         = true
grafana_admin_password = "" # Auto-generated secure password

# ============================================================================
# ALERTMANAGER - Production Alerting
# ============================================================================
enable_alertmanager        = true
alertmanager_replicas      = 2     # HA setup on system nodes
alertmanager_storage_class = "gp2" # GP2 for cost optimization
alert_email                = "dennis.juma@ezra.world"
slack_webhook_url          = "" # Configure for Slack notifications

# ============================================================================
# ENHANCED MONITORING
# ============================================================================
enable_enhanced_monitoring = true
enable_postgres_monitoring = true

# PostgreSQL endpoints for monitoring (update with actual endpoints)
postgres_endpoints = {
  est_test_a = {
    host     = "est-test-a-db.cluster-xyz.us-east-2.rds.amazonaws.com"
    port     = "5432"
    database = "est_test_a_prod"
    client   = "est-test-a"
  }
  est_test_b = {
    host     = "est-test-b-db.cluster-xyz.us-east-2.rds.amazonaws.com"
    port     = "5432"
    database = "est_test_b_prod"
    client   = "est-test-b"
  }
}

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================
enable_network_policies      = true
enable_pod_security_policies = true
enable_security_context      = true

# ============================================================================
# MULTI-REGION SETUP (Optional)
# ============================================================================
enable_cross_region_replication = false # Set to true for multi-region

# ============================================================================
# KIALI - Service Mesh Visualization
# ============================================================================
kiali_auth_strategy     = "token" # Enhanced security
external_prometheus_url = ""      # Use local Prometheus

# ============================================================================
# ADDITIONAL MONITORING NAMESPACES
# ============================================================================
# These are application namespaces to monitor (not where observability runs)
additional_tenant_namespaces = [
  "platform",
  "istio-system",
  "kube-system",
  "est-test-a-prod",
  "est-test-b-prod",
  "analytics"
]

# ============================================================================
# TERRAFORM STATE CONFIGURATION
# ============================================================================
terraform_state_bucket = "ohio-01-terraform-state-production"
terraform_state_region = "us-east-2"

# ============================================================================
# RESOURCE LIMITS FOR DAEMONSETS (Running on Client Nodes)
# ============================================================================
# These components run on ALL nodes but with minimal resource impact

# Fluent Bit - Log collection (lightweight DaemonSet)
# Default resource limits ensure minimal impact on client workloads

# OTEL Collector - Metrics/trace collection (lightweight DaemonSet)  
# Default resource limits ensure minimal impact on client workloads

# Node Exporter - System metrics (minimal impact DaemonSet)
# Default resource limits ensure minimal impact on client workloads

# Jaeger Agent - Local trace forwarding (lightweight DaemonSet)
# Default resource limits ensure minimal impact on client workloads

# ============================================================================
# NOTES ON WORKLOAD PLACEMENT:
# ============================================================================
# - Prometheus: System nodes only (heavy metrics processing)
# - Grafana: System nodes only (dashboard rendering) 
# - AlertManager: System nodes only (alert processing)
# - Jaeger Query: System nodes only (trace querying)
# - Jaeger Collector: System nodes only (trace aggregation)
# - Tempo: System nodes only (trace storage)
# - Kiali: System nodes only (service mesh visualization)
# - Elasticsearch: System nodes only (search and analytics)
#
# - Fluent Bit: DaemonSet on all nodes (log collection)
# - OTEL Collector: DaemonSet on all nodes (metrics/traces)
# - Node Exporter: DaemonSet on all nodes (node metrics)
# - Jaeger Agent: DaemonSet on all nodes (trace forwarding)
# ============================================================================
