<#
.SYNOPSIS
    Wizard: fa le domande e monta il progetto d'esame chiamando i comandi
    giusti, cosi' non devi ricordarteli.

.DESCRIPTION
    Due modi:

      task wizard                 il progetto intero: nome della cartella,
                                  database, e i microservizi uno per uno;
      task wizard SERVICE=<nome>  un microservizio solo.

    Non fa niente di magico: chiede, e poi lancia rename-project, db-config,
    new-service, use-postgres, enable-swagger e check. Gli stessi comandi che
    puoi dare a mano, nell'ordine giusto.

    Le cose che valgono per tutti i servizi (Eureka, OpenFeign, Swagger,
    Lombok, validation, actuator, common-dto) ci sono gia' nel modulo appena
    nasce: il wizard non le chiede perche' non c'e' niente da decidere.

.PARAMETER Service
    Salta le domande sul progetto e configura questo microservizio soltanto.
    Se non esiste lo crea.

.EXAMPLE
    task wizard
    task wizard SERVICE=ordini-service
#>
param([string]$Service = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot

if ([Console]::IsInputRedirected) {
    Write-Host ''
    Write-Host 'Il wizard fa domande: serve un terminale vero.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Lancialo da PowerShell con  task wizard'
    Write-Host '  oppure usa i comandi singoli: task new-service, task use-postgres, ...'
    Write-Host ''
    exit 1
}

# --- Domande ------------------------------------------------------------------

function Ask-Text {
    param([string]$Question, [string]$Default = '', [string]$Pattern = '', [string]$Hint = '')
    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { '' }
        Write-Host ''
        Write-Host ("  " + $Question + $suffix) -ForegroundColor Cyan
        if ($Hint) { Write-Host ("  " + $Hint) -ForegroundColor DarkGray }
        $answer = (Read-Host '  >').Trim()
        if (-not $answer) { $answer = $Default }
        if (-not $answer) { Write-Host '  Serve una risposta.' -ForegroundColor Yellow; continue }
        if ($Pattern -and ($answer -notmatch $Pattern)) {
            Write-Host '  Non va bene, riprova.' -ForegroundColor Yellow
            continue
        }
        return $answer
    }
}

function Ask-YesNo {
    param([string]$Question, [bool]$Default = $true)
    $suffix = if ($Default) { '[S/n]' } else { '[s/N]' }
    while ($true) {
        Write-Host ''
        Write-Host ("  " + $Question + " " + $suffix) -ForegroundColor Cyan
        $answer = (Read-Host '  >').Trim().ToLower()
        if (-not $answer) { return $Default }
        if ($answer -in @('s', 'si', 'y', 'yes')) { return $true }
        if ($answer -in @('n', 'no')) { return $false }
        Write-Host '  Rispondi s o n.' -ForegroundColor Yellow
    }
}

function Ask-Choice {
    param([string]$Question, [string[]]$Options, [int]$Default = 1)
    while ($true) {
        Write-Host ''
        Write-Host ("  " + $Question) -ForegroundColor Cyan
        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host ("    " + ($i + 1) + ") " + $Options[$i])
        }
        $answer = (Read-Host ("  [" + $Default + "] >")).Trim()
        if (-not $answer) { return $Default }
        if ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $Options.Count) { return [int]$answer }
        Write-Host '  Scegli un numero dell''elenco.' -ForegroundColor Yellow
    }
}

function Invoke-Step {
    # I parametri arrivano in una tabella hash, non in un array: lo splatting
    # di un array li passerebbe come posizionali, e '-Name' finirebbe dentro
    # $Name invece di dargli un nome.
    param([string]$Script, [hashtable]$Arguments = @{})
    $shown = (($Arguments.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [bool]) { "-$($_.Key)" } else { "-$($_.Key) $($_.Value)" }
    }) -join ' ')
    Write-Host ''
    Write-Host ('  $ ' + $Script + ' ' + $shown) -ForegroundColor DarkGray
    # Gli script si fermano da soli con un throw: qui basta lasciarlo salire.
    & (Join-Path $PSScriptRoot $Script) @Arguments
}

# --- Un microservizio ---------------------------------------------------------

function Get-DemoDir {
    return (Join-Path $repoRoot (Get-AggregatorName -RepoRoot $repoRoot))
}

function Invoke-ServiceWizard {
    param([string]$Name)

    $demoDir = Get-DemoDir
    $exists = Test-Path (Join-Path $demoDir "$Name/pom.xml")

    if ($exists) {
        Write-Host ''
        Write-Host "  Il modulo $Name c'e' gia': lo rifiniamo." -ForegroundColor Yellow
    } else {
        $kind = Ask-Choice -Question "Che cos'e' $Name?" -Options @(
            'servizio REST con database (il caso normale: entity, repository, controller)',
            'servizio REST senza database (calcoli, orchestrazione, chiamate ad altri servizi)',
            'interfaccia web Thymeleaf (le pagine che si vedono alla demo)'
        ) -Default 1

        $port = Ask-Text -Question 'Su quale porta?' -Default 'automatica' -Hint 'Invio = la prima libera dopo le altre'
        $newArgs = @{ Name = $Name }
        if ($port -ne 'automatica') { $newArgs['Port'] = $port }
        if ($kind -eq 2) { $newArgs['NoDb'] = $true }
        if ($kind -eq 3) { $newArgs['Ui'] = $true }
        Invoke-Step -Script 'new-service.ps1' -Arguments $newArgs

        if ($kind -eq 3) {
            if (Ask-YesNo -Question 'Vuoi Swagger UI anche su questa interfaccia web?' -Default $false) {
                Invoke-Step -Script 'enable-swagger.ps1' -Arguments @{ Module = $Name }
            }
        }
        if ($kind -eq 2) { return }
    }

    # Il database: solo per chi ce l'ha.
    $ymlPath = Join-Path $demoDir "$Name/src/main/resources/application.yml"
    if (-not (Test-Path $ymlPath)) { return }
    $yml = Read-TextFile $ymlPath
    if ($yml -notmatch 'datasource:') { return }
    if ($yml -match 'jdbc:postgresql') {
        Write-Host ''
        Write-Host "  $Name e' gia' collegato a PostgreSQL." -ForegroundColor DarkGray
        return
    }

    $db = Ask-Choice -Question "Che database usa $Name?" -Options @(
        'H2 in memoria (parte da solo, si svuota a ogni riavvio: comodo mentre sviluppi)',
        'PostgreSQL, il database condiviso del docker-compose',
        'PostgreSQL, con un database tutto suo (un servizio, un database)'
    ) -Default 1
    if ($db -eq 2) {
        Invoke-Step -Script 'use-postgres.ps1' -Arguments @{ Module = $Name }
    } elseif ($db -eq 3) {
        $dbName = Ask-Text -Question 'Come si chiama il suo database?' -Default ((Get-ModuleShortName -Module $Name) -replace '-', '_') -Pattern '^[a-z][a-z0-9_]*$'
        Invoke-Step -Script 'use-postgres.ps1' -Arguments @{ Module = $Name; DbName = $dbName }
    }
}

# --- Un servizio solo ---------------------------------------------------------

if ($Service) {
    if ($Service -notmatch '^[a-z][a-z0-9-]*$') {
        throw "Nome non valido: '$Service'. Minuscole, numeri e trattini."
    }
    Write-Host ''
    Write-Host "==> Wizard: $Service" -ForegroundColor Cyan
    Invoke-ServiceWizard -Name $Service
    Write-Host ''
    & (Join-Path $PSScriptRoot 'check.ps1') -ProjectOnly
    Write-Host ''
    Write-Host '  task dev          riavvia lo stack (un modulo nuovo non basta ricompilarlo)'
    Write-Host ''
    exit 0
}

# --- Il progetto intero -------------------------------------------------------

Write-Host ''
Write-Host '==================================================================' -ForegroundColor Cyan
Write-Host ' WIZARD DEL PROGETTO' -ForegroundColor Cyan
Write-Host '==================================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Rispondi alle domande: alla fine il progetto e'' montato, coerente'
Write-Host '  e pronto da avviare. Invio accetta il valore fra parentesi.'
Write-Host ''
Write-Host '  Eureka (naming-server) c''e'' gia'': e'' il registro dei servizi, e' -ForegroundColor DarkGray
Write-Host '  senza di lui i nomi delle chiamate Feign non si risolvono.' -ForegroundColor DarkGray

# 1. Il nome del progetto
$demoName = (Split-Path -Leaf (Get-DemoDir))
$projectName = Ask-Text -Question 'Come si chiama la cartella con i moduli Maven?' -Default $demoName -Pattern '^[a-z][a-z0-9-]*$' -Hint 'La cartella che oggi contiene pom.xml e docker-compose.yml'
if ($projectName -ne $demoName) {
    Invoke-Step -Script 'rename-project.ps1' -Arguments @{ Name = $projectName }
}

# 2. Il database
if (Ask-YesNo -Question 'Il progetto usa PostgreSQL? (altrimenti resta H2 in memoria)' -Default $true) {
    $dbName = Ask-Text -Question 'Nome del database' -Default 'esame' -Pattern '^[a-z][a-z0-9_]*$'
    $dbUser = Ask-Text -Question 'Utente del database' -Default 'exam' -Pattern '^[a-z][a-z0-9_]*$'
    $dbPassword = Ask-Text -Question 'Password' -Default 'exam' -Pattern '^[A-Za-z0-9_]+$'
    Invoke-Step -Script 'db-config.ps1' -Arguments @{ DbName = $dbName; User = $dbUser; Password = $dbPassword }
    $usePostgres = $true
} else {
    $usePostgres = $false
}

# 3. I microservizi
Write-Host ''
Write-Host '------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host ' I MICROSERVIZI' -ForegroundColor Cyan
Write-Host '------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Una traccia tipica ne chiede due o tre piu'' la UI. Per esempio:'
Write-Host '    ordini-service   i dati e le operazioni sugli ordini'
Write-Host '    magazzino-service la disponibilita'', chiamata dal primo via Feign'
Write-Host '    web-ui           le pagine Thymeleaf della demo'
Write-Host ''
Write-Host '  Nome vuoto (solo Invio) quando hai finito.' -ForegroundColor DarkGray

$created = @()
while ($true) {
    Write-Host ''
    Write-Host '  Nome del microservizio (Invio per finire)' -ForegroundColor Cyan
    $name = (Read-Host '  >').Trim()
    if (-not $name) { break }
    if ($name -notmatch '^[a-z][a-z0-9-]*$') {
        Write-Host '  Minuscole, numeri e trattini. Riprova.' -ForegroundColor Yellow
        continue
    }
    if (-not $usePostgres) {
        # Senza PostgreSQL nel progetto, il sotto-wizard non deve proporlo.
        $demoDir = Get-DemoDir
        $exists = Test-Path (Join-Path $demoDir "$name/pom.xml")
        if (-not $exists) {
            $kind = Ask-Choice -Question "Che cos'e' $name?" -Options @(
                'servizio REST con database H2',
                'servizio REST senza database',
                'interfaccia web Thymeleaf'
            ) -Default 1
            $newArgs = @{ Name = $name }
            if ($kind -eq 2) { $newArgs['NoDb'] = $true }
            if ($kind -eq 3) { $newArgs['Ui'] = $true }
            Invoke-Step -Script 'new-service.ps1' -Arguments $newArgs
        }
    } else {
        Invoke-ServiceWizard -Name $name
    }
    $created += $name
}

# 4. La prova del nove
Write-Host ''
Write-Host '------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host ''
& (Join-Path $PSScriptRoot 'check.ps1') -ProjectOnly

Write-Host ''
Write-Host 'Progetto montato.' -ForegroundColor Green
Write-Host ''
if ($created.Count -gt 0) {
    Write-Host ('  Moduli creati: ' + ($created -join ', '))
    Write-Host ''
}
Write-Host '  Adesso, nell''ordine:'
Write-Host ''
Write-Host '   1. scrivi le entity del dominio della traccia'
Write-Host '      (@Entity, @Table, @Id, i campi, le relazioni)'
Write-Host '   2. task seed-data      riempie il database di dati di prova'
Write-Host '   3. task dev            avvia tutto in locale, con hot reload'
Write-Host '   4. task db-schema      lo schema da incollare nell''allegato'
Write-Host '   5. task consegna       la cartella da consegnare'
Write-Host ''
Write-Host '  task help per tutto il resto.' -ForegroundColor DarkGray
Write-Host ''
