#!/usr/bin/env bash
# Collega un modulo al PostgreSQL del progetto, al posto dell'H2 in memoria.
# Equivalente POSIX di scripts/use-postgres.ps1.
#
#   task use-postgres SERVICE=ordini-service
#   task use-postgres SERVICE=ordini-service DBNAME=ordini
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
COMPOSE="$DEMO_DIR/docker-compose.yml"

MODULE=""
DB_NAME=""
REMOVE_H2=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    -DbName|--db-name) DB_NAME="$2"; shift 2 ;;
    -RemoveH2|--remove-h2) REMOVE_H2=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MODULE" ]; then
  if [ ! -t 0 ]; then
    echo "Uso: task use-postgres SERVICE=<modulo> [DBNAME=<database>] [REMOVE_H2=1]" >&2
    exit 1
  fi

  ALL_MODULES=()
  for d in "$DEMO_DIR"/*; do
    if [ -f "$d/pom.xml" ]; then
      ALL_MODULES+=("$(basename "$d")")
    fi
  done
  if [ "${#ALL_MODULES[@]}" -eq 0 ]; then
    echo "Nessun modulo trovato in demo/." >&2
    exit 1
  fi

  echo ""
  echo "COLLEGAMENTO A POSTGRESQL GUIDATO"
  echo "Seleziona il microservizio da collegare a PostgreSQL:"
  for i in "${!ALL_MODULES[@]}"; do
    echo "  $((i+1))) ${ALL_MODULES[$i]}"
  done
  printf "  [1] > "
  read -r IDX
  [ -n "$IDX" ] || IDX=1
  MODULE="${ALL_MODULES[$((IDX-1))]}"

  if [ -z "$DB_NAME" ]; then
    DEFAULT_SUGG="$(printf '%s' "$MODULE" | sed -E 's/-service$//' | sed -E 's/-ui$//')"
    printf "  Nome database dedicato [%s]: " "$DEFAULT_SUGG"
    read -r DB_IN
    if [ -n "$DB_IN" ]; then
      DB_NAME="$DB_IN"
    else
      DB_NAME="$DEFAULT_SUGG"
    fi
  fi

  if [ "$REMOVE_H2" -eq 0 ]; then
    printf "  Rimuovere la dipendenza H2 in memoria? [s/N]: "
    read -r H2_ANS
    H2_ANS="$(printf '%s' "$H2_ANS" | tr '[:upper:]' '[:lower:]')"
    if [ "$H2_ANS" = "s" ] || [ "$H2_ANS" = "si" ] || [ "$H2_ANS" = "y" ]; then
      REMOVE_H2=1
    fi
  fi
fi
if [ ! -f "$DEMO_DIR/$MODULE/pom.xml" ]; then
  available=""
  for dir in "$DEMO_DIR"/*/; do
    [ -f "$dir/pom.xml" ] && available="$available $(basename "$dir")"
  done
  echo "Modulo '$MODULE' non trovato. Moduli disponibili:$available" >&2
  exit 1
fi
YML="$DEMO_DIR/$MODULE/src/main/resources/application.yml"
[ -f "$YML" ] || { echo "Non trovo $YML." >&2; exit 1; }

# --- Le credenziali le detta il container, non le inventiamo noi -------------

DEFAULT_DB="$(grep -oE '^[[:space:]]+POSTGRES_DB:[[:space:]]*\S+' "$COMPOSE" | head -n 1 | awk '{print $2}' || true)"
DB_USER="$(grep -oE '^[[:space:]]+POSTGRES_USER:[[:space:]]*\S+' "$COMPOSE" | head -n 1 | awk '{print $2}' || true)"
DB_PASSWORD="$(grep -oE '^[[:space:]]+POSTGRES_PASSWORD:[[:space:]]*\S+' "$COMPOSE" | head -n 1 | awk '{print $2}' || true)"
if [ -z "$DEFAULT_DB" ]; then
  echo "In docker-compose.yml non c'e' un servizio postgres: aggiungilo prima di collegarci un modulo." >&2
  exit 1
fi
[ -n "$DB_NAME" ] || DB_NAME="$DEFAULT_DB"

# Il prefisso delle variabili d'ambiente: se il modulo ne ha gia' uno lo
# teniamo, altrimenti lo deriviamo dal nome come fa new-service.
PREFIX="$(grep -oE '\$\{[A-Z0-9_]+_DB_URL:' "$YML" | head -n 1 | sed -E 's/\$\{(.*)_DB_URL:/\1/' || true)"
if [ -z "$PREFIX" ]; then
  PREFIX="$(printf '%s' "${MODULE%-service}" | tr 'a-z-' 'A-Z_')"
fi

echo ""
echo "==> $MODULE -> PostgreSQL (database '$DB_NAME')"
echo ""

# --- 1. Le dipendenze ---------------------------------------------------------

POM="$DEMO_DIR/$MODULE/pom.xml"
MISSING=""
grep -q '<artifactId>spring-boot-starter-data-jpa</artifactId>' "$POM" || MISSING="data-jpa"
if ! grep -q '<artifactId>postgresql</artifactId>' "$POM"; then
  [ -n "$MISSING" ] && MISSING="$MISSING,postgresql" || MISSING="postgresql"
fi
if [ -n "$MISSING" ]; then
  # Riusiamo add-dep invece di reinventare l'inserimento nel pom.
  bash "$SCRIPT_DIR/add-dep.sh" --module "$MODULE" --deps "$MISSING" >/dev/null
  echo "  pom.xml: aggiunte ${MISSING//,/, }"
else
  echo "  pom.xml: data-jpa e driver PostgreSQL gia' presenti"
fi

if [ "$REMOVE_H2" -eq 1 ]; then
  python3 -c '
import sys, re
with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()
text = re.sub(r"(?s)\s*<dependency>\s*<groupId>com\.h2database</groupId>\s*<artifactId>h2</artifactId>.*?</dependency>", "", text)
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(text)
' "$POM" 2>/dev/null || true
  echo "  pom.xml: rimossa dipendenza h2"
fi

# --- 2. application.yml -------------------------------------------------------

# Da fuori Docker si passa dalla porta pubblicata, che decide db-config (o il
# wizard): se la 5432 del PC era occupata, non e' piu' la 5432.
HOST_PORT="$(grep -oE '^[[:space:]]+-[[:space:]]*"[0-9]+:5432"' "$COMPOSE" | head -n 1 | grep -oE '[0-9]+:5432' | cut -d: -f1)"
[ -n "$HOST_PORT" ] || HOST_PORT=5432
LOCAL_URL="jdbc:postgresql://localhost:$HOST_PORT/$DB_NAME"
if grep -qE '^[[:space:]]+datasource:' "$YML"; then
  sed -i.bak -E "s#^([[:space:]]+url:[[:space:]]*\\\$\{${PREFIX}_DB_URL:)[^}]*(\})#\1${LOCAL_URL}\2#" "$YML"
  sed -i.bak -E "s#^([[:space:]]+username:[[:space:]]*\\\$\{${PREFIX}_DB_USERNAME:)[^}]*(\})#\1${DB_USER}\2#" "$YML"
  sed -i.bak -E "s#^([[:space:]]+password:[[:space:]]*\\\$\{${PREFIX}_DB_PASSWORD:)[^}]*(\})#\1${DB_PASSWORD}\2#" "$YML"
  sed -i.bak -E "s#^([[:space:]]+driver-class-name:[[:space:]]*\\\$\{${PREFIX}_DB_DRIVER:)[^}]*(\})#\1org.postgresql.Driver\2#" "$YML"
  rm -f "$YML.bak"
  echo "  demo/$MODULE/src/main/resources/application.yml"
else
  # Nessun datasource (modulo creato con NODB=1, o una UI): lo aggiungiamo
  # sotto spring:, dove Spring Boot se lo aspetta.
  N="$(grep -nE '^[[:space:]]+application:' "$YML" | head -n 1 | cut -d: -f1)"
  [ -n "$N" ] || { echo "In $YML non trovo il blocco 'spring:': aggiungi il datasource a mano." >&2; exit 1; }
  END=$((N + 1))
  TOTAL="$(grep -c '' "$YML")"
  while [ "$END" -le "$TOTAL" ] && sed -n "${END}p" "$YML" | grep -qE '^[[:space:]]{4,}\S'; do
    END=$((END + 1))
  done
  BLOCK="
  datasource:
    url: \${${PREFIX}_DB_URL:${LOCAL_URL}}
    username: \${${PREFIX}_DB_USERNAME:${DB_USER}}
    password: \${${PREFIX}_DB_PASSWORD:${DB_PASSWORD}}
    driver-class-name: \${${PREFIX}_DB_DRIVER:org.postgresql.Driver}

  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true"
  awk -v n="$((END - 1))" -v text="$BLOCK" '{ print } NR == n { print text }' "$YML" >"$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "  demo/$MODULE/src/main/resources/application.yml (datasource aggiunto)"
fi

# --- 3. docker-compose: variabili e dipendenza dal database ------------------

ML="$(grep -nE "^[[:space:]]+MODULE:[[:space:]]+$MODULE[[:space:]]*\$" "$COMPOSE" | head -n 1 | cut -d: -f1 || true)"
if [ -z "$ML" ]; then
  echo "  docker-compose.yml: nessun servizio con MODULE: $MODULE, salto."
else
  awk -v ml="$ML" -v prefix="$PREFIX" -v db="$DB_NAME" -v user="$DB_USER" -v pass="$DB_PASSWORD" '
    { lines[NR] = $0 }
    END {
      start = ml
      while (start > 1 && lines[start] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) start--
      end = ml + 1
      while (end <= NR && lines[end] !~ /^[A-Za-z0-9_-]+:[[:space:]]*$/ && lines[end] !~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) end++

      envLines = "      " prefix "_DB_URL: jdbc:postgresql://postgres:5432/" db "\n" \
                 "      " prefix "_DB_USERNAME: " user "\n" \
                 "      " prefix "_DB_PASSWORD: " pass "\n" \
                 "      " prefix "_DB_DRIVER: org.postgresql.Driver"

      # Il blocco ha di suo postgres fra le dipendenze?
      hasPostgres = 0
      for (i = start; i < end; i++) if (lines[i] ~ /^      postgres:[[:space:]]*$/) hasPostgres = 1

      for (i = 1; i <= NR; i++) {
        if (i < start || i >= end) { print lines[i]; continue }
        line = lines[i]
        if (line ~ ("^[[:space:]]+" prefix "_DB_(URL|USERNAME|PASSWORD|DRIVER):")) continue
        print line
        if (line ~ /^    environment:[[:space:]]*$/) { print envLines; seenEnv = 1 }
        if (line ~ /^    depends_on:[[:space:]]*$/) {
          seenDepends = 1
          if (!hasPostgres) { print "      postgres:"; print "        condition: service_healthy" }
        }
        if (i == end - 1) {
          if (!seenEnv) { print "    environment:"; print envLines }
          if (!seenDepends) { print "    depends_on:"; print "      postgres:"; print "        condition: service_healthy" }
        }
      }
    }' "$COMPOSE" >"$COMPOSE.tmp" && mv "$COMPOSE.tmp" "$COMPOSE"
  echo "  demo/docker-compose.yml"
fi

# --- 4. Un database dedicato, se richiesto ------------------------------------

NEEDS_RESET=0
if [ "$DB_NAME" != "$DEFAULT_DB" ]; then
  INIT_FILE="$DEMO_DIR/postgres-init/create-$DB_NAME.sql"
  if [ ! -f "$INIT_FILE" ]; then
    mkdir -p "$DEMO_DIR/postgres-init"
    cat >"$INIT_FILE" <<EOF
-- Creato da task use-postgres: un database per il modulo $MODULE.
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
    echo "  demo/postgres-init/create-$DB_NAME.sql"
    NEEDS_RESET=1
  fi
  if ! grep -q 'postgres-init:/docker-entrypoint-initdb.d' "$COMPOSE"; then
    N="$(grep -nE '^[[:space:]]+- postgres-data:' "$COMPOSE" | head -n 1 | cut -d: -f1)"
    if [ -n "$N" ]; then
      awk -v n="$((N - 1))" '{ print } NR == n { print "      - ./postgres-init:/docker-entrypoint-initdb.d" }' "$COMPOSE" >"$COMPOSE.tmp" && mv "$COMPOSE.tmp" "$COMPOSE"
      echo "  demo/docker-compose.yml (monta gli script di init)"
    fi
  fi
fi

# --- 5. task dev deve avviare il database ------------------------------------

if grep -qE '^\$usesPostgres = \$false' "$SCRIPT_DIR/dev.ps1"; then
  sed -i.bak -E 's/^\$usesPostgres = \$false/$usesPostgres = $true/' "$SCRIPT_DIR/dev.ps1" && rm -f "$SCRIPT_DIR/dev.ps1.bak"
  echo "  scripts/dev.ps1 (task dev avvia PostgreSQL)"
fi
if grep -qE '^USES_POSTGRES=0' "$SCRIPT_DIR/dev.sh"; then
  sed -i.bak -E 's/^USES_POSTGRES=0/USES_POSTGRES=1/' "$SCRIPT_DIR/dev.sh" && rm -f "$SCRIPT_DIR/dev.sh.bak"
  echo "  scripts/dev.sh (task dev avvia PostgreSQL)"
fi

# --- Fatto --------------------------------------------------------------------

echo ""
echo "Modulo collegato a PostgreSQL."
echo ""
if [ "$NEEDS_RESET" -eq 1 ]; then
  echo "  Il database '$DB_NAME' nasce da uno script di init, e PostgreSQL li esegue"
  echo "  solo quando il volume e' vuoto. Una volta sola:"
  echo "    task docker-reset      # ATTENZIONE: cancella i dati gia' presenti"
  echo ""
fi
echo "  task dev          riavvia lo stack: avvia anche PostgreSQL"
echo "  task check        verifica che sia rimasto tutto coerente"
echo ""
echo "  Le tabelle le crea Hibernate con ddl-auto: update. I dati di prova ora"
echo "  restano fra un riavvio e l'altro: se ti servono puliti, task docker-reset."
echo ""
