<#
.SYNOPSIS
    Toglie un modulo dal progetto, e da tutti i file che lo nominano.

.DESCRIPTION
    L'inverso di new-service: cancella la cartella del modulo e lo toglie dai
    <modules> del pom aggregatore, dalla COPY nel Dockerfile, dal blocco in
    docker-compose.yml e dalla lista dei servizi di dev.ps1 e dev.sh.

    Prima di cancellare avvisa se qualche altro modulo lo chiama (client Feign
    o riferimenti al suo nome), perche' quel codice smetterebbe di compilare.

    Quello che cancella e' comunque recuperabile: il repository e' sotto git.

.PARAMETER Module
    Cartella del modulo sotto demo/.

.EXAMPLE
    task remove-service SERVICE=ordini-service
#>
param([string]$Module = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$moduleDir = Join-Path $demoDir $Module

if (-not $Module) {
    throw "Uso: task remove-service SERVICE=<modulo>"
}
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    $available = (Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name }) -join ', '
    throw "Modulo '$Module' non trovato. Moduli disponibili: $available"
}

Write-Host ''
Write-Host "==> Tolgo il modulo $Module" -ForegroundColor Cyan
Write-Host ''

# --- Chi lo chiama? -----------------------------------------------------------

# I servizi si chiamano per nome (spring.application.name), quindi cerchiamo
# quello, non il nome della cartella.
$appName = $Module.ToUpper()
$callers = @()
foreach ($file in (Get-ChildItem -Path $demoDir -Recurse -File -Include '*.java', '*.html' -ErrorAction SilentlyContinue)) {
    if ($file.FullName.StartsWith($moduleDir)) { continue }
    if ($file.FullName -match '\\target\\') { continue }
    $text = Read-TextFile $file.FullName
    if ($text -match [regex]::Escape($appName) -or $text -match [regex]::Escape($Module)) {
        $callers += $file.FullName.Substring($repoRoot.Length + 1)
    }
}

# --- Rimozione ----------------------------------------------------------------

function Remove-MatchingLine {
    param([string]$Path, [string]$Pattern, [string]$Label)
    $text = Read-TextFile $Path
    $eol = Get-TextEol $text
    $lines = @(Split-TextLines $text)
    $kept = @($lines | Where-Object { $_ -notmatch $Pattern })
    if ($kept.Count -eq $lines.Count) { return $false }
    Write-TextFile -Path $Path -Text ($kept -join $eol)
    Write-Step $Label
    return $true
}

Remove-Item -Recurse -Force $moduleDir
Write-Step "demo/$Module/ (cartella)"

[void](Remove-MatchingLine -Path (Join-Path $demoDir 'pom.xml') -Pattern ('<module>' + [regex]::Escape($Module) + '</module>') -Label 'demo/pom.xml')
[void](Remove-MatchingLine -Path (Join-Path $demoDir 'Dockerfile') -Pattern ('^COPY ' + [regex]::Escape($Module) + '/pom\.xml') -Label 'demo/Dockerfile')
[void](Remove-MatchingLine -Path (Join-Path $PSScriptRoot 'dev.ps1') -Pattern ("Module\s*=\s*'" + [regex]::Escape($Module) + "'") -Label 'scripts/dev.ps1')
[void](Remove-MatchingLine -Path (Join-Path $PSScriptRoot 'dev.sh') -Pattern (':' + [regex]::Escape($Module) + ':') -Label 'scripts/dev.sh')

# Il blocco del compose va tolto per intero, dal nome del servizio fino a
# prima del blocco successivo.
$compose = Join-Path $demoDir 'docker-compose.yml'
$lines = @(Split-TextLines (Read-TextFile $compose))
$moduleLine = Find-LineIndex -Lines $lines -Pattern ("^\s+MODULE:\s+" + [regex]::Escape($Module) + "\s*$")
if ($moduleLine -ge 0) {
    $start = $moduleLine
    while ($start -gt 0 -and $lines[$start] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $start-- }
    $end = $moduleLine + 1
    while ($end -lt $lines.Count -and $lines[$end] -notmatch '^[A-Za-z0-9_-]+:\s*$' -and $lines[$end] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $end++ }
    # Porta con se' la riga vuota di separazione, se c'e'.
    while ($end -gt $start -and [string]::IsNullOrWhiteSpace($lines[$end - 1])) { $end-- }
    if ($end -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$end])) { $end++ }
    $kept = @()
    if ($start -gt 0) { $kept += $lines[0..($start - 1)] }
    if ($end -lt $lines.Count) { $kept += $lines[$end..($lines.Count - 1)] }
    Write-TextFile -Path $compose -Text ($kept -join (Get-TextEol (Read-TextFile $compose)))
    Write-Step 'demo/docker-compose.yml'
}

# --- Fatto --------------------------------------------------------------------

Write-Host ''
if ($callers.Count -gt 0) {
    Write-Host '  Attenzione: questi file nominano ancora il modulo tolto.' -ForegroundColor Yellow
    Write-Host '  Se lo chiamavano via Feign, ora non compilano: sistemali.' -ForegroundColor Yellow
    $callers | Select-Object -Unique | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    Write-Host ''
}
Write-Host 'Modulo rimosso.' -ForegroundColor Green
Write-Host ''
Write-Host '  task check        verifica che sia rimasto tutto coerente'
Write-Host '  task dev          riavvia lo stack senza quel modulo'
Write-Host ''
