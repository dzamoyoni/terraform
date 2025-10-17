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

# Set up environment variables for your deployment
export CLOUD_PROVIDER="aws"               # aws, azure, gcp
export REGION="us-east-2"                 # Provider-specific region codes
export PROJECT_NAME="project-alpha"        # Unique project identifier
export ENVIRONMENT="production"            # production, staging, development

# Computed deployment path
export DEPLOYMENT_PATH="providers/${CLOUD_PROVIDER}/regions/${REGION}/${PROJECT_NAME}/${ENVIRONMENT}"
```

## Deployment Process

### Phase 1: Backend Setup
Create the Terraform state backend (one-time setup per provider/region combination):

```bash
# Navigate to provider-specific backend setup
cd infrastructure/${CLOUD_PROVIDER}-backend-setup

# Deploy backend infrastructure
terraform init
terraform plan -var="region=${REGION}" -var="project_name=${PROJECT_NAME}"
terraform apply
```

**What this creates (provider-specific):**

**AWS:** S3 bucket for state storage, DynamoDB table for locking, IAM policies
**Azure:** Storage Account with blob containers, Resource locks, RBAC assignments
**GCP:** Cloud Storage bucket, Cloud Firestore for locking, IAM bindings

### Phase 2: Foundation Layer
Deploy the network and security foundation:

```bash
cd ${DEPLOYMENT_PATH}/layers/layer-1-foundation
terraform init -backend-config=../../../../../shared/backend-configs/${CLOUD_PROVIDER}/${ENVIRONMENT}/${REGION}/${PROJECT_NAME}/foundation.hcl
terraform plan -var="project_name=${PROJECT_NAME}" -var="environment=${ENVIRONMENT}"
terraform apply
```

**What this creates (cloud-agnostic patterns):**

**AWS:** VPC with public/private subnets, NAT gateways, security groups, NACLs
**Azure:** Virtual Network with subnets, NAT Gateway, Network Security Groups
**GCP:** VPC with subnets, Cloud NAT, firewall rules, network policies

### Phase 3: Platform Layer
Deploy the Kubernetes platform:

```bash
cd ../../layer-2-platform/production
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-platform-production.hcl
terraform plan
terraform apply
```

**What this creates:**
- EKS cluster with managed node groups and IRSA
- Dedicated system and application node groups
- AWS Load Balancer Controller and CSI drivers
- Pod security standards and network policies
- Cluster autoscaler for dynamic scaling

### Phase 4: Data Layer
Deploy database infrastructure:

```bash
cd ../../layer-3-data/production
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-data-production.hcl
terraform plan
terraform apply
```

**What this creates:**
- PostgreSQL RDS instances with Multi-AZ deployment
- Automated backup strategies with point-in-time recovery
- Database parameter groups and option groups
- Enhanced monitoring and performance insights
- Security groups with database-specific rules

### Phase 5: Client Services Layer
Deploy client-specific applications and services:

```bash
cd ../../layer-4-client-services/production
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-client-services-production.hcl
terraform plan
terraform apply
```

**What this creates:**
- Client-specific Kubernetes namespaces and RBAC
- Application deployment configurations
- Service accounts with least-privilege permissions
- Resource quotas and limit ranges
- Network policies for micro-segmentation

### Phase 6: Gateway Layer
Deploy API gateways and ingress controllers:

```bash
cd ../../layer-5-gateway/production
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-gateway-production.hcl
terraform plan
terraform apply
```

**What this creates:**
- Application Load Balancers with SSL termination
- API Gateway configurations for external access
- Certificate management with AWS Certificate Manager
- WAF rules for application protection
- Route 53 DNS configurations

### Phase 7: Observability Layer
Deploy comprehensive monitoring and logging:

```bash
cd ../../layer-6-observability/production
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-observability-production.hcl
terraform plan
terraform apply
```

**What this creates:**
- Prometheus stack for metrics collection and alerting
- Grafana for visualization and dashboards
- Tempo for distributed tracing
- Fluent Bit for log collection and forwarding
- Loki for log aggregation and querying
- S3 buckets for long-term storage of observability data

## Multi-Region Deployment Strategy

### Cross-Region Architecture
Our primary production environment runs in US-East-2 with disaster recovery capabilities:

```bash
# For disaster recovery region deployment
export AWS_REGION="us-west-2"
export PROJECT_NAME="production-cluster-dr"

# Follow the same layer deployment pattern
cd providers/aws/regions/us-west-2/backend-setup
# ... repeat deployment phases
```

### Network Isolation Considerations
- **CIDR Blocks**: Non-overlapping IP ranges across regions
  - US-East-2 (Production): `10.0.0.0/16`
  - US-West-2 (DR): `10.1.0.0/16`
- **DNS**: Route 53 health checks with automatic failover
- **Backup Strategy**: Cross-region S3 replication for disaster recovery

## Scaling Strategies

### Horizontal Scaling

#### Adding New Clients
1. **Update Foundation Layer**:
```hcl
# Add new client networking in foundation layer
module "client_vpc_new_client" {
  source = "../../../../modules/vpc-foundation"
  
  client_name       = "new-client-prod"
  client_cidr_block = "10.0.20.0/22"  # Next available range
  environment       = var.environment
  project           = var.project
  # ... enterprise tagging and configuration
}
```

2. **Update Platform Layer**:
```hcl
# Add dedicated node group for new client
node_groups = {
  new_client_prod = {
    instance_types = ["m6i.large"]
    min_size      = 2
    max_size      = 20
    desired_size  = 3
    subnet_ids    = module.client_vpc_new_client.private_subnet_ids
    labels = {
      "client" = "new-client-prod"
      "workload-type" = "application"
    }
  }
}
```

#### Adding New Regions
1. **Copy and customize region structure**:
```bash
# Create new region structure
cp -r providers/aws/regions/us-east-2 providers/aws/regions/eu-central-1

# Update region-specific configurations
find providers/aws/regions/eu-central-1 -name "*.tf" -exec sed -i 's/us-east-2/eu-central-1/g' {} +
find providers/aws/regions/eu-central-1 -name "*.hcl" -exec sed -i 's/us-east-2/eu-central-1/g' {} +
```

2. **Update networking and backend configurations**:
- Change CIDR blocks to avoid conflicts (e.g., `10.2.0.0/16`)
- Update Terraform backend S3 bucket and DynamoDB table names
- Modify availability zone references
- Update region-specific AMIs and instance types

3. **Deploy using phased approach**:
- Phase 1: Backend setup and state management
- Phase 2: Foundation layer with network isolation
- Phase 3-7: Deploy remaining layers based on regional requirements

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
# Scale RDS instances vertically
instance_class = "db.r6g.2xlarge"  # Upgraded from db.r6g.large
allocated_storage = 1000            # Increased from 100GB
iops = 30000                        # Increased IOPS for better performance
max_allocated_storage = 2000        # Enable storage autoscaling

# Enable read replicas for horizontal scaling
read_replica_count = 2
read_replica_instance_class = "db.r6g.large"
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
