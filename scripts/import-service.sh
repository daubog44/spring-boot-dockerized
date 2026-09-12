#!/usr/bin/env bash
# Importa un microservizio da uno zip o una cartella esistente e lo collega a Eureka e allo stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

REPO_ROOT="$(get_scaffold_repo_root)"
DEMO_DIR="$REPO_ROOT/demo"
DEV_PS1="$SCRIPT_DIR/dev.ps1"
DEV_SH="$SCRIPT_DIR/dev.sh"

SRC=""
NAME=""
PORT=0

for arg in "$@"; do
  case "$arg" in
    SRC=*|src=*) SRC="${arg#*=}" ;;
    NAME=*|name=*) NAME="${arg#*=}" ;;
    PORT=*|port=*) PORT="${arg#*=}" ;;
  esac
done

if [ -z "$SRC" ]; then
  if [ -t 0 ]; then
    echo ""
    echo -e "\033[36mIMPORTAZIONE MICROSERVIZIO ESISTENTE\033[0m"
    read -r -p "  Percorso del file .zip o cartella da importare: " SRC
    read -r -p "  Nome del modulo in demo/ (Invio per dedurlo): " nInput
    [ -n "$nInput" ] && NAME="$nInput"
    read -r -p "  Porta specifica (Invio per automatica): " pInput
    [ -n "$pInput" ] && PORT="$pInput"
  else
    echo "Uso: task import-service SRC=<file.zip|cartella> [NAME=<nome-modulo>] [PORT=<porta>]" >&2
    exit 1
  fi
fi

SRC="${SRC%\"}"
SRC="${SRC#\"}"
SRC="${SRC%\'}"
SRC="${SRC#\'}"

if [ ! -e "$SRC" ]; then
  echo "File o cartella sorgente non trovato: $SRC" >&2
  exit 1
fi

# 1. Determinazione Nome
if [ -z "$NAME" ]; then
  if [[ "$SRC" == *.zip ]]; then
    base="$(basename "$SRC")"
    NAME="${base%.zip}"
  else
    NAME="$(basename "$SRC")"
  fi
fi
NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | tr '_' '-' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"
MODULE="$NAME"
MODULE_DIR="$DEMO_DIR/$MODULE"

if [ -d "$MODULE_DIR" ]; then
  echo "La cartella demo/$MODULE esiste gia'. Rimuovila prima o usa un altro nome." >&2
  exit 1
fi

echo ""
echo -e "\033[36m==> Importazione di '$MODULE' da $SRC\033[0m"

# 2. Estrazione o Copia
mkdir -p "$MODULE_DIR"
if [[ "$SRC" == *.zip ]]; then
  TMP_DIR="$(mktemp -d)"
  unzip -q "$SRC" -d "$TMP_DIR"
  # Trova la cartella con pom.xml
  if [ ! -f "$TMP_DIR/pom.xml" ]; then
    POM_FOUND="$(find "$TMP_DIR" -name "pom.xml" | head -n 1 || true)"
    if [ -n "$POM_FOUND" ]; then
      SRC_SUBDIR="$(dirname "$POM_FOUND")"
      cp -r "$SRC_SUBDIR"/* "$MODULE_DIR"/
    else
      cp -r "$TMP_DIR"/* "$MODULE_DIR"/
    fi
  else
    cp -r "$TMP_DIR"/* "$MODULE_DIR"/
  fi
  rm -rf "$TMP_DIR"
else
  if [ ! -f "$SRC/pom.xml" ]; then
    POM_FOUND="$(find "$SRC" -name "pom.xml" | head -n 1 || true)"
    if [ -n "$POM_FOUND" ]; then
      SRC_SUBDIR="$(dirname "$POM_FOUND")"
      cp -r "$SRC_SUBDIR"/* "$MODULE_DIR"/
    else
      cp -r "$SRC"/* "$MODULE_DIR"/
    fi
  else
    cp -r "$SRC"/* "$MODULE_DIR"/
  fi
fi

# Pulizia cartelle inutili
rm -rf "$MODULE_DIR/target" "$MODULE_DIR/.settings" "$MODULE_DIR/.idea" "$MODULE_DIR/.vscode" "$MODULE_DIR/.project" "$MODULE_DIR/.classpath" "$MODULE_DIR/.factorypath"

POM_PATH="$MODULE_DIR/pom.xml"
if [ ! -f "$POM_PATH" ]; then
  echo "Il progetto importato non contiene un pom.xml alla radice di demo/$MODULE." >&2
  exit 1
fi
echo "  sorgenti estratti in demo/$MODULE"

# 3. Determinazione Porta
DETECTED_PORT=""
YML_PATH="$MODULE_DIR/src/main/resources/application.yml"
YAML_PATH="$MODULE_DIR/src/main/resources/application.yaml"
PROP_PATH="$MODULE_DIR/src/main/resources/application.properties"

if [ -f "$YML_PATH" ]; then
  DETECTED_PORT="$(grep -E '^[[:space:]]*port:[[:space:]]*[0-9]+' "$YML_PATH" | awk '{print $2}' | tr -d '\r' | head -1 || true)"
elif [ -f "$YAML_PATH" ]; then
  DETECTED_PORT="$(grep -E '^[[:space:]]*port:[[:space:]]*[0-9]+' "$YAML_PATH" | awk '{print $2}' | tr -d '\r' | head -1 || true)"
elif [ -f "$PROP_PATH" ]; then
  DETECTED_PORT="$(grep -E '^[[:space:]]*server\.port[[:space:]]*=' "$PROP_PATH" | cut -d'=' -f2 | tr -d ' \r' | head -1 || true)"
fi

if [ -n "$PORT" ] && [ "$PORT" -gt 0 ]; then
  FINAL_PORT="$PORT"
elif [ -n "$DETECTED_PORT" ]; then
  FINAL_PORT="$DETECTED_PORT"
else
  FINAL_PORT=8082
  while grep -q "Port = $FINAL_PORT" "$DEV_PS1" 2>/dev/null; do
    FINAL_PORT=$((FINAL_PORT + 1))
  done
fi

# 4. pom.xml: Eureka Client + SpringDoc + Cloud BOM
if ! grep -q "spring-cloud-starter-netflix-eureka-client" "$POM_PATH"; then
  EUREKA_DEP="		<dependency>\n			<groupId>org.springframework.cloud</groupId>\n			<artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>\n		</dependency>"
  # inserisci prima di </dependencies>
  sed -i.bak "/<\/dependencies>/i \\
$EUREKA_DEP" "$POM_PATH" && rm -f "${POM_PATH}.bak"
  echo "  pom.xml: aggiunta dipendenza spring-cloud-starter-netflix-eureka-client"
fi

if ! grep -q "springdoc-openapi-starter-webmvc-ui" "$POM_PATH"; then
  DOC_DEP="		<dependency>\n			<groupId>org.springdoc</groupId>\n			<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>\n			<version>2.8.5</version>\n		</dependency>"
  sed -i.bak "/<\/dependencies>/i \\
$DOC_DEP" "$POM_PATH" && rm -f "${POM_PATH}.bak"
  echo "  pom.xml: aggiunta dipendenza springdoc-openapi-starter-webmvc-ui"
fi

if ! grep -q "spring-cloud-dependencies" "$POM_PATH"; then
  DEP_MGMT="	<dependencyManagement>\n		<dependencies>\n			<dependency>\n				<groupId>org.springframework.cloud</groupId>\n				<artifactId>spring-cloud-dependencies</artifactId>\n				<version>\${spring-cloud.version:2025.1.2}</version>\n				<type>pom</type>\n				<scope>import</scope>\n			</dependency>\n		</dependencies>\n	</dependencyManagement>"
  sed -i.bak "/<\/project>/i \\
$DEP_MGMT" "$POM_PATH" && rm -f "${POM_PATH}.bak"
  echo "  pom.xml: aggiunto dependencyManagement per Spring Cloud"
fi

# 5. Configurazione Eureka
ACTIVE_CFG=""
[ -f "$YML_PATH" ] && ACTIVE_CFG="$YML_PATH"
[ -z "$ACTIVE_CFG" ] && [ -f "$YAML_PATH" ] && ACTIVE_CFG="$YAML_PATH"

if [ -n "$ACTIVE_CFG" ]; then
  if grep -qE '^[[:space:]]*port:[[:space:]]*[0-9]+' "$ACTIVE_CFG"; then
    sed -i.bak -E "s/^[[:space:]]*port:[[:space:]]*[0-9]+/  port: \${SERVER_PORT:$FINAL_PORT}/" "$ACTIVE_CFG" && rm -f "${ACTIVE_CFG}.bak"
  elif ! grep -q 'server:' "$ACTIVE_CFG"; then
    printf 'server:\n  port: ${SERVER_PORT:%s}\n\n%s' "$FINAL_PORT" "$(cat "$ACTIVE_CFG")" >"$ACTIVE_CFG"
  fi
  if ! grep -q "eureka:" "$ACTIVE_CFG"; then
    cat << EOF >> "$ACTIVE_CFG"

eureka:
  client:
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
    registry-fetch-interval-seconds: 5
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 5
    lease-expiration-duration-in-seconds: 15

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
EOF
    echo "  application.yml: configurato Eureka client e porta $FINAL_PORT"
  fi
elif [ -f "$PROP_PATH" ]; then
  if ! grep -q "eureka\.client" "$PROP_PATH"; then
    if grep -qE '^[[:space:]]*server\.port[[:space:]]*=' "$PROP_PATH"; then
      sed -i.bak -E "s/^[[:space:]]*server\.port[[:space:]]*=[^\r\n]*/server.port=\${SERVER_PORT:$FINAL_PORT}/" "$PROP_PATH" && rm -f "${PROP_PATH}.bak"
    else
      printf 'server.port=${SERVER_PORT:%s}\n' "$FINAL_PORT" >> "$PROP_PATH"
    fi
    cat << EOF >> "$PROP_PATH"

# Eureka & OpenAPI
spring.application.name=$MODULE
eureka.client.service-url.defaultZone=\${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
eureka.client.registry-fetch-interval-seconds=5
eureka.instance.prefer-ip-address=true
eureka.instance.lease-renewal-interval-in-seconds=5
eureka.instance.lease-expiration-duration-in-seconds=15
springdoc.api-docs.path=/v3/api-docs
springdoc.swagger-ui.path=/swagger-ui.html
EOF
    echo "  application.properties: configurato Eureka client e porta $FINAL_PORT"
  fi
else
  cat << EOF > "$MODULE_DIR/src/main/resources/application.yml"
server:
  port: \${SERVER_PORT:$FINAL_PORT}

spring:
  application:
    name: $MODULE

eureka:
  client:
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
    registry-fetch-interval-seconds: 5
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 5
    lease-expiration-duration-in-seconds: 15

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
EOF
  echo "  creato application.yml con configurazione Eureka e porta $FINAL_PORT"
fi

# 6. pom aggregatore
AGGR_POM="$DEMO_DIR/pom.xml"
if ! grep -q "<module>$MODULE</module>" "$AGGR_POM"; then
  sed -i.bak "/<\/modules>/i \\
        <module>$MODULE</module>" "$AGGR_POM" && rm -f "${AGGR_POM}.bak"
  echo "  demo/pom.xml: registrato modulo <module>$MODULE</module>"
fi

# 7. demo/Dockerfile
ROOT_DF="$DEMO_DIR/Dockerfile"
if [ -f "$ROOT_DF" ] && ! grep -q "COPY $MODULE/pom.xml $MODULE/pom.xml" "$ROOT_DF"; then
  LAST_POM_LINE="$(grep -nE '^COPY .+/pom\.xml .+/pom\.xml$' "$ROOT_DF" | tail -n 1 | cut -d: -f1 || true)"
  if [ -n "$LAST_POM_LINE" ]; then
    awk -v n="$LAST_POM_LINE" -v line="COPY $MODULE/pom.xml $MODULE/pom.xml" '
      { print }
      NR == n { print line }
    ' "$ROOT_DF" >"$ROOT_DF.tmp" && mv "$ROOT_DF.tmp" "$ROOT_DF"
  else
    echo "COPY $MODULE/pom.xml $MODULE/pom.xml" >> "$ROOT_DF"
  fi
  echo "  demo/Dockerfile: aggiunta riga COPY $MODULE/pom.xml"
fi

# 8. docker-compose.yml
COMPOSE="$DEMO_DIR/docker-compose.yml"
if [ -f "$COMPOSE" ] && ! grep -q "^  ${MODULE}:" "$COMPOSE"; then
  COMPOSE_BLOCK="  ${MODULE}:
    build:
      context: .
      args:
        MODULE: $MODULE
    environment:
      SERVER_PORT: $FINAL_PORT
      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
    ports:
      - \"${FINAL_PORT}:${FINAL_PORT}\"
    depends_on:
      eureka-server:
        condition: service_healthy"

  VOLUMES_LINE="$(grep -nE '^volumes:' "$COMPOSE" | head -n 1 | cut -d: -f1 || true)"
  if [ -n "$VOLUMES_LINE" ]; then
    awk -v n="$((VOLUMES_LINE - 1))" -v block="$COMPOSE_BLOCK" '
      { print }
      NR == n { printf "%s\n\n", block }
    ' "$COMPOSE" >"$COMPOSE.tmp" && mv "$COMPOSE.tmp" "$COMPOSE"
  else
    printf '\n%s\n' "$COMPOSE_BLOCK" >>"$COMPOSE"
  fi
  echo "  demo/docker-compose.yml: aggiunto container $MODULE"
fi

# 9. dev.ps1 e dev.sh
SHORT="$(echo "$MODULE" | sed 's/-service$//')"
if ! grep -q "'$MODULE'" "$DEV_PS1"; then
  PS_START="$(grep -nE '^\$services = @\(' "$DEV_PS1" | head -n 1 | cut -d: -f1 || true)"
  PS_END="$(awk -v s="$PS_START" 'NR > s && /^\)/ { print NR; exit }' "$DEV_PS1" || true)"
  if [ -n "$PS_END" ]; then
    PS_LINE="$(printf '    [pscustomobject]@{ Name = %-14s Module = %-18s Port = %s }' "'$SHORT';" "'$MODULE';" "$FINAL_PORT")"
    awk -v n="$((PS_END - 1))" -v line="$PS_LINE" '
      { print }
      NR == n { print line }
    ' "$DEV_PS1" >"$DEV_PS1.tmp" && mv "$DEV_PS1.tmp" "$DEV_PS1"
    echo "  scripts/dev.ps1: registrato $SHORT -> $MODULE:$FINAL_PORT"
  fi
fi

if [ -f "$DEV_SH" ] && ! grep -q ":${MODULE}:" "$DEV_SH"; then
  SH_START="$(grep -nE '^SERVICES=\(' "$DEV_SH" | head -n 1 | cut -d: -f1 || true)"
  SH_END="$(awk -v s="$SH_START" 'NR > s && /^\)/ { print NR; exit }' "$DEV_SH" || true)"
  if [ -n "$SH_END" ]; then
    awk -v n="$((SH_END - 1))" -v line="  \"$SHORT:$MODULE:$FINAL_PORT\"" '
      { print }
      NR == n { print line }
    ' "$DEV_SH" >"$DEV_SH.tmp" && mv "$DEV_SH.tmp" "$DEV_SH"
    echo "  scripts/dev.sh: registrato $SHORT -> $MODULE:$FINAL_PORT"
  fi
fi

# 10. ide-sync
bash "$SCRIPT_DIR/ide-sync.sh" >/dev/null 2>&1 || true
echo "  configurazione editor sincronizzata"

echo ""
echo -e "\033[32mModulo '$MODULE' importato con successo su porta $FINAL_PORT!\033[0m"
echo ""
echo "  Swagger UI: http://localhost:$FINAL_PORT/swagger-ui.html"
echo "  Eureka:     http://localhost:8761"
echo ""
echo "Per avviarlo assieme agli altri:"
echo -e "\033[36m  task dev\033[0m"
echo ""
