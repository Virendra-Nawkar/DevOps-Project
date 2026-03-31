# DevOps Playground ⚙️

A **hands-on Kubernetes testing project** for DevOps engineers.
Spin it up locally or on a real cluster and practise:

- **Horizontal Pod Autoscaling (HPA)** — watch pods scale up in real-time
- **Load generation** — one-click CPU stress from the browser dashboard
- **Chaos Engineering** — kill liveness/readiness probes, inject latency, trigger errors
- **Rolling deployments & rollbacks**
- **Prometheus metrics + Grafana dashboards**
- **Network Policies, Resource limits, Downward API**

---

## Project Structure

```
devops-playground/
├── app/
│   ├── app.py               # Flask backend (load gen, chaos, metrics, SSE)
│   ├── requirements.txt
│   └── templates/
│       └── index.html       # Live dark-theme dashboard
├── Dockerfile               # Multi-stage build (builder → runtime)
├── docker-compose.yml       # Full local stack (app + nginx + prometheus + grafana)
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml      # Probes, resource limits, rolling update, anti-affinity
│   ├── service.yaml
│   ├── hpa.yaml             # CPU + Memory autoscaling
│   └── ingress.yaml         # Nginx ingress + NetworkPolicy
├── monitoring/
│   ├── prometheus.yml
│   ├── nginx.conf
│   ├── grafana-datasource.yml
│   ├── grafana-dashboard-provider.yml
│   └── grafana-dashboard.json
└── scripts/
    ├── build.sh             # Docker build & push
    ├── deploy.sh            # Full K8s deploy
    ├── load-test.sh         # External load generator
    └── cleanup.sh           # Tear everything down
```

---

## Quick Start — Docker (local, no Kubernetes needed)

```bash
# 1. Build the image
./scripts/build.sh

# 2. Start the full stack (app + nginx + prometheus + grafana)
docker compose up --build

# 3. Open browser
#   Dashboard:   http://localhost:5000
#   Nginx LB:    http://localhost:80
#   Prometheus:  http://localhost:9090
#   Grafana:     http://localhost:3000  (admin / devops123)

# 4. Simulate multiple pods behind load balancer
docker compose up --scale app=3
```

---

## Quick Start — Kubernetes

### Prerequisites
- `kubectl` connected to a cluster (Minikube, Kind, EKS, GKE, AKS …)
- metrics-server installed (for HPA)

```bash
# Install metrics-server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Build & load image into Minikube
eval $(minikube docker-env)
./scripts/build.sh

# Deploy everything
./scripts/deploy.sh

# Port-forward to access the dashboard
kubectl port-forward svc/devops-playground 5000:80 -n devops
# Open http://localhost:5000
```

---

## Testing Scenarios

### 1. Autoscaling (HPA) Demo

```bash
# Terminal 1 – watch pods scale
kubectl get pods -n devops -w

# Terminal 2 – watch HPA
kubectl get hpa devops-playground -n devops -w

# Terminal 3 – trigger load via dashboard button OR script
./scripts/load-test.sh http://localhost:5000 120 30
```

Click **"Add Load"** in the browser dashboard.
Watch CPU climb → HPA fires → new pods appear in ~30 seconds.
Click **"Stop All Load"** → pods scale back down after ~5 minutes.

---

### 2. Chaos Engineering

| Button | What Happens | K8s Reaction |
|--------|-------------|--------------|
| Kill Liveness | `/health` returns 500 | Pod restarted after 3 failures (~30s) |
| Kill Readiness | `/ready` returns 503 | Pod removed from Service endpoints |
| Add 500ms Delay | Every response delayed | SLA breach visible in metrics |
| Trigger Error | Returns HTTP 500 | Error counter increments in Grafana |

```bash
# Watch pod restarts live
kubectl get pods -n devops -w

# See restart count increase
kubectl describe pod -n devops -l app=devops-playground | grep Restart
```

---

### 3. Rolling Update (Zero Downtime)

```bash
# Update to v2 (builds new image)
./scripts/build.sh 2.0.0
kubectl set image deployment/devops-playground \
  app=devops-playground:2.0.0 -n devops

# Watch rolling update
kubectl rollout status deployment/devops-playground -n devops

# Rollback if needed
kubectl rollout undo deployment/devops-playground -n devops
```

---

### 4. Manual Scaling

```bash
# Scale to 5 pods immediately (bypasses HPA)
kubectl scale deployment devops-playground --replicas=5 -n devops

# Scale back to 1
kubectl scale deployment devops-playground --replicas=1 -n devops
```

---

### 5. Resource & Limit Testing

```bash
# Check resource usage
kubectl top pods -n devops

# Describe deployment to see requests/limits
kubectl describe deployment devops-playground -n devops | grep -A 4 Limits
```

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Live dashboard |
| GET | `/health` | Liveness probe |
| GET | `/ready` | Readiness probe |
| GET | `/metrics` | Prometheus metrics |
| GET | `/info` | Full pod JSON |
| GET | `/stream` | SSE live metrics |
| GET | `/load/status` | Active workers |
| POST | `/load/start` | Start CPU stress `{"workers":2}` |
| POST | `/load/stop` | Stop all workers |
| POST | `/chaos/unhealthy` | Fail liveness |
| POST | `/chaos/healthy` | Restore liveness |
| POST | `/chaos/not-ready` | Fail readiness |
| POST | `/chaos/ready` | Restore readiness |
| POST | `/chaos/delay` | Inject latency `{"ms":500}` |
| GET | `/chaos/error` | Trigger 500 error |

---

## Useful kubectl Commands

```bash
# All-in-one status
kubectl get all -n devops

# Stream logs from all pods
kubectl logs -n devops -l app=devops-playground -f

# Exec into a pod
kubectl exec -it $(kubectl get pod -n devops -l app=devops-playground -o name | head -1) -n devops -- bash

# Events (see scale events)
kubectl get events -n devops --sort-by='.lastTimestamp'

# HPA details
kubectl describe hpa devops-playground -n devops

# Network policy
kubectl describe networkpolicy devops-playground-netpol -n devops
```

---

## Cleanup

```bash
# Remove K8s resources (keep namespace)
./scripts/cleanup.sh

# Remove everything including namespace
./scripts/cleanup.sh --all

# Stop Docker Compose
docker compose down -v
```
