#!/usr/bin/env bash
# Sposta un modulo su un'altra porta, in tutti i posti in cui quella porta e'
# scritta. Equivalente POSIX di scripts/set-port.ps1.
#
# Una porta vive in quattro file: l'application.yml del modulo, il
# docker-compose.yml (variabile d'ambiente e pubblicazione) e la lista dei
# servizi di dev.ps1 e dev.sh. Il codice Java non contiene porte: i servizi si
# chiamano per nome via Eureka e Feign.
#
#   task set-port -- --module wms-ui --port 9080
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
COMPOSE="$DEMO_DIR/docker-compose.yml"
DEV_PS1="$SCRIPT_DIR/dev.ps1"
DEV_SH="$SCRIPT_DIR/dev.sh"

MODULE=""
PORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    -Port|--port) PORT="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MODULE" ] || [ -z "$PORT" ]; then
  echo "Uso: task set-port -- --module <modulo> --port <porta>" >&2
  exit 1
fi

YML="$DEMO_DIR/$MODULE/src/main/resources/application.yml"
if [ ! -f "$YML" ]; then
  echo "Non trovo $YML: il modulo '$MODULE' esiste?" >&2
  exit 1
fi

OLD_PORT="$(grep -oE 'SERVER_PORT:[0-9]+' "$YML" | head -n 1 | cut -d: -f2 || true)"
if [ -z "$OLD_PORT" ]; then
  echo "In $YML non c'e' un 'port: \${SERVER_PORT:N}': cambiala a mano." >&2
  exit 1
fi
if [ "$OLD_PORT" = "$PORT" ]; then
  echo "$MODULE e' gia' sulla porta $PORT: niente da fare."
  exit 0
fi

# La porta non deve gia' appartenere a un altro modulo: due servizi sulla stessa
# porta significa che il secondo muore all'avvio.
for dir in "$DEMO_DIR"/*/; do
  name="$(basename "$dir")"
  [ "$name" = "$MODULE" ] && continue
  other="$dir/src/main/resources/application.yml"
  [ -f "$other" ] || continue
  if grep -qE "SERVER_PORT:$PORT([^0-9]|\$)" "$other"; then
    echo "La porta $PORT e' gia' di $name. Spostati su un'altra." >&2
    exit 1
  fi
done

IS_EUREKA=0
[ "$OLD_PORT" = "8761" ] && IS_EUREKA=1

echo ""
echo "==> $MODULE : $OLD_PORT -> $PORT"
echo ""

# --- 1. application.yml del modulo -------------------------------------------

sed -i.bak "s/SERVER_PORT:$OLD_PORT/SERVER_PORT:$PORT/g" "$YML" && rm -f "$YML.bak"
echo "  demo/$MODULE/src/main/resources/application.yml"

# --- 2. docker-compose.yml ----------------------------------------------------

# Il nome del servizio nel compose non coincide sempre con quello del modulo
# (naming-server sta sotto eureka-server): il blocco si trova dal MODULE:.
MODULE_LINE="$(grep -nE "^[[:space:]]+MODULE:[[:space:]]+$MODULE[[:space:]]*\$" "$COMPOSE" | head -n 1 | cut -d: -f1 || true)"
if [ -z "$MODULE_LINE" ]; then
  echo "  docker-compose.yml: nessun servizio con MODULE: $MODULE, salto."
else
  awk -v ml="$MODULE_LINE" -v old="$OLD_PORT" -v new="$PORT" -v iseureka="$IS_EUREKA" '
    { lines[NR] = $0 }
    END {
      start = ml
      while (start > 1 && lines[start] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) start--
      end = ml + 1
      while (end <= NR && lines[end] !~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && lines[end] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) end++
      for (i = 1; i <= NR; i++) {
        line = lines[i]
        if (i >= start && i < end) {
          sub("SERVER_PORT: *" old "[[:space:]]*$", "SERVER_PORT: " new, line)
          sub("\"" old ":" old "\"", "\"" new ":" new "\"", line)
          if (iseureka == "1") gsub("localhost:" old, "localhost:" new, line)
        }
        print line
      }
    }
  ' "$COMPOSE" >"$COMPOSE.tmp" && mv "$COMPOSE.tmp" "$COMPOSE"
  echo "  demo/docker-compose.yml"
fi

# --- 3. Lista dei servizi di task dev ----------------------------------------

DEV_LINE="$(grep -nE "Module = '$MODULE'" "$DEV_PS1" | head -n 1 | cut -d: -f1 || true)"
if [ -z "$DEV_LINE" ]; then
  echo "  scripts/dev.ps1: $MODULE non e' nella lista dei servizi, salto."
elif sed -n "${DEV_LINE}p" "$DEV_PS1" | grep -q 'Port = \$UiPort'; then
  # La UI usa -UiPort, comodo per uno spostamento al volo: qui cambiamo il
  # valore predefinito, cosi' `task dev` senza argomenti usa quello nuovo.
  sed -i.bak -E "s/(\[int\]\\\$UiPort = )[0-9]+/\1$PORT/" "$DEV_PS1" && rm -f "$DEV_PS1.bak"
  sed -i.bak -E "s/^(UI_PORT=)[0-9]+/\1$PORT/" "$DEV_SH" && rm -f "$DEV_SH.bak"
  echo "  scripts/dev.ps1 e dev.sh (valore predefinito di -UiPort)"
else
  sed -i.bak "${DEV_LINE}s/Port = [0-9]\+/Port = $PORT/" "$DEV_PS1" && rm -f "$DEV_PS1.bak"
  echo "  scripts/dev.ps1"
  sed -i.bak -E "s/\"([A-Za-z0-9_-]+):$MODULE:[^\"]+\"/\"\1:$MODULE:$PORT\"/" "$DEV_SH" && rm -f "$DEV_SH.bak"
  echo "  scripts/dev.sh"
fi

# --- 4. Se abbiamo spostato Eureka, tutti devono saperlo ----------------------

if [ "$IS_EUREKA" = "1" ]; then
  echo ""
  echo "  Eureka si e' spostato: aggiorno chi lo cerca."
  for dir in "$DEMO_DIR"/*/; do
    yml="$dir/src/main/resources/application.yml"
    [ -f "$yml" ] || continue
    if grep -q "localhost:$OLD_PORT" "$yml"; then
      sed -i.bak "s/localhost:$OLD_PORT/localhost:$PORT/g" "$yml" && rm -f "$yml.bak"
      echo "  demo/$(basename "$dir")/src/main/resources/application.yml"
    fi
  done
  if grep -q "eureka-server:$OLD_PORT" "$COMPOSE"; then
    sed -i.bak "s/eureka-server:$OLD_PORT/eureka-server:$PORT/g" "$COMPOSE" && rm -f "$COMPOSE.bak"
    echo "  demo/docker-compose.yml (EUREKA_SERVER_URL dei container)"
  fi
  for script in status.ps1 status.sh dev-lib.ps1 dev-lib.sh; do
    path="$SCRIPT_DIR/$script"
    if grep -qE "\b$OLD_PORT\b" "$path"; then
      sed -i.bak -E "s/\b$OLD_PORT\b/$PORT/g" "$path" && rm -f "$path.bak"
      echo "  scripts/$script"
    fi
  done
fi

# --- 5. Cosa resta da guardare a mano ----------------------------------------

# Collaudo e documentazione hanno indirizzi scritti per esteso: non li tocchiamo
# a colpi di regex, ma e' giusto sapere dove sono.
echo ""
echo "Porta cambiata."
LEFT="$(grep -rnE "\b$OLD_PORT\b" "$REPO_ROOT" \
  --include='*.ps1' --include='*.sh' --include='*.md' --include='*.yml' --include='*.yaml' \
  --exclude-dir=.git --exclude-dir=.dev-logs --exclude-dir=target --exclude-dir=node_modules --exclude-dir=.task \
  --exclude=docker-compose.yml --exclude=dev.ps1 --exclude=dev.sh --exclude=status.ps1 --exclude=status.sh --exclude=dev-lib.ps1 --exclude=dev-lib.sh \
  2>/dev/null | cut -d: -f1,2 | sed "s|^$REPO_ROOT/||" || true)"
if [ -n "$LEFT" ]; then
  echo ""
  echo "  La porta $OLD_PORT compare ancora qui (collaudo, documentazione): guardaci tu."
  printf '    %s\n' $LEFT
fi
echo ""
echo "  task dev          riavvia lo stack sulle porte nuove"
echo ""
