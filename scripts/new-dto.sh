#!/usr/bin/env bash
# Genera un DTO (Java record o classe) in common-dto (o in un modulo).
# Equivalente POSIX di scripts/new-dto.ps1.
#
#   task new-dto NAME=Libro FIELDS=id:long,titolo:string(150):required,disponibile:bool
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE="common-dto"
NAME=""
FIELDS=""
CLASS_MODE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Fields|--fields) FIELDS="$2"; shift 2 ;;
    -Class|--class) CLASS_MODE=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# --- Helper read_answer: supporta WIZARD_ANSWERS per test automatici ---
read_answer() {
  local prompt="${1:-> }"
  if [ -n "${WIZARD_ANSWERS:-}" ] && [ -f "$WIZARD_ANSWERS" ]; then
    local answer
    answer="$(head -n 1 "$WIZARD_ANSWERS")"
    sed -i '1d' "$WIZARD_ANSWERS" 2>/dev/null || true
    printf '%s %s\n' "$prompt" "$answer"
    printf '%s' "$answer"
  else
    printf '%s ' "$prompt" >&2
    local ans
    read -r ans
    printf '%s' "$ans"
  fi
}

if [ -z "$NAME" ] || [ -z "$FIELDS" ]; then
  if [ ! -t 0 ] && [ -z "${WIZARD_ANSWERS:-}" ]; then
    if [ -z "$NAME" ]; then
      echo "Uso: task new-dto NAME=<Nome> [FIELDS=<campo:tipo:modificatore,...>] [SERVICE=common-dto]" >&2
      exit 1
    fi
  else
    if [ -z "$NAME" ]; then
      echo ""
      echo "CREAZIONE DTO/RECORD GUIDATA"
      NAME="$(read_answer "  Nome del DTO in PascalCase (es. LibroDto, OrdineDto, ArticoloDto)")"
      [ -n "$NAME" ] || { echo "Uso: task new-dto NAME=<Nome> [FIELDS=<campo:tipo:modificatore,...>] [SERVICE=common-dto]" >&2; exit 1; }
    fi

    if [ -z "$FIELDS" ]; then
      echo ""
      echo "  Come vuoi definire i campi?"
      echo "    1) guidato, un campo alla volta (tipo e modificatori da menu)"
      echo "    2) tutti insieme, in una riga (come FIELDS=... da riga di comando)"
      FIELD_MODE="$(read_answer "  Modalita' [1]")"
      if [ "$FIELD_MODE" = "2" ]; then
        echo "  Esempio: id:long,titolo:string(150):required,anno:int:min(1900),prezzo:decimal"
        FIELDS="$(read_answer "  Campi")"
      else
        FIELD_TOKENS=""
        while true; do
          FNAME="$(read_answer "  Nome campo (Invio per terminare)")"
          [ -n "$FNAME" ] || break

          echo "    1) string      4) long       7) date        10) email"
          echo "    2) string(N)   5) decimal    8) datetime    11) enum(A|B|C)"
          echo "    3) text        6) bool       9) int"
          TYPE_CHOICE="$(read_answer "    Tipo [1]")"
          case "$TYPE_CHOICE" in
            2) SLEN="$(read_answer "    Lunghezza massima")"; TYPE_TOKEN="string($SLEN)" ;;
            3) TYPE_TOKEN="text" ;;
            4) TYPE_TOKEN="long" ;;
            5) TYPE_TOKEN="decimal" ;;
            6) TYPE_TOKEN="bool" ;;
            7) TYPE_TOKEN="date" ;;
            8) TYPE_TOKEN="datetime" ;;
            9) TYPE_TOKEN="int" ;;
            10) TYPE_TOKEN="email" ;;
            11) EVALS="$(read_answer "    Valori separati da | (es. ATTIVO|SOSPESO)")"; TYPE_TOKEN="enum($EVALS)" ;;
            *) TYPE_TOKEN="string" ;;
          esac

          echo "    Modificatori, numeri separati da virgola (Invio per nessuno):"
          echo "      1) required   2) unique   3) min(N)   4) max(N)"
          MOD_CHOICE="$(read_answer "    Modificatori")"
          MODS=""
          if [ -n "$MOD_CHOICE" ]; then
            OLD_IFS="$IFS"; IFS=','
            for m in $MOD_CHOICE; do
              m="${m// /}"
              case "$m" in
                1) MODS="${MODS}:required" ;;
                2) MODS="${MODS}:unique" ;;
                3) MV="$(read_answer "      Minimo")"; MODS="${MODS}:min($MV)" ;;
                4) MV="$(read_answer "      Massimo")"; MODS="${MODS}:max($MV)" ;;
              esac
            done
            IFS="$OLD_IFS"
          fi

          TOKEN="${FNAME}:${TYPE_TOKEN}${MODS}"
          echo "    -> $TOKEN"
          echo ""

          AGAIN="$(read_answer "  Un altro campo? [S/n]")"
          case "$AGAIN" in
            [nN]*) [ -z "$FIELD_TOKENS" ] && FIELD_TOKENS="$TOKEN" || FIELD_TOKENS="${FIELD_TOKENS},${TOKEN}"; break ;;
            *) [ -z "$FIELD_TOKENS" ] && FIELD_TOKENS="$TOKEN" || FIELD_TOKENS="${FIELD_TOKENS},${TOKEN}" ;;
          esac
        done
        FIELDS="$FIELD_TOKENS"
      fi
    fi

    if [ "$CLASS_MODE" -eq 0 ]; then
      CANS="$(read_answer "  Tipo: [1] Record moderno (default), [2] Classe classica con Lombok")"
      if [ "$CANS" = "2" ]; then CLASS_MODE=1; fi
    fi
  fi
fi

if ! printf '%s' "$NAME" | grep -qE '^[A-Z][a-zA-Z0-9]*$'; then
  echo "Nome non valido: '$NAME'. Usa il PascalCase: Libro, DettaglioOrdine." >&2
  exit 1
fi

if printf '%s' "$NAME" | grep -qiE 'dto$'; then
  CLASS_NAME="$NAME"
else
  CLASS_NAME="${NAME}Dto"
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
if [ ! -f "$MODULE_DIR/pom.xml" ]; then
  echo "Non trovo il modulo '$SERVICE' in demo/." >&2
  exit 1
fi

BASE_PKG="$(base_package "$DEMO_DIR")"
if [ "$SERVICE" = "common-dto" ]; then
  PACKAGE="$BASE_PKG.common.dto"
else
  PACKAGE="$(base_package "$DEMO_DIR").$(printf '%s' "$SERVICE" | tr -cd 'a-zA-Z0-9').dto"
fi
PACKAGE_PATH="$(printf '%s' "$PACKAGE" | tr '.' '/')"
TARGET_DIR="$MODULE_DIR/src/main/java/$PACKAGE_PATH"
mkdir -p "$TARGET_DIR"

TARGET_FILE="$TARGET_DIR/$CLASS_NAME.java"
if [ -e "$TARGET_FILE" ]; then
  echo "C'e' gia' $TARGET_FILE. Cancellalo prima, o scegli un altro nome." >&2
  exit 1
fi

# Parsing dei campi
USES_BIGDECIMAL=0
USES_LOCALDATE=0
USES_LOCALDATETIME=0
HAS_VALIDATION=0

# Helper per PascalCase
to_pascal() {
  local s="$1"
  local first rest
  first="$(printf '%s' "$s" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  rest="$(printf '%s' "$s" | cut -c2-)"
  printf '%s%s' "$first" "$rest"
}

RECORD_PARAMS=""
CLASS_FIELDS=""

IFS=',' read -r -a FIELD_ARRAY <<< "${FIELDS:-}"
for raw in "${FIELD_ARRAY[@]}"; do
  raw="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -n "$raw" ] || continue

  IFS=':' read -r -a TOKENS <<< "$raw"
  [ "${#TOKENS[@]}" -ge 2 ] || { echo "Campo mal scritto: '$raw'. Serve almeno nome:tipo." >&2; exit 1; }

  FNAME="$(printf '%s' "${TOKENS[0]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  FTYPE_RAW="$(printf '%s' "${TOKENS[1]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  REQUIRED=0
  MIN_VAL=""
  MAX_VAL=""

  if [ "${#TOKENS[@]}" -gt 2 ]; then
    for (( i=2; i<${#TOKENS[@]}; i++ )); do
      MOD="$(printf '%s' "${TOKENS[$i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      case "$MOD" in
        required) REQUIRED=1 ;;
        min\(*\)) MIN_VAL="$(printf '%s' "$MOD" | sed -E 's/^min\((.*)\)$/\1/')" ;;
        max\(*\)) MAX_VAL="$(printf '%s' "$MOD" | sed -E 's/^max\((.*)\)$/\1/')" ;;
        unique) ;;
        *) echo "Modificatore non riconosciuto per DTO: '$MOD'" >&2; exit 1 ;;
      esac
    done
  fi

  JTYPE=""
  ENUM_NAME=""
  ENUM_VALS=""
  LENGTH=""

  case "$FTYPE_RAW" in
    string) JTYPE="String" ;;
    string\([0-9]*\))
      JTYPE="String"
      LENGTH="$(printf '%s' "$FTYPE_RAW" | sed -E 's/^string\(([0-9]+)\)$/\1/')"
      ;;
    text) JTYPE="String" ;;
    int) JTYPE="Integer" ;;
    long) JTYPE="Long" ;;
    decimal) JTYPE="BigDecimal"; USES_BIGDECIMAL=1 ;;
    bool) JTYPE="Boolean" ;;
    date) JTYPE="LocalDate"; USES_LOCALDATE=1 ;;
    datetime) JTYPE="LocalDateTime"; USES_LOCALDATETIME=1 ;;
    email) JTYPE="String" ;;
    enum\(*\))
      ENUM_VALS="$(printf '%s' "$FTYPE_RAW" | sed -E 's/^enum\((.*)\)$/\1/')"
      ENUM_NAME="$(to_pascal "$FNAME")"
      JTYPE="$ENUM_NAME"
      ;;
    *) echo "Tipo non riconosciuto per '$FNAME': '$FTYPE_RAW'" >&2; exit 1 ;;
  esac

  VALLINES=""
  if [ -n "$LENGTH" ]; then
    VALLINES="${VALLINES}@Size(max = $LENGTH) "
    HAS_VALIDATION=1
  fi
  if [ "$FTYPE_RAW" = "email" ]; then
    VALLINES="${VALLINES}@Email "
    HAS_VALIDATION=1
  fi
  if [ "$REQUIRED" -eq 1 ]; then
    HAS_VALIDATION=1
    if [ "$JTYPE" = "String" ] && [ -z "$ENUM_NAME" ]; then
      VALLINES="${VALLINES}@NotBlank "
    else
      VALLINES="${VALLINES}@NotNull "
    fi
  fi
  if [ -n "$MIN_VAL" ]; then
    VALLINES="${VALLINES}@Min($MIN_VAL) "
    HAS_VALIDATION=1
  fi
  if [ -n "$MAX_VAL" ]; then
    VALLINES="${VALLINES}@Max($MAX_VAL) "
    HAS_VALIDATION=1
  fi

  if [ -n "$ENUM_NAME" ]; then
    ENUM_FILE="$TARGET_DIR/$ENUM_NAME.java"
    if [ ! -e "$ENUM_FILE" ]; then
      ENUM_BODY="$(printf '%s' "$ENUM_VALS" | tr '|' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '[:lower:]' '[:upper:]' | paste -sd ',' - | sed 's/,/, /g')"
      cat > "$ENUM_FILE" <<EOF
package $PACKAGE;

public enum $ENUM_NAME {
    $ENUM_BODY
}
EOF
      echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/$ENUM_NAME.java"
    fi
  fi

  # Record param
  if [ -n "$RECORD_PARAMS" ]; then
    RECORD_PARAMS="${RECORD_PARAMS},"$'\n'
  fi
  RECORD_PARAMS="${RECORD_PARAMS}    ${VALLINES}${JTYPE} ${FNAME}"

  # Class field
  CLASS_FIELDS="${CLASS_FIELDS}"$'\n'"    ${VALLINES}private ${JTYPE} ${FNAME};"
done

IMPORTS=""
if [ "$HAS_VALIDATION" -eq 1 ]; then IMPORTS="${IMPORTS}import jakarta.validation.constraints.*;"$'\n'; fi
if [ "$USES_BIGDECIMAL" -eq 1 ]; then IMPORTS="${IMPORTS}import java.math.BigDecimal;"$'\n'; fi
if [ "$USES_LOCALDATE" -eq 1 ]; then IMPORTS="${IMPORTS}import java.time.LocalDate;"$'\n'; fi
if [ "$USES_LOCALDATETIME" -eq 1 ]; then IMPORTS="${IMPORTS}import java.time.LocalDateTime;"$'\n'; fi

if [ "$CLASS_MODE" -eq 1 ]; then
  cat > "$TARGET_FILE" <<EOF
package $PACKAGE;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
${IMPORTS}
/**
 * DTO per $CLASS_NAME.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class $CLASS_NAME {${CLASS_FIELDS}
}
EOF
else
  cat > "$TARGET_FILE" <<EOF
package $PACKAGE;

${IMPORTS}
/**
 * DTO immutabile per $CLASS_NAME (Java record).
 */
public record $CLASS_NAME(
$RECORD_PARAMS
) {}
EOF
fi

echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/$CLASS_NAME.java"
