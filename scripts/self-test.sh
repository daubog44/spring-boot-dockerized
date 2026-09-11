#!/usr/bin/env bash
# Collauda gli strumenti del template su una copia usa-e-getta del progetto.
# Equivalente POSIX di scripts/self-test.ps1: stesse prove, sugli script .sh.
#
#   task test
#   task test FULL=1     compila anche il modulo generato, con Maven
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FULL=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Full|--full) FULL=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/esame-selftest-XXXXXX")"
SB_SCRIPTS="$SANDBOX/scripts"
DEMO="$SANDBOX/demo"

echo ""
echo "COLLAUDO DEGLI STRUMENTI"
echo "  copia di prova: $SANDBOX"
echo ""

# La copia esclude quello che non serve alle prove e pesa (build, git, log).
tar -cf - -C "$REPO_ROOT" \
  --exclude=target --exclude=.git --exclude=.dev-logs \
  --exclude=node_modules --exclude=.task --exclude=consegna . | tar -xf - -C "$SANDBOX"

PASSED=0
FAILED=""
SKIPPED=0
CURRENT=""
FAILURE=""

# --- Piccola libreria di prova ------------------------------------------------

TOOL_OUT=""
TOOL_CODE=0
run_tool() { # script, argomenti...
  local script="$1"; shift
  TOOL_OUT="$(bash "$SB_SCRIPTS/$script" "$@" 2>&1)"
  TOOL_CODE=$?
}

fail() { FAILURE="$1"; return 1; }

assert_file() { [ -e "$SANDBOX/$1" ] || fail "manca $1"; }
assert_no_file() { [ -e "$SANDBOX/$1" ] && fail "$1 non doveva esserci"; return 0; }
assert_contains() { grep -qF -- "$2" "$SANDBOX/$1" || fail "${3:-$1}: non trovo '$2'"; }
assert_not_contains() { grep -qF -- "$2" "$SANDBOX/$1" && fail "${3:-$1}: trovato invece '$2'"; return 0; }
assert_ok() { [ "$TOOL_CODE" -eq 0 ] || fail "${1:-il comando}: exit $TOOL_CODE
$TOOL_OUT"; }
assert_fails() { [ "$TOOL_CODE" -ne 0 ] || fail "${1:-il comando} doveva fallire e invece e' andato bene"; }
assert_out_contains() { printf '%s' "$TOOL_OUT" | grep -qF -- "$1" || fail "l'output non contiene '$1'"; }

start_case() { CURRENT="$1"; FAILURE=""; }
end_case() {
  if [ -z "$FAILURE" ]; then
    printf '  OK    %s\n' "$CURRENT"
    PASSED=$((PASSED + 1))
  else
    printf '  FALLITO  %s\n' "$CURRENT"
    printf '%s\n' "$FAILURE" | sed 's/^/           /'
    FAILED="$FAILED$CURRENT; "
  fi
}

# --- Le prove -----------------------------------------------------------------

start_case "il progetto di partenza e' coerente (task check)"
run_tool check.sh --project-only && assert_ok "task check"
end_case

start_case "new-service crea il modulo e lo collega ovunque"
run_tool new-service.sh --name alfa-service
assert_ok "new-service" &&
  assert_file demo/alfa-service/pom.xml &&
  assert_file demo/alfa-service/src/main/java/com/example/ttfcloud_esame/alfaservice/Main.java &&
  assert_file demo/alfa-service/src/main/resources/application.yml &&
  assert_contains demo/alfa-service/pom.xml "<artifactId>alfa-service</artifactId>" &&
  assert_contains demo/pom.xml "<module>alfa-service</module>" &&
  assert_contains demo/Dockerfile "COPY alfa-service/pom.xml" &&
  assert_contains demo/docker-compose.yml "MODULE: alfa-service" &&
  assert_contains scripts/dev.ps1 "Module = 'alfa-service'" &&
  assert_contains scripts/dev.sh ":alfa-service:" &&
  # Un nome fisso farebbe scontrare due copie del progetto sulla stessa macchina.
  { grep -qE '^[[:space:]]+container_name:' "$DEMO/docker-compose.yml" && fail "il compose non deve fissare i nomi dei container"; true; } &&
  # Ogni dipendenza sulla sua riga: e' un file che si consegna.
  assert_not_contains demo/alfa-service/pom.xml "</dependency>        <dependency>" "il pom del modulo" &&
  # Senza queste due, le prime chiamate Feign dopo l'avvio falliscono per
  # 30-60 secondi ("Load balancer does not contain an instance").
  assert_contains demo/alfa-service/src/main/resources/application.yml "registry-fetch-interval-seconds: 5" "il registro di Eureka" &&
  assert_contains demo/alfa-service/src/main/resources/application.yml "ttl: 5s" "la cache del load balancer"
end_case

start_case "il modulo nuovo e' coerente (task check)"
run_tool check.sh --project-only && assert_ok "task check dopo new-service"
end_case

start_case "new-service UI=1 genera Thymeleaf e la pagina, senza JPA"
run_tool new-service.sh --name beta-ui --ui
assert_ok "new-service --ui" &&
  assert_contains demo/beta-ui/pom.xml "spring-boot-starter-thymeleaf" &&
  assert_not_contains demo/beta-ui/pom.xml "spring-boot-starter-data-jpa" &&
  assert_file demo/beta-ui/src/main/resources/templates/index.html &&
  assert_not_contains demo/beta-ui/src/main/resources/application.yml "datasource"
end_case

start_case "new-service NODB=1 lascia fuori database e driver"
run_tool new-service.sh --name gamma-service --no-db
assert_ok "new-service --no-db" &&
  assert_not_contains demo/gamma-service/pom.xml "spring-boot-starter-data-jpa" &&
  assert_not_contains demo/gamma-service/pom.xml "<artifactId>h2</artifactId>" &&
  assert_not_contains demo/gamma-service/pom.xml "<artifactId>postgresql</artifactId>"
end_case

start_case "new-service assegna porte diverse a moduli diversi"
ports="$(for m in alfa-service beta-ui gamma-service; do
  grep -oE 'SERVER_PORT:[0-9]+' "$DEMO/$m/src/main/resources/application.yml" | head -n 1 | cut -d: -f2
done)"
[ "$(printf '%s\n' "$ports" | sort -u | grep -c '.')" -eq 3 ] || fail "porte assegnate: $(printf '%s' "$ports" | tr '\n' ' ')"
end_case

start_case "new-service rifiuta un modulo che esiste gia'"
run_tool new-service.sh --name alfa-service
assert_fails "new-service su un modulo esistente"
end_case

start_case "new-service rifiuta un nome non valido"
run_tool new-service.sh --name Alfa_Service
assert_fails "new-service con un nome non valido"
end_case

start_case "new-service senza NAME spiega come si usa"
run_tool new-service.sh
assert_fails "new-service senza nome" && assert_out_contains "task new-service NAME="
end_case

start_case "add-dep aggiunge dal catalogo"
run_tool add-dep.sh --module alfa-service --deps security,mail
assert_ok "add-dep" &&
  assert_contains demo/alfa-service/pom.xml "spring-boot-starter-security" &&
  assert_contains demo/alfa-service/pom.xml "spring-boot-starter-mail"
end_case

start_case "add-dep non duplica quello che c'e' gia'"
run_tool add-dep.sh --module alfa-service --deps security
if assert_ok "la seconda add-dep"; then
  n="$(grep -c '<artifactId>spring-boot-starter-security</artifactId>' "$DEMO/alfa-service/pom.xml")"
  [ "$n" -eq 1 ] || fail "security compare $n volte nel pom"
fi
end_case

start_case "add-dep accetta le coordinate per esteso"
run_tool add-dep.sh --module alfa-service --deps org.apache.commons:commons-lang3:3.17.0
assert_ok "add-dep con coordinate" &&
  assert_contains demo/alfa-service/pom.xml "<artifactId>commons-lang3</artifactId>" &&
  assert_contains demo/alfa-service/pom.xml "<version>3.17.0</version>"
end_case

start_case "add-dep rifiuta un nome sconosciuto e non tocca il pom"
before="$(cat "$DEMO/alfa-service/pom.xml")"
run_tool add-dep.sh --module alfa-service --deps non-esiste-questa
if assert_fails "add-dep con una dipendenza inventata"; then
  [ "$before" = "$(cat "$DEMO/alfa-service/pom.xml")" ] || fail "il pom e' stato modificato lo stesso"
fi
end_case

start_case "add-dep salta devtools, che e' gia' nel pom padre"
before="$(cat "$DEMO/alfa-service/pom.xml")"
run_tool add-dep.sh --module alfa-service --deps devtools
if assert_ok "add-dep devtools"; then
  [ "$before" = "$(cat "$DEMO/alfa-service/pom.xml")" ] || fail "ha aggiunto devtools al modulo"
fi
end_case

start_case "add-dep LIST=1 elenca il catalogo"
run_tool add-dep.sh --list
assert_ok "add-dep --list" && assert_out_contains "data-jpa" && assert_out_contains "feign"
end_case

start_case "set-port sposta la porta in tutti i file"
run_tool set-port.sh --module alfa-service --port 8199
if assert_ok "set-port" &&
  assert_contains demo/alfa-service/src/main/resources/application.yml "SERVER_PORT:8199" &&
  assert_contains demo/docker-compose.yml "SERVER_PORT: 8199" &&
  assert_contains demo/docker-compose.yml '"8199:8199"' &&
  assert_contains scripts/dev.ps1 "Port = 8199" &&
  assert_contains scripts/dev.sh ":alfa-service:8199"; then
  run_tool check.sh --project-only && assert_ok "task check dopo set-port"
fi
end_case

start_case "set-port rifiuta una porta gia' occupata"
run_tool set-port.sh --module gamma-service --port 8199
assert_fails "set-port su una porta occupata"
end_case

start_case "set-port su Eureka aggiorna chi lo cerca"
run_tool set-port.sh --module naming-server --port 8762
if assert_ok "set-port su naming-server" &&
  assert_contains demo/alfa-service/src/main/resources/application.yml "localhost:8762" &&
  assert_contains demo/docker-compose.yml "eureka-server:8762" &&
  assert_not_contains demo/docker-compose.yml "localhost:8761/actuator"; then
  run_tool check.sh --project-only && assert_ok "task check dopo aver spostato Eureka"
fi
end_case

start_case "enable-swagger e' idempotente su un modulo che ce l'ha gia'"
before="$(cat "$DEMO/alfa-service/pom.xml")"
run_tool enable-swagger.sh --module alfa-service
if assert_ok "enable-swagger"; then
  [ "$before" = "$(cat "$DEMO/alfa-service/pom.xml")" ] || fail "ha toccato un pom che era gia' a posto"
  assert_out_contains "gia' presente"
fi
end_case

start_case "enable-swagger rimette springdoc dove manca"
# Simuliamo un modulo scritto a mano: via il blocco <dependency> di springdoc
# dal pom e il blocco springdoc: dallo yml.
awk '
  /<dependency>/ { inb = 1; buf = $0 "\n"; next }
  inb {
    buf = buf $0 "\n"
    if (/<\/dependency>/) { inb = 0; if (buf !~ /springdoc/) printf "%s", buf }
    next
  }
  { print }
' "$DEMO/beta-ui/pom.xml" >"$DEMO/beta-ui/pom.tmp" && mv "$DEMO/beta-ui/pom.tmp" "$DEMO/beta-ui/pom.xml"
sed -n '/^springdoc:/q;p' "$DEMO/beta-ui/src/main/resources/application.yml" >"$DEMO/beta-ui/yml.tmp" &&
  mv "$DEMO/beta-ui/yml.tmp" "$DEMO/beta-ui/src/main/resources/application.yml"

run_tool enable-swagger.sh --module beta-ui
assert_ok "enable-swagger" &&
  assert_contains demo/beta-ui/pom.xml "<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>" &&
  assert_contains demo/beta-ui/src/main/resources/application.yml "swagger-ui:"
end_case

start_case "use-postgres collega il modulo al database condiviso"
run_tool use-postgres.sh --module alfa-service
if assert_ok "use-postgres" &&
  assert_contains demo/alfa-service/src/main/resources/application.yml "jdbc:postgresql://localhost:5432/" &&
  assert_not_contains demo/alfa-service/src/main/resources/application.yml "jdbc:h2:mem" &&
  assert_contains demo/docker-compose.yml "jdbc:postgresql://postgres:5432/" &&
  assert_contains demo/alfa-service/pom.xml "<artifactId>postgresql</artifactId>" &&
  assert_contains scripts/dev.sh "USES_POSTGRES=1"; then
  run_tool check.sh --project-only && assert_ok "task check dopo use-postgres"
fi
end_case

start_case "use-postgres con DBNAME crea il database dedicato"
run_tool use-postgres.sh --module beta-ui --db-name betadb
assert_ok "use-postgres con DBNAME" &&
  assert_file demo/postgres-init/create-betadb.sql &&
  assert_contains demo/postgres-init/create-betadb.sql "CREATE DATABASE betadb" &&
  assert_contains demo/docker-compose.yml "postgres-init:/docker-entrypoint-initdb.d" &&
  assert_contains demo/beta-ui/src/main/resources/application.yml "betadb"
end_case

start_case "use-postgres rifiuta un modulo che non esiste"
run_tool use-postgres.sh --module questo-non-esiste
assert_fails "use-postgres su un modulo inventato"
end_case

start_case "remove-service toglie il modulo da tutti i file"
run_tool remove-service.sh --module gamma-service
if assert_ok "remove-service" &&
  assert_no_file demo/gamma-service &&
  assert_not_contains demo/pom.xml "<module>gamma-service</module>" &&
  assert_not_contains demo/Dockerfile "COPY gamma-service/pom.xml" &&
  assert_not_contains demo/docker-compose.yml "MODULE: gamma-service" &&
  assert_not_contains scripts/dev.ps1 "Module = 'gamma-service'" &&
  assert_not_contains scripts/dev.sh ":gamma-service:"; then
  run_tool check.sh --project-only && assert_ok "task check dopo remove-service"
fi
end_case

start_case "remove-service rifiuta un modulo che non esiste"
run_tool remove-service.sh --module questo-non-esiste
assert_fails "remove-service su un modulo inventato"
end_case

# --- La configurazione degli editor ------------------------------------------

start_case "new-service mette il modulo nuovo nel launch.json"
LAUNCH=".vscode/launch.json"
assert_contains "$LAUNCH" '"projectName": "alfa-service"' "le configurazioni di debug"
assert_contains "$LAUNCH" '"projectName": "naming-server"' "le configurazioni di debug"
assert_contains "$LAUNCH" 'Stack completo' "il compound che li avvia tutti"
# La classe Main deve essere quella vera, o il debug parte e non trova niente.
assert_contains "$LAUNCH" 'com.example.ttfcloud_esame.alfaservice.Main' "la classe Main"
# common-dto e' una libreria: non si avvia.
assert_not_contains "$LAUNCH" '"projectName": "common-dto"' "una libreria non va fra le configurazioni di avvio"
# Zed ha il suo file, con l'adattatore della sua estensione Java.
assert_contains ".zed/debug.json" '"projectName": "alfa-service"' "il debug.json di Zed"
assert_contains ".zed/debug.json" '"adapter": "Java"' "il debug.json di Zed"
assert_contains ".zed/debug.json" 'com.example.ttfcloud_esame.alfaservice.Main' "la classe Main nel debug.json"
assert_not_contains ".zed/debug.json" '"projectName": "common-dto"' "una libreria non va nel debug.json"
end_case

start_case "i file degli editor sono JSON validi"
# I file di configurazione degli editor ammettono i commenti //: li togliamo
# prima di darli al parser.
if command -v python3 >/dev/null 2>&1; then
  for f in .vscode/launch.json .vscode/tasks.json .vscode/settings.json .zed/tasks.json .zed/debug.json .zed/settings.json; do
    python3 -c "
import io, json, re, sys
t = io.open(sys.argv[1], encoding='utf-8').read()
json.loads(re.sub(r'^\s*//.*$', '', t, flags=re.M))
" "$SANDBOX/$f" 2>/dev/null || fail "$f non e' JSON valido"
  done
else
  echo "        (python3 non c'e': validazione JSON saltata)"
fi
end_case

start_case "remove-service toglie il modulo anche dal launch.json"
run_tool new-service.sh --name delta-service
assert_ok "new-service"
assert_contains ".vscode/launch.json" '"projectName": "delta-service"' "il launch.json"
run_tool remove-service.sh --module delta-service
assert_ok "remove-service"
assert_not_contains ".vscode/launch.json" 'delta-service' "il launch.json"
assert_not_contains ".zed/debug.json" 'delta-service' "il debug.json di Zed"
end_case

start_case "set-port aggiorna la porta scritta nel launch.json"
run_tool set-port.sh --module alfa-service --port 8399
assert_ok "set-port"
assert_contains ".vscode/launch.json" 'alfa-service (:8399)' "il launch.json"
assert_contains ".zed/debug.json" 'alfa-service (:8399)' "il debug.json di Zed"
end_case

start_case "check si accorge se il launch.json e' rimasto indietro"
cp "$SANDBOX/.vscode/launch.json" "$SANDBOX/.vscode/launch.json.bak"
sed -i 's/"projectName": "alfa-service"/"projectName": "servizio-fantasma"/' "$SANDBOX/.vscode/launch.json"
run_tool check.sh --project-only
assert_fails "check con un modulo fantasma nel launch.json"
assert_out_contains "task ide-sync"
mv "$SANDBOX/.vscode/launch.json.bak" "$SANDBOX/.vscode/launch.json"
run_tool check.sh --project-only
assert_ok "check dopo aver rimesso a posto il launch.json"
end_case

# --- Database: credenziali, dati di prova, schema ----------------------------

start_case "db-config stampa la configurazione del database"
run_tool db-config.sh
assert_ok "db-config senza variabili"
# Il nome del database cambia da un branch all'altro: lo leggiamo dal compose.
dbnow="$(grep -E '^[[:space:]]+POSTGRES_DB:' "$DEMO/docker-compose.yml" | head -n 1 | awk '{print $2}')"
assert_out_contains "$dbnow"
assert_out_contains "alfa-service"
end_case

start_case "db-config cambia le credenziali dappertutto"
run_tool db-config.sh --db-name collaudo --user tester --password segreta --port 5544
assert_ok "db-config"
assert_contains "demo/docker-compose.yml" "POSTGRES_DB: collaudo" "il container"
assert_contains "demo/docker-compose.yml" "POSTGRES_USER: tester" "il container"
assert_contains "demo/docker-compose.yml" "pg_isready -U tester -d collaudo" "la healthcheck"
assert_contains "demo/docker-compose.yml" '"5544:5432"' "la porta pubblicata"
assert_contains "demo/docker-compose.yml" "jdbc:postgresql://postgres:5432/collaudo" "il modulo nel compose"
assert_contains "demo/alfa-service/src/main/resources/application.yml" "jdbc:postgresql://localhost:5544/collaudo" "application.yml"
assert_contains "demo/alfa-service/src/main/resources/application.yml" "_DB_USERNAME:tester}" "application.yml"
assert_contains "demo/postgres-init/create-betadb.sql" "TO tester;" "la GRANT del database dedicato"
run_tool check.sh --project-only
assert_ok "task check dopo db-config"
end_case

start_case "db-config rifiuta un valore che PostgreSQL non accetterebbe"
run_tool db-config.sh --db-name "non valido!"
assert_fails "db-config con un nome impossibile"
end_case

# --- Il wizard ----------------------------------------------------------------
# Le risposte gliele diamo da un file (WIZARD_ANSWERS), una per riga: una riga
# vuota vale come Invio.

start_case "il wizard senza terminale si rifiuta invece di restare appeso"
TOOL_OUT="$(bash "$SB_SCRIPTS/wizard.sh" </dev/null 2>&1)"; TOOL_CODE=$?
assert_fails "il wizard senza terminale"
assert_out_contains "terminale vero"
end_case

start_case "il wizard si ferma se le risposte finiscono prima delle domande"
: >"$SANDBOX/risposte-corte.txt"
TOOL_OUT="$(WIZARD_ANSWERS="$SANDBOX/risposte-corte.txt" bash "$SB_SCRIPTS/wizard.sh" </dev/null 2>&1)"; TOOL_CODE=$?
assert_fails "il wizard con le risposte finite"
assert_out_contains "risposte sono finite"
end_case

start_case "il wizard monta database e servizi rispondendo alle domande"
# cartella invariata; PostgreSQL con credenziali e porta; un servizio REST con
# il database condiviso; un'interfaccia web senza Swagger; Invio per finire.
printf '%s\n' \
  '' \
  s wizdb wiz wizpass 5439 \
  omega-service 1 '' 2 \
  sigma-ui 3 '' n \
  '' >"$SANDBOX/risposte.txt"
TOOL_OUT="$(WIZARD_ANSWERS="$SANDBOX/risposte.txt" bash "$SB_SCRIPTS/wizard.sh" </dev/null 2>&1)"; TOOL_CODE=$?
assert_ok "il wizard"
assert_contains "demo/docker-compose.yml" "POSTGRES_DB: wizdb" "il database scelto"
assert_contains "demo/docker-compose.yml" '"5439:5432"' "la porta scelta"
assert_contains "demo/omega-service/src/main/resources/application.yml" "jdbc:postgresql://localhost:5439/wizdb" "il servizio sul database condiviso, sulla porta scelta"
assert_file "demo/sigma-ui/src/main/resources/templates/index.html"
assert_contains ".vscode/launch.json" '"projectName": "omega-service"' "il launch.json"
assert_contains ".zed/debug.json" '"projectName": "sigma-ui"' "il debug.json di Zed"
run_tool check.sh --project-only
assert_ok "task check dopo il wizard"
end_case

# Da qui in poi serve un dominio con delle @Entity: lo scriviamo noi.
ENTITY_DIR="$DEMO/alfa-service/src/main/java/com/example/ttfcloud_esame/alfaservice"
cat >"$ENTITY_DIR/DepositoEntity.java" <<'JAVA'
package com.example.ttfcloud_esame.alfaservice;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class DepositoEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String citta;
}
JAVA
cat >"$ENTITY_DIR/StatoArticolo.java" <<'JAVA'
package com.example.ttfcloud_esame.alfaservice;

public enum StatoArticolo { DISPONIBILE, ESAURITO }
JAVA
cat >"$ENTITY_DIR/ArticoloEntity.java" <<'JAVA'
package com.example.ttfcloud_esame.alfaservice;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "articoli")
public class ArticoloEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 80)
    private String nome;

    private Integer quantita;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private StatoArticolo stato;

    @ManyToOne
    @JoinColumn(name = "deposito_id")
    private DepositoEntity deposito;
}
JAVA

# Nome e cognome, un anno, un id che punta a un altro servizio: i valori
# devono sembrare veri, non "nome 1", 10, 20.
cat >"$ENTITY_DIR/SocioEntity.java" <<'JAVA'
package com.example.ttfcloud_esame.alfaservice;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class SocioEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String nome;
    private String cognome;
    private Integer annoIscrizione;
    private Long tesseraId;
}
JAVA

start_case "seed-data ricava le INSERT dalle @Entity"
run_tool seed-data.sh --module alfa-service --rows 3
assert_ok "seed-data"
SQL="demo/alfa-service/src/main/resources/data.sql"
# Senza @Table il nome della tabella e' quello della classe, suffisso compreso:
# e' cosi' che la chiama Hibernate.
assert_contains "$SQL" "INSERT INTO deposito_entity" "la tabella senza @Table"
assert_contains "$SQL" "INSERT INTO articoli (nome, quantita, stato, deposito_id)" "le colonne (la PK generata non va scritta)"
assert_contains "$SQL" "DISPONIBILE" "gli enum dal file Java"
# Ogni riga scatta solo se la tabella non e' ancora piena: un riavvio su
# PostgreSQL non la duplica e una colonna unique non fa fallire l'avvio.
assert_contains "$SQL" "WHERE (SELECT COUNT(*) FROM articoli) < 3;" "le INSERT si ripeterebbero a ogni avvio"
assert_contains "$SQL" "INSERT INTO socio_entity (nome, cognome, anno_iscrizione, tessera_id) SELECT 'Mario', 'Rossi', 2017, 1 WHERE (SELECT COUNT(*) FROM socio_entity) < 1;" "nome, cognome, anno e id verosimili"
# La tabella padre va riempita prima, o la chiave esterna punterebbe a niente.
riga_deposito="$(grep -n 'INSERT INTO deposito_entity' "$SANDBOX/$SQL" | head -n 1 | cut -d: -f1)"
riga_articolo="$(grep -n 'INSERT INTO articoli' "$SANDBOX/$SQL" | head -n 1 | cut -d: -f1)"
[ -n "$riga_deposito" ] && [ -n "$riga_articolo" ] && [ "$riga_deposito" -lt "$riga_articolo" ] ||
  fail "le righe figlie vengono prima di quelle padre"
righe="$(grep -c 'INSERT INTO articoli' "$SANDBOX/$SQL")"
[ "$righe" = "3" ] || fail "ROWS=3 ha prodotto $righe righe"
# Senza queste due proprieta' il file non verrebbe eseguito.
assert_contains "demo/alfa-service/src/main/resources/application.yml" "defer-datasource-initialization: true" "application.yml"
assert_contains "demo/alfa-service/src/main/resources/application.yml" "mode: always" "application.yml"
end_case

start_case "seed-data non ripete i valori quando le righe superano la tabella"
# Le tabelle di valori hanno otto voci: oltre l'ottava riga il valore deve
# portarsi dietro il numero, o una colonna unique = true farebbe fallire l'avvio.
run_tool seed-data.sh --module alfa-service --rows 12
assert_ok "seed-data con 12 righe"
tot="$(grep -c '^INSERT INTO articoli' "$SANDBOX/$SQL")"
# Il conteggio in fondo cambia da riga a riga: confrontiamo solo i valori.
uniche="$(grep '^INSERT INTO articoli' "$SANDBOX/$SQL" | sed 's/ WHERE .*$//' | sort -u | wc -l)"
[ "$tot" = "12" ] || fail "righe generate: $tot"
[ "$uniche" = "12" ] || fail "righe uguali fra loro: $(( tot - uniche ))"
end_case

start_case "db-schema ricava tabelle e relazioni dalle @Entity"
run_tool db-schema.sh
assert_ok "db-schema"
assert_out_contains "Modello concettuale"
assert_out_contains "Modello logico"
assert_out_contains 'Tabella `articoli`'
assert_out_contains 'Tabella `deposito_entity`'
assert_out_contains "erDiagram"
assert_out_contains "FK"
assert_out_contains '| `stato` | VARCHAR(20) |'
end_case

start_case "consegna prepara un archivio che parte appena scompattato"
run_tool consegna.sh --nome ROSSI_MARIO
assert_ok "consegna"
ZIP="$SANDBOX/consegna/ROSSI_MARIO.zip"
DEST="$SANDBOX/consegna-scompattata"
if [ ! -f "$ZIP" ]; then
  fail "manca consegna/ROSSI_MARIO.zip"
else
  # Scompattato come farebbe chi corregge, e poi quello che la build cerca:
  # i moduli del pom aggregatore e i pom che il Dockerfile copia.
  mkdir -p "$DEST"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$ZIP" -d "$DEST"
  else
    (cd "$DEST" && jar xf "$ZIP")
  fi
  for f in docker-compose.yml Dockerfile pom.xml mvnw .mvn/wrapper/maven-wrapper.properties ALLEGATO-TECNICO.md ISTRUZIONI-ESECUZIONE.md SCHEMA-DATABASE.md; do
    [ -e "$DEST/$f" ] || fail "scompattato l'archivio, manca $f accanto al compose"
  done
  for mod in $(grep -oE '<module>[^<]+</module>' "$DEST/pom.xml" | sed -E 's#</?module>##g'); do
    [ -f "$DEST/$mod/pom.xml" ] || fail "il pom aggregatore cerca $mod/pom.xml, che non c'e'"
    [ -d "$DEST/$mod/src" ] || fail "mancano i sorgenti di $mod"
  done
  for p in $(grep -oE '^COPY[[:space:]]+[^[:space:]]+/pom\.xml' "$DEST/Dockerfile" | awk '{print $2}'); do
    [ -f "$DEST/$p" ] || fail "il Dockerfile copia $p, che non c'e'"
  done
  [ -z "$(find "$DEST" -type d -name target)" ] || fail "nella consegna ci sono cartelle target/"
  [ -z "$(find "$DEST" -type f -name '*.zip')" ] || fail "archivi dentro l'archivio"
  grep -q 'Scompatta ogni archivio' "$DEST/ISTRUZIONI-ESECUZIONE.md" && fail "le istruzioni chiedono ancora di ricomporre il progetto"
  rm -rf "$DEST"
fi
end_case

# Questa cambia il nome della cartella dei moduli: va per ultima.
start_case "rename-project rinomina la cartella e i file che la nominano"
# Un modulo che comincia con il nome della cartella (biblioteca e
# biblioteca-ui) non deve essere rinominato insieme a lei.
OMONIMO="$(basename "$DEMO")-extra"
run_tool new-service.sh --name "$OMONIMO" --no-db
assert_ok "new-service del modulo omonimo"
run_tool rename-project.sh --name collaudo-modules
assert_ok "rename-project"
assert_file "collaudo-modules/pom.xml"
assert_no_file "demo"
assert_contains "Taskfile.yml" "dir: collaudo-modules" "il Taskfile"
assert_contains "scripts/check.sh" "/collaudo-modules" "gli script"
assert_file "collaudo-modules/$OMONIMO/pom.xml"
assert_contains "scripts/dev.sh" ":$OMONIMO:" "il modulo $OMONIMO rinominato insieme alla cartella"
run_tool check.sh --project-only
assert_ok "task check dopo rename-project"
end_case

start_case "gli script POSIX hanno sintassi valida"
bad=""
for f in "$SB_SCRIPTS"/*.sh; do
  bash -n "$f" 2>/dev/null || bad="$bad $(basename "$f")"
done
[ -z "$bad" ] || fail "sintassi non valida in:$bad"
end_case

if [ "$FULL" = "1" ]; then
  start_case "il modulo generato compila (Maven)"
  (cd "$DEMO" && ./mvnw -q -pl alfa-service -am install -Dmaven.test.skip=true) >/dev/null 2>&1 ||
    fail "la compilazione del modulo generato e' fallita"
  end_case
fi

# --- Esito --------------------------------------------------------------------

echo ""
if [ -z "$FAILED" ]; then
  extra=""
  [ "$SKIPPED" -gt 0 ] && extra=" ($SKIPPED saltate)"
  echo "$PASSED prove superate, nessun fallimento.$extra"
  rm -rf "$SANDBOX"
  echo ""
  exit 0
fi
echo "$PASSED superate, fallite: $FAILED"
echo "La copia di prova resta qui, per guardarci dentro: $SANDBOX"
echo ""
exit 1
