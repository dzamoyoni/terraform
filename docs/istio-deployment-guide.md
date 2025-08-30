# Istio Service Mesh Deployment Guide

## Overview

This guide covers the deployment of Istio Service Mesh in your Terraform-managed EKS cluster using the integrated Istio module. The implementation features Istio's ambient mesh architecture, which provides service mesh capabilities without requiring sidecar injection.

**Key Feature**: The module includes intelligent detection that automatically identifies existing Istio installations and skips re-installation, making it completely safe to run multiple times without conflicts.

## Architecture

The Istio module deploys a complete service mesh stack including:

- **Istio Base**: Core CRDs and cluster-wide resources
- **Istiod**: Control plane with discovery and configuration management
- **Istio CNI**: Network plugin for transparent traffic capture (ambient mode)
- **Ztunnel**: Secure tunnel proxy for L4 processing (ambient mode)
- **Ingress Gateway**: Entry point for external traffic (optional)
- **Egress Gateway**: Exit point for outbound traffic (optional)

## Prerequisites

Before deploying Istio, ensure you have:

1. **EKS Cluster**: Running with the platform layer deployed
2. **AWS Load Balancer Controller**: Deployed for ingress functionality
3. **Sufficient Resources**: Node capacity for mesh components
4. **kubectl Access**: Configured for your cluster
5. **istioctl**: Istio CLI tool installed (optional, for verification)

### Installing istioctl

```bash
# Download istioctl
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-1.23.1/bin:$PATH
```

## Deployment Steps

### Step 1: Configure Variables

Update your `terraform.tfvars` file in the platform layer:

```hcl
# Basic configuration (minimal deployment)
enable_istio = true

# Advanced configuration (recommended for production)
enable_istio               = true
istio_version             = "1.23.1"
istio_ambient_mode        = true
istio_ingress_gateway     = true
istio_egress_gateway      = false
istio_ingress_gateway_type = "LoadBalancer"
istio_monitoring          = false
istio_ambient_namespaces  = ["default", "production"]
```

### Step 2: Plan and Apply

```bash
cd /home/dennis.juma/terraform/regions/us-east-1/layers/02-platform/production

# Initialize and plan
terraform plan -var-file="terraform.tfvars"

# Apply the changes
terraform apply -var-file="terraform.tfvars"
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n istio-system

# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# istio-cni-node-xxxxx                   1/1     Running   0          5m
# istio-cni-node-yyyyy                   1/1     Running   0          5m
# istiod-xxx-yyy                         1/1     Running   0          5m
# ztunnel-xxxxx                          1/1     Running   0          5m
# ztunnel-yyyyy                          1/1     Running   0          5m

# Check services
kubectl get svc -n istio-system

# Verify installation (if istioctl is available)
istioctl verify-install
```

## Configuration Options

### Ambient Mode vs Sidecar Mode

**Ambient Mode (Recommended)**:
```hcl
istio_ambient_mode = true
ambient_namespaces = ["default", "production", "staging"]
```

**Benefits**:
- No sidecar injection required
- Transparent traffic capture
- Lower resource overhead
- Easier application onboarding

**Sidecar Mode** (Legacy):
```hcl
istio_ambient_mode = false
```

### Gateway Configuration

**LoadBalancer Ingress Gateway**:
```hcl
istio_ingress_gateway      = true
istio_ingress_gateway_type = "LoadBalancer"
```

**ClusterIP with ALB Integration**:
```hcl
istio_ingress_gateway      = true
istio_ingress_gateway_type = "ClusterIP"
```

**Egress Gateway for Outbound Traffic**:
```hcl
istio_egress_gateway = true
```

### Resource Configuration

The module includes production-ready resource settings:

```hcl
# Istiod control plane
istiod_resources = {
  requests = { cpu = "200m", memory = "256Mi" }
  limits   = { cpu = "1000m", memory = "1Gi" }
}

# Gateway resources with autoscaling
gateway_autoscaling = {
  enabled      = true
  min_replicas = 2
  max_replicas = 10
  target_cpu   = 70
}
```

### Monitoring Integration

Enable Prometheus monitoring:

```hcl
istio_monitoring = true
```

This creates ServiceMonitor resources for:
- Istiod control plane
- Ingress/Egress gateways
- Ztunnel (ambient mode)

## Application Onboarding

### Automatic Ambient Mode (Recommended)

Applications in configured namespaces automatically join the mesh:

```hcl
ambient_namespaces = ["production", "staging"]
```

### Manual Namespace Configuration

Enable ambient mode for additional namespaces:

```bash
kubectl label namespace my-app istio.io/dataplane-mode=ambient
```

### Sample Application Deployment

Deploy a test application to verify mesh functionality:

```yaml
# test-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-app
  labels:
    istio.io/dataplane-mode: ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: test-app
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
```

Apply the test application:

```bash
kubectl apply -f test-app.yaml
```

## Traffic Management

### Gateway Configuration

Create an Istio Gateway for external traffic:

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: test-gateway
  namespace: test-app
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - test.example.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: test-vs
  namespace: test-app
spec:
  hosts:
  - test.example.com
  gateways:
  - test-gateway
  http:
  - route:
    - destination:
        host: test-app
        port:
          number: 80
```

### Service-to-Service Communication

Istio automatically handles service-to-service communication in ambient mode:

```bash
# Test connectivity from within the mesh
kubectl exec -n test-app deployment/test-app -- curl http://another-service.another-namespace.svc.cluster.local
```

## Security Policies

### Authorization Policies

Control access between services:

```yaml
# authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: test-app-policy
  namespace: test-app
spec:
  selector:
    matchLabels:
      app: test-app
  rules:
  - from:
    - source:
        namespaces: ["frontend", "api-gateway"]
  - to:
    - operation:
        methods: ["GET", "POST"]
```

### Network Policies

Layer additional network security:

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-app-netpol
  namespace: test-app
spec:
  podSelector:
    matchLabels:
      app: test-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
```

## Monitoring and Observability

### Accessing Metrics

If monitoring is enabled, metrics are available via ServiceMonitors:

```bash
# Check ServiceMonitors
kubectl get servicemonitor -n istio-system

# View metrics in Prometheus (if deployed)
# - istiod metrics: http://prometheus:9090/metrics?q=pilot_
# - proxy metrics: http://prometheus:9090/metrics?q=envoy_
```

### Log Collection

Ztunnel and Istiod logs provide troubleshooting information:

```bash
# View ztunnel logs (ambient mode)
kubectl logs -n istio-system -l app=ztunnel

# View istiod logs
kubectl logs -n istio-system -l app=istiod

# View CNI logs
kubectl logs -n istio-system -l k8s-app=istio-cni-node
```

## Troubleshooting

### Common Issues

**1. CNI Installation Failures**

Check node permissions and container runtime compatibility:

```bash
kubectl describe daemonset -n istio-system istio-cni-node
kubectl logs -n istio-system -l k8s-app=istio-cni-node
```

**2. Ztunnel Not Starting**

Verify eBPF support and kernel version:

```bash
kubectl describe daemonset -n istio-system ztunnel
kubectl get nodes -o wide  # Check kernel versions
```

**3. Traffic Not Flowing Through Mesh**

Verify namespace labels and ztunnel health:

```bash
kubectl get namespace -l istio.io/dataplane-mode=ambient
kubectl get pods -n istio-system -l app=ztunnel
```

### Debug Commands

```bash
# Check Istio configuration
istioctl proxy-config cluster <pod-name> -n <namespace>

# Verify ambient mode status
istioctl x precheck

# Check proxy status
istioctl proxy-status

# Analyze configuration
istioctl analyze -A
```

## Migration Strategies

### From Existing Service Mesh

If migrating from another service mesh or plain Kubernetes:

1. **Gradual Rollout**: Enable ambient mode for one namespace at a time
2. **Traffic Splitting**: Use VirtualServices to gradually shift traffic
3. **Policy Migration**: Migrate existing policies to Istio resources
4. **Monitoring**: Compare metrics before and after migration

### From Sidecar to Ambient Mode

If upgrading from sidecar Istio to ambient mode:

1. **Deploy Ambient Components**: Add CNI and ztunnel
2. **Namespace Migration**: Switch namespaces one by one
3. **Remove Sidecars**: Remove injection labels and restart pods
4. **Cleanup**: Remove unused sidecar configurations

## Best Practices

### Security

1. **Enable mTLS**: Istio automatically enables mTLS in ambient mode
2. **Authorization Policies**: Implement least-privilege access
3. **Network Policies**: Layer additional security controls
4. **Regular Updates**: Keep Istio version current

### Performance

1. **Resource Limits**: Set appropriate CPU/memory limits
2. **Node Selection**: Consider dedicating nodes for mesh components
3. **Monitoring**: Watch for performance impacts on applications
4. **Scaling**: Configure HPA for gateway components

### Operations

1. **Gradual Rollout**: Enable mesh features incrementally
2. **Monitoring**: Implement comprehensive observability
3. **Backup**: Backup configurations before changes
4. **Testing**: Test traffic flows after deployment

## Terraform Integration

### SSM Parameters

The module stores Istio information in SSM for other layers:

- `/terraform/production/platform/istio_enabled`
- `/terraform/production/platform/istio_version`
- `/terraform/production/platform/istio_namespace`
- `/terraform/production/platform/istio_ingress_gateway_service`

### Module Outputs

Access Istio information in other modules:

```hcl
data "aws_ssm_parameter" "istio_enabled" {
  name = "/terraform/${var.environment}/platform/istio_enabled"
}

data "aws_ssm_parameter" "istio_version" {
  count = data.aws_ssm_parameter.istio_enabled.value == "true" ? 1 : 0
  name  = "/terraform/${var.environment}/platform/istio_version"
}
```

## Support and Resources

### Official Documentation

- [Istio Documentation](https://istio.io/latest/docs/)
- [Ambient Mesh Guide](https://istio.io/latest/docs/ambient/)
- [Security Best Practices](https://istio.io/latest/docs/concepts/security/)

### Troubleshooting Resources

- [Istio Troubleshooting Guide](https://istio.io/latest/docs/ops/common-problems/)
- [Performance Tuning](https://istio.io/latest/docs/ops/best-practices/performance/)
- [Community Support](https://istio.io/latest/get-involved/)

This comprehensive guide should help you successfully deploy and manage Istio in your environment. The integrated Terraform module provides a production-ready foundation that can be customized based on your specific requirements.
