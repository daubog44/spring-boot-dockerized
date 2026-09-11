<#
.SYNOPSIS
    Aggiunge dipendenze al pom.xml di un modulo, senza scrivere XML a mano.

.DESCRIPTION
    Le versioni non vanno quasi mai scritte: le governa il pom padre
    (spring-boot-starter-parent) e il BOM di Spring Cloud che importa. Questo
    script conosce le dipendenze piu' probabili all'esame con il loro
    groupId/artifactId esatto, e le inserisce nel punto giusto del pom del
    modulo, saltando quelle gia' presenti.

    Se ti serve qualcosa che non e' in elenco, passala per coordinate:
    -Deps 'org.apache.commons:commons-lang3:3.17.0'.

.PARAMETER Module
    Cartella del modulo sotto demo/, es. wms-service.

.PARAMETER Deps
    Elenco separato da virgole: nomi brevi (task add-dep LIST=1 per vederli)
    oppure coordinate groupId:artifactId[:versione].

.PARAMETER List
    Stampa l'elenco dei nomi brevi conosciuti ed esce.

.EXAMPLE
    task add-dep SERVICE=wms-service DEPS=security,mail
    task add-dep SERVICE=product-service DEPS=org.apache.commons:commons-lang3:3.17.0
    task add-dep LIST=1
#>
param(
    [string]$Module,
    [string]$Deps,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Catalogo -----------------------------------------------------------------

# Version = $null significa "la decide il pom padre": e' il caso normale, ed e'
# anche il motivo per cui qui non compaiono numeri di versione da aggiornare.
function New-Dep {
    param([string]$Group, [string]$Artifact, [string]$Scope, [string]$Version, [switch]$Optional)
    return [pscustomobject]@{
        Group = $Group; Artifact = $Artifact; Scope = $Scope
        Version = $Version; Optional = [bool]$Optional
    }
}

$boot = 'org.springframework.boot'
$cloud = 'org.springframework.cloud'

$catalog = [ordered]@{
    # Web e presentazione
    'web'                = New-Dep $boot 'spring-boot-starter-web'
    'webflux'            = New-Dep $boot 'spring-boot-starter-webflux'
    'thymeleaf'          = New-Dep $boot 'spring-boot-starter-thymeleaf'
    'validation'         = New-Dep $boot 'spring-boot-starter-validation'
    'websocket'          = New-Dep $boot 'spring-boot-starter-websocket'
    'actuator'           = New-Dep $boot 'spring-boot-starter-actuator'
    'springdoc'          = New-Dep 'org.springdoc' 'springdoc-openapi-starter-webmvc-ui'
    # Persistenza
    'data-jpa'           = New-Dep $boot 'spring-boot-starter-data-jpa'
    'data-jdbc'          = New-Dep $boot 'spring-boot-starter-data-jdbc'
    'data-rest'          = New-Dep $boot 'spring-boot-starter-data-rest'
    'data-mongodb'       = New-Dep $boot 'spring-boot-starter-data-mongodb'
    'data-redis'         = New-Dep $boot 'spring-boot-starter-data-redis'
    'cache'              = New-Dep $boot 'spring-boot-starter-cache'
    'h2'                 = New-Dep 'com.h2database' 'h2' 'runtime'
    'postgresql'         = New-Dep 'org.postgresql' 'postgresql' 'runtime'
    'mysql'              = New-Dep 'com.mysql' 'mysql-connector-j' 'runtime'
    'flyway'             = New-Dep 'org.flywaydb' 'flyway-core'
    # Sicurezza
    'security'           = New-Dep $boot 'spring-boot-starter-security'
    'oauth2-client'      = New-Dep $boot 'spring-boot-starter-oauth2-client'
    'oauth2-server'      = New-Dep $boot 'spring-boot-starter-oauth2-resource-server'
    # Microservizi (versione dal BOM spring-cloud gia' importato nel pom padre)
    'eureka-client'      = New-Dep $cloud 'spring-cloud-starter-netflix-eureka-client'
    'eureka-server'      = New-Dep $cloud 'spring-cloud-starter-netflix-eureka-server'
    'feign'              = New-Dep $cloud 'spring-cloud-starter-openfeign'
    'gateway'            = New-Dep $cloud 'spring-cloud-starter-gateway'
    'config-client'      = New-Dep $cloud 'spring-cloud-starter-config'
    'loadbalancer'       = New-Dep $cloud 'spring-cloud-starter-loadbalancer'
    'resilience4j'       = New-Dep $cloud 'spring-cloud-starter-circuitbreaker-resilience4j'
    # Messaggistica e lavori
    'amqp'               = New-Dep $boot 'spring-boot-starter-amqp'
    'kafka'              = New-Dep 'org.springframework.kafka' 'spring-kafka'
    'mail'               = New-Dep $boot 'spring-boot-starter-mail'
    'quartz'             = New-Dep $boot 'spring-boot-starter-quartz'
    'batch'              = New-Dep $boot 'spring-boot-starter-batch'
    # Utilita'
    'lombok'             = New-Dep 'org.projectlombok' 'lombok' $null '${lombok.version}' -Optional
    'common-dto'         = New-Dep 'com.example' 'common-dto' $null '${project.version}'
    'test'               = New-Dep $boot 'spring-boot-starter-test' 'test'
}

if ($List) {
    Write-Host ''
    Write-Host 'Nomi brevi riconosciuti da task add-dep:' -ForegroundColor Cyan
    Write-Host ''
    foreach ($key in $catalog.Keys) {
        $dep = $catalog[$key]
        $extra = @()
        if ($dep.Scope) { $extra += "scope $($dep.Scope)" }
        if ($dep.Version) { $extra += "versione $($dep.Version)" }
        $suffix = ''
        if ($extra.Count -gt 0) { $suffix = '  (' + ($extra -join ', ') + ')' }
        Write-Host ("  {0,-16}{1}:{2}{3}" -f $key, $dep.Group, $dep.Artifact, $suffix)
    }
    Write-Host ''
    Write-Host 'Non in elenco? Passa le coordinate: DEPS=gruppo:artefatto:versione'
    Write-Host ''
    Write-Host 'devtools non serve aggiungerlo: e'' nel pom padre, quindi ce l''hanno gia'' tutti i moduli.'
    Write-Host ''
    exit 0
}

if (-not $Module -or -not $Deps) {
    throw "Uso: task add-dep SERVICE=<modulo> DEPS=<dip1,dip2>   (elenco: task add-dep LIST=1)"
}

# --- Modulo -------------------------------------------------------------------

$pomPath = Join-Path $demoDir (Join-Path $Module 'pom.xml')
if (-not (Test-Path $pomPath)) {
    $available = (Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name }) -join ', '
    throw "Modulo '$Module' non trovato. Moduli disponibili: $available"
}

# --- Risoluzione dei nomi -----------------------------------------------------

$wanted = @()
foreach ($raw in ($Deps -split ',')) {
    $id = $raw.Trim()
    if (-not $id) { continue }
    if ($id -eq 'devtools') {
        Write-Host "  devtools: gia' nel pom padre, lo ereditano tutti i moduli. Salto." -ForegroundColor Yellow
        continue
    }
    if ($catalog.Contains($id)) {
        $wanted += $catalog[$id]
        continue
    }
    if ($id -match '^([^:\s]+):([^:\s]+)(?::([^:\s]+))?$') {
        $wanted += (New-Dep $Matches[1] $Matches[2] $null $Matches[3])
        continue
    }
    throw "Dipendenza sconosciuta: '$id'. Vedi l'elenco con: task add-dep LIST=1 (oppure passa gruppo:artefatto:versione)"
}

if ($wanted.Count -eq 0) {
    Write-Host 'Niente da aggiungere.'
    exit 0
}

# --- Inserimento nel pom ------------------------------------------------------

$pomText = Read-TextFile $pomPath
$added = @()
$lines = @()
foreach ($dep in $wanted) {
    if ($pomText -match [regex]::Escape("<artifactId>$($dep.Artifact)</artifactId>")) {
        Write-Host ("  {0}: gia' presente nel pom, salto." -f $dep.Artifact) -ForegroundColor Yellow
        continue
    }
    $lines += '        <dependency>'
    $lines += "            <groupId>$($dep.Group)</groupId>"
    $lines += "            <artifactId>$($dep.Artifact)</artifactId>"
    if ($dep.Version) { $lines += "            <version>$($dep.Version)</version>" }
    if ($dep.Scope) { $lines += "            <scope>$($dep.Scope)</scope>" }
    if ($dep.Optional) { $lines += '            <optional>true</optional>' }
    $lines += '        </dependency>'
    $added += $dep.Artifact
}

if ($added.Count -eq 0) {
    Write-Host ''
    Write-Host "Nessuna modifica: erano tutte gia' presenti."
    exit 0
}

Add-LinesBefore -Path $pomPath -Anchor '^\s*</dependencies>' -NewLines $lines

# --- Se e' stata aggiunta security, predisponi una SecurityConfig funzionante ---
if ($added -contains 'spring-boot-starter-security') {
    $package = Get-ModulePackage -Module $Module
    $packagePath = $package -replace '\.', '/'
    $configDir = Join-Path $demoDir "$Module/src/main/java/$packagePath/config"
    $securityFile = Join-Path $configDir 'SecurityConfig.java'
    if (-not (Test-Path $securityFile)) {
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
        $secSrc = @"
package $package.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Configurazione Spring Security generata da task add-dep DEPS=security.
 * Evita il blocco totale delle richieste (401/403) tipico di Spring Boot di default.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // Disabilita CSRF per consentire POST/PUT/DELETE da client REST e Postman
            .csrf(csrf -> csrf.disable())
            .headers(headers -> headers.frameOptions(frame -> frame.disable()))
            .authorizeHttpRequests(auth -> auth
                // Rotte di documentazione e diagnostica sempre aperte
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/actuator/**", "/h2-console/**").permitAll()
                // Regole di autorizzazione specifiche (modifica o decommenta se richiesto dalla traccia):
                // .requestMatchers("/api/admin/**").hasRole("ADMIN")
                // Tutte le altre richieste permesse di default per non bloccare lo stack
                .anyRequest().permitAll()
            )
            .httpBasic(httpBasic -> {});

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails admin = User.builder()
            .username("admin")
            .password(encoder.encode("admin123"))
            .roles("ADMIN", "USER")
            .build();

        UserDetails user = User.builder()
            .username("user")
            .password(encoder.encode("user123"))
            .roles("USER")
            .build();

        return new InMemoryUserDetailsManager(admin, user);
    }
}
"@
        Write-TextFile -Path $securityFile -Text ($secSrc.Trim() + "`n")
        Write-Host ''
        Write-Host "  [+] Generato $Module/src/main/java/$packagePath/config/SecurityConfig.java" -ForegroundColor Cyan
        Write-Host "      Configurazione base: Swagger e API libere, CSRF disattivato, utenti in-memory (admin/user)."
    }
}

Write-Host ''
Write-Host "==> demo/$Module/pom.xml aggiornato:" -ForegroundColor Green
foreach ($artifact in $added) { Write-Step $artifact }
Write-Host ''
Write-Host '  task dev          scarica le nuove dipendenze e riavvia lo stack'
Write-Host ''
Write-Host '  Nota: `task compile` non basta. Il classpath di un servizio e'' fissato' -ForegroundColor Yellow
Write-Host '  quando parte: un jar nuovo lo vede solo un riavvio vero, cioe'' `task dev`.' -ForegroundColor Yellow
Write-Host ''
