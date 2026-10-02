#!/bin/bash

# Voting App - Quick Deployment Script for Local Test Cluster
# Author: Kubernetes Expert
# Description: Deploys the voting app and observability stack on a small test cluster

set -e

echo "========================================"
echo "Voting App - Local Deployment Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

print_success "kubectl is installed"

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Step 1: Create Namespaces
print_info "Creating namespaces..."
kubectl apply -f namespace.yaml
print_success "Namespaces created"

echo ""
print_info "Deploying application components..."
echo ""

# Step 2: Deploy PostgreSQL
print_info "Deploying PostgreSQL database..."
kubectl apply -f postgres-deployment.yaml
print_success "PostgreSQL manifests applied"

# Wait for PostgreSQL
print_info "Waiting for PostgreSQL to be ready (max 120s)..."
if kubectl wait --for=condition=ready pod -l app=postgres -n voting-app --timeout=120s; then
    print_success "PostgreSQL is ready"
else
    print_error "PostgreSQL failed to start. Check logs with: kubectl logs -n voting-app -l app=postgres"
    exit 1
fi

# Step 3: Deploy Redis
print_info "Deploying Redis cache..."
kubectl apply -f redis-deployment.yaml
print_success "Redis manifests applied"

# Wait for Redis
print_info "Waiting for Redis to be ready (max 120s)..."
if kubectl wait --for=condition=ready pod -l app=redis -n voting-app --timeout=120s; then
    print_success "Redis is ready"
else
    print_error "Redis failed to start. Check logs with: kubectl logs -n voting-app -l app=redis"
    exit 1
fi

# Step 4: Deploy Application Services
print_info "Deploying Vote application..."
kubectl apply -f vote-deployment.yaml
print_success "Vote app manifests applied"

print_info "Deploying Result application..."
kubectl apply -f result-deployment.yaml
print_success "Result app manifests applied"

print_info "Deploying Worker application..."
kubectl apply -f worker-deployment.yaml
print_success "Worker app manifests applied"

# Wait for applications
print_info "Waiting for applications to be ready (max 120s)..."
kubectl wait --for=condition=ready pod -l app=vote -n voting-app --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=result -n voting-app --timeout=120s || true
print_success "Applications deployed"

echo ""
print_info "Deploying observability stack..."
echo ""

# Step 5: Deploy Observability Stack
print_info "Deploying Prometheus..."
kubectl apply -f observability/prometheus-deployment.yaml
print_success "Prometheus manifests applied"

print_info "Deploying Loki..."
kubectl apply -f observability/loki-deployment.yaml
print_success "Loki manifests applied"

print_info "Deploying Promtail..."
kubectl apply -f observability/promtail-deployment.yaml
print_success "Promtail manifests applied"

print_info "Deploying Grafana..."
kubectl apply -f observability/grafana-deployment.yaml
print_success "Grafana manifests applied"

# Wait for observability stack
print_info "Waiting for observability stack to be ready (max 120s)..."
kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=120s || true
print_success "Observability stack deployed"

echo ""
echo "========================================"
print_success "Deployment Complete!"
echo "========================================"
echo ""

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
fi

if [ -z "$NODE_IP" ]; then
    NODE_IP="<NODE_IP>"
    print_info "Could not automatically detect node IP. Please find it manually."
fi

echo "Application Endpoints:"
echo "  Vote App:    http://${NODE_IP}:31000"
echo "  Result App:  http://${NODE_IP}:31001"
echo ""
echo "Observability Endpoints:"
echo "  Prometheus:  http://${NODE_IP}:32090"
echo "  Grafana:     http://${NODE_IP}:32300 (admin/admin)"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n voting-app"
echo "  kubectl get pods -n observability"
echo ""
echo "Check services:"
echo "  kubectl get svc -n voting-app"
echo "  kubectl get svc -n observability"
echo ""
print_info "For port-forward access (KillerKoda), run:"
echo "  kubectl port-forward -n voting-app svc/vote 8080:80"
echo "  kubectl port-forward -n voting-app svc/result 8081:80"
echo "  kubectl port-forward -n observability svc/grafana 3000:3000"
echo ""
