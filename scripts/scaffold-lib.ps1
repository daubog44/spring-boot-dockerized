<#
.SYNOPSIS
    Funzioni condivise dagli script che cambiano la STRUTTURA del progetto:
    new-service.ps1, add-dep.ps1, set-port.ps1.

.DESCRIPTION
    Sono tutte operazioni di testo su file gia' esistenti (pom.xml, Dockerfile,
    docker-compose.yml, dev.ps1, dev.sh). Qui stanno lettura e scrittura, che
    preservano fine riga e codifica del file originale, e gli inserimenti mirati.
#>

function Get-ScaffoldRepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Read-TextFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path $Path)) { throw "File non trovato: $Path" }
    return [System.IO.File]::ReadAllText($Path)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )
    # UTF-8 SENZA BOM: con il BOM, Maven e bash leggono tre byte invisibili
    # all'inizio del file e falliscono in modi che sembrano stregoneria.
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-TextEol {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    # I file del repository sono CRLF su Windows tranne gli *.sh (vedi
    # .gitattributes): le righe che inseriamo devono seguire il file, non l'OS.
    if ($Text -match "`r`n") { return "`r`n" }
    return "`n"
}

function Split-TextLines {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    return ($Text -split "`r?`n")
}

function Find-LineIndex {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [int]$From = 0
    )
    for ($i = $From; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Add-LinesAt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$NewLines
    )
    $text = Read-TextFile $Path
    $eol = Get-TextEol $text
    $lines = @(Split-TextLines $text)
    $out = @()
    if ($Index -gt 0) { $out += $lines[0..($Index - 1)] }
    $out += $NewLines
    if ($Index -lt $lines.Count) { $out += $lines[$Index..($lines.Count - 1)] }
    Write-TextFile -Path $Path -Text ($out -join $eol)
}

function Add-LinesBefore {
    # Inserisce righe prima della prima riga che corrisponde ad $Anchor.
    # $Start, se passato, limita la ricerca a quello che viene dopo di lui:
    # serve quando l'ancora (es. una parentesi chiusa) compare piu' volte.
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Anchor,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$NewLines,
        [string]$Start
    )
    $lines = @(Split-TextLines (Read-TextFile $Path))
    $from = 0
    if ($Start) {
        $from = Find-LineIndex -Lines $lines -Pattern $Start
        if ($from -lt 0) { throw "Non trovo '$Start' in ${Path}: aggiungi la riga a mano." }
    }
    $idx = Find-LineIndex -Lines $lines -Pattern $Anchor -From $from
    if ($idx -lt 0) { throw "Non trovo il punto di inserimento ($Anchor) in ${Path}: aggiungi la riga a mano." }
    Add-LinesAt -Path $Path -Index $idx -NewLines $NewLines
}

function Add-LinesAfterLast {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Anchor,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$NewLines
    )
    $lines = @(Split-TextLines (Read-TextFile $Path))
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $Anchor) { $idx = $i } }
    if ($idx -lt 0) { throw "Non trovo il punto di inserimento ($Anchor) in ${Path}: aggiungi la riga a mano." }
    Add-LinesAt -Path $Path -Index ($idx + 1) -NewLines $NewLines
}

function Edit-TextFile {
    # Sostituzione con regex; restituisce il numero di sostituzioni fatte, cosi'
    # chi chiama puo' dire "toccato" oppure "non trovato, guardaci tu".
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Replacement
    )
    $text = Read-TextFile $Path
    $count = ([regex]$Pattern).Matches($text).Count
    if ($count -eq 0) { return 0 }
    Write-TextFile -Path $Path -Text ([regex]::Replace($text, $Pattern, $Replacement))
    return $count
}

function Get-ModuleShortName {
    # product-service -> product, wms-ui -> wms-ui: il nome breve e' quello che
    # compare in `task logs`, in `task status` e nel nome del file di log.
    param([Parameter(Mandatory = $true)][string]$Module)
    return ($Module -replace '-service$', '')
}

function Get-BasePackage {
    # Il pacchetto Java di base (esame, it.rossi...). Non sta in un file di
    # configurazione: e' quello di Eureka meno l'ultimo pezzo
    # (esame.namingserver -> esame). Lo cambia task set-package, e
    # new-service lo segue da solo.
    param([string]$RepoRoot = (Get-ScaffoldRepoRoot))
    $aggr = Join-Path $RepoRoot (Get-AggregatorName -RepoRoot $RepoRoot)
    $roots = @(Join-Path $aggr 'naming-server/src/main/java')
    $roots += @(Get-ChildItem -Path $aggr -Directory | ForEach-Object { Join-Path $_.FullName 'src/main/java' })
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($file in (Get-ChildItem -Path $root -Recurse -Filter '*.java')) {
            $text = Read-TextFile $file.FullName
            if ($text -notmatch '@SpringBootApplication') { continue }
            $hit = [regex]::Match($text, '(?m)^\s*package\s+([\w.]+)\.\w+\s*;')
            if ($hit.Success) { return $hit.Groups[1].Value }
        }
    }
    return 'esame'
}

function Get-ModulePackage {
    # ordini-service -> <base>.ordiniservice
    param([Parameter(Mandatory = $true)][string]$Module, [string]$Base = '')
    if (-not $Base) { $Base = Get-BasePackage }
    return ($Base + '.' + ($Module -replace '[^a-zA-Z0-9]', ''))
}

function Get-MachineJdk {
    # Il JDK con cui Maven compilera': quello di JAVA_HOME se c'e', se no il
    # java del PATH. Restituisce versione (17, 21, 25...) e cartella, o $null.
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin\java.exe') }
    $onPath = Get-Command java -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($java in $candidates) {
        if (-not (Test-Path $java)) { continue }
        # java scrive le proprieta' su stderr: la redirezione la fa cmd, se no
        # PowerShell 5.1 trasformerebbe ogni riga in un errore.
        $out = (cmd /c "`"$java`" -XshowSettings:properties -version 2>&1") -join "`n"
        $versionHit = [regex]::Match($out, 'java\.specification\.version = (\S+)')
        if (-not $versionHit.Success) { continue }
        $homeHit = [regex]::Match($out, 'java\.home = ([^\r\n]+)')
        # Java 8 si presenta come 1.8.
        $version = [int]($versionHit.Groups[1].Value -replace '^1\.', '')
        return [pscustomobject]@{ Version = $version; Home = ($homeHit.Groups[1].Value.Trim() -replace '\\', '/') }
    }
    return $null
}

function Get-ProjectJavaVersion {
    # La versione di Java del progetto: <java.version> del pom aggregatore.
    param([string]$RepoRoot = (Get-ScaffoldRepoRoot))
    $pom = Join-Path (Join-Path $RepoRoot (Get-AggregatorName -RepoRoot $RepoRoot)) 'pom.xml'
    $hit = [regex]::Match((Read-TextFile $pom), '<java\.version>(\d+)</java\.version>')
    if ($hit.Success) { return [int]$hit.Groups[1].Value }
    return 0
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "  $Message"
}

# La cartella dell'aggregatore Maven (quella che di solito si chiama demo).
# La verita' sta nel Taskfile, che la nomina in "dir:": cercarla a naso fra le
# cartelle con un pom.xml sbaglierebbe bersaglio, per esempio con consegna/.
function Get-AggregatorName {
    param([string]$RepoRoot)
    $taskfile = Join-Path $RepoRoot 'Taskfile.yml'
    if (Test-Path $taskfile) {
        $hit = [regex]::Match((Read-TextFile $taskfile), "(?m)^\s*dir:\s*'?([A-Za-z0-9_.-]+)'?\s*$")
        if ($hit.Success) {
            $name = $hit.Groups[1].Value
            if (Test-Path (Join-Path $RepoRoot "$name/pom.xml")) { return $name }
        }
    }
    foreach ($dir in (Get-ChildItem -Path $RepoRoot -Directory)) {
        if ($dir.Name -eq 'consegna') { continue }
        if ((Test-Path (Join-Path $dir.FullName 'pom.xml')) -and (Test-Path (Join-Path $dir.FullName 'docker-compose.yml'))) {
            return $dir.Name
        }
    }
    throw "Non trovo la cartella dell'aggregatore (pom.xml + docker-compose.yml) sotto $RepoRoot."
}
