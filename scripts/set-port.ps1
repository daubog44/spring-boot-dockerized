<#
.SYNOPSIS
    Sposta un modulo su un'altra porta, in tutti i posti in cui quella porta e' scritta.

.DESCRIPTION
    Una porta vive in quattro file: l'application.yml del modulo (il valore di
    ripiego di SERVER_PORT), docker-compose.yml (la variabile d'ambiente e la
    pubblicazione), e la lista dei servizi di dev.ps1 e dev.sh. Cambiarne tre su
    quattro da' il caso peggiore: in locale funziona e in Docker no, o viceversa.

    Il codice Java non contiene porte: i servizi si chiamano per nome via Eureka
    e Feign, quindi spostare una porta non rompe nessuna chiamata.

    Caso speciale: spostando naming-server si aggiorna anche il defaultZone di
    Eureka in tutti i moduli e nei container.

.PARAMETER Module
    Cartella del modulo sotto demo/, es. wms-service.

.PARAMETER Port
    Nuova porta.

.EXAMPLE
    task set-port SERVICE=wms-ui PORT=9080
    task set-port SERVICE=wms-service PORT=8090
#>
param(
    [string]$Module = '',
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
if (-not $Module -or $Port -eq 0) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task set-port SERVICE=<modulo> PORT=<porta>"
    }

    $allModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName 'pom.xml')
    } | Select-Object -ExpandProperty Name)

    Write-Host ''
    Write-Host 'CAMBIO PORTA GUIDATA' -ForegroundColor Cyan
    if (-not $Module) {
        Write-Host "Seleziona il modulo di cui cambiare la porta:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $allModules.Count; $i++) {
            $mDir = Join-Path $demoDir $allModules[$i]
            $p = Get-ModulePort -ModuleDir $mDir
            $currPort = if ($p -gt 0) { "$p" } else { '?' }
            Write-Host "  $($i + 1)) $($allModules[$i]) (porta attuale: $currPort)"
        }
        $idx = Read-Host "  [1] >"
        $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
        $Module = $allModules[$idxNum - 1]
    }

    if ($Port -eq 0) {
        $pInput = (Read-Host "  Nuova porta per $Module").Trim()
        if ($pInput -match '^\d+$') {
            $Port = [int]$pInput
        } else {
            throw "Uso: task set-port SERVICE=<modulo> PORT=<porta>"
        }
    }
}
$moduleDir = Join-Path $demoDir $Module
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    $available = (Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name }) -join ', '
    throw "Modulo '$Module' non trovato. Moduli disponibili: $available"
}

$cfgPath = Get-ModuleConfigFile -ModuleDir $moduleDir
if (-not $cfgPath) { throw "Non trovo file di configurazione (application.yml, application.yaml o application.properties) in $moduleDir." }

$oldPort = Get-ModulePort -ModuleDir $moduleDir
if ($oldPort -eq 0) { throw "In $cfgPath non c'e' una porta riconosciuta (es. 'port: `${SERVER_PORT:N}'): impostala prima nel file." }

if ($oldPort -eq $Port) {
    Write-Host "$Module e' gia' sulla porta ${Port}: niente da fare."
    exit 0
}

# La porta non deve gia' appartenere a un altro modulo, altrimenti `task dev`
# avvierebbe due servizi sulla stessa porta e il secondo morirebbe.
foreach ($dir in (Get-ChildItem -Path $demoDir -Directory)) {
    if ($dir.Name -eq $Module) { continue }
    $otherPort = Get-ModulePort -ModuleDir $dir.FullName
    if ($otherPort -eq $Port) {
        throw "La porta $Port e' gia' di $($dir.Name). Spostati su un'altra."
    }
}

$isEureka = ($oldPort -eq 8761)

Write-Host ''
Write-Host "==> $Module : $oldPort -> $Port" -ForegroundColor Cyan
Write-Host ''

# --- 1. file di configurazione del modulo --------------------------------------

$cfgText = Read-TextFile $cfgPath
if ($cfgText -match "SERVER_PORT:$oldPort") {
    $cfgText = [regex]::Replace($cfgText, "SERVER_PORT:$oldPort", "SERVER_PORT:$Port")
} elseif ($cfgText -match '(?m)^\s*port:\s*' + $oldPort) {
    $cfgText = [regex]::Replace($cfgText, '(?m)^\s*port:\s*' + $oldPort, "  port: `${SERVER_PORT:$Port}")
} elseif ($cfgText -match '(?m)^\s*server\.port\s*[:=]\s*' + $oldPort) {
    if ($cfgPath.EndsWith('.properties')) {
        $cfgText = [regex]::Replace($cfgText, '(?m)^\s*server\.port\s*=\s*' + $oldPort, "server.port=`${SERVER_PORT:$Port}")
    } else {
        $cfgText = [regex]::Replace($cfgText, '(?m)^\s*server\.port\s*:\s*' + $oldPort, "server.port: `${SERVER_PORT:$Port}")
    }
} else {
    $cfgText = [regex]::Replace($cfgText, "\b$oldPort\b", "$Port")
}
Write-TextFile -Path $cfgPath -Text $cfgText
$cfgRel = $cfgPath.Substring($demoDir.Length + 1) -replace '\\', '/'
Write-Step "demo/$cfgRel"

# --- 2. docker-compose.yml ----------------------------------------------------

# Il nome del servizio nel compose non coincide sempre con quello del modulo
# (naming-server sta sotto eureka-server): il blocco si trova dal MODULE:.
$compose = Join-Path $demoDir 'docker-compose.yml'
$lines = @(Split-TextLines (Read-TextFile $compose))
$moduleLine = Find-LineIndex -Lines $lines -Pattern ("^\s+MODULE:\s+" + [regex]::Escape($Module) + "\s*$")
if ($moduleLine -lt 0) {
    Write-Host "  docker-compose.yml: nessun servizio con MODULE: $Module, salto." -ForegroundColor Yellow
} else {
    $start = $moduleLine
    while ($start -gt 0 -and $lines[$start] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $start-- }
    $end = $moduleLine + 1
    while ($end -lt $lines.Count -and $lines[$end] -notmatch '^[A-Za-z0-9_-]+:\s*$' -and $lines[$end] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $end++ }
    for ($i = $start; $i -lt $end; $i++) {
        $lines[$i] = $lines[$i] -replace "SERVER_PORT:\s*$oldPort\s*$", "SERVER_PORT: $Port"
        $lines[$i] = $lines[$i] -replace "^(\s*-\s*)""$oldPort`:$oldPort""", "`$1""${Port}:${Port}"""
        if ($isEureka) {
            $lines[$i] = $lines[$i] -replace "localhost:$oldPort", "localhost:$Port"
        }
    }
    $text = Read-TextFile $compose
    Write-TextFile -Path $compose -Text ($lines -join (Get-TextEol $text))
    Write-Step 'demo/docker-compose.yml'
}

# --- 3. Lista dei servizi di task dev ----------------------------------------

$devPs1 = Join-Path $PSScriptRoot 'dev.ps1'
$devSh = Join-Path $PSScriptRoot 'dev.sh'

# La UI usa $UiPort/-UiPort, che resta comodo per uno spostamento al volo: qui
# cambiamo il valore predefinito, cosi' `task dev` senza argomenti usa il nuovo.
$devText = Read-TextFile $devPs1
$devLine = [regex]::Match($devText, "(?m)^.*Module\s*=\s*'" + [regex]::Escape($Module) + "'.*$")
if (-not $devLine.Success) {
    Write-Host "  scripts/dev.ps1: $Module non e' nella lista dei servizi, salto." -ForegroundColor Yellow
} elseif ($devLine.Value -match 'Port\s*=\s*\$UiPort') {
    [void](Edit-TextFile -Path $devPs1 -Pattern '(\[int\]\$UiPort\s*=\s*)\d+' -Replacement "`${1}$Port")
    [void](Edit-TextFile -Path $devSh -Pattern '(?m)^(UI_PORT=)\d+' -Replacement "`${1}$Port")
    Write-Step "scripts/dev.ps1 e dev.sh (valore predefinito di -UiPort)"
} else {
    $updated = $devLine.Value -replace 'Port\s*=\s*\d+', "Port = $Port"
    Write-TextFile -Path $devPs1 -Text ($devText.Remove($devLine.Index, $devLine.Length).Insert($devLine.Index, $updated))
    Write-Step 'scripts/dev.ps1'

    $shText = Read-TextFile $devSh
    $shPattern = '"([A-Za-z0-9_-]+):' + [regex]::Escape($Module) + ':[^"]+"'
    if ($shText -match $shPattern) {
        $shShort = $Matches[1]
        Write-TextFile -Path $devSh -Text ([regex]::Replace($shText, $shPattern, """${shShort}:${Module}:${Port}"""))
        Write-Step 'scripts/dev.sh'
    } else {
        Write-Host "  scripts/dev.sh: $Module non e' nella lista dei servizi, salto." -ForegroundColor Yellow
    }
}

# --- 4. Se abbiamo spostato Eureka, tutti devono saperlo ----------------------

if ($isEureka) {
    Write-Host ''
    Write-Host '  Eureka si e'' spostato: aggiorno chi lo cerca.' -ForegroundColor Cyan
    foreach ($dir in (Get-ChildItem -Path $demoDir -Directory)) {
        $cfg = Get-ModuleConfigFile -ModuleDir $dir.FullName
        if (-not $cfg) { continue }
        if ((Edit-TextFile -Path $cfg -Pattern "localhost:$oldPort" -Replacement "localhost:$Port") -gt 0) {
            $rel = $cfg.Substring($demoDir.Length + 1) -replace '\\', '/'
            Write-Step "demo/$rel"
        }
    }
    if ((Edit-TextFile -Path $compose -Pattern "eureka-server:$oldPort" -Replacement "eureka-server:$Port") -gt 0) {
        Write-Step 'demo/docker-compose.yml (EUREKA_SERVER_URL dei container)'
    }
    foreach ($script in @('status.ps1', 'status.sh', 'dev-lib.ps1', 'dev-lib.sh')) {
        $path = Join-Path $PSScriptRoot $script
        if ((Edit-TextFile -Path $path -Pattern "\b$oldPort\b" -Replacement "$Port") -gt 0) {
            Write-Step "scripts/$script"
        }
    }
}

# --- Gli editor ---------------------------------------------------------------
# Nel launch.json la porta compare nel nome della configurazione.

& (Join-Path $PSScriptRoot 'ide-sync.ps1') | Out-Null
Write-Step 'configurazione di VS Code e Zed riallineata'

# --- 5. Cosa resta da guardare a mano ----------------------------------------

# Collaudo e documentazione hanno indirizzi scritti per esteso: non li tocchiamo
# a colpi di regex, ma e' giusto sapere dove sono.
$leftovers = @()
foreach ($file in (Get-ChildItem -Path $repoRoot -Recurse -File -Include '*.ps1', '*.sh', '*.md', '*.yml', '*.yaml' -ErrorAction SilentlyContinue)) {
    if ($file.FullName -match '\\(\.git|\.dev-logs|target|node_modules|\.task)\\') { continue }
    if ($file.FullName -eq $compose) { continue }
    if ($file.DirectoryName -eq $PSScriptRoot -and $file.Name -in @('dev.ps1', 'dev.sh', 'status.ps1', 'status.sh', 'dev-lib.ps1', 'dev-lib.sh', 'scaffold-lib.ps1', 'new-service.ps1', 'new-service.sh', 'add-dep.ps1', 'add-dep.sh', 'set-port.ps1', 'set-port.sh')) { continue }
    $hits = Select-String -Path $file.FullName -Pattern "\b$oldPort\b" -ErrorAction SilentlyContinue
    foreach ($hit in $hits) {
        $leftovers += ("    {0}:{1}" -f $file.FullName.Substring($repoRoot.Length + 1), $hit.LineNumber)
    }
}

Write-Host ''
Write-Host 'Porta cambiata.' -ForegroundColor Green
if ($leftovers.Count -gt 0) {
    Write-Host ''
    Write-Host "  La porta $oldPort compare ancora qui (collaudo, documentazione): guardaci tu." -ForegroundColor Yellow
    $leftovers | Select-Object -Unique | ForEach-Object { Write-Host $_ }
}
Write-Host ''
Write-Host '  task dev          riavvia lo stack sulle porte nuove'
Write-Host ''
