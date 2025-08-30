# Istio Terraform Module

This module deploys Istio Service Mesh on an EKS cluster with ambient mesh mode support and comprehensive configuration options.

## Features

- **Complete Istio Installation**: Deploys Istio base, control plane (istiod), CNI, and ambient mode components
- **Intelligent Detection**: Automatically detects existing Istio installations and skips re-installation
- **Idempotent Operations**: Safe to run multiple times without conflicts or duplicated resources
- **Ambient Mesh Mode**: Full support for Istio's ambient mesh architecture with ztunnel
- **Gateway Management**: Optional ingress and egress gateways with customizable configurations
- **Monitoring Integration**: Built-in support for Prometheus monitoring with ServiceMonitors
- **Resource Management**: Configurable resource requests and limits for all components
- **Autoscaling**: HPA support for gateway components
- **Namespace Management**: Automatic ambient mode enablement for specified namespaces

## Architecture

The module deploys the following Istio components:

1. **Istio Base**: Core CRDs and cluster-wide resources
2. **Istiod**: Control plane with discovery and configuration
3. **Istio CNI** (ambient mode): Network plugin for transparent traffic capture
4. **Ztunnel** (ambient mode): Secure tunnel proxy for L4 processing
5. **Ingress Gateway** (optional): Entry point for external traffic
6. **Egress Gateway** (optional): Exit point for outbound traffic

## Usage

### Basic Configuration

```hcl
module "istio" {
  source = "./modules/istio"
  
  cluster_name = "my-eks-cluster"
  
  # Enable ambient mesh mode
  enable_ambient_mode = true
  
  # Enable ingress gateway
  enable_ingress_gateway = true
  ingress_gateway_type   = "LoadBalancer"
  
  common_tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Advanced Configuration

```hcl
module "istio" {
  source = "./modules/istio"
  
  cluster_name     = "my-eks-cluster"
  istio_version    = "1.23.1"
  istio_revision   = "stable"
  mesh_id          = "my-mesh"
  network_name     = "primary-network"
  
  # Ambient mesh configuration
  enable_ambient_mode = true
  ambient_namespaces  = ["default", "app-namespace"]
  
  # Gateway configuration
  enable_ingress_gateway = true
  enable_egress_gateway  = true
  ingress_gateway_type   = "LoadBalancer"
  
  ingress_gateway_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
  }
  
  # Resource configuration
  istiod_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
  
  # Autoscaling
  gateway_autoscaling = {
    enabled      = true
    min_replicas = 2
    max_replicas = 10
    target_cpu   = 70
  }
  
  # Monitoring
  enable_monitoring = true
  
  common_tags = {
    Environment = "production"
    Team        = "platform"
    ManagedBy   = "terraform"
  }
}
```

### Integration with Platform Layer

```hcl
# In your platform layer main.tf
module "istio" {
  count  = var.enable_istio ? 1 : 0
  source = "./modules/istio"
  
  cluster_name           = module.eks.cluster_name
  enable_ambient_mode    = var.istio_ambient_mode
  enable_ingress_gateway = var.istio_ingress_gateway
  enable_monitoring      = var.enable_monitoring
  
  common_tags = local.common_tags
  
  depends_on = [
    module.eks,
    module.eks_addons
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | The name of the EKS cluster | `string` | n/a | yes |
| istio_version | The version of Istio to install | `string` | `"1.23.1"` | no |
| istio_revision | The Istio revision to use | `string` | `"default"` | no |
| mesh_id | The mesh ID for Istio | `string` | `"cluster.local"` | no |
| network_name | The network name for Istio | `string` | `"network1"` | no |
| enable_ambient_mode | Enable Istio ambient mesh mode | `bool` | `true` | no |
| enable_ingress_gateway | Enable Istio ingress gateway | `bool` | `true` | no |
| enable_egress_gateway | Enable Istio egress gateway | `bool` | `false` | no |
| enable_monitoring | Enable Istio monitoring with ServiceMonitor | `bool` | `false` | no |
| ingress_gateway_type | The service type for the ingress gateway | `string` | `"ClusterIP"` | no |
| ingress_gateway_annotations | Annotations for the ingress gateway service | `map(string)` | `{}` | no |
| ambient_namespaces | List of namespaces to enable ambient mode for | `list(string)` | `[]` | no |
| istiod_resources | Resource requests and limits for istiod | `object` | See defaults | no |
| cni_resources | Resource requests and limits for Istio CNI | `object` | See defaults | no |
| ztunnel_resources | Resource requests and limits for ztunnel | `object` | See defaults | no |
| gateway_resources | Resource requests and limits for gateways | `object` | See defaults | no |
| gateway_autoscaling | Autoscaling configuration for gateways | `object` | See defaults | no |
| common_tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| istio_version | The version of Istio deployed |
| istio_revision | The Istio revision deployed |
| istio_namespace | The namespace where Istio is deployed |
| ingress_gateway_enabled | Whether the ingress gateway is enabled |
| egress_gateway_enabled | Whether the egress gateway is enabled |
| ambient_mode_enabled | Whether ambient mode is enabled |
| monitoring_enabled | Whether monitoring is enabled |
| mesh_id | The mesh ID for Istio |
| network_name | The network name for Istio |
| helm_releases | Information about the Istio Helm releases |
| ingress_gateway_service_name | The name of the ingress gateway service |
| egress_gateway_service_name | The name of the egress gateway service |
| ambient_namespaces | List of namespaces with ambient mode enabled |

## Ambient Mesh Mode

This module fully supports Istio's ambient mesh mode, which provides:

- **Transparent Traffic Capture**: No sidecar injection required
- **Simplified Operations**: Easier to manage and troubleshoot
- **Better Resource Efficiency**: Lower overhead compared to sidecar mode
- **Gradual Adoption**: Can be enabled per namespace

### Enabling Ambient Mode

Ambient mode is enabled by default. To enable it for specific namespaces:

```hcl
ambient_namespaces = ["default", "production", "staging"]
```

This automatically adds the `istio.io/dataplane-mode=ambient` label to the specified namespaces.

## Gateway Configuration

### Ingress Gateway

The ingress gateway can be configured with different service types and annotations:

```hcl
enable_ingress_gateway = true
ingress_gateway_type   = "LoadBalancer"

ingress_gateway_annotations = {
  "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
  "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
}
```

### Egress Gateway

Enable egress gateway for controlled outbound traffic:

```hcl
enable_egress_gateway = true
```

## Monitoring

Enable monitoring to create ServiceMonitor resources for Prometheus:

```hcl
enable_monitoring = true
```

This creates ServiceMonitors for:
- Istiod control plane
- Ingress gateway (if enabled)
- Egress gateway (if enabled)
- Ztunnel (if ambient mode is enabled)

## Resource Management

All components support configurable resource requests and limits:

```hcl
istiod_resources = {
  requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}
```

## Autoscaling

Gateway components support Horizontal Pod Autoscaling:

```hcl
gateway_autoscaling = {
  enabled      = true
  min_replicas = 2
  max_replicas = 10
  target_cpu   = 70
}
```

## Intelligent Installation Detection

The module includes intelligent detection capabilities to prevent conflicts with existing Istio installations:

### How It Works

1. **Namespace Check**: Verifies if `istio-system` namespace exists
2. **Deployment Check**: Looks for existing `istiod` deployment
3. **Helm Release Check**: Checks for existing Istio Helm releases
4. **Skip Logic**: Automatically skips installation if Istio components are found

### Benefits

- **Idempotent**: Safe to run multiple times
- **No Conflicts**: Prevents duplicate installations
- **Clean Operations**: Maintains existing configurations
- **Status Reporting**: Shows whether installation was skipped

### Example Output

When Istio already exists:
```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:
istio_already_exists = true
installation_message = "Istio already exists - skipping installation"
```

When installing fresh:
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:
istio_already_exists = false
installation_message = "Installing Istio components"
```

## Prerequisites

- EKS cluster with proper RBAC configuration
- Helm provider configured
- Kubernetes provider configured
- kubectl access to the cluster

## Post-Installation

After deployment, verify the installation:

```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
istioctl verify-install
```

For ambient mode verification:

```bash
kubectl get daemonset -n istio-system istio-cni-node
kubectl get daemonset -n istio-system ztunnel
```

## Version Compatibility

- Terraform: >= 1.0
- Kubernetes: >= 1.26
- Istio: >= 1.20
- Helm: >= 3.8

## Security Considerations

- CNI components run with elevated privileges (required for network management)
- Service accounts use minimal required RBAC permissions
- All components support security contexts and pod security standards
- Network policies can be applied for additional security

## Troubleshooting

### Common Issues

1. **CNI Installation Failures**: Check node permissions and container runtime compatibility
2. **Ztunnel Crashes**: Verify kernel version and eBPF support
3. **Gateway Not Ready**: Check service type compatibility and load balancer provisioning
4. **Ambient Mode Not Working**: Verify namespace labels and CNI installation

### Debug Commands

```bash
# Check Istio installation status
istioctl verify-install

# Check ambient mode status
istioctl x precheck

# View ztunnel logs
kubectl logs -n istio-system -l app=ztunnel

# Check CNI logs
kubectl logs -n istio-system -l k8s-app=istio-cni-node
```

## Contributing

When contributing to this module:

1. Test with multiple Istio versions
2. Verify ambient mode functionality
3. Test gateway configurations
4. Validate monitoring integration
5. Update documentation for new features

## License

This module is provided under the same license as your Terraform configuration.
