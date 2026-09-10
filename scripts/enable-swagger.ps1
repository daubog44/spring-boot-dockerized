<#
.SYNOPSIS
    Accende Swagger UI su un modulo che non ce l'ha.

.DESCRIPTION
    I moduli creati con `task new-service` hanno gia' springdoc: la dipendenza
    nel pom e il blocco `springdoc:` nell'application.yml, quindi
    `http://localhost:<porta>/swagger-ui.html` risponde dal primo avvio, sia per
    un servizio REST sia per una UI.

    Questo comando serve per gli altri casi: un modulo scritto a mano, uno da
    cui la dipendenza e' stata tolta, o un progetto ripreso da un'altra fonte.
    E' idempotente: se c'e' gia' tutto, non tocca niente.

.PARAMETER Module
    Cartella del modulo sotto demo/.

.EXAMPLE
    task enable-swagger SERVICE=ordini-service
#>
param([string]$Module = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$moduleDir = Join-Path $demoDir $Module

if (-not $Module) {
    throw "Uso: task enable-swagger SERVICE=<modulo>"
}
$pomPath = Join-Path $moduleDir 'pom.xml'
if (-not (Test-Path $pomPath)) {
    $available = (Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name }) -join ', '
    throw "Modulo '$Module' non trovato. Moduli disponibili: $available"
}

Write-Host ''
Write-Host "==> Swagger UI su $Module" -ForegroundColor Cyan
Write-Host ''

$touched = $false

# --- 1. La dipendenza nel pom -------------------------------------------------

$pom = Read-TextFile $pomPath
if ($pom -match '<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>') {
    Write-Step 'pom.xml: springdoc gia'' presente'
} else {
    Add-LinesBefore -Path $pomPath -Anchor '^\s*</dependencies>' -NewLines @(
        '        <dependency>'
        '            <groupId>org.springdoc</groupId>'
        '            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>'
        '        </dependency>'
    )
    Write-Step 'pom.xml: aggiunta la dipendenza springdoc'
    $touched = $true
}

# Senza spring-web non c'e' niente da documentare: springdoc legge i controller.
if ($pom -notmatch '<artifactId>spring-boot-starter-web</artifactId>') {
    Write-Host '  Attenzione: questo modulo non ha spring-boot-starter-web.' -ForegroundColor Yellow
    Write-Host '  Swagger documenta i controller REST: senza web non c''e'' niente da mostrare.' -ForegroundColor Yellow
    Write-Host "  task add-dep SERVICE=$Module DEPS=web" -ForegroundColor Yellow
}

# --- 2. Il blocco nell'application.yml ---------------------------------------

$ymlPath = Join-Path $moduleDir 'src/main/resources/application.yml'
if (-not (Test-Path $ymlPath)) {
    throw "Non trovo ${ymlPath}: il modulo non ha una configurazione da estendere."
}

$yml = Read-TextFile $ymlPath
if ($yml -match '(?m)^springdoc:') {
    Write-Step 'application.yml: blocco springdoc gia'' presente'
} else {
    $eol = Get-TextEol $yml
    $block = @(
        ''
        'springdoc:'
        '  api-docs:'
        '    path: /v3/api-docs'
        '  swagger-ui:'
        '    path: /swagger-ui.html'
    )
    $text = $yml.TrimEnd("`r", "`n") + $eol + ($block -join $eol) + $eol
    Write-TextFile -Path $ymlPath -Text $text
    Write-Step 'application.yml: aggiunto il blocco springdoc'
    $touched = $true
}

# --- Fatto --------------------------------------------------------------------

$port = ''
$hit = [regex]::Match((Read-TextFile $ymlPath), 'SERVER_PORT:(\d+)')
if ($hit.Success) { $port = $hit.Groups[1].Value }

Write-Host ''
if (-not $touched) {
    Write-Host 'Era gia'' tutto a posto: non ho cambiato niente.' -ForegroundColor Green
} else {
    Write-Host 'Swagger UI abilitato.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  task dev          per vederlo (una dipendenza nuova non entra a caldo)'
}
Write-Host ''
if ($port) {
    Write-Host "  http://localhost:$port/swagger-ui.html"
    Write-Host "  http://localhost:$port/v3/api-docs"
}
Write-Host ''
