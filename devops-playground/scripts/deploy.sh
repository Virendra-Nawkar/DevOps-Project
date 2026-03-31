#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh – Deploy or update the app on Kubernetes
# Usage: ./scripts/deploy.sh [version]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION=${1:-"1.0.0"}
NAMESPACE="devops"

echo "🚀  Deploying devops-playground v${VERSION} to Kubernetes..."
echo ""

# 1. Create namespace (idempotent)
echo "📁  Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# 2. Apply ConfigMap
echo "⚙️   Applying ConfigMap..."
kubectl apply -f k8s/configmap.yaml

# 3. Apply Deployment (rolling update if exists)
echo "📦  Applying Deployment..."
kubectl apply -f k8s/deployment.yaml

# 4. Update image tag if version was passed
if [ "$VERSION" != "1.0.0" ]; then
  echo "🔄  Updating image to version ${VERSION}..."
  kubectl set image deployment/devops-playground \
    app="devops-playground:${VERSION}" \
    -n "${NAMESPACE}"
fi

# 5. Apply Service
echo "🌐  Applying Service..."
kubectl apply -f k8s/service.yaml

# 6. Apply HPA
echo "📈  Applying HPA..."
kubectl apply -f k8s/hpa.yaml

# 7. Apply Ingress + NetworkPolicy
echo "🔀  Applying Ingress & NetworkPolicy..."
kubectl apply -f k8s/ingress.yaml

# 8. Wait for rollout
echo ""
echo "⏳  Waiting for rollout to complete..."
kubectl rollout status deployment/devops-playground -n "${NAMESPACE}" --timeout=120s

echo ""
echo "✅  Deployment complete!"
echo ""
echo "📊  Current pods:"
kubectl get pods -n "${NAMESPACE}" -l app=devops-playground

echo ""
echo "📈  HPA status:"
kubectl get hpa devops-playground -n "${NAMESPACE}"

echo ""
echo "💡  Useful commands:"
echo "    kubectl get pods -n ${NAMESPACE} -w"
echo "    kubectl get hpa  -n ${NAMESPACE} -w"
echo "    kubectl logs -n ${NAMESPACE} -l app=devops-playground -f"
