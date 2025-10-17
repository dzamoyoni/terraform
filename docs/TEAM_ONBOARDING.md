# Team Onboarding Guide

## Welcome to the Infrastructure Team

This guide will help you understand our production AWS infrastructure and get you up and running with our layered Terraform deployments.

## Essential Reading (30 minutes)

Please read these documents in order to understand our infrastructure strategy:

1. **[Usage Guide](USAGE_GUIDE.md)** - Practical day-to-day operations and client management
2. **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Layer-by-layer infrastructure deployment
3. **[FinOps & Cost Management](FINOPS_COST_MANAGEMENT.md)** - Cost optimization and financial governance

## Development Environment Setup

### Prerequisites
Install these tools on your local machine:

```bash
# 1. Install Terraform (version 1.0+)
brew install terraform  # macOS
# or
sudo apt-get install terraform  # Ubuntu
# or
choco install terraform  # Windows

# 2. Install AWS CLI
brew install awscli  # macOS
# or
sudo apt-get install awscli  # Ubuntu
# or
choco install awscli  # Windows

# 3. Install kubectl
brew install kubectl  # macOS
# or
sudo apt-get install kubectl  # Ubuntu
# or
choco install kubernetes-cli  # Windows

# 4. Install additional tools
brew install jq yq helm  # Utilities for JSON/YAML and Kubernetes package management
```

### Access Setup

1. **AWS Access**: Contact your manager to get AWS IAM credentials
2. **Repository Access**: Ensure you have read/write access to this repository
3. **VPN Access**: Set up VPN for accessing private infrastructure resources

### Cloud Provider Configuration

#### AWS Configuration
```bash
# Configure AWS CLI with your credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: [your-target-region]  # us-east-2, us-west-1, eu-central-1, etc.
# Default output format: json

# Test access
aws sts get-caller-identity
```

#### Azure Configuration (when applicable)
```bash
# Login to Azure
az login

# Set default subscription
az account set --subscription "your-subscription-name"

# Test access
az account show
```

#### GCP Configuration (when applicable)
```bash
# Login to GCP
gcloud auth login

# Set default project and region
gcloud config set project your-project-id
gcloud config set compute/region your-region  # us-central1, europe-west1, etc.

# Test access
gcloud auth list
```

## Repository Structure

Our infrastructure follows a logical, scalable organization:

```
terraform/
├── docs/                    # Documentation (you are here)
├── modules/                 # Reusable Terraform modules
│   ├── vpc-foundation/      # Network foundation
│   ├── eks-platform/        # Kubernetes platform
│   ├── client-subnets/      # Client isolation
│   └── observability-layer/ # Monitoring & logging
├── providers/               # Cloud-specific deployments
│   └── aws/                 # Amazon Web Services
│       ├── modules/         # AWS-specific modules
│       └── regions/         # Regional deployments
│           └── us-east-2/   # Ohio region (production)
├── shared/                  # Cross-cloud configuration
│   ├── backend-configs/     # Terraform state backend configs
│   └── policies/            # Governance policies
└── scripts/                 # Automation scripts
```

### Understanding Layers

Our infrastructure is deployed in logical layers:

1. **Backend Setup**: Terraform state storage (S3 + DynamoDB)
2. **Layer 1 - Foundation**: VPC, subnets, security groups, NAT gateways
3. **Layer 2 - Platform**: EKS clusters, node groups, IRSA
4. **Layer 3 - Data**: PostgreSQL instances, backup strategies (To minimize cost to attain HIgh Availability avoiding RDS)
5. **Layer 4 - Client Services**: Application-specific resources
6. **Layer 5 - Gateway**: API gateways, load balancers
7. **Layer 6 - Observability**: Monitoring, logging, distributed tracing

## Your First Deployment

Let's walk through deploying a complete environment step-by-step.

### Step 1: Clone and Explore
```bash
# Clone the repository
git clone <repository-url>
cd terraform

# Explore the structure
tree -L 3 providers/aws/regions/us-east-2/
```

### Step 2: Understand Current Deployments
```bash
# Check what's currently deployed in US-East-2
cd providers/aws/regions/us-east-2

# Look at the backend setup (already deployed)
ls -la backend-setup/

# Examine the foundation layer
cat layers/layer-1-foundation/production/main.tf | head -50
```

### Step 3: Plan a Small Change
```bash
# Navigate to foundation layer
cd layers/layer-1-foundation/production

# Initialize Terraform (downloads providers and modules)
terraform init -backend-config=../../../../../shared/backend-configs/us-east-2-foundation-production.hcl

# See what would change (should show "No changes")
terraform plan
```

### Step 4: Review Current Infrastructure
```bash
# See what's deployed
terraform show | head -50

# Check Kubernetes cluster status
aws eks describe-cluster --name production-cluster --region us-east-2

# List running instances
aws ec2 describe-instances --region us-east-2 --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value[]]' --output table
```

## Common Tasks

### Adding a New Client

1. **Update Foundation Layer** - Add client networking configuration:
```hcl
# In layers/layer-1-foundation/production/main.tf
module "client_networking_new_client" {
  source = "../../../../modules/vpc-foundation"
  
  client_name        = "new-client-prod"
  client_cidr_block  = "10.0.24.0/22"  # Next available range
  availability_zones = data.aws_availability_zones.available.names
  # ... configuration from common variables
}
```

2. **Update Platform Layer** - Add dedicated node group:
```hcl
# In layers/layer-2-platform/production/main.tf
node_groups = {
  new_client_prod = {
    instance_types = ["m6i.large"]
    min_size      = 1
    max_size      = 10
    desired_size  = 2
    subnet_ids    = module.client_networking_new_client.private_subnet_ids
  }
}
```

3. **Plan and Apply Changes**:
```bash
# Foundation layer first
cd layers/layer-1-foundation/production
terraform plan
terraform apply

# Platform layer second  
cd ../../layer-2-platform/production
terraform plan
terraform apply
```

### Scaling Resources

```bash
# Navigate to platform layer
cd providers/aws/regions/us-east-2/layers/layer-2-platform/production

# Update desired capacity in terraform.tfvars or variables
# Then apply changes
terraform plan -var="desired_size=4"  # Scale from 2 to 4 nodes
terraform apply
```

### Monitoring Costs

```bash
# Check current AWS costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Check resource tags for cost allocation
aws resourcegroupstaggingapi get-resources \
  --region us-east-2 \
  --tag-filters Key=Environment,Values=production
```

## Troubleshooting Common Issues

### Terraform State Locks
```bash
# If you see "state lock" error:
terraform force-unlock <lock-id>

# Always check who's running Terraform:
aws dynamodb get-item --table-name terraform-locks-us-east-2 \
  --key '{"LockID":{"S":"<lock-id>"}}' \
  --region us-east-2
```

### Module Not Found
```bash
# If modules aren't found:
terraform init -upgrade
terraform get -update
```

### Permission Denied
```bash
# Check your AWS identity
aws sts get-caller-identity

# Check if you can access the S3 state bucket
aws s3 ls s3://terraform-state-us-east-2/

# Verify IAM permissions with dry-run
aws ec2 describe-instances --dry-run --region us-east-2
```

### Kubernetes Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name production-cluster

# Test kubectl access
kubectl get nodes
kubectl get pods --all-namespaces
```

## Learning Resources

### Terraform
- [Terraform Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Provider Examples](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Kubernetes & EKS
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### AWS Services We Use
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [EC2 User Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/)
- [S3 User Guide](https://docs.aws.amazon.com/s3/latest/userguide/)

## Team Collaboration

### Code Review Process
1. **Create feature branch**: `git checkout -b feature/new-client-setup`
2. **Make changes**: Update Terraform configurations
3. **Test locally**: `terraform plan` to verify changes
4. **Commit changes**: Clear commit messages describing what changed
5. **Create PR**: Request review from senior team members
6. **Address feedback**: Make requested changes
7. **Merge**: Senior team member merges after approval

### Communication Channels
- **Daily Standups**: 9:00 AM, discuss infrastructure changes
- **Slack Channel**: `#infrastructure` for questions and updates
- **Emergency Contact**: On-call rotation for production issues
- **Documentation**: Always update docs when making significant changes

### Best Practices
- ✅ **Always run `terraform plan`** before `terraform apply`
- ✅ **Use meaningful commit messages** like "Add new client subnet for Acme Corp"
- ✅ **Tag resources properly** for cost tracking and organization
- ✅ **Test in development** before applying to production
- ✅ **Document your changes** in commit messages and PR descriptions
- ❌ **Never apply changes directly to production** without review
- ❌ **Don't ignore Terraform warnings** - investigate and resolve them
- ❌ **Avoid manual changes** to infrastructure - use Terraform instead

## 🚨 Emergency Procedures

### Production Incident Response
1. **Assess impact**: What's broken? How many users affected?
2. **Communicate**: Post in `#incidents` channel immediately
3. **Investigate**: Check CloudWatch logs, Kubernetes events
4. **Mitigate**: Implement temporary fix if possible
5. **Document**: Record what happened and timeline
6. **Follow up**: Post-incident review and prevention measures

### Disaster Recovery
- **Primary region failure**: Activate cross-region failover procedures
- **Data loss**: Restore from automated S3 backups with point-in-time recovery
- **Complete AWS outage**: Execute multi-cloud disaster recovery plan
- **Security breach**: Follow incident response playbook and compliance requirements

## Growth and Learning

### Next Steps (First 30 Days)
- [ ] Complete this onboarding guide
- [ ] Deploy a small change to development environment  
- [ ] Attend architecture review meetings
- [ ] Shadow senior team member for production deployment
- [ ] Complete AWS/Terraform training courses

### Career Development
- **Junior Engineer**: Focus on understanding existing patterns
- **Mid-Level Engineer**: Lead small projects, optimize costs
- **Senior Engineer**: Design new architectures, mentor juniors
- **Staff Engineer**: Define strategy, cross-team collaboration

### Training Opportunities
- AWS Certified Solutions Architect
- HashiCorp Certified: Terraform Associate
- Kubernetes Administrator (CKA)
- Internal lunch & learn sessions

---

Welcome to the team! 🎉 Don't hesitate to ask questions - we're here to help you succeed.
