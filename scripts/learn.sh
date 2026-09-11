#!/usr/bin/env bash
# Prepara il corso e lo apre nel browser.
# Equivalente POSIX di scripts/learn.ps1.
#
# Il corso e' una pagina statica, corso/index.html: si apre col doppio clic,
# senza server e senza rete. Il testo sta nei file Markdown (le lezioni in
# corso/lezioni/ e le guide del progetto), che un browser, da un file aperto
# col doppio clic, non puo' leggere: questo script li raccoglie in
# corso/contenuti.js, con una fotografia del progetto, e apre la pagina.
#
#   task learn
#   task learn OPEN=0      solo contenuti.js, senza aprire il browser
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/scaffold-lib.sh"

NO_OPEN=0
while [ $# -gt 0 ]; do
  case "$1" in
    -NoOpen|--no-open) NO_OPEN=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

CORSO="$REPO_ROOT/corso"
INDEX="$CORSO/index.html"
OUT="$CORSO/contenuti.js"
[ -f "$INDEX" ] || { echo "Non trovo $INDEX." >&2; exit 1; }

# Un file dentro un template literal di JavaScript (`...`): vanno protetti la
# barra rovesciata, l'apice inverso e ${, che JavaScript leggerebbe come codice.
js_template() {
  printf '`'
  tr -d '\r' <"$1" | sed -e 's/\\/\\\\/g' -e 's/`/\\`/g' -e 's/\${/\\${/g'
  printf '`'
}
# Una stringa corta fra apici: nomi di moduli, porte, classi.
js_string() { printf "'%s'" "$(printf '%s' "$1" | sed -e "s/\\\\/\\\\\\\\/g" -e "s/'/\\\\'/g")"; }
js_list() { # parole separate da spazi -> 'a', 'b'
  local first=1 w
  for w in $1; do
    [ "$first" -eq 1 ] || printf ', '
    js_string "$w"; first=0
  done
}

# --- La fotografia del progetto ------------------------------------------------

DEMO_DIR="$REPO_ROOT/demo"
AGG="$(basename "$DEMO_DIR")"
MODULES="$(sed -n 's:.*<module>\([^<]*\)</module>.*:\1:p' "$DEMO_DIR/pom.xml")"
JAVA_VERSION="$(sed -n 's:.*<java.version>\([^<]*\)</java.version>.*:\1:p' "$DEMO_DIR/pom.xml" | head -n 1)"

module_rows() {
  local first=1 m dir yml port name kind db entities feign classes
  for m in $MODULES; do
    dir="$DEMO_DIR/$m"
    yml="$dir/src/main/resources/application.yml"
    port=""; name=""; db=""
    if [ -f "$yml" ]; then
      port="$(grep -oE 'SERVER_PORT:[0-9]+' "$yml" | head -n 1 | cut -d: -f2)"
      name="$(grep -E '^[[:space:]]+name:' "$yml" | head -n 1 | sed 's/.*name:[[:space:]]*//' | tr -d '\r ')"
      if grep -q 'jdbc:postgresql://' "$yml"; then
        db="PostgreSQL $(grep -oE 'jdbc:postgresql://[^/]+/[A-Za-z0-9_]+' "$yml" | head -n 1 | sed 's:.*/::')"
      elif grep -q 'jdbc:h2' "$yml"; then
        db="H2 in memoria"
      fi
    fi
    if grep -q 'eureka-server' "$dir/pom.xml" 2>/dev/null; then kind="eureka"
    elif [ ! -f "$yml" ]; then kind="libreria"
    elif [ -d "$dir/src/main/resources/templates" ]; then kind="ui"
    else kind="rest"; fi
    sources="$(find "$dir/src/main/java" -name '*.java' 2>/dev/null | grep -v '/devdata/' | sort)"
    entities=""; feign=""; classes=""
    for f in $sources; do
      base="$(basename "$f" .java)"
      grep -qE '^@Entity' "$f" && entities="$entities $base"
      # Chi chiama: il nome Eureka scritto in @FeignClient(name = "...").
      for n in $(grep -oE '@FeignClient\([^)]*"[^"]+"' "$f" | sed -E 's/.*"([^"]+)".*/\1/'); do
        case " $feign " in *" $n "*) ;; *) feign="$feign $n" ;; esac
      done
      [ "$kind" = "libreria" ] && [ "$base" != "package-info" ] && classes="$classes $base"
    done
    [ "$first" -eq 1 ] || printf ',\n'
    printf '    { nome: %s, tipo: %s, porta: %s, applicazione: %s, database: %s, entity: [%s], feign: [%s], classi: [%s] }' \
      "$(js_string "$m")" "$(js_string "$kind")" "$(js_string "$port")" "$(js_string "$name")" "$(js_string "$db")" \
      "$(js_list "$entities")" "$(js_list "$feign")" "$(js_list "$classes")"
    first=0
  done
  printf '\n'
}

# Prima il README e la procedura del giorno, poi le altre guide in ordine.
docs() {
  local f
  for f in README.md GIORNO-ESAME.md; do [ -f "$REPO_ROOT/$f" ] && printf '%s\n' "$f"; done
  for f in "$REPO_ROOT"/*.md; do
    f="$(basename "$f")"
    case "$f" in README.md|GIORNO-ESAME.md) ;; *) printf '%s\n' "$f" ;; esac
  done
}

entries() { # cartella, prefisso, elenco di file
  local dir="$1" prefix="$2" first=1 f
  shift 2
  for f in "$@"; do
    [ "$first" -eq 1 ] || printf ',\n'
    printf '    { file: %s, testo: ' "$(js_string "$prefix$f")"
    js_template "$dir/$f"
    printf ' }'
    first=0
  done
  printf '\n'
}

LESSONS=()
if [ -d "$CORSO/lezioni" ]; then
  while IFS= read -r f; do LESSONS+=("$f"); done < <(cd "$CORSO/lezioni" && ls -1 *.md 2>/dev/null | LC_ALL=C sort)
fi
DOCS=()
while IFS= read -r f; do DOCS+=("$f"); done < <(docs)

{
  echo "// Generato da task learn: non modificarlo, rilancia il comando."
  echo "window.CORSO = {"
  echo "  generato: $(js_string "$(date '+%Y-%m-%d %H:%M')"),"
  echo "  progetto: {"
  echo "    cartella: $(js_string "$AGG"),"
  echo "    pacchetto: $(js_string "$(base_package "$DEMO_DIR")"),"
  echo "    java: $(js_string "$JAVA_VERSION"),"
  echo "    moduli: ["
  module_rows
  echo "    ]"
  echo "  },"
  echo "  lezioni: ["
  if [ "${#LESSONS[@]}" -gt 0 ]; then entries "$CORSO/lezioni" "corso/lezioni/" "${LESSONS[@]}"; else echo ""; fi
  echo "  ],"
  echo "  documenti: ["
  entries "$REPO_ROOT" "" "${DOCS[@]}"
  echo "  ],"
  echo "};"
} >"$OUT"

echo ""
echo "Il corso e' pronto."
echo "  ${#LESSONS[@]} lezioni, ${#DOCS[@]} guide, $(printf '%s\n' $MODULES | wc -l | tr -d ' ') moduli del progetto"
echo "  $INDEX"
echo ""
if [ "$NO_OPEN" -eq 0 ]; then
  if command -v cygpath >/dev/null 2>&1 && command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe //c start "" "$(cygpath -w "$INDEX")" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$INDEX" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$INDEX"
  else
    echo "  Aprilo tu nel browser: non so come farlo da qui."
    exit 0
  fi
  echo "  Aperto nel browser. Si apre anche col doppio clic sul file."
  echo ""
fi
exit 0
