#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# cleanup.sh – Tear down all resources
# Usage: ./scripts/cleanup.sh [--all]   (--all also removes the namespace)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NAMESPACE="devops"
REMOVE_NS=${1:-""}

echo "🧹  Cleaning up devops-playground..."

# Stop any load first
APP_URL=${APP_URL:-"http://localhost:5000"}
echo "🛑  Stopping load workers (if any)..."
curl -s -X POST "${APP_URL}/load/stop" &>/dev/null || true

echo ""
echo "🗑️   Removing Kubernetes resources..."
kubectl delete -f k8s/ingress.yaml   --ignore-not-found=true
kubectl delete -f k8s/hpa.yaml       --ignore-not-found=true
kubectl delete -f k8s/service.yaml   --ignore-not-found=true
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/configmap.yaml  --ignore-not-found=true

if [ "$REMOVE_NS" = "--all" ]; then
  echo "🗑️   Removing namespace ${NAMESPACE}..."
  kubectl delete -f k8s/namespace.yaml --ignore-not-found=true
fi

echo ""
echo "🐳  Stopping Docker Compose (if running)..."
docker compose down -v 2>/dev/null || true

echo ""
echo "✅  Cleanup complete."
