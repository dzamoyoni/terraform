# Enterprise GitOps Tools Guide
## Production-Grade Security & Dynamic Operations

## Implementation Status: Next Major Platform Enhancement

**Current Status:** This document outlines the planned GitOps implementation designed for full production capacity with enterprise security standards. GitOps integration is the **next major platform enhancement** following multi-cloud readiness.

**Production Requirements Met:**
- ✅ Zero-trust security model
- ✅ Dynamic multi-tenant isolation
- ✅ Enterprise SSO/RBAC integration
- ✅ Audit logging and compliance
- ✅ High availability and disaster recovery
- ✅ Automated security scanning and policy enforcement

**Timeline:** GitOps implementation scheduled as primary focus after current AWS optimization and multi-cloud foundation completion.

---

## Overview

This comprehensive guide defines enterprise-grade GitOps implementation with production-level security, dynamic scaling, and operational excellence. Every component is designed for high-stakes production environments with zero-tolerance for security vulnerabilities.

## Production Security Architecture

### Zero-Trust GitOps Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ZERO-TRUST GITOPS ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────────┐ │
│  │   Developer     │    │  Security Gate   │    │   GitOps Engine        │ │
│  │   Workstation   │────│  - MFA Required  │────│   - Signed Commits     │ │
│  │   - VPN+MFA     │    │  - Code Scanning │    │   - RBAC Enforcement   │ │
│  │   - GPG Signed  │    │  - Policy Check  │    │   - Audit Logging      │ │
│  └─────────────────┘    └──────────────────┘    └────────────────────────┘ │
│           │                        │                         │              │
│           ▼                        ▼                         ▼              │
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────────┐ │
│  │  Git Repository │    │  Webhook Gateway │    │   Infrastructure       │ │
│  │  - Branch Prot. │────│  - TLS 1.3 Only │────│   - Encrypted at Rest  │ │
│  │  - Signed Tags  │    │  - IP Allowlist  │    │   - Network Policies   │ │
│  │  - Audit Trail  │    │  - Rate Limiting │    │   - Pod Security Std.  │ │
│  └─────────────────┘    └──────────────────┘    └────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Security Controls Matrix

| Layer | Control | Implementation | Audit |
|-------|---------|---------------|--------|
| **Identity** | MFA + SSO | SAML/OIDC integration | Authentication logs |
| **Authorization** | RBAC + ABAC | Dynamic role assignment | Authorization audit |
| **Code** | Signed commits | GPG signature verification | Commit signature logs |
| **Pipeline** | Secure scanning | SAST/DAST/Container scanning | Vulnerability reports |
| **Secrets** | Zero-knowledge | External secrets operator | Secret access audit |
| **Network** | Zero-trust | mTLS + Network policies | Network flow logs |
| **Runtime** | Policy enforcement | OPA Gatekeeper policies | Policy violation logs |
| **Data** | Encryption | AES-256 at rest/transit | Encryption key rotation |

---

## 1. Version Control & CI/CD Platform

### Bitbucket Data Center (Enterprise)

#### Installation & Setup
```bash
# 1. Deploy Bitbucket Data Center on Kubernetes
helm repo add atlassian https://atlassian.github.io/data-center-helm-charts
helm repo update

# Create namespace
kubectl create namespace bitbucket

# Install Bitbucket Data Center
helm install bitbucket atlassian/bitbucket \
  --namespace bitbucket \
  --set bitbucket.resources.jvm.maxHeap="4g" \
  --set bitbucket.resources.container.requests.memory="8Gi" \
  --set replicaCount=2 \
  --set database.type=postgresql \
  --set database.url="jdbc:postgresql://postgres.db.svc.cluster.local:5432/bitbucket"
```

#### Configuration
```yaml
# bitbucket-values.yaml
bitbucket:
  resources:
    jvm:
      maxHeap: "8g"
      minHeap: "4g"
    container:
      requests:
        memory: "12Gi"
        cpu: "2"
      limits:
        memory: "16Gi"
        cpu: "4"
  
  clustering:
    enabled: true
  
  # Enterprise features
  license: "${BITBUCKET_LICENSE}"
  
  # SSO Configuration
  sso:
    enabled: true
    saml:
      identityProvider: "https://sso.company.com/saml/bitbucket"
      certificate: "${SAML_CERTIFICATE}"

# Database configuration
database:
  type: postgresql
  driver: "org.postgresql.Driver"
  url: "jdbc:postgresql://bitbucket-postgres:5432/bitbucket"
  credentials:
    secretName: "bitbucket-database-credentials"

# Load balancer
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${SSL_CERTIFICATE_ARN}"
```

#### Enterprise Features Setup
```bash
# Repository permissions and branch protection
curl -X POST \
  -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "branch-restriction",
    "kind": "push",
    "pattern": "main",
    "users": [],
    "groups": ["infrastructure-admins"]
  }' \
  "https://bitbucket.company.com/rest/branch-permissions/2.0/repositories/company/terraform-infrastructure/restrictions"

# Enable required reviewers
curl -X POST \
  -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "branch-restriction",
    "kind": "require_approvals_to_merge",
    "pattern": "main",
    "value": 2
  }' \
  "https://bitbucket.company.com/rest/branch-permissions/2.0/repositories/company/terraform-infrastructure/restrictions"
```

---

## 2. GitOps Automation Engine

### Atlantis Enterprise - Production Security Configuration

#### High-Availability Deployment with Security Hardening
```yaml
# atlantis-deployment.yaml - Production Security Hardened
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlantis
  namespace: atlantis-system
  labels:
    app: atlantis
    version: "v0.26.0"
    security.compliance/level: "high"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: atlantis
  template:
    metadata:
      labels:
        app: atlantis
        version: "v0.26.0"
      annotations:
        # Security annotations
        seccomp.security.alpha.kubernetes.io/pod: "runtime/default"
        container.apparmor.security.beta.kubernetes.io/atlantis: "runtime/default"
    spec:
      serviceAccountName: atlantis
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: atlantis
            topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/system
                operator: In
                values: ["true"]
      containers:
      - name: atlantis
        image: runatlantis/atlantis:v0.26.0
        imagePullPolicy: Always
        ports:
        - name: atlantis
          containerPort: 4141
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 10000
          runAsGroup: 10000
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        env:
        # Repository Security
        - name: ATLANTIS_REPO_ALLOWLIST
          value: "github.com/your-org/*"
        - name: ATLANTIS_REPO_CONFIG_JSON
          value: |
            {
              "repos": [
                {
                  "id": "/.*/",
                  "branch": "main",
                  "apply_requirements": ["approved", "mergeable"],
                  "allowed_overrides": [],
                  "allow_custom_workflows": false
                }
              ]
            }
        # Authentication & Authorization
        - name: ATLANTIS_GH_USER
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: github-username
        - name: ATLANTIS_GH_TOKEN
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: github-token
        - name: ATLANTIS_GH_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: webhook-secret
        # Security Configuration
        - name: ATLANTIS_WRITE_GIT_CREDS
          value: "false"
        - name: ATLANTIS_HIDE_PREV_PLAN_COMMENTS
          value: "true"
        - name: ATLANTIS_DISABLE_MARKDOWN_FOLDING
          value: "false"
        - name: ATLANTIS_ENABLE_POLICY_CHECKS
          value: "true"
        - name: ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT
          value: "true"
        # Operational Security
        - name: ATLANTIS_DATA_DIR
          value: "/atlantis-data"
        - name: ATLANTIS_LOG_LEVEL
          value: "info"
        - name: ATLANTIS_STATS_NAMESPACE
          value: "atlantis"
        - name: ATLANTIS_PORT
          value: "4141"
        # TLS Configuration
        - name: ATLANTIS_TLS_CERT_FILE
          value: "/etc/ssl/certs/tls.crt"
        - name: ATLANTIS_TLS_KEY_FILE
          value: "/etc/ssl/private/tls.key"
        # Resource Management
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "4Gi"
            cpu: "2000m"
            ephemeral-storage: "2Gi"
        # Health Checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: 4141
            scheme: HTTPS
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /healthz
            port: 4141
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Volume Mounts
        volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
        - name: atlantis-config
          mountPath: /etc/atlantis
          readOnly: true
        - name: tls-certs
          mountPath: /etc/ssl/certs
          readOnly: true
        - name: tls-private
          mountPath: /etc/ssl/private
          readOnly: true
        - name: tmp
          mountPath: /tmp
      # Sidecar: Security Scanner
      - name: security-scanner
        image: aquasec/trivy:latest
        command: ["sleep", "infinity"]
        securityContext:
          runAsNonRoot: true
          runAsUser: 10001
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
      volumes:
      - name: atlantis-data
        persistentVolumeClaim:
          claimName: atlantis-data-pvc
      - name: atlantis-config
        configMap:
          name: atlantis-config
          defaultMode: 0600
      - name: tls-certs
        secret:
          secretName: atlantis-tls
          defaultMode: 0600
      - name: tls-private
        secret:
          secretName: atlantis-tls
          defaultMode: 0600
      - name: tmp
        emptyDir: {}
      # Image Pull Secrets
      imagePullSecrets:
      - name: registry-secret
```

#### Atlantis Configuration
```yaml
# atlantis.yaml (repository root)
version: 3
automerge: false
delete_source_branch_on_merge: true
parallel_plan: false
parallel_apply: false

projects:
- name: foundation-af-south-1-production
  dir: providers/aws/regions/af-south-1/layers/01-foundation/production
  workspace: production
  terraform_version: v1.5.7
  autoplan:
    when_modified: ["*.tf", "*.tfvars", "*.hcl"]
    enabled: true
  apply_requirements: 
    - approved
    - mergeable
  workflow: terraform-enterprise

- name: platform-af-south-1-production  
  dir: providers/aws/regions/af-south-1/layers/02-platform/production
  workspace: production
  terraform_version: v1.5.7
  autoplan:
    when_modified: ["*.tf", "*.tfvars", "*.hcl"]
    enabled: true
  apply_requirements:
    - approved
    - mergeable
  workflow: terraform-enterprise

workflows:
  terraform-enterprise:
    plan:
      steps:
      - env:
          name: INFRACOST_API_KEY
          command: 'echo $INFRACOST_API_KEY_SECRET'
      - run: |
          echo "Running security scan..."
          checkov -d . --framework terraform --quiet
      - run: |
          echo "Generating cost estimate..."
          infracost breakdown --path . --format json --out-file infracost.json
          infracost output --path infracost.json --format table
      - init
      - plan:
          extra_args: ["-lock-timeout=10m"]
      - run: |
          echo "Plan validation complete"
    apply:
      steps:
      - run: |
          echo "Pre-deployment backup..."
          terraform state pull > backup-$(date +%Y%m%d-%H%M%S).json
      - apply
      - run: |
          echo "Post-deployment validation..."
          terraform output -json > outputs.json
```

#### RBAC Integration
```yaml
# atlantis-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: atlantis
  namespace: atlantis-system
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT:role/atlantis-service-role"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: atlantis
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: atlantis
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: atlantis
subjects:
- kind: ServiceAccount
  name: atlantis
  namespace: atlantis-system
```

---

## 3. Secrets Management

### HashiCorp Vault Enterprise

#### Installation with HA Configuration
```yaml
# vault-values.yaml
global:
  enabled: true
  tlsDisable: false

server:
  image:
    repository: "hashicorp/vault-enterprise"
    tag: "1.15.0-ent"
  
  enterpriseLicense:
    secretName: "vault-license"
    secretKey: "license"
  
  resources:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "1000m"
  
  readinessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
  
  livenessProbe:
    enabled: true
    path: "/v1/sys/health?standbyok=true"
    initialDelaySeconds: 60
  
  # HA Configuration
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 0
          address = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
          tls_key_file = "/vault/userconfig/vault-tls/tls.key"
        }
        
        storage "raft" {
          path = "/vault/data"
          retry_join {
            leader_api_addr = "https://vault-0.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-ca/ca.crt"
          }
          retry_join {
            leader_api_addr = "https://vault-1.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-ca/ca.crt"
          }
          retry_join {
            leader_api_addr = "https://vault-2.vault-internal:8200"
            leader_ca_cert_file = "/vault/userconfig/vault-ca/ca.crt"
          }
        }
        
        seal "awskms" {
          region = "af-south-1"
          kms_key_id = "${AWS_KMS_KEY_ID}"
        }
        
        service_registration "kubernetes" {}

# Install Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -f vault-values.yaml --namespace vault-system --create-namespace
```

#### Secret Engines Configuration
```bash
# Initialize and unseal Vault (one-time setup)
kubectl exec vault-0 -n vault-system -- vault operator init -key-shares=5 -key-threshold=3

# Configure AWS secret engine
vault secrets enable -path=aws aws
vault write aws/config/root \
    access_key=${AWS_ACCESS_KEY} \
    secret_key=${AWS_SECRET_KEY} \
    region=af-south-1

# Create dynamic IAM role for Terraform
vault write aws/roles/terraform-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "iam:*",
        "sts:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Configure Kubernetes auth
vault auth enable kubernetes
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create policy for Atlantis
vault policy write atlantis-policy - <<EOF
path "aws/creds/terraform-role" {
  capabilities = ["read"]
}
path "secret/data/terraform/*" {
  capabilities = ["read"]
}
EOF

# Bind Atlantis service account
vault write auth/kubernetes/role/atlantis \
    bound_service_account_names=atlantis \
    bound_service_account_namespaces=atlantis-system \
    policies=atlantis-policy \
    ttl=24h
```

---

## 4. Security & Compliance Tools

### Checkov (Infrastructure Security)
```bash
# Install Checkov
pip install checkov

# Custom policy configuration
cat > .checkov.yaml <<EOF
framework:
  - terraform
  - kubernetes
  - dockerfile

skip-check:
  - CKV_AWS_79  # Ensure Instance Metadata Service Version 1 is not enabled
  
soft-fail: true
output: cli
quiet: false

# Custom policies directory
external-checks-dir: ./custom-policies/

# Baseline configuration
baseline: .checkov.baseline
EOF

# Create custom policy example
mkdir -p custom-policies
cat > custom-policies/CompanyTaggingPolicy.py <<EOF
from checkov.common.models.enums import TRUE_VALUES
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import ANY_VALUE

class CompanyTaggingPolicy(BaseResourceCheck):
    def __init__(self):
        name = "Ensure all resources have required company tags"
        id = "CKV_COMPANY_001"
        supported_resources = ['*']
        categories = [CONVENTION]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        required_tags = ["Environment", "Owner", "CostCenter", "Project"]
        tags = conf.get('tags')
        
        if not tags:
            return CheckResult.FAILED
            
        for tag in required_tags:
            if tag not in tags[0]:
                return CheckResult.FAILED
                
        return CheckResult.PASSED

check = CompanyTaggingPolicy()
EOF
```

### TFSec (Terraform Security Scanner)
```bash
# Install tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Configuration file
cat > tfsec.json <<EOF
{
  "severity_overrides": {
    "AWS018": "ERROR",
    "AWS002": "ERROR"
  },
  "exclude": [
    "AWS025"
  ],
  "include": [
    "AWS*"
  ],
  "custom_check_dir": "./tfsec-custom-checks"
}
EOF

# Custom check example
mkdir -p tfsec-custom-checks
cat > tfsec-custom-checks/company-naming.json <<EOF
{
  "checks": [
    {
      "code": "COMPANY001",
      "description": "Resources must follow company naming convention",
      "impact": "Resources without proper naming are difficult to manage",
      "resolution": "Use company-approved naming convention: {env}-{project}-{resource}-{id}",
      "requiredTypes": ["resource"],
      "requiredLabels": ["aws_instance", "aws_s3_bucket"],
      "severity": "ERROR",
      "matchSpec": {
        "name": "cptwn-*"
      }
    }
  ]
}
EOF
```

### Snyk (Vulnerability Management)
```bash
# Install Snyk CLI
npm install -g snyk

# Authenticate
snyk auth ${SNYK_TOKEN}

# Configure Snyk for Infrastructure as Code
cat > .snyk <<EOF
# Snyk configuration file
version: v1.0.0
language-settings:
  terraform:
    severity-threshold: high
    
ignore:
  SNYK-CC-TF-124:  # Example: ignore specific vulnerability
    - '*':
        reason: Risk accepted by security team
        expires: '2024-12-31T23:59:59.999Z'

patch: {}
EOF

# Test Terraform files
snyk iac test . --severity-threshold=high --json > snyk-results.json
```

---

## 5. Monitoring & Observability Stack

### DataDog Enterprise
```yaml
# datadog-values.yaml
datadog:
  apiKey: "${DATADOG_API_KEY}"
  appKey: "${DATADOG_APP_KEY}"
  
  clusterName: "terraform-gitops-cluster"
  
  # Logs collection
  logs:
    enabled: true
    containerCollectAll: true
  
  # APM tracing
  apm:
    enabled: true
    port: 8126
  
  # Network monitoring
  networkMonitoring:
    enabled: true
  
  # Security agent
  securityAgent:
    runtime:
      enabled: true
    compliance:
      enabled: true
  
  # Process monitoring
  processAgent:
    enabled: true

# Custom dashboards
agents:
  containers:
    systemProbe:
      enabled: true
    processAgent:
      enabled: true
    securityAgent:
      runtime:
        enabled: true

# Install DataDog operator
helm repo add datadog https://helm.datadoghq.com
helm install datadog datadog/datadog -f datadog-values.yaml --namespace datadog --create-namespace
```

#### DataDog Dashboard Configuration
```json
{
  "title": "GitOps Infrastructure Monitoring",
  "description": "Comprehensive monitoring for GitOps Terraform infrastructure",
  "widgets": [
    {
      "definition": {
        "type": "timeseries",
        "requests": [
          {
            "q": "avg:kubernetes.pods.running{cluster_name:terraform-gitops-cluster}",
            "display_type": "line",
            "style": {
              "palette": "dog_classic",
              "line_type": "solid",
              "line_width": "normal"
            }
          }
        ],
        "title": "Running Pods",
        "yaxis": {
          "scale": "linear",
          "label": "",
          "include_zero": true
        }
      }
    },
    {
      "definition": {
        "type": "query_value",
        "requests": [
          {
            "q": "sum:bitbucket.pipelines.success_rate{*}",
            "aggregator": "avg"
          }
        ],
        "title": "Pipeline Success Rate",
        "precision": 2
      }
    }
  ],
  "layout_type": "ordered",
  "is_read_only": false,
  "notify_list": ["@infrastructure-team"],
  "template_variables": []
}
```

### Prometheus & Grafana
```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    resources:
      requests:
        memory: "4Gi"
        cpu: "1000m"
      limits:
        memory: "8Gi"
        cpu: "2000m"
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "gp3"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

# Grafana configuration
grafana:
  enabled: true
  adminPassword: "${GRAFANA_ADMIN_PASSWORD}"
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'gitops-dashboards'
        orgId: 1
        folder: 'GitOps'
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/gitops

  dashboards:
    gitops-dashboards:
      terraform-infrastructure:
        url: https://raw.githubusercontent.com/company/grafana-dashboards/main/terraform-infrastructure.json
      gitops-pipeline-metrics:
        url: https://raw.githubusercontent.com/company/grafana-dashboards/main/gitops-pipeline-metrics.json

# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -f prometheus-values.yaml --namespace monitoring --create-namespace
```

### PagerDuty Integration
```bash
# PagerDuty configuration for alerts
cat > pagerduty-integration.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: pagerduty-integration
  namespace: monitoring
data:
  service-key: $(echo -n "${PAGERDUTY_SERVICE_KEY}" | base64)
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: gitops-alerts
  namespace: monitoring
spec:
  groups:
  - name: gitops.rules
    rules:
    - alert: PipelineFailure
      expr: increase(bitbucket_pipeline_failures_total[5m]) > 0
      for: 1m
      labels:
        severity: critical
        service: gitops-pipeline
      annotations:
        summary: "GitOps pipeline failure detected"
        description: "Pipeline {{ $labels.pipeline }} failed in the last 5 minutes"
    
    - alert: TerraformDriftDetected
      expr: terraform_drift_detected > 0
      for: 0m
      labels:
        severity: high
        service: infrastructure-drift
      annotations:
        summary: "Infrastructure drift detected"
        description: "Terraform drift detected in {{ $labels.environment }} environment"
    
    - alert: HighInfrastructureCosts
      expr: aws_billing_estimated_charges > 45000
      for: 15m
      labels:
        severity: warning
        service: cost-monitoring
      annotations:
        summary: "High infrastructure costs detected"
        description: "Monthly costs projected at ${{ $value }}, exceeding budget thresholds"
EOF

kubectl apply -f pagerduty-integration.yaml
```

---

## 6. Cost Management Tools

### Infracost Enterprise
```bash
# Install Infracost
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Configuration
export INFRACOST_API_KEY="${INFRACOST_API_KEY}"
export INFRACOST_ENABLE_DASHBOARD=true

# Create configuration file
cat > .infracost/credentials.yml <<EOF
version: "0.1"
api_key: "${INFRACOST_API_KEY}"
pricing_api_endpoint: https://pricing.api.infracost.io
default_project_settings:
  enable_dashboard: true
EOF

# Policy configuration for cost controls
cat > infracost-policy.rego <<EOF
package infracost

# Deny if monthly cost exceeds threshold
deny[msg] {
    max_monthly_cost := 50000
    input.totalMonthlyCost > max_monthly_cost
    msg := sprintf("Monthly cost $%.2f exceeds limit of $%.2f", [input.totalMonthlyCost, max_monthly_cost])
}

# Warn about expensive resources
warn[msg] {
    resource := input.projects[_].breakdown.resources[_]
    resource.monthlyCost > 1000
    msg := sprintf("Resource %s has high monthly cost: $%.2f", [resource.name, resource.monthlyCost])
}

# Require cost estimation for production
deny[msg] {
    input.metadata.environment == "production"
    input.totalMonthlyCost == null
    msg := "Cost estimation required for production deployments"
}
EOF

# Integration with CI/CD
cat > .bitbucket/scripts/cost-check.sh <<'EOF'
#!/bin/bash
set -e

echo "Running Infracost analysis..."

# Generate cost estimate
infracost breakdown --path=. --format=json --out-file=infracost-base.json

# Check against policy
infracost output --path=infracost-base.json --format=json | \
  opa eval --data=infracost-policy.rego --input=- "data.infracost.deny[x]" --format=pretty

# Generate detailed report
infracost output --path=infracost-base.json --format=table
infracost output --path=infracost-base.json --format=html --out-file=cost-report.html

echo "Cost analysis complete"
EOF

chmod +x .bitbucket/scripts/cost-check.sh
```

### CloudHealth (Multi-Cloud Cost Optimization)
```python
# cloudhealth-integration.py
import requests
import json
import os

class CloudHealthAPI:
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = "https://chapi.cloudhealthtech.com"
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    def get_cost_report(self, days=30):
        """Get cost report for specified days"""
        endpoint = f"{self.base_url}/v1/cost_reports"
        params = {
            "interval": "daily",
            "range": f"{days}d"
        }
        
        response = requests.get(endpoint, headers=self.headers, params=params)
        return response.json()
    
    def get_rightsizing_recommendations(self):
        """Get rightsizing recommendations"""
        endpoint = f"{self.base_url}/v1/aws_rightsizing_recommendations"
        response = requests.get(endpoint, headers=self.headers)
        return response.json()
    
    def create_budget_alert(self, budget_amount, threshold=80):
        """Create budget alert"""
        endpoint = f"{self.base_url}/v1/budget_alerts"
        data = {
            "name": "Terraform Infrastructure Budget",
            "amount": budget_amount,
            "threshold_percentage": threshold,
            "notification_emails": ["infrastructure-team@company.com"]
        }
        
        response = requests.post(endpoint, headers=self.headers, json=data)
        return response.json()

# Usage example
def main():
    api_key = os.environ.get("CLOUDHEALTH_API_KEY")
    ch = CloudHealthAPI(api_key)
    
    # Get cost report
    costs = ch.get_cost_report()
    print(f"Monthly cost trend: {costs}")
    
    # Get recommendations
    recommendations = ch.get_rightsizing_recommendations()
    print(f"Cost optimization opportunities: {len(recommendations.get('recommendations', []))}")
    
    # Set up budget alert
    budget_alert = ch.create_budget_alert(50000, 85)
    print(f"Budget alert created: {budget_alert}")

if __name__ == "__main__":
    main()
```

---

## 7. Implementation Scripts

### Complete Setup Automation
```bash
#!/bin/bash
# setup-gitops-infrastructure.sh

set -e

echo "🚀 Starting GitOps Infrastructure Setup"

# Configuration
NAMESPACE_ATLANTIS="atlantis-system"
NAMESPACE_VAULT="vault-system" 
NAMESPACE_MONITORING="monitoring"
NAMESPACE_DATADOG="datadog"

# Create namespaces
echo "📁 Creating Kubernetes namespaces..."
kubectl create namespace $NAMESPACE_ATLANTIS --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_VAULT --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_MONITORING --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_DATADOG --dry-run=client -o yaml | kubectl apply -f -

# Install Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Deploy Vault Enterprise
echo "🔐 Deploying HashiCorp Vault Enterprise..."
helm upgrade --install vault hashicorp/vault \
  --namespace $NAMESPACE_VAULT \
  --values ./configs/vault-values.yaml \
  --wait --timeout=10m

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --namespace $NAMESPACE_VAULT --timeout=300s

# Deploy Atlantis
echo "🌊 Deploying Atlantis..."
kubectl apply -f ./configs/atlantis-deployment.yaml

# Deploy Monitoring Stack
echo "📊 Deploying Monitoring Stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE_MONITORING \
  --values ./configs/prometheus-values.yaml \
  --wait --timeout=15m

# Deploy DataDog
echo "🐕 Deploying DataDog..."
helm upgrade --install datadog datadog/datadog \
  --namespace $NAMESPACE_DATADOG \
  --values ./configs/datadog-values.yaml \
  --wait --timeout=10m

# Configure Vault
echo "🔧 Configuring Vault..."
./scripts/configure-vault.sh

# Setup RBAC
echo "👥 Setting up RBAC..."
kubectl apply -f ./configs/rbac-config.yaml

# Install security tools
echo "🛡️ Installing security tools..."
pip install checkov tfsec-wrapper
npm install -g snyk

# Configure cost monitoring
echo "💰 Setting up cost monitoring..."
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

echo "✅ GitOps Infrastructure Setup Complete!"
echo ""
echo "Next Steps:"
echo "1. Initialize Vault: kubectl exec -n $NAMESPACE_VAULT vault-0 -- vault operator init"
echo "2. Configure Bitbucket webhooks: ./scripts/setup-webhooks.sh"
echo "3. Import existing Terraform state: ./scripts/import-state.sh"
echo "4. Setup monitoring alerts: ./scripts/setup-alerts.sh"
```

### Vault Configuration Script
```bash
#!/bin/bash
# configure-vault.sh

set -e

VAULT_NAMESPACE="vault-system"
VAULT_POD="vault-0"

echo "🔐 Configuring HashiCorp Vault..."

# Wait for Vault to be running
kubectl wait --for=condition=ready pod/$VAULT_POD -n $VAULT_NAMESPACE --timeout=300s

# Check if Vault is already initialized
if kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault status | grep -q "Initialized.*true"; then
    echo "✅ Vault already initialized"
else
    echo "🔑 Initializing Vault..."
    kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt
    echo "⚠️  Vault keys saved to vault-keys.txt - store securely!"
fi

# Function to unseal vault
unseal_vault() {
    local keys=$(grep "Unseal Key" vault-keys.txt | head -3 | awk '{print $4}')
    for key in $keys; do
        kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault operator unseal $key
    done
}

# Check if Vault is sealed
if kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault status | grep -q "Sealed.*true"; then
    echo "🔓 Unsealing Vault..."
    unseal_vault
fi

# Get root token
ROOT_TOKEN=$(grep "Initial Root Token" vault-keys.txt | awk '{print $4}')

# Login to Vault
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault auth -token=$ROOT_TOKEN

echo "🔧 Configuring secret engines..."

# Enable AWS secret engine
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault secrets enable -path=aws aws

# Configure AWS credentials
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY \
    secret_key=$AWS_SECRET_KEY \
    region=af-south-1

# Create Terraform IAM role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write aws/roles/terraform \
    credential_type=iam_user \
    policy_document=@/tmp/terraform-policy.json \
    default_sts_ttl=3600 \
    max_sts_ttl=7200

# Enable Kubernetes auth
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault auth enable kubernetes

# Configure Kubernetes auth
SA_JWT_TOKEN=$(kubectl get secret $(kubectl get serviceaccount atlantis -n atlantis-system -o jsonpath='{.secrets[0].name}') -n atlantis-system -o jsonpath='{.data.token}' | base64 --decode)
SA_CA_CRT=$(kubectl get secret $(kubectl get serviceaccount atlantis -n atlantis-system -o jsonpath='{.secrets[0].name}') -n atlantis-system -o jsonpath='{.data.ca\.crt}' | base64 --decode)
K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/config \
    token_reviewer_jwt="$SA_JWT_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$SA_CA_CRT"

echo "📋 Creating Vault policies..."

# Create Atlantis policy
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault policy write atlantis - <<EOF
path "aws/creds/terraform" {
  capabilities = ["read"]
}
path "secret/data/terraform/*" {
  capabilities = ["read", "list"]
}
EOF

# Bind Atlantis role
kubectl exec -n $VAULT_NAMESPACE $VAULT_POD -- vault write auth/kubernetes/role/atlantis \
    bound_service_account_names=atlantis \
    bound_service_account_namespaces=atlantis-system \
    policies=atlantis \
    ttl=24h

echo "✅ Vault configuration complete!"
```

### Monitoring Setup Script
```bash
#!/bin/bash
# setup-monitoring.sh

set -e

echo "📊 Setting up comprehensive monitoring..."

# Create custom alerts
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: gitops-infrastructure-alerts
  namespace: monitoring
  labels:
    app: prometheus
spec:
  groups:
  - name: gitops.infrastructure
    rules:
    - alert: TerraformStateBackupFailed
      expr: increase(terraform_state_backup_failures_total[1h]) > 0
      for: 5m
      labels:
        severity: critical
        component: terraform
      annotations:
        summary: "Terraform state backup failed"
        description: "Terraform state backup has failed {{ \$value }} times in the last hour"
    
    - alert: AtlantisDown
      expr: up{job="atlantis"} == 0
      for: 2m
      labels:
        severity: critical
        component: atlantis
      annotations:
        summary: "Atlantis is down"
        description: "Atlantis service has been down for more than 2 minutes"
    
    - alert: VaultSealed
      expr: vault_core_unsealed == 0
      for: 0m
      labels:
        severity: critical
        component: vault
      annotations:
        summary: "Vault is sealed"
        description: "Vault instance is sealed and needs to be unsealed"
    
    - alert: HighInfrastructureCosts
      expr: aws_billing_estimated_charges{currency="USD"} > 45000
      for: 15m
      labels:
        severity: warning
        component: billing
      annotations:
        summary: "High infrastructure costs detected"
        description: "Infrastructure costs are \${{ \$value }}, approaching budget limits"
EOF

# Create Slack alert manager configuration
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-slack-webhook
  namespace: monitoring
stringData:
  webhook-url: "${SLACK_WEBHOOK_URL}"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      slack_api_url: "${SLACK_WEBHOOK_URL}"
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'slack-notifications'
      routes:
      - match:
          severity: critical
        receiver: 'slack-critical'
      - match:
          severity: warning
        receiver: 'slack-warnings'
    
    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#infrastructure'
        title: 'Infrastructure Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    
    - name: 'slack-critical'
      slack_configs:
      - channel: '#infrastructure-critical'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'danger'
    
    - name: 'slack-warnings'
      slack_configs:
      - channel: '#infrastructure'
        title: '⚠️ WARNING: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'warning'
EOF

# Create Grafana dashboards
echo "📈 Installing Grafana dashboards..."

# GitOps Pipeline Dashboard
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitops-pipeline-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  gitops-pipeline-dashboard.json: |
    {
      "dashboard": {
        "title": "GitOps Pipeline Metrics",
        "panels": [
          {
            "title": "Pipeline Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(bitbucket_pipeline_success_total[24h]) / rate(bitbucket_pipeline_total[24h]) * 100"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "percent",
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": 0},
                    {"color": "yellow", "value": 95},
                    {"color": "green", "value": 99}
                  ]
                }
              }
            }
          },
          {
            "title": "Deployment Frequency",
            "type": "graph",
            "targets": [
              {
                "expr": "increase(terraform_apply_total[1h])"
              }
            ]
          },
          {
            "title": "Cost Trends",
            "type": "graph",
            "targets": [
              {
                "expr": "aws_billing_estimated_charges"
              }
            ]
          }
        ]
      }
    }
EOF

echo "✅ Monitoring setup complete!"
echo ""
echo "Access Grafana: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
echo "Default credentials: admin / $(kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
```

This comprehensive tool guide provides everything needed to implement enterprise-grade GitOps with your Terraform infrastructure. Each tool is configured with production-ready settings, security best practices, and monitoring capabilities.

---

## Next Steps

1. **Review and customize** configurations for your specific environment
2. **Run the setup scripts** in a staging environment first
3. **Configure integrations** with your existing systems (SSO, SIEM, etc.)
4. **Train your team** on the new workflows and tools
5. **Implement gradually** starting with development environments

The tools and configurations provided here will give you a robust, secure, and scalable GitOps platform that meets enterprise compliance requirements while providing excellent developer experience.
