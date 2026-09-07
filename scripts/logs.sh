#!/usr/bin/env bash
# Segue i log dei servizi avviati con `task dev`.
# Equivalente POSIX di scripts/logs.ps1.
#
#   task logs              tutti i servizi
#   task logs -- wms       solo wms
#   task logs -- wms crm   solo quei due
#
# Ctrl+C chiude solo questa vista: i servizi restano in esecuzione.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dev-lib.sh
. "$SCRIPT_DIR/dev-lib.sh"

LOG_DIR="$(dev_log_dir)"
TAIL_LINES=30

files=()
names=()
while [ $# -gt 0 ]; do
  case "$1" in
    -Tail|--tail) TAIL_LINES="$2"; shift 2 ;;
    *) names+=("$1"); shift ;;
  esac
done

# Senza argomenti seguiamo i servizi dell'ultimo avvio, nel loro ordine
# (eureka per primo), non tutti i .log che si trovano nella cartella.
if [ "${#names[@]}" -eq 0 ] && [ -f "$LOG_DIR/dev.services" ]; then
  while read -r n; do
    [ -n "$n" ] && names+=("$n")
  done <"$LOG_DIR/dev.services"
fi

if [ "${#names[@]}" -eq 0 ]; then
  for f in "$LOG_DIR"/*.log; do
    [ -e "$f" ] && files+=("$f")
  done
else
  for name in "${names[@]}"; do
    if [ -f "$LOG_DIR/$name.log" ]; then
      files+=("$LOG_DIR/$name.log")
    else
      echo "Nessun log per '$name'." >&2
    fi
  done
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "Nessun log da seguire. Avvia prima lo stack con 'task dev'." >&2
  exit 1
fi

# tail -f su piu' file antepone gia' l'intestazione "==> nome <==" a ogni blocco.
exec tail -n "$TAIL_LINES" -F "${files[@]}"
