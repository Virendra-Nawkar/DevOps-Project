#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build.sh – Build and tag the Docker image
# Usage: ./scripts/build.sh [version]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION=${1:-"1.0.0"}
IMAGE="devops-playground"
REGISTRY=${REGISTRY:-""}   # set REGISTRY=myregistry.io/myrepo to push remotely

echo "🔨  Building Docker image: ${IMAGE}:${VERSION}"
docker build \
  --file Dockerfile \
  --target runtime \
  --tag "${IMAGE}:${VERSION}" \
  --tag "${IMAGE}:latest" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

echo ""
echo "📦  Image size:"
docker images "${IMAGE}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

if [ -n "$REGISTRY" ]; then
  echo ""
  echo "🚀  Pushing to registry: ${REGISTRY}/${IMAGE}:${VERSION}"
  docker tag "${IMAGE}:${VERSION}" "${REGISTRY}/${IMAGE}:${VERSION}"
  docker tag "${IMAGE}:latest"     "${REGISTRY}/${IMAGE}:latest"
  docker push "${REGISTRY}/${IMAGE}:${VERSION}"
  docker push "${REGISTRY}/${IMAGE}:latest"
  echo "✅  Push complete."
fi

echo ""
echo "✅  Build complete. Run locally with:"
echo "    docker run -p 5000:5000 ${IMAGE}:${VERSION}"
