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
  --exclude=node_modules --exclude=.task . | tar -xf - -C "$SANDBOX"

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
run_tool check.sh && assert_ok "task check"
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
run_tool check.sh && assert_ok "task check dopo new-service"
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
  run_tool check.sh && assert_ok "task check dopo set-port"
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
  run_tool check.sh && assert_ok "task check dopo aver spostato Eureka"
fi
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
  run_tool check.sh && assert_ok "task check dopo remove-service"
fi
end_case

start_case "remove-service rifiuta un modulo che non esiste"
run_tool remove-service.sh --module questo-non-esiste
assert_fails "remove-service su un modulo inventato"
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
