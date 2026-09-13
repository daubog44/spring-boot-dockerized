#!/usr/bin/env bash
# Genera un Controller Thymeleaf e una vista HTML con tabella e form per un modulo UI.
# Equivalente POSIX di scripts/new-view.ps1.
#
#   task new-view SERVICE=event-ui NAME=Libri FIELDS=titolo:string:required,autore:string,anno:int:min(1900)
#   task new-view SERVICE=event-ui NAME=Libri CLIENT=LibriClient
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE=""
NAME=""
ROUTE=""
FIELDS=""
CLIENT=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Route|--route) ROUTE="$2"; shift 2 ;;
    -Fields|--fields) FIELDS="$2"; shift 2 ;;
    -Client|--client) CLIENT="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

FIELDS_WIZARD_PENDING=0

# --- Helper read_answer: supporta WIZARD_ANSWERS per test automatici ---
read_answer() {
  local prompt="${1:-> }"
  if [ -n "${WIZARD_ANSWERS:-}" ] && [ -f "$WIZARD_ANSWERS" ]; then
    local answer
    answer="$(head -n 1 "$WIZARD_ANSWERS")"
    # Rimuovi la prima riga dal file temporaneo (usa sed in-place)
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

if [ -z "$SERVICE" ] || [ -z "$NAME" ]; then
  if [ ! -t 0 ] && [ -z "${WIZARD_ANSWERS:-}" ]; then
    echo "Uso: task new-view SERVICE=<modulo-ui> NAME=<Nome> [ROUTE=<percorso>] [FIELDS=<campi>]" >&2
    exit 1
  fi

  UI_MODULES=()
  for d in "$DEMO_DIR"/*; do
    if [ -f "$d/pom.xml" ] && grep -q 'spring-boot-starter-thymeleaf' "$d/pom.xml"; then
      UI_MODULES+=("$(basename "$d")")
    fi
  done
  if [ "${#UI_MODULES[@]}" -eq 0 ]; then
    echo "Non ci sono moduli UI (Thymeleaf) in demo/. Creane uno con task new-service NAME=<nome-ui> UI=1." >&2
    exit 1
  fi

  echo ""
  echo "CREAZIONE VISTA THYMELEAF GUIDATA"
  if [ -z "$SERVICE" ]; then
    echo "Seleziona il modulo UI:"
    for i in "${!UI_MODULES[@]}"; do
      echo "  $((i+1))) ${UI_MODULES[$i]}"
    done
    IDX="$(read_answer "  [1] >")"
    [ -n "$IDX" ] || IDX=1
    SERVICE="${UI_MODULES[$((IDX-1))]}"
  fi

  if [ -z "$NAME" ]; then
    NAME="$(read_answer "  Nome della Vista in PascalCase (es. Libri, Eventi, Clienti)")"
    [ -n "$NAME" ] || { echo "Nome obbligatorio." >&2; exit 1; }
  fi

  # FIELDS verrà chiesto DOPO il rilevamento del Feign Client (potrebbe auto-derivarli).
  [ -z "$FIELDS" ] && FIELDS_WIZARD_PENDING=1
fi


if ! printf '%s' "$NAME" | grep -qE '^[A-Z][a-zA-Z0-9]*$'; then
  echo "Nome non valido: '$NAME'. Usa il PascalCase: Libri, Eventi, Prenotazioni." >&2
  exit 1
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
[ -f "$MODULE_DIR/pom.xml" ] || { echo "Non trovo il modulo '$SERVICE' in demo/." >&2; exit 1; }

SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"
ROUTE_PATH="${ROUTE:-/$SLUG}"
if [ "${ROUTE_PATH:0:1}" != "/" ]; then ROUTE_PATH="/$ROUTE_PATH"; fi

PACKAGE="$(base_package "$DEMO_DIR").$(printf '%s' "$SERVICE" | tr -cd 'a-zA-Z0-9')"
PACKAGE_PATH="$(printf '%s' "$PACKAGE" | tr '.' '/')"
JAVA_DIR="$MODULE_DIR/src/main/java/$PACKAGE_PATH"
CONTROLLER_DIR="$JAVA_DIR/controller"
TEMPLATES_DIR="$MODULE_DIR/src/main/resources/templates"
mkdir -p "$CONTROLLER_DIR" "$TEMPLATES_DIR"

CONTROLLER_NAME="${NAME}UiController"
CONTROLLER_FILE="$CONTROLLER_DIR/$CONTROLLER_NAME.java"
TEMPLATE_FILE="$TEMPLATES_DIR/$SLUG.html"

if [ -e "$CONTROLLER_FILE" ]; then
  echo "C'e' gia' $CONTROLLER_FILE. Cancellalo prima o scegli un altro nome." >&2
  exit 1
fi
if [ -e "$TEMPLATE_FILE" ]; then
  echo "C'e' gia' $TEMPLATE_FILE. Cancellalo prima o scegli un altro nome." >&2
  exit 1
fi

to_pascal() {
  local s="$1"
  local first rest
  first="$(printf '%s' "$s" | cut -c1 | tr '[:lower:]' '[:upper:]')"
  rest="$(printf '%s' "$s" | cut -c2-)"
  printf '%s%s' "$first" "$rest"
}

to_camel() {
  local s="$1"
  local first rest
  first="$(printf '%s' "$s" | cut -c1 | tr '[:upper:]' '[:lower:]')"
  rest="$(printf '%s' "$s" | cut -c2-)"
  printf '%s%s' "$first" "$rest"
}

if [ -z "$CLIENT" ] && [ -t 0 ]; then
  CLIENT_DIR="$JAVA_DIR/client"
  if [ -d "$CLIENT_DIR" ]; then
    CLIENT_FILES=()
    for cf in "$CLIENT_DIR"/*Client.java; do
      [ -f "$cf" ] && CLIENT_FILES+=("$(basename "$cf" .java)")
    done
    if [ "${#CLIENT_FILES[@]}" -eq 1 ]; then
      CNAME="${CLIENT_FILES[0]}"
      printf "  Trovato Feign Client '%s'. Vuoi collegarlo automaticamente alla vista? [S/n] > " "$CNAME"
      read -r ANS
      case "$ANS" in
        [nN]*) ;;
        *) CLIENT="$CNAME" ;;
      esac
    elif [ "${#CLIENT_FILES[@]}" -gt 1 ]; then
      echo "  Trovati ${#CLIENT_FILES[@]} Feign Client nel modulo. Scegli quale collegare:"
      for i in "${!CLIENT_FILES[@]}"; do
        echo "    $((i+1))) ${CLIENT_FILES[$i]}"
      done
      printf "    [1] (premi Invio per primo, o 'n' per nessuno) > "
      read -r CIDX
      if printf '%s' "$CIDX" | grep -qE '^[0-9]+$'; then
        CLIENT="${CLIENT_FILES[$((CIDX-1))]}"
      elif [ "$CIDX" != "n" ]; then
        CLIENT="${CLIENT_FILES[0]}"
      fi
    fi
  fi
fi

HAS_CLIENT=0
CLIENT_INJECT=""
CLIENT_LOMBOK_IMPORT=""
CLIENT_CLASS_ANNOTATION=""
CLIENT_CALL_GET_ALL="        // Sostituisci questa lista con i dati caricati dal Feign client
        List<${NAME}Form> items = new ArrayList<>();
        model.addAttribute(\"items\", items);"
CLIENT_CALL_CREATE="        // TODO: Invia 'form' al microservizio corrispondente tramite Feign client
        // client.create(form);"
CLIENT_ERROR_CATCH="        if (bindingResult.hasErrors()) {
            model.addAttribute(\"items\", new ArrayList<${NAME}Form>());
            return \"$SLUG\";
        }"

if [ -n "$CLIENT" ]; then
  CLIENT_FILE="$JAVA_DIR/client/$CLIENT.java"
  if [ ! -f "$CLIENT_FILE" ]; then
    CANDIDATE="$(find "$JAVA_DIR/client" -name "${CLIENT}*.java" 2>/dev/null | head -n 1 || true)"
    if [ -n "$CANDIDATE" ]; then
      CLIENT_FILE="$CANDIDATE"
      CLIENT="$(basename "$CANDIDATE" .java)"
    fi
  fi

  if [ -f "$CLIENT_FILE" ]; then
    HAS_CLIENT=1
    CLIENT_CAMEL="$(to_camel "$CLIENT")"
    CLIENT_INJECT="    private final $PACKAGE.client.$CLIENT $CLIENT_CAMEL;\n"
    CLIENT_LOMBOK_IMPORT="import lombok.RequiredArgsConstructor;"
    CLIENT_CLASS_ANNOTATION=$'\n@RequiredArgsConstructor'
    CLIENT_CALL_GET_ALL="        try {
            model.addAttribute(\"items\", ${CLIENT_CAMEL}.getAll());
        } catch (Exception e) {
            model.addAttribute(\"items\", new ArrayList<>());
            model.addAttribute(\"errorMessage\", \"Impossibile recuperare i dati dal microservizio: \" + e.getMessage());
        }"
    CLIENT_ERROR_CATCH="        if (bindingResult.hasErrors()) {
            try { model.addAttribute(\"items\", ${CLIENT_CAMEL}.getAll()); } catch (Exception e) { model.addAttribute(\"items\", new ArrayList<>()); }
            return \"$SLUG\";
        }"

    TARGET_DTO_NAME="$(grep -oE 'create\s*\(\s*@RequestBody\s*([a-zA-Z0-9_]+)\s+body\)' "$CLIENT_FILE" | sed -E 's/.*@RequestBody\s*([a-zA-Z0-9_]+)\s+body\)/\1/' || true)"
    if [ -z "$TARGET_DTO_NAME" ]; then
      TARGET_DTO_NAME="$(grep -oE 'List<([a-zA-Z0-9_]+)>\s+getAll\(' "$CLIENT_FILE" | sed -E 's/.*List<([a-zA-Z0-9_]+)>\s+getAll\(/\1/' || true)"
    fi

    if [ -n "$TARGET_DTO_NAME" ] && [ "$TARGET_DTO_NAME" != "Object" ] && [ -d "$DEMO_DIR/common-dto/src/main/java" ]; then
      DTO_FILE="$(find "$DEMO_DIR/common-dto/src/main/java" -name "$TARGET_DTO_NAME.java" 2>/dev/null | head -n 1 || true)"
      if [ -n "$DTO_FILE" ] && [ -f "$DTO_FILE" ]; then
        if [ -z "${FIELDS:-}" ]; then
          AUTO_FIELDS="$(python3 -c "
with open('$DTO_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
import re
m = re.search(r'public\s+record\s+\w+\s*\(([\s\S]*?)\)\s*\{', c)
if m:
    raw_params = m.group(1).split(',')
    out = []
    for p in raw_params:
        p = p.strip()
        if not p: continue
        clean_p = re.sub(r'@\w+(\([^)]*\))?', '', p).strip()
        tokens = clean_p.split()
        if len(tokens) < 2: continue
        ptype, pname = tokens[-2].strip(), tokens[-1].strip()
        if pname == 'id': continue
        ftype = 'string'
        fmod = ':required'
        if ptype in ['int', 'Integer']: ftype = 'int'
        elif ptype in ['long', 'Long']: ftype = 'long'
        elif ptype == 'BigDecimal': ftype = 'decimal'
        elif ptype in ['boolean', 'Boolean']: ftype = 'bool'; fmod = ''
        elif ptype == 'LocalDate': ftype = 'date'
        elif ptype == 'String': ftype = 'string'
        else: ftype = 'string'; fmod = ''
        out.append(f'{pname}:{ftype}{fmod}')
    print(','.join(out))
" 2>/dev/null || true)"
          if [ -n "$AUTO_FIELDS" ]; then
            FIELDS="$AUTO_FIELDS"
            echo "  -> Campi ricavati automaticamente da $TARGET_DTO_NAME: $FIELDS"
          fi
        fi

        DTO_ARGS="$(python3 -c "
with open('$DTO_FILE', 'r', encoding='utf-8') as f:
    c = f.read()
import re
m = re.search(r'public\s+record\s+\w+\s*\(([\s\S]*?)\)\s*\{', c)
if m:
    raw_params = m.group(1).split(',')
    field_names = [r.split(':')[0].strip() for r in '${FIELDS:-}'.split(',') if r.strip()]
    args = []
    for p in raw_params:
        p = p.strip()
        if not p: continue
        clean_p = re.sub(r'@\w+(\([^)]*\))?', '', p).strip()
        tokens = clean_p.split()
        if not tokens: continue
        p_name = tokens[-1].strip()
        p_pascal = p_name[0].upper() + p_name[1:]
        if p_name == 'id':
            args.append('null')
        elif p_name in field_names:
            args.append(f'form.get{p_pascal}()')
        elif p_name in ['disponibile', 'attivo']:
            args.append('true')
        else:
            args.append('null')
    print(',\n'.join('                ' + a for a in args))
" 2>/dev/null || true)"

        if [ -n "$DTO_ARGS" ]; then
          TARGET_DTO_PKG="$(grep -E '^[[:space:]]*package[[:space:]]+' "$DTO_FILE" | sed -E 's/^[[:space:]]*package[[:space:]]+//;s/[[:space:]]*;.*$//' | head -1 || true)"
          [ -z "$TARGET_DTO_PKG" ] && TARGET_DTO_PKG="$(get_base_package).common.dto"
          CLIENT_CALL_CREATE="        try {
            ${CLIENT_CAMEL}.create(new ${TARGET_DTO_PKG}.$TARGET_DTO_NAME(
$DTO_ARGS
            ));
        } catch (Exception e) {
            model.addAttribute(\"errorMessage\", \"Errore nel salvataggio: \" + e.getMessage());
            try { model.addAttribute(\"items\", ${CLIENT_CAMEL}.getAll()); } catch (Exception ex) { model.addAttribute(\"items\", new ArrayList<>()); }
            return \"$SLUG\";
        }"
        fi
      fi
    fi
  fi
fi

# --- Wizard interattivo per i campi (se non sono stati specificati / auto-derivati) ---
if [ "$FIELDS_WIZARD_PENDING" -eq 1 ] && [ -z "${FIELDS:-}" ]; then
  echo ""
  echo "  Come vuoi definire i campi del form e della tabella?"
  echo "    1) guidato, un campo alla volta (tipo e modificatori da menu)"
  echo "    2) tutti insieme, in una riga (come FIELDS=... da riga di comando)"
  FIELD_MODE="$(read_answer "  Modalita' [1]")"
  if [ "$FIELD_MODE" = "2" ]; then
    echo "  Esempio: titolo:string:required,autore:string,anno:int:min(1900)"
    FIELDS="$(read_answer "  Campi")"
  else
    FIELD_TOKENS=""
    while true; do
      FNAME="$(read_answer "  Nome campo (Invio per finire)")"
      [ -n "$FNAME" ] || break

      echo "    1) string      4) long       7) date"
      echo "    2) string(N)   5) decimal    8) enum(A|B|C)"
      echo "    3) int         6) bool"
      TYPE_CHOICE="$(read_answer "    Tipo [1]")"
      case "$TYPE_CHOICE" in
        2) SLEN="$(read_answer "    Lunghezza massima")"; TYPE_TOKEN="string($SLEN)" ;;
        3) TYPE_TOKEN="int" ;;
        4) TYPE_TOKEN="long" ;;
        5) TYPE_TOKEN="decimal" ;;
        6) TYPE_TOKEN="bool" ;;
        7) TYPE_TOKEN="date" ;;
        8) EVALS="$(read_answer "    Valori separati da | (es. ROSSO|VERDE|BLU)")"; TYPE_TOKEN="enum($EVALS)" ;;
        *) TYPE_TOKEN="string" ;;
      esac

      echo "    Modificatori, numeri separati da virgola (Invio per nessuno):"
      echo "      1) required   2) min(N)   3) max(N)   4) unique"
      MOD_CHOICE="$(read_answer "    Modificatori")"
      MODS=""
      if [ -n "$MOD_CHOICE" ]; then
        OLD_IFS="$IFS"; IFS=','
        for m in $MOD_CHOICE; do
          m="${m// /}"
          case "$m" in
            1) MODS="${MODS}:required" ;;
            2) MV="$(read_answer "      Minimo")"; MODS="${MODS}:min($MV)" ;;
            3) MV="$(read_answer "      Massimo")"; MODS="${MODS}:max($MV)" ;;
            4) MODS="${MODS}:unique" ;;
          esac
        done
        IFS="$OLD_IFS"
      fi

      TOKEN="${FNAME}:${TYPE_TOKEN}${MODS}"
      echo "    -> $TOKEN"
      echo ""
      [ -z "$FIELD_TOKENS" ] && FIELD_TOKENS="$TOKEN" || FIELD_TOKENS="${FIELD_TOKENS},${TOKEN}"
    done
    FIELDS="$FIELD_TOKENS"
  fi
fi

# Parsing campi
FORM_FIELDS=""
TH_HEADERS=""
TH_CELLS=""
FORM_INPUTS=""

IFS=',' read -r -a FIELD_ARRAY <<< "${FIELDS:-}"
if [ "${#FIELD_ARRAY[@]}" -eq 0 ] || [ -z "${FIELDS:-}" ]; then
  FIELD_ARRAY=("nome:string:required" "descrizione:string")
fi

for raw in "${FIELD_ARRAY[@]}"; do
  raw="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -n "$raw" ] || continue

  IFS=':' read -r -a TOKENS <<< "$raw"
  FNAME="$(printf '%s' "${TOKENS[0]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  FTYPE="string"
  REQUIRED=0
  MIN_VAL=""
  MAX_VAL=""
  if [ "${#TOKENS[@]}" -gt 1 ]; then
    FTYPE="$(printf '%s' "${TOKENS[1]}" | tr '[:upper:]' '[:lower:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  fi
  if [ "${#TOKENS[@]}" -eq 2 ] && [ "$FTYPE" = "required" ]; then
    FTYPE="string"
    REQUIRED=1
  fi
  if [ "${#TOKENS[@]}" -gt 2 ]; then
    for (( ti=2; ti<${#TOKENS[@]}; ti++ )); do
      MOD="$(printf '%s' "${TOKENS[$ti]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [ "$MOD" = "required" ]; then REQUIRED=1; fi
      if [[ "$MOD" =~ ^min\(([0-9]+)\)$ ]]; then MIN_VAL="${BASH_REMATCH[1]}"; fi
      if [[ "$MOD" =~ ^max\(([0-9]+)\)$ ]]; then MAX_VAL="${BASH_REMATCH[1]}"; fi
    done
  fi

  JTYPE="String"
  HTML_INPUT="text"
  case "$FTYPE" in
    int) JTYPE="Integer"; HTML_INPUT="number" ;;
    long) JTYPE="Long"; HTML_INPUT="number" ;;
    decimal) JTYPE="java.math.BigDecimal"; HTML_INPUT="number" ;;
    bool) JTYPE="Boolean"; HTML_INPUT="checkbox" ;;
    date) JTYPE="java.time.LocalDate"; HTML_INPUT="date" ;;
    email) JTYPE="String"; HTML_INPUT="email" ;;
  esac

  LABEL="$(to_pascal "$FNAME")"

  VAL=""
  if [ "$REQUIRED" -eq 1 ]; then
    if [ "$JTYPE" = "String" ]; then
      VAL="        @NotBlank(message = \"$FNAME e' obbligatorio\")"$'\n'
    else
      VAL="        @NotNull"$'\n'
    fi
  fi
  if [ -n "$MIN_VAL" ]; then
    VAL="${VAL}        @Min($MIN_VAL)"$'\n'
  fi
  if [ -n "$MAX_VAL" ]; then
    VAL="${VAL}        @Max($MAX_VAL)"$'\n'
  fi
  FORM_FIELDS="${FORM_FIELDS}${VAL}        private ${JTYPE} ${FNAME};"$'\n'

  TH_HEADERS="${TH_HEADERS}                    <th>${LABEL}</th>"$'\n'
  TH_CELLS="${TH_CELLS}                    <td th:text=\"\${item.${FNAME}}\">Valore</td>"$'\n'

  if [ "$HTML_INPUT" = "checkbox" ]; then
    FORM_INPUTS="${FORM_INPUTS}
            <div class=\"form-group-check\">
                <label>
                    <input type=\"checkbox\" th:field=\"*{${FNAME}}\" />
                    <span>${LABEL}</span>
                </label>
            </div>"
  else
    FORM_INPUTS="${FORM_INPUTS}
            <div class=\"form-group\">
                <label for=\"${FNAME}\">${LABEL}</label>
                <input id=\"${FNAME}\" type=\"${HTML_INPUT}\" th:field=\"*{${FNAME}}\" class=\"form-control\" />
                <span class=\"error-msg\" th:if=\"\${#fields.hasErrors('${FNAME}')}\" th:errors=\"*{${FNAME}}\">Errore</span>
            </div>"
  fi
done

cat > "$CONTROLLER_FILE" <<EOF
package $PACKAGE.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
${CLIENT_LOMBOK_IMPORT}
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

/**
 * Controller Thymeleaf per la vista $NAME ($ROUTE_PATH).
 * Generato da task new-view.
 */
@Controller
@RequestMapping("$ROUTE_PATH")${CLIENT_CLASS_ANNOTATION}
public class $CONTROLLER_NAME {

$CLIENT_INJECT
    @Getter @Setter @NoArgsConstructor
    public static class ${NAME}Form {
$FORM_FIELDS    }

    @GetMapping
    public String index(Model model) {
$CLIENT_CALL_GET_ALL
        model.addAttribute("form", new ${NAME}Form());
        return "$SLUG";
    }

    @PostMapping
    public String save(@Valid @ModelAttribute("form") ${NAME}Form form,
                       BindingResult bindingResult,
                       Model model) {
$CLIENT_ERROR_CATCH
$CLIENT_CALL_CREATE
        return "redirect:${ROUTE_PATH}?success";
    }
}
EOF
echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/controller/$CONTROLLER_NAME.java"

cat > "$TEMPLATE_FILE" <<EOF
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestione $NAME</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 2rem; }
        .container { max-width: 900px; margin: 0 auto; }
        .card { background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem; margin-bottom: 2rem; }
        h1, h2 { margin-top: 0; color: #0f172a; }
        table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
        th, td { padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #e2e8f0; }
        th { background: #f1f5f9; font-weight: 600; }
        .form-group { margin-bottom: 1rem; }
        .form-group label { display: block; font-weight: 500; margin-bottom: 0.25rem; }
        .form-control { width: 100%; box-sizing: border-box; padding: 0.5rem 0.75rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 1rem; }
        .error-msg { color: #dc2626; font-size: 0.875rem; margin-top: 0.25rem; display: block; }
        .alert-success { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem; }
        .btn { background: #2563eb; color: white; border: none; padding: 0.6rem 1.25rem; border-radius: 6px; cursor: pointer; font-size: 1rem; font-weight: 500; }
        .btn:hover { background: #1d4ed8; }
        .empty-state { text-align: center; color: #64748b; padding: 2rem 0; }
    </style>
</head>
<body>
<div class="container">
    <div class="card">
        <h1>Gestione $NAME</h1>
        <p>Interfaccia generata da <code>task new-view</code>. Collega i dati al Feign Client per visualizzare i record reali.</p>

        <div th:if="\${param.success}" class="alert-success">
            Operazione completata con successo!
        </div>

        <div th:if="\${errorMessage}" style="background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem;">
            <span th:text="\${errorMessage}">Messaggio errore</span>
        </div>

        <h2>Elenco</h2>
        <div th:if="\${items != null and !items.isEmpty()}">
            <table>
                <thead>
                <tr>
$TH_HEADERS                </tr>
                </thead>
                <tbody>
                <tr th:each="item : \${items}">
$TH_CELLS                </tr>
                </tbody>
            </table>
        </div>
        <div th:if="\${items == null or items.isEmpty()}" class="empty-state">
            Nessun elemento presente.
        </div>
    </div>

    <div class="card">
        <h2>Nuovo Elemento</h2>
        <form th:action="@{$ROUTE_PATH}" th:object="\${form}" method="post">
$FORM_INPUTS
            <button type="submit" class="btn">Salva</button>
        </form>
    </div>
</div>
</body>
</html>
EOF
echo "  demo/$SERVICE/src/main/resources/templates/$SLUG.html"
