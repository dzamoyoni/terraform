# ============================================================================
# 🔍 DaemonSets and Tracing Components
# ============================================================================
# Components that need to run on all nodes or provide distributed tracing:
# - Fluent Bit: Log collection DaemonSet (ALL nodes)
# - Tempo: Distributed tracing (System nodes)
# - Kiali: Service mesh visualization (System nodes)
# ============================================================================

# ============================================================================
# 🎯 Tempo - Distributed Tracing Backend (BULLETPROOF VERSION)
# ============================================================================
# This comprehensive configuration addresses all probe and port issues
# by explicitly overriding every chart default that causes problems.

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.23.3"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600  # Increased timeout for robust deployment
  wait       = true

  values = [
    yamlencode({
      # 🎯 CRITICAL FIX: Override ALL probe configurations
      # This is the root cause of all our issues - the chart hardcodes port 3200
      livenessProbe = {
        httpGet = {
          path   = "/ready"
          port   = 3100  # MUST match tempo.server.http_listen_port
          scheme = "HTTP"
        }
        initialDelaySeconds = 45   # Generous startup time
        periodSeconds       = 15
        timeoutSeconds      = 10   # Longer timeout for stability
        failureThreshold    = 5    # More tolerance for startup
        successThreshold    = 1
      }

      readinessProbe = {
        httpGet = {
          path   = "/ready"
          port   = 3100  # MUST match tempo.server.http_listen_port
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 10
        failureThreshold    = 3
        successThreshold    = 1
      }

      # 🏗️ Deployment Configuration - SYSTEM NODES ONLY
      nodeSelector = local.system_node_config.node_selector
      tolerations  = local.system_node_config.tolerations

      # 💪 Enhanced Resource Configuration
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "2Gi"
        }
      }

      # 🔐 Service Account with S3 Access
      serviceAccount = {
        create = true
        name   = "tempo"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.tempo_role.arn
        }
      }

      # 💾 Persistent Storage
      persistence = {
        enabled          = true
        storageClassName = "gp2-csi"
        size             = "20Gi"  # Adequate space for WAL and local cache
        accessModes      = ["ReadWriteOnce"]
      }

      # 🎛️ Comprehensive Tempo Configuration
      tempo = {
        # 🔧 CRITICAL: Server configuration - this sets the HTTP port
        server = {
          http_listen_port = 3100  # Standard Tempo HTTP port
          grpc_listen_port = 9095  # Standard Tempo GRPC port
          log_level        = "info"
          log_format       = "json"
        }

        # 📦 S3 Storage Backend
        storage = {
          trace = {
            backend = "s3"
            s3 = {
              bucket               = data.aws_s3_bucket.traces.id
              region               = var.region
              endpoint             = "s3.${var.region}.amazonaws.com"
              access_key           = ""  # Use IRSA
              secret_key           = ""  # Use IRSA
              insecure             = false
              part_size            = 5242880  # 5MB parts
              hedge_requests_at    = "500ms"
              hedge_requests_up_to = 3
            }
            wal = {
              path = "/var/tempo/wal"
            }
          }
        }

        # 📡 Receiver Configuration for All Protocols
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
                cors = {
                  allowed_origins = ["*"]
                }
              }
            }
          }
          jaeger = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:14250"
              }
              thrift_http = {
                endpoint = "0.0.0.0:14268"
              }
              thrift_compact = {
                endpoint = "0.0.0.0:6831"
              }
              thrift_binary = {
                endpoint = "0.0.0.0:6832"
              }
            }
          }
          zipkin = {
            endpoint = "0.0.0.0:9411"
            cors = {
              allowed_origins = ["*"]
            }
          }
        }

        # ⚡ Performance Tuning
        ingester = {
          trace_idle_period     = "10s"
          max_block_duration    = "5m"
          flush_check_period    = "10s"
          max_block_bytes       = 1048576  # 1MB
          complete_block_timeout = "5m"
        }

        # 🗜️ Compactor Configuration
        compactor = {
          compaction = {
            block_retention = "168h"  # 7 days
          }
        }

        # 🔧 Additional Stability Settings
        multitenancyEnabled = false
        reportingEnabled = false
        memBallastSizeMbs = 1024
        
        # Data retention
        retention = "168h"  # 7 days
      }

      # 🌐 Service Configuration
      service = {
        type = "ClusterIP"
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "3100"
          "prometheus.io/path"   = "/metrics"
        }
      }

      # 📊 ServiceMonitor for Prometheus
      serviceMonitor = {
        enabled = true
        labels = {
          release   = "prometheus-stack-monitoring"
          component = "tempo"
        }
        interval      = "15s"
        scrapeTimeout = "10s"
        path          = "/metrics"
        scheme        = "http"
      }

      # 🛡️ Security Context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 10001
        fsGroup      = 10001
        capabilities = {
          drop = ["ALL"]
        }
      }

      # 🚀 Additional Args for Explicit Configuration
      extraArgs = [
        "-log.level=info",
        "-server.http-listen-port=3100",
        "-server.grpc-listen-port=9095"
      ]
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    data.aws_s3_bucket.traces,
    aws_iam_role.tempo_role
  ]
}

# ============================================================================
# 🔧 Automated Tempo Probe Fix (PERMANENT SOLUTION)
# ============================================================================
# This automatically fixes the Helm chart bug that hardcodes probes to port 3200
# instead of the configured port 3100. This ensures Tempo works on every deployment.

resource "null_resource" "tempo_probe_fix" {
  depends_on = [helm_release.tempo]
  
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      set -e
      
      echo "🔧 Starting Tempo health probe fix..."
      
      # Wait for StatefulSet to be created
      echo "⏳ Waiting for Tempo StatefulSet..."
      kubectl wait --for=condition=Ready statefulset/tempo -n monitoring --timeout=300s || true
      
      # Check current probe ports
      echo "🔍 Checking current probe configuration..."
      LIVENESS_PORT=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null || echo "unknown")
      READINESS_PORT=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || echo "unknown")
      
      echo "📊 Current probe ports: Liveness=$LIVENESS_PORT, Readiness=$READINESS_PORT"
      
      # Apply fix if needed
      if [[ "$LIVENESS_PORT" != "3100" || "$READINESS_PORT" != "3100" ]]; then
        echo "🚨 HELM CHART BUG DETECTED: Probes using wrong ports!"
        echo "🔧 Applying automatic fix..."
        
        # Apply the patch
        kubectl patch statefulset tempo -n monitoring --type='json' -p='[
          {
            "op": "replace", 
            "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/port", 
            "value": 3100
          },
          {
            "op": "replace", 
            "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/port", 
            "value": 3100
          }
        ]'
        
        echo "✅ Patch applied successfully!"
        
        # Force pod restart to apply the fix
        echo "🔄 Restarting Tempo pod to apply probe fix..."
        kubectl delete pod -l app.kubernetes.io/name=tempo -n monitoring --grace-period=30 || true
        
        # Wait for pod to be ready
        echo "⏳ Waiting for Tempo to be ready..."
        kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=tempo -n monitoring --timeout=300s
        
        # Verify fix
        NEW_LIVENESS=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}')
        NEW_READINESS=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')
        
        echo "🎯 Verification: Liveness=$NEW_LIVENESS, Readiness=$NEW_READINESS"
        
        if [[ "$NEW_LIVENESS" == "3100" && "$NEW_READINESS" == "3100" ]]; then
          echo "🎉 SUCCESS: Tempo probe fix applied and verified!"
        else
          echo "❌ ERROR: Fix verification failed!"
          exit 1
        fi
      else
        echo "✅ Probes already correctly configured on port 3100"
      fi
      
      # Final health check
      echo "🏥 Performing final health validation..."
      kubectl get pods -l app.kubernetes.io/name=tempo -n monitoring
      
      # Wait a bit more to ensure stability
      sleep 10
      
      READY_STATUS=$(kubectl get pods -l app.kubernetes.io/name=tempo -n monitoring -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
      
      if [[ "$READY_STATUS" == "True" ]]; then
        echo "🎉 FINAL SUCCESS: Tempo is healthy and ready!"
      else
        echo "⚠️  WARNING: Tempo pod is not yet ready, but fix has been applied"
      fi
      
      echo "✅ Tempo probe fix complete!"
    EOF
    
    working_dir = path.module
  }
  
  # Trigger this fix whenever:
  # 1. Helm release changes (version, values)
  # 2. This script content changes
  triggers = {
    helm_release_version = helm_release.tempo.version
    helm_release_values  = sha256(jsonencode(helm_release.tempo.values))
    script_content      = sha256(<<-EOF
      #!/bin/bash
      set -e
      
      echo "🔧 Starting Tempo health probe fix..."
      
      # Wait for StatefulSet to be created
      echo "⏳ Waiting for Tempo StatefulSet..."
      kubectl wait --for=condition=Ready statefulset/tempo -n monitoring --timeout=300s || true
      
      # Check current probe ports
      echo "🔍 Checking current probe configuration..."
      LIVENESS_PORT=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null || echo "unknown")
      READINESS_PORT=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null || echo "unknown")
      
      echo "📊 Current probe ports: Liveness=$LIVENESS_PORT, Readiness=$READINESS_PORT"
      
      # Apply fix if needed
      if [[ "$LIVENESS_PORT" != "3100" || "$READINESS_PORT" != "3100" ]]; then
        echo "🚨 HELM CHART BUG DETECTED: Probes using wrong ports!"
        echo "🔧 Applying automatic fix..."
        
        # Apply the patch
        kubectl patch statefulset tempo -n monitoring --type='json' -p='[
          {
            "op": "replace", 
            "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/port", 
            "value": 3100
          },
          {
            "op": "replace", 
            "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/port", 
            "value": 3100
          }
        ]'
        
        echo "✅ Patch applied successfully!"
        
        # Force pod restart to apply the fix
        echo "🔄 Restarting Tempo pod to apply probe fix..."
        kubectl delete pod -l app.kubernetes.io/name=tempo -n monitoring --grace-period=30 || true
        
        # Wait for pod to be ready
        echo "⏳ Waiting for Tempo to be ready..."
        kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=tempo -n monitoring --timeout=300s
        
        # Verify fix
        NEW_LIVENESS=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}')
        NEW_READINESS=$(kubectl get statefulset tempo -n monitoring -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}')
        
        echo "🎯 Verification: Liveness=$NEW_LIVENESS, Readiness=$NEW_READINESS"
        
        if [[ "$NEW_LIVENESS" == "3100" && "$NEW_READINESS" == "3100" ]]; then
          echo "🎉 SUCCESS: Tempo probe fix applied and verified!"
        else
          echo "❌ ERROR: Fix verification failed!"
          exit 1
        fi
      else
        echo "✅ Probes already correctly configured on port 3100"
      fi
      
      # Final health check
      echo "🏥 Performing final health validation..."
      kubectl get pods -l app.kubernetes.io/name=tempo -n monitoring
      
      # Wait a bit more to ensure stability
      sleep 10
      
      READY_STATUS=$(kubectl get pods -l app.kubernetes.io/name=tempo -n monitoring -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
      
      if [[ "$READY_STATUS" == "True" ]]; then
        echo "🎉 FINAL SUCCESS: Tempo is healthy and ready!"
      else
        echo "⚠️  WARNING: Tempo pod is not yet ready, but fix has been applied"
      fi
      
      echo "✅ Tempo probe fix complete!"
    EOF
    )
  }
}

# ============================================================================
# 📋 Fluent Bit - Log Collection DaemonSet (ALL Nodes)
# ============================================================================

resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.54.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    yamlencode({
      # Service account with IRSA for S3 and Loki access
      serviceAccount = {
        create = true
        name   = "fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit_role.arn
        }
      }

      # DaemonSet configuration - RUNS ON ALL NODES
      kind = "DaemonSet"

      # Light resource limits for DaemonSet workload
      resources = local.daemonset_config.resources

      # Tolerations to run on ALL nodes (including system nodes)
      tolerations = local.daemonset_config.tolerations

      # Priority class for critical system workload
      priorityClassName = "system-node-critical"

      # Fluent Bit configuration
      config = {
        # Service configuration
        service = <<-EOF
          [SERVICE]
              Daemon Off
              Flush 1
              Log_Level info
              Parsers_File parsers.conf
              Parsers_File custom_parsers.conf
              HTTP_Server On
              HTTP_Listen 0.0.0.0
              HTTP_Port 2020
              Health_Check On
        EOF

        # Input configuration - Kubernetes container logs
        inputs = <<-EOF
          [INPUT]
              Name tail
              Path /var/log/containers/*.log
              multiline.parser docker, cri
              Tag kube.*
              Mem_Buf_Limit 50MB
              Skip_Long_Lines On
              Refresh_Interval 10

          [INPUT]
              Name systemd
              Tag host.*
              Systemd_Filter _SYSTEMD_UNIT=kubelet.service
              Systemd_Filter _SYSTEMD_UNIT=docker.service
              Systemd_Filter _SYSTEMD_UNIT=containerd.service
        EOF

        # Filters for log processing and enrichment
        filters = <<-EOF
          [FILTER]
              Name kubernetes
              Match kube.*
              Kube_URL https://kubernetes.default.svc:443
              Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
              Kube_Tag_Prefix kube.var.log.containers.
              Merge_Log On
              Keep_Log Off
              K8S-Logging.Parser On
              K8S-Logging.Exclude On

          [FILTER]
              Name nest
              Match kube.*
              Operation lift
              Nested_under kubernetes
              Add_prefix kubernetes_

          [FILTER]
              Name modify
              Match kube.*
              Add cluster_name ${local.cluster_name}
              Add environment ${var.environment}
              Add region ${var.region}
        EOF

        # Output configuration - Dual output to Loki and S3
        outputs = <<-EOF
          # Send logs to Loki for real-time querying
          [OUTPUT]
              Name loki
              Match kube.*
              Host loki-loki-distributed-gateway.monitoring.svc.cluster.local
              Port 80
              URI /loki/api/v1/push
              tenant_id ""
              labels job=fluent-bit, cluster=${local.cluster_name}, namespace=$kubernetes_namespace_name, pod=$kubernetes_pod_name, container=$kubernetes_container_name
              label_keys $kubernetes_labels
              remove_keys kubernetes_pod_id, kubernetes_docker_id, kubernetes_container_hash
              auto_kubernetes_labels on
              line_format json

          # Send logs to S3 for long-term storage and compliance
          [OUTPUT]
              Name s3
              Match kube.*
              bucket ${data.aws_s3_bucket.logs.id}
              region ${var.region}
              total_file_size 50M
              upload_timeout 10m
              use_put_object On
              s3_key_format /logs/cluster=${local.cluster_name}/namespace=$kubernetes_namespace_name/pod=$kubernetes_pod_name/year=%Y/month=%m/day=%d/hour=%H/fluent-bit-logs-%Y%m%d-%H%M%S-$UUID.gz

          # Send host logs to S3
          [OUTPUT]
              Name s3
              Match host.*
              bucket ${data.aws_s3_bucket.logs.id}
              region ${var.region}
              total_file_size 10M
              upload_timeout 10m
              use_put_object On
              s3_key_format /host-logs/cluster=${local.cluster_name}/year=%Y/month=%m/day=%d/hour=%H/host-logs-%Y%m%d-%H%M%S-$UUID.gz
        EOF

        # Custom parsers for different log formats
        customParsers = <<-EOF
          [PARSER]
              Name docker_no_time
              Format json
              Time_Keep Off
              Time_Key time
              Time_Format %Y-%m-%dT%H:%M:%S.%L

          [PARSER]
              Name cri
              Format regex
              Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$
              Time_Key time
              Time_Format %Y-%m-%dT%H:%M:%S.%L%z

          [PARSER]
              Name istio_envoy_proxy
              Format regex
              Regex ^\[(?<time>[^\]]*)\] "(?<method>\S+) (?<path>[^"]*) (?<protocol>[^"]*)" (?<response_code>\d+) (?<response_flags>[^ ]*) (?<bytes_received>\d+) (?<bytes_sent>\d+) (?<duration>\d+) (?<upstream_service_time>[^ ]*) "(?<forwarded_for>[^"]*)" "(?<user_agent>[^"]*)" "(?<request_id>[^"]*)" "(?<authority>[^"]*)" "(?<upstream_host>[^"]*)"
              Time_Key time
              Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        EOF
      }

      # Volume mounts for container and host logs
      volumeMounts = [
        {
          name      = "varlogcontainers"
          mountPath = "/var/log/containers"
          readOnly  = true
        },
        {
          name      = "varlogpods"
          mountPath = "/var/log/pods"
          readOnly  = true
        },
        {
          name      = "varlibdockercontainers"
          mountPath = "/var/lib/docker/containers"
          readOnly  = true
        },
        {
          name      = "systemd"
          mountPath = "/var/log/journal"
          readOnly  = true
        }
      ]

      # Host path volumes
      volumes = [
        {
          name = "varlogcontainers"
          hostPath = {
            path = "/var/log/containers"
          }
        },
        {
          name = "varlogpods"
          hostPath = {
            path = "/var/log/pods"
          }
        },
        {
          name = "varlibdockercontainers"
          hostPath = {
            path = "/var/lib/docker/containers"
          }
        },
        {
          name = "systemd"
          hostPath = {
            path = "/var/log/journal"
          }
        }
      ]

      # Security context
      securityContext = {
        runAsNonRoot = false  # Required for log file access
        runAsUser    = 0      # Required for log file access
      }

      # ServiceMonitor for Prometheus metrics
      serviceMonitor = {
        enabled = true
        labels = {
          release = "prometheus-stack-monitoring"
        }
        interval = "15s"
        path     = "/api/v1/metrics/prometheus"
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.loki_distributed,
    data.aws_s3_bucket.logs,
    aws_iam_role.fluent_bit_role
  ]
}

# ============================================================================
# 🕸️ Kiali - Service Mesh Visualization (System Nodes Only)
# ============================================================================

resource "helm_release" "kiali" {
  name       = "kiali-server"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  version    = "2.17.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    yamlencode({
      # Authentication strategy
      auth = {
        strategy = var.kiali_auth_strategy
      }

      # Deployment configuration - SYSTEM NODES ONLY
      deployment = {
        # Resource isolation
        node_selector = local.system_node_config.node_selector
        tolerations   = local.system_node_config.tolerations

        ingress_enabled = false
        
        # High availability configuration
        replica_count = 2
        
        # Additional labels for better organization
        additional_labels = {
          "app.kubernetes.io/component" = "kiali"
          "app.kubernetes.io/part-of"   = "istio"
          "version"                     = "v2.17.0"
        }
        
        # Pod annotations for enhanced observability
        pod_annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9090"
          "prometheus.io/path"   = "/metrics"
          "kiali.io/dashboards"  = "go,kiali"
        }

        # Enhanced resource limits for production
        resources = {
          requests = {
            cpu    = "200m"  # Increased for better performance
            memory = "512Mi" # Increased for larger clusters
          }
          limits = {
            cpu    = "2000m" # Increased for heavy workloads
            memory = "4Gi"   # Increased for large service mesh
          }
        }

        # Persistence for Kiali state and cache
        persistent_volume_claim = {
          enabled       = true
          size          = "5Gi"  # Increased for better caching
          storage_class = "gp2-csi"
          access_modes  = ["ReadWriteOnce"]
        }
        
        # Security context
        security_context = {
          run_as_non_root = true
          run_as_user     = 1001
          fs_group        = 2001
          capabilities = {
            drop = ["ALL"]
          }
        }
        
        # Pod disruption budget for high availability
        pod_disruption_budget = {
          enabled       = true
          min_available = 1
        }
        
        # Environment variables for enhanced functionality
        env = {
          LOG_LEVEL              = "info"
          LOG_FORMAT             = "text"
          LOG_TIME_FIELD_FORMAT  = "2006-01-02T15:04:05Z07:00"
          LOG_SAMPLER_RATE       = "1"
        }
      }

      # External services configuration
      external_services = {
        # Prometheus integration
        prometheus = {
          url = "http://prometheus-stack-monitorin-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
        }

        # Grafana integration with comprehensive dashboards
        grafana = {
          enabled        = true
          in_cluster_url = "http://prometheus-stack-monitoring-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
          url            = "http://prometheus-stack-monitoring-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
          auth = {
            type     = "bearer"
            use_kiali_token = true
          }
          dashboards = [
            {
              name = "Istio Service Dashboard"
              variables = {
                namespace = "var-namespace"
                service   = "var-service"
              }
            },
            {
              name = "Istio Workload Dashboard"
              variables = {
                namespace = "var-namespace"
                workload  = "var-workload"
              }
            },
            {
              name = "Istio Mesh Dashboard"
            },
            {
              name = "Istio Control Plane Dashboard"
            },
            {
              name = "Istio Performance Dashboard"
            }
          ]
        }

        # Tracing integration with Tempo
        tracing = {
          enabled         = true
          in_cluster_url  = "http://tempo.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100"
          external_url    = "http://tempo.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100"
          namespace_selector = true
        }

        # Enhanced Istio configuration
        istio = {
          namespace_name                     = "istio-system"
          config_map_name                    = "istio"
          istio_sidecar_annotation           = "sidecar.istio.io/status"
          istio_sidecar_injection_annotation = "sidecar.istio.io/inject"
          url_service_version                = ""
          
          # Istio API configuration
          istio_api_enabled = true
          
          # Istio identity domain
          istio_identity_domain = "cluster.local"
          
          # Gateway configuration
          gateway_api_classes = [
            {
              name      = "istio"
              class_name = "istio"
            }
          ]
          
          # Component status configuration
          component_status = {
            enabled = true
            components = [
              {
                app_label = "istiod"
                is_core   = true
              },
              {
                app_label = "istio-ingressgateway"
                is_core   = true
              },
              {
                app_label = "istio-egressgateway"
                is_core   = false
              }
            ]
          }
        }
      }

      # Istio namespace
      istio_namespace = "istio-system"

      # Enhanced server configuration
      server = {
        port            = 20001
        metrics_enabled = true
        metrics_port    = 9090
        web_root        = "/"
        web_fqdn        = ""  # Set if using ingress
        web_schema      = ""  # Set to https if using TLS
        
        # CORS configuration for multi-cluster
        cors_allow_all = false
        
        # Audit logging
        audit_log = true
        
        # Gzip compression for better performance
        gzip_enabled = true
        
        # API configuration
        api = {
          namespaces = {
            exclude = ["kube-.*", "openshift-.*"]  # Exclude system namespaces
            include = []
            label_selector_exclude = ""
            label_selector_include = ""
          }
        }
        
        # Cache configuration for better performance
        cache = {
          duration = 300  # 5 minutes
        }
        
        # Rate limiting
        rate_limit = {
          enabled = true
          per_client = 20  # requests per second per client
        }
        
        # Observability configuration
        observability = {
          metrics = {
            enabled = true
            port    = 9090
          }
          tracing = {
            enabled = true
            collector_url = "http://tempo.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:14268"
            otel = {
              protocol = "grpc"
            }
          }
        }
      }

      # Login token configuration for token auth
      login_token = {
        signing_key = "1234567890123456"  # Change in production
      }

      # Advanced Kiali feature flags
      kiali_feature_flags = {
        # Certificate information display
        certificates_information_indicators = {
          enabled = true
          secrets = ["cacerts", "istio-ca-secret"]
        }
        
        # Multi-cluster support
        clustering = {
          enabled = false  # Enable for multi-cluster setup
        }
        
        # Istio annotation action
        istio_annotation_action = true
        
        # Istio injection action
        istio_injection_action = true
        
        # Istio upgrade action
        istio_upgrade_action = false
        
        # UI defaults
        ui_defaults = {
          graph = {
            find_options = [
              {
                description = "Find: slow edges (> 1s)"
                expression  = "rt > 1000"
              },
              {
                description = "Find: unhealthy nodes"
                expression  = "! healthy"
              },
              {
                description = "Find: unknown nodes"
                expression  = "name = unknown"
              }
            ]
            hide_options = [
              {
                description = "Hide: healthy nodes"
                expression  = "healthy"
              },
              {
                description = "Hide: unknown nodes"
                expression  = "name = unknown"
              }
            ]
          }
          metrics_per_refresh = "1m"
          metrics_inbound = {
            aggregations = [
              {
                display_name = "Istio Network"
                label        = "topology_istio_io_network"
              }
            ]
          }
          metrics_outbound = {
            aggregations = [
              {
                display_name = "Istio Network"
                label        = "topology_istio_io_network"
              }
            ]
          }
          namespaces = ["istio-system"]
        }
        
        # Advanced validations
        validations = {
          ignore = [
            "KIA1301",  # Ignore specific validation warnings
            "KIA1201",  # Ignore deployment without app label
          ]
          skip_wildcard_gateway_hosts = false
        }
        
        # Disabled features (can be enabled as needed)
        disabled_features = [
          # "applications-tab",
          # "workloads-tab",
          # "services-tab",
          # "istio-config-tab"
        ]
      }

      # Multi-cluster configuration (if needed)
      clustering = {
        clusters = [
          {
            name              = local.cluster_name
            accessible_namespaces = ["**"]
            is_kialiHome     = true
            network          = ""
            secret_name      = ""
          }
        ]
      }

      # Enhanced ServiceMonitor for comprehensive metrics
      serviceMonitor = {
        enabled = true
        labels = {
          release = "prometheus-stack-monitoring"
          app     = "kiali"
          component = "observability"
        }
        interval      = "15s"  # More frequent scraping for better observability
        scrape_timeout = "10s"
        path          = "/metrics"
        scheme        = "http"
        
        # Metric relabeling for better organization
        metric_relabeling_configs = [
          {
            source_labels = ["__name__"]
            regex         = "kiali_(.+)"
            target_label  = "__name__"
            replacement   = "kiali_${1}"
          }
        ]
      }
      
      # Health check configuration
      health_config = {
        rate = [
          {
            namespace = ".*"
            kind      = "app"
            name      = ".*"
            tolerance = [
              {
                code      = "4XX"
                direction = "inbound"
                protocol  = "http"
                degraded  = 0.1
                failure   = 0.2
              },
              {
                code      = "5XX"
                direction = "inbound"
                protocol  = "http"
                degraded  = 0.05
                failure   = 0.1
              }
            ]
          }
        ]
      }
      
      # Kubernetes configuration
      kubernetes_config = {
        burst                    = 200
        cache_duration          = 300  # 5 minutes
        cache_token_namespace_duration = 10
        excluded_workloads      = ["CronJob", "DeploymentConfig", "Job", "ReplicationController"]
        qps                     = 175
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus_stack,
    helm_release.tempo
  ]
}

# ============================================================================
# 📊 ServiceMonitor for Custom Applications
# ============================================================================

resource "kubectl_manifest" "tenant_service_monitors" {
  for_each = {
    for tenant in local.tenant_configs : tenant.name => tenant
  }

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "${each.key}-service-monitor"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        tenant  = each.key
        release = "prometheus-stack-monitoring"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
      }
      namespaceSelector = {
        matchNames = [each.value.namespace]
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  })

  depends_on = [
    helm_release.prometheus_stack
  ]
}