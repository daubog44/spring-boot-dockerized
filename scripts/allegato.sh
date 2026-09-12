#!/usr/bin/env bash
# Genera o aggiorna allegato.md e compila l'anteprima di ALLEGATO-TECNICO.md.
# Equivalente POSIX di scripts/allegato.ps1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

REPO_ROOT="$(get_scaffold_repo_root)"
DEMO_DIR="$REPO_ROOT/demo"
DEV_SH="$SCRIPT_DIR/dev.sh"
DEV_PS1="$SCRIPT_DIR/dev.ps1"
ALLEGATO_FILE="$REPO_ROOT/allegato.md"

NOME="CANDIDATO"
OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    -Nome|--nome|NOME=*|nome=*)
      if [[ "$1" == *"="* ]]; then NOME="${1#*=}"; shift; else NOME="$2"; shift 2; fi ;;
    -OutDir|--out-dir|OUTDIR=*|outdir=*)
      if [[ "$1" == *"="* ]]; then OUT_DIR="${1#*=}"; shift; else OUT_DIR="$2"; shift 2; fi ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

[ -n "$OUT_DIR" ] || OUT_DIR="$REPO_ROOT"

echo ""
echo -e "\033[36m==> Generazione e verifica Allegato Tecnico\033[0m"

# --- 1. Rilevazione Moduli e Servizi -----------------------------------------

UI_PORT="$(grep -oE '\[int\]\$UiPort = [0-9]+' "$DEV_PS1" 2>/dev/null | grep -oE '[0-9]+' || echo 8080)"
SERVICES="$(grep -oE "Name = '[^']+'; +Module = '[^']+'; +Port = (\\\$UiPort|[0-9]+)" "$DEV_PS1" 2>/dev/null |
  sed -E "s/Name = '([^']+)'; +Module = '([^']+)'; +Port = (.*)/\1 \2 \3/" |
  sed "s/\\\$UiPort/$UI_PORT/" || true)"

# Fallback se dev.ps1 non ha servizi ma dev.sh sì
if [ -z "$SERVICES" ] && [ -f "$DEV_SH" ]; then
  SERVICES="$(grep -oE '"[^"]+:[^"]+:[0-9]+"' "$DEV_SH" 2>/dev/null | tr -d '"' | tr ':' ' ' || true)"
fi

app_name() { # modulo
  local mod_dir="$DEMO_DIR/$1"
  local cfg
  cfg="$(module_config_file "$mod_dir")"
  [ -n "$cfg" ] && [ -f "$cfg" ] || { printf '%s' "$1" | tr 'a-z' 'A-Z'; return 0; }
  local name
  name="$(awk '
    /^[[:space:]]*application:[[:space:]]*$/ { in_app=1; next }
    in_app && /^[[:space:]]+name:[[:space:]]*/ { sub(/^[[:space:]]+name:[[:space:]]*/, ""); print; exit }
    in_app && /^[^[:space:]]/ { in_app=0 }
    /^[[:space:]]*spring\.application\.name[[:space:]]*[:=][[:space:]]*/ {
      sub(/^[[:space:]]*spring\.application\.name[[:space:]]*[:=][[:space:]]*/, ""); print; exit
    }
  ' "$cfg" | tr -d '\r')"
  if [ -n "$name" ]; then echo "$name"; else printf '%s' "$1" | tr 'a-z' 'A-Z'; fi
}

endpoints() { # modulo
  local src="$DEMO_DIR/$1/src/main/java"
  [ -d "$src" ] || return 0
  grep -rl -E '@(Rest)?Controller' "$src" --include='*.java' 2>/dev/null | while read -r file; do
    base="$(grep -oE '@RequestMapping\([[:space:]]*(value[[:space:]]*=[[:space:]]*|path[[:space:]]*=[[:space:]]*)?"[^"]*"' "$file" | head -n 1 | sed -E 's/.*"([^"]*)"/\1/' || true)"
    grep -oE '@(Get|Post|Put|Delete|Patch)Mapping(\([[:space:]]*(value[[:space:]]*=[[:space:]]*|path[[:space:]]*=[[:space:]]*)?"?[^"\)]*"?\))?' "$file" 2>/dev/null |
      while read -r mapping; do
        verb="$(printf '%s' "$mapping" | sed -E 's/@([A-Za-z]+)Mapping.*/\1/' | tr 'a-z' 'A-Z')"
        path="$(printf '%s' "$mapping" | sed -E 's/.*"([^"]*)".*/\1/' || true)"
        [ "$path" = "$mapping" ] && path=""
        base_clean="${base%/}"
        path_clean=""
        if [ -n "$path" ]; then
          case "$path" in
            /*) path_clean="$path" ;;
            *) path_clean="/$path" ;;
          esac
        fi
        full="$base_clean$path_clean"
        [ -z "$full" ] && full="/"
        echo "$verb $full"
      done
  done | sort -u || true
  return 0
}

role() { # modulo
  case "$1" in
    *naming-server*) echo "Eureka Naming Server (Discovery)" ;;
    *-ui|ui) echo "Interfaccia Web (Spring MVC / Thymeleaf)" ;;
    *) echo "Microservizio REST (Business Logic / DB)" ;;
  esac
}

# --- 2. Sincronizzazione allegato.md ------------------------------------------

HINT_ANALISI="[Descrivi brevemente il contesto, il problema e gli obiettivi del progetto.]"
HINT_ALGORITMO="[Descrivi la logica algoritmica implementata (es. selezione slot, verifica disponibilità), con passaggi e complessità temporale.]"
HINT_MODULO="[Descrivi il ruolo di questo modulo, le dipendenze e le scelte implementative.]"
HINT_DOMANDA="[Inserisci qui la tua risposta alla domanda teorica.]"

if [ ! -f "$ALLEGATO_FILE" ]; then
  {
    echo "# Allegato tecnico: le parti scritte da te"
    echo ""
    echo "task allegato e task consegna prendono ogni sezione di questo file e la inseriscono"
    echo "in ALLEGATO-TECNICO.md, accanto a quanto ricavato in automatico dal codice"
    echo "(moduli, porte, endpoint, schema del database)."
    echo ""
    printf '## Analisi\n\n%s\n\n## Algoritmo\n\n%s\n\n' "$HINT_ANALISI" "$HINT_ALGORITMO"
    while read -r name module port; do
      [ -z "$module" ] && continue
      printf '## %s\n\n%s\n\n' "$module" "$HINT_MODULO"
    done <<<"$SERVICES"
    printf '## Domanda A\n\n%s\n\n## Domanda B\n\n%s\n' "$HINT_DOMANDA" "$HINT_DOMANDA"
  } >"$ALLEGATO_FILE"
  echo "  creato $ALLEGATO_FILE"
fi

part_text() { # titolo
  local text
  text="$(awk -v want="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '
    /^##[ \t]+/ { t = $0; sub(/^##[ \t]+/, "", t); gsub(/`/, "", t); sub(/[ \t\r]+$/, "", t); cur = tolower(t); next }
    cur == want { sub(/\r$/, ""); buf[n++] = $0 }
    END {
      s = 0; while (s < n && buf[s] ~ /^[ \t]*$/) s++
      e = n - 1; while (e >= s && buf[e] ~ /^[ \t]*$/) e--
      for (i = s; i <= e; i++) print buf[i]
    }' "$ALLEGATO_FILE")"
  case "$text" in "["*) ;; *) printf '%s' "$text" ;; esac
}

has_part() { grep -qiE "^##[[:space:]]+\`?$1\`?[[:space:]]*\$" "$ALLEGATO_FILE"; }

# Aggiunta moduli mancanti
ADDED=""
while read -r name module port; do
  [ -z "$module" ] && continue
  if ! has_part "$module"; then
    printf '\n## %s\n\n%s\n' "$module" "$HINT_MODULO" >>"$ALLEGATO_FILE"
    ADDED="$ADDED $module"
  fi
done <<<"$SERVICES"
if [ -n "$ADDED" ]; then echo "  allegato.md: aggiunta la sezione per$ADDED"; fi

MISSING=""
part_or_hint() { # titolo, suggerimento
  local text
  text="$(part_text "$1")"
  if [ -n "$text" ]; then
    printf '%s\n' "$text"
  else
    printf '%s\n' "$2"
    if [ -n "$MISSING" ]; then MISSING="$MISSING, $1"; else MISSING="$1"; fi
  fi
}

# --- 3. Generazione Schema DB -------------------------------------------------

SCHEMA_TEXT=""
if [ -f "$SCRIPT_DIR/db-schema.sh" ]; then
  SCHEMA_TEXT="$(bash "$SCRIPT_DIR/db-schema.sh" 2>/dev/null || echo "Nessuna entità persistente rilevata.")"
fi
[ -n "$SCHEMA_TEXT" ] || SCHEMA_TEXT="Nessuna entità persistente rilevata."

echo "$SCHEMA_TEXT" > "$OUT_DIR/SCHEMA-DATABASE.md"
echo "  generato SCHEMA-DATABASE.md"

# --- 4. Compilazione ALLEGATO-TECNICO.md --------------------------------------

TODAY="$(date +'%d/%m/%Y')"
DOC_OUT="$OUT_DIR/ALLEGATO-TECNICO.md"

{
  echo "# Allegato Tecnico di Progetto"
  echo ""
  echo "Candidato: **$NOME**  "
  echo "Data: $TODAY  "
  echo ""
  echo "---"
  echo ""
  echo "## 1. Analisi del problema e contesto applicativo"
  echo ""
  part_or_hint "Analisi" "$HINT_ANALISI"
  echo ""
  echo "## 2. Architettura della soluzione e ripartizione moduli"
  echo ""
  echo "Architettura a microservizi Spring Boot, con service discovery Netflix Eureka e"
  echo "chiamate inter-servizio tramite OpenFeign risolte per nome logico. Ogni microservizio"
  echo "espone i propri contratti REST documentati tramite OpenAPI / Swagger UI."
  echo ""
  echo "| Modulo | Porta | Nome Eureka | Ruolo Architetturale |"
  echo "| :--- | :---: | :--- | :--- |"
  while read -r name module port; do
    [ -z "$module" ] && continue
    echo "| \`$module\` | $port | \`$(app_name "$module")\` | $(role "$module") |"
  done <<<"$SERVICES"
  echo ""
  echo "Il modulo \`common-dto\` contiene classi record/DTO condivise per garantire coerenza nei contratti di comunicazione."
  echo ""
  echo "## 3. Schema concettuale e logico della base dati"
  echo ""
  printf '%s\n' "$SCHEMA_TEXT" | sed '/^# /d; s/^#/##/'
  echo ""
  echo "## 4. Descrizione dei singoli moduli implementati"
  echo ""
  while read -r name module port; do
    [ -z "$module" ] && continue
    echo "### Modulo \`$module\` (Porta $port)"
    echo ""
    eps="$(endpoints "$module" || true)"
    if [ -n "$eps" ]; then
      echo "Endpoint REST esposti:"
      echo ""
      printf '%s\n' "$eps" | sed 's/^/- `/; s/$/`/'
      echo ""
      echo "Documentazione OpenAPI / Swagger: \`http://localhost:$port/swagger-ui.html\`"
    else
      echo "Nessun endpoint REST esposto direttamente (servizio infrastrutturale o interfaccia web)."
    fi
    echo ""
    part_or_hint "$module" "$HINT_MODULO"
    echo ""
  done <<<"$SERVICES"
  echo "## 5. Descrizione dell'algoritmo e complessità"
  echo ""
  part_or_hint "Algoritmo" "$HINT_ALGORITMO"
  echo ""
  echo "## 6. Istruzioni per l'esecuzione e il collaudo"
  echo ""
  echo "### Avvio con Docker Compose"
  echo '```bash'
  echo "docker compose up -d --build"
  echo '```'
  echo ""
  echo "### Porte e Dashboard di riferimento"
  while read -r name module port; do
    [ -z "$module" ] && continue
    case "$module" in
      *naming-server*) echo "- Dashboard Eureka: \`http://localhost:$port\`" ;;
      *-ui|ui) echo "- Interfaccia Web: \`http://localhost:$port\`" ;;
      *) echo "- Swagger UI \`$module\`: \`http://localhost:$port/swagger-ui.html\`" ;;
    esac
  done <<<"$SERVICES"
  echo ""
  qa="$(part_text 'Domanda A')"
  qb="$(part_text 'Domanda B')"
  if [ -n "$qa$qb" ]; then
    echo "---"
    echo ""
    echo "## 7. Risposte alle Domande Teoriche"
    echo ""
    if [ -n "$qa" ]; then printf '### Domanda A\n\n%s\n\n' "$qa"; fi
    if [ -n "$qb" ]; then printf '### Domanda B\n\n%s\n\n' "$qb"; fi
  fi
} >"$DOC_OUT"

echo "  compilato ALLEGATO-TECNICO.md"

# --- 5. Riepilogo e Controllo Completezza -------------------------------------

echo ""
if [ -z "$MISSING" ]; then
  echo -e "\033[32mSTATO: Allegato Tecnico COMPLETO al 100%! Pronto per la consegna.\033[0m"
else
  echo -e "\033[33mSTATO: Allegato Tecnico compilato con sezioni ANCORA DA COMPLETARE in allegato.md:\033[0m"
  IFS=',' read -ra ADDR <<<"$MISSING"
  for i in "${ADDR[@]}"; do
    sec="$(printf '%s' "$i" | sed 's/^[[:space:]]*//')"
    [ -n "$sec" ] && echo -e "\033[33m  - [DA COMPILARE] $sec\033[0m"
  done
  echo ""
  echo -e "\033[36mApri 'allegato.md', scrivi i testi sotto i titoli indicati e rilancia 'task allegato'.\033[0m"
fi
echo ""
