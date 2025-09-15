#!/bin/bash

# Observability Stack Port Forward Script
# This script sets up port forwards for all observability tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}    🔭 Observability Stack Port Forwards${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up port forwards..."
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    exit 0
}

# Trap cleanup on script exit
trap cleanup SIGINT SIGTERM EXIT

print_header

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
    exit 1
fi

print_status "Setting up port forwards for observability tools..."
echo

# Array of services and their configurations
declare -A services=(
    ["grafana"]="svc/grafana:3000:80"
    ["prometheus"]="svc/prometheus-kube-prometheus-prometheus:9090:9090" 
    ["kiali"]="svc/kiali:20001:20001"
    ["alertmanager"]="svc/prometheus-kube-prometheus-alertmanager:9093:9093"
    ["tempo"]="svc/tempo:3100:3100"
)

declare -A descriptions=(
    ["grafana"]="Grafana Dashboard (Temporary Mode)"
    ["prometheus"]="Prometheus Metrics & Queries"
    ["kiali"]="Istio Service Mesh Observability"
    ["alertmanager"]="AlertManager Web UI"
    ["tempo"]="Tempo Tracing Backend"
)

declare -A urls=(
    ["grafana"]="http://localhost:3000"
    ["prometheus"]="http://localhost:9090"
    ["kiali"]="http://localhost:20001"
    ["alertmanager"]="http://localhost:9093"
    ["tempo"]="http://localhost:3100"
)

# Start port forwards in background
pids=()

for service in "${!services[@]}"; do
    IFS=':' read -ra config <<< "${services[$service]}"
    svc_name="${config[0]}"
    local_port="${config[1]}"
    remote_port="${config[2]}"
    
    print_status "Starting port forward for $service..."
    kubectl port-forward -n istio-system "$svc_name" "$local_port:$remote_port" &
    pids+=($!)
    sleep 2
done

echo
print_header
echo -e "${GREEN}🚀 All port forwards are now active!${NC}"
echo
echo -e "${BLUE}📊 Access your observability tools:${NC}"
echo

# Print access information
for service in "${!services[@]}"; do
    echo -e "${YELLOW}• ${descriptions[$service]}:${NC}"
    echo -e "  URL: ${urls[$service]}"
    if [[ "$service" == "grafana" ]]; then
        echo -e "  Username: ${GREEN}admin${NC}"
        echo -e "  Password: ${GREEN}$(kubectl get secret grafana-admin-secret -n istio-system -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Check manually")${NC}"
    fi
    echo
done

echo -e "${BLUE}📝 Notes:${NC}"
echo "• Grafana is running in temporary mode (no persistence)"
echo "• Prometheus includes the full Prometheus stack"
echo "• Kiali provides Istio service mesh visualization"
echo "• AlertManager handles alert routing and notifications"
echo "• Tempo handles distributed tracing"
echo
echo -e "${YELLOW}⚠️  Press Ctrl+C to stop all port forwards${NC}"
echo

# Wait for port forwards to be established
print_status "Checking port forward status..."
sleep 5

# Check if services are accessible
for service in "${!services[@]}"; do
    IFS=':' read -ra config <<< "${services[$service]}"
    local_port="${config[1]}"
    
    if nc -z localhost "$local_port" 2>/dev/null; then
        print_status "✅ $service is accessible on port $local_port"
    else
        print_warning "⚠️  $service may not be ready on port $local_port"
    fi
done

echo
print_status "All port forwards are running. Access the URLs above to use your observability tools."

# Keep the script running
while true; do
    sleep 30
    # Check if all background processes are still running
    for pid in "${pids[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            print_error "Port forward process $pid has died. Restarting all..."
            cleanup
            exec "$0"
        fi
    done
done
