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
# La copia di prova ha il suo progetto Docker Compose: il nome del progetto vero
# (lo passa task test) non deve arrivarle, se no un suo docker compose
# toccherebbe i tuoi container. Gli script lo ricavano dalla cartella della copia.
unset COMPOSE_PROJECT_NAME
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

# Il pacchetto di un modulo nella copia di prova, come percorso: la base cambia
# da un branch all'altro (e la cambiano il wizard e set-package), quindi la
# leggiamo ogni volta.
. "$SB_SCRIPTS/scaffold-lib.sh"
sb_package_path() { printf '%s/%s' "$(base_package "$DEMO" | tr '.' '/')" "$(printf '%s' "$1" | tr -cd 'a-zA-Z0-9')"; }

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

# Col nome di default (demo) la copia di prova e quella dell'esame si prendevano
# container e volume del database: con credenziali diverse PostgreSQL rifiutava
# la seconda ("password authentication failed").
start_case "ogni copia del progetto ha il suo progetto Docker Compose"
NOME_COMPOSE="$(unset COMPOSE_PROJECT_NAME; . "$SB_SCRIPTS/dev-lib.sh"; printf '%s' "$COMPOSE_PROJECT_NAME")"
ATTESO_COMPOSE="$(basename "$SANDBOX" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z0-9]+//')"
{ [ "$NOME_COMPOSE" = "$ATTESO_COMPOSE" ] || fail "progetto Compose '$NOME_COMPOSE' invece di '$ATTESO_COMPOSE'"; } &&
  assert_contains Taskfile.yml "COMPOSE_PROJECT_NAME:" "il Taskfile" &&
  assert_contains demo/.env "COMPOSE_PROJECT_NAME=$ATTESO_COMPOSE" "demo/.env"
end_case

start_case "new-service crea il modulo e lo collega ovunque"
run_tool new-service.sh --name alfa-service
assert_ok "new-service" &&
  assert_file demo/alfa-service/pom.xml &&
  assert_file "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/Main.java" &&
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
  assert_not_contains demo/beta-ui/src/main/resources/application.yml "datasource" &&
  assert_contains demo/beta-ui/src/main/resources/application.yml "tracking-modes: cookie" "la sessione solo nel cookie"
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

start_case "new-entity genera entity, repository, service e controller"
run_tool new-service.sh --name epsilon-service
assert_ok "new-service epsilon-service" &&
run_tool new-entity.sh --service epsilon-service --name Libro \
  --fields "titolo:string(150):required,isbn:string(13):unique,annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,genere:enum(ROMANZO|SAGGIO|GIALLO)" &&
assert_ok "new-entity" &&
EPS_BASE="demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" '@Table(name = "libro")' "il nome tabella non e' quello atteso" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@Column(nullable = false, length = 150)" "required + string(N)" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@Column(unique = true, length = 13)" "unique + string(N)" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@Min(1450)" "manca @Min" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@Max(2100)" "manca @Max" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@NotBlank" "manca @NotBlank" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@NotNull" "manca @NotNull" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "@Enumerated(EnumType.STRING)" "manca @Enumerated" &&
assert_contains "$EPS_BASE/entity/LibroEntity.java" "private Genere genere;" "il tipo del campo enum e' sbagliato" &&
assert_contains "$EPS_BASE/entity/Genere.java" "ROMANZO," "manca un valore dell'enum" &&
assert_contains "$EPS_BASE/entity/Genere.java" "GIALLO" "manca l'ultimo valore dell'enum" &&
assert_contains "$EPS_BASE/repository/LibroRepository.java" "extends JpaRepository<LibroEntity, Long>" "il repository non estende JpaRepository" &&
assert_contains "$EPS_BASE/service/LibroService.java" "ResponseStatusException(HttpStatus.NOT_FOUND" "manca il 404 sul service" &&
assert_contains "$EPS_BASE/service/LibroService.java" "esistente.setTitolo(dati.getTitolo());" "aggiorna() non copia un campo" &&
assert_contains "$EPS_BASE/controller/LibroController.java" '@RequestMapping("/api/libro")' "il percorso REST non e' quello atteso" &&
assert_contains "$EPS_BASE/controller/LibroController.java" "@Valid @RequestBody LibroEntity nuovo" "manca @Valid sulla creazione" &&
assert_contains "$EPS_BASE/controller/LibroController.java" "@ResponseStatus(HttpStatus.CREATED)" "manca il 201 sulla creazione" &&
run_tool check.sh --project-only &&
assert_ok "dopo new-entity il progetto non e' coerente"
end_case

start_case "new-entity rifiuta un modulo senza database"
run_tool new-service.sh --name epsilon-nodb-service --no-db
assert_ok "new-service NoDb" &&
run_tool new-entity.sh --service epsilon-nodb-service --name Cosa &&
assert_fails "ha accettato un modulo NODB=1, che non ha JPA" && assert_out_contains "non ha un database"
end_case

start_case "new-entity rifiuta un'entity che esiste gia'"
run_tool new-entity.sh --service epsilon-service --name Libro --fields "x:int"
assert_fails "ha rigenerato un'entity che esisteva gia'" && assert_out_contains "gia'"
end_case

start_case "new-entity DTO=1 genera entity, dto in common-dto, service con mapper e controller con dto"
run_tool new-entity.sh --service epsilon-service --name Editore --fields "ragioneSociale:string:required,citta:string" --dto
assert_ok "new-entity con --dto" &&
  assert_file "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/EditoreDto.java" &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/service/EditoreService.java" "List<EditoreDto> elenco()" &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/service/EditoreService.java" "public static EditoreDto toDto(EditoreEntity entity)" &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/controller/EditoreController.java" "List<EditoreDto> elenco()"
end_case

start_case "new-entity guidato campo per campo accetta tipo e modificatori dal menu"
run_tool new-service.sh --name wizfields-service
assert_ok "new-service wizfields-service"

# Stesso elenco che new-entity.sh costruisce in modalita' interattiva: la
# risposta al menu dipende da dove finisce il modulo appena creato, non da
# un indice fisso che un'altra prova aggiunta prima potrebbe spostare.
WIZ_JPA_IDX=0
WIZ_I=0
for d in "$DEMO"/*; do
  [ -f "$d/pom.xml" ] || continue
  grep -q 'spring-boot-starter-data-jpa' "$d/pom.xml" || continue
  WIZ_I=$((WIZ_I + 1))
  [ "$(basename "$d")" = "wizfields-service" ] && WIZ_JPA_IDX=$WIZ_I
done

printf '%s\n' \
  "$WIZ_JPA_IDX" \
  Prova \
  1 \
  codice 2 20 1,2 \
  '' \
  durata 9 3,4 1 600 \
  n \
  n >"$SANDBOX/risposte-new-entity.txt"
TOOL_OUT="$(WIZARD_ANSWERS="$SANDBOX/risposte-new-entity.txt" bash "$SB_SCRIPTS/new-entity.sh" </dev/null 2>&1)"; TOOL_CODE=$?
assert_ok "new-entity guidato campo per campo" &&
  assert_file "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" "private String codice;" "tipo string(N) dal menu" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" "@Column(nullable = false, unique = true, length = 20)" "modificatori dal menu" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" "private Integer durata;" "tipo int dal menu" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" "@Min(1)" "min(N) dal menu" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/ProvaEntity.java" "@Max(600)" "max(N) dal menu"
end_case

start_case "new-entity guidato lascia scegliere anche la riga sola, stile FIELDS="
printf '%s\n' \
  "$WIZ_JPA_IDX" \
  Riga \
  2 \
  'codice:string(20):required,descrizione:string:required' \
  n >"$SANDBOX/risposte-new-entity-riga.txt"
TOOL_OUT="$(WIZARD_ANSWERS="$SANDBOX/risposte-new-entity-riga.txt" bash "$SB_SCRIPTS/new-entity.sh" </dev/null 2>&1)"; TOOL_CODE=$?
assert_ok "new-entity riga sola" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/RigaEntity.java" "private String codice;" "campo da riga sola non applicato" &&
  assert_contains "demo/wizfields-service/src/main/java/$(sb_package_path wizfields-service)/entity/RigaEntity.java" "private String descrizione;" "secondo campo da riga sola non applicato"
end_case

start_case "add-relation configura ManyToOne e OneToMany fra due entity"
run_tool add-relation.sh --service epsilon-service --from Libro --to Editore --type many-to-one
assert_ok "add-relation" &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/entity/LibroEntity.java" "@ManyToOne(fetch = FetchType.LAZY)" &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/entity/LibroEntity.java" '@JoinColumn(name = "editore_id")' &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/entity/EditoreEntity.java" '@OneToMany(mappedBy = "editore"' &&
  assert_contains "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/entity/EditoreEntity.java" "private List<LibroEntity> libroList = new ArrayList<>();"
end_case

start_case "new-dto genera record in common-dto con validazione"
# "Volume", non "Libro": su example/biblioteca esiste gia' un vero
# LibroDto.java in common-dto, e il nome collide col progetto reale.
run_tool new-dto.sh --name Volume --fields "id:long,titolo:string(150):required,disponibile:bool"
assert_ok "new-dto" &&
  assert_file "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/VolumeDto.java" &&
  assert_contains "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/VolumeDto.java" "public record VolumeDto" &&
  assert_contains "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/VolumeDto.java" "@Size(max = 150)" &&
  assert_contains "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/VolumeDto.java" "@NotBlank"
end_case

start_case "new-client genera FeignClient collegato al servizio target"
run_tool new-client.sh --from alfa-service --to epsilon-service --dto VolumeDto
assert_ok "new-client" &&
  assert_file "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/client/EpsilonClient.java" &&
  assert_contains "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/client/EpsilonClient.java" '@FeignClient(name = "EPSILON-SERVICE")' &&
  assert_contains "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/client/EpsilonClient.java" "List<VolumeDto> getAll()"
end_case

start_case "new-view genera controller e template thymeleaf nel modulo UI"
run_tool new-view.sh --service beta-ui --name Libri --fields "titolo:string:required,autore:string"
assert_ok "new-view" &&
  assert_file "demo/beta-ui/src/main/java/$(sb_package_path beta-ui)/controller/LibriUiController.java" &&
  assert_file "demo/beta-ui/src/main/resources/templates/libri.html" &&
  assert_contains "demo/beta-ui/src/main/java/$(sb_package_path beta-ui)/controller/LibriUiController.java" "@Controller" &&
  assert_contains "demo/beta-ui/src/main/java/$(sb_package_path beta-ui)/controller/LibriUiController.java" '@RequestMapping("/libri")' &&
  assert_contains "demo/beta-ui/src/main/resources/templates/libri.html" 'xmlns:th="http://www.thymeleaf.org"'
end_case

start_case "new-client crea automaticamente il DTO in common-dto se sono passati FIELDS"
run_tool new-client.sh --from alfa-service --to beta-ui --name BetaClient --dto AutoreDto --fields "nome:string:required"
assert_ok "new-client con FIELDS" &&
  assert_file "demo/common-dto/src/main/java/$(base_package "$DEMO" | tr '.' '/')/common/dto/AutoreDto.java" &&
  assert_file "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/client/BetaClient.java"
end_case

start_case "task new-client (CLI reale, senza ROUTE) non spezza la riga di comando"
# Passa per il Taskfile vero, non per lo script diretto come le altre prove:
# una variabile Task chiamata come una variabile d'ambiente di sistema
# (successo con PATH, prima di diventare ROUTE) viene risolta con quella del
# sistema anche se non la passi, e senza virgolette rompe il parsing di
# mvdan/sh sulla prima parentesi che trova (es. "Program Files (x86)").
if command -v task >/dev/null 2>&1; then
  TASK_OUT="$(cd "$SANDBOX" && task new-client FROM=epsilon-service TO=gamma-service 2>&1)"
  TASK_CODE=$?
  { [ "$TASK_CODE" -eq 0 ] || fail "task new-client FROM=epsilon-service TO=gamma-service: exit $TASK_CODE
$TASK_OUT"; } &&
    assert_file "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/client/GammaClient.java"
else
  echo "        (comando task non trovato sul PATH: prova saltata)"
fi
end_case

start_case "new-auth configura la sicurezza su database (UtenteEntity, Repo, UserDetailsService, BCrypt)"
run_tool new-auth.sh --service epsilon-service --type db
assert_ok "new-auth db" &&
  assert_file "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/entity/UtenteEntity.java" &&
  assert_file "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/repository/UtenteRepository.java" &&
  assert_file "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/service/CustomUserDetailsService.java" &&
  assert_file "demo/epsilon-service/src/main/java/$(sb_package_path epsilon-service)/config/SecurityConfig.java"
end_case

start_case "new-auth configura form login su modulo UI (LoginController, login.html)"
run_tool new-auth.sh --service beta-ui --type form
assert_ok "new-auth form" &&
  assert_file "demo/beta-ui/src/main/java/$(sb_package_path beta-ui)/controller/LoginController.java" &&
  assert_file "demo/beta-ui/src/main/resources/templates/login.html" &&
  assert_contains "demo/beta-ui/src/main/resources/templates/login.html" 'th:action="@{/login}"'
end_case

start_case "new-handler genera GlobalExceptionHandler (@RestControllerAdvice)"
run_tool new-handler.sh --service alfa-service
assert_ok "new-handler" &&
  assert_file "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/controller/GlobalExceptionHandler.java" &&
  assert_contains "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/controller/GlobalExceptionHandler.java" "@RestControllerAdvice" &&
  assert_contains "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/controller/GlobalExceptionHandler.java" "MethodArgumentNotValidException"
end_case

start_case "add-dep aggiunge dal catalogo e crea SecurityConfig se security"
run_tool add-dep.sh --module alfa-service --deps security,mail
assert_ok "add-dep" &&
  assert_contains demo/alfa-service/pom.xml "spring-boot-starter-security" &&
  assert_contains demo/alfa-service/pom.xml "spring-boot-starter-mail" &&
  assert_file "demo/alfa-service/src/main/java/$(sb_package_path alfa-service)/config/SecurityConfig.java"
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
ALFA_MAIN="$(sb_package_path alfa-service | tr '/' '.').Main"
assert_contains "$LAUNCH" "$ALFA_MAIN" "la classe Main"
# common-dto e' una libreria: non si avvia.
assert_not_contains "$LAUNCH" '"projectName": "common-dto"' "una libreria non va fra le configurazioni di avvio"
# Zed ha il suo file, con l'adattatore della sua estensione Java.
assert_contains ".zed/debug.json" '"projectName": "alfa-service"' "il debug.json di Zed"
assert_contains ".zed/debug.json" '"adapter": "Java"' "il debug.json di Zed"
assert_contains ".zed/debug.json" "$ALFA_MAIN" "la classe Main nel debug.json"
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

# --- Java e pacchetto -----------------------------------------------------------

start_case "set-java imposta la versione in pom, Dockerfile e VS Code"
run_tool set-java.sh --version 21
assert_ok "set-java VERSION=21"
assert_contains demo/pom.xml "<java.version>21</java.version>" "il pom"
assert_contains demo/Dockerfile "eclipse-temurin:21-jdk" "l'immagine di build"
assert_contains demo/Dockerfile "eclipse-temurin:21-jre" "l'immagine finale"
assert_contains .vscode/settings.json '"JavaSE-21"' "il runtime di VS Code"
end_case

start_case "set-java rifiuta una versione troppo vecchia per Spring Boot 4"
run_tool set-java.sh --version 11
assert_fails "set-java VERSION=11"
assert_contains demo/pom.xml "<java.version>21</java.version>" "il pom dopo il rifiuto"
end_case

start_case "set-java senza VERSION usa il JDK di questa macchina"
JDK="$(machine_jdk || true)"
if [ -z "$JDK" ]; then
  echo "  SALTATA  $CURRENT -- su questa macchina non c'e' un JDK"
  SKIPPED=$((SKIPPED + 1))
else
  run_tool set-java.sh
  assert_ok "set-java"
  assert_contains demo/pom.xml "<java.version>${JDK%%|*}</java.version>" "il pom segue il JDK della macchina"
  assert_contains .vscode/settings.json "${JDK#*|}" "VS Code punta al JDK della macchina"
  assert_contains Taskfile.yml "${JDK#*|}" "il JDK di ripiego del Taskfile"
  run_tool check.sh --project-only
  assert_ok "task check dopo set-java"
  end_case
fi

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
# cartella invariata; pacchetto it.wiz; PostgreSQL con credenziali e porta; un servizio REST con
# il database condiviso; un'interfaccia web senza Swagger; Invio per finire.
printf '%s\n' \
  '' \
  it.wiz \
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
assert_file "demo/omega-service/src/main/java/it/wiz/omegaservice/Main.java"
assert_file "demo/naming-server/src/main/java/it/wiz/namingserver/Main.java"
assert_contains ".vscode/launch.json" '"projectName": "omega-service"' "il launch.json"
assert_contains ".zed/debug.json" '"projectName": "sigma-ui"' "il debug.json di Zed"
run_tool check.sh --project-only
assert_ok "task check dopo il wizard"
end_case

# Da qui in poi serve un dominio con delle @Entity: il "serraglio" di
# scripts/self-test-entities, con i casi che rompevano i generatori a regex
# (sequenze, UUID, chiavi composte, ereditarieta', @MapsId, @Pattern...).
ALFA_PATH="$(sb_package_path alfa-service)"
ENTITY_DIR="$DEMO/alfa-service/src/main/java/$ALFA_PATH"
ALFA_PKG="$(printf '%s' "$ALFA_PATH" | tr '/' '.')"
ENTITY_COUNT=0
for fixture in "$SB_SCRIPTS"/self-test-entities/*.java.txt; do
  sed "s/__PKG__/$ALFA_PKG/" "$fixture" >"$ENTITY_DIR/$(basename "$fixture" .txt)"
  # Le entity concrete: quante devono riempirsi.
  if grep -q '^@Entity' "$fixture" && ! grep -q 'abstract class' "$fixture"; then ENTITY_COUNT=$((ENTITY_COUNT + 1)); fi
done

start_case "seed-data scrive dev-data.rows e toglie il vecchio data.sql"
OLD_SQL="$DEMO/alfa-service/src/main/resources/data.sql"
printf '%s\n' '-- Dati di prova generati da task seed-data.' 'INSERT INTO x VALUES (1);' >"$OLD_SQL"
run_tool seed-data.sh --module alfa-service --rows 3 --no-check
assert_ok "seed-data --no-check"
[ ! -f "$OLD_SQL" ] || fail "il data.sql della versione vecchia e' rimasto"
run_tool seed-data.sh --module alfa-service --rows 4 --no-check
assert_ok "seed-data rilanciato"
[ "$(grep -c '^dev-data:' "$DEMO/alfa-service/src/main/resources/application.yml")" = "1" ] || fail "dev-data compare piu' di una volta"
assert_contains "demo/alfa-service/src/main/resources/application.yml" "  rows: 4" "il numero di righe aggiornato"
end_case

start_case "seed-data avvisa se lo stack e' gia' acceso (mvnw non si ricompila da solo)"
mkdir -p "$SANDBOX/.dev-logs"
printf '%s\n' "99999 alfa" >"$SANDBOX/.dev-logs/dev.pids"
run_tool seed-data.sh --module alfa-service --rows 3 --no-check
assert_ok "seed-data --no-check con lo stack acceso" &&
  { case "$TOOL_OUT" in *"gia' acceso"*) : ;; *) fail "non avvisa che lo stack e' gia' acceso" ;; esac; } &&
  { case "$TOOL_OUT" in *"task compile"*) : ;; *) fail "non suggerisce task compile" ;; esac; }
rm -f "$SANDBOX/.dev-logs/dev.pids"
end_case

start_case "seed-data riempie ogni tabella passando da Hibernate (Maven + H2)"
run_tool seed-data.sh --module alfa-service --rows 12
assert_ok "seed-data con la prova"
case "$TOOL_OUT" in *ERRORE*) fail "una entity non si e' riempita" ;; esac
assert_out_contains "$ENTITY_COUNT entity riempite"
# Le righe che puntano ad altre arrivano dopo: la tabella di collegamento del
# molti a molti e l'elenco di valori non restano vuoti.
printf '%s' "$TOOL_OUT" | grep -qE 'studente_entity_corsi [1-9]' || fail "la tabella di collegamento e' vuota"
printf '%s' "$TOOL_OUT" | grep -qE 'ordine_entity_etichette [1-9]' || fail "l'@ElementCollection e' vuota"
assert_out_contains "veicolo_entity 24"
end_case

start_case "seed-data SQL=1 scrive un data.sql vero, con INSERT semplici"
run_tool new-service.sh --name sqlseed-service
assert_ok "new-service sqlseed-service"
run_tool new-entity.sh --service sqlseed-service --name Editore --fields 'nome:string(80):required'
assert_ok "new-entity Editore"
run_tool new-entity.sh --service sqlseed-service --name Volume --fields 'titolo:string(150):required,prezzo:decimal,uscita:date,attivo:bool:required'
assert_ok "new-entity Volume"
run_tool add-relation.sh --service sqlseed-service --from Volume --to Editore --type many-to-one
assert_ok "add-relation Volume -> Editore"
run_tool seed-data.sh --module sqlseed-service --rows 3 --sql
assert_ok "seed-data SQL=1" &&
  { case "$TOOL_OUT" in *"data.sql  scritto"*) : ;; *) fail "non conferma di aver scritto data.sql" ;; esac; }
SQLSEED_SQL="$DEMO/sqlseed-service/src/main/resources/data.sql"
SQLSEED_YML="$DEMO/sqlseed-service/src/main/resources/application.yml"
[ -f "$SQLSEED_SQL" ] || fail "manca data.sql"
head -n 1 "$SQLSEED_SQL" | grep -q "data.sql generato da task seed-data SQL=1" || fail "manca l'intestazione che lo marca come generato"
[ "$(grep -c '^INSERT INTO editore' "$SQLSEED_SQL")" = "3" ] || fail "non ci sono 3 INSERT su editore"
[ "$(grep -c '^INSERT INTO volume' "$SQLSEED_SQL")" = "3" ] || fail "non ci sono 3 INSERT su volume"
[ "$(grep -n '^INSERT INTO editore' "$SQLSEED_SQL" | head -n 1 | cut -d: -f1)" -lt "$(grep -n '^INSERT INTO volume' "$SQLSEED_SQL" | head -n 1 | cut -d: -f1)" ] \
  || fail "editore (a cui volume punta con una chiave esterna) non viene prima nel file"
assert_contains "demo/sqlseed-service/src/main/resources/application.yml" "defer-datasource-initialization: true" "manca defer-datasource-initialization"
assert_contains "demo/sqlseed-service/src/main/resources/application.yml" "mode: always" "manca sql.init.mode"
assert_contains "demo/sqlseed-service/src/main/resources/application.yml" "rows: 0" "dev-data.rows non e' stato spento dopo aver scritto data.sql"
end_case

start_case "db-schema legge tabelle, chiavi e vincoli dal database"
# Senza --no-build: sui branch svolti ci sono altri moduli con delle entity,
# che seed-data (limitato ad alfa-service) non ha compilato.
run_tool db-schema.sh
assert_ok "db-schema"
for needle in '## Modulo `alfa-service`' 'Modello concettuale' 'Modello logico' 'erDiagram' \
  'Tabella `articoli`' 'Tabella `deposito_entity`' '| `stato` | VARCHAR(20) |' 'valori ammessi: DISPONIBILE' \
  'generato da Hibernate con una sequenza' 'enum salvato come numero' 'Tabella `studente_entity_corsi`' \
  'Chiave primaria composta' 'una sola tabella per tutta la gerarchia' '**Studente** <-> **Corso**: molti a molti' \
  'riferimento a `deposito_entity`(`id`)' 'DEPOSITO_ENTITY |o--o{ ARTICOLI'; do
  assert_out_contains "$needle"
done
end_case

start_case "set-package sposta i sorgenti e riscrive package, import e mainClass"
OLD_BASE="$(base_package "$DEMO")"
ALFA_OLD="$DEMO/alfa-service/src/main/java/$(sb_package_path alfa-service)"
# Una stringa che nomina la base ma non un suo sottopacchetto: deve restare com'e'.
printf 'package %s.alfaservice;\n\nclass Frase {\n    static final String TESTO = "%s.pdf";\n}\n' "$OLD_BASE" "$OLD_BASE" >"$ALFA_OLD/Frase.java"
run_tool set-package.sh --package it.prova
assert_ok "set-package"
ALFA_NEW="demo/alfa-service/src/main/java/it/prova/alfaservice"
assert_file "$ALFA_NEW/Main.java"
assert_file "$ALFA_NEW/ArticoloEntity.java"
[ -d "$ALFA_OLD" ] && fail "la cartella vecchia e' rimasta"
assert_contains "$ALFA_NEW/ArticoloEntity.java" "package it.prova.alfaservice;" "il package"
assert_contains "$ALFA_NEW/Frase.java" "\"$OLD_BASE.pdf\"" "una stringa che non era un pacchetto"
assert_file "demo/naming-server/src/main/java/it/prova/namingserver/Main.java"
assert_contains demo/naming-server/pom.xml "<mainClass>it.prova.namingserver.Main</mainClass>" "la mainClass del pom"
assert_contains .vscode/launch.json "it.prova.alfaservice.Main" "il launch.json"
VECCHI="$(grep -rlE "^[[:space:]]*(package|import)[[:space:]]+$(printf '%s' "$OLD_BASE" | sed 's/\./\\./g')\." "$DEMO" --include='*.java' 2>/dev/null | grep -v '/target/' || true)"
[ -z "$VECCHI" ] || fail "package o import ancora col pacchetto vecchio: $VECCHI"
run_tool new-service.sh --name zeta-service --no-db
assert_ok "new-service dopo set-package"
assert_file "demo/zeta-service/src/main/java/it/prova/zetaservice/Main.java"
run_tool check.sh --project-only
assert_ok "task check dopo set-package"
end_case

start_case "set-package rifiuta un pacchetto non valido"
run_tool set-package.sh --package It.Prova
assert_fails "set-package con le maiuscole"
run_tool set-package.sh --package it.class
assert_fails "set-package con una parola riservata"
end_case

start_case "rete dice quali domini non passano, senza fallire"
run_tool rete.sh --url http://127.0.0.1:9/ --timeout 3
assert_ok "task rete" && assert_out_contains "NON risponde"
end_case

start_case "offline-prep scarica anche una copia di scorta di task"
{ assert_contains scripts/offline.sh ".tools/task" "offline-prep non prepara una copia di scorta di task" &&
  assert_contains scripts/offline.sh "usa-task-locale.sh" "offline non dice come usare la copia locale"; }
end_case

start_case "usa-task-locale trova ed espone la copia locale di task"
SENZA_COPIA="$(. "$SB_SCRIPTS/usa-task-locale.sh" 2>&1)"
mkdir -p "$SANDBOX/.tools/task"
: > "$SANDBOX/.tools/task/task"
chmod +x "$SANDBOX/.tools/task/task"
# In un sottoshell ($(...)): il PATH aggiornato da "source" non deve
# restare appiccicato allo script di collaudo.
CON_COPIA_PATH="$(. "$SB_SCRIPTS/usa-task-locale.sh" >/dev/null 2>&1; printf '%s' "$PATH")"
{ printf '%s' "$SENZA_COPIA" | grep -qF "offline-prep" || fail "senza una copia locale non spiega come procurarsela"; } &&
  { printf '%s' "$CON_COPIA_PATH" | grep -qF "$SANDBOX/.tools/task" || fail "non aggiunge la copia locale al PATH di questa shell"; }
end_case

start_case "learn raccoglie lezioni, guide e moduli in contenuti.js"
run_tool learn.sh --no-open
JS="$SANDBOX/corso/contenuti.js"
N_LESSONS="$(ls "$SANDBOX/corso/lezioni"/*.md 2>/dev/null | wc -l | tr -d ' ')"
# I testi stanno fra apici inversi: dentro, apici inversi e ${ vanno protetti,
# altrimenti il JavaScript si rompe e la pagina resta vuota.
N_TICKS="$(sed -e 's/\\\\//g' -e 's/\\`//g' "$JS" 2>/dev/null | tr -cd '`' | wc -c | tr -d ' ')"
N_ENTRIES="$(grep -c 'testo: `' "$JS" 2>/dev/null)"
assert_ok "task learn" &&
  { [ "$N_LESSONS" -gt 0 ] || fail "nessuna lezione in corso/lezioni"; } &&
  { [ "$(grep -c "file: 'corso/lezioni/" "$JS")" -eq "$N_LESSONS" ] || fail "non ci sono tutte le lezioni"; } &&
  assert_contains corso/contenuti.js "file: 'GIORNO-ESAME.md'" &&
  assert_contains corso/contenuti.js "nome: 'alfa-service'" &&
  assert_contains corso/contenuti.js '\${SERVER_PORT' &&
  { [ "$N_TICKS" -eq $(( 2 * N_ENTRIES )) ] || fail "un apice inverso non protetto rompe il JavaScript"; }
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
  [ ! -d "$DEST/common-dto/src/main/java/devdata" ] || fail "devdata e' rimasto in common-dto nella consegna"
  [ ! -d "$DEST/common-dto/src/main/resources/META-INF" ] || fail "META-INF e' rimasto in common-dto nella consegna"
  [ -f "$DEST/alfa-service/src/main/resources/data.sql" ] || fail "scompattato l'archivio, manca data.sql per alfa-service"
  grep -q 'INSERT INTO' "$DEST/alfa-service/src/main/resources/data.sql" || fail "data.sql generato nella consegna non ha INSERT"
  grep -q 'defer-datasource-initialization: true' "$DEST/alfa-service/src/main/resources/application.yml" || fail "manca defer-datasource-initialization in application.yml"
  grep -q 'mode: always' "$DEST/alfa-service/src/main/resources/application.yml" || fail "manca sql.init.mode in application.yml"
  grep -q 'continue-on-error: true' "$DEST/alfa-service/src/main/resources/application.yml" || fail "manca sql.init.continue-on-error in application.yml"
  [ -z "$(find "$DEST" -type f -name '*.zip')" ] || fail "archivi dentro l'archivio"
  grep -q 'Scompatta ogni archivio' "$DEST/ISTRUZIONI-ESECUZIONE.md" && fail "le istruzioni chiedono ancora di ricomporre il progetto"
  rm -rf "$DEST"
fi
case "$TOOL_OUT" in *"==> alfa-service non ha un data.sql: lo genero"*) : ;; *) fail "non ha avviato la generazione automatica di data.sql" ;; esac
case "$TOOL_OUT" in *"data.sql presente per: alfa-service"*) : ;; *) fail "non conferma data.sql presente" ;; esac
end_case

start_case "consegna non tocca un modulo che ha gia' un data.sql"
mkdir -p "$SANDBOX/demo/alfa-service/src/main/resources"
printf -- '-- dati veri per la traccia\nINSERT INTO libro (titolo) VALUES (%s);\n' "'Prova'" >"$SANDBOX/demo/alfa-service/src/main/resources/data.sql"
run_tool consegna.sh --nome ROSSI_MARIO
assert_ok "consegna con data.sql" &&
  { ATTN_LINE="$(printf '%s\n' "$TOOL_OUT" | grep 'ATTENZIONE: nessun data.sql' || true)";
    case "$ATTN_LINE" in *alfa-service*) fail "avvisa anche per alfa-service, che ha gia' un data.sql" ;; *) : ;; esac; } &&
  { case "$TOOL_OUT" in *"==> alfa-service non ha un data.sql"*) fail "ha provato a rigenerare un data.sql che c'era gia'" ;; *) : ;; esac; } &&
  grep -q 'dati veri per la traccia' "$SANDBOX/demo/alfa-service/src/main/resources/data.sql" || fail "ha sovrascritto il data.sql esistente"
rm -f "$SANDBOX/demo/alfa-service/src/main/resources/data.sql"
end_case

# Prima la consegna faceva l'archivio e poi diceva di riempire l'allegato:
# l'archivio restava coi segnaposto, e una consegna rifatta cancellava il testo.
start_case "consegna mette nell'archivio il testo scritto in allegato.md"
if [ ! -f "$SANDBOX/allegato.md" ]; then
  fail "la prima consegna non ha creato allegato.md"
else
  assert_contains allegato.md "## alfa-service" "allegato.md"
  printf '# Le mie parti\n\n## Analisi\n\nLa biblioteca di prova presta libri.\n\n## Algoritmo\n\nLa penale di prova.\n' >"$SANDBOX/allegato.md"
  run_tool consegna.sh --nome ROSSI_MARIO
  DEST="$SANDBOX/consegna-allegato"
  mkdir -p "$DEST"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$SANDBOX/consegna/ROSSI_MARIO.zip" ALLEGATO-TECNICO.md -d "$DEST"
  else
    (cd "$DEST" && jar xf "$SANDBOX/consegna/ROSSI_MARIO.zip" ALLEGATO-TECNICO.md)
  fi
  assert_ok "la seconda consegna" &&
    assert_out_contains "mancano ancora" &&
    assert_contains consegna-allegato/ALLEGATO-TECNICO.md "La biblioteca di prova presta libri." "l'allegato nell'archivio" &&
    assert_contains consegna-allegato/ALLEGATO-TECNICO.md "La penale di prova." "l'allegato nell'archivio" &&
    assert_not_contains consegna-allegato/ALLEGATO-TECNICO.md "[Due o tre paragrafi" "l'allegato nell'archivio" &&
    assert_contains allegato.md "## alfa-service" "allegato.md dopo la consegna" &&
    assert_contains allegato.md "La biblioteca di prova presta libri." "allegato.md dopo la consegna"
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

start_case "ogni comando ha un riepilogo dettagliato (task --summary)"
missing="$(awk '
  /^  [a-z][a-zA-Z0-9_-]*:$/ {
    if (name != "" && has_desc == 1 && has_internal == 0 && has_summary == 0) print name
    name = $0; sub(/^  /, "", name); sub(/:$/, "", name)
    has_desc = 0; has_summary = 0; has_internal = 0
    next
  }
  /^    desc:/ { has_desc = 1 }
  /^    summary:/ { has_summary = 1 }
  /^    internal: *true/ { has_internal = 1 }
  END {
    if (name != "" && has_desc == 1 && has_internal == 0 && has_summary == 0) print name
  }
' "$SANDBOX/Taskfile.yml")"
[ -z "$missing" ] || fail "comandi senza summary: $(printf '%s' "$missing" | tr '\n' ' ')"
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
