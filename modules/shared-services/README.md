# 🚀 CPTWN Shared Services Module

**Enhanced with External IRSA Integration!**

This module deploys essential Kubernetes services following CPTWN standards with support for external IRSA (IAM Roles for Service Accounts) modules for enhanced security and flexibility.

## 🌟 New Features

### **External IRSA Integration**
- **✅ Optional External IRSA Support**: Use standalone IRSA modules for enhanced permissions
- **✅ Automatic Fallback**: Creates internal IRSA when external is not provided
- **✅ Zero Downtime**: Seamlessly switch between internal and external IRSA
- **✅ Enhanced Security**: Leverage more comprehensive IAM policies from standalone modules

## 📋 Services Included

| Service | Status | IRSA Support | Description |
|---------|--------|--------------|-------------|
| **Cluster Autoscaler** | ✅ Production | Internal + External | Auto-scaling for worker nodes |
| **AWS Load Balancer Controller** | ✅ Production | Internal + External | ALB/NLB integration |
| **Metrics Server** | ✅ Production | N/A | Resource metrics collection |
| **External DNS** | ✅ Production | Internal + External | Route53 DNS automation |

## 🔧 Usage Examples

### **Basic Usage (Internal IRSA)**
```hcl
module "shared_services" {
  source = "../modules/shared-services"

  # Core configuration
  project_name = "CPTWN-Multi-Client-EKS"
  environment  = "production"
  region       = "af-south-1"
  
  # Cluster information
  cluster_name            = "af-south-prod-cluster-01"
  cluster_endpoint        = data.terraform_remote_state.platform.outputs.cluster_endpoint
  cluster_ca_certificate  = base64decode(data.terraform_remote_state.platform.outputs.cluster_certificate_authority_data)
  oidc_provider_arn       = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = data.terraform_remote_state.platform.outputs.cluster_oidc_issuer_url
  vpc_id                  = data.terraform_remote_state.foundation.outputs.vpc_id
  
  # Service toggles
  enable_cluster_autoscaler           = true
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_external_dns                 = false
}
```

### **Enhanced Usage (External IRSA)**
```hcl
# First, create standalone IRSA modules
module "alb_controller_irsa" {
  source = "../modules/aws-load-balancer-controller-irsa"
  
  cluster_name = "af-south-prod-cluster-01"
  service_account_name = "af-south-prod-cluster-01-aws-load-balancer-controller-sa"
}

module "external_dns_irsa" {
  source = "../modules/external-dns-irsa"
  
  cluster_name = "af-south-prod-cluster-01"
  service_account_name = "af-south-prod-cluster-01-external-dns-sa"
  route53_zone_arns = ["arn:aws:route53:::hostedzone/Z123456789"]
}

# Then, use shared services with external IRSA
module "shared_services" {
  source = "../modules/shared-services"

  # ... basic configuration ...
  
  # 🔐 External IRSA Integration
  external_alb_controller_irsa_role_arn = module.alb_controller_irsa.iam_role_arn
  external_external_dns_irsa_role_arn   = module.external_dns_irsa.iam_role_arn
  
  # Enable services
  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true
  
  # External DNS configuration
  external_dns_domain_filters = ["example.com", "*.example.com"]
  external_dns_policy         = "upsert-only"
}
```

## 🔐 IRSA Variables

### **AWS Load Balancer Controller**
```hcl
variable "external_alb_controller_irsa_role_arn" {
  description = "External AWS Load Balancer Controller IRSA role ARN"
  type        = string
  default     = null
}
```

### **External DNS**
```hcl
variable "external_external_dns_irsa_role_arn" {
  description = "External External DNS IRSA role ARN"
  type        = string
  default     = null
}
```

### **Cluster Autoscaler**
```hcl
variable "external_cluster_autoscaler_irsa_role_arn" {
  description = "External Cluster Autoscaler IRSA role ARN"
  type        = string
  default     = null
}
```

## 🌐 External DNS Configuration

```hcl
# External DNS specific variables
variable "external_dns_version" {
  description = "Version of External DNS Helm chart"
  type        = string
  default     = "1.14.5"
}

variable "external_dns_domain_filters" {
  description = "List of domain filters for External DNS"
  type        = list(string)
  default     = []
}

variable "external_dns_policy" {
  description = "External DNS policy (sync or upsert-only)"
  type        = string
  default     = "upsert-only"
  validation {
    condition     = contains(["sync", "upsert-only"], var.external_dns_policy)
    error_message = "External DNS policy must be either 'sync' or 'upsert-only'."
  }
}
```

## 🚀 Migration Guide

### **From Internal to External IRSA**

1. **Deploy External IRSA Module**:
   ```bash
   # Apply the external IRSA first
   terraform apply -target=module.alb_controller_irsa
   ```

2. **Update Shared Services Configuration**:
   ```hcl
   module "shared_services" {
     # ... existing config ...
     
     # Add external IRSA role ARN
     external_alb_controller_irsa_role_arn = module.alb_controller_irsa.iam_role_arn
   }
   ```

3. **Apply Changes**:
   ```bash
   terraform apply
   ```

The module will automatically:
- ✅ Stop creating internal IRSA resources
- ✅ Update service account to use external IRSA role
- ✅ Maintain zero downtime during transition

## 🔍 Benefits of External IRSA

### **Enhanced Security**
- **More Comprehensive Permissions**: Standalone IRSA modules include additional security features
- **WAF/Shield Integration**: ALB Controller IRSA includes WAF and Shield permissions
- **Fine-grained Control**: Better separation of concerns

### **Operational Excellence**
- **Reusability**: Use the same IRSA across multiple deployments
- **Version Control**: Manage IRSA lifecycle independently
- **Debugging**: Easier troubleshooting with separated resources

### **Compliance**
- **Audit Trails**: Clear separation of IAM and application resources
- **Policy Management**: Centralized IAM policy management
- **Least Privilege**: More precise permission boundaries

## 📊 Resource Management

### **When External IRSA is Used**
- ❌ IAM Role creation **skipped**
- ❌ IAM Policy creation **skipped**
- ❌ Policy attachment **skipped**
- ✅ Service Account created with **external role ARN**
- ✅ Helm deployment **proceeds normally**

### **When External IRSA is NOT Used**
- ✅ IAM Role created **internally**
- ✅ IAM Policy created **internally**
- ✅ Policy attachment **applied**
- ✅ Service Account created with **internal role ARN**
- ✅ Helm deployment **proceeds normally**

## 🛠️ Troubleshooting

### **Common Issues**

#### **Service Account Role Mismatch**
```bash
# Check service account annotations
kubectl get serviceaccount -n kube-system <service-account-name> -o yaml
```

#### **IRSA Trust Relationship Issues**
```bash
# Verify OIDC provider configuration
aws iam get-role --role-name <role-name>
```

#### **Permission Denied Errors**
```bash
# Check pod logs for IAM permission issues
kubectl logs -n kube-system deployment/<deployment-name>
```

## 🎯 Best Practices

1. **Use External IRSA for Production**: Better security and operational control
2. **Test External IRSA First**: Deploy in dev/staging before production
3. **Monitor Service Health**: Verify services work correctly after IRSA changes
4. **Document Role ARNs**: Keep track of which external IRSA modules are used where
5. **Version Compatibility**: Ensure external IRSA modules are compatible with service versions

---

**Last Updated**: September 15, 2025  
**Terraform Version**: >= 1.5  
**Provider Versions**: AWS >= 5.0, Kubernetes >= 2.23, Helm >= 2.11
