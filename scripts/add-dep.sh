#!/usr/bin/env bash
# Aggiunge dipendenze al pom.xml di un modulo, senza scrivere XML a mano.
# Equivalente POSIX di scripts/add-dep.ps1.
#
# Le versioni non vanno quasi mai scritte: le governa il pom padre
# (spring-boot-starter-parent) e il BOM di Spring Cloud che importa.
#
#   task add-dep -- --module wms-service --deps security,mail
#   task add-dep -- --module product-service --deps 'org.apache.commons:commons-lang3:3.17.0'
#   task add-dep -- --list
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

MODULE=""
DEPS=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    -Deps|--deps) DEPS="$2"; shift 2 ;;
    -List|--list) LIST=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

BOOT="org.springframework.boot"
CLOUD="org.springframework.cloud"

# id|gruppo|artefatto|scope|versione|optional
CATALOG="
web|$BOOT|spring-boot-starter-web|||
webflux|$BOOT|spring-boot-starter-webflux|||
thymeleaf|$BOOT|spring-boot-starter-thymeleaf|||
validation|$BOOT|spring-boot-starter-validation|||
websocket|$BOOT|spring-boot-starter-websocket|||
actuator|$BOOT|spring-boot-starter-actuator|||
springdoc|org.springdoc|springdoc-openapi-starter-webmvc-ui|||
data-jpa|$BOOT|spring-boot-starter-data-jpa|||
data-jdbc|$BOOT|spring-boot-starter-data-jdbc|||
data-rest|$BOOT|spring-boot-starter-data-rest|||
data-mongodb|$BOOT|spring-boot-starter-data-mongodb|||
data-redis|$BOOT|spring-boot-starter-data-redis|||
cache|$BOOT|spring-boot-starter-cache|||
h2|com.h2database|h2|runtime||
postgresql|org.postgresql|postgresql|runtime||
mysql|com.mysql|mysql-connector-j|runtime||
flyway|org.flywaydb|flyway-core|||
security|$BOOT|spring-boot-starter-security|||
oauth2-client|$BOOT|spring-boot-starter-oauth2-client|||
oauth2-server|$BOOT|spring-boot-starter-oauth2-resource-server|||
eureka-client|$CLOUD|spring-cloud-starter-netflix-eureka-client|||
eureka-server|$CLOUD|spring-cloud-starter-netflix-eureka-server|||
feign|$CLOUD|spring-cloud-starter-openfeign|||
gateway|$CLOUD|spring-cloud-starter-gateway|||
config-client|$CLOUD|spring-cloud-starter-config|||
loadbalancer|$CLOUD|spring-cloud-starter-loadbalancer|||
resilience4j|$CLOUD|spring-cloud-starter-circuitbreaker-resilience4j|||
amqp|$BOOT|spring-boot-starter-amqp|||
kafka|org.springframework.kafka|spring-kafka|||
mail|$BOOT|spring-boot-starter-mail|||
quartz|$BOOT|spring-boot-starter-quartz|||
batch|$BOOT|spring-boot-starter-batch|||
lombok|org.projectlombok|lombok||\${lombok.version}|1
common-dto|com.example|common-dto||\${project.version}|
test|$BOOT|spring-boot-starter-test|test||
"

if [ "$LIST" = "1" ]; then
  echo ""
  echo "Nomi brevi riconosciuti da task add-dep:"
  echo ""
  printf '%s\n' "$CATALOG" | grep -v '^$' | while IFS='|' read -r id group artifact scope version _opt; do
    extra=""
    [ -n "$scope" ] && extra=" (scope $scope)"
    [ -n "$version" ] && extra="$extra (versione $version)"
    printf '  %-16s%s:%s%s\n' "$id" "$group" "$artifact" "$extra"
  done
  echo ""
  echo "Non in elenco? Passa le coordinate: --deps 'gruppo:artefatto:versione'"
  echo ""
  echo "devtools non serve aggiungerlo: e' nel pom padre, quindi ce l'hanno gia' tutti i moduli."
  echo ""
  exit 0
fi

if [ -z "$MODULE" ] || [ -z "$DEPS" ]; then
  echo "Uso: task add-dep -- --module <modulo> --deps <dip1,dip2>   (elenco: task add-dep -- --list)" >&2
  exit 1
fi

POM="$DEMO_DIR/$MODULE/pom.xml"
if [ ! -f "$POM" ]; then
  available=""
  for dir in "$DEMO_DIR"/*/; do
    [ -f "$dir/pom.xml" ] && available="$available $(basename "$dir")"
  done
  echo "Modulo '$MODULE' non trovato. Moduli disponibili:$available" >&2
  exit 1
fi

BLOCK=""
ADDED=""
IFS=',' read -ra REQUESTED <<<"$DEPS"
for raw in "${REQUESTED[@]}"; do
  id="$(printf '%s' "$raw" | tr -d '[:space:]')"
  [ -z "$id" ] && continue

  if [ "$id" = "devtools" ]; then
    echo "  devtools: gia' nel pom padre, lo ereditano tutti i moduli. Salto."
    continue
  fi

  entry="$(printf '%s\n' "$CATALOG" | grep "^${id}|" || true)"
  if [ -n "$entry" ]; then
    IFS='|' read -r _id group artifact scope version optional <<<"$entry"
  elif printf '%s' "$id" | grep -qE '^[^:[:space:]]+:[^:[:space:]]+(:[^:[:space:]]+)?$'; then
    group="$(printf '%s' "$id" | cut -d: -f1)"
    artifact="$(printf '%s' "$id" | cut -d: -f2)"
    version="$(printf '%s' "$id" | cut -d: -f3-)"
    scope=""
    optional=""
  else
    echo "Dipendenza sconosciuta: '$id'. Vedi l'elenco con: task add-dep -- --list (oppure passa gruppo:artefatto:versione)" >&2
    exit 1
  fi

  if grep -q "<artifactId>${artifact}</artifactId>" "$POM"; then
    echo "  $artifact: gia' presente nel pom, salto."
    continue
  fi

  BLOCK="$BLOCK        <dependency>
            <groupId>${group}</groupId>
            <artifactId>${artifact}</artifactId>
"
  [ -n "$version" ] && BLOCK="$BLOCK            <version>${version}</version>
"
  [ -n "$scope" ] && BLOCK="$BLOCK            <scope>${scope}</scope>
"
  [ -n "$optional" ] && BLOCK="$BLOCK            <optional>true</optional>
"
  BLOCK="$BLOCK        </dependency>
"
  ADDED="$ADDED $artifact"
done

if [ -z "$ADDED" ]; then
  echo ""
  echo "Nessuna modifica: erano tutte gia' presenti."
  exit 0
fi

# Il blocco va prima della chiusura di <dependencies> del modulo (la prima:
# nei pom dei moduli ce n'e' una sola, il resto e' <build>).
N="$(grep -nE '^[[:space:]]*</dependencies>' "$POM" | head -n 1 | cut -d: -f1)"
[ -n "$N" ] || { echo "Non trovo </dependencies> in $POM: aggiungi la dipendenza a mano." >&2; exit 1; }
awk -v n="$((N - 1))" -v text="$BLOCK" '{ print } NR == n { printf "%s", text }' "$POM" >"$POM.tmp" && mv "$POM.tmp" "$POM"

echo ""
echo "==> demo/$MODULE/pom.xml aggiornato:"
for artifact in $ADDED; do echo "  $artifact"; done
echo ""
echo "  task dev          scarica le nuove dipendenze e riavvia lo stack"
echo ""
echo "  Nota: 'task compile' non basta. Il classpath di un servizio e' fissato"
echo "  quando parte: un jar nuovo lo vede solo un riavvio vero, cioe' 'task dev'."
echo ""
