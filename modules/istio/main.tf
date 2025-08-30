# Istio Service Mesh Module
# Deploys Istio with ambient mesh mode for production EKS clusters

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

# ============================================================================
# Istio namespace (managed separately to allow import)
# ============================================================================

# Get the existing istio-system namespace
data "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

# Local values for configuration
locals {
  # Use the existing namespace
  namespace = data.kubernetes_namespace.istio_system.metadata[0].name
}

# Istio Base Components
resource "helm_release" "istio_base" {
  
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = var.istio_version

  create_namespace = true

  values = [
    yamlencode({
      defaultRevision = var.istio_revision
    })
  ]

  timeout = 300
  wait    = true
}

# Istio Control Plane (istiod)
resource "helm_release" "istiod" {
  
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = var.istio_version

  depends_on = [helm_release.istio_base]

  values = [
    yamlencode({
      revision = var.istio_revision
      meshConfig = {
        extensionProviders = [
          {
            name = "otel"
            envoyOtelAls = {
              service = "opentelemetry-collector.istio-system.svc.cluster.local"
              port    = 4317
            }
          }
        ]
      }
      pilot = {
        resources = {
          requests = {
            cpu    = var.istiod_resources.requests.cpu
            memory = var.istiod_resources.requests.memory
          }
          limits = {
            cpu    = var.istiod_resources.limits.cpu
            memory = var.istiod_resources.limits.memory
          }
        }
        env = {
          PILOT_ENABLE_AMBIENT = var.enable_ambient_mode
        }
      }
      global = {
        istioNamespace = "istio-system"
        meshID         = var.mesh_id
        network        = var.network_name
        cluster        = var.cluster_name
      }
    })
  ]

  timeout = 600
  wait    = true
}

# Istio CNI (required for ambient mode) - Skip since it's already configured in AWS CNI
# The CNI plugin is already present in the /etc/cni/net.d/10-aws.conflist file
# so we don't need to install it via Helm

# Ztunnel (ambient mode proxy)
resource "helm_release" "ztunnel" {
  count = var.enable_ambient_mode ? 1 : 0

  name       = "ztunnel"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "ztunnel"
  namespace  = "istio-system"
  version    = var.istio_version

  depends_on = [helm_release.istiod]

  # Use set blocks to override the image directly since values aren't working properly
  set {
    name  = "image.repository"
    value = "docker.io/istio/ztunnel"
  }

  set {
    name  = "image.tag"
    value = var.istio_version
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = var.ztunnel_resources.requests.cpu
          memory = var.ztunnel_resources.requests.memory
        }
        limits = {
          cpu    = var.ztunnel_resources.limits.cpu
          memory = var.ztunnel_resources.limits.memory
        }
      }
    })
  ]

  timeout = 300
  wait    = true
}

# Istio Ingress Gateway
resource "helm_release" "istio_ingress" {
  count = var.enable_ingress_gateway ? 1 : 0

  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = var.istio_version

  depends_on = [helm_release.istiod]

  # Use set blocks to override the image directly since values aren't working properly
  set {
    name  = "image.repository"
    value = "docker.io/istio/proxyv2"
  }

  set {
    name  = "image.tag"
    value = var.istio_version
  }

  values = [
    yamlencode({
      service = {
        type = var.ingress_gateway_type
        ports = [
          {
            name       = "status-port"
            port       = 15021
            protocol   = "TCP"
            targetPort = 15021
          },
          {
            name       = "http2"
            port       = 80
            protocol   = "TCP"
            targetPort = 8080
          },
          {
            name       = "https"
            port       = 443
            protocol   = "TCP"
            targetPort = 8443
          }
        ]
        annotations = var.ingress_gateway_annotations
      }
      resources = {
        requests = {
          cpu    = var.gateway_resources.requests.cpu
          memory = var.gateway_resources.requests.memory
        }
        limits = {
          cpu    = var.gateway_resources.limits.cpu
          memory = var.gateway_resources.limits.memory
        }
      }
      autoscaling = {
        enabled                        = var.gateway_autoscaling.enabled
        minReplicas                   = var.gateway_autoscaling.min_replicas
        maxReplicas                   = var.gateway_autoscaling.max_replicas
        targetCPUUtilizationPercentage = var.gateway_autoscaling.target_cpu
      }
    })
  ]

  timeout = 300
  wait    = true
}

# Istio Egress Gateway (optional)
resource "helm_release" "istio_egress" {
  count = var.enable_egress_gateway ? 1 : 0

  name       = "istio-egressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = var.istio_version

  depends_on = [helm_release.istiod]

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  timeout = 300
  wait    = true
}

# Enable ambient mode for specified namespaces
resource "kubernetes_labels" "ambient_enabled_namespaces" {
  for_each = toset(var.ambient_namespaces)

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = each.value
  }
  labels = {
    "istio.io/dataplane-mode" = "ambient"
  }

  depends_on = [helm_release.ztunnel]
}

# Check if ServiceMonitor CRD exists (Prometheus Operator)
data "kubernetes_resources" "servicemonitor_crd" {
  api_version    = "apiextensions.k8s.io/v1"
  kind           = "CustomResourceDefinition"
  field_selector = "metadata.name=servicemonitors.monitoring.coreos.com"
}

# Create monitoring service monitor if Prometheus is available and enabled
resource "kubernetes_manifest" "istio_service_monitor" {
  count = var.enable_monitoring && length(data.kubernetes_resources.servicemonitor_crd.objects) > 0 ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "istio-mesh"
      namespace = "istio-system"
      labels = {
        app = "istio-mesh-monitor"
      }
    }
    spec = {
      selector = {
        matchExpressions = [
          {
            key      = "app"
            operator = "In"
            values   = ["istiod", "istio-proxy"]
          }
        ]
      }
      endpoints = [
        {
          port     = "http-monitoring"
          interval = "30s"
          path     = "/stats/prometheus"
        }
      ]
    }
  }

  depends_on = [helm_release.istiod]
}
