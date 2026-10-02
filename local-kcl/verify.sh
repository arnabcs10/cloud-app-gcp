#!/bin/bash

# Voting App - Verification Script
# Description: Verifies the deployment and checks application health

set -e

echo "========================================"
echo "Voting App - Deployment Verification"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Check namespaces
print_header "Checking Namespaces"
if kubectl get namespace voting-app &> /dev/null; then
    print_success "voting-app namespace exists"
else
    print_error "voting-app namespace not found"
fi

if kubectl get namespace observability &> /dev/null; then
    print_success "observability namespace exists"
else
    print_error "observability namespace not found"
fi

# Check voting-app pods
print_header "Checking Voting App Pods"
kubectl get pods -n voting-app
echo ""

VOTE_READY=$(kubectl get pods -n voting-app -l app=vote -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$VOTE_READY" == "True" ]; then
    print_success "Vote app is ready"
else
    print_error "Vote app is not ready"
fi

RESULT_READY=$(kubectl get pods -n voting-app -l app=result -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$RESULT_READY" == "True" ]; then
    print_success "Result app is ready"
else
    print_error "Result app is not ready"
fi

WORKER_RUNNING=$(kubectl get pods -n voting-app -l app=worker -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
if [ "$WORKER_RUNNING" == "Running" ]; then
    print_success "Worker app is running"
else
    print_error "Worker app is not running (Status: $WORKER_RUNNING)"
fi

REDIS_READY=$(kubectl get pods -n voting-app -l app=redis -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$REDIS_READY" == "True" ]; then
    print_success "Redis is ready"
else
    print_error "Redis is not ready"
fi

POSTGRES_READY=$(kubectl get pods -n voting-app -l app=postgres -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$POSTGRES_READY" == "True" ]; then
    print_success "PostgreSQL is ready"
else
    print_error "PostgreSQL is not ready"
fi

# Check observability pods
print_header "Checking Observability Pods"
kubectl get pods -n observability
echo ""

PROM_READY=$(kubectl get pods -n observability -l app=prometheus -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$PROM_READY" == "True" ]; then
    print_success "Prometheus is ready"
else
    print_error "Prometheus is not ready"
fi

GRAFANA_READY=$(kubectl get pods -n observability -l app=grafana -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$GRAFANA_READY" == "True" ]; then
    print_success "Grafana is ready"
else
    print_error "Grafana is not ready"
fi

LOKI_READY=$(kubectl get pods -n observability -l app=loki -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$LOKI_READY" == "True" ]; then
    print_success "Loki is ready"
else
    print_error "Loki is not ready"
fi

# Check services
print_header "Checking Services"
echo "Voting App Services:"
kubectl get svc -n voting-app
echo ""
echo "Observability Services:"
kubectl get svc -n observability
echo ""

# Check PVCs
print_header "Checking Persistent Volume Claims"
echo "Voting App PVCs:"
kubectl get pvc -n voting-app
echo ""
echo "Observability PVCs:"
kubectl get pvc -n observability
echo ""

# Resource usage
print_header "Resource Usage"
print_info "Node resources:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

print_info "Voting app pods:"
kubectl top pods -n voting-app 2>/dev/null || echo "Metrics server not available"
echo ""

print_info "Observability pods:"
kubectl top pods -n observability 2>/dev/null || echo "Metrics server not available"
echo ""

# Get access information
print_header "Access Information"

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
fi

if [ -z "$NODE_IP" ]; then
    NODE_IP="<NODE_IP>"
fi

echo "Application URLs:"
echo "  Vote App:    http://${NODE_IP}:31000"
echo "  Result App:  http://${NODE_IP}:31001"
echo ""
echo "Observability URLs:"
echo "  Prometheus:  http://${NODE_IP}:32090"
echo "  Grafana:     http://${NODE_IP}:32300 (admin/admin)"
echo ""

# Test connectivity (if curl is available)
if command -v curl &> /dev/null; then
    print_header "Testing Connectivity"
    
    print_info "Testing Prometheus..."
    if kubectl exec -n observability deployment/prometheus -- wget -q -O- http://localhost:9090/-/healthy 2>/dev/null | grep -q "Prometheus"; then
        print_success "Prometheus is healthy"
    else
        print_error "Prometheus health check failed"
    fi
    
    print_info "Testing Grafana..."
    if kubectl exec -n observability deployment/grafana -- curl -s http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
        print_success "Grafana is healthy"
    else
        print_error "Grafana health check failed"
    fi
    
    print_info "Testing Redis..."
    if kubectl exec -n voting-app deployment/redis -- redis-cli ping 2>/dev/null | grep -q "PONG"; then
        print_success "Redis is healthy"
    else
        print_error "Redis health check failed"
    fi
    
    print_info "Testing PostgreSQL..."
    if kubectl exec -n voting-app deployment/postgres -- pg_isready -U postgres 2>/dev/null | grep -q "accepting connections"; then
        print_success "PostgreSQL is healthy"
    else
        print_error "PostgreSQL health check failed"
    fi
fi

echo ""
echo "========================================"
print_success "Verification Complete!"
echo "========================================"
echo ""
print_info "To view logs, use:"
echo "  kubectl logs -n voting-app deployment/vote"
echo "  kubectl logs -n voting-app deployment/result"
echo "  kubectl logs -n voting-app deployment/worker"
echo ""
print_info "To troubleshoot, use:"
echo "  kubectl describe pod -n voting-app <pod-name>"
echo "  kubectl get events -n voting-app --sort-by='.lastTimestamp'"
echo ""
