#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# load-test.sh – External load test to trigger HPA scaling
#
# Requires: curl  (for API calls)
#           ab    (Apache Bench)  OR  hey (https://github.com/rakyll/hey)
#
# Usage:
#   ./scripts/load-test.sh <APP_URL> [duration_seconds] [concurrency]
#
# Examples:
#   ./scripts/load-test.sh http://localhost:5000
#   ./scripts/load-test.sh http://devops-playground.local 120 50
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_URL=${1:-"http://localhost:5000"}
DURATION=${2:-60}
CONCURRENCY=${3:-20}

echo "═══════════════════════════════════════════════════════════"
echo "  DevOps Playground – Load Test"
echo "  Target:      ${APP_URL}"
echo "  Duration:    ${DURATION}s"
echo "  Concurrency: ${CONCURRENCY}"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Step 1: trigger CPU workers via the app's own endpoint ──────────────────
echo "🔥  Step 1: Triggering CPU stress workers inside the pod..."
curl -s -X POST "${APP_URL}/load/start" \
  -H "Content-Type: application/json" \
  -d '{"workers":4}' | python3 -m json.tool 2>/dev/null || true
echo ""

# ── Step 2: external HTTP load ───────────────────────────────────────────────
echo "🌐  Step 2: Sending ${CONCURRENCY} concurrent HTTP requests for ${DURATION}s..."
echo ""

if command -v hey &>/dev/null; then
  hey -z "${DURATION}s" -c "${CONCURRENCY}" "${APP_URL}/"
elif command -v ab &>/dev/null; then
  TOTAL=$((CONCURRENCY * DURATION * 10))
  ab -n "${TOTAL}" -c "${CONCURRENCY}" -t "${DURATION}" "${APP_URL}/" 2>&1 | \
    grep -E "Requests per second|Time per request|Failed|Complete"
else
  echo "⚠️  Neither 'hey' nor 'ab' found. Falling back to curl loop..."
  END=$((SECONDS + DURATION))
  REQUEST_COUNT=0
  while [ $SECONDS -lt $END ]; do
    for i in $(seq 1 "${CONCURRENCY}"); do
      curl -s "${APP_URL}/" > /dev/null &
    done
    wait
    REQUEST_COUNT=$((REQUEST_COUNT + CONCURRENCY))
    echo -ne "\r  Sent ${REQUEST_COUNT} requests…"
  done
  echo ""
fi

echo ""
echo "📊  Current app metrics:"
curl -s "${APP_URL}/info" | python3 -m json.tool 2>/dev/null || \
  curl -s "${APP_URL}/info"

echo ""
echo "🛑  Stopping CPU workers..."
curl -s -X POST "${APP_URL}/load/stop" | python3 -m json.tool 2>/dev/null || true

echo ""
echo "✅  Load test complete. Watch pods scale down over ~5 minutes."
echo "    kubectl get hpa devops-playground -n devops -w"
