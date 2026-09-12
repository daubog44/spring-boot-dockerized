#!/usr/bin/env bash
# Dati di prova: all'avvio le tabelle ancora vuote si riempiono da sole.
# Equivalente POSIX di scripts/seed-data.ps1.
#
# Scrive "dev-data: rows: N" nell'application.yml dei moduli con un database:
# da li' in poi, a ogni avvio, il pacchetto devdata di common-dto riempie le
# tabelle vuote passando da Hibernate (id generati, relazioni, enum, vincoli
# rispettati). Poi compila e prova ogni modulo su un H2 usa-e-getta.
#
#   task seed-data
#   task seed-data SERVICE=ordini-service ROWS=10
#   task seed-data ROWS=0          spegne i dati di prova
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
. "$SCRIPT_DIR/scaffold-lib.sh"
. "$SCRIPT_DIR/dev-lib.sh"

MODULE=""
ROWS=5
CHECK=1
SQL=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    -Rows|--rows) ROWS="$2"; shift 2 ;;
    -NoCheck|--no-check) CHECK=0; shift ;;
    -Sql|--sql) SQL=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done
case "$ROWS" in ''|*[!0-9]*) echo "ROWS deve essere un numero (0 spegne i dati di prova)." >&2; exit 1 ;; esac
if [ "$SQL" = "1" ]; then
  if [ "$ROWS" -eq 0 ]; then
    echo "SQL=1 genera righe da scrivere in un data.sql: ROWS=0 non ha senso insieme." >&2
    exit 1
  fi
  CHECK=1
fi

# "nome|entity|h2" dei moduli da configurare.
TARGETS=()
while IFS= read -r row; do
  [ -n "$row" ] || continue
  name="${row%%|*}"
  rest="${row#*|}"
  if [ -n "$MODULE" ]; then
    [ "$name" = "$MODULE" ] && TARGETS+=("$row")
  elif [ "${rest%%|*}" = "1" ]; then
    TARGETS+=("$row")
  fi
done < <(jpa_modules "$DEMO_DIR")

echo ""
echo "==> Dati di prova"
echo ""

if [ ${#TARGETS[@]} -eq 0 ]; then
  if [ -n "$MODULE" ]; then
    echo "Il modulo '$MODULE' non c'e' o non usa un database (manca spring-boot-starter-data-jpa nel suo pom)." >&2
    exit 1
  fi
  echo "Nessun modulo con delle @Entity: non c'e' niente da riempire."
  echo ""
  echo "  Crea prima le entity del tuo dominio, poi rilancia questo comando."
  echo ""
  exit 0
fi

for row in "${TARGETS[@]}"; do
  name="${row%%|*}"
  set_devdata_rows "$DEMO_DIR/$name/src/main/resources/application.yml" "$ROWS"
  echo "  $name/src/main/resources/application.yml  dev-data.rows: $ROWS"
  # Il data.sql della versione vecchia di questo comando: adesso ci pensa
  # devdata, e le sue INSERT scritte a mano farebbero doppio lavoro.
  old="$DEMO_DIR/$name/src/main/resources/data.sql"
  if [ -f "$old" ] && head -n 1 "$old" | grep -q '^-- Dati di prova generati da task seed-data\.'; then
    rm -f "$old"
    echo "  $name/src/main/resources/data.sql  tolto (lo scriveva la versione vecchia di questo comando)"
  fi
done
echo ""

# L'application.yml appena scritto arriva al modulo gia' acceso solo se
# qualcosa lo ricompila: mvnw spring-boot:run non guarda da solo
# src/main/resources. L'avviso va dato subito: sia -NoCheck sia ROWS=0
# escono prima della prova su H2, quindi e' l'unico punto comune a ogni caso.
DEV_PIDS_FILE="$(dev_log_dir)/dev.pids"
if [ -s "$DEV_PIDS_FILE" ]; then
  echo "Lo stack e' gia' acceso (task dev): questa configurazione non arriva da sola al processo gia' partito."
  echo "  task compile           ricompila e fa ripartire i moduli gia' avviati: da qui il riempimento scatta"
  echo ""
fi

if [ "$ROWS" -eq 0 ]; then
  echo "Dati di prova spenti: all'avvio non si aggiunge piu' niente."
  echo ""
  exit 0
fi
if [ "$CHECK" = "0" ]; then
  echo "Configurazione scritta: al prossimo avvio (task dev) le tabelle vuote si riempiono."
  echo ""
  exit 0
fi

LIST=""
for row in "${TARGETS[@]}"; do
  rest="${row#*|}"
  [ "${rest%%|*}" = "1" ] && LIST="${LIST:+$LIST,}${row%%|*}"
done
if [ -z "$LIST" ]; then
  echo "Il modulo non ha ancora delle @Entity: si riempira' quando le avra'."
  echo ""
  exit 0
fi

SQL_MARKER="-- data.sql generato da task seed-data SQL=1"

echo "==> Prova su un database H2 usa-e-getta"
echo "  compilo con Maven..."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if ! build_modules "$DEMO_DIR" "$WORK/build.log" "$LIST"; then
  echo "  La compilazione e' fallita:"
  grep 'ERROR' "$WORK/build.log" | head -n 15 | sed 's/^/    /'
  echo ""
  exit 1
fi

FAILED=0
for row in "${TARGETS[@]}"; do
  name="${row%%|*}"
  rest="${row#*|}"
  [ "${rest%%|*}" = "1" ] || continue
  echo ""
  echo "  $name"
  if [ "${rest#*|}" != "1" ]; then
    echo "    senza H2 non c'e' un database usa-e-getta per provare: la prova vera sara' al prossimo avvio"
    continue
  fi
  dataSqlPath="$DEMO_DIR/$name/src/main/resources/data.sql"
  if [ "$SQL" = "1" ] && [ -f "$dataSqlPath" ] && ! head -n 1 "$dataSqlPath" | grep -qF "$SQL_MARKER"; then
    echo "    ha gia' un data.sql scritto a mano: non lo tocco (SQL=1 rigenera solo quello che ha scritto lui)"
    continue
  fi
  EXTRA_ARGS=()
  [ "$SQL" = "1" ] && EXTRA_ARGS+=("--dev-data.sql-out=$(native_path "$WORK/$name-data.sql")")
  devdata_run "$DEMO_DIR" "$name" 1 "$WORK/$name.log" "--dev-data.rows=$ROWS" "${EXTRA_ARGS[@]}"
  code=$?
  if devdata_report "$name" "$code" "$WORK/$name.log"; then
    if [ "$SQL" = "1" ] && [ -s "$WORK/$name-data.sql" ]; then
      {
        echo "$SQL_MARKER: sopravvive a task consegna (che invece toglie devdata)."
        echo "-- Rigeneralo con: task seed-data SQL=1 SERVICE=$name"
        echo ""
        cat "$WORK/$name-data.sql"
      } >"$dataSqlPath"
      ensure_sql_init "$DEMO_DIR/$name/src/main/resources/application.yml"
      set_devdata_rows "$DEMO_DIR/$name/src/main/resources/application.yml" 0
      echo "    $name/src/main/resources/data.sql  scritto (righe fisse: da qui devdata resta spento, dev-data.rows: 0)"
    fi
  else
    FAILED=$((FAILED + 1))
  fi
done
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo "Qualche tabella non si riempie: sopra c'e' il motivo, tabella per tabella."
  echo "  Le altre si riempiono lo stesso, e l'avvio non fallisce mai per i dati di prova."
  echo ""
  exit 1
fi
echo "Dati di prova pronti."
echo ""
echo "  task dev               all'avvio le tabelle vuote si riempiono da sole"
echo "                         (anche su PostgreSQL e in Docker)"
echo "  task db-schema         lo schema di queste tabelle, letto dal database"
echo "  task seed-data ROWS=0  per spegnerli"
echo ""
