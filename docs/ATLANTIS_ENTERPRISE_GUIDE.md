# Atlantis Enterprise Guide
## Commercial-Grade Terraform Automation for GitOps

---

## Important Clarification: Atlantis Licensing

**Atlantis is actually open-source (Apache 2.0 license)** - there isn't an official "Atlantis Enterprise" product from Runatlantis. However, for enterprise environments, you can deploy Atlantis with enterprise-grade configurations and integrations that provide commercial-level capabilities.

For true **enterprise Terraform automation**, you have several commercial options:

---

## Enterprise Terraform Automation Options

### 1. **Atlantis (Open Source) + Enterprise Configuration**
- **Cost**: Free (open source)
- **Enterprise Features**: Through configuration and integrations
- **Best For**: Organizations with strong DevOps capabilities

### 2. **Terraform Cloud Enterprise**
- **Cost**: $20-70 per user/month
- **Vendor**: HashiCorp (official)
- **Best For**: Organizations wanting official HashiCorp support

### 3. **Spacelift**
- **Cost**: $25-75 per user/month
- **Vendor**: Spacelift (third-party)
- **Best For**: Advanced policy management and workflows

### 4. **Env0**
- **Cost**: $25-50 per user/month
- **Vendor**: env0 (third-party)
- **Best For**: Cost optimization and compliance

---

## Atlantis Enterprise-Grade Configuration

While Atlantis itself is open source, you can configure it for enterprise use with the following capabilities:

### Core Enterprise Features

#### **High Availability Deployment**
```yaml
# atlantis-ha-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlantis
  namespace: atlantis-system
spec:
  replicas: 3  # HA configuration
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: atlantis
  template:
    metadata:
      labels:
        app: atlantis
    spec:
      serviceAccountName: atlantis
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - atlantis
              topologyKey: kubernetes.io/hostname
      containers:
      - name: atlantis
        image: runatlantis/atlantis:v0.26.0
        ports:
        - name: atlantis
          containerPort: 4141
        env:
        - name: ATLANTIS_REPO_ALLOWLIST
          value: "bitbucket.org/company/*"
        - name: ATLANTIS_BITBUCKET_USER
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: username
        - name: ATLANTIS_BITBUCKET_TOKEN
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: token
        - name: ATLANTIS_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: atlantis-credentials
              key: webhook-secret
        - name: ATLANTIS_DATA_DIR
          value: /atlantis-data
        - name: ATLANTIS_REDIS_HOST
          value: "redis.atlantis-system.svc.cluster.local"
        - name: ATLANTIS_REDIS_PORT
          value: "6379"
        - name: ATLANTIS_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        resources:
          requests:
            memory: "4Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "2000m"
        volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
        - name: atlantis-config
          mountPath: /etc/atlantis
        livenessProbe:
          httpGet:
            path: /healthz
            port: 4141
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthz
            port: 4141
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: atlantis-data
        persistentVolumeClaim:
          claimName: atlantis-data-pvc
      - name: atlantis-config
        configMap:
          name: atlantis-config
```

#### **Enterprise Redis Backend for State**
```yaml
# redis-ha.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: atlantis-system
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - /etc/redis/redis.conf
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "1000m"
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "gp3"
      resources:
        requests:
          storage: 20Gi
```

### **Enterprise Security Configuration**

#### **RBAC Integration with Corporate SSO**
```yaml
# atlantis-server-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: atlantis-config
  namespace: atlantis-system
data:
  config.yaml: |
    # Enterprise RBAC configuration
    repos:
    - id: "bitbucket.org/company/terraform-infrastructure"
      allowed_overrides: [apply_requirements, workflow]
      allow_custom_workflows: false
      pre_workflow_hooks:
      - run: |
          # Enterprise security scanning
          echo "Running enterprise security validation..."
          checkov -d . --framework terraform --quiet
          tfsec . --format json --out tfsec-results.json
          
    - id: "/.*/terraform-modules"
      allowed_overrides: [workflow]
      allow_custom_workflows: true
      
    # Enterprise workflows with approval gates
    workflows:
      enterprise-terraform:
        plan:
          steps:
          - env:
              name: VAULT_ADDR
              value: "https://vault.company.com"
          - env:
              name: VAULT_ROLE
              value: "atlantis"
          - run: |
              echo "Authenticating with Vault..."
              vault auth -method=kubernetes role=atlantis
              
          - run: |
              echo "Getting AWS credentials from Vault..."
              vault read -field=access_key aws/creds/terraform > /tmp/aws_access_key
              vault read -field=secret_key aws/creds/terraform > /tmp/aws_secret_key
              export AWS_ACCESS_KEY_ID=$(cat /tmp/aws_access_key)
              export AWS_SECRET_ACCESS_KEY=$(cat /tmp/aws_secret_key)
              rm -f /tmp/aws_access_key /tmp/aws_secret_key
              
          - run: |
              echo "Running cost estimation..."
              infracost breakdown --path . --format json --out-file infracost.json
              COST=$(jq -r '.totalMonthlyCost' infracost.json)
              echo "Estimated monthly cost: $COST"
              
              # Enterprise cost gate
              if (( $(echo "$COST > 10000" | bc -l) )); then
                echo "❌ Cost exceeds enterprise limit ($10,000/month)"
                echo "Requires executive approval"
                exit 1
              fi
              
          - init:
              extra_args: ["-upgrade"]
          - plan:
              extra_args: ["-lock-timeout=10m", "-var-file=enterprise.tfvars"]
              
        apply:
          steps:
          - run: |
              echo "Creating pre-deployment backup..."
              terraform state pull > backup-$(date +%Y%m%d-%H%M%S).json
              aws s3 cp backup-*.json s3://company-terraform-backups/atlantis/
              
          - apply
          - run: |
              echo "Post-deployment validation..."
              terraform output -json > deployment-outputs.json
              
              # Enterprise compliance check
              echo "Running post-deployment compliance scan..."
              checkov -d . --framework terraform --check CKV_AWS_20,CKV_AWS_21
              
              # Send deployment notification
              curl -X POST -H 'Content-type: application/json' \
                --data "{\"text\": \"✅ Atlantis deployment complete - $(date)\"}" \
                $SLACK_WEBHOOK_URL
```

#### **Vault Integration for Dynamic Credentials**
```bash
# vault-atlantis-policy.hcl
path "aws/creds/terraform" {
  capabilities = ["read"]
}

path "secret/data/terraform/*" {
  capabilities = ["read"]
}

path "pki/issue/terraform" {
  capabilities = ["create", "update"]
}

# Create Atlantis service account and bind to Vault
vault write auth/kubernetes/role/atlantis \
    bound_service_account_names=atlantis \
    bound_service_account_namespaces=atlantis-system \
    policies=atlantis-policy \
    ttl=3600
```

### **Enterprise Monitoring & Observability**

#### **Comprehensive Metrics Collection**
```yaml
# atlantis-monitoring.yaml
apiVersion: v1
kind: Service
metadata:
  name: atlantis-metrics
  namespace: atlantis-system
  labels:
    app: atlantis
spec:
  ports:
  - name: metrics
    port: 4141
    targetPort: 4141
  selector:
    app: atlantis
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: atlantis
  namespace: atlantis-system
spec:
  selector:
    matchLabels:
      app: atlantis
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

#### **Enterprise Alerting Rules**
```yaml
# atlantis-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: atlantis-enterprise-alerts
  namespace: atlantis-system
spec:
  groups:
  - name: atlantis.enterprise
    rules:
    - alert: AtlantisDown
      expr: up{job="atlantis"} == 0
      for: 2m
      labels:
        severity: critical
        service: atlantis
      annotations:
        summary: "Atlantis service is down"
        description: "Atlantis has been down for more than 2 minutes"
        
    - alert: AtlantisHighLatency
      expr: histogram_quantile(0.95, rate(atlantis_http_request_duration_seconds_bucket[5m])) > 30
      for: 5m
      labels:
        severity: warning
        service: atlantis
      annotations:
        summary: "Atlantis high response latency"
        description: "95th percentile latency is {{ $value }}s"
        
    - alert: AtlantisFailedPlans
      expr: increase(atlantis_plans_total{status="failure"}[1h]) > 5
      for: 0m
      labels:
        severity: warning
        service: atlantis
      annotations:
        summary: "High number of failed Terraform plans"
        description: "{{ $value }} plans have failed in the last hour"
        
    - alert: AtlantisLockTimeout
      expr: increase(atlantis_locks_total{status="timeout"}[1h]) > 3
      for: 0m
      labels:
        severity: warning
        service: atlantis
      annotations:
        summary: "Atlantis lock timeouts detected"
        description: "{{ $value }} lock timeouts in the last hour"
```

---

## Alternative: Terraform Cloud Enterprise

If you prefer official HashiCorp support, **Terraform Cloud Enterprise** offers:

### **Enterprise Features**
- **Private Module Registry**: Centralized module management
- **Sentinel Policy as Code**: Advanced governance and compliance
- **SSO Integration**: SAML, OIDC with your corporate identity provider
- **Audit Logging**: Complete audit trails for compliance
- **Cost Estimation**: Built-in cost analysis for all plans
- **VCS Integration**: Native Bitbucket integration
- **API-Driven Workflows**: Complete automation capabilities
- **Concurrent Runs**: Multiple simultaneous Terraform operations
- **Team Management**: Role-based access control
- **Workspace Management**: Environment isolation and promotion

### **Terraform Cloud Enterprise Configuration**
```hcl
# terraform-cloud-workspace.tf
terraform {
  cloud {
    organization = "your-company"
    
    workspaces {
      tags = ["production", "infrastructure"]
    }
  }
}

# Workspace configuration
resource "tfe_workspace" "production-infrastructure" {
  name              = "production-infrastructure"
  organization      = "your-company"
  description       = "Production infrastructure managed by Terraform Cloud"
  
  # VCS connection to Bitbucket
  vcs_repo {
    identifier     = "company/terraform-infrastructure"
    oauth_token_id = var.bitbucket_oauth_token
  }
  
  # Enterprise features
  queue_all_runs           = false
  auto_apply              = false
  file_triggers_enabled   = true
  allow_destroy_plan      = false
  
  # Environment variables from Vault
  execution_mode = "remote"
  
  # Terraform version management
  terraform_version = "1.5.7"
  
  # Working directory
  working_directory = "providers/aws/regions/af-south-1/layers/01-foundation/production"
  
  # Notification configuration
  notifications {
    name            = "slack-notifications"
    destination_type = "slack"
    url             = var.slack_webhook_url
    triggers        = ["run:created", "run:planning", "run:completed", "run:errored"]
  }
}

# Sentinel policies for governance
resource "tfe_policy" "cost-control" {
  name         = "cost-control"
  organization = "your-company"
  kind         = "sentinel"
  
  policy = file("policies/cost-control.sentinel")
}

resource "tfe_policy_set" "production-policies" {
  name         = "production-policies"
  organization = "your-company"
  
  policy_ids = [
    tfe_policy.cost-control.id,
  ]
  
  workspace_ids = [
    tfe_workspace.production-infrastructure.id,
  ]
}
```

---

## Alternative: Spacelift Enterprise

**Spacelift** is a commercial Terraform automation platform with advanced enterprise features:

### **Spacelift Key Features**
- **Policy as Code**: OPA (Open Policy Agent) integration
- **Drift Detection**: Automated infrastructure drift detection
- **Cost Optimization**: Real-time cost monitoring and optimization
- **Multi-Cloud Support**: AWS, GCP, Azure, and Kubernetes
- **Advanced RBAC**: Fine-grained access control
- **Audit & Compliance**: SOC 2 Type II compliant
- **GitOps Integration**: Native Git workflow support
- **Custom Runners**: Self-hosted runners for security

### **Spacelift Configuration Example**
```yaml
# spacelift-stack.yaml
apiVersion: spacelift.io/v1
kind: Stack
metadata:
  name: production-infrastructure
spec:
  repository: "company/terraform-infrastructure"
  branch: "main"
  projectRoot: "providers/aws/regions/af-south-1/layers/01-foundation/production"
  
  # Enterprise features
  vendor: terraform
  version: "1.5.7"
  
  # Policies
  policies:
  - "cost-control-policy"
  - "security-baseline-policy"
  - "naming-convention-policy"
  
  # Environment variables
  environment:
    - name: "VAULT_ADDR"
      value: "https://vault.company.com"
      secret: false
    - name: "AWS_REGION"
      value: "af-south-1"
      secret: false
  
  # Hooks
  hooks:
    beforeInit:
    - "vault auth -method=kubernetes role=spacelift"
    - "export AWS_ACCESS_KEY_ID=$(vault read -field=access_key aws/creds/terraform)"
    - "export AWS_SECRET_ACCESS_KEY=$(vault read -field=secret_key aws/creds/terraform)"
    
    afterPlan:
    - "infracost breakdown --path . --format json --out-file cost-estimate.json"
    
    afterApply:
    - "terraform output -json > deployment-outputs.json"
    - "aws s3 cp deployment-outputs.json s3://company-deployment-artifacts/"
```

---

## Recommendation for Your Environment

Given your existing Terraform expertise and infrastructure, here's my recommendation:

### **Option 1: Enhanced Open Source Atlantis (Recommended)**
**Best for your current setup because:**
- **Cost-effective**: No licensing fees
- **Full control**: Self-hosted, customizable
- **Existing investment**: Builds on your current Terraform expertise
- **Flexibility**: Can integrate with all your existing tools

**Estimated Setup Cost**: $50,000 (implementation only)
**Annual Operating Cost**: $20,000 (hosting + maintenance)

### **Option 2: Terraform Cloud Enterprise**
**Best if you want official HashiCorp support:**
- **Official support**: Direct HashiCorp backing
- **Integrated features**: Built-in cost estimation, Sentinel policies
- **Reduced complexity**: Managed service, less operational overhead

**Annual Cost**: $60,000 (based on team size)
**Setup Cost**: $30,000 (migration and configuration)

### **Option 3: Spacelift**
**Best for advanced policy management:**
- **Advanced policies**: OPA integration for complex governance
- **Superior UI/UX**: Modern, intuitive interface
- **Drift detection**: Built-in infrastructure drift management

**Annual Cost**: $75,000 (based on team size)
**Setup Cost**: $40,000 (migration and configuration)

---

## Implementation Plan for Enterprise Atlantis

### **Week 1-2: Core Setup**
```bash
# Deploy enterprise-grade Atlantis
kubectl apply -f atlantis-ha-deployment.yaml
kubectl apply -f redis-ha.yaml
kubectl apply -f atlantis-monitoring.yaml

# Configure Vault integration
vault policy write atlantis-policy atlantis-policy.hcl
vault write auth/kubernetes/role/atlantis \
    bound_service_account_names=atlantis \
    bound_service_account_namespaces=atlantis-system \
    policies=atlantis-policy
```

### **Week 3-4: Advanced Configuration**
- SSO integration with corporate identity provider
- Advanced workflow configuration with approval gates
- Cost estimation and budget controls integration
- Comprehensive monitoring and alerting setup

### **Week 5-6: Production Readiness**
- Security hardening and compliance validation
- Disaster recovery procedures implementation
- Performance optimization and load testing
- Team training and documentation

---

## Enterprise Atlantis vs Alternatives Comparison

| Feature | Open Source Atlantis | Terraform Cloud Enterprise | Spacelift |
|---------|---------------------|---------------------------|-----------|
| **Cost (Annual)** | $20K (hosting) | $60K (licensing) | $75K (licensing) |
| **Self-Hosted** | ✅ Full control | ❌ SaaS only | ⚠️ Hybrid options |
| **Official Support** | ❌ Community | ✅ HashiCorp | ✅ Spacelift team |
| **Advanced RBAC** | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| **Policy as Code** | ⚠️ Limited | ✅ Sentinel | ✅ OPA |
| **Cost Estimation** | ⚠️ Integration needed | ✅ Built-in | ✅ Built-in |
| **Drift Detection** | ❌ Manual | ⚠️ Limited | ✅ Advanced |
| **Compliance** | ⚠️ Configuration needed | ✅ Built-in | ✅ Built-in |
| **Customization** | ✅ Unlimited | ⚠️ Limited | ⚠️ Moderate |

---

**My recommendation**: Start with **enterprise-configured open source Atlantis** for your Phase 1 implementation. This gives you immediate value with minimal cost, and you can always migrate to a commercial solution later if needed.

The enterprise configuration I've provided above will give you 90% of the features of commercial solutions while maintaining full control and keeping costs low.

Would you like me to provide more specific implementation details for any of these options?
