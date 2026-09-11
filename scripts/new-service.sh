#!/usr/bin/env bash
# Crea un nuovo microservizio e lo collega a tutto il resto, in un comando.
# Equivalente POSIX di scripts/new-service.ps1: stessi file toccati, stesso
# risultato. Uso:
#   task new-service NAME=ordini-service
#   task new-service NAME=report-ui UI=1
#   task new-service NAME=calcolo-service NODB=1 PORT=8090
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
DEV_PS1="$SCRIPT_DIR/dev.ps1"
DEV_SH="$SCRIPT_DIR/dev.sh"

NAME=""
PORT=0
IS_UI=0
NO_DB=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Name|--name) NAME="$2"; shift 2 ;;
    -Port|--port) PORT="$2"; shift 2 ;;
    -Ui|--ui) IS_UI=1; shift ;;
    -NoDb|--no-db) NO_DB=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

[ -n "$NAME" ] || { echo "Uso: task new-service NAME=<nome-modulo> [PORT=<porta>] [UI=1] [NODB=1]" >&2; exit 1; }
if ! printf '%s' "$NAME" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "Nome non valido: '$NAME'. Usa minuscole e trattini, es. ordini-service." >&2
  exit 1
fi

MODULE="$NAME"
MODULE_DIR="$DEMO_DIR/$MODULE"
[ -e "$MODULE_DIR" ] && { echo "Il modulo esiste gia': $MODULE_DIR" >&2; exit 1; }

SHORT="${MODULE%-service}"
PACKAGE="com.example.ttfcloud_esame.$(printf '%s' "$MODULE" | tr -cd 'a-zA-Z0-9')"
PACKAGE_PATH="$(printf '%s' "$PACKAGE" | tr '.' '/')"
APP_NAME="$(printf '%s' "$MODULE" | tr 'a-z' 'A-Z')"
DB_PREFIX="$(printf '%s' "$SHORT" | tr 'a-z-' 'A-Z_')"
DB_NAME="$(printf '%s' "$SHORT" | tr -d '-')db"
WITH_DB=1
{ [ "$NO_DB" = "1" ] || [ "$IS_UI" = "1" ]; } && WITH_DB=0

# --- Porta --------------------------------------------------------------------

# Porte gia' impegnate: quelle nella configurazione di dev.ps1 (compresa la 8080
# di default della UI) e quelle scritte negli application.yml dei moduli.
used_ports() {
  grep -oE 'Port[[:space:]]*=[[:space:]]*[0-9]+' "$DEV_PS1" | grep -oE '[0-9]+'
  find "$DEMO_DIR" -mindepth 4 -name application.yml -path '*/src/main/resources/*' \
    -exec grep -hoE 'SERVER_PORT:[0-9]+' {} + 2>/dev/null | cut -d: -f2
}
USED="$(used_ports | sort -un)"

if [ "$PORT" -eq 0 ]; then
  PORT=8081
  while printf '%s\n' "$USED" | grep -qx "$PORT"; do PORT=$((PORT + 1)); done
elif printf '%s\n' "$USED" | grep -qx "$PORT"; then
  echo "La porta $PORT e' gia' assegnata a un altro modulo. Scegline un'altra, oppure sposta l'altro con: task set-port SERVICE=<modulo> PORT=<porta>" >&2
  exit 1
fi

echo ""
echo "==> Nuovo modulo $MODULE sulla porta $PORT"
echo ""

# --- Inserimenti di riga ------------------------------------------------------

insert_at_line() { # file, riga-dopo-la-quale-inserire (0 = in testa), testo
  awk -v n="$2" -v text="$3" 'BEGIN{ if (n == 0) printf "%s\n", text } { print } NR == n { printf "%s\n", text }' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

line_of_first() { grep -nE "$2" "$1" | head -n 1 | cut -d: -f1; }
line_of_last() { grep -nE "$2" "$1" | tail -n 1 | cut -d: -f1; }

insert_before_first() { # file, ancora, testo
  local n
  n="$(line_of_first "$1" "$2")"
  [ -n "$n" ] || { echo "Non trovo il punto di inserimento ($2) in $1: aggiungi la riga a mano." >&2; exit 1; }
  insert_at_line "$1" "$((n - 1))" "$3"
}

insert_after_last() { # file, ancora, testo
  local n
  n="$(line_of_last "$1" "$2")"
  [ -n "$n" ] || { echo "Non trovo il punto di inserimento ($2) in $1: aggiungi la riga a mano." >&2; exit 1; }
  insert_at_line "$1" "$n" "$3"
}

# --- 1. pom.xml del modulo ----------------------------------------------------

mkdir -p "$MODULE_DIR/src/main/java/$PACKAGE_PATH" "$MODULE_DIR/src/main/resources"

JPA_DEP=""
DRIVER_DEPS=""
VIEW_DEP=""
if [ "$WITH_DB" = "1" ]; then
  JPA_DEP='        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
'
  DRIVER_DEPS='        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
'
fi
if [ "$IS_UI" = "1" ]; then
  VIEW_DEP='        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-thymeleaf</artifactId>
        </dependency>
'
fi

cat >"$MODULE_DIR/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.example</groupId>
        <artifactId>ttfcloud-esame-parent</artifactId>
        <version>0.0.1-SNAPSHOT</version>
        <relativePath>../pom.xml</relativePath>
    </parent>

    <artifactId>$MODULE</artifactId>
    <name>$MODULE</name>

    <!-- Le versioni non si scrivono qui: le decide il pom padre (Spring Boot e
         il BOM di Spring Cloud). Per aggiungere dipendenze: task add-dep. -->
    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>common-dto</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
${JPA_DEP}${VIEW_DEP}        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-openfeign</artifactId>
        </dependency>
${DRIVER_DEPS}        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>\${lombok.version}</version>
            <optional>true</optional>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <mainClass>$PACKAGE.Main</mainClass>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
echo "  demo/$MODULE/pom.xml"

# --- 2. Main.java e un endpoint di prova --------------------------------------

cat >"$MODULE_DIR/src/main/java/$PACKAGE_PATH/Main.java" <<EOF
package $PACKAGE;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

// @EnableDiscoveryClient: il servizio si registra su Eureka.
// @EnableFeignClients: puo' chiamare gli altri servizi per NOME, senza URL.
@EnableDiscoveryClient
@EnableFeignClients
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
EOF
echo "  demo/$MODULE/src/main/java/$PACKAGE_PATH/Main.java"

if [ "$IS_UI" = "1" ]; then
  cat >"$MODULE_DIR/src/main/java/$PACKAGE_PATH/HomeController.java" <<EOF
package $PACKAGE;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("titolo", "$MODULE");
        return "index";
    }
}
EOF
  echo "  demo/$MODULE/src/main/java/$PACKAGE_PATH/HomeController.java"

  mkdir -p "$MODULE_DIR/src/main/resources/templates"
  cat >"$MODULE_DIR/src/main/resources/templates/index.html" <<EOF
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title th:text="\${titolo}">UI</title>
</head>
<body>
    <h1 th:text="\${titolo}">UI</h1>
    <p>Pagina generata da new-service: sostituiscila con la tua.</p>
</body>
</html>
EOF
  echo "  demo/$MODULE/src/main/resources/templates/index.html"
else
  cat >"$MODULE_DIR/src/main/java/$PACKAGE_PATH/PingController.java" <<EOF
package $PACKAGE;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// Endpoint minimo per verificare che il servizio sia vivo: sostituiscilo con
// il tuo controller vero.
@RestController
@RequestMapping("/api")
public class PingController {

    @GetMapping("/ping")
    public String ping() {
        return "$MODULE ok";
    }
}
EOF
  echo "  demo/$MODULE/src/main/java/$PACKAGE_PATH/PingController.java"
fi

# --- 3. application.yml -------------------------------------------------------

{
  cat <<EOF
# La porta si legge da SERVER_PORT (in Docker la passa docker-compose.yml) e
# ricade sul valore qui sotto quando lo avvii in locale. Per cambiarla:
#   task set-port SERVICE=$MODULE PORT=<porta>
server:
  port: \${SERVER_PORT:$PORT}

spring:
  application:
    name: $APP_NAME
EOF
  if [ "$WITH_DB" = "1" ]; then
    cat <<EOF

  datasource:
    url: \${${DB_PREFIX}_DB_URL:jdbc:h2:mem:$DB_NAME;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE}
    username: \${${DB_PREFIX}_DB_USERNAME:sa}
    password: \${${DB_PREFIX}_DB_PASSWORD:}
    driver-class-name: \${${DB_PREFIX}_DB_DRIVER:org.h2.Driver}

  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
    properties:
      hibernate:
        format_sql: true
EOF
  fi
  cat <<EOF

eureka:
  client:
    service-url:
      defaultZone: \${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
  instance:
    prefer-ip-address: true

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
EOF
} >"$MODULE_DIR/src/main/resources/application.yml"
echo "  demo/$MODULE/src/main/resources/application.yml"

# --- 4. pom aggregatore, Dockerfile, docker-compose ---------------------------

insert_before_first "$DEMO_DIR/pom.xml" '^[[:space:]]*</modules>' "        <module>$MODULE</module>"
echo "  demo/pom.xml             <module>$MODULE</module>"

insert_after_last "$DEMO_DIR/Dockerfile" '^COPY .+/pom\.xml .+/pom\.xml$' "COPY $MODULE/pom.xml $MODULE/pom.xml"
echo "  demo/Dockerfile          COPY $MODULE/pom.xml"

COMPOSE="$DEMO_DIR/docker-compose.yml"
COMPOSE_BLOCK="  $MODULE:
    build:
      context: .
      args:
        MODULE: $MODULE
    environment:
      SERVER_PORT: $PORT
      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
    ports:
      - \"$PORT:$PORT\"
    depends_on:
      eureka-server:
        condition: service_healthy"

# I volumi stanno in fondo, dopo tutti i servizi: il blocco nuovo va prima.
VOLUMES_LINE="$(line_of_first "$COMPOSE" '^volumes:' || true)"
if [ -n "$VOLUMES_LINE" ]; then
  insert_at_line "$COMPOSE" "$((VOLUMES_LINE - 1))" "$COMPOSE_BLOCK
"
else
  printf '\n%s\n' "$COMPOSE_BLOCK" >>"$COMPOSE"
fi
echo "  demo/docker-compose.yml  servizio $MODULE"

# --- 5. Lista dei servizi di task dev (Windows e POSIX) -----------------------

# La lista si chiude con una ')' a inizio riga: e' la prima dopo l'apertura.
PS_START="$(line_of_first "$DEV_PS1" '^\$services = @\(')"
PS_END="$(awk -v s="$PS_START" 'NR > s && /^\)/ { print NR; exit }' "$DEV_PS1")"
[ -n "$PS_END" ] || { echo "Non trovo la fine della lista \$services in $DEV_PS1: aggiungi la riga a mano." >&2; exit 1; }
# Le colonne sono allineate come le altre righe: la lista si legge a colpo d'occhio.
PS_LINE="$(printf '    [pscustomobject]@{ Name = %-14s Module = %-18s Port = %s }' "'$SHORT';" "'$MODULE';" "$PORT")"
insert_at_line "$DEV_PS1" "$((PS_END - 1))" "$PS_LINE"
echo "  scripts/dev.ps1          $SHORT -> $MODULE:$PORT"

SH_START="$(line_of_first "$DEV_SH" '^SERVICES=\(')"
SH_END="$(awk -v s="$SH_START" 'NR > s && /^\)/ { print NR; exit }' "$DEV_SH")"
[ -n "$SH_END" ] || { echo "Non trovo la fine della lista SERVICES in $DEV_SH: aggiungi la riga a mano." >&2; exit 1; }
insert_at_line "$DEV_SH" "$((SH_END - 1))" "  \"$SHORT:$MODULE:$PORT\""
echo "  scripts/dev.sh           $SHORT -> $MODULE:$PORT"

# --- Gli editor ---------------------------------------------------------------
# Un launch.json che elenca servizi che non esistono e' peggio di non averlo.

bash "$SCRIPT_DIR/ide-sync.sh" >/dev/null 2>&1
echo "  configurazione di VS Code e Zed riallineata"

# --- Fatto --------------------------------------------------------------------

echo ""
echo "Modulo creato e collegato."
echo ""
echo "  task dev          ricompila e riavvia lo stack con il modulo nuovo"
echo ""
echo "  Nota: 'task compile' da solo non basta. Il modulo nuovo non e' ancora in"
echo "  esecuzione, e il classpath dei servizi accesi e' fissato all'avvio:"
echo "  dopo un modulo nuovo (o una dipendenza nuova) ci vuole 'task dev'."
echo ""
if [ "$IS_UI" = "1" ]; then
  echo "  http://localhost:$PORT"
else
  echo "  http://localhost:$PORT/api/ping"
  echo "  http://localhost:$PORT/swagger-ui.html"
fi
echo ""
