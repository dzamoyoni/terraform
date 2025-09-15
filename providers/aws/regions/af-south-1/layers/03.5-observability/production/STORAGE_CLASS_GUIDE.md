# Storage Class Configuration Guide

## Overview
This document explains the storage class configuration for the observability layer to prevent PVC binding issues.

## Current Configuration

### EBS CSI Driver Module
- **Default Storage Class**: `gp2` (set as default)
- **GP3 Storage Class**: Disabled (`enable_gp3_storage = false`)
- **Reason**: Cost optimization - GP2 is cheaper for current workloads

### Component Storage Classes
All observability components are configured to use `gp2`:

1. **Tempo**: `storageClassName: gp2` (in tempo-values.yaml.tpl line 89)
2. **AlertManager**: `alertmanager_storage_class = "gp2"` (in variables.tf)
3. **Prometheus**: Uses default storage class (gp2)

## Common Issues and Solutions

### Issue 1: PVC Stuck in Pending
**Symptoms**: `0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims`
**Cause**: No storage class specified or storage class doesn't exist
**Solution**: 
- Ensure default storage class is set: `kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
- Or explicitly specify storage class in PVC

### Issue 2: Application Crashes with Storage Config
**Symptoms**: `Endpoint: does not follow ip address or domain name standards`
**Cause**: Missing S3 endpoint in Tempo configuration
**Solution**: Template now includes `endpoint: s3.${region}.amazonaws.com`

## Best Practices

### 1. Consistent Storage Classes
Always ensure storage class variables match the actual available storage classes:
- Module variable defaults should match actual cluster configuration
- All component templates should use consistent storage class names

### 2. Default Storage Class Management
```bash
# Check current default storage class
kubectl get storageclass

# Set gp2 as default (if not already set)
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 3. Variable Alignment
Ensure production variables align with module capabilities:
- `enable_gp3_storage = false` → use `gp2` in all component configurations
- `enable_gp3_storage = true` → can use `gp3` for better performance

## Terraform Configuration

### Production Layer (`main.tf`)
```hcl
module "observability" {
  # EBS CSI Configuration
  enable_gp3_storage = false  # Use GP2 for cost optimization
  
  # AlertManager Configuration  
  alertmanager_storage_class = var.alertmanager_storage_class  # "gp2"
}
```

### Variables (`variables.tf`)
```hcl
variable "alertmanager_storage_class" {
  description = "Storage class for AlertManager persistent volume"
  type        = string
  default     = "gp2"  # Must match enable_gp3_storage setting
}
```

## Monitoring Storage Issues

### Check PVC Status
```bash
kubectl get pvc -n istio-system
kubectl describe pvc <pvc-name> -n istio-system
```

### Check Storage Classes
```bash
kubectl get storageclass
kubectl describe storageclass gp2
```

### Check EBS CSI Driver
```bash
kubectl get daemonset ebs-csi-node -n kube-system
kubectl get deployment ebs-csi-controller -n kube-system
```

## Future Improvements

1. **GP3 Migration**: When ready for better performance:
   - Set `enable_gp3_storage = true` 
   - Update all storage class variables to `"gp3"`
   - Apply terraform changes

2. **Storage Class Validation**: Add validation rules to ensure consistency:
   ```hcl
   validation {
     condition = var.enable_gp3_storage ? var.alertmanager_storage_class == "gp3" : var.alertmanager_storage_class == "gp2"
     error_message = "Storage class must match enable_gp3_storage setting."
   }
   ```

3. **Automated Testing**: Add checks in CI/CD to validate storage class consistency.
