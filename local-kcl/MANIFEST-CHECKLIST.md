# Manifest Checklist - Production vs Test Cluster

This checklist verifies all required changes have been implemented.

## ✅ Completed Tasks

### 1. Docker Compose Analysis
- [x] Reviewed docker-compose.yml
- [x] Identified 5 services: vote, result, worker, redis, db
- [x] Noted dependencies and health checks
- [x] Understood network topology (front-tier, back-tier)

### 2. Manifest Verification
- [x] Reviewed vote app manifests
- [x] Reviewed result app manifests
- [x] Reviewed worker app manifests
- [x] Reviewed redis manifests
- [x] Identified cloud-sql-proxy in result and worker
- [x] Identified Gateway API usage (HTTPRoute)
- [x] Verified service-to-service communication patterns

### 3. Database Implementation
- [x] Created PostgreSQL deployment
- [x] Created PostgreSQL ConfigMap with credentials
- [x] Created PostgreSQL PVC (1Gi)
- [x] Created PostgreSQL Service (ClusterIP)
- [x] Added health checks (pg_isready)
- [x] Optimized resources for test cluster

### 4. Cloud Proxy Removal
- [x] Removed cloud-sql-proxy sidecar from result app
- [x] Removed cloud-sql-proxy sidecar from worker app
- [x] Updated PGHOST in result app to postgres service
- [x] Updated DB_HOST in worker app to postgres service
- [x] Updated connection strings to use service DNS
- [x] Modified init containers to check postgres service

### 5. Networking Changes
- [x] Removed HTTPRoute from vote app
- [x] Removed HTTPRoute from result app
- [x] Removed HTTPRoute from Grafana
- [x] Changed vote service to NodePort (31000)
- [x] Changed result service to NodePort (31001)
- [x] Changed Prometheus service to NodePort (32090)
- [x] Changed Grafana service to NodePort (32300)
- [x] Updated service discovery DNS names

### 6. Resource Optimization
- [x] Reduced vote app resources (64Mi-128Mi, 50m-200m)
- [x] Reduced result app resources (128Mi-256Mi, 50m-300m)
- [x] Reduced worker app resources (128Mi-256Mi, 50m-300m)
- [x] Reduced redis resources (64Mi-128Mi, 50m-200m)
- [x] Added postgres resources (128Mi-256Mi, 50m-200m)
- [x] Reduced Prometheus resources (256Mi-512Mi, 100m-500m)
- [x] Reduced Grafana resources (128Mi-256Mi, 50m-200m)
- [x] Reduced Loki resources (128Mi-256Mi, 50m-200m)
- [x] Reduced Promtail resources (64Mi-128Mi, 50m-100m)

### 7. High Availability Features Removal
- [x] Removed HPA from vote app
- [x] Removed HPA from result app
- [x] Removed HPA from worker app
- [x] Removed HPA from redis
- [x] Removed PodDisruptionBudget from all apps
- [x] Removed NetworkPolicy from all apps
- [x] Reduced replicas to 1 for all services

### 8. Namespace Consolidation
- [x] Created unified 'voting-app' namespace
- [x] Created unified 'observability' namespace
- [x] Moved vote app to voting-app namespace
- [x] Moved result app to voting-app namespace
- [x] Moved worker app to voting-app namespace
- [x] Moved redis to voting-app namespace
- [x] Moved postgres to voting-app namespace
- [x] Updated all service DNS references

### 9. Observability Stack Implementation
- [x] Created Prometheus deployment (simplified)
- [x] Created Prometheus ConfigMap with scrape configs
- [x] Created Prometheus PVC (2Gi)
- [x] Created Prometheus ServiceAccount and RBAC
- [x] Created Grafana deployment
- [x] Created Grafana ConfigMap with datasources
- [x] Created Grafana PVC (1Gi)
- [x] Created Loki deployment (single-binary mode)
- [x] Created Loki ConfigMap
- [x] Created Loki PVC (2Gi)
- [x] Created Promtail DaemonSet
- [x] Created Promtail ConfigMap
- [x] Created Promtail ServiceAccount and RBAC
- [x] Configured Grafana datasources (Prometheus + Loki)

### 10. Configuration Updates
- [x] Updated Redis config (reduced maxmemory to 128mb)
- [x] Updated Redis config (disabled persistence)
- [x] Updated vote app env vars (redis service DNS)
- [x] Updated result app env vars (postgres service DNS)
- [x] Updated worker app env vars (redis and postgres DNS)
- [x] Simplified init containers
- [x] Updated health check configurations

### 11. Documentation
- [x] Created comprehensive README.md
- [x] Created CHANGES.md with detailed comparison
- [x] Created QUICK-START.md for easy deployment
- [x] Created deployment script (deploy.sh)
- [x] Created cleanup script (cleanup.sh)
- [x] Created verification script (verify.sh)
- [x] Created kustomization.yaml
- [x] Created this checklist

### 12. File Organization
- [x] Created local-kcl folder
- [x] Organized app manifests in root of local-kcl
- [x] Organized observability manifests in subfolder
- [x] Did not modify existing cloud-app-gcp folder
- [x] Did not modify existing example-voting-app folder

## 📋 Manifest Inventory

### Application Manifests (6 files)
1. `namespace.yaml` - Creates voting-app and observability namespaces
2. `postgres-deployment.yaml` - PostgreSQL database
3. `redis-deployment.yaml` - Redis cache
4. `vote-deployment.yaml` - Python Flask voting frontend
5. `result-deployment.yaml` - Node.js results frontend
6. `worker-deployment.yaml` - .NET worker backend

### Observability Manifests (4 files)
1. `observability/prometheus-deployment.yaml` - Metrics collection
2. `observability/grafana-deployment.yaml` - Visualization
3. `observability/loki-deployment.yaml` - Log aggregation
4. `observability/promtail-deployment.yaml` - Log collection

### Automation & Documentation (7 files)
1. `deploy.sh` - Automated deployment script
2. `cleanup.sh` - Cleanup script
3. `verify.sh` - Verification script
4. `kustomization.yaml` - Kustomize configuration
5. `README.md` - Complete documentation
6. `CHANGES.md` - Detailed change log
7. `QUICK-START.md` - Quick start guide
8. `MANIFEST-CHECKLIST.md` - This file

**Total Files**: 18 files

## 🔍 Component Mapping

| Docker Compose Service | Kubernetes Manifest | Namespace | Exposure |
|----------------------|-------------------|-----------|----------|
| vote | vote-deployment.yaml | voting-app | NodePort 31000 |
| result | result-deployment.yaml | voting-app | NodePort 31001 |
| worker | worker-deployment.yaml | voting-app | None |
| redis | redis-deployment.yaml | voting-app | ClusterIP |
| db (postgres) | postgres-deployment.yaml | voting-app | ClusterIP |
| - | prometheus-deployment.yaml | observability | NodePort 32090 |
| - | grafana-deployment.yaml | observability | NodePort 32300 |
| - | loki-deployment.yaml | observability | ClusterIP |
| - | promtail-deployment.yaml | observability | DaemonSet |

## 🔄 Service Communication Matrix

```
Vote App
  ├──▶ Redis (redis.voting-app.svc.cluster.local:6379)

Result App
  └──▶ PostgreSQL (postgres.voting-app.svc.cluster.local:5432)

Worker App
  ├──▶ Redis (redis.voting-app.svc.cluster.local:6379)
  └──▶ PostgreSQL (postgres.voting-app.svc.cluster.local:5432)

Prometheus
  ├──▶ Kubernetes API
  ├──▶ Vote App (vote.voting-app.svc.cluster.local:80)
  ├──▶ Result App (result.voting-app.svc.cluster.local:80)
  ├──▶ Redis (redis.voting-app.svc.cluster.local:6379)
  └──▶ PostgreSQL (postgres.voting-app.svc.cluster.local:5432)

Grafana
  ├──▶ Prometheus (prometheus.observability.svc.cluster.local:9090)
  └──▶ Loki (loki.observability.svc.cluster.local:3100)

Promtail
  └──▶ Loki (loki.observability.svc.cluster.local:3100)
```

## 📊 Resource Summary

### Memory Allocation
| Component | Request | Limit | Production (Req) | Savings |
|-----------|---------|-------|-----------------|----------|
| Vote | 64Mi | 128Mi | 128Mi | 50% |
| Result | 128Mi | 256Mi | 256Mi | 50% |
| Worker | 128Mi | 256Mi | 256Mi | 50% |
| Redis | 64Mi | 128Mi | 128Mi | 50% |
| Postgres | 128Mi | 256Mi | N/A (Cloud SQL) | - |
| Prometheus | 256Mi | 512Mi | 1Gi | 75% |
| Grafana | 128Mi | 256Mi | N/A | - |
| Loki | 128Mi | 256Mi | 512Mi | 75% |
| Promtail | 64Mi | 128Mi | N/A | - |
| **Total** | **1088Mi** | **2176Mi** | **~2.5Gi** | **~56%** |

### CPU Allocation
| Component | Request | Limit | Production (Req) | Savings |
|-----------|---------|-------|-----------------|----------|
| Vote | 50m | 200m | 100m | 50% |
| Result | 50m | 300m | 200m | 75% |
| Worker | 50m | 300m | 200m | 75% |
| Redis | 50m | 200m | 100m | 50% |
| Postgres | 50m | 200m | N/A | - |
| Prometheus | 100m | 500m | 500m | 80% |
| Grafana | 50m | 200m | N/A | - |
| Loki | 50m | 200m | 200m | 75% |
| Promtail | 50m | 100m | N/A | - |
| **Total** | **550m** | **2200m** | **~1.5** | **~63%** |

### Storage Allocation
| Component | Size | Type | Production |
|-----------|------|------|------------|
| Postgres | 1Gi | PVC | Cloud SQL |
| Prometheus | 2Gi | PVC | 10Gi |
| Grafana | 1Gi | PVC | 2Gi |
| Loki | 2Gi | PVC | 10Gi |
| **Total** | **6Gi** | - | **22Gi** |

## ⚠️ Pre-Deployment Checks

- [ ] Kubernetes cluster is running
- [ ] kubectl is configured and working
- [ ] Cluster has at least 4GB RAM
- [ ] Cluster has at least 2 CPU cores
- [ ] Cluster has at least 10GB storage available
- [ ] No conflicting resources in voting-app namespace
- [ ] No conflicting resources in observability namespace
- [ ] NodePorts 31000, 31001, 32090, 32300 are available

## ✅ Post-Deployment Validation

- [ ] All pods in voting-app namespace are Running
- [ ] All pods in observability namespace are Running
- [ ] Vote app accessible via NodePort 31000
- [ ] Result app accessible via NodePort 31001
- [ ] Can cast vote and see result update
- [ ] Prometheus accessible via NodePort 32090
- [ ] Grafana accessible via NodePort 32300
- [ ] Prometheus shows all targets as UP
- [ ] Grafana shows data from Prometheus
- [ ] Grafana shows logs from Loki
- [ ] No pod restarts or crash loops
- [ ] Resource usage within expected limits

## 🛠️ Testing Scenarios

### Basic Functionality
1. [ ] Vote for Cats, verify vote is recorded
2. [ ] Vote for Dogs, verify vote is recorded
3. [ ] Check results page shows vote counts
4. [ ] Verify worker is processing votes (check logs)

### Database Connectivity
1. [ ] PostgreSQL is accessible from result app
2. [ ] PostgreSQL is accessible from worker app
3. [ ] Data persists after pod restart

### Cache Connectivity
1. [ ] Redis is accessible from vote app
2. [ ] Redis is accessible from worker app
3. [ ] Votes are queued in Redis

### Observability
1. [ ] Prometheus scrapes all Kubernetes targets
2. [ ] Prometheus scrapes application targets
3. [ ] Grafana datasources are connected
4. [ ] Logs appear in Loki/Grafana
5. [ ] Metrics appear in Prometheus/Grafana

### Load Testing (Optional)
1. [ ] Generate 100 votes, verify system handles it
2. [ ] Check resource usage during load
3. [ ] Verify no errors in application logs
4. [ ] Verify metrics spike in Prometheus

## 🔗 Quick Commands Reference

```bash
# Deploy
./deploy.sh

# Verify
./verify.sh

# Watch pods
watch kubectl get pods -n voting-app
watch kubectl get pods -n observability

# Logs
kubectl logs -n voting-app deployment/vote
kubectl logs -n voting-app deployment/result
kubectl logs -n voting-app deployment/worker

# Port forward
kubectl port-forward -n voting-app svc/vote 8080:80
kubectl port-forward -n observability svc/grafana 3000:3000

# Scale
kubectl scale -n voting-app deployment/vote --replicas=2

# Cleanup
./cleanup.sh
```

## 🎯 Success Criteria

Deployment is successful when:

✅ All 5 application pods are Running  
✅ All 4 observability pods are Running  
✅ Vote app UI is accessible  
✅ Result app UI is accessible  
✅ Votes flow through: Vote → Redis → Worker → PostgreSQL → Result  
✅ Prometheus collects metrics  
✅ Grafana visualizes data  
✅ Loki aggregates logs  
✅ No errors in any pod logs  
✅ Resource usage < 3GB RAM and < 2 CPU cores  

---

**Status**: ✅ All tasks completed  
**Date**: 2026-10-02  
**Ready for Deployment**: YES  
