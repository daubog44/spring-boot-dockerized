#!/usr/bin/env bash
# Genera un Controller Thymeleaf e una vista HTML con tabella e form per un modulo UI.
# Equivalente POSIX di scripts/new-view.ps1.
#
#   task new-view SERVICE=event-ui NAME=Libri FIELDS=titolo:string:required,autore:string,anno:int
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

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Route|--route) ROUTE="$2"; shift 2 ;;
    -Fields|--fields) FIELDS="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SERVICE" ] || [ -z "$NAME" ]; then
  if [ ! -t 0 ]; then
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
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    SERVICE="${UI_MODULES[$((IDX-1))]}"
  fi

  if [ -z "$NAME" ]; then
    printf "  Nome della Vista in PascalCase (es. Libri, Eventi, Clienti): "
    read -r NAME
    [ -n "$NAME" ] || { echo "Nome obbligatorio." >&2; exit 1; }
  fi

  if [ -z "$FIELDS" ]; then
    echo "  Campi (es. titolo:string:required,autore:string,anno:int):"
    printf "  Campi (premi Invio se nessuno): "
    read -r FIELDS
  fi
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
  if [ "${#TOKENS[@]}" -gt 1 ]; then
    FTYPE="$(printf '%s' "${TOKENS[1]}" | tr '[:upper:]' '[:lower:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  fi
  if [ "${#TOKENS[@]}" -gt 2 ]; then
    MOD="$(printf '%s' "${TOKENS[2]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ "$MOD" = "required" ]; then REQUIRED=1; fi
  elif [ "$FTYPE" = "required" ]; then
    FTYPE="string"
    REQUIRED=1
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
      VAL="        @jakarta.validation.constraints.NotBlank(message = \"$FNAME e' obbligatorio\")"$'\n'
    else
      VAL="        @jakarta.validation.constraints.NotNull"$'\n'
    fi
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
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
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
@RequestMapping("$ROUTE_PATH")
public class $CONTROLLER_NAME {

    @Getter @Setter @NoArgsConstructor
    public static class ${NAME}Form {
$FORM_FIELDS    }

    @GetMapping
    public String index(Model model) {
        List<${NAME}Form> items = new ArrayList<>();
        model.addAttribute("items", items);
        model.addAttribute("form", new ${NAME}Form());
        return "$SLUG";
    }

    @PostMapping
    public String save(@Valid @ModelAttribute("form") ${NAME}Form form,
                       BindingResult bindingResult,
                       Model model) {
        if (bindingResult.hasErrors()) {
            model.addAttribute("items", new ArrayList<${NAME}Form>());
            return "$SLUG";
        }

        return "redirect:$ROUTE_PATH?success";
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
