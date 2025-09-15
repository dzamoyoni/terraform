# Istio Service Mesh Terraform Module

A production-grade Terraform module for deploying Istio service mesh with ambient mode support, ClusterIP ingress gateway, and seamless integration with existing observability infrastructure.

## 🎯 Key Features

- **🚀 Production-Ready**: High availability, autoscaling, and resource optimization
- **🌊 Ambient Mode**: Latest Istio ambient mode with ztunnel for improved performance
- **🔒 ClusterIP Ingress**: Internal routing with ClusterIP service type
- **📊 Observability Integration**: Seamless integration with existing monitoring stack
- **🏢 Multi-Tenant**: Support for multiple client namespaces with different dataplane modes
- **⚡ Performance Optimized**: Minimal overhead with smart resource allocation

## 📋 Prerequisites

- **Kubernetes Cluster**: EKS 1.24+ or compatible Kubernetes cluster
- **Terraform**: Version 1.5 or higher
- **Existing Observability Stack**: Prometheus, Tempo, and Fluent Bit (recommended)
- **Network Policies**: CNI that supports NetworkPolicies (optional but recommended)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Service Mesh                      │
├─────────────────────────────────────────────────────────────┤
│  istio-system namespace:                                    │
│  ├── istiod (Control Plane)                               │
│  ├── istio-cni (Ambient Mode CNI)                         │
│  └── ztunnel (Ambient Mode Data Plane)                    │
├─────────────────────────────────────────────────────────────┤
│  istio-ingress namespace:                                   │
│  └── istio-ingressgateway (ClusterIP)                     │
├─────────────────────────────────────────────────────────────┤
│  Application Namespaces:                                   │
│  ├── mtn-ghana-prod (Ambient Mode)                        │
│  ├── orange-madagascar-prod (Ambient Mode)                │
│  └── cptwn-platform (Sidecar Mode)                        │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Basic Usage

```hcl
module "istio_service_mesh" {
  source = "./modules/istio-service-mesh"
  
  # Core configuration
  cluster_name = "my-eks-cluster"
  region       = "us-west-2"
  
  # Enable ambient mode
  enable_ambient_mode = true
  
  # Configure application namespaces
  application_namespaces = {
    "my-app-prod" = {
      dataplane_mode = "ambient"
      client         = "my-company"
      tenant         = "production"
    }
  }
}
```

### 2. Production Configuration

```hcl
module "istio_service_mesh" {
  source = "./modules/istio-service-mesh"
  
  # Core configuration
  project_name = "my-project"
  environment  = "production"
  region       = "us-west-2"
  cluster_name = "my-production-cluster"
  
  # Istio configuration
  istio_version   = "1.20.2"
  mesh_id        = "production-mesh"
  cluster_network = "us-west-2-network"
  
  # Enable ambient mode for better performance
  enable_ambient_mode = true
  
  # Production ingress gateway
  enable_ingress_gateway = true
  ingress_gateway_replicas = 3
  ingress_gateway_resources = {
    requests = {
      cpu    = "500m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "2000m"
      memory = "2Gi"
    }
  }
  
  # Production istiod configuration
  istiod_resources = {
    requests = {
      cpu    = "1000m"
      memory = "4Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "8Gi"
    }
  }
  
  # Multi-tenant namespace configuration
  application_namespaces = {
    "client-a-prod" = {
      dataplane_mode = "ambient"
      client         = "client-a"
      tenant         = "production"
    }
    "client-b-prod" = {
      dataplane_mode = "ambient"
      client         = "client-b"
      tenant         = "production"
    }
    "platform-services" = {
      dataplane_mode = "sidecar"
      client         = "platform"
      tenant         = "system"
    }
  }
  
  # Observability integration
  enable_distributed_tracing = true
  enable_access_logging     = true
  tracing_sampling_rate     = 0.01  # 1% for production
  
  # Monitoring
  enable_service_monitor  = true
  enable_prometheus_rules = true
}
```

## 🔧 Configuration Options

### Core Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | `string` | **required** | Name of the Kubernetes cluster |
| `region` | `string` | **required** | AWS region |
| `istio_version` | `string` | `"1.20.2"` | Istio version to deploy |
| `mesh_id` | `string` | `"mesh1"` | Unique mesh identifier |

### Ambient Mode Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_ambient_mode` | `bool` | `true` | Enable Istio ambient mode |
| `cni_resources` | `object` | See defaults | Resource limits for CNI pods |
| `ztunnel_resources` | `object` | See defaults | Resource limits for ztunnel pods |

### Ingress Gateway Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_ingress_gateway` | `bool` | `true` | Deploy ingress gateway |
| `ingress_gateway_replicas` | `number` | `3` | Number of gateway replicas |
| `ingress_gateway_resources` | `object` | See defaults | Resource configuration |

### Application Namespaces

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `application_namespaces` | `map(object)` | `{}` | Namespace configuration with dataplane modes |

Example namespace configuration:

```hcl
application_namespaces = {
  "production-app" = {
    dataplane_mode = "ambient"    # or "sidecar"
    client         = "my-client"
    tenant         = "production"
  }
}
```

### Observability Integration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_distributed_tracing` | `bool` | `true` | Enable tracing with existing Tempo |
| `enable_access_logging` | `bool` | `true` | Enable access logs with existing Fluent Bit |
| `tracing_sampling_rate` | `number` | `0.01` | Tracing sampling rate (0.0-1.0) |

## 🎛️ Dataplane Modes

### Ambient Mode (Recommended)

- **Performance**: Lower latency and resource overhead
- **Simplicity**: No sidecar injection required
- **Use Case**: Most production workloads

```hcl
"my-namespace" = {
  dataplane_mode = "ambient"
  client         = "my-client"
}
```

### Sidecar Mode

- **Features**: Full Istio feature set including advanced traffic policies
- **Control**: Fine-grained per-workload configuration
- **Use Case**: Services requiring advanced traffic management

```hcl
"my-namespace" = {
  dataplane_mode = "sidecar"
  client         = "my-client"
}
```

## 📊 Observability Integration

This module is designed to integrate with your existing observability stack (Layer 03.5). It automatically configures:

### Metrics Collection
- Istio metrics exported to existing Prometheus
- Custom dashboards for Grafana
- ServiceMonitor CRDs for automatic discovery

### Distributed Tracing
- Integration with existing Tempo instance
- Automatic trace correlation
- Configurable sampling rates

### Log Collection
- Access logs sent to existing Fluent Bit
- Structured logging with correlation IDs
- Multi-tenant log separation

### Alerting
- PrometheusRules for Istio-specific alerts
- Integration with existing AlertManager
- Critical service mesh health monitoring

## 🔍 Monitoring and Troubleshooting

### Health Checks

Check Istio installation status:

```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-ingress
```

### Ambient Mode Verification

Verify ztunnel is running on all nodes:

```bash
kubectl get daemonset -n istio-system ztunnel
kubectl get pods -n istio-system -l app=ztunnel
```

### Namespace Configuration

Check namespace labels:

```bash
kubectl get namespace -l istio.io/dataplane-mode=ambient
kubectl get namespace -l istio-injection=enabled
```

### Common Issues

1. **CNI Installation Issues**: Check node permissions and security groups
2. **Ambient Mode Not Working**: Verify CNI plugin installation
3. **Ingress Gateway Not Accessible**: Check ClusterIP service and networking
4. **Telemetry Not Working**: Verify observability stack endpoints

## 🔄 Upgrade Guide

### Minor Version Upgrades

1. Update the `istio_version` variable
2. Apply Terraform changes
3. Verify all components are healthy

```bash
terraform plan -var="istio_version=1.20.3"
terraform apply
```

### Major Version Upgrades

1. Review Istio upgrade documentation
2. Test in staging environment first
3. Plan for potential downtime
4. Update configurations as needed

## 🔒 Security Considerations

- **Trust Domain**: Configure appropriate trust domain for your environment
- **Network Policies**: Implement network policies for additional security
- **mTLS**: Automatic mTLS is enabled by default
- **RBAC**: Istio RBAC policies should be configured per namespace
- **Image Security**: Use verified Istio images from official repositories

## 📈 Performance Tuning

### Production Recommendations

1. **Resource Limits**: Set appropriate resource limits based on traffic patterns
2. **Autoscaling**: Enable HPA for istiod and ingress gateway
3. **Node Affinity**: Use node affinity for critical components
4. **Monitoring**: Monitor resource usage and adjust accordingly

### Scaling Guidelines

| Component | Small Cluster | Medium Cluster | Large Cluster |
|-----------|---------------|----------------|---------------|
| Istiod Replicas | 2 | 3 | 5 |
| Ingress Gateway | 2 | 3 | 5 |
| Memory per Istiod | 2Gi | 4Gi | 8Gi |
| CPU per Istiod | 500m | 1000m | 2000m |

## 🤝 Contributing

1. Follow Terraform best practices
2. Update documentation for new features
3. Test changes thoroughly
4. Submit pull requests with clear descriptions

## 📄 License

This module is part of the CPTWN Multi-Client EKS project and follows the project's licensing terms.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review Istio official documentation
3. Contact the platform team
4. Create GitHub issues for bugs

---

**Note**: This module is optimized for production use with the CPTWN Multi-Client EKS architecture and integrates seamlessly with the existing observability stack (Layer 03.5).
