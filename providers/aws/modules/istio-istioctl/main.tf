# Istio Service Mesh Module using istioctl
# This module installs Istio using istioctl for more reliable installation

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Create istio-system namespace
resource "kubernetes_namespace" "istio_system" {
  count = var.create_namespaces ? 1 : 0
  
  metadata {
    name = var.istio_namespace
    
    labels = merge({
      "name" = var.istio_namespace
    }, var.common_tags)
  }
}

# Create ambient-enabled namespaces
resource "kubernetes_namespace" "ambient_namespaces" {
  for_each = var.create_namespaces ? toset(var.ambient_namespaces) : []
  
  metadata {
    name = each.key
    
    labels = merge({
      "name" = each.key
      "istio.io/dataplane-mode" = var.enable_ambient_mode ? "ambient" : null
    }, var.common_tags)
  }
}

# Download and install istioctl to user directory
resource "null_resource" "install_istioctl" {
  triggers = {
    istio_version = var.istio_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ISTIO_VERSION="${var.istio_version}"
      ISTIOCTL_DIR="$HOME/.local/bin"
      
      # Create user bin directory if it doesn't exist
      mkdir -p $ISTIOCTL_DIR
      
      # Check if istioctl already exists and is the right version
      if [ -f "$ISTIOCTL_DIR/istioctl" ]; then
        EXISTING_VERSION=$($ISTIOCTL_DIR/istioctl version 2>/dev/null | grep "client version:" | cut -d: -f2 | tr -d ' ' || echo "unknown")
        if [ "$EXISTING_VERSION" = "$ISTIO_VERSION" ]; then
          echo "istioctl $ISTIO_VERSION already installed"
          exit 0
        fi
      fi
      
      # Create temp directory
      TEMP_DIR=$(mktemp -d)
      cd $TEMP_DIR
      
      # Download istioctl
      curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
      
      # Copy istioctl to user bin directory
      cp istio-$ISTIO_VERSION/bin/istioctl $ISTIOCTL_DIR/
      chmod +x $ISTIOCTL_DIR/istioctl
      
      # Cleanup
      cd /
      rm -rf $TEMP_DIR
      
      # Add to PATH for current session
      export PATH="$ISTIOCTL_DIR:$PATH"
      
      # Verify installation
      $ISTIOCTL_DIR/istioctl version
    EOT
  }
}

# Install Istio base components
resource "null_resource" "istio_base" {
  depends_on = [
    null_resource.install_istioctl
  ]

  triggers = {
    istio_version = var.istio_version
    namespace     = var.istio_namespace
  }

  provisioner "local-exec" {
    command = "$HOME/.local/bin/istioctl install --set values.defaultRevision=default --set values.pilot.env.PILOT_ENABLE_AMBIENT=true -y"
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = "$HOME/.local/bin/istioctl uninstall --purge -y || true"
  }
}

# Configure ambient mode if enabled
resource "null_resource" "configure_ambient_mode" {
  count = var.enable_ambient_mode ? 1 : 0
  
  depends_on = [null_resource.istio_base]

  triggers = {
    ambient_mode = var.enable_ambient_mode
    namespaces   = join(",", var.ambient_namespaces)
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Enable ambient mode globally
      kubectl patch configmap/istio -n ${var.istio_namespace} --type merge -p '{"data":{"mesh":"defaultConfig:\n  proxyStatsMatcher:\n    inclusionRegexps:\n    - \".*outlier_detection.*\"\n    - \".*circuit_breakers.*\"\n    - \".*upstream_rq_retry.*\"\n    - \".*_cx_.*\"\n  extensionProviders:\n  - name: otel\n    envoyOtelAls:\n      service: opentelemetry-collector.istio-system.svc.cluster.local\n      port: 4317"}}'
      
      # Install ztunnel DaemonSet for ambient mode
      $HOME/.local/bin/istioctl install --set components.ztunnel.enabled=true --set values.ztunnel.image=docker.io/istio/ztunnel:${var.istio_version} --set values.pilot.env.PILOT_ENABLE_AMBIENT=true -y
    EOT
  }
}

# Label namespaces for ambient mode
resource "kubernetes_labels" "ambient_enabled_namespaces" {
  for_each = var.enable_ambient_mode ? toset(var.ambient_namespaces) : []
  
  depends_on = [null_resource.configure_ambient_mode]
  
  api_version = "v1"
  kind        = "Namespace"
  
  metadata {
    name = each.key
  }
  
  labels = {
    "istio.io/dataplane-mode" = "ambient"
  }
}

# Deploy Istio ingress gateway
resource "null_resource" "istio_ingress_gateway" {
  count = var.enable_ingress_gateway ? 1 : 0
  
  depends_on = [null_resource.istio_base]

  triggers = {
    replicas      = var.ingress_gateway_replicas
    service_type  = var.gateway_service_type
    resources     = jsonencode(var.gateway_resources)
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create ingress gateway
      $HOME/.local/bin/istioctl install --set components.ingressGateways[0].name=istio-ingressgateway \
        --set components.ingressGateways[0].enabled=true \
        --set "components.ingressGateways[0].k8s.service.type=${var.gateway_service_type}" \
        --set "components.ingressGateways[0].k8s.replicas=${var.ingress_gateway_replicas}" \
        --set "components.ingressGateways[0].k8s.resources.requests.cpu=${var.gateway_resources.requests.cpu}" \
        --set "components.ingressGateways[0].k8s.resources.requests.memory=${var.gateway_resources.requests.memory}" \
        --set "components.ingressGateways[0].k8s.resources.limits.cpu=${var.gateway_resources.limits.cpu}" \
        --set "components.ingressGateways[0].k8s.resources.limits.memory=${var.gateway_resources.limits.memory}" \
        -y
    EOT
  }
}

# Deploy Istio egress gateway
resource "null_resource" "istio_egress_gateway" {
  count = var.enable_egress_gateway ? 1 : 0
  
  depends_on = [null_resource.istio_base]

  triggers = {
    service_type = var.gateway_service_type
    resources    = jsonencode(var.gateway_resources)
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create egress gateway
      $HOME/.local/bin/istioctl install --set components.egressGateways[0].name=istio-egressgateway \
        --set components.egressGateways[0].enabled=true \
        --set "components.egressGateways[0].k8s.service.type=${var.gateway_service_type}" \
        --set "components.egressGateways[0].k8s.resources.requests.cpu=${var.gateway_resources.requests.cpu}" \
        --set "components.egressGateways[0].k8s.resources.requests.memory=${var.gateway_resources.requests.memory}" \
        --set "components.egressGateways[0].k8s.resources.limits.cpu=${var.gateway_resources.limits.cpu}" \
        --set "components.egressGateways[0].k8s.resources.limits.memory=${var.gateway_resources.limits.memory}" \
        -y
    EOT
  }
}

# Wait for Istio components to be ready
resource "null_resource" "wait_for_istio" {
  depends_on = [
    null_resource.istio_base,
    null_resource.istio_ingress_gateway,
    null_resource.configure_ambient_mode
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Istio components to be ready..."
      kubectl wait --for=condition=available --timeout=300s deployment/istiod -n ${var.istio_namespace}
      
      if [ "${var.enable_ingress_gateway}" = "true" ]; then
        kubectl wait --for=condition=available --timeout=300s deployment/istio-ingressgateway -n ${var.istio_namespace}
      fi
      
      if [ "${var.enable_egress_gateway}" = "true" ]; then
        kubectl wait --for=condition=available --timeout=300s deployment/istio-egressgateway -n ${var.istio_namespace}
      fi
      
      echo "Istio installation completed successfully!"
    EOT
  }
}

# Install Istio observability addons
resource "null_resource" "install_observability" {
  count = var.enable_kiali || var.enable_jaeger || var.enable_grafana || var.enable_prometheus ? 1 : 0
  
  depends_on = [null_resource.wait_for_istio]

  triggers = {
    enable_kiali      = var.enable_kiali
    enable_jaeger     = var.enable_jaeger
    enable_grafana    = var.enable_grafana
    enable_prometheus = var.enable_prometheus
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ISTIOCTL="$HOME/.local/bin/istioctl"
      
      # Install Prometheus if enabled
      if [ "${var.enable_prometheus}" = "true" ]; then
        echo "Installing Prometheus..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${var.istio_version}/samples/addons/prometheus.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n ${var.observability_namespace}
      fi
      
      # Install Grafana if enabled
      if [ "${var.enable_grafana}" = "true" ]; then
        echo "Installing Grafana..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${var.istio_version}/samples/addons/grafana.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/grafana -n ${var.observability_namespace}
      fi
      
      # Install Jaeger if enabled
      if [ "${var.enable_jaeger}" = "true" ]; then
        echo "Installing Jaeger..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${var.istio_version}/samples/addons/jaeger.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n ${var.observability_namespace}
      fi
      
      # Install Kiali if enabled
      if [ "${var.enable_kiali}" = "true" ]; then
        echo "Installing Kiali..."
        kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${var.istio_version}/samples/addons/kiali.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/kiali -n ${var.observability_namespace}
        
        # Configure Kiali authentication strategy
        if [ "${var.kiali_auth_strategy}" != "anonymous" ]; then
          kubectl patch configmap kiali -n ${var.observability_namespace} --type merge -p '{"data":{"config.yaml":"auth:\n  strategy: ${var.kiali_auth_strategy}\n"}}'
          kubectl rollout restart deployment/kiali -n ${var.observability_namespace}
        fi
      fi
      
      echo "Observability components installed successfully!"
    EOT
  }
}

# Create VirtualService for Kiali if enabled
resource "kubernetes_manifest" "kiali_virtualservice" {
  count = var.enable_kiali && var.enable_ingress_gateway ? 1 : 0
  
  depends_on = [null_resource.install_observability]
  
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "kiali-vs"
      namespace = var.observability_namespace
    }
    spec = {
      hosts = ["kiali.${var.cluster_name}.local"]
      gateways = ["istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "kiali"
                port = {
                  number = 20001
                }
              }
            }
          ]
        }
      ]
    }
  }
}

# Create Gateway for observability tools
resource "kubernetes_manifest" "observability_gateway" {
  count = (var.enable_kiali || var.enable_grafana) && var.enable_ingress_gateway ? 1 : 0
  
  depends_on = [null_resource.install_observability]
  
  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "observability-gateway"
      namespace = var.observability_namespace
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = [
            "kiali.${var.cluster_name}.local",
            "grafana.${var.cluster_name}.local"
          ]
        }
      ]
    }
  }
}

# Output completion status
resource "null_resource" "istio_complete" {
  depends_on = [
    null_resource.wait_for_istio,
    null_resource.install_observability
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Istio ${var.istio_version} installation completed successfully!"
      echo "Components installed:"
      echo "  - Istio control plane (istiod)"
      if [ "${var.enable_ingress_gateway}" = "true" ]; then
        echo "  - Istio ingress gateway"
      fi
      if [ "${var.enable_egress_gateway}" = "true" ]; then
        echo "  - Istio egress gateway"
      fi
      if [ "${var.enable_ambient_mode}" = "true" ]; then
        echo "  - Ambient mode with ztunnel"
      fi
      if [ "${var.enable_prometheus}" = "true" ]; then
        echo "  - Prometheus metrics collection"
      fi
      if [ "${var.enable_grafana}" = "true" ]; then
        echo "  - Grafana dashboards"
      fi
      if [ "${var.enable_jaeger}" = "true" ]; then
        echo "  - Jaeger distributed tracing"
      fi
      if [ "${var.enable_kiali}" = "true" ]; then
        echo "  - Kiali service mesh observability"
      fi
    EOT
  }
}
