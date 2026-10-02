# Voting App - Local Kubernetes Deployment

This directory contains Kubernetes manifests optimized for deploying the voting application on a small test cluster (1 Node, 4GB RAM) in KillerKoda environment.

## Architecture Overview

The voting application consists of:

### Application Components
- **Vote App**: Python Flask frontend for voting (NodePort: 31000)
- **Result App**: Node.js frontend for results display (NodePort: 31001)
- **Worker**: .NET worker that processes votes from Redis to PostgreSQL
- **Redis**: In-memory cache for vote queue
- **PostgreSQL**: Persistent database for vote storage

### Observability Stack
- **Prometheus**: Metrics collection and storage (NodePort: 32090)
- **Grafana**: Visualization and dashboards (NodePort: 32300)
- **Loki**: Log aggregation
- **Promtail**: Log collection agent (DaemonSet)

## Changes from Production Manifests

### 1. Database Connection
- ✅ **Removed**: Cloud SQL Proxy sidecar containers
- ✅ **Added**: PostgreSQL deployment with local persistent storage
- ✅ **Updated**: Connection strings to use `postgres.voting-app.svc.cluster.local`

### 2. Networking
- ✅ **Removed**: Gateway API (HTTPRoute)
- ✅ **Changed**: ClusterIP → NodePort for external access
- ✅ **Simplified**: Single `voting-app` namespace instead of separate namespaces per service

### 3. Resource Optimization
| Component | Original Memory | New Memory | Original CPU | New CPU |
|-----------|----------------|------------|--------------|----------|
| Vote App | 128Mi/256Mi | 64Mi/128Mi | 100m/500m | 50m/200m |
| Result App | 256Mi/512Mi | 128Mi/256Mi | 200m/1000m | 50m/300m |
| Worker | 256Mi/512Mi | 128Mi/256Mi | 200m/1000m | 50m/300m |
| Redis | 128Mi/512Mi | 64Mi/128Mi | 100m/500m | 50m/200m |
| PostgreSQL | - | 128Mi/256Mi | - | 50m/200m |
| Prometheus | 1Gi/2Gi | 256Mi/512Mi | 500m/1000m | 100m/500m |
| Grafana | - | 128Mi/256Mi | - | 50m/200m |
| Loki | - | 128Mi/256Mi | - | 50m/200m |
| Promtail | - | 64Mi/128Mi | - | 50m/100m |

### 4. High Availability Features Removed
- ❌ HPA (Horizontal Pod Autoscaler)
- ❌ PodDisruptionBudget
- ❌ NetworkPolicy
- ⚡ Reduced replicas: 2 → 1 for all services

### 5. Storage
- PostgreSQL: 1Gi PVC
- Prometheus: 2Gi PVC (7-day retention, 1GB size limit)
- Grafana: 1Gi PVC
- Loki: 2Gi PVC (7-day retention)
- Redis: No persistence (in-memory only for testing)

## Deployment Instructions

### Prerequisites
- Kubernetes cluster with at least 4GB RAM and 2 CPUs
- kubectl configured to access the cluster
- No Ingress Controller or Gateway API required

### Step 1: Create Namespaces
```bash
kubectl apply -f namespace.yaml
```

### Step 2: Deploy Application Components
```bash
# Deploy in order to respect dependencies
kubectl apply -f postgres-deployment.yaml
kubectl apply -f redis-deployment.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n voting-app --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n voting-app --timeout=120s

# Deploy application services
kubectl apply -f vote-deployment.yaml
kubectl apply -f result-deployment.yaml
kubectl apply -f worker-deployment.yaml
```

### Step 3: Deploy Observability Stack
```bash
kubectl apply -f observability/prometheus-deployment.yaml
kubectl apply -f observability/loki-deployment.yaml
kubectl apply -f observability/promtail-deployment.yaml
kubectl apply -f observability/grafana-deployment.yaml

# Wait for observability stack to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n observability --timeout=120s
kubectl wait --for=condition=ready pod -l app=loki -n observability --timeout=120s
kubectl wait --for=condition=ready pod -l app=grafana -n observability --timeout=120s
```

### Step 4: Verify Deployment
```bash
# Check all pods are running
kubectl get pods -n voting-app
kubectl get pods -n observability

# Check services
kubectl get svc -n voting-app
kubectl get svc -n observability
```

## Accessing the Application

### Application Endpoints (NodePort)

Get the node IP:
```bash
kubectl get nodes -o wide
```

Then access:
- **Vote App**: `http://<NODE_IP>:31000`
- **Result App**: `http://<NODE_IP>:31001`

### Observability Endpoints
- **Prometheus**: `http://<NODE_IP>:32090`
- **Grafana**: `http://<NODE_IP>:32300` (admin/admin)

### Testing in KillerKoda
If you're using KillerKoda, you can access services via port forwarding:

```bash
# Vote App
kubectl port-forward -n voting-app svc/vote 8080:80

# Result App
kubectl port-forward -n voting-app svc/result 8081:80

# Grafana
kubectl port-forward -n observability svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090
```

## Observability Setup

### Grafana Configuration

1. Login to Grafana (`http://<NODE_IP>:32300`)
   - Username: `admin`
   - Password: `admin`

2. Data sources are pre-configured:
   - **Prometheus**: `http://prometheus.observability.svc.cluster.local:9090`
   - **Loki**: `http://loki.observability.svc.cluster.local:3100`

3. Create dashboards or import existing ones:
   - Kubernetes Cluster Monitoring
   - Application Metrics
   - Log Analysis

### Prometheus Targets

Prometheus is configured to scrape:
- Kubernetes API server
- Kubernetes nodes
- All pods with `prometheus.io/scrape: "true"` annotation
- Application services (vote, result, redis, postgres)

### Loki Log Aggregation

Promtail DaemonSet automatically collects logs from all pods and sends them to Loki.

Query logs in Grafana using LogQL:
```logql
{namespace="voting-app"}
{app="vote"}
{app="result"}
{app="worker"}
```

## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n voting-app

# Check logs
kubectl logs <pod-name> -n voting-app

# Check init containers
kubectl logs <pod-name> -n voting-app -c wait-for-redis
kubectl logs <pod-name> -n voting-app -c wait-for-db
```

### Database Connection Issues
```bash
# Test PostgreSQL connectivity
kubectl exec -it -n voting-app deployment/postgres -- psql -U postgres -d voting_app -c "\dt"

# Test Redis connectivity
kubectl exec -it -n voting-app deployment/redis -- redis-cli ping
```

### Resource Constraints
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n voting-app
kubectl top pods -n observability

# If resources are exhausted, scale down:
kubectl scale deployment -n observability loki --replicas=0
```

### NodePort Access Issues
```bash
# Verify NodePort services
kubectl get svc -n voting-app
kubectl get svc -n observability

# Check firewall rules (if applicable)
# Ensure ports 31000, 31001, 32090, 32300 are accessible
```

## Clean Up

```bash
# Delete all resources
kubectl delete -f observability/
kubectl delete -f vote-deployment.yaml
kubectl delete -f result-deployment.yaml
kubectl delete -f worker-deployment.yaml
kubectl delete -f redis-deployment.yaml
kubectl delete -f postgres-deployment.yaml
kubectl delete -f namespace.yaml

# Or delete namespaces (cascades to all resources)
kubectl delete namespace voting-app
kubectl delete namespace observability
```

## Resource Summary

### Total Resource Requests
- **Memory**: ~1.1 GB
- **CPU**: ~550m (0.55 cores)

### Total Resource Limits
- **Memory**: ~2.3 GB
- **CPU**: ~2.5 cores

### Storage Requirements
- PostgreSQL: 1Gi
- Prometheus: 2Gi
- Grafana: 1Gi
- Loki: 2Gi
- **Total**: 6Gi

**Note**: This fits comfortably within a 4GB RAM cluster with proper scheduling.

## Monitoring Metrics

### Key Metrics to Monitor

1. **Application Health**
   - Pod restarts: `kube_pod_container_status_restarts_total`
   - Pod status: `kube_pod_status_phase`

2. **Resource Usage**
   - Memory: `container_memory_usage_bytes`
   - CPU: `container_cpu_usage_seconds_total`

3. **Application Metrics**
   - Vote count: Custom metrics from applications
   - Database connections: PostgreSQL exporter metrics
   - Redis operations: Redis exporter metrics

4. **Cluster Health**
   - Node status: `kube_node_status_condition`
   - Available resources: `kube_node_status_capacity`

## Next Steps

1. **Add Custom Dashboards**: Import or create Grafana dashboards for application-specific metrics
2. **Set Up Alerts**: Configure Prometheus alerting rules for critical conditions
3. **Enable Metrics**: Add Prometheus client libraries to vote/result/worker apps for custom metrics
4. **Performance Testing**: Use tools like `hey` or `ab` to generate load and observe behavior
5. **Log Analysis**: Create Loki queries for error detection and debugging

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Voting App - Test Cluster                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────┐                        ┌──────────────────┐  │
│  │   Vote App    │                        │   Result App     │  │
│  │  (NodePort    │                        │   (NodePort      │  │
│  │   31000)      │                        │    31001)        │  │
│  └───────┬───────┘                        └────────┬─────────┘  │
│          │                                          │            │
│          ├─────────┐                    ┌──────────┤            │
│          │         │                    │          │            │
│     ┌────▼────┐   ┌▼────────┐    ┌────▼─────┐    │            │
│     │  Redis  │   │  Worker  │────│ Postgres │    │            │
│     └─────────┘   └──────────┘    └──────────┘    │            │
│          │                                │        │            │
│          └────────────────────────────────┴────────┘            │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│                     Observability Stack                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐        ┌──────────────┐    ┌──────────────┐  │
│  │  Prometheus  │───────▶│   Grafana    │◀───│     Loki     │  │
│  │  (NodePort   │        │  (NodePort   │    │              │  │
│  │   32090)     │        │   32300)     │    └──────▲───────┘  │
│  └──────────────┘        └──────────────┘           │          │
│         ▲                                            │          │
│         │                                    ┌───────┴───────┐  │
│         └────────────────────────────────────│   Promtail    │  │
│                  Scrapes Metrics             │  (DaemonSet)  │  │
│                                              └───────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Differences Summary

| Feature | Production | Test Cluster |
|---------|-----------|-------------|
| Namespaces | 5 separate (vote, result, worker, redis, observability) | 2 consolidated (voting-app, observability) |
| Database | Cloud SQL with Proxy | PostgreSQL in-cluster |
| Networking | Gateway API + HTTPRoute | NodePort |
| Replicas | 2 per service | 1 per service |
| Resources | High (production-grade) | Low (test optimized) |
| HA Features | HPA, PDB, NetworkPolicy | None |
| Storage | Cloud persistent disks | Local PVCs |
| Monitoring | Full stack with exporters | Simplified stack |
| Security Context | Strict | Basic |
