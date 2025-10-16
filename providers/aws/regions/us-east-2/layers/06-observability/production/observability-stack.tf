# ============================================================================
# Production Observability Stack - System Node Isolation
# ============================================================================
# Deploy complete observability stack with proper workload isolation:
# - Heavy workloads (Prometheus, Grafana, Loki) run on system nodes only
# - DaemonSets (Fluent Bit, Node Exporter) run on ALL nodes with light resources
# - Anti-affinity for HA across system nodes
# - S3 storage backend for all observability data
# ============================================================================

# ============================================================================
# Prometheus Stack - System Nodes Only
# ============================================================================

resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack-monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600
  wait       = true

  values = [
    yamlencode({
      # Disable automatic datasource creation to prevent conflicts
      prometheus-node-exporter = {
        hostRootfs = false
      }

      # ============================================================================
      # Prometheus Configuration - System Nodes Only
      # ============================================================================
      prometheus = {
        prometheusSpec = {
          # Resource isolation - SYSTEM NODES ONLY
          nodeSelector = local.system_node_config.node_selector
          tolerations  = local.system_node_config.tolerations

          # High Availability - 2 replicas with anti-affinity
          replicas = var.prometheus_replicas
          
          # Anti-affinity to spread across system nodes
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    labelSelector = {
                      matchExpressions = [
                        {
                          key      = "app.kubernetes.io/name"
                          operator = "In"
                          values   = ["prometheus"]
                        }
                      ]
                    }
                    topologyKey = "kubernetes.io/hostname"
                  }
                }
              ]
            }
          }

          # Storage configuration with GP2-CSI
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2-csi"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"  # Increased for production
                  }
                }
              }
            }
          }

          # Data retention and resource limits
          retention     = var.prometheus_retention
          retentionSize = var.prometheus_retention_size

          # Resource limits for system nodes
          resources = {
            limits = {
              cpu    = "4000m"   # High CPU for metrics processing
              memory = "8Gi"     # High memory for metrics storage
            }
            requests = {
              cpu    = "1000m"
              memory = "4Gi"
            }
          }

          # Remote write to S3 (if configured)
          remoteWrite = var.prometheus_remote_write_url != "" ? [
            {
              url = var.prometheus_remote_write_url
              basicAuth = {
                username = {
                  name = "prometheus-remote-write"
                  key  = "username"
                }
                password = {
                  name = "prometheus-remote-write" 
                  key  = "password"
                }
              }
            }
          ] : []

          # Service discovery for multi-tenant scraping
          additionalScrapeConfigs = [
            {
              job_name = "kubernetes-pods-tenant-scraping"
              kubernetes_sd_configs = [
                {
                  role = "pod"
                  namespaces = {
                    names = concat(
                      ["monitoring", "kube-system", "istio-system"],
                      [for tenant in local.tenant_configs : tenant.namespace]
                    )
                  }
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action        = "keep"
                  regex         = "true"
                }
              ]
            }
          ]
        }
      }

      # ============================================================================
      # AlertManager Configuration - System Nodes Only
      # ============================================================================
      alertmanager = {
        alertmanagerSpec = {
          # Resource isolation - SYSTEM NODES ONLY
          nodeSelector = local.system_node_config.node_selector
          tolerations  = local.system_node_config.tolerations

          # High Availability
          replicas = var.alertmanager_replicas

          # Anti-affinity for HA
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    labelSelector = {
                      matchExpressions = [
                        {
                          key      = "app.kubernetes.io/name"
                          operator = "In"
                          values   = ["alertmanager"]
                        }
                      ]
                    }
                    topologyKey = "kubernetes.io/hostname"
                  }
                }
              ]
            }
          }

          # Storage configuration
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2-csi"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }

          # Resource limits
          resources = {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }

        # AlertManager configuration
        config = {
          global = {
            smtp_smarthost = "localhost:587"
          }
          route = {
            group_by        = ["alertname"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "1h"
            receiver        = "web.hook"
          }
          receivers = [
            {
              name = "web.hook"
              email_configs = var.alert_email != "" ? [
                {
                  to      = var.alert_email
                  subject = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  body    = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                }
              ] : []
              slack_configs = var.slack_webhook_url != "" ? [
                {
                  api_url   = var.slack_webhook_url
                  channel   = "#alerts"
                  title     = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
                  text      = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                }
              ] : []
            }
          ]
        }
      }

      # ============================================================================
      # Grafana Configuration - System Nodes Only  
      # ============================================================================
      grafana = {
        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        # Persistence with proper storage class
        persistence = {
          enabled          = true
          storageClassName = "gp2-csi"
          size             = "20Gi"
        }

        # Resource limits
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }

        # Admin credentials
        adminPassword = var.grafana_admin_password != "" ? var.grafana_admin_password : "admin123"

        # Service configuration
        service = {
          type = "ClusterIP"
          port = 80
          annotations = {}
        }

        # Grafana configuration
        "grafana.ini" = {
          security = {
            admin_user     = "admin"
            admin_password = var.grafana_admin_password != "" ? var.grafana_admin_password : "admin123"
          }
          server = {
            root_url         = "%(protocol)s://%(domain)s:%(http_port)s/"
            serve_from_sub_path = false
            domain          = "localhost"
            http_port       = 3000
            protocol        = "http"
            enforce_domain  = false
          }
          "auth.anonymous" = {
            enabled = false
          }
        }

        # Disable sidecar datasource provisioning completely
        sidecar = {
          datasources = {
            enabled = false
          }
        }
        
        # Force our own datasource configuration
        forceDeployDatasources = true
        
        # Datasource configuration
        datasources = {
          "datasources.yaml" = {
            apiVersion = 1
            datasources = [
              {
                name      = "Prometheus"
                type      = "prometheus"
                url       = "http://prometheus-stack-monitorin-prometheus.monitoring.svc.cluster.local:9090"
                access    = "proxy"
                isDefault = true
                uid       = "prometheus"
                jsonData = {
                  httpMethod   = "POST"
                  timeInterval = "30s"
                }
              },
              {
                name      = "Alertmanager"
                type      = "alertmanager"
                url       = "http://prometheus-stack-monitorin-alertmanager.monitoring.svc.cluster.local:9093"
                access    = "proxy"
                isDefault = false
                uid       = "alertmanager"
                jsonData = {
                  handleGrafanaManagedAlerts = false
                  implementation            = "prometheus"
                }
              },
              {
                name      = "Loki"
                type      = "loki"
                url       = "http://loki-loki-distributed-gateway.monitoring.svc.cluster.local:80"
                access    = "proxy"
                isDefault = false
                uid       = "loki"
              },
              {
                name      = "Tempo"
                type      = "tempo"
                url       = "http://tempo.monitoring.svc.cluster.local:3100"
                access    = "proxy"
                isDefault = false
                uid       = "tempo"
              }
            ]
          }
        }

        # Dashboard providers
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name    = "default"
                orgId   = 1
                folder  = ""
                type    = "file"
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        # Pre-configured dashboards
        dashboards = {
          default = {
            "kubernetes-cluster-monitoring" = {
              gnetId     = 7249
              datasource = "Prometheus"
            }
            "kubernetes-pod-monitoring" = {
              gnetId     = 6336
              datasource = "Prometheus"
            }
            "istio-mesh-dashboard" = {
              gnetId     = 7636
              datasource = "Prometheus"
            }
          }
        }
      }

      # ============================================================================
      # Node Exporter - DaemonSet on ALL Nodes
      # ============================================================================
      nodeExporter = {
        # DaemonSet tolerations - RUNS ON ALL NODES
        tolerations = local.daemonset_config.tolerations

        # Light resource limits for DaemonSet
        resources = local.daemonset_config.resources

        # Host network for node metrics
        hostNetwork = true
        hostPID     = true

        # Service configuration
        service = {
          port = 9100
        }
      }

      # ============================================================================
      # Kube State Metrics - System Nodes Only
      # ============================================================================
      kubeStateMetrics = {
        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        # Resource limits
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # ============================================================================
      # Default Rules and ServiceMonitors
      # ============================================================================
      defaultRules = {
        create = true
        rules = {
          alertmanager        = true
          etcd               = true
          general            = true
          k8s                = true
          kubeApiserver      = true
          kubeApiserverAvailability = true
          kubeApiserverBurnrate     = true
          kubeApiserverHistogram    = true
          kubeApiserverSlos         = true
          kubelet                   = true
          kubeProxy                 = true
          kubePrometheusGeneral     = true
          kubePrometheusNodeRecording = true
          kubernetesApps            = true
          kubernetesResources       = true
          kubernetesStorage         = true
          kubernetesSystem          = true
          node                      = true
          nodeExporterAlerting      = true
          nodeExporterRecording     = true
          prometheus                = true
          prometheusOperator        = true
        }
      }

      # Service monitors for additional components
      kubeControllerManager = {
        enabled = false  # EKS managed
      }
      kubeEtcd = {
        enabled = false  # EKS managed  
      }
      kubeScheduler = {
        enabled = false  # EKS managed
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_storage_class_v1.gp2_csi
  ]
}

# ============================================================================
# 📋 Loki Distributed - System Nodes Only (COMMENTED OUT - RESOURCE CONSTRAINTS)
# ============================================================================

resource "helm_release" "loki_distributed" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-distributed"
  version    = "0.80.5"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600
  wait       = true

  values = [
    yamlencode({
      # Global configuration
      global = {
        image = {
          registry = "docker.io"
        }
        dnsService   = "kube-dns"
        dnsNamespace = "kube-system"
      }

      # Loki configuration with S3 backend - using config override approach
      loki = {
        # Use config file override approach instead of structured config
        structuredConfig = {
          auth_enabled = false
          server = {
            http_listen_port = 3100
            grpc_listen_port = 9095
            log_level        = "info"
          }
          common = {
            storage = {
              s3 = {
                bucketnames = data.aws_s3_bucket.logs.id
                region      = var.region
              }
            }
          }
          schema_config = {
            configs = [
              {
                from         = "2024-01-01"
                store        = "boltdb-shipper"
                object_store = "s3"
                schema       = "v12"
                index = {
                  prefix = "loki_index_"
                  period = "24h"
                }
              }
            ]
          }
          limits_config = {
            ingestion_rate_strategy      = "global"
            ingestion_rate_mb            = 32
            ingestion_burst_size_mb      = 64
            max_global_streams_per_user  = 10000
            max_query_length             = "12000h"
            retention_period             = "${var.logs_retention_days * 24}h"
            per_stream_rate_limit        = "10MB"
            per_stream_rate_limit_burst  = "20MB"
          }
        }
      }

      # ============================================================================
      # Loki Components - All on System Nodes
      # ============================================================================

      # Ingester - System Nodes Only - Reduced replicas
      ingester = {
        replicas       = 1
        maxUnavailable = 0

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        # Anti-affinity for HA - COMMENTED OUT
        # podAntiAffinity = {
        #   preferredDuringSchedulingIgnoredDuringExecution = [
        #     {
        #       weight = 100
        #       podAffinityTerm = {
        #         labelSelector = {
        #           matchExpressions = [
        #             {
        #               key      = "app.kubernetes.io/component"
        #               operator = "In"
        #               values   = ["ingester"]
        #             }
        #           ]
        #         }
        #         topologyKey = "kubernetes.io/hostname"
        #       }
        #     }
        #   ]
        # }

        # Resources - Minimal for constrained cluster
        resources = {
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }

        # Persistence for WAL - Reduced size
        persistence = {
          enabled          = true
          storageClassName = "gp2-csi"
          size             = "10Gi"
        }

        # Service account with IRSA for S3 access
        serviceAccount = {
          create = true
          name   = "loki-ingester"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit_role.arn
          }
        }
      }

      # Distributor - System Nodes Only - Reduced replicas
      distributor = {
        replicas       = 1
        maxUnavailable = 0

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
        }
      }

      # Querier - System Nodes Only - Reduced replicas
      querier = {
        replicas       = 1
        maxUnavailable = 0

        # Resource isolation - SYSTEM NODES ONLY  
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
        }

        serviceAccount = {
          create = true
          name   = "loki-querier"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit_role.arn
          }
        }
      }

      # Query Frontend - System Nodes Only - Reduced replicas
      queryFrontend = {
        replicas       = 1
        maxUnavailable = 0

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
        }
      }

      # Compactor - System Nodes Only
      compactor = {
        enabled = true

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }

        serviceAccount = {
          create = true
          name   = "loki-compactor"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit_role.arn
          }
        }

        persistence = {
          enabled          = true
          storageClassName = "gp2-csi"
          size             = "5Gi"
        }
      }

      # Gateway - System Nodes Only - Reduced replicas
      gateway = {
        enabled        = true
        replicas       = 1
        maxUnavailable = 0

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "50m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "10m"
            memory = "32Mi"
          }
        }

        service = {
          type = "ClusterIP"
          port = 80
        }
      }

      # Memcached for query caching - System Nodes Only
      memcached = {
        enabled = true

        # Resource isolation - SYSTEM NODES ONLY
        nodeSelector = local.system_node_config.node_selector
        tolerations  = local.system_node_config.tolerations

        resources = {
          limits = {
            cpu    = "100m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
        }
      }

      # Service monitor for Prometheus integration
      serviceMonitor = {
        enabled   = true
        namespace = kubernetes_namespace.monitoring.metadata[0].name
        labels = {
          release = "prometheus-stack-monitoring"
        }
        interval = "15s"
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus_stack,
    data.aws_s3_bucket.logs,
    aws_iam_role.fluent_bit_role
  ]
}