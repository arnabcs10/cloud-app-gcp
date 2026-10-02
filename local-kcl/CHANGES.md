# Changes from Production to Local Test Cluster

This document details all the changes made to adapt the production Kubernetes manifests for deployment on a small local test cluster (1 Node, 4GB RAM).

## Table of Contents
1. [Architecture Changes](#architecture-changes)
2. [Database Configuration](#database-configuration)
3. [Networking Changes](#networking-changes)
4. [Resource Optimization](#resource-optimization)
5. [High Availability Features Removed](#high-availability-features-removed)
6. [Namespace Consolidation](#namespace-consolidation)
7. [Observability Stack Simplification](#observability-stack-simplification)
8. [Configuration Changes](#configuration-changes)

---

## Architecture Changes

### Production Architecture
```
Vote App (ns-vote-app)
  └─ HTTPRoute → External Gateway
  └─ Redis (ns-redis)

Result App (ns-result-app)
  └─ HTTPRoute → External Gateway
  └─ Cloud SQL Proxy → Cloud SQL (Private IP)

Worker (ns-worker-app)
  └─ Redis (ns-redis)
  └─ Cloud SQL Proxy → Cloud SQL (Private IP)

Observability (ns-observability)
  └─ HTTPRoute for Grafana
  └─ Full Helm charts with enterprise features
```

### Test Cluster Architecture
```
Vote App (voting-app)
  └─ NodePort 31000
  └─ Redis (voting-app)

Result App (voting-app)
  └─ NodePort 31001
  └─ PostgreSQL (voting-app)

Worker (voting-app)
  └─ Redis (voting-app)
  └─ PostgreSQL (voting-app)

Observability (observability)
  └─ Prometheus NodePort 32090
  └─ Grafana NodePort 32300
  └─ Simplified deployments
```

---

## Database Configuration

### ❌ Removed: Cloud SQL Proxy

**Production (result-deployment.yaml):**
```yaml
containers:
- name: result-app
  env:
  - name: PGHOST
    value: "127.0.0.1"  # Cloud SQL Proxy on localhost

- name: cloud-sql-proxy
  image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
  args:
    - "--private-ip"
    - "burner-arnsengu:us-central1:cloud-app-postgres-prd"
```

**Test Cluster:**
```yaml
containers:
- name: result-app
  env:
  - name: PGHOST
    value: "postgres.voting-app.svc.cluster.local"
  # No cloud-sql-proxy sidecar
```

### ✅ Added: PostgreSQL Deployment

**New file: postgres-deployment.yaml**
- PostgreSQL 15 Alpine
- 1Gi PVC for data persistence
- Simple credentials (postgres/postgres)
- Health checks with pg_isready
- Resources: 128Mi/256Mi memory, 50m/200m CPU

---

## Networking Changes

### ❌ Removed: Gateway API

**Production (vote/httproute.yaml):**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: vote-app-route
spec:
  parentRefs:
  - name: external-gateway
```

### ✅ Changed: NodePort Services

**Test Cluster:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: vote
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 31000
```

**NodePort Mappings:**
- Vote App: 31000
- Result App: 31001
- Prometheus: 32090
- Grafana: 32300

---

## Resource Optimization

### Vote App
```yaml
# Production
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"

# Test Cluster
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Result App
```yaml
# Production
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "1000m"

# Test Cluster
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "300m"
```

### Worker App
```yaml
# Production
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "1000m"

# Test Cluster
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "300m"
```

### Redis
```yaml
# Production
maxmemory 256mb
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Test Cluster
maxmemory 128mb
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Total Resource Comparison

| Component | Production Request | Test Request | Savings |
|-----------|-------------------|--------------|----------|
| **Memory** | ~2.5 GB | ~1.1 GB | 56% reduction |
| **CPU** | ~1.5 cores | ~0.55 cores | 63% reduction |

---

## High Availability Features Removed

### ❌ HPA (Horizontal Pod Autoscaler)

**Production (vote/hpa.yaml):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vote-app-hpa
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Test Cluster:** Removed - Fixed 1 replica

### ❌ PodDisruptionBudget

**Production:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vote-app-pdb
spec:
  minAvailable: 1
```

**Test Cluster:** Removed - Not needed for single node

### ❌ NetworkPolicy

**Production (vote/networkpolicy.yaml):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vote-app-network-policy
spec:
  podSelector:
    matchLabels:
      app: vote-app
  policyTypes:
  - Ingress
  - Egress
```

**Test Cluster:** Removed - Simplified networking

### Replica Count Changes

| Component | Production | Test Cluster |
|-----------|-----------|-------------|
| Vote App | 2 | 1 |
| Result App | 2 | 1 |
| Worker | 2 | 1 |
| Redis | 1 | 1 |
| Prometheus | 1 | 1 |
| Grafana | 1 | 1 |
| Loki | 1 | 1 |

---

## Namespace Consolidation

### Production Namespaces
```
ns-vote-app
ns-result-app
ns-worker-app
ns-redis
ns-observability
```

### Test Cluster Namespaces
```
voting-app       (consolidated vote, result, worker, redis, postgres)
observability    (prometheus, grafana, loki, promtail)
```

**Benefits:**
- Simplified service discovery
- Easier RBAC management
- Reduced namespace overhead
- Shorter DNS names

**Service Name Changes:**
```yaml
# Production
REDIS_HOST: "redis-service.ns-redis.svc.cluster.local"

# Test Cluster
REDIS_HOST: "redis.voting-app.svc.cluster.local"
```

---

## Observability Stack Simplification

### Prometheus

**Production (Helm values):**
```yaml
server:
  persistentVolume:
    size: 10Gi
  retention: "7d"
  retentionSize: "8GB"
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
```

**Test Cluster (Simple deployment):**
```yaml
volumes:
- name: prometheus-storage
  persistentVolumeClaim:
    claimName: prometheus-pvc  # 2Gi
args:
  - '--storage.tsdb.retention.time=7d'
  - '--storage.tsdb.retention.size=1GB'
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Grafana

**Production (Helm chart):**
- SMTP configuration
- External secrets
- Advanced features
- 2Gi storage

**Test Cluster:**
- Simple admin/admin credentials
- Pre-configured datasources in ConfigMap
- 1Gi storage
- Basic features only

### Loki

**Production (Helm chart):**
```yaml
deploymentMode: SingleBinary
loki:
  storage:
    type: filesystem
  limits_config:
    retention_period: 168h
resources:
  requests:
    cpu: 200m
    memory: 512Mi
```

**Test Cluster (Simplified):**
```yaml
# Same single-binary mode but:
- Reduced retention configs
- Smaller buffer sizes
- Lower resource limits (128Mi/256Mi)
- No ruler/alertmanager integration
```

### Promtail

**Changes:**
- Removed complex relabeling
- Simplified scrape configs
- Focus on pod logs only
- Reduced memory footprint (64Mi/128Mi)

### ❌ Removed Components

- Tempo (distributed tracing)
- Redis Exporter
- Postgres Exporter
- AlertManager
- Custom recording rules
- Custom alerting rules

---

## Configuration Changes

### Environment Variables

#### Result App

**Production:**
```yaml
env:
- name: PGHOST
  value: "127.0.0.1"
- name: PGDATABASE
  valueFrom:
    secretKeyRef:
      name: cloudsql-db-credentials
      key: DB_NAME
```

**Test Cluster:**
```yaml
env:
- name: PGHOST
  value: "postgres.voting-app.svc.cluster.local"
- name: PGDATABASE
  value: "voting_app"
- name: PGPASSWORD
  value: "postgres"
```

#### Worker App

**Production:**
```yaml
env:
- name: DB_HOST
  value: "127.0.0.1"  # Cloud SQL Proxy
- name: CONNECTION_STRING
  value: "Server=127.0.0.1;Port=5432;..."
```

**Test Cluster:**
```yaml
env:
- name: DB_HOST
  value: "postgres.voting-app.svc.cluster.local"
- name: CONNECTION_STRING
  value: "Server=$(DB_HOST);Port=$(DB_PORT);..."
```

### Storage Configuration

**Production:**
```yaml
storageClassName: standard-rwo  # GKE persistent disk
```

**Test Cluster:**
```yaml
storageClassName: standard  # Default local storage
# Or omit for dynamic provisioning
```

### Security Context Changes

**Production:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

**Test Cluster:**
```yaml
# Removed or simplified for most components
# Only kept for critical services like Redis
```

### Init Container Changes

**Production (Result App):**
```yaml
initContainers:
- name: wait-for-db
  command:
  - sh
  - -c
  - |
    echo "Waiting for Cloud SQL Proxy to be ready..."
    sleep 10
```

**Test Cluster:**
```yaml
initContainers:
- name: wait-for-db
  command:
  - sh
  - -c
  - |
    until nc -z postgres.voting-app.svc.cluster.local 5432; do
      echo "Waiting for PostgreSQL..."
      sleep 2
    done
```

---

## File Structure Comparison

### Production Structure
```
cloud-app-gcp/
├── deployments/envs/prd/
│   ├── vote/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── httproute.yaml
│   │   ├── hpa.yaml
│   │   ├── networkpolicy.yaml
│   │   ├── pod-disruption-budget.yaml
│   │   ├── serviceaccount.yaml
│   │   └── kustomization.yaml
│   ├── result/ (similar structure)
│   ├── worker/ (similar structure)
│   └── redis/ (similar structure)
└── addons/envs/prd/observability/
    ├── prometheus.yaml (Helm values)
    ├── grafana.yaml (Helm values)
    ├── loki.yaml (Helm values)
    ├── tempo.yaml
    └── ...
```

### Test Cluster Structure
```
local-kcl/
├── namespace.yaml
├── postgres-deployment.yaml
├── redis-deployment.yaml
├── vote-deployment.yaml
├── result-deployment.yaml
├── worker-deployment.yaml
├── observability/
│   ├── prometheus-deployment.yaml
│   ├── grafana-deployment.yaml
│   ├── loki-deployment.yaml
│   └── promtail-deployment.yaml
├── kustomization.yaml
├── deploy.sh
├── cleanup.sh
├── verify.sh
├── README.md
└── CHANGES.md
```

---

## Summary of Benefits

✅ **Resource Efficiency**: 56% memory reduction, 63% CPU reduction  
✅ **Simplified Deployment**: No Helm, no Gateway API, no cloud dependencies  
✅ **Faster Startup**: Fewer components, lower resource requests  
✅ **Easy Access**: NodePort instead of complex ingress setup  
✅ **Consolidated**: 2 namespaces instead of 5  
✅ **Self-Contained**: No external dependencies (Cloud SQL, GCS, etc.)  
✅ **Easy Testing**: Simple scripts for deploy/verify/cleanup  

---

## Migration Path

To use these manifests in production, reverse the following:

1. **Add Cloud SQL Proxy** sidecar to result and worker
2. **Change NodePort to ClusterIP** and add Gateway/Ingress
3. **Increase resources** to production levels
4. **Add HPA, PDB, NetworkPolicy** for high availability
5. **Separate namespaces** for better isolation
6. **Use Helm charts** for observability stack
7. **Add secrets management** (External Secrets, Sealed Secrets)
8. **Enable monitoring exporters** (Redis, Postgres)
9. **Configure persistent storage** with proper StorageClass
10. **Add security contexts** and pod security policies

---

## Testing Checklist

- [ ] All pods start successfully
- [ ] Vote app accessible on NodePort 31000
- [ ] Result app accessible on NodePort 31001
- [ ] Can cast votes and see results
- [ ] Worker processes votes from Redis to PostgreSQL
- [ ] Prometheus scrapes all targets
- [ ] Grafana shows metrics from Prometheus
- [ ] Loki receives logs from Promtail
- [ ] No pod restarts or crashes
- [ ] Resource usage within cluster limits

---

**Document Version**: 1.0  
**Last Updated**: 2026-10-02  
**Author**: Kubernetes Expert  
