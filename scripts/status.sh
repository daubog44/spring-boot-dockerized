#!/usr/bin/env bash
# Mostra lo stato dello stack: porte, container e registro Eureka.
# Equivalente POSIX di scripts/status.ps1.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dev-lib.sh
. "$SCRIPT_DIR/dev-lib.sh"

LOG_DIR="$(dev_log_dir)"

# Nome atteso per ogni porta (cambia da traccia a traccia).
port_name() {
  case "$1" in
    8761) echo "eureka" ;;
    8081) echo "product" ;;
    8082) echo "crm" ;;
    8083) echo "wms" ;;
    8080) echo "wms-ui" ;;
    *)    echo "wms-ui (--ui-port)" ;;
  esac
}

echo ""
echo "PORTE"
printf '  %-6s %-18s %-12s %s\n' "PORTA" "SERVIZIO" "STATO" "PROCESSO"
for port in $(dev_ports "$LOG_DIR"); do
  pid="$(port_pids "$port" | head -n 1)"
  if [ -z "$pid" ]; then
    printf '  %-6s %-18s %-12s %s\n' "$port" "$(port_name "$port")" "libera" "-"
    continue
  fi
  name="$(process_name "$pid")"
  case "$name" in
    java*) state="in ascolto" ;;
    *)     state="ESTRANEO" ;;
  esac
  printf '  %-6s %-18s %-12s %s\n' "$port" "$(port_name "$port")" "$state" "$name (PID $pid)"
done

echo ""
echo "CONTAINER"
if ! command -v docker >/dev/null 2>&1; then
  echo "  Docker non installato."
else
  containers="$(docker ps --filter 'name=exam-' --format '  {{.Names}}  {{.Status}}' 2>/dev/null)"
  if [ -z "$containers" ]; then
    echo "  Nessun container dell'esame in esecuzione."
  else
    echo "$containers"
  fi
fi

echo ""
echo "REGISTRO EUREKA"
if command -v curl >/dev/null 2>&1 && curl -sf -m 3 -H 'Accept: application/json' http://localhost:8761/eureka/apps >/dev/null 2>&1; then
  curl -sf -m 3 -H 'Accept: application/json' http://localhost:8761/eureka/apps |
    grep -o '"name":"[A-Z-]*"' | sed 's/"name":"/  /; s/"$//' | sort -u
else
  echo "  Eureka non risponde su http://localhost:8761"
fi

echo ""
echo "  task dev / task dev-down      stack locale"
echo "  task docker-up / docker-down  stack in container"
echo ""
