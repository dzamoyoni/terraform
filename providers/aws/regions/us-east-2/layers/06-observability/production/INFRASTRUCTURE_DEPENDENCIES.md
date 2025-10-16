# Enterprise Observability Infrastructure Dependencies

This document provides a comprehensive analysis of infrastructure dependencies and integration requirements for the enterprise observability platform. Understanding these relationships is essential for successful deployment, maintenance, and operational excellence.

## Platform Integration Requirements

### Foundation Layer Dependencies (01-foundation)
**Location**: `providers/aws/regions/us-east-2/layers/01-foundation/production/`

My observability stack needs these fundamental networking components:

**Critical Outputs I Use**:
- `vpc_id`: The VPC where all my monitoring components run
- `platform_subnet_ids`: Private subnets where I place my workloads
- `availability_zones`: AZ spread for my high availability setup
- `vpc_cidr_block`: Network range for my security group configurations

**How I Connect**:
```hcl
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/01-foundation/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}
```

### Platform Layer Dependencies (02-platform)
**Location**: `providers/aws/regions/us-east-2/layers/02-platform/production/`

My monitoring depends entirely on the EKS cluster from this layer:

**Essential Outputs I Need**:
- `cluster_name`: The EKS cluster where I deploy everything
- `cluster_endpoint`: API server endpoint for my kubectl operations
- `cluster_certificate_authority_data`: Security certificate for cluster access
- `oidc_provider_arn`: OIDC provider that enables my IRSA setup
- `cluster_oidc_issuer_url`: URL for service account token validation

**My Integration**:
```hcl
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "providers/aws/regions/${var.region}/layers/02-platform/${var.environment}/terraform.tfstate"
    region = var.terraform_state_region
  }
}
```

### Shared Services Layer (05-shared-services)
**Location**: `providers/aws/regions/us-east-2/layers/05-shared-services/production/`

I have optional integrations with shared services:
- Certificate management for secure communication
- DNS services for service discovery
- Shared security policies and compliance requirements

## My EKS Cluster Requirements

### Node Group Architecture I Designed

**My System Node Group** (Critical):
This is where my heavy monitoring workloads run:
- **Taints**: `workload-type=system:NoSchedule` (keeps apps away)
- **Labels**: `workload-type=system` (attracts my monitoring pods)
- **Instance Types**: `m5.large` or bigger (I need the resources)
- **Capacity**: At least 2 nodes (for high availability)
- **Storage**: EBS optimized (for my persistent volumes)

**Application Node Groups** (For my DaemonSets):
Where my lightweight collectors run:
- **Taints**: None (my DaemonSets need to run everywhere)
- **Labels**: Standard application node labels
- **Purpose**: Hosts my Fluent Bit and Node Exporter pods

### Required Add-ons I Need

1. **EBS CSI Driver** (Critical):
   ```bash
   # This must be running for my persistent volumes
   kubectl get daemonset ebs-csi-node -n kube-system
   ```

2. **CoreDNS** (Standard):
   - My services need DNS resolution
   - Default EKS installation works fine

3. **VPC CNI** (Standard):
   - Required for pod-to-pod networking
   - Default EKS setup is sufficient

## My External Dependencies

### AWS Services I Use

#### My S3 Bucket Strategy
I store all long-term data in dedicated S3 buckets:

```bash
# I create these buckets with lifecycle policies
# Pattern: {project_name}-{region}-{purpose}-{environment}

# My logs storage
aws s3 ls s3://${project_name}-${region}-logs-${environment}/

# My traces storage  
aws s3 ls s3://${project_name}-${region}-traces-${environment}/

# My metrics storage
aws s3 ls s3://${project_name}-${region}-metrics-${environment}/

# My audit logs
aws s3 ls s3://${project_name}-${region}-audit-logs-${environment}/
```

**My S3 Configuration Standards**:
- Versioning enabled (for data recovery)
- Server-side encryption (security requirement)
- Lifecycle policies (cost optimization)
- Public access blocked (security baseline)
- Intelligent tiering (automatic cost optimization)

#### My IAM Security Model
**How I Secure AWS Access**:
- OIDC provider configured on my EKS cluster
- Service accounts assume IAM roles (no credentials in pods)
- Least-privilege access (each service gets only what it needs)

## My Kubernetes Foundation

### Storage Classes I Configured
**My Primary Storage Class**:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### My Namespace Strategy
**Monitoring Namespace**:
- I create this namespace for all my observability components
- Isolated from application workloads
- Contains all my monitoring, logging, and tracing services

## How Applications Integrate

### Metrics Collection
**How Apps Expose Metrics to My Stack**:
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: my-app
  annotations:
    prometheus.io/scrape: "true"    # I scrape this service
    prometheus.io/port: "8080"      # On this port
    prometheus.io/path: "/metrics"  # At this endpoint
spec:
  ports:
  - name: metrics
    port: 8080
  selector:
    app: my-app
```

### Log Collection
**My Automatic Log Discovery**:
- My Fluent Bit DaemonSet automatically finds logs in `/var/log/containers/`
- No per-application configuration needed
- I prefer structured logging (JSON format) for better parsing

### Distributed Tracing
**How I Capture Traces**:
- Applications send traces to my Tempo instance via OTLP protocol
- My Istio service mesh generates traces automatically
- I can add manual instrumentation for custom trace data

## My Multi-Tenant Architecture

**Client Environments I Monitor**:
```hcl
local {
  tenant_configs = [
    {
      name      = "est-test-a-prod"
      namespace = "est-test-a-prod"
      labels = {
        tenant      = "est-test-a-prod"
        client      = "est-test-a"
        tier        = "production"
        client_code = "ETA"
      }
    },
    {
      name      = "est-test-b-prod"
      namespace = "est-test-b-prod"
      labels = {
        tenant      = "est-test-b-prod"
        client      = "est-test-b"
        tier        = "production"
        client_code = "ETB"
      }
    },
    {
      name      = "analytics"
      namespace = "analytics"
      labels = {
        tenant      = "analytics"
        client      = "shared"
        tier        = "production"
        client_code = "ANA"
      }
    }
  ]
}
```

Each tenant gets isolated metrics collection while sharing my observability infrastructure efficiently.

## My Network Security

### Security Groups I Rely On
- EKS cluster security group (managed by my platform layer)
- Node group security groups (also platform layer)
- ALB security groups (if I use ingress controllers)

### My Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
  egress:
  - {} # Allow all egress for S3 and external services
```

## My Deployment Strategy

### Order of Operations I Follow
1. **Foundation Layer** → My VPC, subnets, and security groups
2. **Platform Layer** → My EKS cluster, node groups, and OIDC provider
3. **S3 Infrastructure** → My buckets for logs, traces, and metrics
4. **EBS CSI Driver** → My storage class configuration
5. **Observability Layer** → My monitoring stack deployment

### How I Validate Dependencies
```bash
# 1. Check my cluster access
kubectl cluster-info

# 2. Verify my node groups are ready
kubectl get nodes --show-labels

# 3. Confirm my storage classes
kubectl get storageclass

# 4. Test my S3 bucket access
aws s3 ls s3://${project_name}-${region}-logs-${environment}/

# 5. Run my comprehensive validation
./validate_config.sh
```

## Troubleshooting Common Issues

### Storage Problems I've Solved
**Symptoms**: My PVCs get stuck in Pending state
**Root Cause**: Storage class misconfiguration or missing EBS CSI driver
**My Solution**: 
```bash
# Check my storage classes
kubectl get storageclass

# Verify my EBS CSI driver is running
kubectl get daemonset ebs-csi-node -n kube-system

# Set my default storage class
kubectl patch storageclass gp2-csi -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Node Scheduling Issues I've Fixed
**Symptoms**: My monitoring pods stick in Pending state
**Root Cause**: Missing system nodes or incorrect taints/tolerations
**My Resolution**:
```bash
# Check my node labels and taints
kubectl describe nodes

# Verify I have system nodes available
kubectl get nodes -l workload-type=system
```

### S3 Access Problems I've Resolved
**Symptoms**: My Tempo/Loki crashes with access denied errors
**Root Cause**: Missing S3 buckets or incorrect IRSA permissions
**How I Fix It**:
```bash
# Verify my bucket exists
aws s3 ls s3://${bucket_name}/

# Check my service account IRSA annotations
kubectl get sa tempo -n monitoring -o yaml

# Test my IRSA role assumption
aws sts get-caller-identity
```

## My Health Monitoring Approach

I use my validation script to check all dependencies regularly:

```bash
./validate_config.sh
```

**What My Script Validates**:
- ✅ My cluster connectivity
- ✅ My required node groups
- ✅ My storage class configuration
- ✅ My S3 bucket accessibility
- ✅ My IRSA permissions
- ✅ My PVC binding status
- ✅ My component health status

## The Bottom Line

My observability stack is tightly integrated with my infrastructure layers. When something goes wrong, I start by checking these dependencies in order:

1. **Cluster Access** - Can I reach my EKS cluster?
2. **Node Groups** - Are my system nodes available?
3. **Storage** - Are my storage classes working?
4. **S3 Access** - Can my services reach their S3 buckets?
5. **Network** - Is traffic flowing between components?

This dependency map has saved me hours of troubleshooting by providing a systematic approach to diagnosing issues.