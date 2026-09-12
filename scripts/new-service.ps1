<#
.SYNOPSIS
    Crea un nuovo microservizio e lo collega a tutto il resto, in un comando.

.DESCRIPTION
    Un modulo nuovo, fatto a mano, tocca sei posti: la cartella con pom.xml,
    Main.java e application.yml, i <modules> del pom aggregatore, la COPY nel
    Dockerfile, il blocco in docker-compose.yml e la lista dei servizi in
    dev.ps1 e dev.sh. Dimenticarne uno da' errori che sembrano scollegati
    (il modulo non compila, oppure compila ma `task dev` non lo avvia, oppure
    parte in locale e non in Docker). Questo script li fa tutti e sei.

    La porta, se non la passi, e' la prima libera dopo quelle gia' assegnate.

.PARAMETER Name
    Nome della cartella del modulo, in minuscolo: ordini-service, magazzino-ui.

.PARAMETER Port
    Porta del servizio. Se omessa, la prima libera (8084, 8085, ...).

.PARAMETER Ui
    Genera un modulo di interfaccia (Thymeleaf, con un controller e una pagina)
    invece di un servizio REST.

.PARAMETER NoDb
    Servizio senza database: niente JPA, H2 e PostgreSQL nel pom.

.EXAMPLE
    task new-service NAME=ordini-service
    task new-service NAME=report-ui UI=1
    task new-service NAME=calcolo-service NODB=1 PORT=8090
#>
param(
    [string]$Name = '',
    [int]$Port = 0,
    [switch]$Ui,
    [switch]$NoDb
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Nomi derivati ------------------------------------------------------------

if (-not $Name) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task new-service NAME=<nome-modulo> [PORT=<porta>] [UI=1] [NODB=1]"
    }
    Write-Host ''
    Write-Host 'CREAZIONE MICROSERVIZIO GUIDATA' -ForegroundColor Cyan
    $Name = (Read-Host "  Nome del servizio (es. ordini-service, magazzino-ui)").Trim()
    if (-not $Name) {
        throw "Uso: task new-service NAME=<nome-modulo> [PORT=<porta>] [UI=1] [NODB=1]"
    }
    $tipo = (Read-Host "  Tipo: [1] REST con Database (default), [2] Web UI Thymeleaf (UI=1), [3] Senza Database (NODB=1)").Trim()
    if ($tipo -eq '2' -or $Name -like '*-ui') { $Ui = $true }
    elseif ($tipo -eq '3') { $NoDb = $true }

    $pInput = (Read-Host "  Porta specifica (premi Invio per la prima libera)").Trim()
    if ($pInput -match '^\d+$') { $Port = [int]$pInput }
}
if ($Name -cnotmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$') {
    throw "Nome non valido: '$Name'. Usa minuscole e trattini, es. ordini-service."
}
$module = $Name
$moduleDir = Join-Path $demoDir $module
if (Test-Path $moduleDir) {
    throw "Il modulo esiste gia': $moduleDir. Cancellalo, o scegli un altro nome."
}

$short = Get-ModuleShortName -Module $module
$package = Get-ModulePackage -Module $module
$packagePath = $package -replace '\.', '/'
$appName = $module.ToUpper()
$dbPrefix = ($short -replace '-', '_').ToUpper()
$dbName = ($short -replace '-', '') + 'db'
$withDb = (-not $NoDb) -and (-not $Ui)

# --- Porta --------------------------------------------------------------------

$devPs1 = Join-Path $PSScriptRoot 'dev.ps1'
$devSh = Join-Path $PSScriptRoot 'dev.sh'

# Porte gia' impegnate: quelle nella lista dei servizi di dev.ps1 e quelle scritte
# nelle configurazioni dei moduli in demo/.
$used = @()
$devText = Read-TextFile $devPs1
foreach ($hit in ([regex]"Module\s*=\s*'[^']+';\s*Port\s*=\s*(\d+)").Matches($devText)) {
    $used += [int]$hit.Groups[1].Value
}
foreach ($dir in (Get-ChildItem -Path $demoDir -Directory)) {
    $p = Get-ModulePort -ModuleDir $dir.FullName
    if ($p -gt 0) { $used += $p }
}
$used = @($used | Select-Object -Unique)

if ($Port -eq 0) {
    if ($Ui -and ($used -notcontains 8080)) {
        $Port = 8080
    } else {
        $Port = 8081
        while ($used -contains $Port) { $Port++ }
    }
} elseif ($used -contains $Port) {
    throw "La porta $Port e' gia' assegnata a un altro modulo. Scegline un'altra, oppure sposta l'altro con: task set-port SERVICE=<modulo> PORT=<porta>"
}

Write-Host ''
Write-Host "==> Nuovo modulo $module sulla porta $Port" -ForegroundColor Cyan
Write-Host ''

# --- 1. pom.xml del modulo ----------------------------------------------------

$jpaDep = ''
if ($withDb) {
    $jpaDep = @'
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

'@
}
$driverDeps = ''
if ($withDb) {
    $driverDeps = @'
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>

'@
}
$viewDep = ''
if ($Ui) {
    $viewDep = @'
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-thymeleaf</artifactId>
        </dependency>

'@
}

$pom = @"
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

    <artifactId>$module</artifactId>
    <name>$module</name>

    <!-- Le versioni non si scrivono qui: le decide il pom padre (Spring Boot e
         il BOM di Spring Cloud). Per aggiungere dipendenze: task add-dep. -->
    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>common-dto</artifactId>
            <version>`${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
$jpaDep$viewDep        <dependency>
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
$driverDeps        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>`${lombok.version}</version>
            <optional>true</optional>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <mainClass>$package.Main</mainClass>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
"@
Write-TextFile -Path (Join-Path $moduleDir 'pom.xml') -Text $pom
Write-Step "demo/$module/pom.xml"

# --- 2. Main.java e un endpoint di prova --------------------------------------

$javaDir = Join-Path $moduleDir "src/main/java/$packagePath"
$main = @"
package $package;

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
"@
Write-TextFile -Path (Join-Path $javaDir 'Main.java') -Text $main
Write-Step "demo/$module/src/main/java/$packagePath/Main.java"

if ($Ui) {
    $controller = @"
package $package;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("titolo", "$module");
        return "index";
    }
}
"@
    Write-TextFile -Path (Join-Path $javaDir 'HomeController.java') -Text $controller
    Write-Step "demo/$module/src/main/java/$packagePath/HomeController.java"

    $page = @"
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <title th:text="`${titolo}">UI</title>
</head>
<body>
    <h1 th:text="`${titolo}">UI</h1>
    <p>Pagina generata da new-service: sostituiscila con la tua.</p>
</body>
</html>
"@
    Write-TextFile -Path (Join-Path $moduleDir 'src/main/resources/templates/index.html') -Text $page
    Write-Step "demo/$module/src/main/resources/templates/index.html"
} else {
    $controller = @"
package $package;

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
        return "$module ok";
    }
}
"@
    Write-TextFile -Path (Join-Path $javaDir 'PingController.java') -Text $controller
    Write-Step "demo/$module/src/main/java/$packagePath/PingController.java"

    $handlerDir = Join-Path $javaDir 'controller'
    if (-not (Test-Path $handlerDir)) { New-Item -ItemType Directory -Path $handlerDir -Force | Out-Null }
    $handler = @"
package $package.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Gestore centralizzato delle eccezioni generato automaticamente da new-service.
 * Trasforma errori di validazione (@Valid), 404 e 500 in risposte JSON pulite.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            errors.put(error.getField(), error.getDefaultMessage());
        }

        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("error", "Bad Request");
        body.put("message", "Errori di validazione sui campi della richiesta");
        body.put("details", errors);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatusException(ResponseStatusException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", ex.getStatusCode().value());
        body.put("error", ex.getStatusCode().toString());
        body.put("message", ex.getReason());

        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
        body.put("error", "Internal Server Error");
        body.put("message", ex.getMessage() != null ? ex.getMessage() : "Errore interno del server");

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
"@
    Write-TextFile -Path (Join-Path $handlerDir 'GlobalExceptionHandler.java') -Text $handler
    Write-Step "demo/$module/src/main/java/$packagePath/controller/GlobalExceptionHandler.java"
}

# --- 3. application.yml -------------------------------------------------------

$dbBlock = ''
if ($withDb) {
    $dbBlock = @"

  datasource:
    url: `${${dbPrefix}_DB_URL:jdbc:h2:mem:$dbName;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE}
    username: `${${dbPrefix}_DB_USERNAME:sa}
    password: `${${dbPrefix}_DB_PASSWORD:}
    driver-class-name: `${${dbPrefix}_DB_DRIVER:org.h2.Driver}

  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
    properties:
      hibernate:
        format_sql: true

"@
}

$sessionBlock = ''
if ($Ui) {
    $sessionBlock = @"

  servlet:
    session:
      # Solo cookie: senza, al primo invio di un form (quando il browser non ha
      # ancora un JSESSIONID) Tomcat riscrive il redirect in "/;jsessionid=...",
      # Spring non lo riconosce piu' come "/" e la pagina risponde 500.
      tracking-modes: cookie
"@
}

$yml = @"
# La porta si legge da SERVER_PORT (in Docker la passa docker-compose.yml) e
# ricade sul valore qui sotto quando lo avvii in locale. Per cambiarla:
#   task set-port SERVICE=$module PORT=<porta>
server:
  port: `${SERVER_PORT:$Port}$sessionBlock

spring:
  application:
    name: $appName
  # Il load balancer di Feign tiene l'elenco delle istanze in cache per 35
  # secondi: con 5, un servizio appena acceso diventa chiamabile subito.
  cloud:
    loadbalancer:
      cache:
        ttl: 5s
$dbBlock
eureka:
  client:
    service-url:
      defaultZone: `${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
    # Il registro si rilegge ogni 5 secondi invece che ogni 30.
    registry-fetch-interval-seconds: 5
  instance:
    prefer-ip-address: true
    # Un battito ogni 5 secondi: se il servizio si spegne, dopo 15 Eureka lo
    # toglie e gli altri smettono di chiamarlo.
    lease-renewal-interval-in-seconds: 5
    lease-expiration-duration-in-seconds: 15

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
"@
Write-TextFile -Path (Join-Path $moduleDir 'src/main/resources/application.yml') -Text $yml
Write-Step "demo/$module/src/main/resources/application.yml"

# --- 4. pom aggregatore, Dockerfile, docker-compose ---------------------------

$aggregatorPom = Join-Path $demoDir 'pom.xml'
Add-LinesBefore -Path $aggregatorPom -Anchor '^\s*</modules>' -NewLines @("        <module>$module</module>")
Write-Step "demo/pom.xml             <module>$module</module>"

$dockerfile = Join-Path $demoDir 'Dockerfile'
Add-LinesAfterLast -Path $dockerfile -Anchor '^COPY .+/pom\.xml .+/pom\.xml$' -NewLines @("COPY $module/pom.xml $module/pom.xml")
Write-Step "demo/Dockerfile          COPY $module/pom.xml"

$compose = Join-Path $demoDir 'docker-compose.yml'
$composeBlock = @(
    "  ${module}:"
    '    build:'
    '      context: .'
    '      args:'
    "        MODULE: $module"
    '    environment:'
    "      SERVER_PORT: $Port"
    '      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/'
    '    ports:'
    "      - ""${Port}:${Port}"""
    '    depends_on:'
    '      eureka-server:'
    '        condition: service_healthy'
)
$composeLines = @(Split-TextLines (Read-TextFile $compose))
$volumesIdx = Find-LineIndex -Lines $composeLines -Pattern '^volumes:'
if ($volumesIdx -ge 0) {
    # I volumi stanno in fondo, dopo tutti i servizi: il blocco nuovo va prima.
    Add-LinesAt -Path $compose -Index $volumesIdx -NewLines ($composeBlock + @(''))
} else {
    $tail = $composeLines.Count
    while ($tail -gt 0 -and [string]::IsNullOrWhiteSpace($composeLines[$tail - 1])) { $tail-- }
    Add-LinesAt -Path $compose -Index $tail -NewLines (@('') + $composeBlock)
}
Write-Step "demo/docker-compose.yml  servizio $module"

# --- 5. Lista dei servizi di task dev (Windows e POSIX) -----------------------

# Le colonne sono allineate come le altre righe: la lista si legge a colpo d'occhio.
$devLine = "    [pscustomobject]@{{ Name = {0,-14} Module = {1,-18} Port = {2} }}" -f "'$short';", "'$module';", $Port
Add-LinesBefore -Path $devPs1 -Start '^\$services = @\(' -Anchor '^\)' -NewLines @($devLine)
Write-Step ("scripts/dev.ps1          {0} -> {1}:{2}" -f $short, $module, $Port)

Add-LinesBefore -Path $devSh -Start '^SERVICES=\(' -Anchor '^\)' -NewLines @("  ""${short}:${module}:${Port}""")
Write-Step ("scripts/dev.sh           {0} -> {1}:{2}" -f $short, $module, $Port)

# --- Gli editor ---------------------------------------------------------------
# Un launch.json che elenca servizi che non esistono e' peggio di non averlo.

& (Join-Path $PSScriptRoot 'ide-sync.ps1') | Out-Null
Write-Step 'configurazione di VS Code e Zed riallineata'

# --- Fatto --------------------------------------------------------------------

Write-Host ''
Write-Host 'Modulo creato e collegato.' -ForegroundColor Green
Write-Host ''
Write-Host '  task dev          ricompila e riavvia lo stack con il modulo nuovo'
Write-Host ''
Write-Host '  Nota: `task compile` da solo non basta. Il modulo nuovo non e'' ancora' -ForegroundColor Yellow
Write-Host '  in esecuzione, e il classpath dei servizi accesi e'' fissato all''avvio:' -ForegroundColor Yellow
Write-Host '  dopo un modulo nuovo (o una dipendenza nuova) ci vuole `task dev`.' -ForegroundColor Yellow
Write-Host ''
if ($Ui) {
    Write-Host "  http://localhost:$Port"
} else {
    Write-Host "  http://localhost:$Port/api/ping"
    Write-Host "  http://localhost:$Port/swagger-ui.html"
}
Write-Host ''
