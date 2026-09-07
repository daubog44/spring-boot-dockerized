#!/usr/bin/env bash
# Avvia l'intero stack in locale con un solo comando, con hot reload.
# Equivalente POSIX di scripts/dev.ps1.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
LOG_DIR="$REPO_ROOT/.dev-logs"
PID_FILE="$LOG_DIR/dev.pids"

# Ordine di avvio: Eureka per primo, poi i servizi che vi si registrano.
SERVICES=(
  "eureka:naming-server:8761"
  "product:product-service:8081"
  "crm:crm-service:8082"
  "wms:wms-service:8083"
  "wms-ui:wms-ui:8080"
)

port_in_use() {
  local port="$1"
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
  fi
}

wait_for_port() {
  local port="$1" timeout="${2:-120}" elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if port_in_use "$port"; then return 0; fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

# --- Controllo porte occupate -------------------------------------------------

busy=""
for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name _module port <<<"$svc"
  if port_in_use "$port"; then busy="$busy $name:$port"; fi
done
if [ -n "$busy" ]; then
  echo "Porte gia in uso:$busy" >&2
  echo "Lo stack Docker e ancora attivo, oppure sono rimasti processi Java appesi." >&2
  echo "  task docker-down    # se hai avviato i container" >&2
  echo "  task dev-down       # se sono processi Java locali" >&2
  exit 1
fi

# --- Build unica --------------------------------------------------------------

echo "==> Compilazione di tutti i moduli (una sola volta)..."
(cd "$DEMO_DIR" && ./mvnw -q install -Dmaven.test.skip=true)
echo "==> Compilazione completata."

# --- Avvio ordinato -----------------------------------------------------------

mkdir -p "$LOG_DIR"
: >"$PID_FILE"

for svc in "${SERVICES[@]}"; do
  IFS=':' read -r name module port <<<"$svc"
  echo "==> Avvio $name sulla porta $port..."
  (cd "$DEMO_DIR/$module" && ../mvnw spring-boot:run) >"$LOG_DIR/$name.log" 2>&1 &
  echo "$! $name" >>"$PID_FILE"

  # Eureka deve essere in ascolto prima che gli altri tentino di registrarsi,
  # altrimenti la prima registrazione slitta di un intero ciclo di heartbeat.
  if [ "$name" = "eureka" ]; then
    if ! wait_for_port "$port"; then
      echo "Eureka non risponde sulla porta $port: vedi $LOG_DIR/eureka.log" >&2
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

echo ""
if [ -n "$failed" ]; then
  echo "Servizi non partiti:$failed. Leggi i log in $LOG_DIR." >&2
  exit 1
fi

cat <<EOF
Stack locale avviato.

  UI WMS            http://localhost:8080
  Dashboard Eureka  http://localhost:8761
  Swagger product   http://localhost:8081/swagger-ui.html
  Swagger crm       http://localhost:8082/swagger-ui.html
  Swagger wms       http://localhost:8083/swagger-ui.html

Log dei servizi in $LOG_DIR
Hot reload attivo: dopo una modifica lancia \`task compile\` e il servizio si riavvia da solo.
Per fermare tutto: task dev-down

Nota: i client Feign impiegano 10-15 secondi ad aggiornare il registro Eureka.
EOF
