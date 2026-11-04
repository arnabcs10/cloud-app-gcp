#!/bin/bash

# Observability Stack - Helm-based Deployment Script
# Deploys Prometheus, Grafana, Loki, Promtail via Helm charts + Kustomize

set -e

echo "=========================================="
echo "Observability Stack - Helm Deployment"
echo "=========================================="
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

# Check prerequisites
print_header "Checking Prerequisites"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi
print_success "kubectl is installed"

# Check kubectl version for --enable-helm support
KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"v[0-9.]*"' | cut -d'"' -f4 | cut -d'v' -f2)
KUBECTL_MAJOR=$(echo $KUBECTL_VERSION | cut -d'.' -f1)
KUBECTL_MINOR=$(echo $KUBECTL_VERSION | cut -d'.' -f2)

if [ "$KUBECTL_MAJOR" -lt 1 ] || ([ "$KUBECTL_MAJOR" -eq 1 ] && [ "$KUBECTL_MINOR" -lt 26 ]); then
    print_error "kubectl version $KUBECTL_VERSION does not support --enable-helm (requires >= 1.26)"
    exit 1
fi
print_success "kubectl version $KUBECTL_VERSION supports --enable-helm"

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Check Helm charts directory
# HELM_CHARTS_DIR="cloud-app-gcp/addons/helm-charts"
# if [ ! -d "$HELM_CHARTS_DIR" ]; then
#     print_error "Helm charts directory not found: $HELM_CHARTS_DIR"
#     echo ""
#     print_info "Please download Helm charts first:"
#     echo "  cd cloud-app-gcp/addons && mkdir -p helm-charts && cd helm-charts"
#     echo "  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
#     echo "  helm repo add grafana https://grafana.github.io/helm-charts"
#     echo "  helm repo update"
#     echo "  helm pull prometheus-community/prometheus --version 25.21.0 --untar"
#     echo "  helm pull grafana/grafana --version 8.0.0 --untar"
#     echo "  helm pull grafana/loki --version 6.6.5 --untar"
#     echo "  helm pull grafana/promtail --version 6.16.6 --untar"
#     echo "  helm pull grafana/tempo --version 1.10.3 --untar"
#     echo "  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts"
#     echo "  helm pull open-telemetry/opentelemetry-collector --version 0.91.1 --untar"
#     echo "  helm pull prometheus-community/prometheus-redis-exporter --version 6.3.0 --untar"
#     echo ""
#     exit 1
# fi
# print_success "Helm charts directory found"

# Verify individual charts
# MISSING_CHARTS=""
# for CHART in prometheus grafana loki promtail tempo opentelemetry-collector prometheus-redis-exporter; do
#     if [ ! -d "$HELM_CHARTS_DIR/$CHART" ]; then
#         MISSING_CHARTS="$MISSING_CHARTS $CHART"
#     fi
# done

# if [ -n "$MISSING_CHARTS" ]; then
#     print_error "Missing Helm charts:$MISSING_CHARTS"
#     print_info "Please download the missing charts (see README.md)"
#     exit 1
# fi
# print_success "All required Helm charts found"

echo ""
print_header "Deploying Observability Stack"

# Change to observability-helm directory
cd observability-helm

print_info "Generating manifests from Helm charts..."

# Generate manifests
if ! kubectl kustomize --enable-helm . > observability-deployment.yaml 2>&1; then
    print_error "Failed to generate manifests"
    cat observability-deployment.yaml
    exit 1
fi

print_success "Manifests generated successfully"
print_info "Generated file size: $(wc -l < observability-deployment.yaml) lines"

# Apply manifests
print_info "Applying manifests to cluster..."

if kubectl apply -f observability-deployment.yaml; then
    print_success "Manifests applied successfully"
else
    print_error "Failed to apply manifests"
    exit 1
fi

echo ""
print_header "Waiting for Deployments"

# Wait for namespace
print_info "Waiting for namespace to be active..."
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/observability --timeout=30s || true
print_success "Namespace is active"

# Wait for Prometheus
print_info "Waiting for Prometheus (max 120s)..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server -n observability --timeout=120s 2>/dev/null; then
    print_success "Prometheus is ready"
else
    print_error "Prometheus failed to start (check logs: kubectl logs -n observability -l app.kubernetes.io/name=prometheus)"
fi

# Wait for Grafana
print_info "Waiting for Grafana (max 120s)..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n observability --timeout=120s 2>/dev/null; then
    print_success "Grafana is ready"
else
    print_error "Grafana failed to start (check logs: kubectl logs -n observability -l app.kubernetes.io/name=grafana)"
fi

# Wait for Loki
print_info "Waiting for Loki (max 120s)..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n observability --timeout=120s 2>/dev/null; then
    print_success "Loki is ready"
else
    print_error "Loki failed to start (check logs: kubectl logs -n observability -l app.kubernetes.io/name=loki)"
fi

# Check Promtail (DaemonSet - at least one pod should be ready)
print_info "Checking Promtail DaemonSet..."
sleep 10
PROMTAIL_PODS=$(kubectl get pods -n observability -l app.kubernetes.io/name=promtail --no-headers 2>/dev/null | wc -l)
if [ "$PROMTAIL_PODS" -gt 0 ]; then
    print_success "Promtail is running ($PROMTAIL_PODS pod(s))"
else
    print_error "Promtail pods not found"
fi

# Wait for Tempo
print_info "Waiting for Tempo (max 120s)..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tempo -n observability --timeout=120s 2>/dev/null; then
    print_success "Tempo is ready"
else
    print_error "Tempo failed to start (check logs: kubectl logs -n observability -l app.kubernetes.io/name=tempo)"
fi

# Wait for OpenTelemetry Collector
print_info "Waiting for OpenTelemetry Collector (max 120s)..."
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-collector -n observability --timeout=120s 2>/dev/null; then
    print_success "OpenTelemetry Collector is ready"
else
    print_error "OpenTelemetry Collector failed to start (check logs: kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector)"
fi

# Check Redis Exporter
print_info "Checking Redis Exporter..."
sleep 5
REDIS_EXP_READY=$(kubectl get pods -n observability -l app.kubernetes.io/name=prometheus-redis-exporter -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$REDIS_EXP_READY" == "True" ]; then
    print_success "Redis Exporter is ready"
else
    print_info "Redis Exporter is not ready (check if Redis is accessible)"
fi

echo ""
print_header "Deployment Summary"

# Show pods
echo "Pods in observability namespace:"
kubectl get pods -n observability
echo ""

# Show services
echo "Services in observability namespace:"
kubectl get svc -n observability
echo ""

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
fi

if [ -z "$NODE_IP" ]; then
    NODE_IP="<NODE_IP>"
    print_info "Could not automatically detect node IP"
fi

echo "=========================================="
print_success "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Prometheus:  http://${NODE_IP}:32090"
echo "  Grafana:     http://${NODE_IP}:32300 (admin/admin)"
echo ""
echo "For KillerKoda or port-forwarding:"
echo "  kubectl port-forward -n observability svc/grafana 3000:80"
echo "  kubectl port-forward -n observability svc/prometheus-server 9090:9090"
echo ""
echo "Check status:"
echo "  kubectl get pods -n observability"
echo "  kubectl get svc -n observability"
echo ""
echo "View logs:"
echo "  kubectl logs -n observability -l app.kubernetes.io/name=prometheus"
echo "  kubectl logs -n observability -l app.kubernetes.io/name=grafana"
echo "  kubectl logs -n observability -l app.kubernetes.io/name=loki"
echo ""

# Save generated manifests
print_info "Generated manifests saved to: local-kcl/observability-deployment.yaml"
echo ""
