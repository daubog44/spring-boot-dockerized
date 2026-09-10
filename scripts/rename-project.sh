#!/usr/bin/env bash
# Rinomina la cartella dell'aggregatore Maven (quella chiamata demo) e con
# essa ogni file che la nomina.
# Equivalente POSIX di scripts/rename-project.ps1.
#
#   task rename-project NAME=wms
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Name|--name) NAME="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# --- Come si chiama adesso ----------------------------------------------------
# Non lo diamo per scontato: e' la cartella con il pom aggregatore e il
# docker-compose. Cosi' il comando funziona anche la seconda volta.

# La cartella dell'aggregatore Maven (quella che di solito si chiama demo).
# La verita' sta nel Taskfile, che la nomina in "dir:": cercarla a naso fra le
# cartelle con un pom.xml sbaglierebbe bersaglio, per esempio con consegna/.
aggregator_name() {
  local name dir
  if [ -f "$REPO_ROOT/Taskfile.yml" ]; then
    name="$(grep -oE "^[[:space:]]*dir:[[:space:]]*'?[A-Za-z0-9_.-]+'?[[:space:]]*$"  "$REPO_ROOT/Taskfile.yml" | head -n 1 | sed -E "s/^[[:space:]]*dir:[[:space:]]*'?//; s/'?[[:space:]]*$//")"
    if [ -n "$name" ] && [ -f "$REPO_ROOT/$name/pom.xml" ]; then
      echo "$name"
      return 0
    fi
  fi
  for dir in "$REPO_ROOT"/*/; do
    [ "$(basename "${dir%/}")" = "consegna" ] && continue
    if [ -f "$dir/pom.xml" ] && [ -f "$dir/docker-compose.yml" ]; then
      basename "${dir%/}"
      return 0
    fi
  done
  echo "Non trovo la cartella dell'aggregatore sotto $REPO_ROOT." >&2
  return 1
}

CURRENT="$(aggregator_name)" || exit 1

if [ -z "$NAME" ]; then
  echo ""
  echo "La cartella dell'aggregatore si chiama '$CURRENT'."
  echo ""
  echo "  task rename-project NAME=<nome-nuovo>"
  echo ""
  exit 0
fi
case "$NAME" in
  [a-z]*) : ;;
  *) echo "Nome non valido: '$NAME'. Minuscole, numeri e trattini, e deve iniziare per lettera." >&2; exit 1 ;;
esac
case "$NAME" in
  *[!a-z0-9-]*) echo "Nome non valido: '$NAME'. Minuscole, numeri e trattini." >&2; exit 1 ;;
esac
if [ "$NAME" = "$CURRENT" ]; then
  echo ""
  echo "La cartella si chiama gia' '$NAME': non c'e' niente da fare."
  echo ""
  exit 0
fi
if [ -e "$REPO_ROOT/$NAME" ]; then
  echo "Esiste gia' una cartella '$NAME' nel progetto." >&2
  exit 1
fi

echo ""
echo "==> $CURRENT -> $NAME"
echo ""

# --- 1. La cartella -----------------------------------------------------------

MOVED=0
if [ -d "$REPO_ROOT/.git" ]; then
  ( cd "$REPO_ROOT" && git mv "$CURRENT" "$NAME" >/dev/null 2>&1 ) && MOVED=1
fi
[ "$MOVED" -eq 1 ] || mv "$REPO_ROOT/$CURRENT" "$REPO_ROOT/$NAME"
echo "  $CURRENT/ -> $NAME/"

# --- 2. Ogni file che la nomina ----------------------------------------------
# Sostituiamo il nome solo quando e' un pezzo di percorso: cioe' quando ha
# accanto una barra, un apice, una virgoletta o un backtick -- ma non quando e'
# il nome di una variabile ($demo). Cosi' la parola demo in italiano resta
# dov'e'.

FILES="$(ls "$REPO_ROOT"/*.md "$REPO_ROOT"/Taskfile.yml "$REPO_ROOT"/scripts/*.ps1 "$REPO_ROOT"/scripts/*.sh 2>/dev/null || true)"

# Solo i file che lo nominano davvero: sed riscrive il file per intero, e
# riscrivere quaranta file per niente cambierebbe loro le fini riga.
MATCH="([/\\\\'\"\`])$CURRENT|(^|[^\$A-Za-z0-9_{])$CURRENT([/\\\\'\"\`])|^[[:space:]]*dir:[[:space:]]*$CURRENT[[:space:]]*\$|(^|[[:space:]])cd $CURRENT([[:space:]]|\$)"

TOUCHED=0
for file in $FILES; do
  grep -qE "$MATCH" "$file" || continue
  sed -i -E \
    -e "s@([/\\\\'\"\`])$CURRENT@\1$NAME@g" \
    -e "s@(^|[^\$A-Za-z0-9_{])$CURRENT([/\\\\'\"\`])@\1$NAME\2@g" \
    -e "s@^([[:space:]]*dir:[[:space:]]*)$CURRENT[[:space:]]*\$@\1$NAME@" \
    -e "s@(^|[[:space:]])cd $CURRENT([[:space:]]|\$)@\1cd $NAME\2@g" \
    "$file"
  echo "  ${file#$REPO_ROOT/}"
  TOUCHED=$(( TOUCHED + 1 ))
done

echo ""
echo "Rinominata: $TOUCHED file aggiornati."
echo ""

# --- 3. La prova del nove -----------------------------------------------------

bash "$SCRIPT_DIR/check.sh" --project-only || {
  echo ""
  echo "task check ha trovato qualcosa: guarda sopra."
  exit 1
}

echo ""
echo "  I comandi non cambiano: task dev, task build, task docker-up."
echo "  Cambia solo il percorso dei sorgenti: $NAME/<modulo>/src/..."
echo ""
