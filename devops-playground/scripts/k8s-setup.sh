#!/usr/bin/env bash
# =============================================================================
# k8s-setup.sh  –  One-click K3s install + DevOps Playground deploy
#
# What this script does (in order):
#   1. Installs K3s (lightweight Kubernetes)
#   2. Configures kubectl
#   3. Waits for the node to be Ready
#   4. Builds the Docker image
#   5. Imports the image into K3s (so it works without a registry)
#   6. Deploys all Kubernetes manifests
#   7. Waits for the pod to start
#   8. Starts port-forward so you can open the app on port 80
#
# Usage:
#   chmod +x scripts/k8s-setup.sh
#   ./scripts/k8s-setup.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

NAMESPACE="devops"
APP_NAME="devops-playground"
IMAGE_NAME="devops-playground:latest"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        DevOps Playground  —  K8s Setup Script           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Install K3s ───────────────────────────────────────────────────────
if command -v k3s &>/dev/null; then
  success "K3s already installed – skipping"
else
  info "Installing K3s (lightweight Kubernetes)..."
  curl -sfL https://get.k3s.io | sh -
  sleep 5
  success "K3s installed"
fi

# ── Step 2: Configure kubectl ─────────────────────────────────────────────────
info "Configuring kubectl..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER":"$USER" ~/.kube/config
export KUBECONFIG=~/.kube/config

# Add to .bashrc so it persists
if ! grep -q "KUBECONFIG" ~/.bashrc; then
  echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
fi
success "kubectl configured"

# ── Step 3: Wait for node Ready ───────────────────────────────────────────────
info "Waiting for Kubernetes node to be Ready..."
for i in $(seq 1 30); do
  STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1)
  if [ "$STATUS" = "Ready" ]; then
    success "Node is Ready"
    break
  fi
  echo -n "."
  sleep 3
done
echo ""
kubectl get nodes
echo ""

# ── Step 4: Install metrics-server (needed for HPA) ──────────────────────────
info "Checking metrics-server..."
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  success "metrics-server already running"
else
  info "Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  # Patch for single-node / self-signed cert
  kubectl patch deployment metrics-server -n kube-system \
    --type='json' \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  sleep 10
  success "metrics-server installed"
fi

# ── Step 5: Build Docker image ────────────────────────────────────────────────
info "Building Docker image ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" .
success "Docker image built"

# ── Step 6: Import image into K3s ─────────────────────────────────────────────
info "Importing image into K3s containerd..."
docker save "${IMAGE_NAME}" | sudo env "PATH=$PATH" k3s ctr images import -
success "Image imported into K3s"

# ── Step 7: Deploy manifests ──────────────────────────────────────────────────
info "Deploying to Kubernetes..."

kubectl apply -f k8s/namespace.yaml
success "Namespace '${NAMESPACE}' ready"

kubectl apply -f k8s/configmap.yaml
success "ConfigMap applied"

kubectl apply -f k8s/deployment.yaml
success "Deployment applied"

kubectl apply -f k8s/service-nodeport.yaml
success "Service (NodePort) applied"

kubectl apply -f k8s/hpa.yaml
success "HPA applied"

# ── Step 8: Wait for pod to be Running ───────────────────────────────────────
info "Waiting for pod to start..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=120s
success "Pod is running"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                   Setup Complete!                        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Pods:"
kubectl get pods -n ${NAMESPACE} -o wide
echo ""
echo "  HPA:"
kubectl get hpa -n ${NAMESPACE}
echo ""
echo "  Service:"
kubectl get svc -n ${NAMESPACE}
echo ""

# ── Step 9: Start port-forward ────────────────────────────────────────────────
info "Starting port-forward on port 80..."
echo ""
echo "  App will be available at:  http://$(curl -s ifconfig.me 2>/dev/null || echo '52.173.127.47'):80"
echo ""
echo "  NEXT: Open a NEW terminal and run:"
echo "    ./scripts/demo-watch.sh"
echo ""
echo "  Press Ctrl+C to stop port-forward"
echo ""

kubectl port-forward svc/${APP_NAME} 80:80 -n ${NAMESPACE} --address 0.0.0.0
