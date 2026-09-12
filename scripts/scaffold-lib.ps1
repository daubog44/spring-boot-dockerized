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

# Un progetto Docker Compose per copia del template, col nome della cartella
# del repository (come fanno il Taskfile e dev-lib.ps1).
if (-not $env:COMPOSE_PROJECT_NAME) {
    $env:COMPOSE_PROJECT_NAME = (Split-Path -Leaf (Get-ScaffoldRepoRoot)).ToLowerInvariant() -replace '[^a-z0-9_-]+', '-' -replace '^[^a-z0-9]+', ''
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

# --- I moduli con un database, avviati per interrogarlo -----------------------
# Li usano task seed-data e task db-schema. Il lavoro vero lo fa il pacchetto
# devdata di common-dto, dentro l'applicazione: qui si compila, si avvia il jar
# con le proprieta' giuste e si leggono le sue righe [dev-data].

function Get-JpaModules {
    # I moduli con spring-boot-starter-data-jpa nel pom. Per ognuno: se ha gia'
    # delle @Entity e se ha H2 (il database usa-e-getta delle prove).
    param([string]$RepoRoot = (Get-ScaffoldRepoRoot))
    $aggr = Join-Path $RepoRoot (Get-AggregatorName -RepoRoot $RepoRoot)
    $out = @()
    foreach ($dir in (Get-ChildItem -Path $aggr -Directory | Sort-Object Name)) {
        $pom = Join-Path $dir.FullName 'pom.xml'
        if (-not (Test-Path $pom)) { continue }
        $pomText = Read-TextFile $pom
        if ($pomText -notmatch '<artifactId>spring-boot-starter-data-jpa</artifactId>') { continue }
        $src = Join-Path $dir.FullName 'src/main/java'
        $hasEntities = $false
        if (Test-Path $src) {
            $hit = Get-ChildItem -Path $src -Recurse -Filter '*.java' |
                Where-Object { (Read-TextFile $_.FullName) -match '(?m)^\s*@(jakarta\.persistence\.)?Entity\b' } |
                Select-Object -First 1
            $hasEntities = [bool]$hit
        }
        $out += [pscustomobject]@{
            Name = $dir.Name
            Dir = $dir.FullName
            HasEntities = $hasEntities
            HasH2 = ($pomText -match '<artifactId>h2</artifactId>')
        }
    }
    return $out
}

function Get-JavaExe {
    if ($env:JAVA_HOME) {
        $java = Join-Path $env:JAVA_HOME 'bin\java.exe'
        if (Test-Path $java) { return $java }
    }
    $onPath = Get-Command java -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    return $null
}

function Invoke-ModuleBuild {
    # Compila i moduli, e common-dto da cui dipendono, con il wrapper Maven.
    param([Parameter(Mandatory = $true)][string[]]$Modules, [string]$RepoRoot = (Get-ScaffoldRepoRoot))
    $aggr = Join-Path $RepoRoot (Get-AggregatorName -RepoRoot $RepoRoot)
    $log = Join-Path ([System.IO.Path]::GetTempPath()) ('devdata-build-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.log')
    $javaHome = if ($env:JAVA_HOME -and (Test-Path $env:JAVA_HOME)) { $env:JAVA_HOME } else { '' }
    Push-Location $aggr
    try {
        # La redirezione la fa cmd: PowerShell 5.1 trasformerebbe gli avvisi di
        # Maven su stderr in errori.
        cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q -pl $($Modules -join ',') -am package -Dmaven.test.skip=true > `"$log`" 2>&1"
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $tail = @(Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match 'ERROR' } | Select-Object -First 15)
    return [pscustomobject]@{ ExitCode = $code; Log = $log; Errors = $tail }
}

function Invoke-DevDataRun {
    # Avvia il jar di un modulo senza server web ne' Eureka, su un database H2
    # in memoria (o sul suo, con -OwnDatabase), e aspetta che devdata finisca.
    # Restituisce l'exit code, le righe [dev-data] e, se non e' partito, le
    # righe del log che spiegano perche'.
    param(
        [Parameter(Mandatory = $true)]$Module,
        [string[]]$Arguments = @(),
        [switch]$OwnDatabase,
        [int]$TimeoutSeconds = 180
    )
    $result = [pscustomobject]@{ ExitCode = -1; Lines = @(); Problem = ''; LogTail = @() }
    $jar = Get-ChildItem -Path (Join-Path $Module.Dir 'target') -Filter '*.jar' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '(sources|javadoc|plain)\.jar$' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $jar) { $result.Problem = "manca il jar in $($Module.Name)/target: compila prima (task build)"; return $result }
    $java = Get-JavaExe
    if (-not $java) { $result.Problem = 'java non trovato: installa un JDK (task check)'; return $result }

    $all = @(
        '--spring.main.web-application-type=none', '--spring.main.banner-mode=off', '--logging.level.root=WARN',
        '--eureka.client.enabled=false', '--spring.cloud.discovery.enabled=false',
        '--spring.cloud.service-registry.auto-registration.enabled=false', '--spring.sql.init.mode=never',
        '--dev-data.exit=true'
    )
    if (-not $OwnDatabase) {
        # Un database vuoto tutto suo: Hibernate ci crea le tabelle da zero, e
        # quello del progetto (PostgreSQL compreso) non viene toccato.
        $all += @(
            '--spring.datasource.url=jdbc:h2:mem:devdata;DB_CLOSE_DELAY=-1', '--spring.datasource.driver-class-name=org.h2.Driver',
            '--spring.datasource.username=sa', '--spring.datasource.password=', '--spring.jpa.hibernate.ddl-auto=create',
            '--spring.jpa.database-platform=org.hibernate.dialect.H2Dialect',
            '--spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect',
            '--spring.flyway.enabled=false', '--spring.liquibase.enabled=false'
        )
    }
    $all += $Arguments
    $log = Join-Path ([System.IO.Path]::GetTempPath()) ('devdata-run-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.log')
    $line = '"' + $java + '" -jar "' + $jar.FullName + '" ' + (($all | ForEach-Object { '"' + $_ + '"' }) -join ' ') + ' > "' + $log + '" 2>&1'
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/c', ('"' + $line + '"')) -NoNewWindow -PassThru
    $null = $process.Handle   # senza, ExitCode resta vuoto (difetto noto di PowerShell)
    if ($process.WaitForExit($TimeoutSeconds * 1000)) {
        $result.ExitCode = $process.ExitCode
    } else {
        # Solo questo processo e i suoi figli: mai tutti i java della macchina.
        & taskkill /PID $process.Id /T /F 2>&1 | Out-Null
        $result.ExitCode = -2
        $result.Problem = "non ha finito in $TimeoutSeconds secondi (aspetta un database o un altro servizio?)"
    }
    $text = @(Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue)
    $result.Lines = @($text | Where-Object { $_.StartsWith('[dev-data] ') } | ForEach-Object { $_.Substring(11) })
    $result.LogTail = @($text | Where-Object { $_ -match 'ERROR|Caused by|Description:|Action:|APPLICATION FAILED|Exception' -and $_ -notmatch '^\s+at ' } | Select-Object -Last 12)
    if (-not $result.Problem -and $result.Lines.Count -eq 0) {
        $result.Problem = if ($result.ExitCode -eq 0) {
            "non usa common-dto, che porta devdata: task add-dep SERVICE=$($Module.Name) DEP=common-dto"
        } else {
            "non si e' avviato (log completo: $log)"
        }
    }
    return $result
}

function Write-DevDataResult {
    # Mostra le righe [dev-data] di un modulo; $true se e' andato tutto bene.
    param([Parameter(Mandatory = $true)]$Result)
    foreach ($line in $Result.Lines) {
        $color = if ($line.StartsWith('ERRORE')) { 'Red' } else { 'Gray' }
        Write-Host "    $line" -ForegroundColor $color
    }
    if ($Result.Problem) {
        Write-Host "    $($Result.Problem)" -ForegroundColor Red
        foreach ($l in $Result.LogTail) { Write-Host "      $l" -ForegroundColor DarkGray }
    }
    return ($Result.ExitCode -eq 0 -and $Result.Lines.Count -gt 0)
}

function Set-DevDataRows {
    # dev-data.rows nell'application.yml: lo aggiorna se c'e', se no lo aggiunge in fondo.
    param([Parameter(Mandatory = $true)][string]$YmlPath, [Parameter(Mandatory = $true)][int]$Rows)
    $text = Read-TextFile $YmlPath
    $eol = Get-TextEol $text
    $block = '(?m)(^dev-data:[ \t]*\r?\n(?:[ \t]+.*\r?\n)*?[ \t]+rows:[ \t]*)\d+'
    if ($text -match $block) {
        $text = [regex]::Replace($text, $block, ('${1}' + $Rows))
    } elseif ($text -match '(?m)^dev-data:[ \t]*\r?$') {
        $text = [regex]::Replace($text, '(?m)^(dev-data:[ \t]*)(\r?)$', ('${1}${2}' + "`n" + '  rows: ' + $Rows + '${2}'))
    } else {
        $lines = @(
            ''
            '# Dati di prova (task seed-data): all''avvio le tabelle ancora vuote si'
            '# riempiono da sole con righe inventate, passando da Hibernate. 0 = spento.'
            'dev-data:'
            "  rows: $Rows"
        )
        $text = $text.TrimEnd("`r", "`n") + $eol + ($lines -join $eol) + $eol
    }
    Write-TextFile -Path $YmlPath -Text $text
}

function Ensure-SqlInit {
    # Le due chiavi che servono perche' un data.sql giri dopo Hibernate, anche
    # su PostgreSQL (senza, Spring lo esegue subito, prima che le tabelle
    # esistano): spring.jpa.defer-datasource-initialization e
    # spring.sql.init.mode. Le aggiunge sotto spring: se mancano; se ci sono
    # gia' non tocca niente.
    param([Parameter(Mandatory = $true)][string]$YmlPath)
    $text = Read-TextFile $YmlPath
    if ($text -match 'defer-datasource-initialization') { return }
    $lines = @(Split-TextLines $text)
    $springIdx = Find-LineIndex -Lines $lines -Pattern '^spring:\s*$'
    if ($springIdx -lt 0) { return }
    $endIdx = $lines.Count
    for ($i = $springIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^[^ \t\r]') { $endIdx = $i; break }
    }
    $jpaIdx = -1
    for ($i = $springIdx + 1; $i -lt $endIdx; $i++) {
        if ($lines[$i] -match '^  jpa:\s*$') { $jpaIdx = $i; break }
    }
    if ($jpaIdx -ge 0) {
        Add-LinesAt -Path $YmlPath -Index ($jpaIdx + 1) -NewLines @('    defer-datasource-initialization: true')
        $endIdx++
    }
    Add-LinesAt -Path $YmlPath -Index $endIdx -NewLines @('  sql:', '    init:', '      mode: always', '      continue-on-error: true', '')
}
