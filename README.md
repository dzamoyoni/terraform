# Enterprise Cloud Infrastructure Platform

**Multi-cloud infrastructure platform** engineered for scalable, multi-tenant deployments across regions, environments, and cloud providers with comprehensive observability and security.

## ⚠️ Multi-Provider Status & Important Notice

### Current Production Status
** AWS Production-Ready:** This infrastructure has been extensively tested and is production-ready on **Amazon Web Services (AWS)**. All modules, layers, and operational procedures have been validated in AWS environments including:
- Production deployments in **us-east-2** region
- Multi-client isolation and scaling
- Enterprise-grade security and compliance
- Comprehensive observability and monitoring

### Multi-Provider Development Status
** Azure & GCP - Under Development:** While this platform is designed with multi-cloud architecture principles, **Azure and GCP implementations are currently in development**:

**Azure Status:**
- Directory structure prepared
- Module interfaces designed but not fully implemented
- **Not recommended for production use yet**

**Google Cloud Status:**
- Directory structure prepared  
- Module interfaces designed but not fully implemented
- **Not recommended for production use yet**

### Recommendations by Use Case

**For Production Workloads:**Use AWS implementation
- All features fully tested and supported
- Production-grade observability and security
- 24/7 operational procedures validated

**For Development/Testing:** Multi-provider experimentation welcomed
- Contribute to Azure/GCP implementation development
- Test provider-agnostic interfaces
- Report issues and improvements

**For Planning:** Review [Multi-Cloud Readiness Plan](docs/MULTI_CLOUD_READINESS_PLAN.md)
- Detailed implementation roadmap
- Resource requirements and timelines
- Technical architecture considerations

### Getting Multi-Provider Updates

To track multi-provider development progress:
- Review [Multi-Cloud Scaling Guide](docs/MULTI_CLOUD_SCALING_GUIDE.md) for architecture patterns
- Monitor [Multi-Cloud Readiness Plan](docs/MULTI_CLOUD_READINESS_PLAN.md) for implementation status

---

## Quick Start for Engineering Teams

1. **[Team Onboarding Guide](docs/TEAM_ONBOARDING.md)** - Complete setup and your first deployment
2. **[Usage Guide](docs/USAGE_GUIDE.md)** - Practical operations for client management, scaling, monitoring
3. **[Deployment Strategy](docs/DEPLOYMENT_GUIDE.md)** - Layer-by-layer infrastructure deployment
4. **[FinOps & Cost Management](docs/FINOPS_COST_MANAGEMENT.md)** - Cost optimization strategies

## Architecture Overview

This infrastructure platform uses a **layered, provider-agnostic architecture** designed for horizontal scaling across multiple dimensions:

```
terraform/
├── providers/
│   ├── aws/regions/           # Amazon Web Services
│   │   ├── {region}/          # us-east-2, us-west-1, eu-central-1, etc.
│   │   │   └── {project}/     # project-alpha, project-beta, etc.
│   │   │       └── {env}/     # production, staging, development
│   │   │           └── layers/# Deployment layers 1-6
│   ├── azure/regions/         # Microsoft Azure
│   │   ├── {region}/          # eastus2, westus2, westeurope, etc.
│   │   │   └── {project}/     # Same project structure
│   └── gcp/regions/           # Google Cloud Platform
│       ├── {region}/          # us-central1, europe-west1, etc.
│       │   └── {project}/     # Same project structure
├── modules/                   # Cloud-agnostic infrastructure modules
├── backends/                  # Provider-specific state management
└── shared/                    # Cross-cloud configuration and policies
```

### Universal Layer Architecture

Each project deployment implements infrastructure in dependency-ordered layers (cloud-agnostic patterns):

1. **Layer 1 - Foundation** - Network foundation, subnets, security groups, connectivity
2. **Layer 2 - Platform** - Kubernetes clusters, node pools, identity management
3. **Layer 3 - Data** - Managed databases, backup strategies, replication
4. **Layer 4 - Client Services** - Application namespaces, workloads, RBAC policies
5. **Layer 5 - Gateway** - Load balancers, API gateways, ingress controllers, SSL
6. **Layer 6 - Observability** - Metrics, logging, tracing, alerting, dashboards

### Scaling Dimensions

**Multi-Region Scaling:**
- Deploy identical infrastructure patterns across any region
- Automatic CIDR management prevents network conflicts
- Region-specific optimizations (instance types, zones, services)

**Multi-Project Scaling:**
- Multiple projects can coexist in the same region
- Isolated state management and resource namespacing
- Shared backend infrastructure with project-specific keys

**Multi-Provider Scaling:**
- Cloud-agnostic modules with provider-specific implementations
- Consistent deployment patterns across AWS, Azure, GCP
- Unified observability and management across providers

## Key Features

### **Production-Grade AWS Infrastructure**
- Battle-tested modules used across 6 deployment layers
- Multi-AZ deployments with automatic failover
- Comprehensive state management with S3 + DynamoDB
- Zero-downtime deployments with layered architecture

### **Multi-Tenant Client Isolation**
- Dedicated subnets per client with network isolation
- Separate EKS node groups for workload isolation
- Client-specific PostgreSQL instances and databases
- Granular security group rules and IAM policies

### **Enterprise Observability Stack**
- Fluent Bit log aggregation to S3 with intelligent tiering
- Grafana Tempo distributed tracing with S3 backend
- Prometheus metrics collection with long-term storage
- Real-time monitoring dashboards and alerting

### **Security & Compliance**
- Site-to-site VPN with BGP routing for hybrid connectivity
- IAM Roles for Service Accounts (IRSA) for pod-level security
- Comprehensive resource tagging for governance
- Encrypted storage and transit across all layers

### **Cost Engineering**
- Intelligent S3 storage tiering for logs and traces
- EBS GP3 storage optimization
- Right-sized EKS node groups with cluster autoscaler
- Real-time cost tracking with client-specific tags

### Multi-Tenant Architecture
- **Client Isolation**: Dedicated network segments with configurable CIDR blocks
- **Resource Boundaries**: Isolated compute, storage, and networking per tenant
- **Scalable Design**: Dynamic subnet allocation and automated resource sizing
- **Security Controls**: Network policies, RBAC, and identity-based access

### Resource Tagging Strategy
All resources include standardized tags for governance and cost management:
```hcl
tags = {
  Project         = var.project_name        # project-alpha, project-beta
  Environment     = var.environment         # production, staging, development
  Provider        = var.cloud_provider      # aws, azure, gcp
  Region          = var.region              # us-east-2, westus2, europe-west1
  Layer           = var.layer               # foundation, platform, data, etc.
  CostCenter      = var.cost_center         # engineering, operations, client-x
  BusinessUnit    = var.business_unit       # platform, product, infrastructure
  Owner           = var.owner_team          # platform-team, dev-team-a
  ManagedBy       = "terraform"
}
```

### Security Controls
- ✅ All traffic encrypted in transit and at rest
- ✅ Network segmentation between clients
- ✅ Regular security scanning and updates
- ✅ Audit logging for all infrastructure changes

## 🔧 Scaling Operations

### Deploy New Region
```bash
# 1. Provision backend infrastructure (provider-specific)
cd infrastructure/{provider}-backend-setup
terraform init && terraform apply -var="region={new-region}"

# 2. Copy and customize region structure  
cp -r providers/{provider}/regions/{source-region} providers/{provider}/regions/{new-region}

# 3. Deploy layers for specific project and environment
cd providers/{provider}/regions/{new-region}/{project-name}/{environment}/layers/layer-1-foundation
terraform init -backend-config=../../../../../../../backends/{provider}/{environment}/{region}/{project}/foundation.hcl
terraform apply -var="project_name={project}" -var="environment={environment}"
```

### Deploy New Project in Existing Region
```bash
# 1. Create project directory structure
mkdir -p providers/{provider}/regions/{region}/{new-project}/{environment}
cp -r providers/{provider}/regions/{region}/{existing-project}/{environment}/* \
      providers/{provider}/regions/{region}/{new-project}/{environment}/

# 2. Update project-specific configurations
cd providers/{provider}/regions/{region}/{new-project}/{environment}/layers/layer-1-foundation
terraform init -backend-config=../../../../../../../backends/{provider}/{environment}/{region}/{new-project}/foundation.hcl
terraform apply -var="project_name={new-project}" -var="environment={environment}"
```

### Scale Existing Infrastructure
```bash
# Scale Kubernetes node groups
cd providers/{provider}/regions/{region}/{project}/{environment}/layers/layer-2-platform
terraform plan -var="node_group_desired_size=6"
terraform apply

# Scale database tier (add read replicas)
cd ../layer-3-data
terraform plan -var="enable_read_replicas=true" -var="replica_count=2"
terraform apply
```

## Monitoring & Observability

### Observability Stack Components
- **Fluent Bit**: Log aggregation with S3 backends and intelligent tiering
- **Grafana Tempo**: Distributed tracing with S3 storage backend
- **Prometheus**: Metrics collection with remote write capabilities
- **EBS CSI Driver**: Persistent storage for observability workloads
- **AWS CloudWatch**: Infrastructure monitoring and alerting

### Data Pipeline Architecture
- **Logs**: Fluent Bit → S3 (hot/cold tiering) → Grafana for querying
- **Traces**: Tempo → S3 backend → Distributed tracing visualization
- **Metrics**: Prometheus → Long-term storage → Grafana dashboards
- **Client Isolation**: Tenant-specific data partitioning and access controls

### Alerting & Monitoring
- EKS cluster health and node group status
- PostgreSQL database performance and connections
- S3 storage costs and intelligent tiering efficiency
- VPN connectivity and BGP route propagation

### VPN Management

#### Extract VPN Preshared Keys
```bash
# Extract all VPN connection details for a specific region/project
cd providers/{provider}/regions/{region}/{project}/{environment}/layers/layer-1-foundation

# Get VPN connection IDs
terraform output vpn_connection_ids

# Extract preshared keys for specific VPN connection (AWS)
aws ec2 describe-vpn-connections \
  --vpn-connection-ids $(terraform output -raw vpn_connection_id_site1) \
  --region {region} \
  --query 'VpnConnections[0].Options.TunnelOptions[*].PreSharedKey' \
  --output table

# Get tunnel configuration details
aws ec2 describe-vpn-connections \
  --vpn-connection-ids $(terraform output -raw vpn_connection_id_site1) \
  --region {region} \
  --query 'VpnConnections[0].Options.TunnelOptions[*].{Tunnel:TunnelIpAddress,BGP_ASN:BgpAsn,PreSharedKey:PreSharedKey,Status:Status}' \
  --output table

# Extract all VPN connections and save to file
for vpn_id in $(terraform output -json vpn_connection_ids | jq -r '.[]'); do
  echo "=== VPN Connection: $vpn_id ===" >> vpn-config.txt
  aws ec2 describe-vpn-connections \
    --vpn-connection-ids $vpn_id \
    --region {region} \
    --query 'VpnConnections[0].Options.TunnelOptions[*]' \
    --output table >> vpn-config.txt
  echo "" >> vpn-config.txt
done

# Get VPN connection status and routing information
aws ec2 describe-vpn-connections \
  --vpn-connection-ids $(terraform output -raw vpn_connection_id_site1) \
  --region {region} \
  --query 'VpnConnections[0].{State:State,Type:Type,CustomerGatewayId:CustomerGatewayId,VpnGatewayId:VpnGatewayId}' \
  --output table
```

#### VPN Troubleshooting Commands
```bash
# Check VPN tunnel status
aws ec2 describe-vpn-connections \
  --region {region} \
  --query 'VpnConnections[*].VgwTelemetry[*].{ConnectionId:VpnConnectionId,OutsideIP:OutsideIpAddress,Status:Status,StatusMessage:StatusMessage}' \
  --output table

# Monitor VPN logs (if enabled)
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/vpn" \
  --region {region}

# Get routing table propagation status
aws ec2 describe-route-tables \
  --region {region} \
  --filters "Name=tag:Project,Values={project-name}" \
  --query 'RouteTables[*].PropagatingVgws[*].{RouteTableId:RouteTableId,GatewayId:GatewayId}' \
  --output table
```

## Contributing

### Development Workflow
1. **Feature Branch**: Create branch for changes
2. **Local Testing**: Run `terraform plan` to validate
3. **Code Review**: Submit PR for team review
4. **Staging Deploy**: Test in non-production environment
5. **Production Deploy**: Apply changes with approval

### Best Practices
- Always run `terraform plan` before `apply`
- Use meaningful commit messages
- Tag all resources properly for cost tracking
- Document architectural decisions
- Test changes in development first

## Support & Contacts

- **Platform Team**: `#infrastructure` Slack channel
- **On-Call**: Available 24/7 for production issues  
- **Documentation**: All guides in `/docs` directory
- **Training**: Monthly infrastructure workshops

---

## Getting Started

**New to the team?** Start with the [Team Onboarding Guide](docs/TEAM_ONBOARDING.md) for complete setup instructions.

**Need to deploy?** Follow the [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) for step-by-step procedures.

**Questions about costs?** Check the [FinOps Guide](docs/FINOPS_COST_MANAGEMENT.md) for optimization strategies.

---

**Status**: Production Ready | **Architecture**: Multi-Cloud | **Team**: Platform Engineering
