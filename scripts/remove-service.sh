#!/usr/bin/env bash
# Toglie un modulo dal progetto e da tutti i file che lo nominano.
# Equivalente POSIX di scripts/remove-service.ps1 — l'inverso di new-service.
#
#   task remove-service SERVICE=ordini-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
COMPOSE="$DEMO_DIR/docker-compose.yml"

MODULE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module|-Name|--name) MODULE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MODULE" ]; then
  echo "Uso: task remove-service SERVICE=<modulo>" >&2
  exit 1
fi
if [ ! -f "$DEMO_DIR/$MODULE/pom.xml" ]; then
  available=""
  for dir in "$DEMO_DIR"/*/; do
    [ -f "$dir/pom.xml" ] && available="$available $(basename "$dir")"
  done
  echo "Modulo '$MODULE' non trovato. Moduli disponibili:$available" >&2
  exit 1
fi

echo ""
echo "==> Tolgo il modulo $MODULE"
echo ""

# --- Chi lo chiama? -----------------------------------------------------------

# I servizi si chiamano per nome (spring.application.name), quindi cerchiamo
# quello, non il nome della cartella.
APP_NAME="$(printf '%s' "$MODULE" | tr 'a-z' 'A-Z')"
CALLERS="$(grep -rl -e "$APP_NAME" -e "$MODULE" "$DEMO_DIR" \
  --include='*.java' --include='*.html' --exclude-dir=target 2>/dev/null |
  grep -v "^$DEMO_DIR/$MODULE/" | sed "s|^$REPO_ROOT/||" || true)"

# --- Rimozione ----------------------------------------------------------------

remove_line() { # file, regex, etichetta
  if grep -qE "$2" "$1"; then
    grep -vE "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
    echo "  $3"
  fi
}

rm -rf "${DEMO_DIR:?}/$MODULE"
echo "  demo/$MODULE/ (cartella)"

remove_line "$DEMO_DIR/pom.xml" "<module>$MODULE</module>" "demo/pom.xml"
remove_line "$DEMO_DIR/Dockerfile" "^COPY $MODULE/pom\.xml" "demo/Dockerfile"
remove_line "$SCRIPT_DIR/dev.ps1" "Module = '$MODULE'" "scripts/dev.ps1"
remove_line "$SCRIPT_DIR/dev.sh" ":$MODULE:" "scripts/dev.sh"

# Il blocco del compose va tolto per intero, dal nome del servizio fino a prima
# del blocco successivo (riga vuota di separazione compresa).
ML="$(grep -nE "^[[:space:]]+MODULE:[[:space:]]+$MODULE[[:space:]]*\$" "$COMPOSE" | head -n 1 | cut -d: -f1 || true)"
if [ -n "$ML" ]; then
  awk -v ml="$ML" '
    { lines[NR] = $0 }
    END {
      start = ml
      while (start > 1 && lines[start] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) start--
      end = ml + 1
      while (end <= NR && lines[end] !~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && lines[end] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) end++
      while (end > start && lines[end - 1] ~ /^[[:space:]]*$/) end--
      if (end <= NR && lines[end] ~ /^[[:space:]]*$/) end++
      for (i = 1; i <= NR; i++) if (i < start || i >= end) print lines[i]
    }' "$COMPOSE" >"$COMPOSE.tmp" && mv "$COMPOSE.tmp" "$COMPOSE"
  echo "  demo/docker-compose.yml"
fi

# --- Fatto --------------------------------------------------------------------

echo ""
if [ -n "$CALLERS" ]; then
  echo "  Attenzione: questi file nominano ancora il modulo tolto."
  echo "  Se lo chiamavano via Feign, ora non compilano: sistemali."
  printf '    %s\n' $CALLERS
  echo ""
fi
echo "Modulo rimosso."
echo ""
echo "  task check        verifica che sia rimasto tutto coerente"
echo "  task dev          riavvia lo stack senza quel modulo"
echo ""
