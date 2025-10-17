# Infrastructure Usage Guide

**Practical guide for day-to-day operations** with our production AWS infrastructure in us-east-2.

## Quick Reference

### Current Production Architecture
- **Primary Region**: `us-east-2` (Ohio)
- **Project Name**: `ohio-01` 
- **EKS Cluster**: `ohio-01-eks-cluster`
- **Client Tenants**: `est-test-a` (172.16.12.0/22), `est-test-b` (172.16.16.0/22)

### Layer Dependencies
```
01-foundation → 02-platform → 03-database-layer
                           ↓
04-standalone-compute ← 05-shared-services ← 06-observability
```

## Common Operations

### 1. Adding a New Client Tenant

#### Step 1: Update Foundation Layer
```bash
cd providers/aws/regions/us-east-2/layers/01-foundation/production

# Edit main.tf to add new client subnet module
```

```hcl
# Add this block to main.tf
module "client_subnets_new_client" {
  source = "../../../../../../../modules/client-subnets"

  enabled            = true
  project_name       = var.project_name
  client_name        = "new-client"
  vpc_id             = module.vpc_foundation.vpc_id
  client_cidr_block  = "172.16.20.0/22"  # Next available range
  availability_zones = local.availability_zones
  nat_gateway_ids    = module.vpc_foundation.nat_gateway_ids
  cluster_name       = "${var.project_name}-cluster"

  management_cidr_blocks = var.management_cidr_blocks
  custom_ports           = [8080, 9000, 3000, 5000]
  database_ports         = [5432, 5433, 5434, 5435]
  
  vpn_gateway_id = null
  
  common_tags = merge(
    local.common_tags,
    {
      Client     = "new-client"
      ClientCode = "NC"
      ClientTier = "Premium"
      TenantType = "Production"
    }
  )

  depends_on = [module.vpc_foundation]
}
```

#### Step 2: Deploy Foundation Changes
```bash
# Initialize and plan changes
terraform init -backend-config=../../../../backends/aws/production/us-east-2/foundation.hcl
terraform plan -var="project_name=ohio-01"
terraform apply
```

#### Step 3: Update Platform Layer (if EKS node groups needed)
```bash
cd ../02-platform/production

# Edit main.tf to add node group configuration
```

### 2. Scaling Infrastructure

#### Scale EKS Node Groups
```bash
cd providers/aws/regions/us-east-2/layers/02-platform/production

# Edit variables or terraform.tfvars
terraform plan -var="desired_capacity=6"  # Scale from current to 6 nodes
terraform apply
```

#### Scale PostgreSQL Database
```bash
cd providers/aws/regions/us-east-2/layers/03-database-layer/production

# Update instance type or storage
terraform plan -var="instance_type=r5.2xlarge"
terraform apply
```

### 3. Observability Operations

#### Check S3 Storage for Logs and Traces
```bash
# List log buckets
aws s3 ls | grep ohio-01 | grep logs

# Check trace storage utilization
aws s3api get-bucket-location --bucket ohio-01-us-east-2-traces-production

# View log structure (Fluent Bit creates structured paths)
aws s3 ls s3://ohio-01-us-east-2-logs-production/logs/ --recursive | head -20
```

#### Monitor Fluent Bit Log Collection
```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig --region us-east-2 --name ohio-01-eks-cluster

# Check Fluent Bit pods in observability layer
kubectl get pods -n istio-system | grep fluent-bit

# View Fluent Bit configuration
kubectl get configmap fluent-bit-config -n istio-system -o yaml
```

#### Access Grafana Tempo Traces
```bash
# Check Tempo deployment in observability layer
kubectl get pods -n istio-system | grep tempo

# Port forward to Tempo for local access
kubectl port-forward -n istio-system svc/tempo 3200:3200
```

### 4. Database Management

#### Connect to PostgreSQL Instances
```bash
# List PostgreSQL EC2 instances
aws ec2 describe-instances --region us-east-2 \
  --filters "Name=tag:Component,Values=PostgreSQL" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value[]]' \
  --output table

# Connect via SSH tunnel (requires VPN or bastion)
psql -h <private-ip> -U postgres -d <database-name>
```

#### Database Backup Operations
```bash
# Check automated backup status
aws ec2 describe-snapshots --region us-east-2 \
  --owner-ids self \
  --filters "Name=tag:Purpose,Values=PostgreSQL-Backup" \
  --query 'Snapshots[].[SnapshotId,StartTime,Description]' \
  --output table
```

### 5. Network & VPN Management

#### Check Site-to-Site VPN Status
```bash
# List VPN connections
aws ec2 describe-vpn-connections --region us-east-2 \
  --query 'VpnConnections[].[VpnConnectionId,State,CustomerGatewayConfiguration]' \
  --output table

# Monitor VPN tunnel status
aws ec2 describe-vpn-connections --region us-east-2 \
  --query 'VpnConnections[].VgwTelemetry[].[OutsideIpAddress,Status,StatusMessage]' \
  --output table
```

#### Validate Client Network Isolation
```bash
# Check security group rules for client isolation
aws ec2 describe-security-groups --region us-east-2 \
  --filters "Name=tag:Client,Values=est-test-a" \
  --query 'SecurityGroups[].[GroupId,GroupName,Description]' \
  --output table

# Verify subnet isolation
aws ec2 describe-subnets --region us-east-2 \
  --filters "Name=tag:Client,Values=est-test-a,est-test-b" \
  --query 'Subnets[].[SubnetId,CidrBlock,Tags[?Key==`Client`].Value[]]' \
  --output table
```

### 6. Cost Management & Monitoring

#### Track Costs by Client
```bash
# Get cost breakdown by client tags
aws ce get-cost-and-usage \
  --time-period Start=2024-10-01,End=2024-10-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT Type=TAG,Key=Client

# Check S3 storage costs for observability
aws ce get-cost-and-usage \
  --time-period Start=2024-10-01,End=2024-10-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Simple Storage Service"]}}'
```

#### Monitor Resource Utilization
```bash
# EKS node utilization
kubectl top nodes

# Pod resource usage by namespace
kubectl top pods --all-namespaces

# Check EBS volume usage
aws ec2 describe-volumes --region us-east-2 \
  --query 'Volumes[].[VolumeId,Size,VolumeType,State,Tags[?Key==`Name`].Value[]]' \
  --output table
```

## Backend Management

### Initialize Terraform with Correct Backends

#### Foundation Layer
```bash
cd providers/aws/regions/us-east-2/layers/01-foundation/production
terraform init -backend-config=../../../../backends/aws/production/us-east-2/foundation.hcl
```

#### Platform Layer
```bash
cd providers/aws/regions/us-east-2/layers/02-platform/production
terraform init -backend-config=../../../../backends/aws/production/us-east-2/platform.hcl
```

#### Observability Layer
```bash
cd providers/aws/regions/us-east-2/layers/06-observability/production
terraform init -backend-config=../../../../backends/aws/production/us-east-2/observability.hcl
```

### Backend Configuration Details
```bash
# Check backend configurations
ls -la backends/aws/production/us-east-2/

# Contents include:
# - foundation.hcl     # VPC and network layer
# - platform.hcl       # EKS cluster layer  
# - databases.hcl      # PostgreSQL layer
# - observability.hcl  # Monitoring stack layer
# - shared-services.hcl # Load balancers and DNS layer
```

## Layer-Specific Operations

### Foundation Layer (01)
```bash
# Key resources managed:
# - VPC with multi-AZ subnets
# - Client isolation (est-test-a, est-test-b)  
# - Site-to-site VPN
# - NAT Gateways

# Check VPC configuration
terraform show | grep -A 10 "vpc_foundation"
```

### Platform Layer (02)
```bash
# Key resources managed:
# - EKS cluster with managed node groups
# - IRSA (IAM Roles for Service Accounts)
# - Cluster security configuration

# Check EKS cluster status
aws eks describe-cluster --region us-east-2 --name ohio-01-eks-cluster
```

### Database Layer (03)
```bash
# Key resources managed:
# - PostgreSQL EC2 instances
# - Automated backups
# - Database security groups

# Check PostgreSQL instances
aws ec2 describe-instances --region us-east-2 \
  --filters "Name=tag:Layer,Values=database" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
  --output table
```

### Shared Services (05)
```bash
# Key resources managed:
# - AWS Load Balancer Controller
# - External DNS
# - Cluster Autoscaler

# Check shared services in EKS
kubectl get pods -n kube-system | grep -E "(aws-load-balancer|external-dns|cluster-autoscaler)"
```

### Observability (06)
```bash
# Key resources managed:
# - Fluent Bit (logs → S3)
# - Grafana Tempo (traces → S3)
# - Prometheus (metrics)
# - EBS CSI Driver for persistent volumes

# Check observability stack
kubectl get pods -n istio-system | grep -E "(fluent-bit|tempo|prometheus)"
```

## Troubleshooting

### Terraform State Issues
```bash
# Check state lock
aws dynamodb get-item \
  --table-name terraform-locks-us-east \
  --key '{"LockID":{"S":"ohio-01/foundation"}}'

# Force unlock if needed (use with caution)
terraform force-unlock <lock-id>
```

### EKS Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name ohio-01-eks-cluster

# Verify access
kubectl auth can-i get pods --all-namespaces
```

### Network Connectivity Issues
```bash
# Test VPN connectivity
aws ec2 describe-vpn-connections --region us-east-2

# Check route table propagation
aws ec2 describe-route-tables --region us-east-2 \
  --filters "Name=tag:Project,Values=ohio-01" \
  --query 'RouteTables[].[RouteTableId,Routes[].DestinationCidrBlock]' \
  --output table
```

### S3 Backend Access Issues
```bash
# Test S3 bucket access
aws s3 ls s3://ohio-01-terraform-state-production/

# Check DynamoDB table for locks
aws dynamodb describe-table --table-name terraform-locks-us-east
```

## Best Practices

### Always Use Terraform Plan First
```bash
# Never apply without planning
terraform plan -out=tfplan
terraform apply tfplan
```

### Layer Dependencies
- Deploy foundation layer before platform layer
- Deploy platform layer before databases and observability
- Shared services can be deployed after platform layer

### Client Isolation
- Each client gets dedicated subnets
- Security groups prevent cross-client communication
- Node groups can be client-specific for workload isolation

### Cost Optimization
- Monitor S3 intelligent tiering for logs and traces
- Use EBS GP3 storage for cost efficiency
- Right-size EKS node groups based on actual usage

---

This usage guide reflects the actual implemented infrastructure and provides practical commands for day-to-day operations.