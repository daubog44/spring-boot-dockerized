<#
.SYNOPSIS
    Ferma lo stack locale avviato con `task dev` e libera le porte.

.DESCRIPTION
    Usa le stesse funzioni con cui `task dev` fa pulizia all'avvio, quindi i
    due comandi non possono comportarsi in modo diverso: termina i processi
    registrati in .dev-logs\dev.pids, qualunque java rimasto in ascolto sulle
    porte dello stack, i container dell'esame e le applicazioni estranee che
    tengono quelle porte. Restano intoccati i processi di sistema e
    l'infrastruttura di Docker.

    Se `task dev` aveva avviato PostgreSQL, ferma anche quel container: il
    volume resta, quindi i dati non si perdono.

.PARAMETER KeepForeign
    Non chiudere le applicazioni estranee: le segnala soltanto.
#>
param([switch]$KeepForeign)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Get-DevLogDir

$stopped = Stop-DevStack -LogDir $logDir -RepoRoot $repoRoot -KeepForeign:$KeepForeign

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
