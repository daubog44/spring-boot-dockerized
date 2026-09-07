#!/usr/bin/env bash
# Ferma lo stack locale avviato con `task dev` e libera le porte.
# Equivalente POSIX di scripts/dev-down.ps1.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dev-lib.sh
. "$SCRIPT_DIR/dev-lib.sh"

REPO_ROOT="$(dev_repo_root)"
LOG_DIR="$(dev_log_dir)"

stopped="$(stop_dev_stack "$LOG_DIR")"

# PostgreSQL: solo se e' stato `task dev` ad accenderlo. `stop` e non `down`,
# cosi' il volume con i dati resta al suo posto.
if [ -f "$LOG_DIR/dev.postgres" ]; then
  echo "  fermo il container PostgreSQL"
  (cd "$REPO_ROOT/demo" && docker compose stop postgres >/dev/null 2>&1) || \
    echo "  (Docker non raggiungibile: container gia' fermo?)"
  rm -f "$LOG_DIR/dev.postgres"
  stopped=$((stopped + 1))
fi

if [ "$stopped" -eq 0 ]; then
  echo "Nessun processo dello stack locale in esecuzione."
else
  echo "Stack locale fermato, porte libere."
fi
