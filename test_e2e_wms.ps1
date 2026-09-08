# ===================================================================
# SCRIPT DI TEST E2E AUTOMATIZZATO - TRACCIA WMS "SPOSTATI S.R.L."
# ===================================================================

param(
    # Porta su cui risponde la UI. Va allineata a quella usata all'avvio: con
    # `task dev -- -UiPort 9080` passa 9080, altrimenti il controllo interrogherebbe
    # qualunque altra applicazione occupi la 8080, dando un falso positivo.
    [int]$UiPort = 8080
)

$ErrorActionPreference = "Continue"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " 🚀 AVVIO TEST E2E COMPLETO - TRACCIA D'ESAME WMS MAGAZZINO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$baseDir = Get-Location
. (Join-Path $PSScriptRoot 'scripts\dev-lib.ps1')

# -------------------------------------------------------------------
# STAGE 1: VERIFICA COMPILAZIONE MAVEN MULTI-MODULO
# -------------------------------------------------------------------
Write-Host "[STEP 1/4] Esecuzione Maven Package Multi-Modulo..." -ForegroundColor Yellow
$demoDir = Join-Path $baseDir "demo"

# Quali servizi locali sono accesi in questo momento. Se ce ne sono, il `clean`
# cancellerebbe le classi sotto i piedi di spring-boot-devtools: il riavvio
# automatico partirebbe con il classpath a meta' e il servizio morirebbe con
# "APPLICATION FAILED TO START ... required a bean that could not be found".
$logDir = Get-DevLogDir
# Quello che va storto nei controlli dal vivo: decide l'esito finale, cosi'
# `task test-e2e` fallisce davvero quando qualcosa non va, invece di stampare
# un banner verde su un collaudo mezzo saltato.
$liveProblems = @()
$runningPorts = @()
foreach ($port in (Get-DevPorts -LogDir $logDir)) {
    if (Get-PortListeners -Port $port | Where-Object { $_.IsOurs }) { $runningPorts += $port }
}

$goals = "clean package"
if ($runningPorts.Count -gt 0) {
    $goals = "package"
    Write-Host "  ℹ️ Stack locale acceso: compilo senza 'clean' per non farlo cadere." -ForegroundColor Cyan
}

Push-Location $demoDir
try {
    $mvnResult = cmd /c ".\mvnw.cmd $goals -Dmaven.test.skip=true"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Fallimento nella compilazione Maven!" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    $moduleCount = ([regex]'<module>').Matches((Get-Content (Join-Path $demoDir 'pom.xml') -Raw)).Count
    Write-Host "✅ Maven Package eseguito con successo per tutti i $moduleCount moduli!" -ForegroundColor Green
} finally {
    Pop-Location
}

# La ricompilazione fa ripartire i servizi via devtools: senza questa attesa i
# controlli sugli endpoint li troverebbero ancora in fase di riavvio.
if ($runningPorts.Count -gt 0) {
    Write-Host "  🔄 Attendo il riavvio automatico dei servizi (devtools)..." -ForegroundColor Cyan
    $notBack = @()
    foreach ($port in $runningPorts) {
        if (-not (Wait-ForPort -Port $port -TimeoutSeconds 120)) { $notBack += $port }
    }
    if ($notBack.Count -gt 0) {
        Write-Host "  ❌ Non sono tornati su dopo il riavvio: $($notBack -join ', '). Guarda 'task logs'." -ForegroundColor Red
        $liveProblems += "servizi non ripartiti dopo la ricompilazione: $($notBack -join ', ')"
    } else {
        Write-Host "  ✅ Tutti i servizi sono tornati in ascolto." -ForegroundColor Green
    }
}

Write-Host ""
# -------------------------------------------------------------------
# STAGE 2: AVVIO E CHECK SALUTE DEGLI ENDPOINT HTTP
# -------------------------------------------------------------------
Write-Host "[STEP 2/4] Verifico la raggiungibilità degli endpoint e contratti OpenAPI..." -ForegroundColor Yellow

function Test-Endpoint {
    param (
        [string]$Name,
        [string]$Url,
        [int]$ExpectedStatusCode = 200
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq $ExpectedStatusCode) {
            Write-Host "  ✅ [$Name] -> OK (Status $ExpectedStatusCode)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ❌ [$Name] -> Status inatteso: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ⚠️ [$Name] -> Non raggiungibile su $Url (Servizio non avviato in locale/Docker: $($_.Exception.Message))" -ForegroundColor Yellow
        return $false
    }
}

$endpointsChecked = 0
$endpointsPassed = 0

$tests = @(
    @{ Name = "Eureka Dashboard"; Url = "http://localhost:8761" },
    @{ Name = "Product Service REST"; Url = "http://localhost:8081/api/products" },
    @{ Name = "Product Swagger UI"; Url = "http://localhost:8081/swagger-ui.html" },
    @{ Name = "CRM Service REST"; Url = "http://localhost:8082/api/customers" },
    @{ Name = "CRM Swagger UI"; Url = "http://localhost:8082/swagger-ui.html" },
    @{ Name = "WMS Service Locations"; Url = "http://localhost:8083/api/wms/locations" },
    @{ Name = "WMS Swagger UI"; Url = "http://localhost:8083/swagger-ui.html" },
    @{ Name = "WMS Web UI Dashboard"; Url = "http://localhost:$UiPort" }
)

foreach ($t in $tests) {
    $endpointsChecked++
    $ok = Test-Endpoint -Name $t.Name -Url $t.Url
    if ($ok) { $endpointsPassed++ }
}

if ($runningPorts.Count -gt 0 -and $endpointsPassed -lt $endpointsChecked) {
    $liveProblems += "$($endpointsChecked - $endpointsPassed) endpoint su $endpointsChecked non hanno risposto"
}

Write-Host ""
# -------------------------------------------------------------------
# STAGE 3: TEST DELLA LOGICA APPLICATIVA E DEGLI ALGORITMI (OFFLINE/ONLINE)
# -------------------------------------------------------------------
Write-Host "[STEP 3/4] Verifica logica di Business & Algoritmo Ubicazione Vicina..." -ForegroundColor Yellow

if ($endpointsPassed -ge 3) {
    Write-Host "  🔄 Esecuzione chiamate di test E2E sugli endpoint attivi..." -ForegroundColor Cyan

    # Test Movimentazione Errore (Pezzi Insufficienti)
    try {
        $body = @{
            sourceLocationId = 1
            destLocationId = 2
            quantity = 999
        } | ConvertTo-Json

        $resp = Invoke-RestMethod -Uri "http://localhost:8083/api/wms/movements" -Method Post -Body $body -ContentType "application/json"
        if ($resp.success -eq $false) {
            Write-Host "  ✅ Validazione quantità insufficiente: OK ('$($resp.message)')" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Risultato inatteso su movimentazione non valida!" -ForegroundColor Red
            $liveProblems += "la movimentazione con quantita' eccessiva non e' stata respinta"
        }
    } catch {
        Write-Host "  ❌ Impossibile eseguire test chiamata POST: $($_.Exception.Message)" -ForegroundColor Red
        $liveProblems += "chiamata POST /api/wms/movements fallita"
    }

    # Test Algoritmo Ubicazione Vicina
    try {
        $bodyAlg = @{
            sourceLocationId = 1
            quantity = 1
        } | ConvertTo-Json

        $respAlg = Invoke-RestMethod -Uri "http://localhost:8083/api/wms/nearest-location" -Method Post -Body $bodyAlg -ContentType "application/json"
        if ($respAlg.nearestLocation -ne $null) {
            Write-Host "  ✅ Algoritmo Distanza Manhattan: OK (Trovata ubicazione #$($respAlg.nearestLocation.id) a distanza d=$($respAlg.distance))" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Algoritmo ha restituito 0 candidati: $($respAlg.message)" -ForegroundColor Red
            $liveProblems += "l'algoritmo della ubicazione piu' vicina non ha trovato candidati"
        }
    } catch {
        Write-Host "  ❌ Impossibile eseguire test algoritmo POST: $($_.Exception.Message)" -ForegroundColor Red
        $liveProblems += "chiamata POST /api/wms/nearest-location fallita"
    }
} else {
    Write-Host "  ℹ️ Lo stack di container Docker o le app locali non sono attualmente accese." -ForegroundColor Yellow
    Write-Host "  ℹ️ Nota: Puoi avviare lo stack con 'task docker-up' e ri-eseguire 'task test-e2e' per la verifica live!" -ForegroundColor Yellow
}

Write-Host ""
# -------------------------------------------------------------------
# STAGE 4: COLLAUDO STRUTTURA ED INTEGRITA' SORGENTI
# -------------------------------------------------------------------
Write-Host "[STEP 4/4] Verifica file di configurazione ed integrità repository..." -ForegroundColor Yellow

$requiredFiles = @(
    "demo/pom.xml",
    "demo/docker-compose.yml",
    "demo/Dockerfile",
    "demo/product-service/pom.xml",
    "demo/crm-service/pom.xml",
    "demo/wms-service/pom.xml",
    "demo/wms-ui/pom.xml",
    "guida_setup_e_cheatsheet.md",
    "guida_prova_finale_spring_boot.md",
    "guida_multi_modulo_maven.md"
)

$filesOk = $true
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $baseDir $file
    if (Test-Path $filePath) {
        Write-Host "  ✅ File $file presente" -ForegroundColor Green
    } else {
        Write-Host "  ❌ File $file mancante!" -ForegroundColor Red
        $filesOk = $false
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if (-not $filesOk) { $liveProblems += "mancano dei file attesi nel repository" }

if ($liveProblems.Count -gt 0) {
    Write-Host " ❌ RISULTATO TEST E2E: ci sono problemi da guardare." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Cyan
    foreach ($problem in $liveProblems) { Write-Host "   - $problem" -ForegroundColor Red }
    Write-Host ""
    exit 1
}

if ($endpointsPassed -eq 0) {
    # Struttura e compilazione sono a posto, ma niente e' stato provato davvero:
    # dirlo, invece di far passare per collaudato quello che non lo e'.
    Write-Host " ⚠️ RISULTATO: struttura e compilazione OK, ma i servizi erano spenti." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   Avvia lo stack con 'task dev' (o 'task docker-up') e rilancia" -ForegroundColor Yellow
    Write-Host "   'task test-e2e' per il collaudo vero." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host " 🎉 RISULTATO TEST E2E: TEMPLATE E SOLUZIONE E2E WMS PERFETTI! " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
exit 0
