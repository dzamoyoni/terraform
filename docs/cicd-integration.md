# CI/CD Integration for Scalable Terraform Architecture

## Overview

This document outlines the CI/CD integration strategy for the new scalable Terraform architecture, providing automated deployment pipelines with proper state isolation, dependency management, and safety controls.

## Architecture Benefits for CI/CD

### State Isolation Benefits
- **Parallel Deployments**: Different layers can be deployed simultaneously
- **Faster Pipelines**: Smaller state files = faster terraform operations
- **Selective Deployments**: Deploy only changed layers/clients
- **Better Testing**: Layer-specific testing and validation

### Dependency Management
- **Clear Dependencies**: Foundation → Platform → Databases → Clients
- **SSM Parameter Communication**: Cross-layer data sharing
- **Independent Rollbacks**: Layer-specific rollback capabilities
- **Environment Promotion**: Clean dev → staging → prod workflow

## CI/CD Pipeline Design

### 1. GitHub Actions Pipeline Structure

```yaml
# .github/workflows/terraform-deploy.yml
name: Terraform Multi-Layer Deployment

on:
  push:
    branches: [main, staging, development]
  pull_request:
    branches: [main, staging, development]

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.6.0

jobs:
  # ===================================================================================
  # CHANGE DETECTION
  # ===================================================================================
  detect-changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    outputs:
      foundation-changed: ${{ steps.changes.outputs.foundation }}
      platform-changed: ${{ steps.changes.outputs.platform }}
      databases-changed: ${{ steps.changes.outputs.databases }}
      applications-changed: ${{ steps.changes.outputs.applications }}
      clients-changed: ${{ steps.changes.outputs.clients }}
      client-list: ${{ steps.client-changes.outputs.clients }}
      environment: ${{ steps.env.outputs.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect Environment
        id: env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/staging" ]]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
          else
            echo "environment=development" >> $GITHUB_OUTPUT
          fi

      - name: Detect Layer Changes
        uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            foundation:
              - 'regions/*/layers/01-foundation/**'
              - 'shared/modules/foundation-layer/**'
            platform:
              - 'regions/*/layers/02-platform/**'  
              - 'shared/modules/eks-cluster/**'
              - 'shared/modules/*-irsa/**'
              - 'shared/modules/aws-load-balancer-controller/**'
              - 'shared/modules/external-dns/**'
              - 'shared/modules/route53-zones/**'
            databases:
              - 'regions/*/layers/03-databases/**'
              - 'shared/modules/database-instance/**'
            applications:
              - 'regions/*/layers/04-applications/**'
            clients:
              - 'regions/*/clients/**'
              - 'shared/modules/client-infrastructure/**'

      - name: Detect Client Changes
        id: client-changes
        run: |
          CHANGED_CLIENTS=""
          if [[ "${{ steps.changes.outputs.clients }}" == "true" ]]; then
            CHANGED_FILES=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }} | grep "regions/.*/clients/" || true)
            for file in $CHANGED_FILES; do
              CLIENT=$(echo $file | cut -d'/' -f4)
              if [[ ! " $CHANGED_CLIENTS " =~ " $CLIENT " ]]; then
                CHANGED_CLIENTS="$CHANGED_CLIENTS $CLIENT"
              fi
            done
          fi
          echo "clients=$(echo $CHANGED_CLIENTS | jq -R -s -c 'split(" ") | map(select(length > 0))')" >> $GITHUB_OUTPUT

  # ===================================================================================
  # FOUNDATION LAYER
  # ===================================================================================
  foundation:
    name: Foundation Layer
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.foundation-changed == 'true'
    environment: ${{ needs.detect-changes.outputs.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: regions/${{ env.AWS_REGION }}/layers/01-foundation/${{ needs.detect-changes.outputs.environment }}
        run: |
          terraform init -backend-config="../../../../../shared/backend-configs/${{ needs.detect-changes.outputs.environment }}.hcl"

      - name: Terraform Plan
        working-directory: regions/${{ env.AWS_REGION }}/layers/01-foundation/${{ needs.detect-changes.outputs.environment }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'
        working-directory: regions/${{ env.AWS_REGION }}/layers/01-foundation/${{ needs.detect-changes.outputs.environment }}
        run: terraform apply -auto-approve tfplan

      - name: Upload Plan Artifact
        if: github.event_name == 'pull_request'
        uses: actions/upload-artifact@v3
        with:
          name: foundation-plan-${{ needs.detect-changes.outputs.environment }}
          path: regions/${{ env.AWS_REGION }}/layers/01-foundation/${{ needs.detect-changes.outputs.environment }}/tfplan

  # ===================================================================================
  # PLATFORM LAYER
  # ===================================================================================
  platform:
    name: Platform Layer
    runs-on: ubuntu-latest
    needs: [detect-changes, foundation]
    if: |
      always() &&
      (needs.foundation.result == 'success' || needs.foundation.result == 'skipped') &&
      needs.detect-changes.outputs.platform-changed == 'true'
    environment: ${{ needs.detect-changes.outputs.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Wait for Foundation SSM Parameters
        run: |
          echo "Waiting for foundation layer SSM parameters..."
          aws ssm wait parameter-exists --name "/${{ needs.detect-changes.outputs.environment }}/${{ env.AWS_REGION }}/foundation/vpc_id"
          echo "Foundation parameters ready"

      - name: Terraform Init
        working-directory: regions/${{ env.AWS_REGION }}/layers/02-platform/${{ needs.detect-changes.outputs.environment }}
        run: |
          terraform init -backend-config="../../../../../shared/backend-configs/${{ needs.detect-changes.outputs.environment }}.hcl"

      - name: Terraform Plan
        working-directory: regions/${{ env.AWS_REGION }}/layers/02-platform/${{ needs.detect-changes.outputs.environment }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'
        working-directory: regions/${{ env.AWS_REGION }}/layers/02-platform/${{ needs.detect-changes.outputs.environment }}
        run: terraform apply -auto-approve tfplan

  # ===================================================================================
  # DATABASE LAYER
  # ===================================================================================
  databases:
    name: Database Layer
    runs-on: ubuntu-latest
    needs: [detect-changes, foundation, platform]
    if: |
      always() &&
      (needs.platform.result == 'success' || needs.platform.result == 'skipped') &&
      needs.detect-changes.outputs.databases-changed == 'true'
    environment: ${{ needs.detect-changes.outputs.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: regions/${{ env.AWS_REGION }}/layers/03-databases/${{ needs.detect-changes.outputs.environment }}
        run: |
          terraform init -backend-config="../../../../../shared/backend-configs/${{ needs.detect-changes.outputs.environment }}.hcl"

      - name: Terraform Plan
        working-directory: regions/${{ env.AWS_REGION }}/layers/03-databases/${{ needs.detect-changes.outputs.environment }}
        env:
          TF_VAR_mtn_ghana_db_password: ${{ secrets.MTN_GHANA_DB_PASSWORD }}
          TF_VAR_ezra_db_password: ${{ secrets.EZRA_DB_PASSWORD }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'
        working-directory: regions/${{ env.AWS_REGION }}/layers/03-databases/${{ needs.detect-changes.outputs.environment }}
        env:
          TF_VAR_mtn_ghana_db_password: ${{ secrets.MTN_GHANA_DB_PASSWORD }}
          TF_VAR_ezra_db_password: ${{ secrets.EZRA_DB_PASSWORD }}
        run: terraform apply -auto-approve tfplan

  # ===================================================================================
  # CLIENT LAYERS
  # ===================================================================================
  clients:
    name: Client Layer - ${{ matrix.client }}
    runs-on: ubuntu-latest
    needs: [detect-changes, foundation, platform]
    if: |
      always() &&
      (needs.platform.result == 'success' || needs.platform.result == 'skipped') &&
      needs.detect-changes.outputs.clients-changed == 'true'
    strategy:
      matrix:
        client: ${{ fromJson(needs.detect-changes.outputs.client-list) }}
    environment: ${{ needs.detect-changes.outputs.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Wait for Platform SSM Parameters
        run: |
          echo "Waiting for platform layer SSM parameters..."
          aws ssm wait parameter-exists --name "/${{ needs.detect-changes.outputs.environment }}/${{ env.AWS_REGION }}/platform/cluster_name"
          echo "Platform parameters ready"

      - name: Terraform Init
        working-directory: regions/${{ env.AWS_REGION }}/clients/${{ matrix.client }}/${{ needs.detect-changes.outputs.environment }}
        run: |
          terraform init -backend-config="../../../../../../shared/backend-configs/${{ needs.detect-changes.outputs.environment }}.hcl"

      - name: Terraform Plan
        working-directory: regions/${{ env.AWS_REGION }}/clients/${{ matrix.client }}/${{ needs.detect-changes.outputs.environment }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/staging'
        working-directory: regions/${{ env.AWS_REGION }}/clients/${{ matrix.client }}/${{ needs.detect-changes.outputs.environment }}
        run: terraform apply -auto-approve tfplan

  # ===================================================================================
  # INTEGRATION TESTS
  # ===================================================================================
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: [detect-changes, foundation, platform, databases, clients]
    if: always() && github.ref == 'refs/heads/main'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Test Cross-Layer Communication
        run: |
          echo "Testing SSM parameter availability..."
          aws ssm get-parameters-by-path --path "/production/us-east-1/foundation" --recursive
          aws ssm get-parameters-by-path --path "/production/us-east-1/platform" --recursive
          
          echo "Testing EKS cluster connectivity..."
          aws eks update-kubeconfig --region us-east-1 --name us-test-cluster-01
          kubectl cluster-info
          kubectl get nodes
          
          echo "Testing client namespaces..."
          kubectl get namespaces | grep -E "(mtn-ghana|ezra)" || echo "Client namespaces not found"

      - name: Notify Teams
        if: failure()
        run: |
          echo "Integration tests failed. Notifying teams..."
          # Add Slack/Teams notification here
```

### 2. GitLab CI Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - detect
  - foundation
  - platform
  - databases
  - clients
  - test

variables:
  AWS_REGION: "us-east-1"
  TERRAFORM_VERSION: "1.6.0"

# ===================================================================================
# CHANGE DETECTION
# ===================================================================================
detect-changes:
  stage: detect
  image: alpine:latest
  script:
    - apk add --no-cache git jq
    - |
      ENVIRONMENT="development"
      if [[ "$CI_COMMIT_REF_NAME" == "main" ]]; then
        ENVIRONMENT="production"
      elif [[ "$CI_COMMIT_REF_NAME" == "staging" ]]; then
        ENVIRONMENT="staging"
      fi
      echo "ENVIRONMENT=$ENVIRONMENT" > environment.env
      
      # Detect changes
      git diff --name-only $CI_COMMIT_BEFORE_SHA $CI_COMMIT_SHA > changed_files.txt
      
      if grep -q "regions/.*/layers/01-foundation/" changed_files.txt; then
        echo "FOUNDATION_CHANGED=true" >> changes.env
      fi
      
      if grep -q "regions/.*/layers/02-platform/" changed_files.txt; then
        echo "PLATFORM_CHANGED=true" >> changes.env
      fi
      
      if grep -q "regions/.*/clients/" changed_files.txt; then
        echo "CLIENTS_CHANGED=true" >> changes.env
        # Extract client names
        CLIENTS=$(grep "regions/.*/clients/" changed_files.txt | cut -d'/' -f4 | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))')
        echo "CLIENT_LIST=$CLIENTS" >> changes.env
      fi
  artifacts:
    reports:
      dotenv:
        - environment.env
        - changes.env

# ===================================================================================
# FOUNDATION LAYER
# ===================================================================================
foundation-deploy:
  stage: foundation
  image:
    name: hashicorp/terraform:$TERRAFORM_VERSION
    entrypoint: [""]
  rules:
    - if: $FOUNDATION_CHANGED == "true"
  before_script:
    - cd regions/$AWS_REGION/layers/01-foundation/$ENVIRONMENT
    - terraform init -backend-config="../../../../../shared/backend-configs/$ENVIRONMENT.hcl"
  script:
    - terraform plan -out=tfplan
    - |
      if [[ "$CI_COMMIT_REF_NAME" == "main" || "$CI_COMMIT_REF_NAME" == "staging" ]]; then
        terraform apply -auto-approve tfplan
      fi
  artifacts:
    paths:
      - regions/$AWS_REGION/layers/01-foundation/$ENVIRONMENT/tfplan
    expire_in: 1 hour

# ===================================================================================
# PLATFORM LAYER
# ===================================================================================
platform-deploy:
  stage: platform
  image:
    name: hashicorp/terraform:$TERRAFORM_VERSION
    entrypoint: [""]
  rules:
    - if: $PLATFORM_CHANGED == "true"
  needs:
    - foundation-deploy
  before_script:
    - cd regions/$AWS_REGION/layers/02-platform/$ENVIRONMENT
    - terraform init -backend-config="../../../../../shared/backend-configs/$ENVIRONMENT.hcl"
  script:
    - terraform plan -out=tfplan
    - |
      if [[ "$CI_COMMIT_REF_NAME" == "main" || "$CI_COMMIT_REF_NAME" == "staging" ]]; then
        terraform apply -auto-approve tfplan
      fi

# ===================================================================================
# CLIENT DEPLOYMENTS
# ===================================================================================
.client-deploy-template: &client-deploy
  stage: clients
  image:
    name: hashicorp/terraform:$TERRAFORM_VERSION
    entrypoint: [""]
  needs:
    - platform-deploy
  before_script:
    - cd regions/$AWS_REGION/clients/$CLIENT_NAME/$ENVIRONMENT
    - terraform init -backend-config="../../../../../../shared/backend-configs/$ENVIRONMENT.hcl"
  script:
    - terraform plan -out=tfplan
    - |
      if [[ "$CI_COMMIT_REF_NAME" == "main" || "$CI_COMMIT_REF_NAME" == "staging" ]]; then
        terraform apply -auto-approve tfplan
      fi

mtn-ghana-deploy:
  <<: *client-deploy
  variables:
    CLIENT_NAME: "mtn-ghana"
  rules:
    - if: $CLIENTS_CHANGED == "true" && $CLIENT_LIST =~ /mtn-ghana/

ezra-deploy:
  <<: *client-deploy
  variables:
    CLIENT_NAME: "ezra"
  rules:
    - if: $CLIENTS_CHANGED == "true" && $CLIENT_LIST =~ /ezra/
```

### 3. Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - staging
      - development

variables:
  - name: AWS_REGION
    value: us-east-1
  - name: TERRAFORM_VERSION
    value: 1.6.0

stages:
  - stage: DetectChanges
    displayName: 'Detect Changes'
    jobs:
      - job: DetectChanges
        displayName: 'Detect Layer Changes'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - checkout: self
            fetchDepth: 0
          
          - script: |
              ENVIRONMENT="development"
              if [[ "$(Build.SourceBranch)" == "refs/heads/main" ]]; then
                ENVIRONMENT="production"
              elif [[ "$(Build.SourceBranch)" == "refs/heads/staging" ]]; then
                ENVIRONMENT="staging"
              fi
              echo "##vso[task.setvariable variable=ENVIRONMENT;isOutput=true]$ENVIRONMENT"
              
              # Detect changes and set pipeline variables
              git diff --name-only HEAD~1 HEAD > changed_files.txt
              
              if grep -q "regions/.*/layers/01-foundation/" changed_files.txt; then
                echo "##vso[task.setvariable variable=FOUNDATION_CHANGED;isOutput=true]true"
              fi
              
              if grep -q "regions/.*/layers/02-platform/" changed_files.txt; then
                echo "##vso[task.setvariable variable=PLATFORM_CHANGED;isOutput=true]true"
              fi
            name: detectChanges
            displayName: 'Detect Changes'

  - stage: Foundation
    displayName: 'Foundation Layer'
    condition: eq(dependencies.DetectChanges.outputs['DetectChanges.detectChanges.FOUNDATION_CHANGED'], 'true')
    dependsOn: DetectChanges
    variables:
      ENVIRONMENT: $[ dependencies.DetectChanges.outputs['DetectChanges.detectChanges.ENVIRONMENT'] ]
    jobs:
      - deployment: FoundationDeploy
        displayName: 'Deploy Foundation'
        environment: $(ENVIRONMENT)
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: TerraformInstaller@0
                  inputs:
                    terraformVersion: $(TERRAFORM_VERSION)
                - script: |
                    cd regions/$(AWS_REGION)/layers/01-foundation/$(ENVIRONMENT)
                    terraform init -backend-config="../../../../../shared/backend-configs/$(ENVIRONMENT).hcl"
                    terraform plan -out=tfplan
                    terraform apply -auto-approve tfplan
                  displayName: 'Deploy Foundation'
                  env:
                    AWS_ACCESS_KEY_ID: $(AWS_ACCESS_KEY_ID)
                    AWS_SECRET_ACCESS_KEY: $(AWS_SECRET_ACCESS_KEY)
```

## Advanced CI/CD Features

### 1. Terraform Cloud Integration

```yaml
# Example with Terraform Cloud
foundation:
  name: Foundation Layer
  runs-on: ubuntu-latest
  steps:
    - name: Setup Terraform Cloud
      uses: hashicorp/tfc-workflows-github@v1.0.0
      with:
        token: ${{ secrets.TF_API_TOKEN }}
        organization: your-org
        workspace: foundation-production
    
    - name: Terraform Cloud Plan
      uses: hashicorp/tfc-workflows-github@v1.0.0
      with:
        command: plan
        workspace: foundation-production
    
    - name: Terraform Cloud Apply
      if: github.ref == 'refs/heads/main'
      uses: hashicorp/tfc-workflows-github@v1.0.0
      with:
        command: apply
        workspace: foundation-production
```

### 2. Policy as Code Integration

```yaml
# OPA/Sentinel policy checks
policy-check:
  name: Policy Validation
  runs-on: ubuntu-latest
  needs: [foundation, platform]
  steps:
    - name: Download Plan Files
      uses: actions/download-artifact@v3
    
    - name: OPA Policy Check
      run: |
        opa fmt --diff policies/
        opa test policies/
        
        # Check foundation policies
        opa eval -d policies/ -i foundation-plan.json "data.terraform.deny[_]"
        
        # Check platform policies  
        opa eval -d policies/ -i platform-plan.json "data.terraform.deny[_]"
```

### 3. Security Scanning Integration

```yaml
security-scan:
  name: Security Scan
  runs-on: ubuntu-latest
  steps:
    - name: Checkov Scan
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
        
    - name: TFSec Scan
      uses: aquasecurity/tfsec-action@v1.0.0
      with:
        working_directory: .
        
    - name: Terraform Compliance
      run: |
        pip install terraform-compliance
        terraform-compliance -f compliance-rules/ -p plan.json
```

### 4. Drift Detection

```yaml
drift-detection:
  name: Drift Detection
  runs-on: ubuntu-latest
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  steps:
    - name: Terraform Refresh and Plan
      run: |
        for layer in foundation platform databases; do
          cd regions/us-east-1/layers/*-$layer/production
          terraform refresh
          terraform plan -detailed-exitcode
          
          if [ $? -eq 2 ]; then
            echo "Drift detected in $layer layer!"
            # Send notification
          fi
        done
```

## Environment-Specific Configurations

### Production Pipeline
- **Approval Gates**: Manual approval required for applies
- **Security Scans**: All policies enforced
- **Notifications**: Slack/Teams notifications for all changes
- **Backup**: Automatic state backups before changes
- **Rollback**: Automated rollback on failure

### Staging Pipeline
- **Auto-Apply**: Automatic applies for testing
- **Policy Warnings**: Policy violations as warnings only
- **Performance Tests**: Load testing after deployment
- **Data Refresh**: Refresh from production data

### Development Pipeline
- **Fast Feedback**: Minimal checks for rapid iteration
- **Parallel Runs**: Multiple developers can run simultaneously
- **Auto-Cleanup**: Automatic resource cleanup

## Monitoring and Alerting

### Pipeline Monitoring
- **Success/Failure Rates**: Track deployment success rates
- **Duration Metrics**: Monitor pipeline execution times
- **Resource Costs**: Track infrastructure costs per deployment
- **State File Sizes**: Monitor state file growth

### Infrastructure Monitoring
- **Drift Detection**: Daily drift detection runs
- **Resource Health**: Monitor created resources
- **Cross-Layer Dependencies**: Validate SSM parameters
- **Security Compliance**: Continuous compliance monitoring

## Best Practices Summary

### 1. Layer Dependencies
- Always deploy foundation before platform
- Wait for SSM parameters before dependent layers
- Use proper dependency chains in pipelines

### 2. State Management
- Never run concurrent applies on same layer
- Always use state locking
- Regular state backups
- Monitor state file sizes

### 3. Security
- Secrets stored in CI/CD secret stores
- IAM roles with least privilege
- Policy as code validation
- Regular security scans

### 4. Testing
- Plan validation for all changes
- Integration tests after deployment
- Smoke tests for critical resources
- Performance validation for staging

This CI/CD integration provides a robust, scalable foundation for managing the new Terraform architecture with proper safety controls, monitoring, and automation.
