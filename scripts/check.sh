#!/usr/bin/env bash
# Controlla che le parti del progetto che devono restare d'accordo lo siano.
# Equivalente POSIX di scripts/check.ps1: non avvia niente, non modifica niente.
#
#   task check
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

PROBLEMS=0
ERRORS=""

add_error() { ERRORS="$ERRORS$1"$'\n'; }

report() { # etichetta, nota-se-tutto-ok
  local label="$1" ok_note="${2:-OK}" count=0
  if [ -n "$ERRORS" ]; then
    count="$(printf '%s' "$ERRORS" | grep -c '')"
    printf '  %-26s%s problema/i\n' "$label" "$count"
    printf '%s' "$ERRORS" | sed 's/^/      /'
    PROBLEMS=$((PROBLEMS + count))
  else
    printf '  %-26s%s\n' "$label" "$ok_note"
  fi
  ERRORS=""
}

echo ""
echo "CONTROLLO DEL PROGETTO"
echo ""

# --- Moduli -------------------------------------------------------------------

DECLARED="$(grep -oE '<module>[^<]+</module>' "$DEMO_DIR/pom.xml" | sed 's/<[^>]*>//g')"
ON_DISK=""
for dir in "$DEMO_DIR"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/pom.xml" ] && ON_DISK="$ON_DISK$name"$'\n'
done

for m in $DECLARED; do
  [ -f "$DEMO_DIR/$m/pom.xml" ] || add_error "demo/pom.xml dichiara <module>$m</module> ma demo/$m/pom.xml non esiste"
done
for m in $ON_DISK; do
  printf '%s\n' "$DECLARED" | grep -qx "$m" || add_error "demo/$m ha un pom.xml ma non e' fra i <modules>: Maven non lo compila"
done
report "moduli" "OK ($(printf '%s\n' "$DECLARED" | grep -c '.'))"

# --- Porte dichiarate dai moduli ---------------------------------------------

# Un modulo e' "avviabile" se ha un application.yml: common-dto non lo e'.
PORT_LINES=""   # "<modulo> <porta>"
for m in $ON_DISK; do
  yml="$DEMO_DIR/$m/src/main/resources/application.yml"
  [ -f "$yml" ] || continue
  port="$(grep -oE 'SERVER_PORT:[0-9]+' "$yml" | head -n 1 | cut -d: -f2)"
  if [ -z "$port" ]; then
    add_error "demo/$m/src/main/resources/application.yml non ha 'port: \${SERVER_PORT:N}'"
    continue
  fi
  PORT_LINES="$PORT_LINES$m $port"$'\n'
done

for port in $(printf '%s' "$PORT_LINES" | awk '{print $2}' | sort | uniq -d); do
  add_error "porta $port usata da: $(printf '%s' "$PORT_LINES" | awk -v p="$port" '$2 == p {printf "%s ", $1}')"
done
report "porte dei moduli" "OK ($(printf '%s' "$PORT_LINES" | grep -c '.') servizi, nessun doppione)"

port_of() { printf '%s' "$PORT_LINES" | awk -v m="$1" '$1 == m {print $2}'; }

# --- Dockerfile ---------------------------------------------------------------

# Il sorgente puo' entrare tutto insieme (COPY . .) oppure modulo per modulo:
# nel secondo caso ogni modulo deve avere la sua riga.
COPIES_ALL=0
grep -qE '^COPY \. \.[[:space:]]*$' "$DEMO_DIR/Dockerfile" && COPIES_ALL=1
for m in $DECLARED; do
  grep -q "COPY $m/pom.xml" "$DEMO_DIR/Dockerfile" || add_error "demo/Dockerfile non copia $m/pom.xml: la build in Docker fallira'"
  if [ "$COPIES_ALL" -eq 0 ]; then
    grep -q "COPY $m $m" "$DEMO_DIR/Dockerfile" || add_error "demo/Dockerfile non copia i sorgenti di $m (manca 'COPY $m $m')"
  fi
done
report "Dockerfile"

# --- Lista dei servizi di dev.ps1 e dev.sh -----------------------------------

UI_PORT_PS="$(grep -oE '\[int\]\$UiPort = [0-9]+' "$SCRIPT_DIR/dev.ps1" | grep -oE '[0-9]+')"
UI_PORT_SH="$(grep -oE '^UI_PORT=[0-9]+' "$SCRIPT_DIR/dev.sh" | cut -d= -f2)"

# "<nome> <modulo> <porta>", nell'ordine di avvio.
DEV_PS="$(grep -oE "Name = '[^']+'; +Module = '[^']+'; +Port = (\\\$UiPort|[0-9]+)" "$SCRIPT_DIR/dev.ps1" |
  sed -E "s/Name = '([^']+)'; +Module = '([^']+)'; +Port = (.*)/\1 \2 \3/" |
  sed "s/\\\$UiPort/$UI_PORT_PS/")"
DEV_SH_LIST="$(sed -n '/^SERVICES=(/,/^)/p' "$SCRIPT_DIR/dev.sh" | grep -oE '"[^"]+"' | tr -d '"' |
  awk -F: '{print $1" "$2" "$3}' | sed "s/\\\$UI_PORT/$UI_PORT_SH/")"

if [ -z "$DEV_PS" ]; then
  add_error "non riesco a leggere la lista \$services in scripts/dev.ps1"
else
  while read -r name module port; do
    [ -z "$name" ] && continue
    if ! printf '%s\n' "$DECLARED" | grep -qx "$module"; then
      add_error "dev.ps1 avvia '$name' dal modulo $module, che non e' fra i <modules>"
      continue
    fi
    declared_port="$(port_of "$module")"
    if [ -z "$declared_port" ]; then
      add_error "dev.ps1 avvia $module, che non ha un application.yml"
    elif [ "$declared_port" != "$port" ]; then
      add_error "$module: dev.ps1 dice porta $port, application.yml dice $declared_port (task set-port SERVICE=$module PORT=<porta>)"
    fi
  done <<<"$DEV_PS"

  while read -r m _p; do
    [ -z "$m" ] && continue
    printf '%s\n' "$DEV_PS" | awk '{print $2}' | grep -qx "$m" ||
      add_error "$m e' avviabile ma non e' nella lista di task dev: non partira'"
  done <<<"$PORT_LINES"
fi
report "servizi di task dev" "OK ($(printf '%s\n' "$DEV_PS" | grep -c '.'))"

if [ "$DEV_PS" != "$DEV_SH_LIST" ]; then
  add_error "la lista dei servizi di dev.ps1 e quella di dev.sh non coincidono:"
  add_error "  dev.ps1: $(printf '%s' "$DEV_PS" | tr '\n' ';')"
  add_error "  dev.sh : $(printf '%s' "$DEV_SH_LIST" | tr '\n' ';')"
fi
report "dev.sh allineato"

# --- docker-compose -----------------------------------------------------------

COMPOSE="$DEMO_DIR/docker-compose.yml"
while read -r _name module port; do
  [ -z "$module" ] && continue
  ml="$(grep -nE "^[[:space:]]+MODULE:[[:space:]]+$module[[:space:]]*\$" "$COMPOSE" | head -n 1 | cut -d: -f1)"
  if [ -z "$ml" ]; then
    add_error "docker-compose.yml non ha un servizio con MODULE: $module"
    continue
  fi
  block="$(awk -v ml="$ml" '
    { lines[NR] = $0 }
    END {
      start = ml
      while (start > 1 && lines[start] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) start--
      end = ml + 1
      while (end <= NR && lines[end] !~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && lines[end] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) end++
      for (i = start; i < end; i++) print lines[i]
    }' "$COMPOSE")"
  printf '%s' "$block" | grep -qE "SERVER_PORT: *$port( |\$)" ||
    add_error "$module: in docker-compose.yml SERVER_PORT non e' $port"
  printf '%s' "$block" | grep -q "\"$port:$port\"" ||
    add_error "$module: in docker-compose.yml la porta pubblicata non e' $port:$port"
done <<<"$DEV_PS"
report "docker-compose"

# --- Esito --------------------------------------------------------------------

echo ""
if [ "$PROBLEMS" -eq 0 ]; then
  echo "Tutto coerente."
  echo ""
  exit 0
fi
echo "$PROBLEMS problema/i da sistemare."
echo ""
exit 1
