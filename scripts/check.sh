#!/usr/bin/env bash
# Controlla che le parti del progetto che devono restare d'accordo lo siano.
# Equivalente POSIX di scripts/check.ps1: non avvia niente, non modifica niente.
#
#   task check
set -uo pipefail

PROJECT_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    -ProjectOnly|--project-only) PROJECT_ONLY=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

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

# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

# --- Porte dichiarate dai moduli ---------------------------------------------

# Un modulo e' "avviabile" se ha un file di configurazione: common-dto non lo e'.
PORT_LINES=""   # "<modulo> <porta>"
for m in $ON_DISK; do
  cfg="$(module_config_file "$DEMO_DIR/$m" 2>/dev/null || true)"
  [ -n "$cfg" ] || continue
  port="$(module_port "$DEMO_DIR/$m")"
  if [ "$port" = "0" ]; then
    add_error "demo/${cfg#$DEMO_DIR/} non ha una porta configurata valida (es. 'port: \${SERVER_PORT:N}')"
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
      add_error "dev.ps1 avvia $module, che non ha un file di configurazione (application.yml/yaml/properties)"
    elif [ "$declared_port" != "$port" ]; then
      add_error "$module: dev.ps1 dice porta $port, configurazione modulo dice $declared_port (task set-port SERVICE=$module PORT=<porta>)"
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

# --- Porte riservate da Windows ----------------------------------------------

# Riguarda solo Windows: qui non esiste il concetto, e non c'e' niente da dire.
if [ "$PROJECT_ONLY" -eq 0 ] && command -v netsh >/dev/null 2>&1; then
  RESERVED="$(netsh interface ipv4 show excludedportrange protocol=tcp 2>/dev/null | grep -E '^ *[0-9]+ +[0-9]+')"
  while read -r _name module port; do
    [ -z "$module" ] && continue
    printf '%s
' "$RESERVED" | while read -r start end; do
      [ -z "$start" ] && continue
      if [ "$port" -ge "$start" ] && [ "$port" -le "$end" ]; then
        echo "$module: la porta $port e' in un intervallo riservato da Windows ($start-$end)"
      fi
    done
  done <<<"$DEV_PS" | while read -r line; do add_error "$line"; done
  report "porte riservate" "OK (nessuna)"
fi

# --- Il compose e' anche YAML valido? ----------------------------------------

# `docker compose config` non ha bisogno del daemon acceso: legge e valida il
# file. Se Docker non c'e', non e' un errore: qui non lo si sta usando.
if command -v docker >/dev/null 2>&1; then
  out="$(cd "$DEMO_DIR" && docker compose config --quiet 2>&1)" ||
    add_error "docker-compose.yml non e' valido: $out"
  report "compose valido"
else
  printf '  %-26s%s
' "compose valido" "saltato (docker non installato)"
fi

# --- La configurazione degli editor -------------------------------------------
# Una configurazione di debug che elenca servizi spariti manda in errore il
# tasto Debug, e una che non li elenca non lo fa partire affatto. Vale per VS
# Code (launch.json) e per Zed (debug.json): li scrive entrambi ide-sync.

EDITOR_FILES=""
for f in .vscode/launch.json .zed/debug.json; do
  [ -f "$REPO_ROOT/$f" ] && EDITOR_FILES="$EDITOR_FILES $f"
done
if [ -n "$EDITOR_FILES" ]; then
  for f in $EDITOR_FILES; do
    LAUNCHED="$(grep -oE '"projectName"[[:space:]]*:[[:space:]]*"[^"]+"' "$REPO_ROOT/$f" | sed -E 's/.*"([^"]+)"$/\1/')"
    while read -r _name module _port; do
      [ -z "$module" ] && continue
      printf '%s\n' "$LAUNCHED" | grep -qx "$module" || add_error "$module: manca in $f"
    done <<<"$DEV_PS"
    for name in $LAUNCHED; do
      [ -f "$DEMO_DIR/$name/pom.xml" ] || add_error "$name: e' in $f ma il modulo non esiste"
    done
  done
  [ -n "$ERRORS" ] && add_error "riallinea con: task ide-sync"
  report "editor (debug)"
else
  printf '  %-26s%s\n' "editor (debug)" "assente: task ide-sync"
fi

# --- Java: il JDK della macchina basta al progetto? --------------------------
# Riguarda la macchina, non i file: le prove automatiche lo saltano. Un JDK
# piu' nuovo del progetto va bene (compila per la versione vecchia), uno piu'
# vecchio no: "release version 25 not supported".

if [ "$PROJECT_ONLY" -eq 1 ]; then
  printf '  %-26s%s\n' "java" "saltato (--project-only)"
else
  . "$SCRIPT_DIR/scaffold-lib.sh"
  WANTED="$(project_java_version "$DEMO_DIR")"
  JDK="$(machine_jdk || true)"
  JDK_VERSION="${JDK%%|*}"
  if [ -z "$JDK" ]; then
    add_error "non trovo un JDK (JAVA_HOME o PATH): Maven non puo' compilare. Installa Java $WANTED, poi task set-java"
  elif [ -n "$WANTED" ] && [ "$JDK_VERSION" -lt "$WANTED" ]; then
    add_error "il progetto chiede Java $WANTED e il JDK di questa macchina e' Java $JDK_VERSION: task set-java (o installa Java $WANTED)"
  fi
  report "java" "OK (progetto Java $WANTED, JDK ${JDK_VERSION:-?})"
fi

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
