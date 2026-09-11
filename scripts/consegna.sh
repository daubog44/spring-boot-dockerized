#!/usr/bin/env bash
# Prepara la cartella di consegna: il progetto pronto da eseguire (moduli senza
# target/ accanto a pom e compose), l'allegato tecnico gia' compilato, lo
# schema del database e le istruzioni per eseguire.
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
mkdir -p "$OUT_DIR"

# Un zip col contenuto di una cartella: percorsi relativi a lei, niente
# cartella in cima ("Estrai tutto" di Windows ne crea gia' una col nome
# dell'archivio) e i file nascosti compresi (senza .mvn/ il wrapper Maven non
# parte). La traccia chiede un .zip, e zip non c'e' dappertutto (su Git Bash
# manca): allora Python, allora jar, che col JDK c'e' sempre.
zip_dir() { # cartella, archivio.zip
  local src="$1" out="$2" py
  rm -f "$out"
  if command -v zip >/dev/null 2>&1; then
    (cd "$src" && zip -qr "$out" .)
    return
  fi
  for py in python3 python; do
    command -v "$py" >/dev/null 2>&1 && "$py" -c 'import zipfile' >/dev/null 2>&1 || continue
    "$py" - "$src" "$out" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            z.write(full, os.path.relpath(full, src).replace(os.sep, '/'))
PY
    return
  done
  if command -v jar >/dev/null 2>&1; then
    jar --create --no-manifest --file "$out" -C "$src" .
    return
  fi
  echo "Non trovo niente per fare uno zip (zip, python o jar)." >&2
  return 1
}

# --- I moduli, senza roba compilata ------------------------------------------
# Ognuno nella sua cartella accanto al pom aggregatore, come nel progetto: e'
# li' che il Dockerfile e Maven li cercano.

MODULES=""
for dir in "$DEMO_DIR"/*/; do
  [ -f "$dir/pom.xml" ] || continue
  name="$(basename "$dir")"
  MODULES="$MODULES $name"
  # Le cartelle target/ non si consegnano: si ricompilano.
  tar -cf - -C "$DEMO_DIR" --exclude='target' "$name" | tar -xf - -C "$OUT_DIR"
  echo "  $name/  ($(du -sk "$OUT_DIR/$name" | cut -f1) KB)"
done

# --- Pulizia interna: la consegna non deve avere tracce del template ---------
COMMON_DTO_DEST="$OUT_DIR/common-dto"
if [ -d "$COMMON_DTO_DEST" ]; then
  rm -rf "$COMMON_DTO_DEST/src/main/java/devdata"
  rm -rf "$COMMON_DTO_DEST/src/main/resources/META-INF"
  if [ -f "$COMMON_DTO_DEST/pom.xml" ]; then
    python3 -c '
import sys, re
with open(sys.argv[1], "r", encoding="utf-8") as f:
    text = f.read()
text = re.sub(r"(?s)\s*<!-- Per il pacchetto devdata.*?jakarta\.persistence-api\s*</artifactId>\s*<optional>true</optional>\s*</dependency>", "", text)
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(text)
' "$COMMON_DTO_DEST/pom.xml" 2>/dev/null || true
  fi
fi

for yml in "$OUT_DIR"/*/src/main/resources/application.yml; do
  [ -f "$yml" ] || continue
  awk '/^[[:space:]]*dev-data:/{skip=1; next} skip && /^[[:space:]]+rows:/{next} {skip=0; print}' "$yml" > "$yml.tmp" && mv "$yml.tmp" "$yml"
done
echo "  pulizia consegna: rimosse classi del template (devdata) e configurazioni interne"

# --- Quello che serve a farlo girare -----------------------------------------

for file in docker-compose.yml Dockerfile .dockerignore pom.xml mvnw mvnw.cmd; do
  [ -f "$DEMO_DIR/$file" ] && cp "$DEMO_DIR/$file" "$OUT_DIR/$file"
done
[ -d "$DEMO_DIR/.mvn" ] && cp -r "$DEMO_DIR/.mvn" "$OUT_DIR/.mvn"
[ -d "$DEMO_DIR/postgres-init" ] && cp -r "$DEMO_DIR/postgres-init" "$OUT_DIR/postgres-init"
echo "  docker-compose.yml, Dockerfile, pom aggregatore e wrapper Maven"

# --- Lo schema del database ---------------------------------------------------

# db-schema compila e avvia i moduli con un database per interrogarlo: se uno
# non parte, lo schema esce con una nota al posto delle sue tabelle, e la
# consegna va avanti lo stesso.
if bash "$SCRIPT_DIR/db-schema.sh" --out "$OUT_DIR/SCHEMA-DATABASE.md" >/dev/null; then
  echo "  SCHEMA-DATABASE.md (letto dal database che crea Hibernate)"
else
  echo "  SCHEMA-DATABASE.md incompleto: task db-schema ti dice perche', poi rilancia la consegna"
fi

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

# --- Le parti scritte a mano: allegato.md -------------------------------------
# L'analisi, l'algoritmo e la descrizione dei moduli li scrivi tu, in
# allegato.md nella cartella del progetto: sta li' e non in consegna/, che a
# ogni giro si rifa' da zero. Qui si prendono le sue sezioni per titolo e si
# mettono al loro posto nell'allegato, PRIMA di fare l'archivio: cosi'
# l'archivio ha sempre dentro il testo, e una consegna rifatta non lo perde.

ALLEGATO="$REPO_ROOT/allegato.md"
HINT_ANALISI="[Due o tre paragrafi: cosa chiede la traccia, quali sono gli attori, che cosa fa il sistema nel suo insieme.]"
HINT_ALGORITMO="[Se la traccia chiede un algoritmo (calcolo di una distanza, scelta di un'ubicazione, estrazione casuale...), spiegalo qui a parole e indica la classe e il metodo che lo implementano.]"
HINT_MODULO="[Una o due righe su cosa fa e su come lo fa.]"
HINT_DOMANDA="[Facoltativa: la risposta alla domanda teorica, se la traccia la vuole nell'allegato.]"
if [ ! -f "$ALLEGATO" ]; then
  {
    echo "# Allegato tecnico: le parti scritte da te"
    echo ""
    echo "task consegna prende ogni sezione di questo file e la mette al suo posto in"
    echo "ALLEGATO-TECNICO.md, accanto a quello che ricava dal progetto (moduli, porte,"
    echo "endpoint, schema del database). Scrivi sotto ogni titolo e lascia i titoli"
    echo "come sono: una sezione ancora fra parentesi quadre conta come da scrivere, e"
    echo "la consegna te lo ricorda."
    echo ""
    printf '## Analisi\n\n%s\n\n## Algoritmo\n\n%s\n\n' "$HINT_ANALISI" "$HINT_ALGORITMO"
    while read -r name module port; do
      [ -z "$module" ] && continue
      printf '## %s\n\n%s\n\n' "$module" "$HINT_MODULO"
    done <<<"$SERVICES"
    printf '## Domanda A\n\n%s\n\n## Domanda B\n\n%s\n' "$HINT_DOMANDA" "$HINT_DOMANDA"
  } >"$ALLEGATO"
  echo "  allegato.md creato: e' li' che scrivi analisi, algoritmo e moduli"
fi

# Il testo scritto sotto "## <titolo>", senza righe vuote ai bordi; niente se
# la sezione manca o e' ancora fra parentesi quadre.
part_text() { # titolo
  local text
  text="$(awk -v want="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" '
    /^##[ \t]+/ { t = $0; sub(/^##[ \t]+/, "", t); gsub(/`/, "", t); sub(/[ \t\r]+$/, "", t); cur = tolower(t); next }
    cur == want { sub(/\r$/, ""); buf[n++] = $0 }
    END {
      s = 0; while (s < n && buf[s] ~ /^[ \t]*$/) s++
      e = n - 1; while (e >= s && buf[e] ~ /^[ \t]*$/) e--
      for (i = s; i <= e; i++) print buf[i]
    }' "$ALLEGATO")"
  case "$text" in "["*) ;; *) printf '%s' "$text" ;; esac
}
has_part() { grep -qiE "^##[[:space:]]+\`?$1\`?[[:space:]]*\$" "$ALLEGATO"; }

# Un modulo nato dopo l'ultima consegna: la sua sezione si aggiunge in fondo.
ADDED=""
while read -r name module port; do
  [ -z "$module" ] && continue
  if ! has_part "$module"; then
    printf '\n## %s\n\n%s\n' "$module" "$HINT_MODULO" >>"$ALLEGATO"
    ADDED="$ADDED $module"
  fi
done <<<"$SERVICES"
if [ -n "$ADDED" ]; then echo "  allegato.md: aggiunta la sezione di$ADDED"; fi

# Il testo di una sezione, o il suggerimento fra quadre se e' da scrivere.
# Va chiamata senza $(...): deve poter aggiornare MISSING.
MISSING=""
part_or_hint() { # titolo, suggerimento
  local text
  text="$(part_text "$1")"
  if [ -n "$text" ]; then
    printf '%s\n' "$text"
  else
    printf '%s\n' "$2"
    MISSING="$MISSING, $1"
  fi
}

# --- L'allegato tecnico -------------------------------------------------------

{
  echo "# Allegato tecnico di progetto"
  echo ""
  echo "Candidato: **$NOME**  "
  echo "Data: $(date '+%d/%m/%Y')"
  echo ""
  echo "---"
  echo ""
  echo "## 1. Analisi del problema e contesto applicativo"
  echo ""
  part_or_hint "Analisi" "$HINT_ANALISI"
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
      echo "Nessun endpoint REST."
    fi
    echo ""
    part_or_hint "$module" "$HINT_MODULO"
    echo ""
  done <<<"$SERVICES"
  echo "## 5. Descrizione dell'algoritmo"
  echo ""
  part_or_hint "Algoritmo" "$HINT_ALGORITMO"
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
  # Le risposte teoriche ci vanno solo se le hai scritte in allegato.md.
  qa="$(part_text 'Domanda A')"
  qb="$(part_text 'Domanda B')"
  if [ -n "$qa$qb" ]; then
    echo "## 7. Risposte alle domande teoriche"
    echo ""
    if [ -n "$qa" ]; then printf '### Domanda A\n\n%s\n\n' "$qa"; fi
    if [ -n "$qb" ]; then printf '### Domanda B\n\n%s\n\n' "$qb"; fi
  fi
} >"$OUT_DIR/ALLEGATO-TECNICO.md"
echo "  ALLEGATO-TECNICO.md (moduli, porte, endpoint e schema gia' dentro)"

# --- Istruzioni per chi la esegue --------------------------------------------

{
  echo "# Come eseguire il progetto"
  echo ""
  echo "L'archivio contiene il progetto gia' pronto: non c'e' niente da ricomporre."
  echo ""
  echo '```'
  echo "$NOME/"
  echo "+-- docker-compose.yml, Dockerfile   lo stack, un'immagine per servizio"
  echo "+-- pom.xml, mvnw, mvnw.cmd, .mvn/   il progetto Maven e il suo wrapper"
  for module in $MODULES; do echo "+-- $module/"; done
  echo "+-- ALLEGATO-TECNICO.md, SCHEMA-DATABASE.md"
  echo '```'
  echo ""
  echo "I comandi qui sotto si lanciano **dalla cartella che contiene"
  echo "\`docker-compose.yml\`**. Se il programma di decompressione ha creato una"
  echo "cartella dentro l'altra con lo stesso nome, entra in quella interna."
  echo ""
  echo "## 1. Con Docker (consigliato)"
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
  echo "## 2. Senza Docker"
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
  echo "## 3. Indirizzi"
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
  echo "Dopo l'avvio servono pochi secondi perche' i servizi si trovino su Eureka:"
  echo "se la primissima chiamata fra servizi fallisce, riprova."
  echo ""
} >"$OUT_DIR/ISTRUZIONI-ESECUZIONE.md"
echo "  ISTRUZIONI-ESECUZIONE.md"

# --- L'archivio unico ---------------------------------------------------------

# Lo scriviamo fuori da consegna/, perche' non finisca dentro se stesso.
STAGING="$(mktemp -d)"
zip_dir "$OUT_DIR" "$STAGING/$NOME.zip"
mv "$STAGING/$NOME.zip" "$OUT_DIR/$NOME.zip"
FINAL="$OUT_DIR/$NOME.zip"
rm -rf "$STAGING"

echo ""
echo "Consegna pronta in $OUT_DIR"
echo ""
echo "  $(basename "$FINAL")   $(( $(wc -c <"$FINAL") / 1024 )) KB   <- questo e' l'archivio da consegnare"
echo ""
if [ -z "$MISSING" ]; then
  echo "  L'allegato e' completo: le parti scritte da te vengono da allegato.md."
else
  echo "  Nell'allegato mancano ancora: ${MISSING#, }."
  echo "  Scrivile in allegato.md, nella cartella del progetto, e rilancia"
  echo "  task consegna: l'archivio si rifa' con dentro il testo."
fi
echo ""
