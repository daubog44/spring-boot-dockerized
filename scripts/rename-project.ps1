<#
.SYNOPSIS
    Rinomina la cartella dell'aggregatore Maven (quella chiamata demo) e con
    essa ogni file che la nomina.

.DESCRIPTION
    La cartella che contiene il pom aggregatore, il Dockerfile e il
    docker-compose si chiama demo perche' cosi' nasce da Spring Initializr.
    All'esame fa piu' bella figura chiamarla come il progetto.

    Il nome pero' non e' scritto solo li': lo nominano il Taskfile (dir:), gli
    script di scripts/ e le guide. Questo comando li aggiorna tutti insieme,
    e alla fine controlla che il progetto sia rimasto coerente.

    Non tocca la parola demo quando e' italiano corrente (prima della demo):
    rinomina solo dove e' un pezzo di percorso.

    La cartella che contiene tutto (quella del repository) rinominala pure a
    mano da Esplora risorse: nessuno script dipende dal suo nome.

.PARAMETER Name
    Il nome nuovo: minuscole, numeri e trattini.

.EXAMPLE
    task rename-project NAME=wms
#>
param([string]$Name = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot

# --- Come si chiama adesso ----------------------------------------------------
# Non lo diamo per scontato: e' la cartella con il pom aggregatore e il
# docker-compose. Cosi' il comando funziona anche la seconda volta.

$current = Get-AggregatorName -RepoRoot $repoRoot

if (-not $Name) {
    Write-Host ''
    Write-Host "La cartella dell'aggregatore si chiama '$current'." -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  task rename-project NAME=<nome-nuovo>'
    Write-Host ''
    exit 0
}
if ($Name -notmatch '^[a-z][a-z0-9-]*$') {
    throw "Nome non valido: '$Name'. Minuscole, numeri e trattini, e deve iniziare per lettera."
}
if ($Name -eq $current) {
    Write-Host ''
    Write-Host "La cartella si chiama gia' '$Name': non c'e' niente da fare." -ForegroundColor Yellow
    Write-Host ''
    exit 0
}
if (Test-Path (Join-Path $repoRoot $Name)) {
    throw "Esiste gia' una cartella '$Name' nel progetto."
}

Write-Host ''
Write-Host "==> $current -> $Name" -ForegroundColor Cyan
Write-Host ''

# --- 1. La cartella -----------------------------------------------------------
# Con git la rinominiamo con git mv, cosi' la storia resta attaccata.

$moved = $false
if (Test-Path (Join-Path $repoRoot '.git')) {
    Push-Location $repoRoot
    try {
        & git mv $current $Name 2>$null
        if ($LASTEXITCODE -eq 0) { $moved = $true }
    } catch { }
    finally { Pop-Location }
}
if (-not $moved) {
    Move-Item -Path (Join-Path $repoRoot $current) -Destination (Join-Path $repoRoot $Name)
}
Write-Step "$current/ -> $Name/"

# --- 2. Ogni file che la nomina ----------------------------------------------
# Sostituiamo il nome solo quando e' un pezzo di percorso: cioe' quando ha
# accanto una barra, un apice o una virgoletta -- ma non quando e' il nome di
# una variabile ($demo). Cosi' la parola demo in italiano resta dov'e'.
# E solo quando il nome finisce li': 'biblioteca-ui' e' un modulo, non la
# cartella biblioteca seguita da qualcos'altro.

$escaped = [regex]::Escape($current)
$rules = @(
    @{ Pattern = "(?<=[/\\'`"``])$escaped(?![\w-])"; Replacement = $Name },
    @{ Pattern = "(?<![$\w{])$escaped(?=[/\\'`"``])"; Replacement = $Name },
    @{ Pattern = "(?m)^(\s*dir:\s*)$escaped\s*$"; Replacement = ('${1}' + $Name) },
    @{ Pattern = "(?m)(^|\s)cd $escaped(?=\s|$)"; Replacement = ('${1}cd ' + $Name) }
)

$files = @()
$files += Get-ChildItem -Path $repoRoot -Filter '*.md' -File
$files += Get-ChildItem -Path $repoRoot -Filter 'Taskfile.yml' -File
$files += Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -File | Where-Object { $_.Extension -in @('.ps1', '.sh') }

$touched = 0
foreach ($file in $files) {
    $changes = 0
    foreach ($rule in $rules) {
        $changes += (Edit-TextFile -Path $file.FullName -Pattern $rule.Pattern -Replacement $rule.Replacement)
    }
    if ($changes -gt 0) {
        $relative = $file.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/'
        Write-Step "$relative ($changes)"
        $touched++
    }
}

Write-Host ''
Write-Host "Rinominata: $touched file aggiornati." -ForegroundColor Green
Write-Host ''

# --- 3. La prova del nove -----------------------------------------------------

& (Join-Path $PSScriptRoot 'check.ps1') -ProjectOnly
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'task check ha trovato qualcosa: guarda sopra.' -ForegroundColor Yellow
    exit 1
}

Write-Host ''
Write-Host "  I comandi non cambiano: task dev, task build, task docker-up." -ForegroundColor DarkGray
Write-Host "  Cambia solo il percorso dei sorgenti: $Name/<modulo>/src/..." -ForegroundColor DarkGray
Write-Host ''
