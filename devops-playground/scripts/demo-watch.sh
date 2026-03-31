#!/usr/bin/env bash
# =============================================================================
# demo-watch.sh  –  Live scaling dashboard for the presentation
#
# Shows in ONE terminal:
#   • Pod list with status + age + node
#   • HPA status (current replicas, CPU%, target)
#   • Resource usage (kubectl top)
#   • Refreshes every 3 seconds automatically
#
# Usage:
#   chmod +x scripts/demo-watch.sh
#   ./scripts/demo-watch.sh
#
# TIP: Run this in a separate terminal while you trigger load from the browser
# =============================================================================

NAMESPACE="devops"
INTERVAL=3

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear_screen() { printf '\033[H\033[2J'; }

print_header() {
  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║          DevOps Playground  —  Live Scaling Dashboard               ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${CYAN}Namespace:${NC} ${NAMESPACE}   ${CYAN}Time:${NC} $(date '+%H:%M:%S')   ${CYAN}Refresh:${NC} every ${INTERVAL}s"
  echo ""
}

print_pods() {
  echo -e "${BOLD}${YELLOW}  🫛  PODS${NC}"
  echo "  ─────────────────────────────────────────────────────────────────"

  POD_COUNT=0
  RUNNING=0
  PENDING=0

  while IFS= read -r line; do
    if [[ "$line" == NAME* ]]; then
      echo -e "  ${CYAN}${line}${NC}"
      continue
    fi
    STATUS=$(echo "$line" | awk '{print $3}')
    case "$STATUS" in
      Running)   echo -e "  ${GREEN}${line}${NC}"; ((RUNNING++)) ;;
      Pending)   echo -e "  ${YELLOW}${line}${NC}"; ((PENDING++)) ;;
      *)         echo -e "  ${RED}${line}${NC}" ;;
    esac
    ((POD_COUNT++)) || true
  done < <(kubectl get pods -n "$NAMESPACE" -o wide --no-headers 2>/dev/null | \
           awk '{printf "%-50s %-10s %-10s %-6s %-20s\n", $1, $2, $3, $5, $7}')

  echo ""
  echo -e "  Total pods: ${BOLD}${POD_COUNT}${NC}  |  Running: ${GREEN}${BOLD}${RUNNING}${NC}  |  Pending: ${YELLOW}${BOLD}${PENDING}${NC}"
  echo ""
}

print_hpa() {
  echo -e "${BOLD}${YELLOW}  📈  HPA  (Horizontal Pod Autoscaler)${NC}"
  echo "  ─────────────────────────────────────────────────────────────────"

  HPA_DATA=$(kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null)
  if [ -z "$HPA_DATA" ]; then
    echo -e "  ${RED}No HPA found${NC}"
    echo ""
    return
  fi

  echo -e "  ${CYAN}NAME                    MIN  MAX  CURRENT  CPU-CURRENT  CPU-TARGET${NC}"

  while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    MIN=$(echo "$line"  | awk '{print $5}')
    MAX=$(echo "$line"  | awk '{print $6}')
    CUR=$(echo "$line"  | awk '{print $7}')
    CPU=$(echo "$line"  | awk '{print $4}' | tr -d '%<')

    # Color code CPU
    if [ -n "$CPU" ] && [ "$CPU" -gt 80 ] 2>/dev/null; then
      CPU_COLOR="${RED}"
    elif [ -n "$CPU" ] && [ "$CPU" -gt 50 ] 2>/dev/null; then
      CPU_COLOR="${YELLOW}"
    else
      CPU_COLOR="${GREEN}"
    fi

    # Color code pod count
    if [ -n "$CUR" ] && [ "$CUR" -gt 3 ] 2>/dev/null; then
      CUR_COLOR="${YELLOW}"
    else
      CUR_COLOR="${GREEN}"
    fi

    printf "  %-25s %-5s %-5s ${CUR_COLOR}%-9s${NC} ${CPU_COLOR}%-12s${NC} %s\n" \
      "$NAME" "$MIN" "$MAX" "$CUR" "${CPU}%" "50%"
  done <<< "$HPA_DATA"
  echo ""
}

print_resources() {
  echo -e "${BOLD}${YELLOW}  🖥️   RESOURCE USAGE (kubectl top)${NC}"
  echo "  ─────────────────────────────────────────────────────────────────"
  TOP=$(kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null)
  if [ -z "$TOP" ]; then
    echo -e "  ${YELLOW}metrics-server starting up... wait 60s after setup${NC}"
  else
    echo -e "  ${CYAN}POD NAME                              CPU        MEMORY${NC}"
    while IFS= read -r line; do
      echo "  $line"
    done <<< "$TOP"
  fi
  echo ""
}

print_scale_bar() {
  CURRENT=$(kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $7}' | head -1)
  MAX=10
  CURRENT=${CURRENT:-1}

  echo -e "${BOLD}${YELLOW}  📊  SCALE VISUALIZER  (${CURRENT}/${MAX} pods)${NC}"
  echo "  ─────────────────────────────────────────────────────────────────"
  echo -n "  ["
  for i in $(seq 1 $MAX); do
    if [ "$i" -le "$CURRENT" ]; then
      echo -ne "${GREEN}█${NC}"
    else
      echo -ne "${CYAN}░${NC}"
    fi
  done
  echo "]  ${BOLD}${CURRENT}${NC} / ${MAX}"
  echo ""
}

print_events() {
  echo -e "${BOLD}${YELLOW}  📋  RECENT EVENTS${NC}"
  echo "  ─────────────────────────────────────────────────────────────────"
  kubectl get events -n "$NAMESPACE" \
    --sort-by='.lastTimestamp' \
    --field-selector reason!=Pulling,reason!=Pulled,reason!=Created,reason!=Started \
    2>/dev/null | tail -5 | while IFS= read -r line; do
    if echo "$line" | grep -qi "scal"; then
      echo -e "  ${GREEN}$line${NC}"
    elif echo "$line" | grep -qi "warn\|fail\|error"; then
      echo -e "  ${RED}$line${NC}"
    else
      echo "  $line"
    fi
  done
  echo ""
}

print_tip() {
  echo -e "  ${CYAN}─────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Quick actions:${NC}"
  echo -e "  • Open ${BOLD}http://52.173.127.47:80${NC} → Click ${YELLOW}Add Load${NC} to trigger scaling"
  echo -e "  • Manual scale: ${CYAN}kubectl scale deploy/devops-playground --replicas=5 -n devops${NC}"
  echo -e "  • Stop watching: ${RED}Ctrl+C${NC}"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "Starting live dashboard... (Ctrl+C to stop)"
sleep 1

while true; do
  clear_screen
  print_header
  print_scale_bar
  print_hpa
  print_pods
  print_resources
  print_events
  print_tip
  sleep "$INTERVAL"
done
