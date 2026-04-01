# DevOps Playground

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?style=flat&logo=flask&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat&logo=grafana&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=github-actions&logoColor=white)

A hands-on DevOps learning platform for testing **Kubernetes autoscaling, chaos engineering, blue/green deployments, and full-stack observability** — all from a live browser dashboard.

Deploy in minutes on any Linux VM or Kubernetes cluster and watch pods scale, alerts fire, and traffic shift in real time.

---

## What You Can Test and Learn

- **Horizontal Pod Autoscaling (HPA)** — CPU stress triggers automatic pod scaling (min 1 → max 10)
- **Chaos Engineering** — Kill liveness/readiness probes, inject latency, trigger errors from the dashboard
- **Blue/Green Deployment** — Shift traffic between v1 and v2 with a single slider or curl command
- **Prometheus Metrics** — Scrape custom app metrics, write PromQL queries
- **Grafana Dashboards** — Pre-built dashboard with CPU, memory, request rate, error rate
- **Log Aggregation** — Loki + Promtail collect pod logs queryable in Grafana Explore
- **Alertmanager** — Alert rules fire when CPU is high or errors spike
- **CI/CD Pipeline** — GitHub Actions builds and deploys on every push to main
- **Rolling Updates & Rollbacks** — Zero-downtime deployments with one kubectl command
- **Downward API** — Pod name, IP, and node injected as environment variables

---

## Architecture

```
                        ┌─────────────────────────────────┐
                        │         Your Browser             │
                        └────────────┬────────────────────┘
                                     │
              ┌──────────────────────▼──────────────────────┐
              │              Azure VM / Linux Host           │
              │                                             │
              │  :80  ──► Main App Dashboard (Flask)        │
              │  :81  ──► Nginx Load Balancer               │
              │  :82  ──► Prometheus (metrics)              │
              │  :83  ──► Grafana (dashboards)              │
              │  :84  ──► Alertmanager (alerts)             │
              │  :85  ──► Blue/Green Router                 │
              │                                             │
              │  ┌─────────────┐   ┌─────────────────────┐ │
              │  │  app-blue   │   │      Prometheus      │ │
              │  │  (v1.0.0)   │   │      Grafana         │ │
              │  ├─────────────┤   │      Alertmanager    │ │
              │  │  app-green  │   │      Loki            │ │
              │  │  (v2.0.0)   │   │      Promtail        │ │
              │  └─────────────┘   └─────────────────────┘ │
              └─────────────────────────────────────────────┘
```

**Two deployment modes:**

| Mode | Best For | Setup Time |
|------|----------|------------|
| Docker Compose | Quick demo, local testing | ~5 min |
| Kubernetes (K8s) | Real autoscaling, production patterns | ~15 min |

---

## Port Reference

| Port | Service | URL | Login |
|------|---------|-----|-------|
| **80** | Main App + Dashboard | `http://YOUR_VM_IP:80` | — |
| **81** | Nginx Load Balancer | `http://YOUR_VM_IP:81` | — |
| **82** | Prometheus | `http://YOUR_VM_IP:82` | — |
| **83** | Grafana | `http://YOUR_VM_IP:83` | `admin` / `devops123` |
| **84** | Alertmanager | `http://YOUR_VM_IP:84` | — |
| **85** | Blue/Green Router | `http://YOUR_VM_IP:85` | — |

> Replace `YOUR_VM_IP` with your actual VM IP (e.g. `52.173.127.47`).

---

## Project Structure

```
devops-playground/
├── app/
│   ├── app.py                      # Flask backend — all 22 endpoints
│   ├── router.py                   # Blue/Green traffic splitter
│   ├── requirements.txt
│   ├── router_requirements.txt
│   └── templates/
│       ├── index.html              # Live dark-theme dashboard
│       └── guide.html              # End-user guide with Try-It buttons
│
├── Dockerfile                      # Multi-stage build (builder → runtime)
├── Dockerfile.router               # Router service container
├── docker-compose.yml              # Full local stack (10 services)
│
├── k8s/
│   ├── namespace.yaml              # devops + monitoring namespaces
│   ├── configmap.yaml
│   ├── deployment.yaml             # Probes, resource limits, anti-affinity
│   ├── service.yaml
│   ├── service-nodeport.yaml
│   ├── hpa.yaml                    # CPU 50% + Memory 70% autoscaling
│   ├── ingress.yaml                # Nginx ingress + NetworkPolicy
│   ├── bluegreen/
│   │   ├── app-blue.yaml           # v1.0.0 deployment + service
│   │   ├── app-green.yaml          # v2.0.0 deployment + service
│   │   └── router.yaml             # Weight-based proxy router
│   └── monitoring/
│       ├── prometheus.yaml
│       ├── grafana.yaml
│       ├── alertmanager.yaml
│       ├── loki.yaml
│       └── promtail.yaml           # DaemonSet — collects logs from all nodes
│
├── monitoring/                     # Config files for monitoring services
│   ├── prometheus.yml
│   ├── alert-rules.yml
│   ├── alertmanager.yml
│   ├── grafana-datasource.yml
│   ├── grafana-dashboard.json
│   ├── loki-config.yml
│   ├── nginx.conf
│   └── promtail-config.yml
│
├── scripts/
│   ├── k8s-full-deploy.sh          # Deploy full stack to existing K8s cluster
│   ├── k8s-setup.sh                # One-click K3s install + deploy
│   ├── demo-watch.sh               # Live terminal scaling dashboard
│   ├── build.sh                    # Docker build & push
│   ├── deploy.sh                   # Basic deployment
│   ├── load-test.sh                # External load generator
│   └── cleanup.sh                  # Tear down all resources
│
└── .github/workflows/
    └── ci-cd.yml                   # Build → push GHCR → SSH deploy on push
```

---

## Install Everything From Scratch (Fresh Ubuntu/Debian VM)

Run these once on your VM before doing anything else.

### 1. System packages

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  git \
  curl \
  wget \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  net-tools \
  htop \
  unzip
```

### 2. Docker

```bash
# Add Docker's official GPG key and repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow running Docker without sudo
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

### 3. kubectl

```bash
# Add Kubernetes apt repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubectl

# Verify
kubectl version --client
```

### 4. Python 3.11 (for running the app directly without Docker)

```bash
sudo apt install -y python3.11 python3.11-venv python3-pip

# Verify
python3 --version
pip3 --version
```

### 5. Open Firewall Ports (Azure / AWS / GCP security group)

On Azure Portal: go to your VM → **Networking** → **Add inbound port rule** for each port:

| Port | Protocol | Purpose |
|------|----------|---------|
| 80 | TCP | Main app dashboard |
| 81 | TCP | Nginx load balancer |
| 82 | TCP | Prometheus |
| 83 | TCP | Grafana |
| 84 | TCP | Alertmanager |
| 85 | TCP | Blue/Green router |

Or via Azure CLI:
```bash
for port in 80 81 82 83 84 85; do
  az network nsg rule create \
    --resource-group YOUR_RESOURCE_GROUP \
    --nsg-name YOUR_NSG_NAME \
    --name "Allow-$port" \
    --protocol Tcp \
    --direction Inbound \
    --priority $((1000 + port)) \
    --destination-port-range $port \
    --access Allow
done
```

---

## Run Locally (No Docker, Pure Python)

If you just want to run the Flask app on your machine without Docker:

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/devops-playground.git
cd devops-playground

# 2. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate          # Linux / macOS
# venv\Scripts\activate           # Windows

# 3. Install dependencies
pip install -r app/requirements.txt

# 4. Set environment variables (optional — defaults work fine)
export FLASK_ENV=development
export APP_VERSION=1.0.0

# 5. Run the app
python app/app.py

# App is now running at http://localhost:80
# (or http://127.0.0.1:80 — same thing)
```

> **Note:** Running locally without Docker means only the Flask app runs.
> Prometheus, Grafana, Loki, and Nginx are Docker-only services.
> For the full monitoring stack, use Docker Compose.

---

## Option A — Docker Compose (Quick Start, ~5 min)

### Prerequisites

- Linux VM or local machine with Docker installed (see install steps above)
- Ports 80–85 open in your firewall / security group

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/devops-playground.git
cd devops-playground

# 2. Start all 10 services
docker compose up --build -d

# 3. Check all containers are up
docker compose ps
```

### Access the Services

```
Dashboard:    http://YOUR_VM_IP:80
Nginx LB:     http://YOUR_VM_IP:81
Prometheus:   http://YOUR_VM_IP:82
Grafana:      http://YOUR_VM_IP:83   (admin / devops123)
Alertmanager: http://YOUR_VM_IP:84
Router:       http://YOUR_VM_IP:85
```

### Scale App Containers (Docker Compose)

```bash
# Simulate 3 app pods behind Nginx
docker compose up --scale app=3 -d

# Watch them in real time
docker compose ps
```

### Stop Everything

```bash
docker compose down -v
```

---

## Option B — Full Kubernetes Deployment (~15 min)

### Prerequisites

- A Kubernetes cluster (single node or multi-node) with `kubectl` access
- Docker installed on the master node (to build images)
- Ports 80–85 accessible from your machine

### Step 1 — Install metrics-server (required for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify it's running
kubectl get deployment metrics-server -n kube-system
```

If pods are in `Pending` state due to no StorageClass, also install:

### Step 2 — Install StorageClass (required for Prometheus/Grafana/Loki PVCs)

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Verify
kubectl get storageclass
```

### Step 3 — Clone and Deploy

```bash
git clone https://github.com/YOUR_USERNAME/devops-playground.git
cd devops-playground

# Run the full deploy script (builds images, imports to containerd, applies all manifests)
./scripts/k8s-full-deploy.sh
```

The script will:
1. Build `devops-playground:latest` and `devops-router:latest` Docker images
2. Import images into containerd (`ctr -n k8s.io images import`)
3. Apply all K8s manifests (namespaces, deployments, services, HPA, monitoring stack)
4. Start `kubectl port-forward` processes to expose services on ports 80–85

### Step 4 — Multi-node Clusters: Distribute Images to Worker Nodes

If you have a multi-node cluster, images must be present on **every** worker node. Run this on the master:

```bash
# Save images to tar files
docker save devops-playground:latest -o /tmp/dp.tar
docker save devops-router:latest     -o /tmp/router.tar

# Copy and import on each worker node (replace IPs with your worker IPs)
for NODE in 10.0.1.5 10.0.1.7; do
  scp /tmp/dp.tar /tmp/router.tar vir@$NODE:/tmp/
  ssh vir@$NODE "sudo ctr -n k8s.io images import /tmp/dp.tar && \
                 sudo ctr -n k8s.io images import /tmp/router.tar"
done
```

### Step 5 — Verify Everything Is Running

```bash
kubectl get pods --all-namespaces

# Expected output:
# NAMESPACE    NAME                              READY   STATUS    RESTARTS
# devops       devops-playground-xxx-yyy         1/1     Running   0
# devops       app-blue-xxx-yyy                  1/1     Running   0
# devops       app-green-xxx-yyy                 1/1     Running   0
# devops       router-xxx-yyy                    1/1     Running   0
# monitoring   prometheus-xxx-yyy                1/1     Running   0
# monitoring   grafana-xxx-yyy                   1/1     Running   0
# monitoring   alertmanager-xxx-yyy              1/1     Running   0
# monitoring   loki-xxx-yyy                      1/1     Running   0
# monitoring   promtail-xxx-yyy (DaemonSet)      1/1     Running   0
```

### Step 6 — Access Services (Manual Port-Forward)

If the deploy script's port-forwards stopped, restart them:

```bash
kubectl port-forward svc/devops-playground 80:80   -n devops      --address 0.0.0.0 &
kubectl port-forward svc/prometheus        82:9090  -n monitoring  --address 0.0.0.0 &
kubectl port-forward svc/grafana           83:3000  -n monitoring  --address 0.0.0.0 &
kubectl port-forward svc/alertmanager      84:9093  -n monitoring  --address 0.0.0.0 &
kubectl port-forward svc/router            85:85    -n devops      --address 0.0.0.0 &
```

---

## Using the Dashboard

Open `http://YOUR_VM_IP:80` in your browser.

### Dashboard Cards

| Card | What It Shows |
|------|---------------|
| **CPU Usage** | Real-time CPU % of the current pod |
| **Memory Usage** | RSS memory in MB |
| **Total Requests** | Cumulative HTTP requests since startup |
| **Uptime** | How long this pod has been running |
| **Pod Info** | Pod name, IP, node (from Kubernetes Downward API) |
| **Live CPU Chart** | 60-second rolling chart updated via Server-Sent Events |
| **Services Health** | Live health check of all 6 services |
| **Pod Scaling Visualizer** | Shows how many replicas HPA is running |
| **Blue/Green Status** | Current traffic split between v1 and v2 |
| **Live Alerts** | Active Alertmanager alerts |

### User Guide

Click the **"User Guide"** link at the top of the dashboard for interactive documentation with live "Try It" buttons for every endpoint.

---

## Testing Autoscaling (HPA)

The HPA scales pods when **CPU > 50%** (scale up within 30s) or scales down after **5 minutes** of low CPU.

### Step-by-Step Demo

**Terminal 1 — Watch pods scale:**
```bash
kubectl get pods -n devops -w
```

**Terminal 2 — Watch HPA:**
```bash
kubectl get hpa -n devops -w
```

**Terminal 3 — Start load (choose one):**

Option A — Click "Add Load" in the dashboard at `http://YOUR_VM_IP:80`

Option B — Use curl:
```bash
# Start 4 CPU stress workers
curl -X POST http://YOUR_VM_IP:80/load/start \
  -H "Content-Type: application/json" \
  -d '{"workers": 4}'

# Check how many workers are running
curl http://YOUR_VM_IP:80/load/status

# Stop all workers
curl -X POST http://YOUR_VM_IP:80/load/stop
```

Option C — Use the load-test script:
```bash
./scripts/load-test.sh http://YOUR_VM_IP:80 120 30
# Arguments: URL  duration(sec)  concurrent-requests
```

**What to observe:**
1. CPU bar in dashboard climbs above 50%
2. HPA fires: `REPLICAS` column increases from 1 to 2, 3, ...
3. New pods appear in `kubectl get pods -n devops`
4. Stop load → pods scale back down after ~5 minutes

### Live Terminal Monitoring Script

```bash
./scripts/demo-watch.sh
```

This shows a refreshing terminal dashboard every 3 seconds with pods, HPA status, resource usage, and a scaling bar visualizer.

---

## Chaos Engineering

All chaos endpoints are on port **:80**. Each button on the dashboard calls these same endpoints.

| Action | Endpoint | What Happens | Kubernetes Response |
|--------|----------|--------------|---------------------|
| Kill Liveness | `POST /chaos/unhealthy` | `/health` returns 500 | Pod restarted after 3 consecutive failures (~30s) |
| Restore Liveness | `POST /chaos/healthy` | `/health` returns 200 | Pod stays running |
| Kill Readiness | `POST /chaos/not-ready` | `/ready` returns 503 | Pod removed from Service — no traffic sent to it |
| Restore Readiness | `POST /chaos/ready` | `/ready` returns 200 | Pod re-added to Service endpoints |
| Add Latency | `POST /chaos/delay` | Every response is delayed | Latency visible in Grafana, SSE stream |
| Trigger Error | `GET /chaos/error` | Returns HTTP 500 | Error rate counter increments |

### Curl Commands

```bash
VM=http://YOUR_VM_IP

# Make the pod appear unhealthy (Kubernetes will restart it in ~30s)
curl -X POST $VM:80/chaos/unhealthy

# Watch the restart happen
kubectl get pods -n devops -w

# Restore health
curl -X POST $VM:80/chaos/healthy

# Remove pod from load balancer (readiness probe fails)
curl -X POST $VM:80/chaos/not-ready

# Restore readiness
curl -X POST $VM:80/chaos/ready

# Add 500ms delay to all responses
curl -X POST $VM:80/chaos/delay \
  -H "Content-Type: application/json" \
  -d '{"ms": 500}'

# Trigger a 500 error (increments error counter in metrics)
curl $VM:80/chaos/error

# See pod restart count
kubectl describe pod -n devops -l app=devops-playground | grep "Restart Count"
```

---

## Blue/Green Deployment

The router on port **:85** splits traffic between `app-blue` (v1.0.0) and `app-green` (v2.0.0) based on a configurable weight.

### Concept

```
Browser → :85 (Router)
              ├── 70% → app-blue  (v1.0.0, stable)
              └── 30% → app-green (v2.0.0, canary)
```

### Control the Traffic Split

```bash
VM=http://YOUR_VM_IP

# Check current split
curl $VM:85/router/weight

# Send 50% to each version
curl -X POST $VM:85/router/weight \
  -H "Content-Type: application/json" \
  -d '{"blue": 50}'

# Send all traffic to green (v2 fully promoted)
curl -X POST $VM:85/router/weight \
  -H "Content-Type: application/json" \
  -d '{"blue": 0}'

# Roll back — send everything back to blue (v1)
curl -X POST $VM:85/router/weight \
  -H "Content-Type: application/json" \
  -d '{"blue": 100}'

# Reset traffic counters
curl -X POST $VM:85/router/reset
```

### Python Example

```python
import requests

VM = "http://YOUR_VM_IP"

# Gradual canary rollout
for blue_pct in [90, 70, 50, 30, 10, 0]:
    r = requests.post(f"{VM}:85/router/weight", json={"blue": blue_pct})
    print(f"Blue: {blue_pct}% → {r.json()}")
    # Check error rates before each step
    metrics = requests.get(f"{VM}:80/metrics").text
    print("Errors so far:", [l for l in metrics.splitlines() if "error_total" in l])
```

---

## Monitoring

### Prometheus — `http://YOUR_VM_IP:82`

Prometheus scrapes metrics from the app every 15 seconds. Open the Prometheus UI and run PromQL queries:

```promql
# CPU usage per pod
rate(process_cpu_seconds_total[1m])

# HTTP request rate (requests per second)
rate(http_requests_total[1m])

# Total errors
http_errors_total

# Memory usage (bytes)
process_resident_memory_bytes

# HPA replica count
kube_horizontalpodautoscaler_status_current_replicas{namespace="devops"}
```

**Check targets are being scraped:**
1. Open `http://YOUR_VM_IP:82`
2. Go to **Status → Targets**
3. All targets should show `UP`

### Grafana — `http://YOUR_VM_IP:83`

**Login:** `admin` / `devops123`

**Open the pre-built dashboard:**
1. Click the grid icon (Dashboards) in the left sidebar
2. Select **DevOps Playground** from the list
3. The dashboard shows: CPU usage, memory, request rate, error rate, pod count, uptime

**Query logs with Loki:**
1. Click the compass icon (Explore) in the left sidebar
2. Select **Loki** as the datasource
3. Use LogQL:
```logql
# All logs from the devops namespace
{namespace="devops"}

# Only error logs
{namespace="devops"} |= "ERROR"

# Logs from a specific pod
{namespace="devops", pod="devops-playground-xxx"}
```

### Alertmanager — `http://YOUR_VM_IP:84`

Alertmanager receives alerts from Prometheus when rules fire. Current alert rules:

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighCPUUsage | CPU > 80% for 2 min | warning |
| HighErrorRate | Error rate > 5% | critical |
| PodRestartingTooMuch | Restarts > 5 in 1 hour | warning |

Fired alerts are also visible in the **"Live Alerts"** card on the main dashboard.

---

## Rolling Update & Rollback

```bash
# Deploy a new image version (zero-downtime rolling update)
kubectl set image deployment/devops-playground \
  app=devops-playground:2.0.0 -n devops

# Watch the rollout progress
kubectl rollout status deployment/devops-playground -n devops

# View rollout history
kubectl rollout history deployment/devops-playground -n devops

# Roll back to previous version
kubectl rollout undo deployment/devops-playground -n devops

# Roll back to a specific revision
kubectl rollout undo deployment/devops-playground -n devops --to-revision=2
```

---

## Full API Reference

All endpoints are available at `http://YOUR_VM_IP:80` (main app) or `http://YOUR_VM_IP:85` (router).

### App Endpoints (port :80)

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/` | — | Live dashboard UI |
| GET | `/guide` | — | End-user guide with Try-It buttons |
| GET | `/health` | — | Liveness probe — returns `{"status":"healthy"}` |
| GET | `/ready` | — | Readiness probe — returns `{"status":"ready"}` |
| GET | `/info` | — | Full pod info: name, IP, node, CPU, memory, uptime |
| GET | `/metrics` | — | Prometheus-format metrics |
| GET | `/stream` | — | Server-Sent Events — live JSON metrics every 2s |
| POST | `/load/start` | `{"workers": 4}` | Start N CPU stress worker processes |
| POST | `/load/stop` | — | Stop all CPU workers |
| GET | `/load/status` | — | Number of active workers |
| POST | `/chaos/unhealthy` | — | Make liveness probe return 500 |
| POST | `/chaos/healthy` | — | Restore liveness probe |
| POST | `/chaos/not-ready` | — | Make readiness probe return 503 |
| POST | `/chaos/ready` | — | Restore readiness probe |
| POST | `/chaos/delay` | `{"ms": 500}` | Inject latency on all responses |
| GET | `/chaos/error` | — | Return HTTP 500 immediately |
| GET | `/services/health` | — | Health check all 6 services |
| GET | `/pods` | — | Pod list from Prometheus |
| GET | `/bluegreen/status` | — | Current blue/green traffic split |
| POST | `/bluegreen/weight` | `{"blue": 50}` | Set traffic weight (0–100 = % to blue) |
| POST | `/alerts` | Alertmanager JSON | Webhook receiver for Alertmanager |
| GET | `/alerts/list` | — | List currently active alerts |

### Router Endpoints (port :85)

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| GET | `/router/health` | — | Router health check |
| GET | `/router/weight` | — | Get current blue/green split |
| POST | `/router/weight` | `{"blue": 70}` | Set split (blue 70% = green 30%) |
| POST | `/router/reset` | — | Reset request counters |
| ANY | `/*` | — | Proxy all requests to blue or green |

### Live Metrics Stream (SSE)

The `/stream` endpoint pushes a JSON event every 2 seconds:

```bash
# Watch live in terminal
curl -N http://YOUR_VM_IP:80/stream

# Example event:
# data: {"cpu": 43.2, "memory": 87.4, "requests": 1523, "errors": 2,
#        "workers": 4, "uptime": 3612, "pod": "devops-playground-abc-xyz",
#        "replicas": 3, "node": "vm1"}
```

**Python consumer:**
```python
import requests

def watch_metrics(vm_ip):
    url = f"http://{vm_ip}:80/stream"
    with requests.get(url, stream=True) as resp:
        for line in resp.iter_lines():
            if line.startswith(b"data:"):
                print(line.decode())

watch_metrics("YOUR_VM_IP")
```

---

## Kubernetes Reference Commands

```bash
# ── Status ─────────────────────────────────────────────────────────────
# All resources across all namespaces
kubectl get all --all-namespaces

# Pods in devops namespace (with node placement)
kubectl get pods -n devops -o wide

# HPA status (shows current vs target CPU)
kubectl get hpa -n devops

# Watch pods scale in real time
kubectl get pods -n devops -w

# Watch HPA in real time
kubectl get hpa -n devops -w

# ── Resource Usage ──────────────────────────────────────────────────────
# CPU and memory per pod
kubectl top pods -n devops

# CPU and memory per node
kubectl top nodes

# ── Logs ───────────────────────────────────────────────────────────────
# Stream logs from all app pods
kubectl logs -n devops -l app=devops-playground -f

# Logs from a specific pod
kubectl logs -n devops <pod-name>

# Last 50 lines from all pods
kubectl logs -n devops -l app=devops-playground --tail=50

# ── Debugging ──────────────────────────────────────────────────────────
# Describe a pod (shows events, restart reasons)
kubectl describe pod -n devops <pod-name>

# Exec into a running pod
kubectl exec -it -n devops $(kubectl get pod -n devops -l app=devops-playground \
  -o name | head -1) -- bash

# Events (sorted by time — see scale events and restarts)
kubectl get events -n devops --sort-by='.lastTimestamp'

# ── Scaling ────────────────────────────────────────────────────────────
# Manually scale to 5 replicas (bypasses HPA temporarily)
kubectl scale deployment devops-playground --replicas=5 -n devops

# Describe HPA for detailed behavior
kubectl describe hpa devops-playground -n devops

# ── Networking ─────────────────────────────────────────────────────────
# Check services and their cluster IPs
kubectl get svc -n devops
kubectl get svc -n monitoring

# Check network policies
kubectl describe networkpolicy -n devops

# ── Config ─────────────────────────────────────────────────────────────
# View configmap
kubectl get configmap -n devops -o yaml

# View deployment spec
kubectl describe deployment devops-playground -n devops

# Check resource limits
kubectl describe deployment devops-playground -n devops | grep -A 6 "Limits"
```

---

## CI/CD Pipeline (GitHub Actions)

Every push to `main` automatically:
1. Builds the Docker image
2. Pushes to GitHub Container Registry (GHCR)
3. SSHs into your VM and runs `docker compose up --build -d`
4. Runs a health check on port 80

### Setup

**1. Add GitHub Secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `VM_HOST` | Your VM's IP address (e.g. `52.173.127.47`) |
| `VM_USER` | SSH username (e.g. `vir` or `azureuser`) |
| `VM_SSH_KEY` | Contents of your private SSH key (`~/.ssh/id_rsa`) |

**2. Push to main:**
```bash
git add .
git commit -m "feat: update app"
git push origin main
```

**3. Watch the pipeline:**
- Go to your repo → **Actions** tab → watch the workflow run

### Manual Trigger

```bash
# SSH into VM and redeploy manually
ssh vir@YOUR_VM_IP
cd ~/DevOps-Project/devops-playground
git pull
docker compose up --build -d
```

---

## Cleanup

```bash
# ── Docker Compose ──────────────────────────────────────────────────────
# Stop all containers and remove volumes
docker compose down -v

# ── Kubernetes ─────────────────────────────────────────────────────────
# Delete app workloads only
kubectl delete namespace devops

# Delete monitoring stack only
kubectl delete namespace monitoring

# Delete everything (app + monitoring)
kubectl delete namespace devops monitoring

# Or use the cleanup script
./scripts/cleanup.sh --all
```

---

## Troubleshooting

### ImagePullBackOff

**Cause:** Pods are scheduled on worker nodes but images only exist on the master node.

**Fix:** Import images on each worker node:
```bash
docker save devops-playground:latest -o /tmp/dp.tar
docker save devops-router:latest -o /tmp/router.tar

for NODE in WORKER_IP_1 WORKER_IP_2; do
  scp /tmp/dp.tar /tmp/router.tar vir@$NODE:/tmp/
  ssh vir@$NODE "sudo ctr -n k8s.io images import /tmp/dp.tar && \
                 sudo ctr -n k8s.io images import /tmp/router.tar"
done
```

### Pods Stuck in Pending

**Cause:** PersistentVolumeClaims have no StorageClass to bind to (affects Prometheus, Grafana, Loki).

**Fix:**
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### HPA Shows `<unknown>` for CPU/Memory

**Cause:** metrics-server is not installed or not working.

**Fix:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# If it's installed but not working (e.g. TLS issues on bare-metal):
kubectl patch deployment metrics-server -n kube-system \
  --type json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-",
  "value":"--kubelet-insecure-tls"}]'
```

### Port Already in Use

**Cause:** Another process is using port 80, 82, etc.

**Fix:**
```bash
# Find what's using the port
sudo lsof -i :80

# Kill the port-forward processes
pkill -f "kubectl port-forward"

# Restart port-forwards
kubectl port-forward svc/devops-playground 80:80 -n devops --address 0.0.0.0 &
```

### Pod CrashLoopBackOff

**Fix:**
```bash
# Check what crashed
kubectl logs <pod-name> -n devops --previous

# See the restart reason
kubectl describe pod <pod-name> -n devops | grep -A 10 "Last State"
```

### Docker Compose Port Conflict

**Cause:** Another service (e.g. Apache) is using port 80.

**Fix:**
```bash
# Check what's on port 80
sudo ss -tlnp | grep :80

# Stop the conflicting service
sudo systemctl stop apache2   # or nginx, etc.
```

---

## Learning Path

If you're new to this project, follow this order:

1. **Start with Docker Compose** (`docker compose up --build -d`) — get familiar with the dashboard
2. **Try the load generator** — click "Add Load", watch CPU rise
3. **Open Grafana** (port :83) — see metrics on the pre-built dashboard
4. **Try chaos engineering** — kill liveness probe, watch K8s restart the pod
5. **Deploy to Kubernetes** — run `k8s-full-deploy.sh`, see pods spread across nodes
6. **Trigger HPA scaling** — load test the K8s deployment, watch `kubectl get hpa -n devops -w`
7. **Try blue/green** — shift traffic from v1 to v2 using the router on port :85
8. **Query Loki logs** — open Grafana Explore, query `{namespace="devops"}`
9. **Set up CI/CD** — configure GitHub Actions secrets, push a change, watch it auto-deploy
