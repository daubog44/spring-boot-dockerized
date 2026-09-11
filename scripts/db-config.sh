#!/usr/bin/env bash
# Cambia nome, utente, password o porta del PostgreSQL del progetto, e
# aggiorna tutti i moduli collegati.
# Equivalente POSIX di scripts/db-config.ps1.
#
#   task db-config                                  # stampa com'e' configurato
#   task db-config DBNAME=magazzino USER=wms PASSWORD=wms123
#   task db-config PORT=5433
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
COMPOSE="$DEMO_DIR/docker-compose.yml"

DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_PORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -DbName|--db-name) DB_NAME="$2"; shift 2 ;;
    -User|--user) DB_USER="$2"; shift 2 ;;
    -Password|--password) DB_PASSWORD="$2"; shift 2 ;;
    -Port|--port) DB_PORT="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

[ -f "$COMPOSE" ] || { echo "Non trovo $COMPOSE." >&2; exit 1; }
grep -qE '^[[:space:]]+POSTGRES_DB:' "$COMPOSE" || {
  echo "In docker-compose.yml non c'e' un servizio postgres." >&2; exit 1; }

# --- Come sta adesso ----------------------------------------------------------

OLD_DB="$(grep -E '^[[:space:]]+POSTGRES_DB:' "$COMPOSE" | head -n 1 | awk '{print $2}')"
OLD_USER="$(grep -E '^[[:space:]]+POSTGRES_USER:' "$COMPOSE" | head -n 1 | awk '{print $2}')"
OLD_PASSWORD="$(grep -E '^[[:space:]]+POSTGRES_PASSWORD:' "$COMPOSE" | head -n 1 | awk '{print $2}')"
OLD_PORT="$(grep -oE '"[0-9]+:5432"' "$COMPOSE" | head -n 1 | tr -d '"' | cut -d: -f1)"
[ -n "$OLD_PORT" ] || OLD_PORT=5432

connected_modules() {
  for dir in "$DEMO_DIR"/*/; do
    yml="$dir/src/main/resources/application.yml"
    [ -f "$yml" ] || continue
    grep -q 'jdbc:postgresql' "$yml" && basename "${dir%/}"
  done
}

# Senza argomenti racconta com'e' configurato: e' il modo piu' veloce per
# ricordarsi la password durante la demo.
if [ -z "$DB_NAME" ] && [ -z "$DB_USER" ] && [ -z "$DB_PASSWORD" ] && [ -z "$DB_PORT" ]; then
  echo ""
  echo "==> Database del progetto"
  echo ""
  echo "  database   $OLD_DB"
  echo "  utente     $OLD_USER"
  echo "  password   $OLD_PASSWORD"
  echo "  porta      $OLD_PORT  (dentro Docker sempre 5432)"
  echo ""
  mods="$(connected_modules | tr '\n' ' ')"
  if [ -n "${mods// /}" ]; then
    echo "  moduli collegati: $mods"
  else
    echo "  Nessun modulo collegato: task use-postgres SERVICE=<modulo>"
  fi
  echo ""
  echo "  Per cambiare qualcosa:"
  echo "    task db-config DBNAME=magazzino USER=wms PASSWORD=wms123"
  echo "    task db-config PORT=5433"
  echo ""
  echo "  psql: docker compose exec postgres psql -U $OLD_USER -d $OLD_DB   (dalla cartella $(basename "$DEMO_DIR"))"
  echo ""
  exit 0
fi

NEW_DB="${DB_NAME:-$OLD_DB}"
NEW_USER="${DB_USER:-$OLD_USER}"
NEW_PASSWORD="${DB_PASSWORD:-$OLD_PASSWORD}"
NEW_PORT="${DB_PORT:-$OLD_PORT}"

for pair in "DBNAME:$NEW_DB" "USER:$NEW_USER" "PASSWORD:$NEW_PASSWORD"; do
  value="${pair#*:}"
  case "$value" in
    *[!A-Za-z0-9_]*|'')
      echo "Valore non valido per ${pair%%:*}: '$value'. Usa lettere, numeri e underscore." >&2
      exit 1 ;;
  esac
done
case "$NEW_PORT" in *[!0-9]*|'') echo "PORT deve essere un numero." >&2; exit 1 ;; esac

echo ""
echo "==> Configurazione del database"
echo ""
[ "$NEW_DB" != "$OLD_DB" ] && echo "  database   $OLD_DB -> $NEW_DB"
[ "$NEW_USER" != "$OLD_USER" ] && echo "  utente     $OLD_USER -> $NEW_USER"
[ "$NEW_PASSWORD" != "$OLD_PASSWORD" ] && echo "  password   $OLD_PASSWORD -> $NEW_PASSWORD"
[ "$NEW_PORT" != "$OLD_PORT" ] && echo "  porta      $OLD_PORT -> $NEW_PORT"
echo ""

# --- 1. Il container ----------------------------------------------------------

sed -i -E \
  -e "s|^([[:space:]]+POSTGRES_DB:[[:space:]]*).*$|\1$NEW_DB|" \
  -e "s|^([[:space:]]+POSTGRES_USER:[[:space:]]*).*$|\1$NEW_USER|" \
  -e "s|^([[:space:]]+POSTGRES_PASSWORD:[[:space:]]*).*$|\1$NEW_PASSWORD|" \
  -e "s|pg_isready -U [^ ]+ -d [^\"]+|pg_isready -U $NEW_USER -d $NEW_DB|" \
  -e "s|^([[:space:]]+-[[:space:]]*\")[0-9]+(:5432\")|\1$NEW_PORT\2|" \
  "$COMPOSE"
echo "  demo/docker-compose.yml (container postgres)"

# --- 2. Le variabili dei moduli nel compose ----------------------------------
# Dentro Docker la porta e' sempre 5432: quella pubblicata riguarda solo chi si
# collega dalla macchina.

sed -i -E \
  -e "s|^([[:space:]]+[A-Z0-9_]+_DB_USERNAME:[[:space:]]*).*$|\1$NEW_USER|" \
  -e "s|^([[:space:]]+[A-Z0-9_]+_DB_PASSWORD:[[:space:]]*).*$|\1$NEW_PASSWORD|" \
  "$COMPOSE"
if [ "$NEW_DB" != "$OLD_DB" ]; then
  # Solo il database condiviso: quelli dedicati (task use-postgres DBNAME=...)
  # restano com'erano.
  sed -i -E "s|^([[:space:]]+[A-Z0-9_]+_DB_URL:[[:space:]]*jdbc:postgresql://postgres:5432/)$OLD_DB[[:space:]]*$|\1$NEW_DB|" "$COMPOSE"
fi
echo "  demo/docker-compose.yml (variabili dei moduli)"

# --- 3. application.yml di ogni modulo ---------------------------------------

TOUCHED=0
for dir in "$DEMO_DIR"/*/; do
  yml="$dir/src/main/resources/application.yml"
  [ -f "$yml" ] || continue
  grep -q 'jdbc:postgresql' "$yml" || continue

  sed -i -E \
    -e "s|(_DB_USERNAME:)[^}]*(\})|\1$NEW_USER\2|" \
    -e "s|(_DB_PASSWORD:)[^}]*(\})|\1$NEW_PASSWORD\2|" \
    -e "s|(jdbc:postgresql://localhost:)[0-9]+(/)|\1$NEW_PORT\2|" \
    "$yml"
  if [ "$NEW_DB" != "$OLD_DB" ]; then
    sed -i -E "s|(jdbc:postgresql://localhost:[0-9]+/)$OLD_DB(\})|\1$NEW_DB\2|" "$yml"
  fi
  echo "  demo/$(basename "${dir%/}")/src/main/resources/application.yml"
  TOUCHED=$(( TOUCHED + 1 ))
done

# --- 4. Gli script di init dei database dedicati -----------------------------

if [ -d "$DEMO_DIR/postgres-init" ]; then
  for f in "$DEMO_DIR"/postgres-init/*.sql; do
    [ -f "$f" ] || continue
    if grep -qE "TO[[:space:]]+$OLD_USER[[:space:]]*;" "$f"; then
      sed -i -E "s|(TO[[:space:]]+)$OLD_USER([[:space:]]*;)|\1$NEW_USER\2|" "$f"
      echo "  demo/postgres-init/$(basename "$f")"
    fi
  done
fi

# --- Fatto --------------------------------------------------------------------

echo ""
echo "Configurazione aggiornata."
echo ""
if [ "$TOUCHED" -eq 0 ]; then
  echo "  Nessun modulo era collegato al database: quando lo colleghi"
  echo "  (task use-postgres SERVICE=<modulo>) prendera' questi valori."
  echo ""
fi
if [ "$NEW_DB" != "$OLD_DB" ] || [ "$NEW_USER" != "$OLD_USER" ] || [ "$NEW_PASSWORD" != "$OLD_PASSWORD" ]; then
  echo "  PostgreSQL crea utente e database solo al primo avvio, su volume"
  echo "  vuoto. Perche' i valori nuovi valgano davvero serve:"
  echo "    task docker-reset      # ATTENZIONE: cancella i dati gia' presenti"
  echo ""
fi
echo "  task check        verifica che sia rimasto tutto coerente"
echo "  task dev          riavvia lo stack in locale"
echo ""
