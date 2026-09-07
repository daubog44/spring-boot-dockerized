#!/usr/bin/env bash
# Avvia l'intero stack in locale con un solo comando, con hot reload.
# Equivalente POSIX di scripts/dev.ps1: nessuna finestra per servizio, l'output
# va in .dev-logs/<servizio>.log e si segue con `task logs`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dev-lib.sh
. "$SCRIPT_DIR/dev-lib.sh"

# Porta della UI: -UiPort/--ui-port N, per allinearsi a dev.ps1 (il Taskfile
# passa gli stessi argomenti a entrambi gli script).
UI_PORT=8080
NO_BUILD=""
KEEP_FOREIGN=""
while [ $# -gt 0 ]; do
  case "$1" in
    -UiPort|--ui-port) UI_PORT="$2"; shift 2 ;;
    -NoBuild|--no-build) NO_BUILD=1; shift ;;
    -KeepForeign|--keep-foreign) KEEP_FOREIGN=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(dev_repo_root)"
DEMO_DIR="$REPO_ROOT/demo"
LOG_DIR="$(dev_log_dir)"

# --- Configurazione dello stack (l'unica parte che cambia da traccia a traccia) ---

# Ordine di avvio: Eureka per primo, poi i servizi che vi si registrano.
SERVICES=(
  "eureka:naming-server:8761"
  "product:product-service:8081"
  "crm:crm-service:8082"
  "wms:wms-service:8083"
  "wms-ui:wms-ui:$UI_PORT"
)

# I servizi di questa traccia usano H2 in memoria: nessun database da avviare.
USES_POSTGRES=0

mkdir -p "$LOG_DIR"

# --- Pulizia iniziale ---------------------------------------------------------

# Un `task dev` lanciato due volte, o dopo un crash, troverebbe le porte
# occupate dai propri stessi processi: li fermiamo prima di ricominciare.
echo ""
echo "==> Libero le porte dello stack..."
CONFIGURED_PORTS=""
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r _name _module port <<<"$svc"
  CONFIGURED_PORTS="$CONFIGURED_PORTS $port"
done
cleaned="$(stop_dev_stack "$LOG_DIR" "" "$REPO_ROOT" "$KEEP_FOREIGN" "$CONFIGURED_PORTS")"
[ "$cleaned" -eq 0 ] && echo "  erano gia libere."

# Log degli avvii precedenti: `task logs` segue tutto quello che trova qui,
# quindi un log rimasto da un'altra traccia comparirebbe insieme a quelli veri.
rm -f "$LOG_DIR"/*.log

# --- Controllo porte occupate -------------------------------------------------

busy=""
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name _module port <<<"$svc"
  if port_in_use "$port"; then busy="$busy $name:$port"; fi
done
if [ -n "$busy" ]; then
  echo "Porte ancora occupate dopo la pulizia:$busy" >&2
  echo "Sono processi che non abbiamo avviato noi (container Docker, o altro)." >&2
  echo "  task docker-down    # se sono i container dell'esame" >&2
  echo "  task status         # per vedere chi occupa cosa" >&2
  exit 1
fi

# --- Build unica --------------------------------------------------------------

if [ -z "$NO_BUILD" ]; then
  echo "==> Compilazione di tutti i moduli (una sola volta)..."
  (cd "$DEMO_DIR" && ./mvnw -q install -Dmaven.test.skip=true)
  echo "==> Compilazione completata."
fi

# --- PostgreSQL ---------------------------------------------------------------

if [ "$USES_POSTGRES" -eq 1 ]; then
  echo "==> Avvio PostgreSQL su Docker..."
  (cd "$DEMO_DIR" && docker compose up -d postgres)
  if ! wait_for_port 5432 60; then
    echo "PostgreSQL non risponde sulla porta 5432." >&2
    exit 1
  fi
  # Segnaposto per dev-down: fermiamo il container solo se l'abbiamo avviato noi.
  echo 1 >"$LOG_DIR/dev.postgres"
  echo "==> PostgreSQL pronto."
fi

# --- Avvio ordinato -----------------------------------------------------------

: >"$LOG_DIR/dev.pids"
# Registra le porte realmente usate, cosi' la pulizia sa quali liberare.
: >"$LOG_DIR/dev.ports"
# I nomi, nell'ordine di avvio: `task logs` li segue in quest'ordine.
: >"$LOG_DIR/dev.services"
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r n _m p <<<"$svc"
  echo "$p" >>"$LOG_DIR/dev.ports"
  echo "$n" >>"$LOG_DIR/dev.services"
done

started_ok=0
cleanup_on_failure() {
  if [ "$started_ok" -eq 0 ]; then
    echo ""
    echo "==> Avvio non riuscito: fermo i servizi gia' partiti..." >&2
    # Qui vogliamo solo ritirare quello che abbiamo avviato noi.
    stop_dev_stack "$LOG_DIR" "" "" 1 >/dev/null
  fi
}
# Vale anche per Ctrl+C: non lasciamo mezzo stack acceso a occupare le porte.
trap cleanup_on_failure EXIT

show_log_tail() {
  local name="$1"
  [ -f "$LOG_DIR/$name.log" ] || return 0
  echo ""
  echo "--- ultime righe di $name.log ---" >&2
  tail -n 25 "$LOG_DIR/$name.log" >&2
}

for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name module port <<<"$svc"
  echo "==> Avvio $name sulla porta $port..."
  (cd "$DEMO_DIR/$module" && ../mvnw spring-boot:run "-Dspring-boot.run.arguments=--server.port=$port") >"$LOG_DIR/$name.log" 2>&1 &
  echo "$! $name" >>"$LOG_DIR/dev.pids"

  # Eureka deve essere in ascolto prima che gli altri tentino di registrarsi,
  # altrimenti la prima registrazione slitta di un intero ciclo di heartbeat.
  if [ "$name" = "eureka" ]; then
    if ! wait_for_port "$port"; then
      echo "Eureka non risponde sulla porta $port." >&2
      show_log_tail eureka
      exit 1
    fi
    echo "==> Eureka pronto."
  fi
done

# --- Attesa dei servizi -------------------------------------------------------

echo ""
echo "==> Attendo che i servizi siano in ascolto..."
failed=""
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name _module port <<<"$svc"
  [ "$name" = "eureka" ] && continue
  if wait_for_port "$port"; then
    printf '    %-8s :%s  OK\n' "$name" "$port"
  else
    printf '    %-8s :%s  NON PARTITO\n' "$name" "$port"
    failed="$failed $name"
  fi
done

if [ -n "$failed" ]; then
  echo "Servizi non partiti:$failed" >&2
  for name in $failed; do show_log_tail "$name"; done
  exit 1
fi

started_ok=1

echo ""
echo "Stack locale avviato."
echo ""
# Gli indirizzi vengono dalla configurazione in cima: cambiando una porta li',
# questo elenco resta giusto senza altri interventi.
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name _module port <<<"$svc"
  case "$name" in
    eureka) printf '  %-18s%s\n' "Dashboard Eureka" "http://localhost:$port" ;;
    ui|*-ui) printf '  %-18s%s\n' "UI $name" "http://localhost:$port" ;;
    *)      printf '  %-18s%s\n' "Swagger $name" "http://localhost:$port/swagger-ui.html" ;;
  esac
done

cat <<EOF

  task logs         segue i log di tutti i servizi (Ctrl+C per uscire)
  task logs -- wms  solo quel servizio
  task status       chi occupa le porte
  task dev-down     ferma tutto

Hot reload attivo: dopo una modifica lancia \`task compile\` e il servizio si riavvia da solo.
Nota: i client Feign impiegano 10-15 secondi ad aggiornare il registro Eureka.
EOF
