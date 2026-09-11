#!/usr/bin/env bash
# Prepara la cartella di consegna: i moduli zippati (senza target/), l'allegato
# tecnico gia' compilato, lo schema del database e le istruzioni per eseguire.
# Equivalente POSIX di scripts/consegna.ps1.
#
#   task consegna NOME=ROSSI_MARIO
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

NOME="CONSEGNA"
OUT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Nome|--nome) NOME="$2"; shift 2 ;;
    -OutDir|--out-dir) OUT_DIR="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done
[ -n "$OUT_DIR" ] || OUT_DIR="$REPO_ROOT/consegna"

echo ""
echo "==> Preparazione della consegna"
echo ""

# --- Prima di tutto: il progetto sta in piedi? -------------------------------

if ! bash "$SCRIPT_DIR/check.sh" --project-only >/dev/null; then
  bash "$SCRIPT_DIR/check.sh" --project-only
  echo "task check non passa: sistema il progetto prima di consegnarlo." >&2
  exit 1
fi
echo "  il progetto e' coerente (task check)"

# --- La cartella di consegna, da zero ----------------------------------------

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/moduli"

# zip se c'e', altrimenti tar.gz: l'importante e' che si apra sulla macchina di
# chi corregge.
have_zip=0
command -v zip >/dev/null 2>&1 && have_zip=1

pack() { # cartella-sorgente, nome-archivio-senza-estensione
  local src="$1" out="$2" base parent
  parent="$(dirname "$src")"
  base="$(basename "$src")"
  if [ "$have_zip" -eq 1 ]; then
    (cd "$parent" && zip -qr "$out.zip" "$base")
    echo "$out.zip"
  else
    tar -czf "$out.tar.gz" -C "$parent" "$base"
    echo "$out.tar.gz"
  fi
}

# --- Un pacchetto per microservizio, senza roba compilata --------------------

STAGING="$(mktemp -d)"
MODULES=""
for dir in "$DEMO_DIR"/*/; do
  [ -f "$dir/pom.xml" ] || continue
  name="$(basename "$dir")"
  MODULES="$MODULES $name"
  # Le cartelle target/ non si consegnano: si ricompilano.
  tar -cf - -C "$DEMO_DIR" --exclude='target' "$name" | tar -xf - -C "$STAGING"
  archive="$(pack "$STAGING/$name" "$OUT_DIR/moduli/$name")"
  size="$(( $(wc -c <"$archive") / 1024 ))"
  echo "  moduli/$(basename "$archive")  (${size} KB)"
done

# --- Quello che serve a farlo girare -----------------------------------------

for file in docker-compose.yml Dockerfile .dockerignore pom.xml mvnw mvnw.cmd; do
  [ -f "$DEMO_DIR/$file" ] && cp "$DEMO_DIR/$file" "$OUT_DIR/$file"
done
[ -d "$DEMO_DIR/.mvn" ] && cp -r "$DEMO_DIR/.mvn" "$OUT_DIR/.mvn"
[ -d "$DEMO_DIR/postgres-init" ] && cp -r "$DEMO_DIR/postgres-init" "$OUT_DIR/postgres-init"
echo "  docker-compose.yml, Dockerfile, pom aggregatore e wrapper Maven"

# --- Lo schema del database ---------------------------------------------------

bash "$SCRIPT_DIR/db-schema.sh" --out "$OUT_DIR/SCHEMA-DATABASE.md" >/dev/null
echo "  SCHEMA-DATABASE.md (ricavato dalle @Entity)"

# --- I servizi, con porte, nomi Eureka ed endpoint ---------------------------

UI_PORT="$(grep -oE '\[int\]\$UiPort = [0-9]+' "$SCRIPT_DIR/dev.ps1" | grep -oE '[0-9]+' || echo 8080)"
SERVICES="$(grep -oE "Name = '[^']+'; +Module = '[^']+'; +Port = (\\\$UiPort|[0-9]+)" "$SCRIPT_DIR/dev.ps1" |
  sed -E "s/Name = '([^']+)'; +Module = '([^']+)'; +Port = (.*)/\1 \2 \3/" |
  sed "s/\\\$UiPort/$UI_PORT/")"

app_name() { # modulo
  local yml="$DEMO_DIR/$1/src/main/resources/application.yml"
  [ -f "$yml" ] || return 0
  grep -E '^[[:space:]]+name:' "$yml" 2>/dev/null | head -n 1 | awk '{print $2}' || true
  return 0
}

endpoints() { # modulo
  local src="$DEMO_DIR/$1/src/main/java"
  [ -d "$src" ] || return 0
  grep -rl -E '@(Rest)?Controller' "$src" --include='*.java' 2>/dev/null | while read -r file; do
    base="$(grep -oE '@RequestMapping\([[:space:]]*"[^"]*"' "$file" | head -n 1 | sed -E 's/.*"([^"]*)"/\1/')"
    grep -oE '@(Get|Post|Put|Delete|Patch)Mapping(\([[:space:]]*(value[[:space:]]*=[[:space:]]*)?"[^"]*"[[:space:]]*\))?' "$file" |
      while read -r mapping; do
        verb="$(printf '%s' "$mapping" | sed -E 's/@([A-Za-z]+)Mapping.*/\1/' | tr 'a-z' 'A-Z')"
        path="$(printf '%s' "$mapping" | sed -E 's/[^"]*"([^"]*)".*/\1/')"
        [ "$path" = "$mapping" ] && path=""
        full="$base$path"
        [ -z "$full" ] && full="/"
        echo "$verb $full"
      done
  done | sort -u || true
  return 0
}

role() { # modulo
  case "$1" in
    naming-server) echo "Eureka Naming Server" ;;
    *-ui|ui) echo "Interfaccia web (Thymeleaf)" ;;
    *) echo "Microservizio REST" ;;
  esac
}

HAS_POSTGRES=0
grep -qE 'image:[[:space:]]*postgres' "$DEMO_DIR/docker-compose.yml" && HAS_POSTGRES=1
# La porta pubblicata sul PC, che db-config puo' aver spostato dalla 5432.
PG_PORT="$(grep -oE '^[[:space:]]+-[[:space:]]*"[0-9]+:5432"' "$DEMO_DIR/docker-compose.yml" | head -n 1 | grep -oE '[0-9]+:5432' | cut -d: -f1 || true)"
[ -n "$PG_PORT" ] || PG_PORT=5432

# --- L'allegato tecnico -------------------------------------------------------

{
  echo "# Allegato tecnico di progetto"
  echo ""
  echo "Candidato: **$NOME**  "
  echo "Data: $(date '+%d/%m/%Y')"
  echo ""
  echo "> Le parti fra parentesi quadre sono le uniche da scrivere a mano: il"
  echo "> resto e' stato ricavato dal progetto."
  echo ""
  echo "---"
  echo ""
  echo "## 1. Analisi del problema e contesto applicativo"
  echo ""
  echo "[Due o tre paragrafi: cosa chiede la traccia, quali sono gli attori, che"
  echo "cosa fa il sistema nel suo insieme.]"
  echo ""
  echo "## 2. Architettura della soluzione"
  echo ""
  echo "Architettura a microservizi Spring Boot, con service discovery Eureka e"
  echo "chiamate fra servizi via OpenFeign risolte per nome logico. Ogni servizio"
  echo "espone i propri contratti REST tramite OpenAPI/Swagger UI. L'intero stack"
  echo "e' containerizzato con Docker Compose."
  echo ""
  echo "| Modulo | Porta | Nome su Eureka | Ruolo |"
  echo "| :--- | :---: | :--- | :--- |"
  while read -r name module port; do
    [ -z "$module" ] && continue
    echo "| \`$module\` | $port | \`$(app_name "$module")\` | $(role "$module") |"
  done <<<"$SERVICES"
  [ "$HAS_POSTGRES" -eq 1 ] && echo "| \`postgres\` | $PG_PORT | - | Database relazionale (container) |"
  echo ""
  echo "Il modulo \`common-dto\` non e' un servizio: contiene le classi DTO"
  echo "condivise, cosi' chi chiama e chi risponde usano lo stesso contratto."
  echo ""
  echo "## 3. Schema concettuale e logico della base dati"
  echo ""
  # Lo schema arriva come documento a se': qui dentro scala di un livello.
  sed '/^# /d; s/^#/##/' "$OUT_DIR/SCHEMA-DATABASE.md"
  echo ""
  echo "## 4. Descrizione dei moduli implementati"
  echo ""
  while read -r name module port; do
    [ -z "$module" ] && continue
    echo "### \`$module\` (porta $port)"
    echo ""
    eps="$(endpoints "$module" || true)"
    if [ -n "$eps" ]; then
      echo "Endpoint esposti:"
      echo ""
      printf '%s\n' "$eps" | sed 's/^/- `/; s/$/`/'
      echo ""
      echo "Contratti OpenAPI: \`http://localhost:$port/swagger-ui.html\`"
    else
      echo "Nessun endpoint REST: [descrivi cosa fa questo modulo]."
    fi
    echo ""
    echo "[Una o due righe su cosa fa e su come lo fa.]"
    echo ""
  done <<<"$SERVICES"
  echo "## 5. Descrizione dell'algoritmo"
  echo ""
  echo "[Se la traccia chiede un algoritmo (calcolo di una distanza, scelta di"
  echo "un'ubicazione, estrazione casuale...), spiegalo qui a parole e indica la"
  echo "classe e il metodo che lo implementano.]"
  echo ""
  echo "## 6. Istruzioni per il test della soluzione"
  echo ""
  echo "Vedi \`ISTRUZIONI-ESECUZIONE.md\`, allegato alla consegna."
  echo ""
  while read -r name module port; do
    [ -z "$module" ] && continue
    case "$module" in
      naming-server) echo "- dashboard Eureka: \`http://localhost:$port\`" ;;
      *-ui|ui) echo "- interfaccia web: \`http://localhost:$port\`" ;;
      *) echo "- Swagger di \`$module\`: \`http://localhost:$port/swagger-ui.html\`" ;;
    esac
  done <<<"$SERVICES"
  echo ""
} >"$OUT_DIR/ALLEGATO-TECNICO.md"
echo "  ALLEGATO-TECNICO.md (moduli, porte, endpoint e schema gia' dentro)"

# --- Istruzioni per chi la esegue --------------------------------------------

{
  echo "# Come eseguire il progetto"
  echo ""
  echo "Nella cartella trovi:"
  echo ""
  echo "- \`moduli/*\` - i sorgenti di ogni microservizio (senza le cartelle \`target/\`);"
  echo "- \`docker-compose.yml\`, \`Dockerfile\`, \`pom.xml\` e il wrapper Maven - l'infrastruttura;"
  echo "- \`ALLEGATO-TECNICO.md\` e \`SCHEMA-DATABASE.md\` - la documentazione."
  echo ""
  echo "## 1. Ricostruire il progetto"
  echo ""
  echo "Scompatta ogni archivio di \`moduli/\` **nella stessa cartella** dove si"
  echo "trovano \`pom.xml\` e \`docker-compose.yml\`. Il risultato:"
  echo ""
  echo '```'
  echo "progetto/"
  echo "+-- pom.xml"
  echo "+-- mvnw, mvnw.cmd, .mvn/"
  echo "+-- Dockerfile"
  echo "+-- docker-compose.yml"
  for module in $MODULES; do echo "+-- $module/"; done
  echo '```'
  echo ""
  echo "## 2. Con Docker (consigliato)"
  echo ""
  echo '```bash'
  echo "docker compose up -d --build"
  echo '```'
  echo ""
  echo "La prima build compila tutti i moduli e prepara un'immagine per servizio;"
  echo "Eureka parte per primo e gli altri lo aspettano (healthcheck)."
  echo ""
  echo "Per fermare tutto: \`docker compose down\` (i dati del database restano),"
  echo "oppure \`docker compose down -v\` per cancellare anche il volume."
  echo ""
  echo "## 3. Senza Docker"
  echo ""
  echo '```bash'
  echo "./mvnw clean package -Dmaven.test.skip=true"
  echo '```'
  echo ""
  echo "Poi, in terminali separati e **partendo da Eureka**:"
  echo ""
  echo '```bash'
  while read -r name module port; do
    [ -z "$module" ] && continue
    echo "./mvnw -pl $module spring-boot:run"
  done <<<"$SERVICES"
  echo '```'
  echo ""
  if [ "$HAS_POSTGRES" -eq 1 ]; then
    echo "Se i servizi usano PostgreSQL, avvialo prima: \`docker compose up -d postgres\`."
    echo ""
  fi
  echo "## 4. Indirizzi"
  echo ""
  echo "| Cosa | Indirizzo |"
  echo "| :--- | :--- |"
  while read -r name module port; do
    [ -z "$module" ] && continue
    case "$module" in
      naming-server) echo "| Dashboard Eureka | \`http://localhost:$port\` |" ;;
      *-ui|ui) echo "| Interfaccia web | \`http://localhost:$port\` |" ;;
      *) echo "| Swagger \`$module\` | \`http://localhost:$port/swagger-ui.html\` |" ;;
    esac
  done <<<"$SERVICES"
  [ "$HAS_POSTGRES" -eq 1 ] && echo "| PostgreSQL | \`localhost:$PG_PORT\` |"
  echo ""
  echo "I servizi impiegano 10-15 secondi a registrarsi su Eureka: le prime"
  echo "chiamate fra servizi, subito dopo l'avvio, possono fallire."
  echo ""
} >"$OUT_DIR/ISTRUZIONI-ESECUZIONE.md"
echo "  ISTRUZIONI-ESECUZIONE.md"

# --- L'archivio unico ---------------------------------------------------------

FINAL="$(cd "$OUT_DIR/.." && pack "$OUT_DIR" "$(cd "$OUT_DIR/.." && pwd)/$NOME")"
mv "$FINAL" "$OUT_DIR/$(basename "$FINAL")"
FINAL="$OUT_DIR/$(basename "$FINAL")"
rm -rf "$STAGING"

echo ""
echo "Consegna pronta in $OUT_DIR"
echo ""
echo "  $(basename "$FINAL")   $(( $(wc -c <"$FINAL") / 1024 )) KB   <- questo e' l'archivio da consegnare"
echo ""
echo "  Prima di consegnare, apri ALLEGATO-TECNICO.md e riempi le parti fra"
echo "  parentesi quadre: analisi, algoritmo e descrizione dei moduli."
echo ""
