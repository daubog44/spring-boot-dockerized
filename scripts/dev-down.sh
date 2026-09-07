#!/usr/bin/env bash
# Ferma lo stack locale avviato con `task dev`.
# Equivalente POSIX di scripts/dev-down.ps1.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/.dev-logs"
PID_FILE="$LOG_DIR/dev.pids"

stopped=0

if [ -f "$PID_FILE" ]; then
  while read -r pid name; do
    [ -z "${pid:-}" ] && continue
    if kill -0 "$pid" >/dev/null 2>&1; then
      echo "Termino $name (PID $pid)"
      # Il processo mvnw ha java come figlio: chiude l'intero gruppo.
      kill -TERM -- "-$pid" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1
      stopped=$((stopped + 1))
    fi
  done <"$PID_FILE"
  rm -f "$PID_FILE"
fi

# Rete di sicurezza: chiude quel che resta in ascolto sulle porte dello stack.
if command -v lsof >/dev/null 2>&1; then
  ports="8761 8081 8082 8083 8080"
  if [ -f "$LOG_DIR/dev.ports" ]; then
    ports="$ports $(tr '
' ' ' <"$LOG_DIR/dev.ports")"
  fi
  for port in $ports; do
    for pid in $(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null); do
      echo "Termino il processo sulla porta $port (PID $pid)"
      kill -TERM "$pid" >/dev/null 2>&1
      stopped=$((stopped + 1))
    done
  done
fi

if [ "$stopped" -eq 0 ]; then
  echo "Nessun processo dello stack locale in esecuzione."
else
  echo "Stack locale fermato."
fi
