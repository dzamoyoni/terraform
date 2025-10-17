# Kubernetes Security Policies Examples

This directory contains example Kubernetes Network Policies and Istio Authorization Policies for tenant isolation.

## ⚠️ Status: Examples Only

These policies are **not automatically applied** by our Terraform infrastructure. They serve as examples for manual application or future integration.

## Contents

- **`network-policies/`** - Kubernetes NetworkPolicy examples for tenant isolation
- **`istio-policies/`** - Istio AuthorizationPolicy examples for service mesh security

## Purpose

These policies demonstrate how to implement:
- **Tenant isolation** between different client namespaces
- **Defense in depth** using both Kubernetes and Istio policies
- **Service mesh security** with Istio authorization

## Usage

To apply these policies manually:

```bash
# Apply network policies
kubectl apply -f network-policies/tenant-isolation-policies.yaml

# Apply Istio authorization policies  
kubectl apply -f istio-policies/tenant-authorization-policies.yaml
```

## Notes

- **Hardcoded values**: These examples use specific namespace names that would need to be updated for your environment
- **Manual maintenance**: Changes require manual updates to both policies and client configurations
- **Future integration**: Consider integrating these into Terraform as `kubernetes_manifest` resources for automated deployment

## Future Improvements

1. **Terraform integration**: Convert to Terraform `kubernetes_manifest` resources
2. **Variable templating**: Use variables instead of hardcoded namespace names
3. **Automated application**: Apply during infrastructure deployment
4. **Policy validation**: Add automated testing for policy effectiveness
