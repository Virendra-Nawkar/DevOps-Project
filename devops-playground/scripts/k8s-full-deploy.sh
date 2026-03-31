#!/usr/bin/env bash
# =============================================================================
# k8s-full-deploy.sh  –  Deploy the FULL stack to Kubernetes
#
# What this deploys:
#
#   Namespace: devops
#     • devops-playground  (main app + HPA)
#     • app-blue           (v1.0.0 for blue/green)
#     • app-green          (v2.0.0 for blue/green)
#     • router             (traffic splitter)
#
#   Namespace: monitoring
#     • Prometheus         (metrics + alerting)
#     • Grafana            (dashboards + logs)
#     • Alertmanager       (alert routing)
#     • Loki               (log storage)
#     • Promtail           (log collector DaemonSet)
#
# After deploy, port-forwards everything so you can access on allowed ports:
#   Port 80  → devops-playground (main app)
#   Port 82  → Prometheus
#   Port 83  → Grafana  (admin/devops123)
#   Port 84  → Alertmanager
#   Port 85  → Router (blue/green)
#
# Usage:
#   chmod +x scripts/k8s-full-deploy.sh
#   ./scripts/k8s-full-deploy.sh
# =============================================================================
set -euo pipefail

# Always run from project root regardless of where script is called from
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
RED='\033[0;31m';   BOLD='\033[1m';      NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()    { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }

export KUBECONFIG=~/.kube/config

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       DevOps Playground  —  Full K8s Deploy                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────
step "Preflight checks"
command -v kubectl &>/dev/null || error "kubectl not found. Run k8s-setup.sh first."
kubectl cluster-info &>/dev/null || error "Cannot reach cluster. Is K3s running?"
success "Cluster reachable"

# ── Build images ──────────────────────────────────────────────────────────────
step "Building Docker images"
info "Building main app image..."
docker build -t devops-playground:latest .
success "devops-playground:latest built"

info "Building router image..."
docker build -t devops-router:latest -f Dockerfile.router .
success "devops-router:latest built"

info "Importing images into K3s..."
docker save devops-playground:latest | sudo env "PATH=$PATH" k3s ctr images import -
docker save devops-router:latest     | sudo env "PATH=$PATH" k3s ctr images import -
success "Images imported into K3s"

# ── Namespaces ────────────────────────────────────────────────────────────────
step "Creating namespaces"
kubectl apply -f k8s/namespace.yaml
success "Namespaces: devops + monitoring"

# ══════════════════════════════════════════════════════════════════════════════
# DEVOPS NAMESPACE  –  App
# ══════════════════════════════════════════════════════════════════════════════
step "Deploying app (devops namespace)"

kubectl apply -f k8s/configmap.yaml
success "ConfigMap"

kubectl apply -f k8s/deployment.yaml
success "Deployment (main app)"

kubectl apply -f k8s/service-nodeport.yaml
success "Service (main app)"

kubectl apply -f k8s/hpa.yaml
success "HPA (autoscaler)"

# ── Blue/Green ────────────────────────────────────────────────────────────────
step "Deploying blue/green (devops namespace)"

kubectl apply -f k8s/bluegreen/app-blue.yaml
success "app-blue (v1.0.0)"

kubectl apply -f k8s/bluegreen/app-green.yaml
success "app-green (v2.0.0)"

kubectl apply -f k8s/bluegreen/router.yaml
success "router (traffic splitter)"

# ══════════════════════════════════════════════════════════════════════════════
# MONITORING NAMESPACE
# ══════════════════════════════════════════════════════════════════════════════
step "Deploying monitoring stack (monitoring namespace)"

kubectl apply -f k8s/monitoring/prometheus.yaml
success "Prometheus"

kubectl apply -f k8s/monitoring/grafana.yaml
success "Grafana"

kubectl apply -f k8s/monitoring/alertmanager.yaml
success "Alertmanager"

kubectl apply -f k8s/monitoring/loki.yaml
success "Loki"

kubectl apply -f k8s/monitoring/promtail.yaml
success "Promtail (DaemonSet)"

# ── Wait for all pods ─────────────────────────────────────────────────────────
step "Waiting for pods to start"

info "Waiting for devops namespace..."
kubectl rollout status deployment/devops-playground -n devops --timeout=120s
kubectl rollout status deployment/app-blue          -n devops --timeout=120s
kubectl rollout status deployment/app-green         -n devops --timeout=120s
kubectl rollout status deployment/router            -n devops --timeout=120s
success "All devops pods running"

info "Waiting for monitoring namespace..."
kubectl rollout status deployment/prometheus   -n monitoring --timeout=180s
kubectl rollout status deployment/grafana      -n monitoring --timeout=180s
kubectl rollout status deployment/alertmanager -n monitoring --timeout=120s
kubectl rollout status deployment/loki         -n monitoring --timeout=120s
success "All monitoring pods running"

# ── Status summary ────────────────────────────────────────────────────────────
step "Deployment complete — full status"

echo ""
echo -e "${BOLD}  devops namespace:${NC}"
kubectl get pods,svc,hpa -n devops

echo ""
echo -e "${BOLD}  monitoring namespace:${NC}"
kubectl get pods,svc -n monitoring

# ── Start port-forwards ───────────────────────────────────────────────────────
step "Starting port-forwards"

# Kill any existing port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

info "Forwarding port 80  → devops-playground (app)"
kubectl port-forward svc/devops-playground 80:80   -n devops     --address 0.0.0.0 &>/tmp/pf-app.log &

info "Forwarding port 82  → Prometheus"
kubectl port-forward svc/prometheus         82:9090 -n monitoring --address 0.0.0.0 &>/tmp/pf-prom.log &

info "Forwarding port 83  → Grafana"
kubectl port-forward svc/grafana            83:3000 -n monitoring --address 0.0.0.0 &>/tmp/pf-grafana.log &

info "Forwarding port 84  → Alertmanager"
kubectl port-forward svc/alertmanager       84:9093 -n monitoring --address 0.0.0.0 &>/tmp/pf-alert.log &

info "Forwarding port 85  → Router (blue/green)"
kubectl port-forward svc/router             85:5001 -n devops     --address 0.0.0.0 &>/tmp/pf-router.log &

sleep 3

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                 All services are live!                       ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Main App:${NC}       http://52.173.127.47:80"
echo -e "  ${BOLD}User Guide:${NC}     http://52.173.127.47:80/guide"
echo -e "  ${BOLD}Prometheus:${NC}     http://52.173.127.47:82"
echo -e "  ${BOLD}Grafana:${NC}        http://52.173.127.47:83  (admin/devops123)"
echo -e "  ${BOLD}Alertmanager:${NC}   http://52.173.127.47:84"
echo -e "  ${BOLD}Router (B/G):${NC}   http://52.173.127.47:85"
echo ""
echo -e "  ${BOLD}Watch scaling:${NC}"
echo -e "  ${BLUE}kubectl get pods,hpa -n devops -w${NC}"
echo ""
echo -e "  ${BOLD}Live demo dashboard:${NC}"
echo -e "  ${BLUE}./scripts/demo-watch.sh${NC}"
echo ""
echo -e "  ${YELLOW}Port-forward logs: /tmp/pf-*.log${NC}"
echo ""

# Keep script running so port-forwards stay alive
wait
