<#
.SYNOPSIS
    Ferma lo stack locale avviato con `task dev` e libera le porte.

.DESCRIPTION
    Usa le stesse funzioni con cui `task dev` fa pulizia all'avvio: termina i
    processi registrati in .dev-logs\dev.pids e qualunque java rimasto in
    ascolto sulle porte dello stack. I processi estranei (Docker, o un'altra
    applicazione qualsiasi della macchina) vengono solo segnalati.

    Se `task dev` aveva avviato PostgreSQL, ferma anche quel container: il
    volume resta, quindi i dati non si perdono.
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Get-DevLogDir

$stopped = Stop-DevStack -LogDir $logDir

# PostgreSQL: solo se e' stato `task dev` ad accenderlo (lo segnala con questo
# file). `stop` e non `down`, cosi' il volume con i dati resta al suo posto.
$pgMarker = Join-Path $logDir 'dev.postgres'
if (Test-Path $pgMarker) {
    Write-Host '  fermo il container PostgreSQL'
    Push-Location (Join-Path $repoRoot 'demo')
    try {
        docker compose stop postgres | Out-Null
    } catch {
        Write-Host '  (Docker non raggiungibile: container gia fermo?)' -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
    Remove-Item $pgMarker -Force -ErrorAction SilentlyContinue
    $stopped++
}

if ($stopped -eq 0) {
    Write-Host 'Nessun processo dello stack locale in esecuzione.' -ForegroundColor Yellow
} else {
    Write-Host 'Stack locale fermato, porte libere.' -ForegroundColor Green
}
