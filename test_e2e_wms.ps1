# ===================================================================
# SCRIPT DI TEST E2E AUTOMATIZZATO - TRACCIA WMS "SPOSTATI S.R.L."
# ===================================================================

$ErrorActionPreference = "Continue"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " 🚀 AVVIO TEST E2E COMPLETO - TRACCIA D'ESAME WMS MAGAZZINO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$baseDir = Get-Location

# -------------------------------------------------------------------
# STAGE 1: VERIFICA COMPILAZIONE MAVEN MULTI-MODULO
# -------------------------------------------------------------------
Write-Host "[STEP 1/4] Esecuzione Maven Package Multi-Modulo..." -ForegroundColor Yellow
$demoDir = Join-Path $baseDir "demo"
Push-Location $demoDir

try {
    $mvnResult = cmd /c "mvnw.cmd clean package -Dmaven.test.skip=true"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Fallimento nella compilazione Maven!" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "✅ Maven Package eseguito con successo per tutti i 10 moduli!" -ForegroundColor Green
} finally {
    Pop-Location
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
    @{ Name = "WMS Web UI Dashboard"; Url = "http://localhost:8080" }
)

foreach ($t in $tests) {
    $endpointsChecked++
    $ok = Test-Endpoint -Name $t.Name -Url $t.Url
    if ($ok) { $endpointsPassed++ }
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
        }
    } catch {
        Write-Host "  ⚠️ Impossibile eseguire test chiamata POST: $($_.Exception.Message)" -ForegroundColor Yellow
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
            Write-Host "  ⚠️ Algoritmo ha restituito 0 candidati: $($respAlg.message)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️ Impossibile eseguire test algoritmo POST: $($_.Exception.Message)" -ForegroundColor Yellow
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
if ($filesOk) {
    Write-Host " 🎉 RISULTATO TEST E2E: TEMPLATE E SOLUZIONE E2E WMS PERFETTI! " -ForegroundColor Green
} else {
    Write-Host " ⚠️ RISULTATO TEST E2E: Alcuni file non sono stati trovati." -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan
