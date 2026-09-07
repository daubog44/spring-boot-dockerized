<#
.SYNOPSIS
    Avvia l'intero stack in locale con un solo comando, con hot reload.

.DESCRIPTION
    1. Compila e installa una volta sola tutti i moduli nel repository Maven locale.
    2. Avvia Eureka e ne attende la porta.
    3. Avvia gli altri servizi in parallelo, ognuno nella propria finestra.

    Ogni servizio gira con spring-boot-devtools: ricompilando un modulo
    (`task compile`, o il salvataggio in VS Code con build automatica)
    il servizio corrispondente si riavvia da solo in pochi secondi.

.PARAMETER NoBuild
    Salta la compilazione iniziale (utile se hai gia' fatto `task build`).
#>
param(
    [switch]$NoBuild,
    [int]$UiPort = 8080
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$demoDir = Join-Path $repoRoot 'demo'
$logDir = Join-Path $repoRoot '.dev-logs'

if (-not (Test-Path (Join-Path $demoDir 'mvnw.cmd'))) {
    throw "mvnw.cmd non trovato in $demoDir. Esegui lo script dalla radice del repository."
}

# Ordine di avvio: Eureka per primo, poi i servizi che vi si registrano.
$services = @(
    [pscustomobject]@{ Name = 'eureka';      Module = 'naming-server';   Port = 8761 }
    [pscustomobject]@{ Name = 'tourist';     Module = 'tourist-service'; Port = 8081 }
    [pscustomobject]@{ Name = 'random';      Module = 'random-service';  Port = 8082 }
    [pscustomobject]@{ Name = 'store';       Module = 'store-service';   Port = 8083 }
    [pscustomobject]@{ Name = 'ui';          Module = 'event-ui';        Port = $UiPort }
)

function Test-CanBind {
    param([System.Net.IPAddress]$Address, [int]$Port)
    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new($Address, $Port)
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener) { $listener.Stop() }
    }
}

function Get-PortStatus {
    param([int]$Port)

    # Spring Boot fa bind su 0.0.0.0: se questo fallisce il servizio non parte.
    if (-not (Test-CanBind -Address ([System.Net.IPAddress]::Any) -Port $Port)) {
        return 'blocked'
    }
    # Il bind su 0.0.0.0 riesce ma qualcuno tiene 127.0.0.1: su Windows il bind
    # piu' specifico vince, quindi http://localhost:PORT servirebbe l'altro processo.
    if (-not (Test-CanBind -Address ([System.Net.IPAddress]::Loopback) -Port $Port)) {
        return 'loopback-taken'
    }
    return 'free'
}

function Get-PortOwner {
    param([int]$Port)
    try {
        $owner = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty OwningProcess
        $proc = Get-Process -Id $owner -ErrorAction SilentlyContinue
        if ($proc) { return "$($proc.ProcessName) (PID $owner)" }
    } catch {
        # nessun listener individuabile
    }
    return 'processo sconosciuto'
}

function Wait-ForPort {
    param([int]$Port, [string]$Name, [int]$TimeoutSeconds = 120, [switch]$AnyProcess)

    # Non basta che la porta risponda: un'applicazione estranea in ascolto sulla
    # stessa porta darebbe un falso positivo. Attendiamo un processo java.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $owners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop |
                Select-Object -ExpandProperty OwningProcess -Unique
            foreach ($owner in $owners) {
                if ($AnyProcess) { return $true }
                $proc = Get-Process -Id $owner -ErrorAction SilentlyContinue
                if ($proc -and $proc.ProcessName -eq 'java') { return $true }
            }
        } catch {
            # nessun listener sulla porta: riprova
        }
        Start-Sleep -Milliseconds 700
    }
    return $false
}

function Start-DevService {
    param([string]$Name, [string]$Module, [int]$Port)

    $moduleDir = Join-Path $demoDir $Module
    $title = "$Name (:$Port)"
    # -NoExit: la finestra resta aperta anche se il servizio va in errore,
    # cosi' lo stack trace resta leggibile.
    $runArgs = "'-Dspring-boot.run.arguments=--server.port=$Port'"
    $logFile = Join-Path $logDir "$Name.log"
    # L'output va sia a video sia su file, cosi' resta consultabile dopo aver
    # chiuso la finestra e permette di seguire i riavvii di devtools.
    $command = "`$Host.UI.RawUI.WindowTitle = '$title'; Set-Location '$moduleDir'; ..\mvnw.cmd spring-boot:run $runArgs 2>&1 | Tee-Object -FilePath '$logFile'"
    Start-Process -FilePath 'powershell' -ArgumentList '-NoExit', '-NoProfile', '-Command', $command | Out-Null
}

# --- Controllo porte occupate -------------------------------------------------

$blocked = @()
$hijacked = @()
foreach ($svc in $services) {
    switch (Get-PortStatus -Port $svc.Port) {
        'blocked'        { $blocked += $svc }
        'loopback-taken' { $hijacked += $svc }
    }
}

if ($blocked.Count -gt 0) {
    Write-Host ''
    Write-Host 'Porte gia occupate: ' -ForegroundColor Red -NoNewline
    Write-Host (($blocked | ForEach-Object { "$($_.Name):$($_.Port) -> $(Get-PortOwner -Port $_.Port)" }) -join ', ')
    Write-Host 'Lo stack Docker e ancora attivo, oppure sono rimasti processi Java appesi.' -ForegroundColor Yellow
    Write-Host '  task docker-down    # se hai avviato i container'
    Write-Host '  task dev-down       # se sono processi Java locali'
    exit 1
}

if ($hijacked.Count -gt 0) {
    Write-Host ''
    Write-Host 'Porte occupate su 127.0.0.1 da applicazioni estranee allo stack:' -ForegroundColor Red
    foreach ($svc in $hijacked) {
        Write-Host "  $($svc.Name):$($svc.Port) -> $(Get-PortOwner -Port $svc.Port)"
    }
    Write-Host ''
    Write-Host "Tomcat non riesce a fare il bind in questa situazione e il servizio muore" -ForegroundColor Yellow
    Write-Host "con 'Web server failed to start. Port N was already in use'." -ForegroundColor Yellow
    Write-Host 'Chiudi quel processo, oppure sposta la UI su unaltra porta:' -ForegroundColor Yellow
    Write-Host '  task dev -- -UiPort 9080'
    exit 1
}

# --- Build unica --------------------------------------------------------------

# --- PostgreSQL ---------------------------------------------------------------
# store-service punta a jdbc:postgresql://localhost:5432 e non parte senza database.

Write-Host ''
Write-Host '==> Avvio PostgreSQL su Docker...' -ForegroundColor Cyan
Push-Location $demoDir
try {
    docker compose up -d postgres
    if ($LASTEXITCODE -ne 0) {
        throw "Avvio di PostgreSQL fallito. Docker Desktop e in esecuzione?"
    }
} finally {
    Pop-Location
}
if (-not (Wait-ForPort -Port 5432 -Name 'postgres' -TimeoutSeconds 60 -AnyProcess)) {
    Write-Host 'PostgreSQL non risponde sulla porta 5432.' -ForegroundColor Red
    exit 1
}
Write-Host '==> PostgreSQL pronto.' -ForegroundColor Green

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

# --- Avvio ordinato -----------------------------------------------------------

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# Registra le porte realmente usate (possono differire dai default per via di
# -UiPort), cosi' dev-down sa quali processi fermare.
$services | ForEach-Object { $_.Port } | Set-Content -Path (Join-Path $logDir 'dev.ports') -Encoding ascii

foreach ($svc in $services) {
    Write-Host "==> Avvio $($svc.Name) sulla porta $($svc.Port)..." -ForegroundColor Cyan
    Start-DevService -Name $svc.Name -Module $svc.Module -Port $svc.Port

    # Eureka deve essere in ascolto prima che gli altri tentino di registrarsi,
    # altrimenti la prima registrazione slitta di un intero ciclo di heartbeat.
    if ($svc.Name -eq 'eureka') {
        if (-not (Wait-ForPort -Port $svc.Port -Name $svc.Name)) {
            Write-Host "Eureka non risponde sulla porta $($svc.Port): controlla la sua finestra." -ForegroundColor Red
            exit 1
        }
        Write-Host '==> Eureka pronto.' -ForegroundColor Green
    }
}

# --- Attesa dei servizi -------------------------------------------------------

Write-Host ''
Write-Host '==> Attendo che i servizi siano in ascolto...' -ForegroundColor Cyan
$failed = @()
foreach ($svc in $services | Where-Object { $_.Name -ne 'eureka' }) {
    if (Wait-ForPort -Port $svc.Port -Name $svc.Name) {
        Write-Host ("    {0,-8} :{1}  OK" -f $svc.Name, $svc.Port) -ForegroundColor Green
    } else {
        Write-Host ("    {0,-8} :{1}  NON PARTITO" -f $svc.Name, $svc.Port) -ForegroundColor Red
        $failed += $svc.Name
    }
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "Servizi non partiti: $($failed -join ', '). Leggi l'errore nella loro finestra." -ForegroundColor Red
    exit 1
}

Write-Host 'Stack locale avviato.' -ForegroundColor Green
Write-Host ''
Write-Host "  UI applicativa    http://localhost:$UiPort"
Write-Host '  Dashboard Eureka  http://localhost:8761'
Write-Host '  Swagger tourist   http://localhost:8081/swagger-ui.html'
Write-Host '  Swagger random    http://localhost:8082/swagger-ui.html'
Write-Host '  Swagger store     http://localhost:8083/swagger-ui.html'
Write-Host ''
Write-Host "Log dei servizi in $logDir"
Write-Host 'Hot reload attivo: dopo una modifica lancia `task compile` e il servizio si riavvia da solo.'
Write-Host 'Per fermare tutto: task dev-down'
Write-Host ''
Write-Host 'Nota: i client Feign impiegano 10-15 secondi ad aggiornare il registro Eureka.' -ForegroundColor Yellow
