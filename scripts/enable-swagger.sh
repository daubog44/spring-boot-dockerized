#!/usr/bin/env bash
# Accende Swagger UI su un modulo che non ce l'ha.
# Equivalente POSIX di scripts/enable-swagger.ps1.
#
# I moduli creati con `task new-service` hanno gia' springdoc: questo comando
# serve per un modulo scritto a mano, o da cui la dipendenza e' stata tolta.
# E' idempotente: se c'e' gia' tutto, non tocca niente.
#
#   task enable-swagger SERVICE=ordini-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

MODULE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$MODULE" ]; then
  echo "Uso: task enable-swagger SERVICE=<modulo>" >&2
  exit 1
fi
POM="$DEMO_DIR/$MODULE/pom.xml"
if [ ! -f "$POM" ]; then
  available=""
  for dir in "$DEMO_DIR"/*/; do
    [ -f "$dir/pom.xml" ] && available="$available $(basename "$dir")"
  done
  echo "Modulo '$MODULE' non trovato. Moduli disponibili:$available" >&2
  exit 1
fi

echo ""
echo "==> Swagger UI su $MODULE"
echo ""

TOUCHED=0

# --- 1. La dipendenza nel pom -------------------------------------------------

if grep -q '<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>' "$POM"; then
  echo "  pom.xml: springdoc gia' presente"
else
  N="$(grep -nE '^[[:space:]]*</dependencies>' "$POM" | head -n 1 | cut -d: -f1)"
  [ -n "$N" ] || { echo "Non trovo </dependencies> in $POM: aggiungi la dipendenza a mano." >&2; exit 1; }
  BLOCK='        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
        </dependency>'
  awk -v n="$((N - 1))" -v text="$BLOCK" '{ print } NR == n { print text }' "$POM" >"$POM.tmp" && mv "$POM.tmp" "$POM"
  echo "  pom.xml: aggiunta la dipendenza springdoc"
  TOUCHED=1
fi

# Senza spring-web non c'e' niente da documentare: springdoc legge i controller.
if ! grep -q '<artifactId>spring-boot-starter-web</artifactId>' "$POM"; then
  echo "  Attenzione: questo modulo non ha spring-boot-starter-web."
  echo "  Swagger documenta i controller REST: senza web non c'e' niente da mostrare."
  echo "  task add-dep SERVICE=$MODULE DEPS=web"
fi

# --- 2. Il blocco nell'application.yml ---------------------------------------

YML="$DEMO_DIR/$MODULE/src/main/resources/application.yml"
if [ ! -f "$YML" ]; then
  echo "Non trovo $YML: il modulo non ha una configurazione da estendere." >&2
  exit 1
fi

if grep -qE '^springdoc:' "$YML"; then
  echo "  application.yml: blocco springdoc gia' presente"
else
  cat >>"$YML" <<'EOF'

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
EOF
  echo "  application.yml: aggiunto il blocco springdoc"
  TOUCHED=1
fi

# --- Fatto --------------------------------------------------------------------

PORT="$(grep -oE 'SERVER_PORT:[0-9]+' "$YML" | head -n 1 | cut -d: -f2 || true)"

echo ""
if [ "$TOUCHED" -eq 0 ]; then
  echo "Era gia' tutto a posto: non ho cambiato niente."
else
  echo "Swagger UI abilitato."
  echo ""
  echo "  task dev          per vederlo (una dipendenza nuova non entra a caldo)"
fi
echo ""
if [ -n "$PORT" ]; then
  echo "  http://localhost:$PORT/swagger-ui.html"
  echo "  http://localhost:$PORT/v3/api-docs"
fi
echo ""
