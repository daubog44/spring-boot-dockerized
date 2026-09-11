#!/usr/bin/env bash
# Genera un client OpenFeign per chiamare un altro microservizio via Eureka.
# Equivalente POSIX di scripts/new-client.ps1.
#
#   task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

FROM=""
TO=""
NAME=""
DTO=""
PATH_VAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    -From|--from) FROM="$2"; shift 2 ;;
    -To|--to) TO="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Dto|--dto) DTO="$2"; shift 2 ;;
    -Path|--path) PATH_VAL="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$FROM" ] || [ -z "$TO" ]; then
  echo "Uso: task new-client FROM=<modulo-chiamante> TO=<modulo-target> [DTO=<NomeDto>] [NAME=<ClientName>] [PATH=<rotta>]" >&2
  exit 1
fi

FROM_DIR="$DEMO_DIR/$FROM"
[ -f "$FROM_DIR/pom.xml" ] || { echo "Non trovo il modulo chiamante '$FROM' in demo/." >&2; exit 1; }
TO_DIR="$DEMO_DIR/$TO"
[ -f "$TO_DIR/pom.xml" ] || { echo "Non trovo il modulo target '$TO' in demo/." >&2; exit 1; }

EUREKA_NAME="$(printf '%s' "$TO" | tr '[:lower:]' '[:upper:]')"
TO_YML="$TO_DIR/src/main/resources/application.yml"
if [ -f "$TO_YML" ]; then
  APP_HIT="$(grep -E '^[[:space:]]+name:[[:space:]]*[^[:space:]]+' "$TO_YML" | head -n 1 | awk '{print $2}' || true)"
  if [ -n "$APP_HIT" ]; then
    EUREKA_NAME="$(printf '%s' "$APP_HIT" | tr '[:lower:]' '[:upper:]')"
  fi
fi

# Helper per PascalCase
to_pascal() {
  local s="$1"
  local clean
  clean="$(printf '%s' "$s" | sed -e 's/[^a-zA-Z0-9]/ /g')"
  local out=""
  for w in $clean; do
    local first rest
    first="$(printf '%s' "$w" | cut -c1 | tr '[:lower:]' '[:upper:]')"
    rest="$(printf '%s' "$w" | cut -c2- | tr '[:upper:]' '[:lower:]')"
    out="${out}${first}${rest}"
  done
  printf '%s' "$out"
}

if [ -n "$NAME" ]; then
  CLIENT_NAME="$NAME"
else
  BASE_TO="$(printf '%s' "$TO" | sed -E 's/-(service|app|api)$//')"
  CLIENT_NAME="$(to_pascal "$BASE_TO")Client"
fi

ROUTE_PATH="$PATH_VAL"
if [ -z "$ROUTE_PATH" ]; then
  ROUTE_PATH="/api"
fi

DTO_NAME="${DTO:-}"
if [ -z "$DTO_NAME" ]; then
  DTO_NAME="Object"
fi

FROM_PKG="$(base_package "$DEMO_DIR").$(printf '%s' "$FROM" | tr -cd 'a-zA-Z0-9')"
FROM_PKG_PATH="$(printf '%s' "$FROM_PKG" | tr '.' '/')"
CLIENT_DIR="$FROM_DIR/src/main/java/$FROM_PKG_PATH/client"
mkdir -p "$CLIENT_DIR"

CLIENT_FILE="$CLIENT_DIR/$CLIENT_NAME.java"
if [ -e "$CLIENT_FILE" ]; then
  echo "C'e' gia' $CLIENT_FILE. Cancellalo prima, o specifica NAME=<AltroNome>." >&2
  exit 1
fi

BASE_PKG="$(base_package "$DEMO_DIR")"
DTO_IMPORT=""
if [ "$DTO_NAME" != "Object" ]; then
  DTO_IMPORT="import $BASE_PKG.common.dto.$DTO_NAME;"$'\n'
fi

cat > "$CLIENT_FILE" <<EOF
package $FROM_PKG.client;

${DTO_IMPORT}import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * Client OpenFeign per comunicare con $EUREKA_NAME via Eureka.
 * Generato da task new-client.
 */
@FeignClient(name = "$EUREKA_NAME")
public interface $CLIENT_NAME {

    @GetMapping("$ROUTE_PATH")
    List<$DTO_NAME> getAll();

    @GetMapping("$ROUTE_PATH/{id}")
    $DTO_NAME getById(@PathVariable("id") Long id);

    @PostMapping("$ROUTE_PATH")
    $DTO_NAME create(@RequestBody $DTO_NAME body);

    @PutMapping("$ROUTE_PATH/{id}")
    $DTO_NAME update(@PathVariable("id") Long id, @RequestBody $DTO_NAME body);

    @DeleteMapping("$ROUTE_PATH/{id}")
    void delete(@PathVariable("id") Long id);
}
EOF

echo "  demo/$FROM/src/main/java/$FROM_PKG_PATH/client/$CLIENT_NAME.java"
