<#
.SYNOPSIS
    Allinea il progetto a una versione di Java: di default quella del JDK
    installato su questa macchina.

.DESCRIPTION
    La versione di Java e' scritta in quattro posti:

      demo/pom.xml              <java.version>, con cui Maven compila
      demo/Dockerfile           le immagini eclipse-temurin:<n>-jdk e -jre
      .vscode/settings.json     il runtime JavaSE-<n> e la cartella del JDK
      Taskfile.yml              la cartella del JDK di ripiego, per quando
                                JAVA_HOME non c'e'

    Se il progetto chiede un Java piu' nuovo di quello installato, `task build`
    si ferma con "release version 25 not supported"; se VS Code usa un JDK
    diverso da Maven, uno compila e l'altro no. Questo comando li mette
    d'accordo in una volta. Il wizard lo lancia da solo all'inizio.

    Spring Boot 4 vuole almeno Java 17.

.PARAMETER Version
    La versione da impostare (17, 21, 25...). Senza, quella del JDK trovato:
    prima JAVA_HOME, poi il java del PATH.

.EXAMPLE
    task set-java
    task set-java VERSION=21
#>
param([string]$Version = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$minimum = 17
# La versione piu' nuova con cui il template e' stato provato.
$tested = 25

$jdk = Get-MachineJdk
if (-not $Version) {
    if (-not $jdk) {
        throw "Non trovo un JDK (ne' in JAVA_HOME ne' nel PATH). Installane uno da $minimum in su, oppure indica la versione: task set-java VERSION=25"
    }
    $Version = [string]$jdk.Version
}
if ($Version -notmatch '^\d+$') { throw "Versione non valida: '$Version'. Un numero: 17, 21, 25..." }
$target = [int]$Version
if ($target -lt $minimum) {
    throw "Spring Boot 4 vuole almeno Java ${minimum}: con Java $target non parte. Installa un JDK piu' recente."
}
# Il percorso del JDK si scrive solo se e' davvero quella versione.
$sameAsMachine = ($jdk -and $jdk.Version -eq $target)

$current = Get-ProjectJavaVersion -RepoRoot $repoRoot

Write-Host ''
Write-Host "==> Java $current -> $target" -ForegroundColor Cyan
if ($jdk) { Write-Host ("  JDK di questa macchina: Java {0} in {1}" -f $jdk.Version, $jdk.Home) -ForegroundColor DarkGray }
Write-Host ''

# --- 1. Il pom: con questa versione compila Maven ----------------------------

$pom = Join-Path $demoDir 'pom.xml'
if ((Edit-TextFile -Path $pom -Pattern '<java\.version>\d+</java\.version>' -Replacement "<java.version>$target</java.version>") -eq 0) {
    throw "Non trovo <java.version> in demo/pom.xml: aggiungilo nelle <properties>."
}
Write-Step 'demo/pom.xml               <java.version>'

# --- 2. Il Dockerfile: il JDK che compila e il JRE che esegue -----------------

$dockerfile = Join-Path $demoDir 'Dockerfile'
if ((Edit-TextFile -Path $dockerfile -Pattern 'eclipse-temurin:\d+-(jdk|jre)' -Replacement "eclipse-temurin:$target-`$1") -gt 0) {
    Write-Step "demo/Dockerfile            eclipse-temurin:$target-jdk e -jre"
}

# --- 3. VS Code ---------------------------------------------------------------

$settings = Join-Path $repoRoot '.vscode/settings.json'
if ((Test-Path $settings) -and ((Read-TextFile $settings) -match '"JavaSE-\d+"')) {
    [void](Edit-TextFile -Path $settings -Pattern '"JavaSE-\d+"' -Replacement "`"JavaSE-$target`"")
    if ($sameAsMachine) {
        # Il "path" del blocco dei runtime, che e' l'unico del file.
        [void](Edit-TextFile -Path $settings -Pattern '(?s)("java\.configuration\.runtimes".*?"path":\s*")[^"]*(")' -Replacement ('${1}' + $jdk.Home + '${2}'))
    }
    Write-Step ".vscode/settings.json      runtime JavaSE-$target"
}

# --- 4. Il JDK di ripiego del Taskfile ---------------------------------------

if ($sameAsMachine) {
    $taskfile = Join-Path $repoRoot 'Taskfile.yml'
    if ((Edit-TextFile -Path $taskfile -Pattern 'for d in "\$JAVA_HOME" "[^"]*"' -Replacement ('for d in "$$JAVA_HOME" "' + $jdk.Home + '"')) -gt 0) {
        Write-Step "Taskfile.yml               JDK di ripiego: $($jdk.Home)"
    }
}

# --- Cosa resta da sapere -----------------------------------------------------

Write-Host ''
Write-Host "Java $target." -ForegroundColor Green
if ($jdk -and $jdk.Version -lt $target) {
    Write-Host ''
    Write-Host "  Il JDK di questa macchina e' Java $($jdk.Version): Maven non puo' compilare per Java $target." -ForegroundColor Yellow
    Write-Host "  In Docker funziona lo stesso (l'immagine ha il suo JDK); per task dev installa Java $target." -ForegroundColor Yellow
}
if ($target -gt $tested) {
    Write-Host ''
    Write-Host "  Spring Boot 4.0.5 e' stato provato fino a Java ${tested}: se qualcosa non parte, prova con $tested." -ForegroundColor Yellow
}
if ($current -ne $target) {
    Write-Host ''
    Write-Host '  Sono cambiate le immagini Docker di base: con la rete, task offline-prep' -ForegroundColor DarkGray
    Write-Host '  le scarica per l''esame senza rete.' -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  task build          per vedere che compila'
Write-Host ''
