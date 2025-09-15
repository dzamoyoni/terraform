# 🕸️ CPTWN Istio Service Mesh Deployment Guide

## 📋 Overview

This guide walks you through deploying Istio service mesh for the CPTWN Multi-Client EKS environment with:
- ✅ **Keep observability in Layer 03.5** (existing production-grade stack)
- ✅ **Istio in Layer 06 (Shared Services)** for service mesh functionality
- ✅ **Ambient mode** for optimal performance
- ✅ **ClusterIP ingress** for internal routing
- ✅ **Multi-client isolation** with proper namespace management

## 🎯 Architecture Decision Summary

After analyzing your existing observability setup, here's the **recommended approach**:

### ✅ **KEEP** Observability in Layer 03.5
**Why this is RIGHT:**
- 🏆 **Production-grade reliability**: Your Tempo + S3, Prometheus remote write, IRSA setup
- 🏢 **Multi-tenant isolation**: Proper tenant data partitioning already implemented  
- 🔧 **Operational excellence**: Centralized observability with distributed collection
- 📈 **Scalability**: Independent scaling and management
- 🔒 **Security**: Tenant-based data partitioning

### ✅ **ADD** Istio to Shared Services Layer
**Integration approach:**
- 🔗 **Lightweight telemetry config**: Istio → existing Prometheus/Tempo/Fluent Bit
- 🚀 **Service mesh features**: Traffic management, security, observability
- 🌊 **Ambient mode**: Better performance for multi-client workloads
- 🔧 **Terraform managed**: Consistent with your infrastructure approach

## 🚀 Deployment Steps

### Step 1: Prepare Terraform Configuration

Copy the example configuration:

```bash
cd /home/dennis.juma/terraform/providers/aws/regions/af-south-1/layers/06-shared-services/production
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Customize Configuration

Edit `terraform.tfvars` for your environment:

```hcl
# =============================================================================
# ISTIO SERVICE MESH CONFIGURATION
# =============================================================================

# Enable Istio deployment
enable_istio_service_mesh = true

# Istio version and mesh configuration
istio_version        = "1.20.2"
istio_mesh_id       = "cptwn-mesh-af-south-1"
istio_cluster_network = "af-south-1-network"

# Enable ambient mode (recommended for production)
enable_istio_ambient_mode = true

# Configure your client namespaces
istio_application_namespaces = {
  # Your existing clients
  "mtn-ghana-prod" = {
    dataplane_mode = "ambient"
    client         = "mtn-ghana"
    tenant         = "mtn-ghana-prod"
  }
  "orange-madagascar-prod" = {
    dataplane_mode = "ambient"
    client         = "orange-madagascar"
    tenant         = "orange-madagascar-prod"
  }
  # Platform services (if you need advanced policies)
  "cptwn-platform" = {
    dataplane_mode = "sidecar"
    client         = "cptwn"
    tenant         = "platform"
  }
}

# Integration with your existing observability (Layer 03.5)
enable_istio_distributed_tracing = true
enable_istio_access_logging     = true
istio_tracing_sampling_rate     = 0.01  # 1% for production
```

### Step 3: Plan and Apply

```bash
# Initialize Terraform (if needed)
terraform init

# Plan the deployment
terraform plan

# Apply (deploy Istio)
terraform apply
```

### Step 4: Verify Deployment

```bash
# Check Istio components
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress

# Verify ambient mode
kubectl get daemonset -n istio-system ztunnel
kubectl get pods -n istio-system -l app=ztunnel

# Check namespace configuration
kubectl get namespace -l istio.io/dataplane-mode=ambient
kubectl get namespace -l istio-injection=enabled
```

Expected output:
```
NAME           STATUS   AGE    LABELS
istio-system   Active   5m     istio-injection=disabled
istio-ingress  Active   5m     istio-injection=enabled
mtn-ghana-prod Active   5m     istio.io/dataplane-mode=ambient
orange-madagascar-prod Active 5m istio.io/dataplane-mode=ambient
cptwn-platform Active   5m     istio-injection=enabled
```

### Step 5: Test Integration with Observability

```bash
# Check if Istio metrics are being scraped by Prometheus
kubectl port-forward -n istio-system svc/istiod 15014:15014
curl http://localhost:15014/stats/prometheus

# Check ServiceMonitor is created (for Prometheus integration)
kubectl get servicemonitor -n istio-system

# Verify traces are being sent to Tempo
kubectl logs -n istio-system -l app=istiod | grep -i tempo
```

## 🔧 Managing Different Client Namespaces

### Adding a New Client

1. **Update terraform.tfvars**:
```hcl
istio_application_namespaces = {
  # ... existing clients ...
  
  # New client
  "new-client-prod" = {
    dataplane_mode = "ambient"    # or "sidecar" if advanced policies needed
    client         = "new-client"
    tenant         = "new-client-prod"
  }
}
```

2. **Apply changes**:
```bash
terraform plan
terraform apply
```

3. **Deploy applications to the new namespace**:
```bash
kubectl apply -f your-app-manifests.yaml -n new-client-prod
```

### Switching Between Ambient and Sidecar Mode

For a namespace requiring advanced traffic policies:

```hcl
"special-client" = {
  dataplane_mode = "sidecar"    # Full Istio features
  client         = "special-client"
  tenant         = "special-client-prod"
}
```

## 📊 Observability Integration Details

### Metrics Flow
```
Istio → Prometheus (Layer 03.5) → Grafana (Layer 03.5) → Your Central Grafana
```

### Tracing Flow  
```
Istio → Tempo (Layer 03.5) → S3 → Your Grafana
```

### Logging Flow
```
Istio Access Logs → Fluent Bit (Layer 03.5) → S3
```

### Dashboards Available
- **Istio Control Plane**: Control plane health and performance
- **Istio Service Mesh**: Service-to-service communication metrics
- **Istio Workload**: Individual workload performance
- **Multi-Tenant**: Per-client metrics and isolation

## 🚦 Traffic Management Examples

### Basic Gateway Configuration

Create a Gateway for your clients:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: mtn-ghana-gateway
  namespace: mtn-ghana-prod
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "mtn-ghana.internal.cptwn.com"
```

### VirtualService for Traffic Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mtn-ghana-api
  namespace: mtn-ghana-prod
spec:
  hosts:
  - "mtn-ghana.internal.cptwn.com"
  gateways:
  - mtn-ghana-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: mtn-ghana-api-service
        port:
          number: 8080
```

## 🔒 Security Configuration

### Automatic mTLS

Istio automatically enables mTLS between services. Verify with:

```bash
# Check mTLS status
kubectl get peerauthentication -A
kubectl get destinationrules -A
```

### Authorization Policies

For client isolation:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: mtn-ghana-access-control
  namespace: mtn-ghana-prod
spec:
  rules:
  - from:
    - source:
        namespaces: ["mtn-ghana-prod", "cptwn-platform"]
  - to:
    - operation:
        methods: ["GET", "POST"]
```

## 🔍 Monitoring and Alerting

### Key Metrics to Monitor

1. **Control Plane Health**:
   - `pilot_k8s_cfg_events_total`
   - `process_cpu_seconds_total{job="istiod"}`

2. **Data Plane Performance**:
   - `istio_request_duration_milliseconds`
   - `istio_request_total`
   - `istio_tcp_connections_opened_total`

3. **Multi-Client Metrics**:
   - Request rates per client namespace
   - Error rates by client
   - Resource usage per tenant

### Sample AlertManager Rules

```yaml
groups:
- name: istio-multi-client
  rules:
  - alert: IstioHighErrorRateForClient
    expr: >
      (
        sum(rate(istio_request_total{reporter="destination",response_code!~"2.."}[5m])) by (destination_namespace)
        /
        sum(rate(istio_request_total{reporter="destination"}[5m])) by (destination_namespace)
      ) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected for client {{ $labels.destination_namespace }}"
```

## 🔄 Upgrade Process

### Minor Version Upgrade
```bash
# Update version in terraform.tfvars
istio_version = "1.20.3"

# Apply
terraform plan
terraform apply
```

### Major Version Upgrade
1. **Test in staging first**
2. **Review breaking changes**
3. **Plan maintenance window** 
4. **Backup configuration**
5. **Apply upgrade**

## 🐛 Troubleshooting

### Common Issues

1. **Ambient Mode Not Working**
   ```bash
   # Check CNI installation
   kubectl get pods -n istio-system -l k8s-app=istio-cni-node
   
   # Check ztunnel logs
   kubectl logs -n istio-system -l app=ztunnel
   ```

2. **Telemetry Not Flowing**
   ```bash
   # Check Telemetry configuration
   kubectl get telemetry -n istio-system
   
   # Verify endpoints
   kubectl get svc -n istio-system tempo
   ```

3. **ClusterIP Gateway Not Accessible**
   ```bash
   # Check service
   kubectl get svc -n istio-ingress istio-ingressgateway
   
   # Test connectivity from pod
   kubectl run test-pod --image=curlimages/curl -- sleep 3600
   kubectl exec -it test-pod -- curl istio-ingressgateway.istio-ingress:80
   ```

## ✅ Best Practices for Multi-Client Setup

1. **Namespace Isolation**: Use ambient mode for most clients, sidecar only when needed
2. **Resource Limits**: Set appropriate limits per client based on SLA
3. **Monitoring**: Monitor per-client metrics and costs
4. **Security**: Implement authorization policies between clients
5. **Upgrades**: Test with one client first, then roll out gradually

## 🎯 Next Steps

1. **Deploy test applications** to verify service mesh functionality
2. **Configure Grafana dashboards** to visualize multi-client metrics
3. **Set up alerting rules** for each client's SLA requirements
4. **Implement traffic policies** for advanced routing needs
5. **Plan client onboarding process** for new tenants

---

**Note**: This deployment maintains your excellent observability setup in Layer 03.5 while adding powerful service mesh capabilities in the shared services layer. The integration is designed to be lightweight and production-ready.
