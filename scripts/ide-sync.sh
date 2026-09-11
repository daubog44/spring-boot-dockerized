#!/usr/bin/env bash
# Riallinea la configurazione degli editor (VS Code, Zed) ai moduli veri.
# Equivalente POSIX di scripts/ide-sync.ps1.
#
# Riscrive .vscode/launch.json, .vscode/tasks.json e .zed/tasks.json; crea, solo
# se mancano, i file che non dipendono dai moduli.
#
#   task ide-sync
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# La cartella dell'aggregatore Maven (quella che di solito si chiama demo).
aggregator_name() {
  local name dir
  if [ -f "$REPO_ROOT/Taskfile.yml" ]; then
    name="$(grep -oE "^[[:space:]]*dir:[[:space:]]*'?[A-Za-z0-9_.-]+'?[[:space:]]*$" "$REPO_ROOT/Taskfile.yml" | head -n 1 | sed -E "s/^[[:space:]]*dir:[[:space:]]*'?//; s/'?[[:space:]]*$//")"
    if [ -n "$name" ] && [ -f "$REPO_ROOT/$name/pom.xml" ]; then
      echo "$name"; return 0
    fi
  fi
  for dir in "$REPO_ROOT"/*/; do
    [ "$(basename "${dir%/}")" = "consegna" ] && continue
    if [ -f "$dir/pom.xml" ] && [ -f "$dir/docker-compose.yml" ]; then
      basename "${dir%/}"; return 0
    fi
  done
  echo "Non trovo la cartella dell'aggregatore sotto $REPO_ROOT." >&2
  return 1
}

DEMO_NAME="$(aggregator_name)" || exit 1
DEMO_DIR="$REPO_ROOT/$DEMO_NAME"
VSCODE_DIR="$REPO_ROOT/.vscode"
ZED_DIR="$REPO_ROOT/.zed"
mkdir -p "$VSCODE_DIR" "$ZED_DIR"

# --- I moduli veri, con la loro classe Main e la loro porta ------------------

TARGETS="$(mktemp)"
trap 'rm -f "$TARGETS"' EXIT

for module in $(sed -n 's/.*<module>\(.*\)<\/module>.*/\1/p' "$DEMO_DIR/pom.xml"); do
  src="$DEMO_DIR/$module/src/main/java"
  [ -d "$src" ] || continue

  # La classe Main la cerchiamo nei sorgenti invece di dedurla dal nome: cosi'
  # funziona anche per un modulo scritto a mano.
  main_file="$(grep -rl '@SpringBootApplication' "$src" --include='*.java' 2>/dev/null | head -n 1)"
  # Una libreria (common-dto) non si avvia: niente Main, niente voce.
  [ -n "$main_file" ] || continue
  pkg="$(sed -n 's/^[[:space:]]*package[[:space:]]\+\([A-Za-z0-9_.]*\)[[:space:]]*;.*/\1/p' "$main_file" | head -n 1)"
  cls="$(basename "$main_file" .java)"
  if [ -n "$pkg" ]; then main_class="$pkg.$cls"; else main_class="$cls"; fi

  port=""
  yml="$DEMO_DIR/$module/src/main/resources/application.yml"
  [ -f "$yml" ] && port="$(grep -oE 'SERVER_PORT:[0-9]+' "$yml" | head -n 1 | cut -d: -f2)"

  # Eureka per primo: e' l'ordine in cui vanno accesi.
  if [ "$module" = "naming-server" ]; then rank=0; else rank=1; fi
  printf '%s|%s|%s|%s\n' "$rank" "$module" "$main_class" "$port" >>"$TARGETS"
done

sort -t'|' -k1,1n -k2,2 "$TARGETS" -o "$TARGETS"
# grep -c esce con 1 quando non trova niente: senza il || il conteggio
# resterebbe vuoto, e il confronto numerico piu' sotto protesterebbe.
COUNT="$(grep -c '.' "$TARGETS" 2>/dev/null)" || COUNT=0

echo ""
echo "==> Configurazione degli editor"
echo ""

# --- .vscode/launch.json ------------------------------------------------------

{
  echo '// Generato da `task ide-sync`: lo riscrivono new-service, remove-service'
  echo '// e set-port. Le modifiche a mano si perdono al prossimo comando.'
  echo '{'
  echo '    "version": "0.2.0",'
  if [ "$COUNT" -eq 0 ]; then
    echo '    "configurations": []'
  else
    echo '    "configurations": ['
    i=0
    while IFS='|' read -r rank module main_class port; do
      [ -z "$module" ] && continue
      i=$(( i + 1 ))
      [ "$i" -gt 1 ] && echo '        },'
      if [ -n "$port" ]; then label="$i. $module (:$port)"; else label="$i. $module"; fi
      echo '        {'
      echo '            "type": "java",'
      echo "            \"name\": \"$label\","
      echo '            "request": "launch",'
      echo "            \"mainClass\": \"$main_class\","
      echo "            \"projectName\": \"$module\""
    done <"$TARGETS"
    echo '        }'
    echo '    ],'
    echo '    "compounds": ['
    echo '        {'
    echo '            "name": "Stack completo",'
    echo '            "configurations": ['
    i=0
    while IFS='|' read -r rank module main_class port; do
      [ -z "$module" ] && continue
      i=$(( i + 1 ))
      [ "$i" -gt 1 ] && echo '",'
      if [ -n "$port" ]; then label="$i. $module (:$port)"; else label="$i. $module"; fi
      printf '                "%s' "$label"
    done <"$TARGETS"
    echo '"'
    echo '            ],'
    echo '            "stopAll": true'
    echo '        }'
    echo '    ]'
  fi
  echo '}'
} >"$VSCODE_DIR/launch.json"
echo "  .vscode/launch.json ($COUNT servizio/i)"

# --- I comandi, uguali per i due editor --------------------------------------

COMMANDS="dev|compila e avvia tutto in background
compile|ricompila: i servizi si riavviano da soli
logs|segue i log in un terminale solo
status|porte, container, registro Eureka
dev-down|ferma tutto e libera le porte
check|il progetto e' coerente?
test|collauda gli strumenti
docker-up|lo stack in container, per la demo
docker-down|ferma i container, i dati restano
db-schema|lo schema del database dalle @Entity
seed-data|dati di prova dalle @Entity"

{
  echo '// Generato da `task ide-sync`. Ctrl+Shift+P -> "Tasks: Run Task".'
  echo '{'
  echo '    "version": "2.0.0",'
  echo '    "tasks": ['
  first=1
  while IFS='|' read -r name what; do
    [ -z "$name" ] && continue
    [ "$first" -eq 0 ] && echo '        },'
    first=0
    echo '        {'
    echo "            \"label\": \"task $name\","
    echo "            \"detail\": \"$what\","
    echo '            "type": "shell",'
    echo "            \"command\": \"task $name\","
    echo '            "problemMatcher": [],'
    echo '            "presentation": { "reveal": "always", "panel": "dedicated" }'
  done <<<"$COMMANDS"
  echo '        }'
  echo '    ]'
  echo '}'
} >"$VSCODE_DIR/tasks.json"
echo "  .vscode/tasks.json"

# Zed usa un elenco piatto, con comando e argomenti separati.
{
  echo '// Generato da `task ide-sync`. Palette: "task: Spawn".'
  echo '['
  first=1
  while IFS='|' read -r name what; do
    [ -z "$name" ] && continue
    [ "$first" -eq 0 ] && echo '    },'
    first=0
    echo '    {'
    echo "        \"label\": \"task $name\","
    echo '        "command": "task",'
    echo "        \"args\": [\"$name\"],"
    echo '        "use_new_terminal": false,'
    echo '        "allow_concurrent_runs": false,'
    echo '        "reveal": "always"'
  done <<<"$COMMANDS"
  echo '    }'
  echo ']'
} >"$ZED_DIR/tasks.json"
echo "  .zed/tasks.json"

# --- I file che non dipendono dai moduli: solo se mancano --------------------
# Questi puoi modificarli a piacere: ide-sync non ci torna sopra.

if [ ! -f "$VSCODE_DIR/settings.json" ]; then
  cat >"$VSCODE_DIR/settings.json" <<'EOF'
{
    "java.configuration.updateBuildConfiguration": "automatic",
    "java.compile.nullAnalysis.mode": "automatic",
    // Lo stesso JDK che usa il Taskfile. Se sulla macchina d'esame sta
    // altrove, correggi qui il percorso (o togli il blocco: VS Code cerca da
    // solo, ma puo' pescare un Java piu' vecchio).
    "java.configuration.runtimes": [
        {
            "name": "JavaSE-25",
            "path": "C:/Program Files/Microsoft/jdk-25.0.2.10-hotspot",
            "default": true
        }
    ],
    // L'hot reload di task compile ricompila quello che hai salvato: senza
    // salvataggio automatico non si accorge di niente.
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.exclude": {
        "**/target": true,
        "**/.dev-logs": true
    },
    "search.exclude": {
        "**/target": true,
        "**/consegna": true
    },
    "[java]": { "editor.tabSize": 4 },
    "[yaml]": { "editor.tabSize": 2, "editor.insertSpaces": true }
}
EOF
  echo "  .vscode/settings.json (creato)"
fi

if [ ! -f "$VSCODE_DIR/extensions.json" ]; then
  cat >"$VSCODE_DIR/extensions.json" <<'EOF'
{
    // Ctrl+Shift+P -> "Extensions: Show Recommended Extensions".
    "recommendations": [
        "vscjava.vscode-java-pack",
        "vmware.vscode-boot-dev-pack",
        "ms-azuretools.vscode-docker",
        "redhat.vscode-yaml",
        "task.vscode-task"
    ]
}
EOF
  echo "  .vscode/extensions.json (creato)"
fi

if [ ! -f "$ZED_DIR/settings.json" ]; then
  cat >"$ZED_DIR/settings.json" <<'EOF'
// Zed legge il Java dall'estensione "Java" (jdtls): installala da
// "zed: extensions". Il progetto e' Maven multi-modulo, quindi apri la
// cartella del repository, non quella di un singolo servizio.
{
    "format_on_save": "on",
    "languages": {
        "Java": { "tab_size": 4 },
        "YAML": { "tab_size": 2 }
    },
    "file_scan_exclusions": [
        "**/target",
        "**/.dev-logs",
        "**/consegna",
        "**/.git"
    ]
}
EOF
  echo "  .zed/settings.json (creato)"
fi

if [ ! -f "$REPO_ROOT/.editorconfig" ]; then
  cat >"$REPO_ROOT/.editorconfig" <<'EOF'
# Vale per VS Code, Zed, IntelliJ ed Eclipse: nessuno dei quattro va
# configurato a mano.
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space

[*.java]
indent_size = 4

[*.{yml,yaml,json,xml,html}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

# Gli script POSIX e il wrapper Maven vogliono LF anche su Windows.
[*.sh]
end_of_line = lf
EOF
  echo "  .editorconfig (creato)"
fi

echo ""
echo "Editor riallineati."
echo ""
if [ "$COUNT" -gt 0 ]; then
  echo '  VS Code: F5 -> "Stack completo" avvia tutti i servizi in debug.'
  echo '  Zed:     palette "task: Spawn" per i comandi task.'
else
  echo "  Nessun servizio avviabile: crea un modulo con task new-service."
fi
echo ""
echo "  Per il debug in VS Code serve l'estensione Extension Pack for Java;"
echo "  IntelliJ non ha bisogno di niente: apri il pom aggregatore."
echo ""
