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
$null = robocopy $repoRoot $sandbox /E /XD target .git .dev-logs node_modules .task /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "Copia del progetto fallita (robocopy $LASTEXITCODE)." }

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
    Assert-That (Test-Path (Join-Path $demo 'alfa-service/src/main/java/com/example/ttfcloud_esame/alfaservice/Main.java')) 'manca Main.java'
    Assert-That (Test-Path (Join-Path $demo 'alfa-service/src/main/resources/application.yml')) 'manca application.yml'

    [void][xml](Get-Text 'demo/alfa-service/pom.xml')
    Assert-Contains (Get-Text 'demo/alfa-service/pom.xml') '<artifactId>alfa-service</artifactId>' 'artifactId sbagliato'
    Assert-Contains (Get-Text 'demo/pom.xml') '<module>alfa-service</module>' 'non aggiunto ai <modules>'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'COPY alfa-service/pom.xml' 'non aggiunto al Dockerfile'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'MODULE: alfa-service' 'non aggiunto al compose'
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
