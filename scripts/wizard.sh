#!/usr/bin/env bash
# Wizard: fa le domande e monta il progetto d'esame chiamando i comandi giusti.
# Equivalente POSIX di scripts/wizard.ps1.
#
#   task wizard                 il progetto intero
#   task wizard SERVICE=<nome>  un microservizio solo
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SERVICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# Le risposte possono arrivare anche da un file, una per riga (una riga vuota
# vale come Invio): e' cosi' che `task test` collauda il wizard senza nessuno
# alla tastiera.
ANSWERS_FILE="${WIZARD_ANSWERS:-}"
if [ -n "$ANSWERS_FILE" ]; then
  [ -f "$ANSWERS_FILE" ] || { echo "WIZARD_ANSWERS: non trovo $ANSWERS_FILE" >&2; exit 1; }
  exec 3<"$ANSWERS_FILE"
elif [ ! -t 0 ]; then
  echo ""
  echo "Il wizard fa domande: serve un terminale vero."
  echo ""
  echo "  Lancialo con  task wizard"
  echo "  oppure usa i comandi singoli: task new-service, task use-postgres, ..."
  echo ""
  exit 1
fi

# --- Domande ------------------------------------------------------------------

REPLY_TEXT=""
read_answer() { # $1 il prompt; la risposta finisce in REPLY_TEXT
  local prompt="${1:-  >}"
  if [ -z "$ANSWERS_FILE" ]; then
    read -r -p "$prompt " REPLY_TEXT
    return 0
  fi
  # Senza questo controllo, una domanda con risposta obbligatoria
  # continuerebbe a chiedere per sempre.
  if ! IFS= read -r REPLY_TEXT <&3 && [ -z "$REPLY_TEXT" ]; then
    echo "WIZARD_ANSWERS: le risposte sono finite prima delle domande." >&2
    exit 1
  fi
  REPLY_TEXT="${REPLY_TEXT%$'\r'}"
  echo "$prompt $REPLY_TEXT"
}

# Una 5432 gia' presa (un PostgreSQL installato sul PC del laboratorio, un
# altro progetto in Docker) e' il guaio piu' comune: meglio accorgersene adesso
# che al primo avvio.
port_busy() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk 'NR > 1 {print $4}' | grep -qE "[:.]$1\$"
  else
    netstat -an 2>/dev/null | grep -iE 'listen' | grep -qE "[:.]$1[[:space:]]"
  fi
}
free_postgres_port() {
  local port=5432
  while [ "$port" -lt 5450 ] && port_busy "$port"; do port=$(( port + 1 )); done
  echo "$port"
}

ANSWER=""

ask_text() {
  # $1 domanda, $2 default, $3 regex (facoltativa), $4 suggerimento
  local question="$1" default="${2:-}" pattern="${3:-}" hint="${4:-}" suffix=""
  [ -n "$default" ] && suffix=" [$default]"
  while true; do
    echo ""
    echo "  ${question}${suffix}"
    [ -n "$hint" ] && echo "  $hint"
    read_answer "  >"; ANSWER="$REPLY_TEXT"
    ANSWER="$(echo "$ANSWER" | tr -d '[:space:]')"
    [ -z "$ANSWER" ] && ANSWER="$default"
    if [ -z "$ANSWER" ]; then echo "  Serve una risposta."; continue; fi
    if [ -n "$pattern" ] && ! printf '%s' "$ANSWER" | grep -qE "$pattern"; then
      echo "  Non va bene, riprova."
      continue
    fi
    return 0
  done
}

ask_yesno() {
  # $1 domanda, $2 default (s/n). Ritorna 0 per si', 1 per no.
  local question="$1" default="${2:-s}" suffix answer
  if [ "$default" = "s" ]; then suffix="[S/n]"; else suffix="[s/N]"; fi
  while true; do
    echo ""
    echo "  $question $suffix"
    read_answer "  >"; answer="$REPLY_TEXT"
    answer="$(echo "$answer" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    [ -z "$answer" ] && answer="$default"
    case "$answer" in
      s|si|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "  Rispondi s o n." ;;
    esac
  done
}

CHOICE=0
ask_choice() {
  # $1 domanda, $2 default, poi le opzioni
  local question="$1" default="$2"; shift 2
  local options=("$@") i answer
  while true; do
    echo ""
    echo "  $question"
    for i in "${!options[@]}"; do
      echo "    $((i + 1))) ${options[$i]}"
    done
    read_answer "  [$default] >"; answer="$REPLY_TEXT"
    answer="$(echo "$answer" | tr -d '[:space:]')"
    [ -z "$answer" ] && answer="$default"
    case "$answer" in
      ''|*[!0-9]*) echo "  Scegli un numero dell'elenco." ; continue ;;
    esac
    if [ "$answer" -ge 1 ] && [ "$answer" -le "${#options[@]}" ]; then
      CHOICE="$answer"
      return 0
    fi
    echo "  Scegli un numero dell'elenco."
  done
}

step() {
  # $1 script, poi gli argomenti
  local script="$1"; shift
  echo ""
  echo "  \$ $script $*"
  bash "$SCRIPT_DIR/$script" "$@" || { echo "$script ha fallito." >&2; exit 1; }
}

# La cartella dell'aggregatore Maven (quella che di solito si chiama demo).
# La verita' sta nel Taskfile, che la nomina in "dir:": cercarla a naso fra le
# cartelle con un pom.xml sbaglierebbe bersaglio, per esempio con consegna/.
aggregator_name() {
  local name dir
  if [ -f "$REPO_ROOT/Taskfile.yml" ]; then
    name="$(grep -oE "^[[:space:]]*dir:[[:space:]]*'?[A-Za-z0-9_.-]+'?[[:space:]]*$"  "$REPO_ROOT/Taskfile.yml" | head -n 1 | sed -E "s/^[[:space:]]*dir:[[:space:]]*'?//; s/'?[[:space:]]*$//")"
    if [ -n "$name" ] && [ -f "$REPO_ROOT/$name/pom.xml" ]; then
      echo "$name"
      return 0
    fi
  fi
  for dir in "$REPO_ROOT"/*/; do
    [ "$(basename "${dir%/}")" = "consegna" ] && continue
    if [ -f "$dir/pom.xml" ] && [ -f "$dir/docker-compose.yml" ]; then
      basename "${dir%/}"
      return 0
    fi
  done
  echo "Non trovo la cartella dell'aggregatore sotto $REPO_ROOT." >&2
  return 1
}

demo_dir() {
  local name
  name="$(aggregator_name)" || exit 1
  echo "$REPO_ROOT/$name"
}

# --- Un microservizio ---------------------------------------------------------

service_wizard() {
  # La variabile non si chiama demo apposta: rename-project riscrive i
  # percorsi, e un riferimento a $demo gli somiglierebbe troppo.
  local name="$1" aggr yml short
  aggr="$(demo_dir)"

  if [ -f "$aggr/$name/pom.xml" ]; then
    echo ""
    echo "  Il modulo $name c'e' gia': lo rifiniamo."
  else
    ask_choice "Che cos'e' $name?" 1 \
      'servizio REST con database (il caso normale: entity, repository, controller)' \
      'servizio REST senza database (calcoli, orchestrazione, chiamate ad altri servizi)' \
      'interfaccia web Thymeleaf (le pagine che si vedono alla demo)'
    local kind="$CHOICE"

    ask_text 'Su quale porta?' 'automatica' '' 'Invio = la prima libera dopo le altre'
    local port="$ANSWER"

    local args=(--name "$name")
    [ "$port" != "automatica" ] && args+=(--port "$port")
    [ "$kind" = "2" ] && args+=(--no-db)
    [ "$kind" = "3" ] && args+=(--ui)
    step new-service.sh "${args[@]}"

    if [ "$kind" = "3" ]; then
      if ask_yesno 'Vuoi Swagger UI anche su questa interfaccia web?' n; then
        step enable-swagger.sh --module "$name"
      fi
    fi
    [ "$kind" = "2" ] && return 0
  fi

  # Il database: solo per chi ce l'ha.
  yml="$aggr/$name/src/main/resources/application.yml"
  [ -f "$yml" ] || return 0
  grep -q 'datasource:' "$yml" || return 0
  if grep -q 'jdbc:postgresql' "$yml"; then
    echo ""
    echo "  $name e' gia' collegato a PostgreSQL."
    return 0
  fi

  ask_choice "Che database usa $name?" 1 \
    'H2 in memoria (parte da solo, si svuota a ogni riavvio: comodo mentre sviluppi)' \
    'PostgreSQL, il database condiviso del docker-compose' \
    'PostgreSQL, con un database tutto suo (un servizio, un database)'
  case "$CHOICE" in
    2) step use-postgres.sh --module "$name" ;;
    3)
      short="$(printf '%s' "$name" | sed -E 's/-(service|ui|server)$//' | tr '-' '_')"
      ask_text 'Come si chiama il suo database?' "$short" '^[a-z][a-z0-9_]*$'
      step use-postgres.sh --module "$name" --db-name "$ANSWER"
      ;;
  esac
}

# --- Un servizio solo ---------------------------------------------------------

if [ -n "$SERVICE" ]; then
  printf '%s' "$SERVICE" | grep -qE '^[a-z][a-z0-9-]*$' || {
    echo "Nome non valido: '$SERVICE'. Minuscole, numeri e trattini." >&2; exit 1; }
  echo ""
  echo "==> Wizard: $SERVICE"
  service_wizard "$SERVICE"
  echo ""
  bash "$SCRIPT_DIR/check.sh" --project-only
  echo ""
  echo "  task new-entity   genera entity, repository, service e controller"
  echo "  task dev          riavvia lo stack (un modulo nuovo non basta ricompilarlo)"
  echo ""
  exit 0
fi

# --- Il progetto intero -------------------------------------------------------

echo ""
echo "=================================================================="
echo " WIZARD DEL PROGETTO"
echo "=================================================================="
echo ""
echo "  Rispondi alle domande: alla fine il progetto e' montato, coerente"
echo "  e pronto da avviare. Invio accetta il valore fra parentesi."
echo ""
echo "  Eureka (naming-server) c'e' gia': e' il registro dei servizi, e"
echo "  senza di lui i nomi delle chiamate Feign non si risolvono."

# 0. Java: il progetto si allinea al JDK di questa macchina, senza domande.
. "$SCRIPT_DIR/scaffold-lib.sh"
JDK="$(machine_jdk || true)"
JDK_VERSION="${JDK%%|*}"
PROJECT_JAVA="$(project_java_version "$(demo_dir)")"
echo ""
if [ -z "$JDK" ]; then
  echo "  Non trovo un JDK (JAVA_HOME o PATH): il progetto resta su Java $PROJECT_JAVA."
  echo "  Installane uno da 17 in su, poi task set-java."
elif [ "$JDK_VERSION" -lt 17 ]; then
  echo "  Il JDK di questa macchina e' Java $JDK_VERSION: Spring Boot 4 vuole almeno Java 17."
  echo "  Il progetto resta su Java $PROJECT_JAVA: installa un JDK piu' recente, poi task set-java."
elif [ "$JDK_VERSION" != "$PROJECT_JAVA" ]; then
  echo "  Il progetto e' su Java $PROJECT_JAVA, il JDK di questa macchina e' Java $JDK_VERSION: li allineo."
  step set-java.sh
else
  echo "  Java $PROJECT_JAVA: lo stesso del JDK di questa macchina."
fi

# 1. Il nome del progetto
DEMO_NAME="$(basename "$(demo_dir)")"
ask_text 'Come si chiama la cartella con i moduli Maven?' "$DEMO_NAME" '^[a-z][a-z0-9-]*$' \
  'La cartella che oggi contiene pom.xml e docker-compose.yml'
PROJECT_NAME="$ANSWER"
if [ "$PROJECT_NAME" != "$DEMO_NAME" ]; then
  step rename-project.sh --name "$PROJECT_NAME"
fi

# 1-bis. Il pacchetto Java
BASE_PACKAGE="$(base_package "$(demo_dir)")"
ask_text 'Pacchetto Java di base' "$BASE_PACKAGE" '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$' \
  "Ogni modulo stara' in src/main/java/<pacchetto>/<modulo>/; oggi: src/main/java/$(printf '%s' "$BASE_PACKAGE" | tr '.' '/')/"
if [ "$ANSWER" != "$BASE_PACKAGE" ]; then
  step set-package.sh --package "$ANSWER"
fi

# 2. Il database
USE_POSTGRES=0
if ask_yesno 'Il progetto usa PostgreSQL? (altrimenti resta H2 in memoria)' s; then
  ask_text 'Nome del database' 'esame' '^[a-z][a-z0-9_]*$';  DB_NAME="$ANSWER"
  ask_text 'Utente del database' 'exam' '^[a-z][a-z0-9_]*$'; DB_USER="$ANSWER"
  ask_text 'Password' 'exam' '^[A-Za-z0-9_]+$';               DB_PASSWORD="$ANSWER"
  FREE_PORT="$(free_postgres_port)"
  if [ "$FREE_PORT" != "5432" ]; then
    PORT_HINT="La 5432 su questo PC e' gia' occupata: ti propongo la $FREE_PORT"
  else
    PORT_HINT="La porta sul tuo PC: dentro Docker resta sempre 5432"
  fi
  ask_text 'Porta di PostgreSQL' "$FREE_PORT" '^[0-9]{2,5}$' "$PORT_HINT"; DB_PORT="$ANSWER"
  step db-config.sh --db-name "$DB_NAME" --user "$DB_USER" --password "$DB_PASSWORD" --port "$DB_PORT"
  USE_POSTGRES=1
fi

# 3. I microservizi
echo ""
echo "------------------------------------------------------------------"
echo " I MICROSERVIZI"
echo "------------------------------------------------------------------"
echo ""
echo "  Una traccia tipica ne chiede due o tre piu' la UI. Per esempio:"
echo "    ordini-service    i dati e le operazioni sugli ordini"
echo "    magazzino-service la disponibilita', chiamata dal primo via Feign"
echo "    web-ui            le pagine Thymeleaf della demo"
echo ""
echo "  Nome vuoto (solo Invio) quando hai finito."

CREATED=""
while true; do
  echo ""
  echo "  Nome del microservizio (Invio per finire)"
  read_answer "  >"; NAME="$REPLY_TEXT"
  NAME="$(echo "$NAME" | tr -d '[:space:]')"
  [ -z "$NAME" ] && break
  printf '%s' "$NAME" | grep -qE '^[a-z][a-z0-9-]*$' || {
    echo "  Minuscole, numeri e trattini. Riprova."; continue; }

  if [ "$USE_POSTGRES" -eq 0 ]; then
    # Senza PostgreSQL nel progetto, il sotto-wizard non deve proporlo.
    if [ ! -f "$(demo_dir)/$NAME/pom.xml" ]; then
      ask_choice "Che cos'e' $NAME?" 1 \
        'servizio REST con database H2' \
        'servizio REST senza database' \
        'interfaccia web Thymeleaf'
      args=(--name "$NAME")
      [ "$CHOICE" = "2" ] && args+=(--no-db)
      [ "$CHOICE" = "3" ] && args+=(--ui)
      step new-service.sh "${args[@]}"
    fi
  else
    service_wizard "$NAME"
  fi
  CREATED="$CREATED $NAME"
done

# 4. La prova del nove
echo ""
echo "------------------------------------------------------------------"
echo ""
bash "$SCRIPT_DIR/check.sh" --project-only

echo ""
echo "Progetto montato."
echo ""
if [ -n "${CREATED// /}" ]; then
  echo "  Moduli creati:$CREATED"
  echo ""
fi
echo "  Adesso, nell'ordine:"
echo ""
echo "   1. Genera entity e CRUD:      task new-entity SERVICE=<modulo> NAME=<Nome> FIELDS=..."
echo "   2. Client Feign e DTO:        task new-client FROM=<ui> TO=<backend> DTO=<NomeDto> [FIELDS=...]"
echo "   3. Vista Thymeleaf (se UI):   task new-view SERVICE=<ui> NAME=<Nome> FIELDS=..."
echo "   4. Errori / Sicurezza:        task new-handler SERVICE=<modulo> | task new-auth"
echo "   5. Dati di prova e avvio:     task seed-data && task dev"
echo "   6. Schema ER e Consegna:      task db-schema && task consegna NOME=COGNOME_NOME"
echo ""
echo "  task help per tutti i dettagli e gli esempi."
echo ""
