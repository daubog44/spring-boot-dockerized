#!/usr/bin/env bash
# Genera un gestore globale delle eccezioni (@RestControllerAdvice) per un modulo.
# Equivalente POSIX di scripts/new-handler.ps1.
#
#   task new-handler SERVICE=ordini-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SERVICE" ]; then
  if [ ! -t 0 ]; then
    echo "Uso: task new-handler SERVICE=<modulo>" >&2
    exit 1
  fi

  ALL_MODULES=()
  for d in "$DEMO_DIR"/*; do
    if [ -f "$d/pom.xml" ] && [ "$(basename "$d")" != "common-dto" ]; then
      ALL_MODULES+=("$(basename "$d")")
    fi
  done
  if [ "${#ALL_MODULES[@]}" -eq 0 ]; then
    echo "Non ci sono moduli in demo/." >&2
    exit 1
  fi

  echo ""
  echo "GENERATORE GLOBAL EXCEPTION HANDLER"
  echo "Seleziona il modulo in cui inserire GlobalExceptionHandler:"
  for i in "${!ALL_MODULES[@]}"; do
    echo "  $((i+1))) ${ALL_MODULES[$i]}"
  done
  printf "  [1] > "
  read -r IDX
  [ -n "$IDX" ] || IDX=1
  SERVICE="${ALL_MODULES[$((IDX-1))]}"
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
if [ ! -f "$MODULE_DIR/pom.xml" ]; then
  echo "Non trovo il modulo '$SERVICE' in demo/." >&2
  exit 1
fi

BASE_PKG="$(base_package "$DEMO_DIR")"
PKG="$BASE_PKG.$(printf '%s' "$SERVICE" | tr -cd 'a-zA-Z0-9')"
PKG_PATH="$(printf '%s' "$PKG" | tr '.' '/')"
CONTROLLER_DIR="$MODULE_DIR/src/main/java/$PKG_PATH/controller"
mkdir -p "$CONTROLLER_DIR"

HANDLER_FILE="$CONTROLLER_DIR/GlobalExceptionHandler.java"
if [ -e "$HANDLER_FILE" ]; then
  echo "  GlobalExceptionHandler gia' presente in $SERVICE."
  exit 0
fi

cat > "$HANDLER_FILE" <<EOF
package $PKG.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Gestore centralizzato delle eccezioni generato da task new-handler.
 * Trasforma errori di validazione (@Valid), 404 e 500 in risposte JSON strutturate.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            errors.put(error.getField(), error.getDefaultMessage());
        }

        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("error", "Bad Request");
        body.put("message", "Errori di validazione sui campi della richiesta");
        body.put("details", errors);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatusException(ResponseStatusException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", ex.getStatusCode().value());
        body.put("error", ex.getStatusCode().toString());
        body.put("message", ex.getReason());

        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
        body.put("error", "Internal Server Error");
        body.put("message", ex.getMessage() != null ? ex.getMessage() : "Errore interno imprevisto");

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
EOF

echo "  demo/$SERVICE/src/main/java/$PKG_PATH/controller/GlobalExceptionHandler.java"
echo ""
echo "GlobalExceptionHandler generato con successo per '$SERVICE'."
echo ""
