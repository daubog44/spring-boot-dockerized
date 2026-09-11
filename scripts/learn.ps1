<#
.SYNOPSIS
    Prepara il corso e lo apre nel browser.

.DESCRIPTION
    Il corso e' una pagina statica, corso/index.html: si apre col doppio clic,
    senza server e senza rete. Il testo pero' sta nei file Markdown - le
    lezioni in corso/lezioni/ e le guide del progetto nella cartella
    principale - e un browser, da un file aperto col doppio clic, non puo'
    leggere altri file. Questo script li raccoglie in corso/contenuti.js,
    insieme a una fotografia del progetto (moduli, porte, database, DTO), e
    apre la pagina.

    Rilancialo quando cambi una guida o un modulo: la pagina mostra quello
    che c'era l'ultima volta.

.PARAMETER NoOpen
    Prepara contenuti.js senza aprire il browser.

.EXAMPLE
    task learn
    task learn OPEN=0
#>
param([switch]$NoOpen)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$corsoDir = Join-Path $repoRoot 'corso'
$index = Join-Path $corsoDir 'index.html'
$out = Join-Path $corsoDir 'contenuti.js'
if (-not (Test-Path $index)) { throw "Non trovo $index." }

# Un testo dentro un template literal di JavaScript (`...`): vanno protetti
# la barra rovesciata, l'apice inverso e ${, che altrimenti JavaScript
# leggerebbe come codice.
function ConvertTo-JsTemplate {
    param([string]$Text)
    $t = $Text -replace "`r`n", "`n"
    $t = $t.Replace('\', '\\').Replace('`', '\`').Replace('${', '\${')
    return '`' + $t + '`'
}
function ConvertTo-JsString {
    param([string]$Text)
    return "'" + ($Text.Replace('\', '\\').Replace("'", "\'")) + "'"
}

# --- Le lezioni e le guide -----------------------------------------------------

$lessons = @(Get-ChildItem -Path (Join-Path $corsoDir 'lezioni') -Filter '*.md' -ErrorAction SilentlyContinue | Sort-Object Name)
# Prima il README e la procedura del giorno, poi le altre in ordine alfabetico.
$docs = @(Get-ChildItem -Path $repoRoot -Filter '*.md' | Sort-Object @{ Expression = {
            switch ($_.Name) { 'README.md' { 0 } 'GIORNO-ESAME.md' { 1 } default { 2 } } } }, Name)

# --- La fotografia del progetto ------------------------------------------------

$aggregator = Get-AggregatorName -RepoRoot $repoRoot
$demoDir = Join-Path $repoRoot $aggregator
$pomText = Read-TextFile (Join-Path $demoDir 'pom.xml')
$modules = @([regex]::Matches($pomText, '<module>([^<]+)</module>') | ForEach-Object { $_.Groups[1].Value })
$javaVersion = [regex]::Match($pomText, '<java.version>([^<]+)</java.version>').Groups[1].Value

$moduleRows = @()
foreach ($m in $modules) {
    $dir = Join-Path $demoDir $m
    $yml = Join-Path $dir 'src/main/resources/application.yml'
    $ymlText = if (Test-Path $yml) { Read-TextFile $yml } else { '' }
    $modulePom = Join-Path $dir 'pom.xml'
    $modulePomText = if (Test-Path $modulePom) { Read-TextFile $modulePom } else { '' }
    $port = [regex]::Match($ymlText, 'SERVER_PORT:(\d+)').Groups[1].Value
    $name = [regex]::Match($ymlText, '(?m)^\s+name:\s*(\S+)').Groups[1].Value
    $sources = @(Get-ChildItem -Path (Join-Path $dir 'src/main/java') -Recurse -Filter '*.java' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]devdata[\\/]' })
    $entities = @($sources | Where-Object { (Read-TextFile $_.FullName) -match '(?m)^@Entity' } | ForEach-Object { $_.BaseName })
    # Chi chiama: il nome Eureka scritto in @FeignClient(name = "...").
    $feign = @($sources | ForEach-Object {
            [regex]::Matches((Read-TextFile $_.FullName), '@FeignClient\(\s*(?:(?:name|value)\s*=\s*)?"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
        } | Select-Object -Unique)
    $kind = if ($modulePomText -match 'eureka-server') { 'eureka' }
        elseif (-not $ymlText) { 'libreria' }
        elseif (Test-Path (Join-Path $dir 'src/main/resources/templates')) { 'ui' }
        else { 'rest' }
    $db = if ($ymlText -match 'jdbc:postgresql://[^/]+/([A-Za-z0-9_]+)') { 'PostgreSQL ' + $Matches[1] }
        elseif ($ymlText -match 'jdbc:h2') { 'H2 in memoria' } else { '' }
    $dtos = @()
    if ($kind -eq 'libreria') {
        $dtos = @($sources | Where-Object { $_.Name -ne 'package-info.java' } | ForEach-Object { $_.BaseName })
    }
    $moduleRows += ('    {{ nome: {0}, tipo: {1}, porta: {2}, applicazione: {3}, database: {4}, entity: [{5}], feign: [{6}], classi: [{7}] }}' -f `
        (ConvertTo-JsString $m), (ConvertTo-JsString $kind), (ConvertTo-JsString $port), (ConvertTo-JsString $name), (ConvertTo-JsString $db),
        (($entities | ForEach-Object { ConvertTo-JsString $_ }) -join ', '),
        (($feign | ForEach-Object { ConvertTo-JsString $_ }) -join ', '),
        (($dtos | ForEach-Object { ConvertTo-JsString $_ }) -join ', '))
}

# --- contenuti.js ----------------------------------------------------------------

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('// Generato da task learn: non modificarlo, rilancia il comando.')
$lines.Add('window.CORSO = {')
$lines.Add('  generato: ' + (ConvertTo-JsString (Get-Date -Format 'yyyy-MM-dd HH:mm')) + ',')
$lines.Add('  progetto: {')
$lines.Add('    cartella: ' + (ConvertTo-JsString $aggregator) + ',')
$lines.Add('    pacchetto: ' + (ConvertTo-JsString (Get-BasePackage -RepoRoot $repoRoot)) + ',')
$lines.Add('    java: ' + (ConvertTo-JsString $javaVersion) + ',')
$lines.Add('    moduli: [')
$lines.Add(($moduleRows -join (",`n")))
$lines.Add('    ]')
$lines.Add('  },')
foreach ($group in @(@{ Key = 'lezioni'; Files = $lessons; Prefix = 'corso/lezioni/' }, @{ Key = 'documenti'; Files = $docs; Prefix = '' })) {
    $lines.Add("  $($group.Key): [")
    $entries = @()
    foreach ($f in $group.Files) {
        $entries += ('    {{ file: {0}, testo: {1} }}' -f (ConvertTo-JsString ($group.Prefix + $f.Name)), (ConvertTo-JsTemplate (Read-TextFile $f.FullName)))
    }
    $lines.Add(($entries -join ",`n"))
    $lines.Add('  ],')
}
$lines.Add('};')
Write-TextFile -Path $out -Text (($lines -join "`n") + "`n")

Write-Host ''
Write-Host 'Il corso e'' pronto.' -ForegroundColor Green
Write-Host ("  {0} lezioni, {1} guide, {2} moduli del progetto" -f $lessons.Count, $docs.Count, $modules.Count)
Write-Host "  $index"
Write-Host ''
if (-not $NoOpen) {
    Start-Process $index
    Write-Host '  Aperto nel browser. Si apre anche col doppio clic sul file.' -ForegroundColor DarkGray
    Write-Host ''
}
