<#
.SYNOPSIS
    Dati di prova: all'avvio le tabelle ancora vuote si riempiono da sole.

.DESCRIPTION
    Scrive nell'application.yml dei moduli con un database

        dev-data:
          rows: 5

    e da li' in poi, a ogni avvio, il pacchetto devdata di common-dto riempie
    le tabelle ancora vuote con righe inventate. Le righe passano da Hibernate
    (persist), quindi rispettano tutto quello che rispetta l'applicazione: id
    generati (IDENTITY, sequenze, UUID), relazioni verso righe che esistono,
    enum veri, @Column(length), @NotNull, @Size, @Min/@Max, @Email, @Pattern.
    Vale su H2, su PostgreSQL e dentro Docker; un riavvio non duplica niente.

    Poi la prova: compila e avvia ogni modulo su un database H2 usa-e-getta, e
    dice tabella per tabella quante righe sono entrate. Se una non entra lo
    vedi adesso, con il motivo, e non davanti al docente.

    I dati di test valgono punti nella griglia d'esame.

.PARAMETER Module
    Un modulo solo. Se omesso, tutti quelli che hanno delle @Entity.

.PARAMETER Rows
    Quante righe per tabella (default 5). 0 spegne i dati di prova.

.PARAMETER NoCheck
    Scrive solo la configurazione, senza compilare ne' provare.

.EXAMPLE
    task seed-data
    task seed-data SERVICE=ordini-service ROWS=10
    task seed-data ROWS=0
#>
param(
    [string]$Module = '',
    [int]$Rows = 5,
    [switch]$NoCheck
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$all = @(Get-JpaModules -RepoRoot $repoRoot)

if ($Module) {
    $targets = @($all | Where-Object { $_.Name -eq $Module })
    if ($targets.Count -eq 0) {
        throw "Il modulo '$Module' non c'e' o non usa un database (manca spring-boot-starter-data-jpa nel suo pom)."
    }
} else {
    $targets = @($all | Where-Object { $_.HasEntities })
}

Write-Host ''
Write-Host '==> Dati di prova' -ForegroundColor Cyan
Write-Host ''

if ($targets.Count -eq 0) {
    Write-Host 'Nessun modulo con delle @Entity: non c''e'' niente da riempire.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Crea prima le entity del tuo dominio, poi rilancia questo comando.'
    Write-Host ''
    exit 0
}

foreach ($target in $targets) {
    Set-DevDataRows -YmlPath (Join-Path $target.Dir 'src/main/resources/application.yml') -Rows $Rows
    Write-Step ($target.Name + "/src/main/resources/application.yml  dev-data.rows: $Rows")

    # Il data.sql della versione vecchia di questo comando: adesso ci pensa
    # devdata, e le sue INSERT scritte a mano farebbero doppio lavoro.
    $oldSql = Join-Path $target.Dir 'src/main/resources/data.sql'
    if ((Test-Path $oldSql) -and ((Read-TextFile $oldSql) -match '^-- Dati di prova generati da task seed-data\.')) {
        Remove-Item $oldSql -Force
        Write-Step ($target.Name + '/src/main/resources/data.sql  tolto (lo scriveva la versione vecchia di questo comando)')
    }
}
Write-Host ''

# L'application.yml appena scritto arriva al modulo gia' acceso solo se
# qualcosa lo ricompila: mvnw spring-boot:run non guarda da solo
# src/main/resources. L'avviso va dato subito: sia -NoCheck sia Rows 0
# escono prima della prova su H2, quindi e' l'unico punto comune a ogni caso.
$devPidsFile = Join-Path (Get-DevLogDir) 'dev.pids'
if ((Test-Path $devPidsFile) -and ((Get-Content $devPidsFile -ErrorAction SilentlyContinue) | Where-Object { $_ })) {
    Write-Host 'Lo stack e'' gia'' acceso (task dev): questa configurazione non arriva da sola al processo gia'' partito.' -ForegroundColor Yellow
    Write-Host '  task compile           ricompila e fa ripartire i moduli gia'' avviati: da qui il riempimento scatta'
    Write-Host ''
}

if ($Rows -le 0) {
    Write-Host 'Dati di prova spenti: all''avvio non si aggiunge piu'' niente.' -ForegroundColor Green
    Write-Host ''
    exit 0
}
if ($NoCheck) {
    Write-Host 'Configurazione scritta: al prossimo avvio (task dev) le tabelle vuote si riempiono.' -ForegroundColor Green
    Write-Host ''
    exit 0
}

$toCheck = @($targets | Where-Object { $_.HasEntities })
if ($toCheck.Count -eq 0) {
    Write-Host 'Il modulo non ha ancora delle @Entity: si riempira'' quando le avra''.' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

Write-Host '==> Prova su un database H2 usa-e-getta' -ForegroundColor Cyan
Write-Host '  compilo con Maven...' -ForegroundColor DarkGray
$build = Invoke-ModuleBuild -Modules @($toCheck | ForEach-Object { $_.Name }) -RepoRoot $repoRoot
if ($build.ExitCode -ne 0) {
    Write-Host '  La compilazione e'' fallita:' -ForegroundColor Red
    foreach ($line in $build.Errors) { Write-Host "    $line" -ForegroundColor DarkGray }
    Write-Host "  Log completo: $($build.Log)" -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}

$failed = 0
foreach ($target in $toCheck) {
    Write-Host ''
    Write-Host "  $($target.Name)" -ForegroundColor Cyan
    if (-not $target.HasH2) {
        Write-Host '    senza H2 non c''e'' un database usa-e-getta per provare: la prova vera sara'' al prossimo avvio' -ForegroundColor Yellow
        continue
    }
    $result = Invoke-DevDataRun -Module $target -Arguments @("--dev-data.rows=$Rows")
    if (-not (Write-DevDataResult -Result $result)) { $failed++ }
}
Write-Host ''

if ($failed -gt 0) {
    Write-Host 'Qualche tabella non si riempie: sopra c''e'' il motivo, tabella per tabella.' -ForegroundColor Yellow
    Write-Host '  Le altre si riempiono lo stesso, e l''avvio non fallisce mai per i dati di prova.' -ForegroundColor DarkGray
    Write-Host ''
    exit 1
}
Write-Host 'Dati di prova pronti.' -ForegroundColor Green
Write-Host ''
Write-Host '  task dev               all''avvio le tabelle vuote si riempiono da sole'
Write-Host '                         (anche su PostgreSQL e in Docker)'
Write-Host '  task db-schema         lo schema di queste tabelle, letto dal database'
Write-Host '  task seed-data ROWS=0  per spegnerli'
Write-Host ''
