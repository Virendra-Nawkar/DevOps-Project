# DevOps Playground — Demo Guide

> **Goal:** Show a real audience how Kubernetes automatically scales pods when load increases, and scales back down when load stops.

---

## What You Will Show

```
START                                          DURING LOAD                    AFTER LOAD STOPS
─────────────────────────────────────────────────────────────────────────────────────────────
1 Pod running         →    CPU spikes above 50%    →    Pods scale back to 1
                           HPA detects it                (after 5 min cool-down)
                           New pods created
                           1 → 2 → 4 → 6 pods
```

---

## Infrastructure Overview

```
                    ┌─────────────────────────────────┐
                    │        K3s Kubernetes Node       │
                    │         (52.173.127.47)          │
                    │                                  │
                    │  ┌──────────────────────────┐    │
                    │  │    HPA (autoscaler)       │    │
                    │  │  CPU > 50% → add pods     │    │
                    │  │  CPU < 50% → remove pods  │    │
                    │  └────────────┬─────────────┘    │
                    │               │ controls          │
                    │  ┌────────────▼─────────────┐    │
                    │  │       Deployment          │    │
                    │  │  [Pod1] [Pod2] [Pod3]...  │    │
                    │  │  min:1  current:?  max:10 │    │
                    │  └────────────┬─────────────┘    │
                    │               │                   │
                    │  ┌────────────▼─────────────┐    │
                    │  │     Service (port 80)     │    │
                    │  │   Load balances traffic   │    │
                    │  └──────────────────────────┘    │
                    │                                  │
                    │  ┌──────────────────────────┐    │
                    │  │   metrics-server          │    │
                    │  │   Feeds CPU data to HPA   │    │
                    │  └──────────────────────────┘    │
                    └─────────────────────────────────┘
                                   │
                             Port 80 (HTTP)
                                   │
                            Your Browser
```

### Kubernetes objects deployed

| Object | File | Purpose |
|--------|------|---------|
| Namespace | `k8s/namespace.yaml` | Isolates all resources in `devops` namespace |
| ConfigMap | `k8s/configmap.yaml` | App config injected as env vars |
| Deployment | `k8s/deployment.yaml` | Runs the app pods, rolling updates |
| Service | `k8s/service-nodeport.yaml` | Exposes pods, load balances requests |
| HPA | `k8s/hpa.yaml` | Watches CPU, creates/removes pods automatically |
| metrics-server | (auto-installed) | Collects CPU/memory from each pod for HPA |

---

## Setup (Do This Once Before the Demo)

### Step 1 — Push latest code to GitHub

```bash
# On Windows
cd "C:\Users\2474017\OneDrive - Cognizant\Desktop\DevOps\devops-playground"
git add .
git commit -m "demo: add k8s setup and demo scripts"
git push origin main
```

### Step 2 — Pull on VM and run setup

```bash
# On VM
cd ~/DevOps-Project/devops-playground
git pull origin main

chmod +x scripts/*.sh
./scripts/k8s-setup.sh
```

This script automatically:
- Installs K3s (takes ~2 min first time)
- Installs metrics-server
- Builds the Docker image
- Imports image into K3s
- Deploys all manifests
- Starts port-forward on port 80

### Step 3 — Verify everything is ready

```bash
# Check node is Ready
kubectl get nodes

# Check pod is Running
kubectl get pods -n devops

# Check HPA is active (TARGETS should show a number, not <unknown>)
kubectl get hpa -n devops

# Open the app
# http://52.173.127.47:80
```

> **Note:** HPA shows `<unknown>` for the first 60 seconds while metrics-server warms up. Wait 1-2 minutes.

---

## The Demo (Step by Step)

### Before you start — open these in split terminals

```
Terminal 1 (setup + port-forward):
  Already running from k8s-setup.sh

Terminal 2 (live scaling dashboard):
  ./scripts/demo-watch.sh

Browser:
  http://52.173.127.47:80
```

---

### Scene 1 — Show the baseline (1 pod)

**Say:** *"Right now, Kubernetes is running exactly 1 pod of our app. The HPA is watching CPU usage. Our threshold is 50% — if CPU goes above that, Kubernetes will automatically create more pods."*

**Show on screen:**
- `demo-watch.sh` showing 1 pod running
- Scale visualizer: `[█░░░░░░░░░]  1 / 10`
- Browser dashboard: CPU at ~5%, 1 worker

```bash
# Confirm in terminal
kubectl get pods -n devops
kubectl get hpa   -n devops
```

---

### Scene 2 — Trigger the load

**Say:** *"I'm going to click this button to add CPU stress workers inside the pod. Watch what happens to CPU — and then watch the pod count."*

**In the browser:**
1. Set slider to **4 workers**
2. Click **"Add Load"** 3 times (= 12 workers total)
3. Watch CPU bar climb to 80–100%

**In demo-watch.sh — what they will see:**
```
📊  SCALE VISUALIZER  (1/10 pods)
  [█░░░░░░░░░]  1 / 10

📈  HPA
  devops-playground   1   10   1   82%   50%   ← CPU over threshold

  ... 30 seconds later ...

📊  SCALE VISUALIZER  (3/10 pods)
  [███░░░░░░░]  3 / 10

📈  HPA
  devops-playground   1   10   3   65%   50%   ← scaling up

  ... 30 seconds later ...

📊  SCALE VISUALIZER  (5/10 pods)
  [█████░░░░░]  5 / 10
```

**Also show events:**
```bash
kubectl get events -n devops --sort-by='.lastTimestamp' | grep -i "scal"
# SuccessfulRescale   Scaled up replica set to 3
# SuccessfulRescale   Scaled up replica set to 5
```

---

### Scene 3 — Show all pods are real and serving traffic

**Say:** *"Each of these pods is a real container running independently. The service automatically load-balances requests across all of them."*

```bash
# Show all pods with IPs
kubectl get pods -n devops -o wide

# Show pod logs (each pod handles requests)
kubectl logs -n devops -l app=devops-playground --tail=5

# Show the pod identity changes if you refresh the browser
# (each refresh may hit a different pod — different hostname shows)
```

---

### Scene 4 — Stop the load and watch scale-down

**Say:** *"Now I'll stop the load. Kubernetes won't immediately remove pods — it waits 5 minutes to make sure the load is really gone. This prevents flapping."*

**In the browser:**
- Click **"Stop All Load"**

**In demo-watch.sh:**
```
📈  HPA
  devops-playground   1   10   5   8%   50%   ← CPU dropped

  ... 5 minutes later ...

📊  SCALE VISUALIZER  (2/10 pods)
  [██░░░░░░░░]  2 / 10

  ... 5 minutes later ...

📊  SCALE VISUALIZER  (1/10 pods)
  [█░░░░░░░░░]  1 / 10   ← back to normal
```

---

### Scene 5 — Chaos demo (bonus)

**Say:** *"Kubernetes also self-heals. Watch what happens when I make this pod report itself as unhealthy."*

**In the browser:**
- Click **"Kill Liveness"**

```bash
# Watch in terminal — pod will restart
kubectl get pods -n devops -w
# devops-playground-xxx   1/1   Running   0   → Restarting
# devops-playground-xxx   0/1   Running   1   → Restarted
# devops-playground-xxx   1/1   Running   1   → Healthy again
```

**Say:** *"Kubernetes detected the liveness probe failing, killed the container, and restarted it automatically. Zero manual intervention."*

---

### Scene 6 — Rolling update demo (optional)

**Say:** *"Let's deploy a new version with zero downtime."*

```bash
# Simulate a new version by updating the image label
kubectl set image deployment/devops-playground \
  app=devops-playground:latest -n devops \
  --record

# Watch rolling update — old pods go down one by one, new ones come up
kubectl rollout status deployment/devops-playground -n devops

# Rollback if needed
kubectl rollout undo deployment/devops-playground -n devops
```

---

## Useful Commands During the Demo

```bash
# Watch everything live
kubectl get pods,hpa,svc -n devops -w

# See all scaling events
kubectl get events -n devops --sort-by='.lastTimestamp'

# CPU/memory per pod
kubectl top pods -n devops

# Describe HPA (shows scaling decisions)
kubectl describe hpa devops-playground -n devops

# Force scale to 5 pods manually
kubectl scale deployment devops-playground --replicas=5 -n devops

# Force scale back to 1
kubectl scale deployment devops-playground --replicas=1 -n devops

# Delete a pod (K8s will recreate it immediately)
kubectl delete pod -n devops $(kubectl get pod -n devops -o name | head -1)

# Exec into a running pod
kubectl exec -it -n devops \
  $(kubectl get pod -n devops -l app=devops-playground -o name | head -1) -- bash
```

---

## Clean Up After the Demo

```bash
# Remove all Kubernetes resources
kubectl delete namespace devops

# Stop K3s
sudo systemctl stop k3s

# Remove K3s completely (optional)
/usr/local/bin/k3s-uninstall.sh
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| HPA shows `<unknown>` CPU | Wait 60s for metrics-server to start |
| Pod stuck in `Pending` | `kubectl describe pod <name> -n devops` — check events |
| App not accessible on port 80 | Re-run `kubectl port-forward svc/devops-playground 80:80 -n devops --address 0.0.0.0` |
| Image not found | Re-run `docker save devops-playground:latest \| sudo k3s ctr images import -` |
| K3s not starting | `sudo systemctl status k3s` and `sudo journalctl -u k3s -n 50` |
| HPA not scaling | Check `kubectl describe hpa -n devops` for error messages |
