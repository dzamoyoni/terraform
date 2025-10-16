#!/bin/bash
# deploy-atlantis-poc.sh
# Quick Atlantis POC deployment for Dennis's environment

set -e

echo "🚀 Deploying Atlantis POC for GitOps evaluation..."

# Configuration
NAMESPACE="atlantis-poc"
ATLANTIS_VERSION="v0.26.0"

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    echo "   Ubuntu: sudo apt-get install -y kubectl"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    echo "   Make sure kubectl is configured correctly."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Create namespace
echo "📁 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Get credentials from user
echo ""
echo "🔐 Setting up Atlantis credentials..."
echo "You'll need:"
echo "1. A Bitbucket App Password with Repository permissions"
echo "2. A webhook secret (any random string)"
echo ""

read -p "Enter your Bitbucket username: " BITBUCKET_USER
read -s -p "Enter your Bitbucket App Password: " BITBUCKET_TOKEN
echo ""
read -p "Enter a webhook secret (any random string): " WEBHOOK_SECRET
read -p "Enter your Bitbucket repository (e.g., mycompany/terraform-infrastructure): " BITBUCKET_REPO

# Create secrets
echo "🔐 Creating Kubernetes secrets..."
kubectl create secret generic atlantis-poc-credentials \
  --from-literal=token="$BITBUCKET_TOKEN" \
  --from-literal=webhook-secret="$WEBHOOK_SECRET" \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create RBAC
echo "👥 Setting up RBAC..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: atlantis-poc
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: atlantis-poc
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: atlantis-poc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: atlantis-poc
subjects:
- kind: ServiceAccount
  name: atlantis-poc
  namespace: $NAMESPACE
EOF

# Deploy Atlantis
echo "🌊 Deploying Atlantis POC..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlantis-poc
  namespace: $NAMESPACE
  labels:
    app: atlantis-poc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atlantis-poc
  template:
    metadata:
      labels:
        app: atlantis-poc
    spec:
      serviceAccountName: atlantis-poc
      containers:
      - name: atlantis
        image: runatlantis/atlantis:$ATLANTIS_VERSION
        ports:
        - name: atlantis
          containerPort: 4141
        env:
        - name: ATLANTIS_REPO_ALLOWLIST
          value: "bitbucket.org/$BITBUCKET_REPO"
        - name: ATLANTIS_BITBUCKET_USER
          value: "$BITBUCKET_USER"
        - name: ATLANTIS_BITBUCKET_TOKEN
          valueFrom:
            secretKeyRef:
              name: atlantis-poc-credentials
              key: token
        - name: ATLANTIS_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: atlantis-poc-credentials
              key: webhook-secret
        - name: ATLANTIS_DATA_DIR
          value: /atlantis-data
        - name: ATLANTIS_PORT
          value: "4141"
        - name: ATLANTIS_LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
        livenessProbe:
          httpGet:
            path: /healthz
            port: 4141
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 4141
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: atlantis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: atlantis-poc-service
  namespace: $NAMESPACE
  labels:
    app: atlantis-poc
spec:
  type: LoadBalancer
  ports:
  - name: atlantis
    port: 80
    targetPort: 4141
    protocol: TCP
  selector:
    app: atlantis-poc
EOF

# Wait for deployment
echo "⏳ Waiting for Atlantis to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/atlantis-poc -n $NAMESPACE

# Get service information
echo ""
echo "✅ Atlantis POC deployment complete!"
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n $NAMESPACE
echo ""

# Get LoadBalancer info
echo "🌐 Getting Atlantis URL..."
ATLANTIS_URL=""
for i in {1..30}; do
    ATLANTIS_URL=$(kubectl get svc atlantis-poc-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ ! -z "$ATLANTIS_URL" ]; then
        break
    fi
    echo "Waiting for LoadBalancer... ($i/30)"
    sleep 10
done

if [ -z "$ATLANTIS_URL" ]; then
    echo "⚠️  LoadBalancer not ready yet. Get the URL manually:"
    echo "   kubectl get svc atlantis-poc-service -n $NAMESPACE"
    ATLANTIS_URL="<PENDING>"
else
    echo "✅ Atlantis is available at: http://$ATLANTIS_URL"
fi

echo ""
echo "🔧 Next Steps:"
echo "1. Configure Bitbucket Webhook:"
echo "   - Go to your repository settings in Bitbucket"
echo "   - Add webhook URL: http://$ATLANTIS_URL/events"
echo "   - Secret: $WEBHOOK_SECRET"
echo "   - Triggers: Repository push, Pull request created/updated"
echo ""
echo "2. Test the POC:"
echo "   - Create a feature branch"
echo "   - Make a small Terraform change"
echo "   - Create a pull request"
echo "   - Atlantis should automatically comment with a plan"
echo ""
echo "3. Monitor the POC:"
echo "   - Check logs: kubectl logs -f deployment/atlantis-poc -n $NAMESPACE"
echo "   - Check status: kubectl get pods -n $NAMESPACE"
echo ""
echo "🎉 POC is ready for testing!"
echo ""
echo "💡 POC Limitations (to be addressed in enterprise version):"
echo "   - Single replica (no HA)"
echo "   - Temporary storage (data lost on restart)"
echo "   - Basic security (no SSO)"
echo "   - Manual monitoring"
echo "   - No cost controls"
echo ""
echo "After successful POC, we'll upgrade to enterprise configuration!"
