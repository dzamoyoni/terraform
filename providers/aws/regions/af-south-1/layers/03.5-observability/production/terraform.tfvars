# ============================================================================
# 📊 Observability Layer - AF-South-1 Production Configuration
# ============================================================================
# PRODUCTION-GRADE CONFIGURATION WITH ENHANCED MONITORING & ALERTING
# ============================================================================

# Core Configuration
project_name = "cptwn-multi-client-eks"
environment  = "production"
region      = "af-south-1"

# ============================================================================
# S3 Configuration - PRODUCTION RETENTION POLICIES
# ============================================================================
logs_retention_days   = 90  # 3 months for compliance & debugging
traces_retention_days = 30  # 1 month for performance analysis

# ============================================================================
# Prometheus Configuration - PRODUCTION GRADE
# ============================================================================
enable_local_prometheus = true # ✅ Required for service mesh metrics

# IMPORTANT: Configure your central Grafana remote write endpoint
# This allows metrics to flow to your central monitoring system
prometheus_remote_write_url      = "https://prometheus-us-central-1.prod-us-central-0.grafana.net/api/prom/push"  # 🔧 UPDATE THIS
prometheus_remote_write_username = "1234567"  # 🔧 UPDATE WITH YOUR GRAFANA INSTANCE ID
prometheus_remote_write_password = "glc_your-grafana-cloud-token-here"  # 🔧 UPDATE WITH YOUR API TOKEN

# ============================================================================
# Kiali Configuration - PRODUCTION SECURITY
# ============================================================================
kiali_auth_strategy     = "token" # ✅ Production security (vs anonymous)
external_prometheus_url = "http://prometheus-kube-prometheus-prometheus.istio-system.svc.cluster.local:9090"

# ============================================================================
# Production Features - ENHANCED MONITORING
# ============================================================================
enable_cross_region_replication = false  # Enable if you need DR replication
additional_tenant_namespaces    = []

# ============================================================================
# PRODUCTION ENHANCEMENTS - MISSING FROM CURRENT CONFIG
# ============================================================================
enable_grafana              = true   # 🆕 Local dashboards for troubleshooting
enable_alertmanager         = true   # 🆕 CRITICAL: Production alerting
enable_enhanced_monitoring  = true   # 🆕 ServiceMonitors & PrometheusRules
enable_postgres_monitoring  = true   # 🆕 Database monitoring

# ============================================================================
# ALERT CONFIGURATION - PRODUCTION CRITICAL
# ============================================================================
# 🚨 CONFIGURE THESE FOR PRODUCTION ALERTS
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"  # 🔧 UPDATE THIS
alert_email       = "dennis.juma@ezra.world"

# ============================================================================
# DATABASE MONITORING - CLIENT SPECIFIC
# ============================================================================
postgres_endpoints = {
  mtn_ghana = {
    host     = "172.20.2.33"
    port     = "5433"
    database = "mtn_ghana_prod"
    client   = "mtn-ghana"
  }
  orange_madagascar = {
    host     = "172.20.3.44"     # 🔧 UPDATE WITH ACTUAL IP
    port     = "5433"
    database = "orange_madagascar_prod"
    client   = "orange-madagascar"
  }
  ezra = {
    host     = "172.20.1.153"
    port     = "5433"  
    database = "ezra_prod"
    client   = "ezra"
  }
}

# ============================================================================
# HIGH AVAILABILITY & PRODUCTION CONFIGURATION
# ============================================================================
prometheus_replicas         = 2      # HA setup
enable_prometheus_ha        = true   # High availability
prometheus_retention        = "30d"  # 30 days retention
prometheus_retention_size   = "25GB" # Storage limit

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================
enable_network_policies     = true  # Network isolation
enable_pod_security_policies = true # Pod security
enable_security_context     = true  # Security contexts

# ============================================================================
# ALERTMANAGER CONFIGURATION
# ============================================================================
alertmanager_storage_class = "gp3"   # EBS gp3 for performance
alertmanager_replicas     = 2        # High availability

# ============================================================================
# GRAFANA CONFIGURATION
# ============================================================================
grafana_admin_password = ""  # Auto-generated secure password
