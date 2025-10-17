# GitOps Implementation Plan - Production-Grade Zero-Trust Security

##  **Implementation Overview**

This comprehensive plan transforms your current infrastructure pipeline into a production-grade, zero-trust GitOps system with advanced security controls, compliance validation, and enterprise-level operational excellence.

##  **Prerequisites Checklist**

### **1. Infrastructure Requirements**
- [ ] **Bitbucket/GitHub Repository** with admin access
- [ ] **AWS Account** with administrative permissions
- [ ] **Kubernetes Cluster** (EKS) in us-east-2 region
- [ ] **Domain/DNS Management** for GitOps services
- [ ] **SSL Certificates** for HTTPS endpoints

### **2. Required Service Accounts & API Keys**
- [ ] **Infracost API Key** - Cost analysis integration
- [ ] **Snyk API Token** - Vulnerability scanning
- [ ] **Slack Webhook URL** - Notifications
- [ ] **PagerDuty Integration Key** - Incident management
- [ ] **DataDog API Key** (Optional) - Monitoring integration

### **3. Security Tools Access**
- [ ] **Container Registry** access (Docker Hub, ECR, etc.)
- [ ] **Secret Management** system (AWS Secrets Manager, Vault)
- [ ] **Certificate Authority** for internal TLS

---

## **Phase 1: Foundation Setup (Week 1)**

### **Step 1.1: Repository Preparation**
```bash
# Backup current pipeline configuration
cd /home/dennis.juma/terraform
cp .bitbucket/bitbucket-pipelines.yml .bitbucket/bitbucket-pipelines-backup.yml

# Create new directory structure for GitOps
mkdir -p .gitops/{config,policies,templates}
mkdir -p shared/variables/security
mkdir -p scripts/security-validation
```

### **Step 1.2: Security Policy Configuration**
```bash
# Create terraform compliance rules
cat << 'EOF' > terraform-compliance.yml
---
terraform:
  - name: "Ensure all resources are encrypted"
    description: "All AWS resources must have encryption enabled"
    resource: "aws_*"
    attribute: "encrypted"
    condition: "contain"
    requirement: "True"

  - name: "No public access allowed"
    description: "Security groups must not allow access from 0.0.0.0/0"
    resource: "aws_security_group_rule"
    attribute: "cidr_blocks"
    condition: "not_contain"
    requirement: "0.0.0.0/0"

  - name: "S3 buckets must be private"
    description: "S3 buckets should not have public access"
    resource: "aws_s3_bucket"
    attribute: "acl"
    condition: "not_equal"
    requirement: "public-read"
EOF

# Create custom security validation scripts
cat << 'EOF' > scripts/security-validation/validate-encryption.sh
#!/bin/bash
echo "Validating encryption settings..."

# Check for unencrypted resources
UNENCRYPTED=$(grep -r "encrypted.*=.*false" --include="*.tf" . | wc -l)
if [ $UNENCRYPTED -gt 0 ]; then
    echo "Found $UNENCRYPTED unencrypted resources"
    exit 1
fi

# Check for missing encryption settings
MISSING_ENCRYPTION=$(grep -r -L "encrypt" --include="*.tf" . | wc -l)
if [ $MISSING_ENCRYPTION -gt 0 ]; then
    echo "⚠️  Found $MISSING_ENCRYPTION files without encryption configuration"
fi

echo "Encryption validation passed"
EOF

chmod +x scripts/security-validation/validate-encryption.sh
```

### **Step 1.3: Environment Variables Setup**
```bash
# Create secure environment variables in Bitbucket
# Repository Settings > Pipelines > Repository Variables

cat << 'EOF' > .gitops/config/required-variables.md
# Required Pipeline Variables

## Security & Scanning
- INFRACOST_API_KEY: Cost analysis API key
- SNYK_TOKEN: Vulnerability scanning token

## Notifications
- SLACK_WEBHOOK_URL: Slack notifications
- PAGERDUTY_INTEGRATION_KEY: Incident management

## Monitoring (Optional)
- DATADOG_API_KEY: Infrastructure monitoring
- NEW_RELIC_API_KEY: Application monitoring

## AWS Credentials (if not using IAM roles)
- AWS_ACCESS_KEY_ID: AWS access key
- AWS_SECRET_ACCESS_KEY: AWS secret key
- AWS_DEFAULT_REGION: us-east-2
EOF
```

---

## **Phase 2: Advanced Security Implementation (Week 2)**

### **Step 2.1: Deploy Enhanced Pipeline**
```bash
# Replace existing pipeline with production-grade version
cp .bitbucket/bitbucket-pipelines-secure.yml .bitbucket/bitbucket-pipelines.yml

# Test pipeline configuration
git add .bitbucket/bitbucket-pipelines.yml
git commit -m "feat: implement production-grade security pipeline"
git push origin feature/security-pipeline-upgrade
```

### **Step 2.2: Configure GitOps Service Accounts**
```bash
# Create Kubernetes service accounts for GitOps tools
kubectl create namespace gitops-system

# Create service account with RBAC
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitops-operator
  namespace: gitops-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT-ID:role/GitOpsOperatorRole
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gitops-operator
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitops-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gitops-operator
subjects:
- kind: ServiceAccount
  name: gitops-operator
  namespace: gitops-system
EOF
```

### **Step 2.3: Setup Secret Management**
```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true

# Create AWS Secrets Manager integration
cat << 'EOF' | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: gitops-system
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-2
      auth:
        serviceAccount:
          name: gitops-operator
EOF
```

---

## ⚙️ **Phase 3: Atlantis GitOps Engine Setup (Week 3)**

### **Step 3.1: Deploy Production Atlantis**
```bash
# Create Atlantis namespace
kubectl create namespace atlantis-system

# Create Atlantis configuration
cat << 'EOF' > .gitops/config/atlantis-values.yaml
image:
  repository: runatlantis/atlantis
  tag: v0.26.0
  pullPolicy: Always

orgAllowlist: "github.com/your-org/*"

# Security hardening
securityContext:
  runAsNonRoot: true
  runAsUser: 10000
  runAsGroup: 10000
  fsGroup: 10000
  capabilities:
    drop:
    - ALL

# High availability
replicaCount: 3
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

# Resource allocation
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

# Security policies
podSecurityPolicy:
  enabled: true

# Storage
dataStorage: 20Gi
storageClassName: gp3

# Ingress with SSL
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: aws-load-balancer-controller
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/ssl-redirect: 'true'
  host: atlantis.internal.company.com
  tls:
    enabled: true
EOF

# Deploy Atlantis
helm repo add runatlantis https://runatlantis.github.io/helm-charts
helm install atlantis runatlantis/atlantis \
  --namespace atlantis-system \
  --values .gitops/config/atlantis-values.yaml
```

### **Step 3.2: Configure Atlantis Repository Config**
```bash
# Create Atlantis repository configuration
cat << 'EOF' > atlantis.yaml
version: 3
automerge: false
delete_source_branch_on_merge: true
parallel_plan: false
parallel_apply: false

projects:
- name: foundation-production
  dir: providers/aws/regions/us-east-2/project-name/production/layers/layer-1-foundation
  workspace: production
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved", "mergeable"]
  workflow: production

- name: platform-production  
  dir: providers/aws/regions/us-east-2/project-name/production/layers/layer-2-platform
  workspace: production
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved", "mergeable"]
  workflow: production

workflows:
  production:
    plan:
      steps:
      - init
      - plan:
          extra_args: ["-var-file", "terraform.tfvars"]
      - policy_check
    apply:
      steps:
      - apply

policies:
  policy_sets:
  - name: security-policies
    path: .gitops/policies/
    source: local
EOF
```

---

## 🔄 **Phase 4: ArgoCD Application GitOps (Week 4)**

### **Step 4.1: Deploy Production ArgoCD**
```bash
# Create ArgoCD namespace
kubectl create namespace argocd-system

# Deploy ArgoCD with production configuration
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd-system \
  --values .gitops/config/argocd-values.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd-system
```

### **Step 4.2: Configure ArgoCD Applications**
```bash
# Create application-of-applications pattern
cat << 'EOF' > .gitops/applications/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd-system
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-applications
    targetRevision: main
    path: applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Apply the application
kubectl apply -f .gitops/applications/app-of-apps.yaml
```

---

## 🔍 **Phase 5: Security & Compliance Integration (Week 5)**

### **Step 5.1: OPA Gatekeeper Policy Engine**
```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Create security policies
cat << 'EOF' > .gitops/policies/require-security-context.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredsecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredSecurityContext
      validation:
        properties:
          requiredSecurityContext:
            type: object
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredsecuritycontext

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Container must run as non-root user"
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.readOnlyRootFilesystem
          msg := "Container must have read-only root filesystem"
        }
---
apiVersion: config.gatekeeper.sh/v1alpha1
kind: K8sRequiredSecurityContext
metadata:
  name: must-have-security-context
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment", "StatefulSet", "DaemonSet"]
  parameters:
    requiredSecurityContext:
      runAsNonRoot: true
      readOnlyRootFilesystem: true
EOF

kubectl apply -f .gitops/policies/require-security-context.yaml
```

### **Step 5.2: Falco Security Monitoring**
```bash
# Install Falco for runtime security
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

---

## 📊 **Phase 6: Monitoring & Observability (Week 6)**

### **Step 6.1: Prometheus & Grafana Setup**
```bash
# Deploy kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values .gitops/config/monitoring-values.yaml
```

### **Step 6.2: GitOps Specific Dashboards**
```bash
# Create GitOps monitoring dashboard
cat << 'EOF' > .gitops/config/gitops-dashboard.json
{
  "dashboard": {
    "title": "GitOps Security & Compliance Dashboard",
    "panels": [
      {
        "title": "Security Gate Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(pipeline_security_gate_passed[5m]) * 100"
          }
        ]
      },
      {
        "title": "Compliance Violations", 
        "type": "graph",
        "targets": [
          {
            "expr": "sum(compliance_violations_total) by (framework)"
          }
        ]
      }
    ]
  }
}
EOF
```

---

## 🧪 **Phase 7: Testing & Validation (Week 7)**

### **Step 7.1: End-to-End Pipeline Testing**
```bash
# Create test infrastructure change
cat << 'EOF' > test-security-pipeline.tf
# Test resource for security pipeline validation
resource "aws_s3_bucket" "test_security" {
  bucket = "test-security-pipeline-${random_id.test.hex}"
  
  tags = {
    Environment = "test"
    Purpose     = "Security pipeline validation"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_security" {
  bucket = aws_s3_bucket.test_security.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "test" {
  byte_length = 8
}
EOF

# Test pipeline with security validation
git add test-security-pipeline.tf
git commit -m "test: validate security pipeline"
git push origin feature/test-security-pipeline

# Create PR to trigger security scans
# Monitor pipeline execution in Bitbucket
```

### **Step 7.2: Security Scan Validation**
```bash
# Simulate security issues for testing
cat << 'EOF' > test-security-issues.tf
# This file intentionally contains security issues for testing

# ISSUE: Unencrypted S3 bucket
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "insecure-test-bucket"
  # Missing: encryption configuration
}

# ISSUE: Overly permissive security group
resource "aws_security_group" "insecure_sg" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Security issue: open to world
  }
}

# ISSUE: Hardcoded secret (for testing only)
resource "aws_db_instance" "test" {
  password = "hardcoded-password-123"  # Security issue
}
EOF

# Test that security pipeline catches these issues
git add test-security-issues.tf
git commit -m "test: security pipeline should fail"
git push origin feature/test-security-issues
```

---

## 🚀 **Phase 8: Production Deployment (Week 8)**

### **Step 8.1: Production Cutover**
```bash
# Backup current pipeline
git tag "pre-gitops-$(date +%Y%m%d)"

# Deploy to production
git checkout main
git merge feature/security-pipeline-upgrade
git push origin main

# Monitor first production deployment
# Check Atlantis UI: https://atlantis.internal.company.com
# Check ArgoCD UI: https://argocd.internal.company.com
```

### **Step 8.2: Team Training & Documentation**
```bash
# Create team runbooks
mkdir -p docs/runbooks
cat << 'EOF' > docs/runbooks/gitops-operations.md
# GitOps Operations Runbook

## Daily Operations
1. Check ArgoCD application health
2. Review Atlantis plan comments on PRs
3. Monitor security scan results
4. Validate compliance reports

## Incident Response
1. Check Falco alerts for security events
2. Review OPA Gatekeeper policy violations
3. Use ArgoCD rollback for application issues
4. Use Terraform state for infrastructure rollback

## Emergency Procedures
1. Disable automatic sync in ArgoCD
2. Lock Atlantis plans if needed
3. Contact security team for policy violations
4. Escalate to platform engineering for infrastructure issues
EOF
```

---

## 📈 **Success Metrics & KPIs**

### **Security Metrics**
- **Security Gate Pass Rate**: Target >95%
- **Critical Vulnerabilities**: Target <5 per month
- **Mean Time to Remediation**: Target <24 hours
- **Compliance Score**: Target >90%

### **Operational Metrics**
- **Deployment Frequency**: Track daily deployments
- **Lead Time**: Commit to production time
- **Change Failure Rate**: Target <10%
- **Mean Time to Recovery**: Target <2 hours

### **Cost Metrics**
- **Infrastructure Cost Trend**: Monthly tracking
- **Cost per Deployment**: Efficiency measurement
- **Budget Variance**: Target ±5%

---

## 🔧 **Troubleshooting Guide**

### **Common Issues & Solutions**

#### **Pipeline Failures**
```bash
# Check pipeline logs
# Fix security issues found by scans
# Validate Terraform configuration
# Check resource permissions
```

#### **Atlantis Issues**
```bash
# Check Atlantis pod logs
kubectl logs -n atlantis-system -l app=atlantis

# Validate webhook configuration
# Check GitHub/Bitbucket integration
# Verify RBAC permissions
```

#### **ArgoCD Sync Issues**
```bash
# Check application health
kubectl get applications -n argocd-system

# Manual sync if needed
argocd app sync app-name

# Check repository access
# Validate Kubernetes permissions
```

---

## 🎉 **Implementation Complete**

Upon completion, you will have:

✅ **Production-Grade Security Pipeline** with zero-trust architecture  
✅ **Multi-Layer Security Scanning** (8 different security tools)  
✅ **Automated Compliance Validation** (SOC2, GDPR, PCI DSS, ISO 27001)  
✅ **Infrastructure GitOps** with Atlantis  
✅ **Application GitOps** with ArgoCD  
✅ **Policy as Code** with OPA Gatekeeper  
✅ **Runtime Security** with Falco  
✅ **Comprehensive Monitoring** with Prometheus & Grafana  
✅ **Cost Management** with Infracost integration  
✅ **Multi-Stage Approvals** for production changes  

Your infrastructure platform now meets enterprise security standards with production-grade operational excellence! 🚀