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
FIELDS=""

while [ $# -gt 0 ]; do
  case "$1" in
    -From|--from) FROM="$2"; shift 2 ;;
    -To|--to) TO="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Dto|--dto) DTO="$2"; shift 2 ;;
    -Path|--path) PATH_VAL="$2"; shift 2 ;;
    -Fields|--fields) FIELDS="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

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

if [ -z "$FROM" ] || [ -z "$TO" ]; then
  if [ ! -t 0 ]; then
    echo "Uso: task new-client FROM=<modulo-chiamante> TO=<modulo-target> [DTO=<NomeDto>] [FIELDS=<campi>] [NAME=<ClientName>] [ROUTE=<rotta>]" >&2
    echo "Esempio: task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto FIELDS=id:long,titolo:string:required" >&2
    exit 1
  fi

  ALL_MODULES=()
  for d in "$DEMO_DIR"/*/; do
    [ -f "$d/pom.xml" ] || continue
    m="$(basename "$d")"
    [ "$m" = "common-dto" ] && continue
    ALL_MODULES+=("$m")
  done
  if [ "${#ALL_MODULES[@]}" -lt 2 ]; then
    echo "Servono almeno due moduli in demo/ per collegare un client OpenFeign." >&2
    exit 1
  fi

  echo ""
  echo "CREAZIONE OPENFEIGN CLIENT GUIDATA"
  if [ -z "$FROM" ]; then
    echo "Seleziona il modulo CHIAMANTE (da dove parte la chiamata):"
    for i in "${!ALL_MODULES[@]}"; do
      echo "  $((i+1))) ${ALL_MODULES[$i]}"
    done
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    FROM="${ALL_MODULES[$((IDX-1))]}"
  fi

  if [ -z "$TO" ]; then
    TARGETS=()
    for m in "${ALL_MODULES[@]}"; do
      [ "$m" != "$FROM" ] && TARGETS+=("$m")
    done
    echo "Seleziona il modulo TARGET (chi risponde):"
    for i in "${!TARGETS[@]}"; do
      echo "  $((i+1))) ${TARGETS[$i]}"
    done
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    TO="${TARGETS[$((IDX-1))]}"
  fi

  TARGET_ROUTES=()
  if [ -d "$DEMO_DIR/$TO/src/main/java" ]; then
    while IFS= read -r c; do
      [ -f "$c" ] || continue
      while IFS= read -r m; do
        if [ -n "$m" ] && [ "$m" != "/api/ping" ]; then
          already=0
          for kr in "${TARGET_ROUTES[@]}"; do
            if [ "$kr" = "$m" ]; then already=1; break; fi
          done
          [ $already -eq 0 ] && TARGET_ROUTES+=("$m")
        fi
      done < <(grep -oE '@RequestMapping\([[:space:]]*(value[[:space:]]*=[[:space:]]*|path[[:space:]]*=[[:space:]]*)?"[^"]*"' "$c" 2>/dev/null | sed -E 's/.*"([^"]*)".*/\1/')
    done < <(find "$DEMO_DIR/$TO/src/main/java" -name '*Controller.java' 2>/dev/null)
  fi

  if [ -z "$PATH_VAL" ]; then
    if [ "${#TARGET_ROUTES[@]}" -gt 1 ]; then
      echo "Rotte disponibili rilevate in $TO:"
      for i in "${!TARGET_ROUTES[@]}"; do
        echo "  $((i+1))) ${TARGET_ROUTES[$i]}"
      done
      echo "  $((${#TARGET_ROUTES[@]}+1))) Altra rotta personalizzata"
      printf "  [1] > "
      read -r R_IDX
      [ -n "$R_IDX" ] || R_IDX=1
      if [ "$R_IDX" -ge 1 ] && [ "$R_IDX" -le "${#TARGET_ROUTES[@]}" ]; then
        PATH_VAL="${TARGET_ROUTES[$((R_IDX-1))]}"
      else
        printf "  Prefisso rotta REST (default: /api): "
        read -r PATH_VAL
      fi
    elif [ "${#TARGET_ROUTES[@]}" -eq 1 ]; then
      PATH_VAL="${TARGET_ROUTES[0]}"
      echo "  Rotta rilevata: $PATH_VAL"
    fi
  fi

  if [ -z "$DTO" ]; then
    SUGG_DTO=""
    if [ -n "$PATH_VAL" ]; then
      TOKEN="$(basename "$PATH_VAL")"
      SUGG_DTO="$(to_pascal "$TOKEN")Dto"
    fi
    if [ -n "$SUGG_DTO" ]; then
      printf "  Nome DTO scambiato (premi Invio per %s): " "$SUGG_DTO"
    else
      printf "  Nome DTO scambiato (es. LibroDto, OrdineDto): "
    fi
    read -r INP_DTO
    if [ -n "$INP_DTO" ]; then
      DTO="$INP_DTO"
    elif [ -n "$SUGG_DTO" ]; then
      DTO="$SUGG_DTO"
    fi
  fi
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

KNOWN_ROUTES=()
if [ -d "$TO_DIR/src/main/java" ]; then
  while IFS= read -r c; do
    [ -f "$c" ] || continue
    while IFS= read -r m; do
      if [ -n "$m" ] && [ "$m" != "/api/ping" ]; then
        already=0
        for kr in "${KNOWN_ROUTES[@]}"; do
          if [ "$kr" = "$m" ]; then already=1; break; fi
        done
        [ $already -eq 0 ] && KNOWN_ROUTES+=("$m")
      fi
    done < <(grep -oE '@RequestMapping\([[:space:]]*(value[[:space:]]*=[[:space:]]*|path[[:space:]]*=[[:space:]]*)?"[^"]*"' "$c" 2>/dev/null | sed -E 's/.*"([^"]*)".*/\1/')
  done < <(find "$TO_DIR/src/main/java" -name '*Controller.java' 2>/dev/null)
fi

ROUTE_PATH="$PATH_VAL"
if [ -z "$ROUTE_PATH" ]; then
  if [ "${#KNOWN_ROUTES[@]}" -gt 0 ]; then
    ROUTE_PATH="${KNOWN_ROUTES[0]}"
  else
    ROUTE_PATH="/api"
  fi
fi
ROUTE_PATH="$(printf '%s' "$ROUTE_PATH" | sed -E 's#/+$##')"
[ -z "$ROUTE_PATH" ] && ROUTE_PATH="/api"
case "$ROUTE_PATH" in
  /*) ;;
  *) ROUTE_PATH="/$ROUTE_PATH" ;;
esac

# Avviso rotta non trovata sul target
if [ "${#KNOWN_ROUTES[@]}" -gt 0 ]; then
  MATCH_FOUND=0
  for kr in "${KNOWN_ROUTES[@]}"; do
    if [ "$kr" = "$ROUTE_PATH" ]; then MATCH_FOUND=1; break; fi
  done
  if [ $MATCH_FOUND -eq 0 ]; then
    echo -e "\033[33mATTENZIONE: Nessun controller in '$TO' espone la rotta '$ROUTE_PATH'.\033[0m"
    echo -e "\033[33m            Rotte trovate nel target: ${KNOWN_ROUTES[*]}\033[0m"
    echo -e "\033[33m            Se l'endpoint non esiste, le chiamate Feign falliranno con HTTP 404 (Not Found) a runtime.\033[0m"
  fi
fi

if [ -n "$NAME" ]; then
  CLIENT_NAME="$NAME"
else
  BASE_TO="$(printf '%s' "$TO" | sed -E 's/-(service|app|api)$//')"
  CLIENT_NAME="$(to_pascal "$BASE_TO")Client"
fi

DTO_NAME="${DTO:-}"
if [ -z "$DTO_NAME" ]; then
  if [ -n "$FIELDS" ]; then
    BASE_TO="$(printf '%s' "$TO" | sed -E 's/-(service|app|api)$//')"
    DTO_NAME="$(to_pascal "$BASE_TO")Dto"
  else
    BASE_PKG="$(base_package "$DEMO_DIR")"
    BASE_PKG_PATH="$(printf '%s' "$BASE_PKG" | tr '.' '/')"
    COMMON_DIR="$DEMO_DIR/common-dto/src/main/java/$BASE_PKG_PATH/common/dto"
    ROUTE_TOKEN="$(basename "$ROUTE_PATH")"
    ROUTE_DTO="$(to_pascal "$ROUTE_TOKEN")Dto"
    BASE_TO="$(printf '%s' "$TO" | sed -E 's/-(service|app|api)$//')"
    CANDIDATE="$(to_pascal "$BASE_TO")Dto"
    if [ -f "$COMMON_DIR/$ROUTE_DTO.java" ]; then
      DTO_NAME="$ROUTE_DTO"
    elif [ -f "$COMMON_DIR/$CANDIDATE.java" ]; then
      DTO_NAME="$CANDIDATE"
    else
      DTO_NAME="Object"
    fi
  fi
fi

# Auto-generazione DTO in common-dto se sono forniti FIELDS o se il DTO indicato non esiste ancora
if [ "$DTO_NAME" != "Object" ]; then
  BASE_PKG="$(base_package "$DEMO_DIR")"
  BASE_PKG_PATH="$(printf '%s' "$BASE_PKG" | tr '.' '/')"
  DTO_FILE="$DEMO_DIR/common-dto/src/main/java/$BASE_PKG_PATH/common/dto/$DTO_NAME.java"
  if [ -n "$FIELDS" ] || [ ! -f "$DTO_FILE" ]; then
    CLEAN_DTO_BASE="$(printf '%s' "$DTO_NAME" | sed -E 's/[Dd][Tt][Oo]$//')"
    DTO_ARGS=(--name "$CLEAN_DTO_BASE")
    if [ -n "$FIELDS" ]; then
      DTO_ARGS+=(--fields "$FIELDS")
    fi
    bash "$SCRIPT_DIR/new-dto.sh" "${DTO_ARGS[@]}" >/dev/null
  fi
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
FIRST_CHAR="$(printf '%s' "${CLIENT_NAME:0:1}" | tr '[:upper:]' '[:lower:]')"
CONTEXT_ID="${FIRST_CHAR}${CLIENT_NAME:1}"

cat > "$CLIENT_FILE" <<EOF
package $FROM_PKG.client;

${DTO_IMPORT}import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * Client OpenFeign per comunicare con $EUREKA_NAME via Eureka.
 * Generato da task new-client.
 *
 * Punti di estensione per la traccia d'esame:
 *   - Aggiungi metodi con @RequestParam per ricerche/filtri (es. List<$DTO_NAME> cerca(@RequestParam String query))
 *   - Aggiungi metodi per rotte specifiche (es. @PatchMapping("$ROUTE_PATH/{id}/stato"))
 */
@FeignClient(name = "$EUREKA_NAME", contextId = "$CONTEXT_ID")
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
