# Infrastructure Deployment & Scaling Guide

## Quick Start

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- kubectl for Kubernetes management
- Git for version control

### Initial Setup
```bash
# Clone and navigate to repository
git clone <repository-url>
cd terraform

# Set up environment variables
export AWS_REGION="af-south-1"
export PROJECT_NAME="cptwn-eks-01"
export ENVIRONMENT="production"
```

## Deployment Process

### Phase 1: Backend Setup
Create the Terraform state backend (one-time setup per region):

```bash
cd providers/aws/regions/af-south-1/backend-setup
terraform init
terraform plan
terraform apply
```

**What this creates:**
- S3 bucket for Terraform state storage
- DynamoDB table for state locking
- IAM policies and encryption

### Phase 2: Foundation Layer
Deploy the network and security foundation:

```bash
cd ../layers/01-foundation/production
terraform init -backend-config=../../../../../shared/backend-configs/af-south-foundation-production.hcl
terraform plan -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates:**
- VPC with public/private subnets
- NAT gateways for internet access
- Security groups and NACLs
- VPN connections (if enabled)
- Client-specific network isolation

### Phase 3: Platform Layer
Deploy the Kubernetes platform:

```bash
cd ../02-platform/production
terraform init -backend-config=../../../../../shared/backend-configs/af-south-platform-production.hcl
terraform plan -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates:**
- EKS cluster with managed node groups
- IRSA (IAM Roles for Service Accounts)
- Cluster autoscaler configuration
- Network security policies

### Phase 4: Observability Layer
Deploy monitoring and logging:

```bash
cd ../03.5-observability/production
terraform init -backend-config=../../../../../shared/backend-configs/af-south-observability-production.hcl
terraform plan -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates:**
- Prometheus for metrics collection
- Grafana for visualization
- Jaeger/Tempo for distributed tracing
- FluentBit for log aggregation
- S3 buckets for long-term storage

### Phase 5: Database Layer
Deploy database infrastructure:

```bash
cd ../03-databases/production
terraform init -backend-config=../../../../../shared/backend-configs/af-south-databases-production.hcl
terraform plan -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates:**
- PostgreSQL instances on EC2
- Automated backup systems
- Database security groups
- Client-specific database isolation

### Phase 6: Shared Services
Deploy cluster-wide services:

```bash
cd ../06-shared-services/production
terraform init -backend-config=../../../../../shared/backend-configs/af-south-shared-services-production.hcl
terraform plan -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates:**
- AWS Load Balancer Controller
- External DNS
- Metrics Server
- Cluster Autoscaler

## Multi-Region Deployment

### Deploying to US-East-1
After AF-South-1 is stable, deploy to US-East-1:

```bash
export AWS_REGION="us-east-1"
export PROJECT_NAME="us-east-1-cluster-01"

# Follow the same phases 1-6, but use us-east-1 paths:
cd providers/aws/regions/us-east-1/backend-setup
# ... repeat deployment phases
```

### Cross-Region Considerations
- **CIDR Blocks**: Ensure non-overlapping IP ranges
  - AF-South-1: `172.16.0.0/16`
  - US-East-1: `172.20.0.0/16`
- **DNS**: Configure Route 53 for global load balancing
- **Data Replication**: Set up cross-region database replication
- **Backup Strategy**: Implement cross-region backup storage

## Scaling Strategies

### Horizontal Scaling

#### Adding New Clients
1. **Update Foundation Layer**:
```hcl
# Add new client in foundation layer
module "client_subnets_new_client" {
  source = "../../../../../modules/client-subnets"
  
  client_name       = "new-client-prod"
  client_cidr_block = "172.16.20.0/22"  # Next available range
  # ... other configuration
}
```

2. **Update Platform Layer**:
```hcl
# Add node group for new client
node_groups = {
  new_client_prod = {
    instance_types = ["m5.large"]
    min_size      = 1
    max_size      = 10
    desired_size  = 2
  }
}
```

#### Adding New Regions
1. **Copy region structure**:
```bash
cp -r providers/aws/regions/af-south-1 providers/aws/regions/eu-west-1
```

2. **Update configuration**:
- Change CIDR blocks to avoid conflicts
- Update region-specific variables
- Modify backend configuration paths

3. **Deploy incrementally**:
- Start with backend setup
- Deploy foundation layer
- Add other layers based on requirements

### Vertical Scaling

#### Instance Resizing
```hcl
# Update node group instance types
node_groups = {
  primary = {
    instance_types = ["m5.xlarge"]  # Upgraded from m5.large
    min_size      = 2
    max_size      = 20              # Increased capacity
    desired_size  = 4
  }
}
```

#### Database Scaling
```hcl
# Scale database instances
instance_type = "r5.2xlarge"  # Upgraded from r5.large
volume_size   = 500           # Increased from 100GB
volume_iops   = 20000        # Increased IOPS
```

## Environment Management

### Development Environment
Create a development environment alongside production:

```bash
# Create dev-specific backend
cd providers/aws/regions/af-south-1/backend-setup
terraform workspace new development

# Deploy with dev-specific variables
terraform apply -var="environment=development" -var="instance_type=t3.medium"
```

### Staging Environment
```bash
# Deploy staging with production-like configuration but smaller scale
terraform apply -var="environment=staging" -var="min_size=1" -var="max_size=3"
```

### Blue-Green Deployments
1. **Deploy new version** to separate node groups
2. **Test thoroughly** in isolated environment
3. **Switch traffic** using load balancer weights
4. **Decommission old version** after validation

## Maintenance Operations

### Regular Updates
```bash
# Update Terraform modules
terraform get -update

# Plan and apply updates
terraform plan -out=tfplan
terraform apply tfplan
```

### Kubernetes Version Upgrades
```bash
# Update EKS cluster version in variables
cluster_version = "1.28"

# Apply upgrade
terraform apply

# Update node groups (done automatically with managed node groups)
```

### Certificate Rotation
- EKS certificates rotate automatically
- Application certificates managed by cert-manager
- Database certificates rotated during maintenance windows

## Monitoring Deployments

### Key Metrics to Watch
- **Deployment Success Rate**: > 95%
- **Rollback Rate**: < 5%
- **Mean Time to Recovery**: < 30 minutes
- **Infrastructure Drift**: Zero tolerance

### Automated Checks
```bash
# Post-deployment health checks
kubectl get nodes
kubectl get pods --all-namespaces
terraform plan  # Should show no changes
```

### Alerting Rules
- Failed Terraform applies
- Infrastructure drift detection
- Resource quota exhaustion
- Security group changes

## Troubleshooting

### Common Issues

1. **State Lock Issues**:
```bash
terraform force-unlock <lock-id>
```

2. **Resource Conflicts**:
```bash
terraform import <resource_type>.<resource_name> <resource_id>
```

3. **Module Updates**:
```bash
terraform init -upgrade
```

4. **Permissions Issues**:
- Check IAM policies
- Verify AssumeRole permissions
- Ensure service account roles are correct

### Emergency Procedures
1. **Infrastructure Failure**:
   - Switch to backup region
   - Restore from latest backup
   - Implement disaster recovery plan

2. **Security Breach**:
   - Rotate all credentials
   - Review access logs
   - Implement additional security controls

---

This deployment guide ensures consistent, repeatable infrastructure deployments while providing flexibility for scaling and maintenance operations.
