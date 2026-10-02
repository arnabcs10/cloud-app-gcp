#!/bin/bash

# Voting App - Cleanup Script
# Description: Removes all deployed resources from the cluster

set -e

echo "========================================"
echo "Voting App - Cleanup Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_info "Deleting observability stack..."
kubectl delete -f observability/grafana-deployment.yaml --ignore-not-found=true
kubectl delete -f observability/promtail-deployment.yaml --ignore-not-found=true
kubectl delete -f observability/loki-deployment.yaml --ignore-not-found=true
kubectl delete -f observability/prometheus-deployment.yaml --ignore-not-found=true
print_success "Observability stack deleted"

print_info "Deleting application components..."
kubectl delete -f worker-deployment.yaml --ignore-not-found=true
kubectl delete -f result-deployment.yaml --ignore-not-found=true
kubectl delete -f vote-deployment.yaml --ignore-not-found=true
kubectl delete -f redis-deployment.yaml --ignore-not-found=true
kubectl delete -f postgres-deployment.yaml --ignore-not-found=true
print_success "Application components deleted"

print_info "Deleting namespaces..."
kubectl delete -f namespace.yaml --ignore-not-found=true
print_success "Namespaces deleted"

print_info "Waiting for resources to be fully removed..."
sleep 5

echo ""
print_success "Cleanup complete!"
echo ""
echo "Verify cleanup:"
echo "  kubectl get all -n voting-app"
echo "  kubectl get all -n observability"
echo ""
