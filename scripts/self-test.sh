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
  assert_contains scripts/dev.sh ":alfa-service:"
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
    private StatoArticolo stato;

    @ManyToOne
    @JoinColumn(name = "deposito_id")
    private DepositoEntity deposito;
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

start_case "db-schema ricava tabelle e relazioni dalle @Entity"
run_tool db-schema.sh
assert_ok "db-schema"
assert_out_contains "Modello concettuale"
assert_out_contains "Modello logico"
assert_out_contains 'Tabella `articoli`'
assert_out_contains 'Tabella `deposito_entity`'
assert_out_contains "erDiagram"
assert_out_contains "FK"
end_case

# Questa cambia il nome della cartella dei moduli: va per ultima.
start_case "rename-project rinomina la cartella e i file che la nominano"
run_tool rename-project.sh --name collaudo-modules
assert_ok "rename-project"
assert_file "collaudo-modules/pom.xml"
assert_no_file "demo"
assert_contains "Taskfile.yml" "dir: collaudo-modules" "il Taskfile"
assert_contains "scripts/check.sh" "/collaudo-modules" "gli script"
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
