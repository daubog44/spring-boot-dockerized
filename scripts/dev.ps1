<#
.SYNOPSIS
    Avvia l'intero stack in locale con un solo comando, con hot reload.

.DESCRIPTION
    1. Ferma quello che fosse rimasto acceso da un avvio precedente.
    2. Compila e installa una volta sola tutti i moduli nel repository Maven locale.
    3. Avvia Eureka e ne attende la porta, poi tutti gli altri servizi.

    I servizi girano in background, senza aprire una finestra per ciascuno:
    l'output va in .dev-logs\<servizio>.log e si segue con `task logs`.

    Ogni servizio gira con spring-boot-devtools: ricompilando un modulo
    (`task compile`, o il salvataggio in VS Code con build automatica)
    il servizio corrispondente si riavvia da solo in pochi secondi.

.PARAMETER NoBuild
    Salta la compilazione iniziale (utile se hai gia' fatto `task build`).

.PARAMETER UiPort
    Porta della UI, se la 8080 e' occupata da un'altra applicazione.
#>
param(
    [switch]$NoBuild,
    [int]$UiPort = 8080
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$demoDir = Join-Path $repoRoot 'demo'
$logDir = Get-DevLogDir

# --- Configurazione dello stack (l'unica parte che cambia da traccia a traccia) ---

# Ordine di avvio: Eureka per primo, poi i servizi che vi si registrano.
$services = @(
    [pscustomobject]@{ Name = 'eureka';      Module = 'naming-server';   Port = 8761 }
    [pscustomobject]@{ Name = 'product';     Module = 'product-service'; Port = 8081 }
    [pscustomobject]@{ Name = 'crm';         Module = 'crm-service';     Port = 8082 }
    [pscustomobject]@{ Name = 'wms';         Module = 'wms-service';     Port = 8083 }
    [pscustomobject]@{ Name = 'wms-ui';      Module = 'wms-ui';          Port = $UiPort }
)

# I servizi di questa traccia usano H2 in memoria: nessun database da avviare.
$usesPostgres = $false

# --- Controlli preliminari ----------------------------------------------------

if (-not (Test-Path (Join-Path $demoDir 'mvnw.cmd'))) {
    throw "mvnw.cmd non trovato in $demoDir. Esegui lo script dalla radice del repository."
}

# Il Taskfile passa lo stesso JAVA_HOME usato da `task build`. Se quel percorso
# non esiste (JDK installato altrove) lo ignoriamo, cosi' mvnw ricade sul java
# del PATH invece di fallire con un errore poco leggibile.
if ($env:JAVA_HOME -and -not (Test-Path $env:JAVA_HOME)) {
    Write-Host "JAVA_HOME non valido ($env:JAVA_HOME): uso il java del PATH." -ForegroundColor Yellow
    Remove-Item Env:JAVA_HOME
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# --- Pulizia iniziale ---------------------------------------------------------

# Un `task dev` lanciato due volte, o dopo un crash, troverebbe le porte
# occupate dai propri stessi processi: li fermiamo prima di ricominciare.
Write-Host ''
Write-Host '==> Pulizia degli avanzi dell''avvio precedente...' -ForegroundColor Cyan
$cleaned = Stop-DevStack -LogDir $logDir
if ($cleaned -eq 0) { Write-Host '  niente da fermare.' }

# Log e wrapper degli avvii precedenti: `task logs` segue tutto quello che
# trova qui, quindi un log rimasto da un'altra traccia (dopo un cambio di
# branch) comparirebbe insieme a quelli veri.
Get-ChildItem -Path $logDir -Filter '*.log' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $logDir -Filter 'run-*.cmd' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# --- Controllo porte occupate -------------------------------------------------

function Format-Owner {
    param([int]$Port)
    $owner = Get-PortOwner -Port $Port
    if ($owner) { return "$($owner.Name) (PID $($owner.Id))" }
    return 'processo sconosciuto'
}

$inDocker = @()
$blocked = @()
$hijacked = @()
foreach ($svc in $services) {
    switch (Get-PortStatus -Port $svc.Port) {
        'docker'         { $inDocker += $svc }
        'busy'           { $blocked += $svc }
        'blocked'        { $blocked += $svc }
        'loopback-taken' { $hijacked += $svc }
    }
}

if ($inDocker.Count -gt 0) {
    Write-Host ''
    Write-Host 'Lo stack e'' gia'' in esecuzione nei container.' -ForegroundColor Red
    Write-Host ("Porte occupate: {0}" -f (($inDocker | ForEach-Object { "$($_.Name):$($_.Port)" }) -join ', '))
    Write-Host 'Scegli uno dei due modi di lavorare:' -ForegroundColor Yellow
    Write-Host '  task docker-down    # spegni i container, poi task dev'
    Write-Host '  task docker-logs    # oppure resta sui container'
    exit 1
}

if ($blocked.Count -gt 0) {
    Write-Host ''
    Write-Host 'Porte ancora occupate dopo la pulizia:' -ForegroundColor Red
    foreach ($svc in $blocked) {
        Write-Host "  $($svc.Name):$($svc.Port) -> $(Format-Owner -Port $svc.Port)"
    }
    Write-Host 'Sono processi che non abbiamo avviato noi.' -ForegroundColor Yellow
    Write-Host '  task status         # per vedere chi occupa cosa'
    exit 1
}

if ($hijacked.Count -gt 0) {
    Write-Host ''
    Write-Host 'Porte occupate su 127.0.0.1 da applicazioni estranee allo stack:' -ForegroundColor Red
    foreach ($svc in $hijacked) {
        Write-Host "  $($svc.Name):$($svc.Port) -> $(Format-Owner -Port $svc.Port)"
    }
    Write-Host ''
    Write-Host 'Tomcat non riesce a fare il bind in questa situazione e il servizio muore' -ForegroundColor Yellow
    Write-Host "con 'Web server failed to start. Port N was already in use'." -ForegroundColor Yellow
    Write-Host 'Chiudi quel processo, oppure sposta la UI su un''altra porta:' -ForegroundColor Yellow
    Write-Host '  task dev -- -UiPort 9080'
    exit 1
}

# --- Build unica --------------------------------------------------------------

if (-not $NoBuild) {
    Write-Host ''
    Write-Host '==> Compilazione di tutti i moduli (una sola volta)...' -ForegroundColor Cyan
    Push-Location $demoDir
    try {
        cmd /c ".\mvnw.cmd -q install -Dmaven.test.skip=true"
        if ($LASTEXITCODE -ne 0) {
            throw "Compilazione fallita (exit $LASTEXITCODE). Correggi gli errori e riprova."
        }
    } finally {
        Pop-Location
    }
    Write-Host '==> Compilazione completata.' -ForegroundColor Green
}

# --- PostgreSQL ---------------------------------------------------------------

if ($usesPostgres) {
    Write-Host ''
    Write-Host '==> Avvio PostgreSQL su Docker...' -ForegroundColor Cyan
    Push-Location $demoDir
    try {
        docker compose up -d postgres
        if ($LASTEXITCODE -ne 0) {
            throw 'Avvio di PostgreSQL fallito. Docker Desktop e in esecuzione?'
        }
    } finally {
        Pop-Location
    }
    if (-not (Wait-ForPort -Port 5432 -TimeoutSeconds 60 -AnyProcess)) {
        Write-Host 'PostgreSQL non risponde sulla porta 5432.' -ForegroundColor Red
        exit 1
    }
    # Segnaposto per dev-down: fermiamo il container solo se l'abbiamo avviato noi.
    Set-Content -Path (Join-Path $logDir 'dev.postgres') -Value '1' -Encoding ascii
    Write-Host '==> PostgreSQL pronto.' -ForegroundColor Green
}

# --- Avvio ordinato -----------------------------------------------------------

function Start-DevService {
    param([string]$Name, [string]$Module, [int]$Port)

    $moduleDir = Join-Path $demoDir $Module
    $logFile = Join-Path $logDir "$Name.log"

    # Un piccolo wrapper .cmd per servizio: evita di far passare virgolette
    # annidate attraverso Start-Process, ed e' ispezionabile se qualcosa non va.
    $runner = Join-Path $logDir "run-$Name.cmd"
    @(
        '@echo off'
        "cd /d ""$moduleDir"""
        "..\mvnw.cmd spring-boot:run ""-Dspring-boot.run.arguments=--server.port=$Port"" > ""$logFile"" 2>&1"
    ) | Set-Content -Path $runner -Encoding ascii

    # Nessuna finestra: l'output e' gia' sul file, e `task logs` li segue tutti.
    $proc = Start-Process -FilePath $runner -WindowStyle Hidden -PassThru
    return $proc.Id
}

function Show-LogTail {
    param([string]$Name, [int]$Lines = 25)

    $logFile = Join-Path $logDir "$Name.log"
    if (-not (Test-Path $logFile)) { return }
    Write-Host ''
    Write-Host "--- ultime righe di $Name.log ---" -ForegroundColor Yellow
    Get-Content $logFile -Tail $Lines | ForEach-Object { Write-Host "  $_" }
}

# Registra le porte realmente usate (possono differire dai default per via di
# -UiPort), cosi' la pulizia sa quali porte liberare anche al prossimo avvio.
$services | ForEach-Object { $_.Port } | Set-Content -Path (Join-Path $logDir 'dev.ports') -Encoding ascii
# I nomi, nell'ordine di avvio: `task logs` li segue in quest'ordine.
$services | ForEach-Object { $_.Name } | Set-Content -Path (Join-Path $logDir 'dev.services') -Encoding ascii
$pidFile = Join-Path $logDir 'dev.pids'
Set-Content -Path $pidFile -Value '' -Encoding ascii

$startedOk = $false
try {
    foreach ($svc in $services) {
        Write-Host "==> Avvio $($svc.Name) sulla porta $($svc.Port)..." -ForegroundColor Cyan
        $processId = Start-DevService -Name $svc.Name -Module $svc.Module -Port $svc.Port
        Add-Content -Path $pidFile -Value "$processId $($svc.Name)" -Encoding ascii

        # Eureka deve essere in ascolto prima che gli altri tentino di registrarsi,
        # altrimenti la prima registrazione slitta di un intero ciclo di heartbeat.
        if ($svc.Name -eq 'eureka') {
            if (-not (Wait-ForPort -Port $svc.Port)) {
                Write-Host "Eureka non risponde sulla porta $($svc.Port)." -ForegroundColor Red
                Show-LogTail -Name $svc.Name
                return
            }
            Write-Host '==> Eureka pronto.' -ForegroundColor Green
        }
    }

    Write-Host ''
    Write-Host '==> Attendo che i servizi siano in ascolto...' -ForegroundColor Cyan
    $failed = @()
    foreach ($svc in ($services | Where-Object { $_.Name -ne 'eureka' })) {
        if (Wait-ForPort -Port $svc.Port) {
            Write-Host ("    {0,-8} :{1}  OK" -f $svc.Name, $svc.Port) -ForegroundColor Green
        } else {
            Write-Host ("    {0,-8} :{1}  NON PARTITO" -f $svc.Name, $svc.Port) -ForegroundColor Red
            $failed += $svc.Name
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host ''
        Write-Host "Servizi non partiti: $($failed -join ', ')." -ForegroundColor Red
        foreach ($name in $failed) { Show-LogTail -Name $name }
        return
    }

    $startedOk = $true
} finally {
    # Se l'avvio fallisce a meta' (o lo interrompi con Ctrl+C) non lasciamo in
    # giro servizi a occupare le porte: il prossimo `task dev` ripartirebbe male.
    if (-not $startedOk) {
        Write-Host ''
        Write-Host '==> Avvio non riuscito: fermo i servizi gia'' partiti...' -ForegroundColor Yellow
        Stop-DevStack -LogDir $logDir | Out-Null
    }
}

if (-not $startedOk) { exit 1 }

Write-Host ''
Write-Host 'Stack locale avviato.' -ForegroundColor Green
Write-Host ''
Write-Host "  UI WMS            http://localhost:$UiPort"
Write-Host '  Dashboard Eureka  http://localhost:8761'
Write-Host '  Swagger product   http://localhost:8081/swagger-ui.html'
Write-Host '  Swagger crm       http://localhost:8082/swagger-ui.html'
Write-Host '  Swagger wms       http://localhost:8083/swagger-ui.html'
Write-Host ''
Write-Host '  task logs         segue i log di tutti i servizi (Ctrl+C per uscire)'
Write-Host '  task logs -- wms  solo quel servizio'
Write-Host '  task status       chi occupa le porte'
Write-Host '  task dev-down     ferma tutto'
Write-Host ''
Write-Host 'Hot reload attivo: dopo una modifica lancia `task compile` e il servizio si riavvia da solo.'
Write-Host 'Nota: i client Feign impiegano 10-15 secondi ad aggiornare il registro Eureka.' -ForegroundColor Yellow
