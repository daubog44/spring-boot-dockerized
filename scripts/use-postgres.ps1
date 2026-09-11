<#
.SYNOPSIS
    Collega un modulo al PostgreSQL del progetto, al posto dell'H2 in memoria.

.DESCRIPTION
    I servizi creati da `task new-service` partono con H2 in memoria: comodo
    mentre sviluppi, ma i dati spariscono a ogni riavvio. Questo comando li
    sposta sul PostgreSQL che sta gia' nel docker-compose.yml, in tutti i punti
    che servono:

      - pom.xml: driver PostgreSQL e Spring Data JPA, se mancano;
      - application.yml: url, utente, password e driver del modulo;
      - docker-compose.yml: le stesse variabili per il container (dove il
        database non e' "localhost" ma "postgres"), e depends_on sul database;
      - scripts/dev.ps1 e dev.sh: `task dev` ora avvia anche PostgreSQL e ne
        aspetta la porta prima dei servizi.

    Con DBNAME crei un database dedicato a quel modulo (un servizio, un
    database: e' la regola dei microservizi). Il database in piu' nasce da uno
    script di init, che PostgreSQL esegue **solo la prima volta** che il volume
    e' vuoto: dopo averlo aggiunto serve un `task docker-reset`.

.PARAMETER Module
    Cartella del modulo sotto demo/.

.PARAMETER DbName
    Nome del database. Se omesso, quello gia' configurato nel compose.

.EXAMPLE
    task use-postgres SERVICE=ordini-service
    task use-postgres SERVICE=ordini-service DBNAME=ordini
#>
param(
    [string]$Module = '',
    [string]$DbName = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$moduleDir = Join-Path $demoDir $Module
$compose = Join-Path $demoDir 'docker-compose.yml'

if (-not $Module) {
    throw "Uso: task use-postgres SERVICE=<modulo> [DBNAME=<database>]"
}
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    $available = (Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name }) -join ', '
    throw "Modulo '$Module' non trovato. Moduli disponibili: $available"
}
$ymlPath = Join-Path $moduleDir 'src/main/resources/application.yml'
if (-not (Test-Path $ymlPath)) { throw "Non trovo $ymlPath." }

# --- Le credenziali le detta il container, non le inventiamo noi -------------

$composeText = Read-TextFile $compose
if ($composeText -notmatch '(?m)^\s+POSTGRES_DB:') {
    throw "In docker-compose.yml non c'e' un servizio postgres: aggiungilo prima di collegarci un modulo."
}
$defaultDb = [regex]::Match($composeText, '(?m)^\s+POSTGRES_DB:\s*(\S+)').Groups[1].Value
$dbUser = [regex]::Match($composeText, '(?m)^\s+POSTGRES_USER:\s*(\S+)').Groups[1].Value
$dbPassword = [regex]::Match($composeText, '(?m)^\s+POSTGRES_PASSWORD:\s*(\S+)').Groups[1].Value
if (-not $DbName) { $DbName = $defaultDb }

# Il prefisso delle variabili d'ambiente: se il modulo ne ha gia' uno lo
# teniamo, altrimenti lo deriviamo dal nome come fa new-service.
$yml = Read-TextFile $ymlPath
$prefixHit = [regex]::Match($yml, '\$\{([A-Z0-9_]+)_DB_URL:')
if ($prefixHit.Success) {
    $prefix = $prefixHit.Groups[1].Value
} else {
    $prefix = ((Get-ModuleShortName -Module $Module) -replace '-', '_').ToUpper()
}

Write-Host ''
Write-Host "==> $Module -> PostgreSQL (database '$DbName')" -ForegroundColor Cyan
Write-Host ''

# --- 1. Le dipendenze ---------------------------------------------------------

$pom = Read-TextFile (Join-Path $moduleDir 'pom.xml')
$missing = @()
if ($pom -notmatch '<artifactId>spring-boot-starter-data-jpa</artifactId>') { $missing += 'data-jpa' }
if ($pom -notmatch '<artifactId>postgresql</artifactId>') { $missing += 'postgresql' }
if ($missing.Count -gt 0) {
    # Riusiamo add-dep invece di reinventare l'inserimento nel pom.
    & (Join-Path $PSScriptRoot 'add-dep.ps1') -Module $Module -Deps ($missing -join ',') | Out-Null
    Write-Step ("pom.xml: aggiunte " + ($missing -join ', '))
} else {
    Write-Step 'pom.xml: data-jpa e driver PostgreSQL gia'' presenti'
}

# --- 2. application.yml -------------------------------------------------------

# Da fuori Docker si passa dalla porta pubblicata, che decide db-config (o il
# wizard): se la 5432 del PC era occupata, non e' piu' la 5432.
$portHit = [regex]::Match($composeText, '(?m)^\s+-\s*"(\d+):5432"')
$hostPort = if ($portHit.Success) { $portHit.Groups[1].Value } else { '5432' }
$localUrl = "jdbc:postgresql://localhost:$hostPort/$DbName"
if ($yml -match '(?m)^\s+datasource:') {
    [void](Edit-TextFile -Path $ymlPath -Pattern ('(?m)^(\s+url:\s*\$\{' + $prefix + '_DB_URL:)[^}]*(\})') -Replacement ('${1}' + $localUrl + '${2}'))
    [void](Edit-TextFile -Path $ymlPath -Pattern ('(?m)^(\s+username:\s*\$\{' + $prefix + '_DB_USERNAME:)[^}]*(\})') -Replacement ('${1}' + $dbUser + '${2}'))
    [void](Edit-TextFile -Path $ymlPath -Pattern ('(?m)^(\s+password:\s*\$\{' + $prefix + '_DB_PASSWORD:)[^}]*(\})') -Replacement ('${1}' + $dbPassword + '${2}'))
    [void](Edit-TextFile -Path $ymlPath -Pattern ('(?m)^(\s+driver-class-name:\s*\$\{' + $prefix + '_DB_DRIVER:)[^}]*(\})') -Replacement ('${1}org.postgresql.Driver${2}'))
    Write-Step "demo/$Module/src/main/resources/application.yml"
} else {
    # Nessun datasource (modulo creato con NODB=1, o una UI): lo aggiungiamo
    # sotto spring:, dove Spring Boot se lo aspetta.
    $lines = @(Split-TextLines $yml)
    $anchor = Find-LineIndex -Lines $lines -Pattern '(?m)^\s+application:'
    if ($anchor -lt 0) { throw "In $ymlPath non trovo il blocco 'spring:': aggiungi il datasource a mano." }
    $end = $anchor + 1
    while ($end -lt $lines.Count -and $lines[$end] -match '^\s{4,}\S') { $end++ }
    Add-LinesAt -Path $ymlPath -Index $end -NewLines @(
        ''
        '  datasource:'
        "    url: `${${prefix}_DB_URL:$localUrl}"
        "    username: `${${prefix}_DB_USERNAME:$dbUser}"
        "    password: `${${prefix}_DB_PASSWORD:$dbPassword}"
        "    driver-class-name: `${${prefix}_DB_DRIVER:org.postgresql.Driver}"
        ''
        '  jpa:'
        '    hibernate:'
        '      ddl-auto: update'
        '    show-sql: true'
    )
    Write-Step "demo/$Module/src/main/resources/application.yml (datasource aggiunto)"
}

# --- 3. docker-compose: variabili e dipendenza dal database ------------------

$lines = @(Split-TextLines (Read-TextFile $compose))
$moduleLine = Find-LineIndex -Lines $lines -Pattern ("^\s+MODULE:\s+" + [regex]::Escape($Module) + "\s*$")
if ($moduleLine -lt 0) {
    Write-Host "  docker-compose.yml: nessun servizio con MODULE: $Module, salto." -ForegroundColor Yellow
} else {
    $start = $moduleLine
    while ($start -gt 0 -and $lines[$start] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $start-- }
    $end = $moduleLine + 1
    while ($end -lt $lines.Count -and $lines[$end] -notmatch '^[A-Za-z0-9_-]+:\s*$' -and $lines[$end] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $end++ }

    $envLines = @(
        "      ${prefix}_DB_URL: jdbc:postgresql://postgres:5432/$DbName"
        "      ${prefix}_DB_USERNAME: $dbUser"
        "      ${prefix}_DB_PASSWORD: $dbPassword"
        "      ${prefix}_DB_DRIVER: org.postgresql.Driver"
    )

    # Ricostruiamo il blocco: via le vecchie variabili del database, dentro le
    # nuove, e postgres fra le dipendenze.
    $block = @()
    $envSeen = $false
    $dependsSeen = $false
    for ($i = $start; $i -lt $end; $i++) {
        $line = $lines[$i]
        if ($line -match ("^\s+" + $prefix + "_DB_(URL|USERNAME|PASSWORD|DRIVER):")) { continue }
        $block += $line
        if ($line -match '^    environment:\s*$') {
            $block += $envLines
            $envSeen = $true
        }
        if ($line -match '^    depends_on:\s*$') { $dependsSeen = $true }
    }
    if (-not $envSeen) {
        $block += '    environment:'
        $block += $envLines
    }
    if ($dependsSeen) {
        if (($block -join "`n") -notmatch '(?m)^      postgres:') {
            $out = @()
            foreach ($line in $block) {
                $out += $line
                if ($line -match '^    depends_on:\s*$') {
                    $out += '      postgres:'
                    $out += '        condition: service_healthy'
                }
            }
            $block = $out
        }
    } else {
        $block += '    depends_on:'
        $block += '      postgres:'
        $block += '        condition: service_healthy'
    }

    $rebuilt = @()
    if ($start -gt 0) { $rebuilt += $lines[0..($start - 1)] }
    $rebuilt += $block
    if ($end -lt $lines.Count) { $rebuilt += $lines[$end..($lines.Count - 1)] }
    Write-TextFile -Path $compose -Text ($rebuilt -join (Get-TextEol (Read-TextFile $compose)))
    Write-Step 'demo/docker-compose.yml'
}

# --- 4. Un database dedicato, se richiesto ------------------------------------

$needsReset = $false
if ($DbName -ne $defaultDb) {
    $initDir = Join-Path $demoDir 'postgres-init'
    $initFile = Join-Path $initDir "create-$DbName.sql"
    if (-not (Test-Path $initFile)) {
        Write-TextFile -Path $initFile -Text "-- Creato da task use-postgres: un database per il modulo $Module.`nCREATE DATABASE $DbName;`nGRANT ALL PRIVILEGES ON DATABASE $DbName TO $dbUser;`n"
        Write-Step "demo/postgres-init/create-$DbName.sql"
        $needsReset = $true
    }
    # Il mount della cartella di init, una volta sola.
    $composeText = Read-TextFile $compose
    if ($composeText -notmatch 'postgres-init:/docker-entrypoint-initdb.d') {
        $lines = @(Split-TextLines $composeText)
        $idx = Find-LineIndex -Lines $lines -Pattern '^\s+- postgres-data:'
        if ($idx -ge 0) {
            Add-LinesAt -Path $compose -Index $idx -NewLines @('      - ./postgres-init:/docker-entrypoint-initdb.d')
            Write-Step 'demo/docker-compose.yml (monta gli script di init)'
        }
    }
}

# --- 5. task dev deve avviare il database ------------------------------------

$devPs1 = Join-Path $PSScriptRoot 'dev.ps1'
$devSh = Join-Path $PSScriptRoot 'dev.sh'
if ((Edit-TextFile -Path $devPs1 -Pattern '(?m)^\$usesPostgres = \$false' -Replacement '$usesPostgres = $true') -gt 0) {
    Write-Step 'scripts/dev.ps1 (task dev avvia PostgreSQL)'
}
if ((Edit-TextFile -Path $devSh -Pattern '(?m)^USES_POSTGRES=0' -Replacement 'USES_POSTGRES=1') -gt 0) {
    Write-Step 'scripts/dev.sh (task dev avvia PostgreSQL)'
}

# --- Fatto --------------------------------------------------------------------

Write-Host ''
Write-Host 'Modulo collegato a PostgreSQL.' -ForegroundColor Green
Write-Host ''
if ($needsReset) {
    Write-Host "  Il database '$DbName' nasce da uno script di init, e PostgreSQL li esegue" -ForegroundColor Yellow
    Write-Host '  solo quando il volume e'' vuoto. Una volta sola:' -ForegroundColor Yellow
    Write-Host '    task docker-reset      # ATTENZIONE: cancella i dati gia'' presenti'
    Write-Host ''
}
Write-Host '  task dev          riavvia lo stack: avvia anche PostgreSQL'
Write-Host '  task check        verifica che sia rimasto tutto coerente'
Write-Host ''
Write-Host '  Le tabelle le crea Hibernate con ddl-auto: update. I dati di prova' -ForegroundColor DarkGray
Write-Host '  ora restano fra un riavvio e l''altro: se ti servono puliti,' -ForegroundColor DarkGray
Write-Host '  task docker-reset.' -ForegroundColor DarkGray
Write-Host ''
