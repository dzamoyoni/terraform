# Platform Layer Documentation

## Overview
The Platform Layer manages the core Kubernetes platform services and infrastructure components that support applications running on the EKS cluster.

## Architecture

### Layer Dependencies
```
01-foundation (VPC, Networking) 
    ↓
02-platform (EKS, DNS, Load Balancers) ← YOU ARE HERE
    ↓
03-databases (Managed Databases)
    ↓
04-applications (Application Deployments)
```

## Components Managed

### **EKS Cluster**
- **Cluster Name:** `us-test-cluster-01`
- **Version:** Latest supported (currently managed as existing resource)
- **Networking:** Uses existing VPC (172.20.0.0/16)
- **Node Groups:** 4 nodes across 2 AZs (us-east-1a, us-east-1b)

### **Platform Services**

#### **AWS Load Balancer Controller**
- **Deployment:** Helm-managed (chart version 1.8.1)
- **IRSA Role:** `us-test-cluster-01-aws-load-balancer-controller`
- **Replicas:** 2 (high availability)
- **Purpose:** Manages ALB/NLB resources for ingress

#### **External DNS** 
- **Deployment:** Kubernetes manifest
- **IRSA Role:** `us-test-cluster-01-external-dns`
- **Replicas:** 1
- **Domains:** `stacai.ai`, `ezra.world`
- **Purpose:** Automated Route53 DNS record management

#### **EBS CSI Driver**
- **Type:** EKS Add-on (v1.35.0-eksbuild.1)
- **IRSA Role:** `us-test-cluster-01-ebs-csi-driver`
- **Components:** 2 controllers + 4 node drivers
- **Purpose:** Persistent volume support for applications

### **DNS Management**
- **Route53 Zones:** 2 hosted zones
  - `stacai.ai` (Z04776272SUAXJJ67BOOF)
  - `ezra.world` (Z046811616JHZ6MU53R8Y)

### **Ingress Configuration**
- **Default Ingress Class:** ALB
- **Controller:** `ingress.k8s.aws/alb`
- **Integration:** Works with AWS Load Balancer Controller

## Configuration

### **Required Variables**
```hcl
# Core cluster information
cluster_name         = "us-test-cluster-01"
cluster_version     = "1.30"
region              = "us-east-1"

# Networking (inherited from existing VPC)
vpc_id          = "vpc-0ec63df5e5566ea0c"
private_subnets = ["subnet-0a6936df3ff9a4f77", "subnet-0ec8a91aa274caea1"]
public_subnets  = ["subnet-0b97065c0b7e66d5e", "subnet-067cb01bb4e3bb0e7"]

# DNS domains to manage
route53_zones = {
  "stacai.ai"  = true
  "ezra.world" = true
}

# External DNS configuration
external_dns_enabled = true
external_dns_domains = ["stacai.ai", "ezra.world"]

# Tags
common_tags = {
  Environment = "production"
  Layer      = "platform"
  Repository = "infrastructure"
  ManagedBy  = "terraform"
}
```

### **Outputs Provided**
The platform layer exposes key information via SSM parameters for use by other layers:

```hcl
# Cluster information
cluster_endpoint = "https://040685953098FF194079A7F628B03260.gr7.us-east-1.eks.amazonaws.com"
cluster_id       = "us-test-cluster-01"
cluster_ca_certificate = "(stored as sensitive in SSM)"

# OIDC provider for IRSA
oidc_provider_arn = "arn:aws:iam::101886104835:oidc-provider/..."
oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/..."

# Service roles
aws_load_balancer_controller_role_arn = "arn:aws:iam::101886104835:role/us-test-cluster-01-aws-load-balancer-controller"
external_dns_role_arn = "arn:aws:iam::101886104835:role/us-test-cluster-01-external-dns"
ebs_csi_irsa_role_arn = "arn:aws:iam::101886104835:role/us-test-cluster-01-ebs-csi-driver"

# Route53 zones
route53_zone_ids = {
  "ezra.world" = "Z046811616JHZ6MU53R8Y"
  "stacai.ai"  = "Z04776272SUAXJJ67BOOF"
}
```

## Operations

### **Deployment**
```bash
cd /home/dennis.juma/terraform/regions/us-east-1/layers/02-platform/production

# Initialize and plan
terraform init
terraform plan

# Apply changes
terraform apply
```

### **Validation**
```bash
# Check EKS cluster health
kubectl get nodes

# Verify platform services
kubectl get deployments,daemonsets -n kube-system | grep -E "(aws-load-balancer|external-dns|ebs-csi)"

# Test ingress class
kubectl get ingressclass

# Verify DNS zones
aws route53 list-hosted-zones --query 'HostedZones[?Name==`stacai.ai.` || Name==`ezra.world.`]'
```

### **Monitoring**
Monitor these key metrics:
- EKS node health and resource utilization
- Platform service pod status (Running/Ready)
- Route53 DNS query metrics
- Load balancer health checks
- EBS CSI driver volume operations

## Security

### **IRSA (IAM Roles for Service Accounts)**
All platform services use IRSA for AWS API access:
- Least privilege IAM policies
- No hardcoded credentials in pods
- Automatic token rotation

### **Network Security**
- Platform services run in `kube-system` namespace
- Security groups control access to AWS services
- VPC CNI provides pod-level networking isolation

## Troubleshooting

### **Common Issues**

#### **Load Balancer Controller Not Creating ALBs**
```bash
# Check controller logs
# kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IRSA role
# kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml
```

#### **External DNS Not Updating Records**
```bash
# Check external-dns logs
kubectl logs -n kube-system deployment/external-dns

# Verify Route53 permissions
aws sts assume-role --role-arn $(kubectl get sa external-dns -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}') --role-session-name test
```

#### **EBS Volumes Not Attaching**
```bash
# Check CSI driver status
kubectl get pods -n kube-system | grep ebs-csi

# Verify storage class
kubectl get storageclass
```

## Dependencies

### **External Dependencies**
- **VPC:** Existing VPC with public/private subnets
- **EKS Cluster:** Pre-existing cluster (imported during migration)
- **Route53:** Domain registration and delegation

### **Module Dependencies**
- `terraform-aws-modules/eks/aws` (EKS cluster management)
- Custom modules for IRSA and platform services

## Backup & Recovery

### **State Backup**
Terraform state is stored in S3 backend with versioning enabled.

### **Configuration Backup**
Latest configuration backed up to:
- `/home/dennis.juma/terraform/final-migration-backup-20250826/`

### **Critical Snapshots**
Database volumes are backed up with automatic snapshots containing critical data.

---

**Layer Status:** ✅ Production Ready  
**Last Updated:** August 26, 2025  
**Managed Resources:** 53 resources in clean state
