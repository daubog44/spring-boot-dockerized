<#
.SYNOPSIS
    Collauda gli strumenti del template su una copia usa-e-getta del progetto.

.DESCRIPTION
    Copia il repository in una cartella temporanea (senza .git, target e log) e
    li' esegue new-service, add-dep, set-port e check, verificando il risultato
    file per file. Il progetto vero non viene toccato, e alla fine la copia
    viene cancellata (se qualcosa fallisce resta, e ti dico dov'e').

    Serve a sapere che gli strumenti funzionano PRIMA di averne bisogno.

.PARAMETER Full
    Compila anche con Maven il modulo generato: piu' lento, ma verifica che il
    codice prodotto sia davvero compilabile.

.EXAMPLE
    task test
    task test FULL=1
#>
param([switch]$Full)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('esame-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

Write-Host ''
Write-Host 'COLLAUDO DEGLI STRUMENTI' -ForegroundColor Cyan
Write-Host "  copia di prova: $sandbox" -ForegroundColor DarkGray
Write-Host ''

# robocopy esce con codici 0-7 quando ha funzionato (1 = file copiati).
# /XF .git oltre a /XD .git: in un worktree di git (git worktree add) .git e'
# un FILE che punta al repository vero. Copiato nella prova, faceva lavorare
# git mv di rename-project sull'indice del worktree vero: la rinomina di demo
# finiva nel commit successivo.
$null = robocopy $repoRoot $sandbox /E /XD target .git .dev-logs node_modules .task consegna /XF .git /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "Copia del progetto fallita (robocopy $LASTEXITCODE)." }
if (Test-Path (Join-Path $sandbox '.git')) {
    throw "La copia di prova ha un .git: le prove toccherebbero il repository vero. Mi fermo."
}

$sandboxScripts = Join-Path $sandbox 'scripts'
$demo = Join-Path $sandbox 'demo'

# --- Piccola libreria di prova ------------------------------------------------

$passed = 0
$failed = @()
$skipped = @()

function Invoke-Tool {
    param([string]$Script, [string[]]$Arguments = @())
    $path = Join-Path $sandboxScripts $Script
    # Qui vogliamo osservare i fallimenti, non subirli: con
    # $ErrorActionPreference = 'Stop' ogni riga di stderr di un processo
    # esterno diventerebbe un'eccezione nostra, e una prova che verifica un
    # errore atteso risulterebbe fallita.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $path @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{ ExitCode = $code; Output = $output }
}

function Get-BashPath {
    # Su Windows 'bash' nel PATH e' quello di WSL, che qui non esiste: cerchiamo
    # prima quello di Git for Windows.
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git/bin/bash.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'Git/bin/bash.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs/Git/bin/bash.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $found = Get-Command bash -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notmatch 'System32') { return $found.Source }
    return $null
}

function Get-Text { param([string]$RelativePath) ; return (Read-TextFile (Join-Path $sandbox $RelativePath)) }

# Il pacchetto di un modulo nella copia di prova, come percorso: la base cambia
# da un branch all'altro (e la cambiano il wizard e set-package), quindi la
# leggiamo ogni volta.
function Get-SandboxPackagePath {
    param([string]$Module)
    return ((Get-ModulePackage -Module $Module -Base (Get-BasePackage -RepoRoot $sandbox)) -replace '\.', '/')
}

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text -notmatch [regex]::Escape($Needle)) { throw "$Message (non trovo: $Needle)" }
}
function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text -match [regex]::Escape($Needle)) { throw "$Message (trovato invece: $Needle)" }
}
function Assert-Ok {
    param($Result, [string]$Message)
    if ($Result.ExitCode -ne 0) { throw "$Message`n$($Result.Output)" }
}
function Assert-Fails {
    param($Result, [string]$Message)
    if ($Result.ExitCode -eq 0) { throw "$Message (invece e' andato a buon fine)`n$($Result.Output)" }
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Write-Host ("  OK    {0}" -f $Name) -ForegroundColor Green
        $script:passed++
    } catch {
        # Una prova che non si puo' eseguire qui (manca uno strumento) non e'
        # un fallimento: lo diciamo e andiamo avanti.
        if ($_.Exception.Message -like 'SALTATO*') {
            Write-Host ("  SALTATA  {0} -- {1}" -f $Name, ($_.Exception.Message -replace '^SALTATO:\s*', '')) -ForegroundColor Yellow
            $script:skipped += $Name
            return
        }
        Write-Host ("  FALLITO  {0}" -f $Name) -ForegroundColor Red
        Write-Host ("           {0}" -f ($_.Exception.Message -replace "`r?`n", "`n           ")) -ForegroundColor Red
        $script:failed += $Name
    }
}

# --- Le prove -----------------------------------------------------------------

Test-Case 'il progetto di partenza e'' coerente (task check)' {
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'task check non passa sul progetto cosi'' com''e'''
}

Test-Case 'new-service crea il modulo e lo collega ovunque' {
    $r = Invoke-Tool 'new-service.ps1' @('-Name', 'alfa-service')
    Assert-Ok $r 'new-service e'' fallito'

    Assert-That (Test-Path (Join-Path $demo 'alfa-service/pom.xml')) 'manca il pom del modulo'
    Assert-That (Test-Path (Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/Main.java'))) 'manca Main.java'
    Assert-That (Test-Path (Join-Path $demo 'alfa-service/src/main/resources/application.yml')) 'manca application.yml'

    [void][xml](Get-Text 'demo/alfa-service/pom.xml')
    Assert-Contains (Get-Text 'demo/alfa-service/pom.xml') '<artifactId>alfa-service</artifactId>' 'artifactId sbagliato'
    Assert-Contains (Get-Text 'demo/pom.xml') '<module>alfa-service</module>' 'non aggiunto ai <modules>'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'COPY alfa-service/pom.xml' 'non aggiunto al Dockerfile'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'MODULE: alfa-service' 'non aggiunto al compose'
    # Un nome fisso farebbe scontrare due copie del progetto sulla stessa macchina.
    Assert-That ((Get-Text 'demo/docker-compose.yml') -notmatch '(?m)^\s+container_name:') 'il compose non deve fissare i nomi dei container'
    # Ogni dipendenza sulla sua riga: e' un file che si consegna.
    Assert-NotContains (Get-Text 'demo/alfa-service/pom.xml') '</dependency>        <dependency>' 'due dipendenze sulla stessa riga del pom'
    # Senza queste due, le prime chiamate Feign dopo l'avvio falliscono per
    # 30-60 secondi ("Load balancer does not contain an instance").
    $alfaYml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $alfaYml 'registry-fetch-interval-seconds: 5' 'il registro di Eureka si rileggerebbe ogni 30 secondi'
    Assert-Contains $alfaYml 'ttl: 5s' 'la cache del load balancer resterebbe a 35 secondi'
    Assert-Contains (Get-Text 'scripts/dev.ps1') "Module = 'alfa-service'" 'non aggiunto alla lista di dev.ps1'
    Assert-Contains (Get-Text 'scripts/dev.sh') ':alfa-service:' 'non aggiunto alla lista di dev.sh'
}

Test-Case 'il modulo nuovo e'' coerente (task check)' {
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo new-service il progetto non e'' piu'' coerente'
}

Test-Case 'new-service UI=1 genera Thymeleaf e la pagina, senza JPA' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'beta-ui', '-Ui')) 'new-service -Ui e'' fallito'
    $pom = Get-Text 'demo/beta-ui/pom.xml'
    Assert-Contains $pom 'spring-boot-starter-thymeleaf' 'manca thymeleaf'
    Assert-NotContains $pom 'spring-boot-starter-data-jpa' 'una UI non deve avere JPA'
    Assert-That (Test-Path (Join-Path $demo 'beta-ui/src/main/resources/templates/index.html')) 'manca la pagina index.html'
    Assert-NotContains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'datasource' 'una UI non deve avere datasource'
}

Test-Case 'new-service NODB=1 lascia fuori database e driver' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'gamma-service', '-NoDb')) 'new-service -NoDb e'' fallito'
    $pom = Get-Text 'demo/gamma-service/pom.xml'
    Assert-NotContains $pom 'spring-boot-starter-data-jpa' 'NoDb non deve mettere JPA'
    Assert-NotContains $pom '<artifactId>h2</artifactId>' 'NoDb non deve mettere H2'
    Assert-NotContains $pom '<artifactId>postgresql</artifactId>' 'NoDb non deve mettere PostgreSQL'
}

Test-Case 'new-service assegna porte diverse a moduli diversi' {
    $a = [regex]::Match((Get-Text 'demo/alfa-service/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    $b = [regex]::Match((Get-Text 'demo/beta-ui/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    $c = [regex]::Match((Get-Text 'demo/gamma-service/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    Assert-That ($a -and $b -and $c) 'porta non scritta in qualche application.yml'
    Assert-That ((@($a, $b, $c) | Select-Object -Unique).Count -eq 3) "porte assegnate: $a, $b, $c"
}

Test-Case 'new-service rifiuta un modulo che esiste gia''' {
    Assert-Fails (Invoke-Tool 'new-service.ps1' @('-Name', 'alfa-service')) 'ha ricreato un modulo esistente'
}

Test-Case 'new-service rifiuta un nome non valido' {
    Assert-Fails (Invoke-Tool 'new-service.ps1' @('-Name', 'Alfa_Service')) 'ha accettato un nome con maiuscole e underscore'
}

Test-Case 'new-service senza NAME spiega come si usa' {
    $r = Invoke-Tool 'new-service.ps1'
    Assert-Fails $r 'senza NAME dovrebbe fallire'
    Assert-Contains $r.Output 'task new-service NAME=' 'il messaggio non dice come si usa'
}

Test-Case 'add-dep aggiunge dal catalogo' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'security,mail')) 'add-dep e'' fallito'
    $pom = Get-Text 'demo/alfa-service/pom.xml'
    [void][xml]$pom
    Assert-Contains $pom 'spring-boot-starter-security' 'manca security'
    Assert-Contains $pom 'spring-boot-starter-mail' 'manca mail'
}

Test-Case 'add-dep non duplica quello che c''e'' gia''' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'security')) 'la seconda add-dep e'' fallita'
    $count = ([regex]'<artifactId>spring-boot-starter-security</artifactId>').Matches((Get-Text 'demo/alfa-service/pom.xml')).Count
    Assert-That ($count -eq 1) "security compare $count volte nel pom"
}

Test-Case 'add-dep accetta le coordinate per esteso' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'org.apache.commons:commons-lang3:3.17.0')) 'coordinate rifiutate'
    $pom = Get-Text 'demo/alfa-service/pom.xml'
    Assert-Contains $pom '<artifactId>commons-lang3</artifactId>' 'manca commons-lang3'
    Assert-Contains $pom '<version>3.17.0</version>' 'manca la versione delle coordinate'
}

Test-Case 'add-dep rifiuta un nome sconosciuto e non tocca il pom' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'non-esiste-questa')
    Assert-Fails $r 'ha accettato una dipendenza inventata'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'il pom e'' stato modificato lo stesso'
}

Test-Case 'add-dep salta devtools, che e'' gia'' nel pom padre' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'devtools')
    Assert-Ok $r 'devtools non dovrebbe essere un errore'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'ha aggiunto devtools al modulo'
}

Test-Case 'add-dep LIST=1 elenca il catalogo' {
    $r = Invoke-Tool 'add-dep.ps1' @('-List')
    Assert-Ok $r 'LIST=1 e'' fallito'
    Assert-Contains $r.Output 'data-jpa' 'il catalogo non elenca data-jpa'
    Assert-Contains $r.Output 'feign' 'il catalogo non elenca feign'
}

Test-Case 'set-port sposta la porta in tutti i file' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'alfa-service', '-Port', '8199')) 'set-port e'' fallito'
    Assert-Contains (Get-Text 'demo/alfa-service/src/main/resources/application.yml') 'SERVER_PORT:8199' 'application.yml non aggiornato'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'SERVER_PORT: 8199' 'compose: variabile d''ambiente non aggiornata'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') '"8199:8199"' 'compose: porta pubblicata non aggiornata'
    Assert-Contains (Get-Text 'scripts/dev.ps1') 'Port = 8199' 'dev.ps1 non aggiornato'
    Assert-Contains (Get-Text 'scripts/dev.sh') ':alfa-service:8199' 'dev.sh non aggiornato'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-port il progetto non e'' piu'' coerente'
}

Test-Case 'set-port rifiuta una porta gia'' occupata' {
    Assert-Fails (Invoke-Tool 'set-port.ps1' @('-Module', 'gamma-service', '-Port', '8199')) 'ha accettato una porta gia'' usata'
}

Test-Case 'set-port su Eureka aggiorna chi lo cerca' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'naming-server', '-Port', '8762')) 'set-port su naming-server e'' fallito'
    Assert-Contains (Get-Text 'demo/alfa-service/src/main/resources/application.yml') 'localhost:8762' 'il defaultZone di un client non e'' stato aggiornato'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'eureka-server:8762' 'EUREKA_SERVER_URL dei container non aggiornato'
    Assert-NotContains (Get-Text 'demo/docker-compose.yml') 'localhost:8761/actuator' 'healthcheck di Eureka rimasto sulla porta vecchia'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo aver spostato Eureka il progetto non e'' piu'' coerente'
}

Test-Case 'enable-swagger e'' idempotente su un modulo che ce l''ha gia''' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'enable-swagger.ps1' @('-Module', 'alfa-service')
    Assert-Ok $r 'enable-swagger e'' fallito'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'ha toccato un pom che era gia'' a posto'
    Assert-Contains $r.Output 'gia'' presente' 'non dice che c''era gia'' tutto'
}

Test-Case 'enable-swagger rimette springdoc dove manca' {
    # Simuliamo un modulo scritto a mano: niente dipendenza, niente blocco yml.
    $pomPath = Join-Path $demo 'beta-ui/pom.xml'
    $pattern = '\s*<dependency>\s*<groupId>org\.springdoc</groupId>.*?</dependency>'
    Write-TextFile -Path $pomPath -Text ([regex]::Replace((Read-TextFile $pomPath), $pattern, '', 'Singleline'))
    $ymlPath = Join-Path $demo 'beta-ui/src/main/resources/application.yml'
    $yml = Read-TextFile $ymlPath
    Write-TextFile -Path $ymlPath -Text ($yml.Substring(0, $yml.IndexOf('springdoc:')).TrimEnd() + "`n")

    Assert-Ok (Invoke-Tool 'enable-swagger.ps1' @('-Module', 'beta-ui')) 'enable-swagger e'' fallito'
    Assert-Contains (Get-Text 'demo/beta-ui/pom.xml') '<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>' 'dipendenza non rimessa'
    Assert-Contains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'swagger-ui:' 'blocco yml non rimesso'
}

Test-Case 'use-postgres collega il modulo al database condiviso' {
    Assert-Ok (Invoke-Tool 'use-postgres.ps1' @('-Module', 'alfa-service')) 'use-postgres e'' fallito'
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $yml 'jdbc:postgresql://localhost:5432/' 'application.yml non punta a postgres'
    Assert-NotContains $yml 'jdbc:h2:mem' 'e'' rimasto l''H2'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'jdbc:postgresql://postgres:5432/' 'il compose non passa l''url del container'
    Assert-Contains (Get-Text 'demo/alfa-service/pom.xml') '<artifactId>postgresql</artifactId>' 'manca il driver nel pom'
    Assert-Contains (Get-Text 'scripts/dev.ps1') '$usesPostgres = $true' 'task dev non avviera'' il database'
    Assert-Contains (Get-Text 'scripts/dev.sh') 'USES_POSTGRES=1' 'dev.sh non allineato'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo use-postgres il progetto non e'' piu'' coerente'
}

Test-Case 'use-postgres con DBNAME crea il database dedicato' {
    Assert-Ok (Invoke-Tool 'use-postgres.ps1' @('-Module', 'beta-ui', '-DbName', 'betadb')) 'use-postgres con DBNAME e'' fallito'
    Assert-That (Test-Path (Join-Path $demo 'postgres-init/create-betadb.sql')) 'manca lo script di init'
    Assert-Contains (Get-Text 'demo/postgres-init/create-betadb.sql') 'CREATE DATABASE betadb' 'lo script non crea il database'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'postgres-init:/docker-entrypoint-initdb.d' 'il compose non monta gli script di init'
    Assert-Contains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'betadb' 'il modulo non punta al suo database'
}

Test-Case 'use-postgres rifiuta un modulo che non esiste' {
    Assert-Fails (Invoke-Tool 'use-postgres.ps1' @('-Module', 'questo-non-esiste')) 'ha accettato un modulo inventato'
}

Test-Case 'remove-service toglie il modulo da tutti i file' {
    Assert-Ok (Invoke-Tool 'remove-service.ps1' @('-Module', 'gamma-service')) 'remove-service e'' fallito'
    Assert-That (-not (Test-Path (Join-Path $demo 'gamma-service'))) 'la cartella del modulo e'' rimasta'
    Assert-NotContains (Get-Text 'demo/pom.xml') '<module>gamma-service</module>' 'ancora fra i <modules>'
    Assert-NotContains (Get-Text 'demo/Dockerfile') 'COPY gamma-service/pom.xml' 'ancora nel Dockerfile'
    Assert-NotContains (Get-Text 'demo/docker-compose.yml') 'MODULE: gamma-service' 'ancora nel compose'
    Assert-NotContains (Get-Text 'scripts/dev.ps1') "Module = 'gamma-service'" 'ancora nella lista di dev.ps1'
    Assert-NotContains (Get-Text 'scripts/dev.sh') ':gamma-service:' 'ancora nella lista di dev.sh'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo remove-service il progetto non e'' piu'' coerente'
}

Test-Case 'remove-service rifiuta un modulo che non esiste' {
    Assert-Fails (Invoke-Tool 'remove-service.ps1' @('-Module', 'questo-non-esiste')) 'ha accettato un modulo inventato'
}

# --- La configurazione degli editor ------------------------------------------

Test-Case 'new-service mette il modulo nuovo nel launch.json' {
    $launch = Get-Text '.vscode/launch.json'
    Assert-Contains $launch '"projectName": "alfa-service"' 'il modulo nuovo non e'' fra le configurazioni di debug'
    Assert-Contains $launch '"projectName": "naming-server"' 'manca Eureka'
    Assert-Contains $launch 'Stack completo' 'manca il compound che li avvia tutti'
    # La classe Main deve essere quella vera, o il debug parte e non trova niente.
    $alfaMain = ((Get-SandboxPackagePath 'alfa-service') -replace '/', '.') + '.Main'
    Assert-Contains $launch $alfaMain 'classe Main sbagliata'
    # common-dto e' una libreria: non si avvia.
    Assert-NotContains $launch '"projectName": "common-dto"' 'una libreria non va fra le configurazioni di avvio'
    # Zed ha il suo file, con l'adattatore della sua estensione Java.
    $zedDebug = Get-Text '.zed/debug.json'
    Assert-Contains $zedDebug '"projectName": "alfa-service"' 'il modulo nuovo non e'' nel debug.json di Zed'
    Assert-Contains $zedDebug '"adapter": "Java"' 'il debug.json di Zed non usa l''adattatore Java'
    Assert-Contains $zedDebug $alfaMain 'classe Main sbagliata nel debug.json'
    Assert-NotContains $zedDebug '"projectName": "common-dto"' 'una libreria non va nel debug.json'
}

Test-Case 'i file degli editor sono JSON validi' {
    foreach ($relative in @('.vscode/launch.json', '.vscode/tasks.json', '.vscode/settings.json', '.zed/tasks.json', '.zed/debug.json', '.zed/settings.json')) {
        # I file di configurazione degli editor ammettono i commenti //: li
        # togliamo prima di darli al parser.
        $text = (Get-Text $relative) -replace '(?m)^\s*//.*$', ''
        try { $null = ConvertFrom-Json $text } catch { throw "$relative non e' JSON valido: $($_.Exception.Message)" }
    }
}

Test-Case 'remove-service toglie il modulo anche dal launch.json' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'delta-service')) 'new-service e'' fallito'
    Assert-Contains (Get-Text '.vscode/launch.json') '"projectName": "delta-service"' 'non aggiunto al launch.json'
    Assert-Ok (Invoke-Tool 'remove-service.ps1' @('-Module', 'delta-service')) 'remove-service e'' fallito'
    Assert-NotContains (Get-Text '.vscode/launch.json') 'delta-service' 'rimasto nel launch.json'
    Assert-NotContains (Get-Text '.zed/debug.json') 'delta-service' 'rimasto nel debug.json di Zed'
}

Test-Case 'set-port aggiorna la porta scritta nel launch.json' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'alfa-service', '-Port', '8399')) 'set-port e'' fallito'
    Assert-Contains (Get-Text '.vscode/launch.json') 'alfa-service (:8399)' 'la porta nel launch.json e'' rimasta indietro'
    Assert-Contains (Get-Text '.zed/debug.json') 'alfa-service (:8399)' 'la porta nel debug.json di Zed e'' rimasta indietro'
}

Test-Case 'check si accorge se il launch.json e'' rimasto indietro' {
    $launchPath = Join-Path $sandbox '.vscode/launch.json'
    $saved = Read-TextFile $launchPath
    Write-TextFile -Path $launchPath -Text ($saved -replace '"projectName": "alfa-service"', '"projectName": "servizio-fantasma"')
    $r = Invoke-Tool 'check.ps1' @('-ProjectOnly')
    Assert-Fails $r 'check non si e'' accorto del modulo fantasma'
    Assert-Contains $r.Output 'task ide-sync' 'check non dice come rimediare'
    Write-TextFile -Path $launchPath -Text $saved
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'rimesso a posto, check dovrebbe passare'
}

# --- Database: credenziali, dati di prova, schema ----------------------------

Test-Case 'db-config stampa la configurazione del database' {
    $r = Invoke-Tool 'db-config.ps1'
    Assert-Ok $r 'db-config senza variabili e'' fallito'
    # Il nome del database cambia da un branch all'altro: lo leggiamo dal compose.
    $dbNow = [regex]::Match((Get-Text 'demo/docker-compose.yml'), '(?m)^\s+POSTGRES_DB:\s*(\S+)').Groups[1].Value
    Assert-Contains $r.Output $dbNow 'non stampa il nome del database'
    Assert-Contains $r.Output 'alfa-service' 'non elenca i moduli collegati'
}

Test-Case 'db-config cambia le credenziali dappertutto' {
    Assert-Ok (Invoke-Tool 'db-config.ps1' @('-DbName', 'collaudo', '-User', 'tester', '-Password', 'segreta', '-Port', '5544')) 'db-config e'' fallito'
    $compose = Get-Text 'demo/docker-compose.yml'
    Assert-Contains $compose 'POSTGRES_DB: collaudo' 'il container non ha il database nuovo'
    Assert-Contains $compose 'POSTGRES_USER: tester' 'il container non ha l''utente nuovo'
    Assert-Contains $compose 'pg_isready -U tester -d collaudo' 'la healthcheck e'' rimasta indietro'
    Assert-Contains $compose '"5544:5432"' 'la porta pubblicata non e'' cambiata'
    Assert-Contains $compose 'jdbc:postgresql://postgres:5432/collaudo' 'il modulo nel compose punta ancora al vecchio database'
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $yml 'jdbc:postgresql://localhost:5544/collaudo' 'application.yml non aggiornato'
    Assert-Contains $yml '_DB_USERNAME:tester}' 'utente non aggiornato in application.yml'
    Assert-Contains (Get-Text 'demo/postgres-init/create-betadb.sql') 'TO tester;' 'la GRANT del database dedicato e'' rimasta indietro'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo db-config il progetto non e'' piu'' coerente'
}

Test-Case 'db-config rifiuta un valore che PostgreSQL non accetterebbe' {
    Assert-Fails (Invoke-Tool 'db-config.ps1' @('-DbName', 'non valido!')) 'ha accettato un nome impossibile'
}

# --- Java e pacchetto -----------------------------------------------------------

Test-Case 'set-java imposta la versione in pom, Dockerfile e VS Code' {
    Assert-Ok (Invoke-Tool 'set-java.ps1' @('-Version', '21')) 'set-java VERSION=21 e'' fallito'
    Assert-Contains (Get-Text 'demo/pom.xml') '<java.version>21</java.version>' 'il pom non e'' passato a Java 21'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'eclipse-temurin:21-jdk' 'l''immagine di build e'' rimasta indietro'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'eclipse-temurin:21-jre' 'l''immagine finale e'' rimasta indietro'
    Assert-Contains (Get-Text '.vscode/settings.json') '"JavaSE-21"' 'il runtime di VS Code e'' rimasto indietro'
}

Test-Case 'set-java rifiuta una versione troppo vecchia per Spring Boot 4' {
    Assert-Fails (Invoke-Tool 'set-java.ps1' @('-Version', '11')) 'ha accettato Java 11'
    Assert-Contains (Get-Text 'demo/pom.xml') '<java.version>21</java.version>' 'dopo il rifiuto il pom e'' cambiato lo stesso'
}

Test-Case 'set-java senza VERSION usa il JDK di questa macchina' {
    $jdk = Get-MachineJdk
    if (-not $jdk) { throw 'SALTATO: su questa macchina non c''e'' un JDK' }
    Assert-Ok (Invoke-Tool 'set-java.ps1') 'set-java e'' fallito'
    Assert-Contains (Get-Text 'demo/pom.xml') "<java.version>$($jdk.Version)</java.version>" 'il pom non segue il JDK della macchina'
    Assert-Contains (Get-Text '.vscode/settings.json') $jdk.Home 'VS Code non punta al JDK della macchina'
    Assert-Contains (Get-Text 'Taskfile.yml') $jdk.Home 'il JDK di ripiego del Taskfile e'' rimasto indietro'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-java il progetto non e'' coerente'
}

# --- Il wizard ----------------------------------------------------------------
# Le risposte gliele diamo da un file (WIZARD_ANSWERS), una per riga: una riga
# vuota vale come Invio.

Test-Case 'il wizard senza terminale si rifiuta invece di restare appeso' {
    $path = Join-Path $sandboxScripts 'wizard.ps1'
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # < NUL: nessuna tastiera. La redirezione la fa cmd, come farebbe una
        # pipeline o un'esecuzione automatica.
        $out = cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$path`" < NUL 2>&1" | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    Assert-That ($code -ne 0) "senza terminale doveva fermarsi`n$out"
    Assert-Contains $out 'terminale vero' 'non dice perche'' si ferma'
}

Test-Case 'il wizard si ferma se le risposte finiscono prima delle domande' {
    $answers = Join-Path $sandbox 'risposte-corte.txt'
    Write-TextFile -Path $answers -Text ''
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'wizard.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Fails $r 'con le risposte finite doveva fermarsi'
    Assert-Contains $r.Output 'risposte sono finite' 'non dice perche'' si ferma'
}

Test-Case 'il wizard monta database e servizi rispondendo alle domande' {
    $answers = Join-Path $sandbox 'risposte.txt'
    $lines = @(
        ''                                          # cartella dei moduli: resta com'e'
        'it.wiz'                                    # pacchetto Java: it.wiz invece di quello di oggi
        's', 'wizdb', 'wiz', 'wizpass', '5439'      # PostgreSQL, credenziali, porta
        'omega-service', '1', '', '2'               # REST con database, porta automatica, database condiviso
        'sigma-ui', '3', '', 'n'                    # interfaccia web, porta automatica, niente Swagger
        ''                                          # fine dei microservizi
    )
    # L'a capo in fondo serve: senza, l'ultima riga vuota non verrebbe letta.
    Write-TextFile -Path $answers -Text (($lines -join "`n") + "`n")
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'wizard.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Ok $r 'il wizard e'' fallito'

    $compose = Get-Text 'demo/docker-compose.yml'
    Assert-Contains $compose 'POSTGRES_DB: wizdb' 'il database non e'' quello scelto'
    Assert-Contains $compose '"5439:5432"' 'la porta scelta non e'' pubblicata'
    Assert-Contains (Get-Text 'demo/omega-service/src/main/resources/application.yml') 'jdbc:postgresql://localhost:5439/wizdb' 'il servizio non punta al database condiviso, sulla porta scelta'
    Assert-That (Test-Path (Join-Path $demo 'sigma-ui/src/main/resources/templates/index.html')) 'l''interfaccia web non ha la sua pagina'
    Assert-That (Test-Path (Join-Path $demo 'omega-service/src/main/java/it/wiz/omegaservice/Main.java')) 'il servizio non e'' nel pacchetto scelto'
    Assert-That (Test-Path (Join-Path $demo 'naming-server/src/main/java/it/wiz/namingserver/Main.java')) 'Eureka non si e'' spostato nel pacchetto scelto'
    Assert-Contains (Get-Text '.vscode/launch.json') '"projectName": "omega-service"' 'il servizio non e'' nel launch.json'
    Assert-Contains (Get-Text '.zed/debug.json') '"projectName": "sigma-ui"' 'l''interfaccia non e'' nel debug.json di Zed'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo il wizard il progetto non e'' coerente'
}

# Da qui in poi serve un dominio con delle @Entity: lo scriviamo noi.
$alfaPackage = (Get-SandboxPackagePath 'alfa-service') -replace '/', '.'
$entityDir = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service'))
Write-TextFile -Path (Join-Path $entityDir 'DepositoEntity.java') -Text @'
package __PKG__;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class DepositoEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String citta;
}
'@
Write-TextFile -Path (Join-Path $entityDir 'StatoArticolo.java') -Text @'
package __PKG__;

public enum StatoArticolo { DISPONIBILE, ESAURITO }
'@
Write-TextFile -Path (Join-Path $entityDir 'ArticoloEntity.java') -Text @'
package __PKG__;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "articoli")
public class ArticoloEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 80)
    private String nome;

    private Integer quantita;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private StatoArticolo stato;

    @ManyToOne
    @JoinColumn(name = "deposito_id")
    private DepositoEntity deposito;
}
'@

# Nome e cognome, un anno, un id che punta a un altro servizio: i valori
# devono sembrare veri, non "nome 1", 10, 20.
Write-TextFile -Path (Join-Path $entityDir 'SocioEntity.java') -Text @'
package __PKG__;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class SocioEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String nome;
    private String cognome;
    private Integer annoIscrizione;
    private Long tesseraId;
}
'@

# I file qui sopra dicono __PKG__: al suo posto va il pacchetto del modulo.
foreach ($file in (Get-ChildItem -Path $entityDir -Filter '*.java')) {
    [void](Edit-TextFile -Path $file.FullName -Pattern '__PKG__' -Replacement $alfaPackage)
}

Test-Case 'seed-data ricava le INSERT dalle @Entity' {
    Assert-Ok (Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '3')) 'seed-data e'' fallito'
    $sql = Get-Text 'demo/alfa-service/src/main/resources/data.sql'

    # Senza @Table il nome della tabella e' quello della classe, suffisso
    # compreso: e' cosi' che la chiama Hibernate.
    Assert-Contains $sql 'INSERT INTO deposito_entity' 'manca la tabella senza @Table'
    Assert-Contains $sql 'INSERT INTO articoli (nome, quantita, stato, deposito_id)' 'colonne sbagliate (la PK generata non va scritta)'
    Assert-Contains $sql 'DISPONIBILE' 'gli enum non arrivano dal file Java'
    # Ogni riga scatta solo se la tabella non e' ancora piena: un riavvio su
    # PostgreSQL non la duplica e una colonna unique non fa fallire l'avvio.
    Assert-Contains $sql 'WHERE (SELECT COUNT(*) FROM articoli) < 3;' 'le INSERT si ripeterebbero a ogni avvio'
    Assert-Contains $sql "INSERT INTO socio_entity (nome, cognome, anno_iscrizione, tessera_id) SELECT 'Mario', 'Rossi', 2017, 1 WHERE (SELECT COUNT(*) FROM socio_entity) < 1;" 'nome, cognome, anno o id non sembrano veri'

    # La tabella padre va riempita prima, o la chiave esterna punterebbe a niente.
    $primoDeposito = $sql.IndexOf('INSERT INTO deposito_entity')
    $primoArticolo = $sql.IndexOf('INSERT INTO articoli')
    Assert-That ($primoDeposito -lt $primoArticolo) 'le righe figlie vengono prima di quelle padre'

    $righe = ([regex]'INSERT INTO articoli').Matches($sql).Count
    Assert-That ($righe -eq 3) "ROWS=3 ha prodotto $righe righe"

    # Senza queste due proprieta' il file non verrebbe eseguito.
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $yml 'defer-datasource-initialization: true' 'manca la proprieta'' che rimanda data.sql dopo Hibernate'
    Assert-Contains $yml 'mode: always' 'manca spring.sql.init.mode'
}

Test-Case 'seed-data non ripete i valori quando le righe superano la tabella' {
    # Le tabelle di valori hanno otto voci: oltre l'ottava riga il valore deve
    # portarsi dietro il numero, o una colonna unique = true farebbe fallire
    # l'avvio.
    Assert-Ok (Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '12')) 'seed-data con 12 righe e'' fallito'
    $righe = @((Get-Text 'demo/alfa-service/src/main/resources/data.sql') -split "`r?`n" | Where-Object { $_ -match '^INSERT INTO articoli' })
    Assert-That ($righe.Count -eq 12) ("righe generate: " + $righe.Count)
    # Il conteggio in fondo cambia da riga a riga: confrontiamo solo i valori.
    $unici = @($righe | ForEach-Object { $_ -replace ' WHERE .*$', '' } | Select-Object -Unique)
    Assert-That ($unici.Count -eq 12) ("righe uguali fra loro: " + (12 - $unici.Count))
}

Test-Case 'db-schema ricava tabelle e relazioni dalle @Entity' {
    $r = Invoke-Tool 'db-schema.ps1'
    Assert-Ok $r 'db-schema e'' fallito'
    Assert-Contains $r.Output 'Modello concettuale' 'manca il modello concettuale'
    Assert-Contains $r.Output 'Modello logico' 'manca il modello logico'
    Assert-Contains $r.Output 'Tabella `articoli`' 'manca la tabella con @Table'
    Assert-Contains $r.Output 'Tabella `deposito_entity`' 'manca la tabella senza @Table'
    Assert-Contains $r.Output 'erDiagram' 'manca il diagramma ER'
    Assert-Contains $r.Output 'FK' 'la chiave esterna non e'' segnata'
    Assert-Contains $r.Output '| `stato` | VARCHAR(20) |' 'la lunghezza di un enum con @Column(length) e'' ignorata'
}

Test-Case 'set-package sposta i sorgenti e riscrive package, import e mainClass' {
    $old = Get-BasePackage -RepoRoot $sandbox
    $alfaOld = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service'))
    # Una stringa che nomina la base ma non un suo sottopacchetto: deve restare com'e'.
    Write-TextFile -Path (Join-Path $alfaOld 'Frase.java') -Text ("package $old.alfaservice;`n`nclass Frase {`n    static final String TESTO = `"$old.pdf`";`n}`n")
    Assert-Ok (Invoke-Tool 'set-package.ps1' @('-Package', 'it.prova')) 'set-package e'' fallito'

    $alfaNew = Join-Path $demo 'alfa-service/src/main/java/it/prova/alfaservice'
    Assert-That (Test-Path (Join-Path $alfaNew 'Main.java')) 'Main.java non e'' nella cartella nuova'
    Assert-That (Test-Path (Join-Path $alfaNew 'ArticoloEntity.java')) 'le entity non si sono spostate'
    Assert-That (-not (Test-Path $alfaOld)) 'la cartella vecchia e'' rimasta'
    Assert-Contains (Read-TextFile (Join-Path $alfaNew 'ArticoloEntity.java')) 'package it.prova.alfaservice;' 'package non riscritto'
    Assert-Contains (Read-TextFile (Join-Path $alfaNew 'Frase.java')) "`"$old.pdf`"" 'ha riscritto una stringa che non era un pacchetto'
    Assert-That (Test-Path (Join-Path $demo 'naming-server/src/main/java/it/prova/namingserver/Main.java')) 'Eureka non si e'' spostato'
    Assert-Contains (Get-Text 'demo/naming-server/pom.xml') '<mainClass>it.prova.namingserver.Main</mainClass>' 'la mainClass del pom e'' rimasta indietro'
    Assert-Contains (Get-Text '.vscode/launch.json') 'it.prova.alfaservice.Main' 'launch.json non riallineato'
    $vecchi = @(Get-ChildItem -Path $demo -Recurse -Filter '*.java' | Where-Object {
        $_.FullName -notmatch '[\\/]target[\\/]' -and (Read-TextFile $_.FullName) -match ('(?m)^\s*(package|import)\s+' + [regex]::Escape($old) + '\.')
    })
    Assert-That ($vecchi.Count -eq 0) ('package o import ancora col pacchetto vecchio: ' + (($vecchi | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ', '))

    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'zeta-service', '-NoDb')) 'new-service dopo set-package e'' fallito'
    Assert-That (Test-Path (Join-Path $demo 'zeta-service/src/main/java/it/prova/zetaservice/Main.java')) 'il modulo nuovo non usa la base nuova'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-package il progetto non e'' coerente'
}

Test-Case 'set-package rifiuta un pacchetto non valido' {
    Assert-Fails (Invoke-Tool 'set-package.ps1' @('-Package', 'It.Prova')) 'ha accettato le maiuscole'
    Assert-Fails (Invoke-Tool 'set-package.ps1' @('-Package', 'it.class')) 'ha accettato una parola riservata'
}

Test-Case 'consegna prepara un archivio che parte appena scompattato' {
    Assert-Ok (Invoke-Tool 'consegna.ps1' @('-Nome', 'ROSSI_MARIO')) 'consegna e'' fallita'
    $zip = Join-Path $sandbox 'consegna/ROSSI_MARIO.zip'
    Assert-That (Test-Path $zip) 'manca consegna/ROSSI_MARIO.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try { $entries = @($archive.Entries | ForEach-Object { $_.FullName }) } finally { $archive.Dispose() }
    $storte = @($entries | Where-Object { $_ -match '\\' })
    Assert-That ($storte.Count -eq 0) ('percorsi con la barra rovesciata: ' + (($storte | Select-Object -First 3) -join ', '))

    # Scompattato come farebbe chi corregge, e poi quello che la build cerca:
    # i moduli del pom aggregatore e i pom che il Dockerfile copia.
    $dest = Join-Path $sandbox 'consegna-scompattata'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
    try {
        foreach ($f in @('docker-compose.yml', 'Dockerfile', 'pom.xml', 'mvnw', '.mvn/wrapper/maven-wrapper.properties', 'ALLEGATO-TECNICO.md', 'ISTRUZIONI-ESECUZIONE.md', 'SCHEMA-DATABASE.md')) {
            Assert-That (Test-Path (Join-Path $dest $f)) "scompattato l'archivio, manca $f accanto al compose"
        }
        foreach ($m in [regex]::Matches((Read-TextFile (Join-Path $dest 'pom.xml')), '<module>([^<]+)</module>')) {
            $mod = $m.Groups[1].Value
            Assert-That (Test-Path (Join-Path $dest "$mod/pom.xml")) "il pom aggregatore cerca $mod/pom.xml, che non c'e'"
            Assert-That (Test-Path (Join-Path $dest "$mod/src")) "mancano i sorgenti di $mod"
        }
        foreach ($m in [regex]::Matches((Read-TextFile (Join-Path $dest 'Dockerfile')), '(?m)^COPY\s+(\S+/pom\.xml)\s')) {
            Assert-That (Test-Path (Join-Path $dest $m.Groups[1].Value)) "il Dockerfile copia $($m.Groups[1].Value), che non c'e'"
        }
        $target = @(Get-ChildItem -Path $dest -Recurse -Directory -Filter 'target')
        Assert-That ($target.Count -eq 0) 'nella consegna ci sono cartelle target/'
        $zips = @(Get-ChildItem -Path $dest -Recurse -File -Filter '*.zip')
        Assert-That ($zips.Count -eq 0) ('archivi dentro l''archivio: ' + ($zips.Name -join ', '))
        Assert-NotContains (Read-TextFile (Join-Path $dest 'ISTRUZIONI-ESECUZIONE.md')) 'Scompatta ogni archivio' 'le istruzioni chiedono ancora di ricomporre il progetto'
    } finally {
        Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
    }
}

# Questa cambia il nome della cartella dei moduli: va per ultima.
Test-Case 'rename-project rinomina la cartella e i file che la nominano' {
    # Un modulo che comincia con il nome della cartella (biblioteca e
    # biblioteca-ui) non deve essere rinominato insieme a lei.
    $omonimo = (Split-Path -Leaf $demo) + '-extra'
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', $omonimo, '-NoDb')) 'new-service del modulo omonimo e'' fallito'
    Assert-Ok (Invoke-Tool 'rename-project.ps1' @('-Name', 'collaudo-modules')) 'rename-project e'' fallito'
    Assert-That (Test-Path (Join-Path $sandbox 'collaudo-modules/pom.xml')) 'la cartella nuova non c''e'''
    Assert-That (-not (Test-Path $demo)) 'la cartella vecchia e'' rimasta'
    Assert-Contains (Get-Text 'Taskfile.yml') 'dir: collaudo-modules' 'il Taskfile punta ancora alla cartella vecchia'
    Assert-Contains (Get-Text 'scripts/check.ps1') "'collaudo-modules'" 'gli script puntano ancora alla cartella vecchia'
    Assert-That (Test-Path (Join-Path $sandbox "collaudo-modules/$omonimo/pom.xml")) "il modulo $omonimo non c'e' piu'"
    Assert-Contains (Get-Text 'scripts/dev.ps1') "Module = '$omonimo'" "il modulo $omonimo e' stato rinominato insieme alla cartella"
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo rename-project il progetto non e'' piu'' coerente'
}

Test-Case 'gli script PowerShell hanno sintassi valida' {
    $bad = @()
    foreach ($file in (Get-ChildItem -Path $sandboxScripts -Filter '*.ps1')) {
        $errors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        if ($errors.Count -gt 0) { $bad += "$($file.Name): $($errors[0].Message)" }
    }
    Assert-That ($bad.Count -eq 0) ($bad -join "`n")
}

Test-Case 'gli script POSIX hanno sintassi valida' {
    $bash = Get-BashPath
    if (-not $bash) { throw 'SALTATO: bash non e'' installato su questa macchina' }
    $bad = @()
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($file in (Get-ChildItem -Path $sandboxScripts -Filter '*.sh')) {
            $out = & $bash -n $file.FullName 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { $bad += "$($file.Name): $out" }
        }
    } finally {
        $ErrorActionPreference = $previous
    }
    Assert-That ($bad.Count -eq 0) ($bad -join "`n")
}

if ($Full) {
    Test-Case 'il modulo generato compila (Maven)' {
        Push-Location $demo
        # Maven scrive avvisi su stderr anche quando va tutto bene (Lombok e
        # sun.misc.Unsafe): la redirezione la fa cmd, non PowerShell, che
        # altrimenti li trasformerebbe in errori nostri.
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            cmd /c ".\mvnw.cmd -q -pl alfa-service -am install -Dmaven.test.skip=true > NUL 2>&1"
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previous
            Pop-Location
        }
        Assert-That ($code -eq 0) "la compilazione del modulo generato e' fallita (exit $code)"
    }
}

# --- Esito --------------------------------------------------------------------

Write-Host ''
$skippedNote = if ($skipped.Count -gt 0) { " ($($skipped.Count) saltate)" } else { '' }
if ($failed.Count -eq 0) {
    Write-Host "$passed prove superate, nessun fallimento.$skippedNote" -ForegroundColor Green
    Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    Write-Host ''
    exit 0
}
Write-Host "$passed superate, $($failed.Count) fallite: $($failed -join ', ')" -ForegroundColor Red
Write-Host "La copia di prova resta qui, per guardarci dentro: $sandbox" -ForegroundColor Yellow
Write-Host ''
exit 1
