# Quick Start Guide - Voting App on Local Test Cluster

## Prerequisites

- Kubernetes cluster (1 Node, 4GB RAM minimum)
- kubectl configured
- No special requirements (no Helm, no Ingress Controller needed)

## 30-Second Deployment

```bash
cd local-kcl
chmod +x deploy.sh
./deploy.sh
```

That's it! The script will:
1. Create namespaces
2. Deploy PostgreSQL and Redis
3. Deploy Vote, Result, and Worker apps
4. Deploy Prometheus, Grafana, Loki, and Promtail
5. Display access URLs

## Access the Application

### Get Node IP
```bash
kubectl get nodes -o wide
```

### Application URLs
- **Vote**: `http://<NODE_IP>:31000`
- **Result**: `http://<NODE_IP>:31001`

### Observability URLs
- **Prometheus**: `http://<NODE_IP>:32090`
- **Grafana**: `http://<NODE_IP>:32300` (admin/admin)

### Port Forward (for KillerKoda or restricted environments)
```bash
# Vote App
kubectl port-forward -n voting-app svc/vote 8080:80
# Access: http://localhost:8080

# Result App
kubectl port-forward -n voting-app svc/result 8081:80
# Access: http://localhost:8081

# Grafana
kubectl port-forward -n observability svc/grafana 3000:3000
# Access: http://localhost:3000

# Prometheus
kubectl port-forward -n observability svc/prometheus 9090:9090
# Access: http://localhost:9090
```

## Verify Deployment

```bash
chmod +x verify.sh
./verify.sh
```

## Manual Deployment (if you prefer step-by-step)

### Step 1: Namespaces
```bash
kubectl apply -f namespace.yaml
```

### Step 2: Databases
```bash
kubectl apply -f postgres-deployment.yaml
kubectl apply -f redis-deployment.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app=postgres -n voting-app --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n voting-app --timeout=120s
```

### Step 3: Applications
```bash
kubectl apply -f vote-deployment.yaml
kubectl apply -f result-deployment.yaml
kubectl apply -f worker-deployment.yaml
```

### Step 4: Observability (Optional)
```bash
kubectl apply -f observability/prometheus-deployment.yaml
kubectl apply -f observability/loki-deployment.yaml
kubectl apply -f observability/promtail-deployment.yaml
kubectl apply -f observability/grafana-deployment.yaml
```

## Using Kustomize

```bash
kubectl apply -k .
```

## Check Status

```bash
# Pods
kubectl get pods -n voting-app
kubectl get pods -n observability

# Services
kubectl get svc -n voting-app
kubectl get svc -n observability

# All resources
kubectl get all -n voting-app
kubectl get all -n observability
```

## Test the Application

1. **Open Vote App**: Visit `http://<NODE_IP>:31000`
2. **Cast a Vote**: Click Cats or Dogs
3. **View Results**: Visit `http://<NODE_IP>:31001`
4. **Check Metrics**: Visit `http://<NODE_IP>:32090`
5. **View Dashboards**: Visit `http://<NODE_IP>:32300`

## Troubleshooting

### Pods not starting?
```bash
kubectl get pods -n voting-app
kubectl describe pod <pod-name> -n voting-app
kubectl logs <pod-name> -n voting-app
```

### Can't access NodePort?
```bash
# Check if services are created
kubectl get svc -n voting-app

# Check node ports
kubectl get svc -n voting-app -o wide

# Use port-forward as alternative
kubectl port-forward -n voting-app svc/vote 8080:80
```

### Database connection issues?
```bash
# Test PostgreSQL
kubectl exec -it -n voting-app deployment/postgres -- psql -U postgres -d voting_app

# Test Redis
kubectl exec -it -n voting-app deployment/redis -- redis-cli ping
```

### Resource issues?
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n voting-app

# If low on resources, disable observability
kubectl delete -f observability/
```

## Clean Up

```bash
chmod +x cleanup.sh
./cleanup.sh
```

Or manually:
```bash
kubectl delete namespace voting-app observability
```

## Resource Usage

**Expected Resource Usage:**
- Memory: ~1.1 GB (requests), ~2.3 GB (limits)
- CPU: ~0.55 cores (requests), ~2.5 cores (limits)
- Storage: ~6 GB total

**Fits comfortably in:** 4GB RAM cluster

## What's Different from Production?

✅ No Cloud SQL - Uses PostgreSQL in cluster  
✅ No Gateway API - Uses NodePort  
✅ No Helm - Plain Kubernetes manifests  
✅ Reduced resources - Optimized for small cluster  
✅ Single replicas - No HA features  
✅ Consolidated namespaces - Simplified architecture  

See [CHANGES.md](CHANGES.md) for detailed comparison.

## Next Steps

1. **Explore Grafana**: Create custom dashboards
2. **Query Logs**: Use Loki in Grafana to explore application logs
3. **Load Test**: Use `hey` or `ab` to generate traffic
4. **Monitor**: Watch Prometheus metrics during load
5. **Scale**: Try `kubectl scale deployment vote -n voting-app --replicas=2`

## Support

For issues or questions, check:
- [README.md](README.md) - Full documentation
- [CHANGES.md](CHANGES.md) - Detailed changes
- Kubernetes logs: `kubectl logs -n voting-app <pod-name>`
- Events: `kubectl get events -n voting-app --sort-by='.lastTimestamp'`

---

**Happy Testing! 🚀**
