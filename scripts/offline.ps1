<#
.SYNOPSIS
    Prepara e verifica il progetto per un esame senza rete.

.DESCRIPTION
    Il giorno dell'esame potresti non avere internet. Maven e Docker, lasciati
    a se stessi, scaricano: il primo le dipendenze in ~/.m2, il secondo le
    immagini di base. Se quella roba non c'e' gia' sul disco, senza rete non
    parte niente.

    Due modi:

      task offline-prep   (CON rete, la sera prima) scarica tutto quello che
                          servira': dipendenze Maven, immagini Docker, e la
                          prima build dei container, che riempie la cache;
      task offline        (quando vuoi) dice cosa c'e' e cosa manca, e cosa
                          funzionerebbe adesso a rete staccata.

.PARAMETER Prep
    Scarica invece di limitarsi a controllare.

.PARAMETER All
    Con -Prep: scarica anche tutto il catalogo di add-dep (security, kafka,
    mongodb...), non solo quello che genera new-service. Ci mette di piu'.

.EXAMPLE
    task offline-prep
    task offline-prep ALL=1
    task offline
#>
param([switch]$Prep, [switch]$All)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
# Il JDK lo sceglie il Taskfile (JAVA_HOME_PATH). Se manca, o non esiste,
# JAVA_HOME resta vuoto e il wrapper Maven usa il java del PATH.
$javaHome = if ($env:JAVA_HOME -and (Test-Path $env:JAVA_HOME)) { $env:JAVA_HOME } else { '' }

function Write-Line {
    param([string]$Label, [string]$Value, [string]$Color = 'Green')
    Write-Host ('  {0,-26}{1}' -f $Label, $Value) -ForegroundColor $Color
}

# Le immagini che servono: quelle del Dockerfile piu' quella del compose.
$images = @()
foreach ($line in (Select-String -Path (Join-Path $demoDir 'Dockerfile') -Pattern '^FROM\s+(\S+)')) {
    $images += ($line.Matches[0].Groups[1].Value)
}
$composeImage = Select-String -Path (Join-Path $demoDir 'docker-compose.yml') -Pattern '^\s+image:\s*(\S+)'
foreach ($hit in $composeImage) { $images += $hit.Matches[0].Groups[1].Value }
$images = @($images | Select-Object -Unique)

$problems = 0

# Un progetto di prova, fuori dal tuo, con i moduli che new-service genera
# all'esame: un servizio REST con database e un'interfaccia web. Le loro
# dipendenze (JPA, H2, PostgreSQL, Feign, Swagger, Thymeleaf) nel progetto di
# oggi magari non ci sono ancora, e senza rete non si scaricherebbero piu'.
$probeModules = @('prova-offline-service', 'prova-offline-ui')
function New-OfflineProbe {
    $probe = Join-Path ([System.IO.Path]::GetTempPath()) ('esame-offline-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    # /XF .git: in un worktree .git e' un file che punta al repository vero.
    $null = robocopy $repoRoot $probe /E /XD target .git .dev-logs node_modules .task consegna /XF .git /NFL /NDL /NJH /NJS /NP
    $scripts = Join-Path $probe 'scripts'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'new-service.ps1') -Name $probeModules[0] | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'new-service.ps1') -Name $probeModules[1] -Ui | Out-Null
    if ($All) {
        $catalog = @([regex]::Matches((Read-TextFile (Join-Path $scripts 'add-dep.ps1')), "(?m)^\s+'([a-z0-9-]+)'\s+=\s+New-Dep") | ForEach-Object { $_.Groups[1].Value })
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'add-dep.ps1') -Module $probeModules[0] -Deps ($catalog -join ',') | Out-Null
    }
    return $probe
}

if ($Prep) {
    Write-Host ''
    Write-Host 'PREPARAZIONE PER L''ESAME SENZA RETE' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Serve internet ADESSO. Ci vogliono alcuni minuti.' -ForegroundColor DarkGray
    Write-Host ''

    # 1. Le dipendenze Maven, nella cache di casa (~/.m2).
    Write-Host '==> Dipendenze Maven' -ForegroundColor Cyan
    Push-Location $demoDir
    try {
        cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q dependency:go-offline"
        $goOffline = $LASTEXITCODE
        cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q clean package -Dmaven.test.skip=true"
        $package = $LASTEXITCODE
    } finally { Pop-Location }
    if ($goOffline -eq 0 -and $package -eq 0) {
        Write-Line 'maven' 'scaricate e compilate'
    } else {
        Write-Line 'maven' 'qualcosa non ha funzionato: guarda l''output sopra' 'Yellow'
        $problems++
    }

    # 1-bis. Le dipendenze dei moduli che creerai all'esame.
    Write-Host ''
    Write-Host '==> Dipendenze dei moduli che creerai (new-service, seed-data, db-schema)' -ForegroundColor Cyan
    if ($All) { Write-Host '  ... piu'' tutto il catalogo di add-dep: ci vuole un po''.' -ForegroundColor DarkGray }
    $probe = New-OfflineProbe
    $probeDemo = Join-Path $probe (Get-AggregatorName -RepoRoot $probe)
    Push-Location $probeDemo
    try {
        cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q dependency:go-offline"
        $probeOffline = $LASTEXITCODE
        # Con la fase dei test, anche se non ce ne sono: scarica il plugin che li esegue.
        cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q package -pl $($probeModules -join ',') -am"
        $probePackage = $LASTEXITCODE
    } finally { Pop-Location }
    if ($probeOffline -eq 0 -and $probePackage -eq 0) {
        Write-Line 'moduli nuovi' 'JPA, H2, PostgreSQL, Feign, Swagger, Thymeleaf scaricati'
    } else {
        Write-Line 'moduli nuovi' 'qualcosa non ha funzionato: guarda l''output sopra' 'Yellow'
        $problems++
    }

    # 2. Le immagini di base, che Docker altrimenti va a prendere al volo.
    Write-Host ''
    Write-Host '==> Immagini Docker' -ForegroundColor Cyan
    foreach ($image in $images) {
        & docker pull $image 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Line $image 'scaricata' }
        else { Write-Line $image 'non scaricata' 'Yellow'; $problems++ }
    }

    # 3. La build dei container: riempie la cache dei livelli, compreso quello
    #    con curl (che a rete staccata non si potrebbe piu' installare).
    Write-Host ''
    Write-Host '==> Build delle immagini del progetto' -ForegroundColor Cyan
    Push-Location $demoDir
    try {
        & docker compose build
        $built = $LASTEXITCODE
    } finally { Pop-Location }
    if ($built -eq 0) { Write-Line 'docker compose build' 'fatta' }
    else { Write-Line 'docker compose build' 'fallita' 'Yellow'; $problems++ }

    # Anche dentro Docker: la build di un modulo nuovo scarica le sue
    # dipendenze nella cache di Maven delle build (--mount=type=cache nel
    # Dockerfile), che cosi' il giorno dell'esame le ha gia'.
    Push-Location $probeDemo
    try {
        & docker compose build $probeModules[0] 2>&1 | Out-Null
        $probeBuilt = $LASTEXITCODE
        # Le immagini di prova non servono: resta solo la cache.
        & docker compose down --rmi local 2>&1 | Out-Null
    } finally { Pop-Location }
    if ($probeBuilt -eq 0) { Write-Line 'build di un modulo nuovo' 'fatta (cache Maven di Docker piena)' }
    else { Write-Line 'build di un modulo nuovo' 'fallita' 'Yellow'; $problems++ }
    Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue

    Write-Host ''
    if ($problems -eq 0) {
        Write-Host 'Pronto: da adesso il progetto parte anche senza rete.' -ForegroundColor Green
    } else {
        Write-Host "Finito con $problems problema/i: rileggi sopra." -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host '  Verifica quando vuoi con: task offline' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}

# --- Controllo ----------------------------------------------------------------

# 0. La rete di adesso: all'esame e' filtrata, e quello che passa oggi
#    decide che cosa deve essere gia' sul disco.
& (Join-Path $PSScriptRoot 'rete.ps1')

Write-Host 'E SE UN DOMINIO NON PASSA, C''E'' GIA'' TUTTO?' -ForegroundColor Cyan
Write-Host ''

# 1. Gli attrezzi.
$taskVersion = (& task --version 2>$null)
if ($LASTEXITCODE -eq 0) { Write-Line 'go-task' ($taskVersion -join ' ') } else { Write-Line 'go-task' 'non trovato' 'Red'; $problems++ }

if (Test-Path $javaHome) {
    Write-Line 'JDK' $javaHome
} else {
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) { Write-Line 'JDK' ("dal PATH: " + $java.Source) 'Yellow' }
    else { Write-Line 'JDK' 'non trovato' 'Red'; $problems++ }
}

# 2. La cache Maven: senza questa, offline non si compila.
$m2 = Join-Path $env:USERPROFILE '.m2/repository'
if (Test-Path $m2) {
    $bootJars = @(Get-ChildItem -Path (Join-Path $m2 'org/springframework/boot') -Directory -ErrorAction SilentlyContinue)
    if ($bootJars.Count -gt 0) {
        Write-Line 'cache Maven (~/.m2)' ("piena (" + $bootJars.Count + " artefatti Spring Boot)")
    } else {
        Write-Line 'cache Maven (~/.m2)' 'c''e'', ma senza Spring Boot' 'Red'
        $problems++
    }
} else {
    Write-Line 'cache Maven (~/.m2)' 'non c''e''' 'Red'
    $problems++
}

# La prova vera: compilare a rete finta staccata (-o = offline).
Write-Host ''
Write-Host '  Provo a compilare in modalita'' offline...' -ForegroundColor DarkGray
Push-Location $demoDir
try {
    cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q -o clean package -Dmaven.test.skip=true > `"$env:TEMP\offline-build.log`" 2>&1"
    $offlineBuild = $LASTEXITCODE
} finally { Pop-Location }
if ($offlineBuild -eq 0) {
    Write-Line 'build offline (mvnw -o)' 'RIESCE'
} else {
    Write-Line 'build offline (mvnw -o)' 'FALLISCE: lancia task offline-prep con la rete' 'Red'
    $problems++
}

# E un modulo nuovo, come quelli che creerai all'esame? Stessa prova, su un
# progetto usa-e-getta con un servizio con database e un'interfaccia.
Write-Host '  Provo a compilare offline anche un modulo nuovo (servizio con database + interfaccia)...' -ForegroundColor DarkGray
$probe = New-OfflineProbe
Push-Location (Join-Path $probe (Get-AggregatorName -RepoRoot $probe))
try {
    cmd /c "set JAVA_HOME=$javaHome&& .\mvnw.cmd -B -q -o package -Dmaven.test.skip=true -pl $($probeModules -join ',') -am > `"$env:TEMP\offline-probe.log`" 2>&1"
    $probeBuild = $LASTEXITCODE
} finally { Pop-Location }
Remove-Item -Recurse -Force $probe -ErrorAction SilentlyContinue
if ($probeBuild -eq 0) {
    Write-Line 'modulo nuovo offline' 'RIESCE (new-service, seed-data, db-schema)'
} else {
    Write-Line 'modulo nuovo offline' 'FALLISCE: lancia task offline-prep con la rete' 'Red'
    $problems++
}

# 3. Docker.
Write-Host ''
& docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Line 'Docker' 'non risponde (Docker Desktop e'' acceso?)' 'Yellow'
} else {
    $local = @(& docker images --format '{{.Repository}}:{{.Tag}}' 2>$null)
    foreach ($image in $images) {
        # Le immagini tirate giu' da una build di buildx finiscono nella sua
        # cache, non nell'elenco locale: qui vogliamo proprio l'elenco locale,
        # perche' e' quello che sopravvive a tutto.
        if ($local -contains $image) { Write-Line $image 'scaricata' }
        else { Write-Line $image 'non scaricata: task offline-prep' 'Red'; $problems++ }
    }
}

# 4. L'editor. Anche lui scarica: l'estensione Java di Zed prende jdtls,
#    Lombok e il debugger al primo file .java che apri, e senza rete non puo'.
#    Il progetto parte lo stesso, quindi e' un avviso e non un problema.
Write-Host ''
$editorSeen = $false
$zedRoot = Join-Path $env:LOCALAPPDATA 'Zed'
if (Test-Path (Join-Path $zedRoot 'extensions')) {
    $editorSeen = $true
    $zedJava = Join-Path $zedRoot 'extensions/work/java'
    $missing = @()
    if (-not @(Get-ChildItem (Join-Path $zedJava 'jdtls') -Directory -Filter 'jdt-language-server-*' -ErrorAction SilentlyContinue)) { $missing += 'jdtls' }
    if (-not @(Get-ChildItem (Join-Path $zedJava 'lombok') -Filter '*.jar' -ErrorAction SilentlyContinue)) { $missing += 'Lombok' }
    if (-not @(Get-ChildItem (Join-Path $zedJava 'debugger') -Filter '*.jar' -ErrorAction SilentlyContinue)) { $missing += 'debugger' }
    if (-not (Test-Path (Join-Path $zedRoot 'extensions/installed/java'))) {
        Write-Line 'Zed (estensione Java)' 'non installata: zed: extensions -> Java, con la rete' 'Yellow'
    } elseif ($missing.Count -gt 0) {
        Write-Line 'Zed (estensione Java)' ('manca ' + ($missing -join ', ') + ': apri un file .java in Zed, con la rete') 'Yellow'
    } else {
        Write-Line 'Zed (estensione Java)' 'jdtls, Lombok e debugger gia'' scaricati'
    }
}
$vscodeExtensions = Join-Path $env:USERPROFILE '.vscode/extensions'
if (Test-Path $vscodeExtensions) {
    $editorSeen = $true
    $hasJava = @(Get-ChildItem $vscodeExtensions -Directory -Filter 'redhat.java-*' -ErrorAction SilentlyContinue).Count -gt 0
    $hasDebug = @(Get-ChildItem $vscodeExtensions -Directory -Filter 'vscjava.vscode-java-debug-*' -ErrorAction SilentlyContinue).Count -gt 0
    if ($hasJava -and $hasDebug) { Write-Line 'VS Code (Java)' 'estensioni Java e debugger installate' }
    else { Write-Line 'VS Code (Java)' 'manca l''Extension Pack for Java: installalo con la rete' 'Yellow' }
}
if (-not $editorSeen) { Write-Line 'editor' 'ne'' VS Code ne'' Zed su questo PC' 'DarkGray' }

# --- Il verdetto --------------------------------------------------------------

Write-Host ''
if ($problems -eq 0) {
    Write-Host 'Tutto pronto: il progetto parte anche a rete staccata.' -ForegroundColor Green
} else {
    Write-Host "$problems cosa/e da sistemare: lancia task offline-prep finche' hai rete." -ForegroundColor Yellow
}
Write-Host ''
Write-Host '  Come presentare senza rete, in ordine di sicurezza:' -ForegroundColor DarkGray
Write-Host '    1. task dev      + task run-db   (Maven offline + il solo PostgreSQL in Docker)'
Write-Host '    2. task docker-up                (tutto in container: rifa'' le build, piu'' fragile)'
Write-Host ''
Write-Host '  Il primo modo non ricompila niente dentro Docker: e'' quello che' -ForegroundColor DarkGray
Write-Host '  regge meglio senza rete.' -ForegroundColor DarkGray
Write-Host ''
if ($problems -gt 0) { exit 1 }
