<#
.SYNOPSIS
    Controlla che le parti del progetto che devono restare d'accordo lo siano.

.DESCRIPTION
    Non avvia niente e non modifica niente: legge i file e confronta.

    Un modulo vive in sei posti (cartella, <modules> del pom aggregatore, COPY
    nel Dockerfile, blocco in docker-compose.yml, lista dei servizi di dev.ps1
    e di dev.sh) e una porta in quattro. Se ne sfugge uno, l'errore che vedi
    dopo sembra scollegato dalla causa: il modulo non compila, oppure compila
    ma non parte, oppure parte in locale e non in Docker.

    Da lanciare dopo una modifica fatta a mano, e prima della demo.

.PARAMETER ProjectOnly
    Salta i controlli che riguardano la macchina e non il progetto (le porte
    che Windows si e' riservato): serve alle prove automatiche, che verificano
    la coerenza dei file su una copia.

.EXAMPLE
    task check
#>
param([switch]$ProjectOnly)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')
# Serve Test-PortReserved: le porte le sa leggere dev-lib.
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

$problems = @()
function Add-Problem { param([string]$Message) ; $script:problems += $Message }

function Write-Check {
    param([string]$Label, [string[]]$Errors, [string]$OkNote = 'OK')
    if ($Errors.Count -eq 0) {
        Write-Host ("  {0,-26}{1}" -f $Label, $OkNote) -ForegroundColor Green
    } else {
        Write-Host ("  {0,-26}{1} problema/i" -f $Label, $Errors.Count) -ForegroundColor Red
        foreach ($e in $Errors) { Write-Host "      $e" -ForegroundColor Red }
    }
}

Write-Host ''
Write-Host 'CONTROLLO DEL PROGETTO' -ForegroundColor Cyan
Write-Host ''

# --- Moduli -------------------------------------------------------------------

$aggregator = Join-Path $demoDir 'pom.xml'
$declared = @()
foreach ($hit in ([regex]'<module>([^<]+)</module>').Matches((Read-TextFile $aggregator))) {
    $declared += $hit.Groups[1].Value
}
$onDisk = @(Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') } | ForEach-Object { $_.Name })

$errors = @()
foreach ($m in $declared) {
    if (-not (Test-Path (Join-Path $demoDir (Join-Path $m 'pom.xml')))) {
        $errors += "demo/pom.xml dichiara <module>$m</module> ma demo/$m/pom.xml non esiste"
    }
}
foreach ($m in $onDisk) {
    if ($declared -notcontains $m) {
        $errors += "demo/$m ha un pom.xml ma non e' fra i <modules>: Maven non lo compila"
    }
}
foreach ($m in $onDisk) {
    try { [void][xml](Read-TextFile (Join-Path $demoDir (Join-Path $m 'pom.xml'))) }
    catch { $errors += "demo/$m/pom.xml non e' XML valido: $($_.Exception.Message)" }
}
Write-Check -Label 'moduli' -Errors $errors -OkNote "OK ($($declared.Count))"
$problems += $errors

# --- Porte dichiarate dai moduli ---------------------------------------------

# Un modulo e' "avviabile" se ha un application.yml: common-dto non lo e'.
$modulePorts = [ordered]@{}
foreach ($m in $onDisk) {
    $yml = Join-Path $demoDir (Join-Path $m 'src/main/resources/application.yml')
    if (-not (Test-Path $yml)) { continue }
    $hit = [regex]::Match((Read-TextFile $yml), 'SERVER_PORT:(\d+)')
    if ($hit.Success) { $modulePorts[$m] = [int]$hit.Groups[1].Value }
    else { $modulePorts[$m] = 0 }
}

$errors = @()
foreach ($m in $modulePorts.Keys) {
    if ($modulePorts[$m] -eq 0) {
        $errors += "demo/$m/src/main/resources/application.yml non ha 'port: `${SERVER_PORT:N}'"
    }
}
$duplicates = $modulePorts.GetEnumerator() | Where-Object { $_.Value -ne 0 } | Group-Object -Property Value | Where-Object { $_.Count -gt 1 }
foreach ($dup in $duplicates) {
    $errors += "porta $($dup.Name) usata da: $(($dup.Group | ForEach-Object { $_.Key }) -join ', ')"
}
Write-Check -Label 'porte dei moduli' -Errors $errors -OkNote "OK ($($modulePorts.Count) servizi, nessun doppione)"
$problems += $errors

# --- Dockerfile ---------------------------------------------------------------

$dockerfile = Read-TextFile (Join-Path $demoDir 'Dockerfile')
$errors = @()
# Il sorgente puo' entrare tutto insieme (COPY . .) oppure modulo per modulo:
# nel secondo caso ogni modulo deve avere la sua riga, o in Docker mancherebbe.
$copiesEverything = $dockerfile -match '(?m)^COPY \. \.\s*$'
foreach ($m in $declared) {
    if ($dockerfile -notmatch [regex]::Escape("COPY $m/pom.xml")) {
        $errors += "demo/Dockerfile non copia $m/pom.xml: la build in Docker fallira'"
    }
    if (-not $copiesEverything -and $dockerfile -notmatch [regex]::Escape("COPY $m $m")) {
        $errors += "demo/Dockerfile non copia i sorgenti di $m (manca 'COPY $m $m')"
    }
}
Write-Check -Label 'Dockerfile' -Errors $errors
$problems += $errors

# --- Lista dei servizi di dev.ps1 --------------------------------------------

$devPs1Text = Read-TextFile (Join-Path $PSScriptRoot 'dev.ps1')
$uiPortDefault = 0
$hit = [regex]::Match($devPs1Text, '\[int\]\$UiPort\s*=\s*(\d+)')
if ($hit.Success) { $uiPortDefault = [int]$hit.Groups[1].Value }

$devServices = @()
foreach ($m in ([regex]"Name\s*=\s*'([^']+)';\s*Module\s*=\s*'([^']+)';\s*Port\s*=\s*(\`$UiPort|\d+)").Matches($devPs1Text)) {
    $port = if ($m.Groups[3].Value -eq '$UiPort') { $uiPortDefault } else { [int]$m.Groups[3].Value }
    $devServices += [pscustomobject]@{ Name = $m.Groups[1].Value; Module = $m.Groups[2].Value; Port = $port }
}

$errors = @()
if ($devServices.Count -eq 0) {
    $errors += "non riesco a leggere la lista `$services in scripts/dev.ps1"
}
foreach ($svc in $devServices) {
    if ($declared -notcontains $svc.Module) {
        $errors += "dev.ps1 avvia '$($svc.Name)' dal modulo $($svc.Module), che non e' fra i <modules>"
        continue
    }
    if (-not $modulePorts.Contains($svc.Module)) {
        $errors += "dev.ps1 avvia $($svc.Module), che non ha un application.yml"
        continue
    }
    if ($modulePorts[$svc.Module] -ne $svc.Port) {
        $errors += "$($svc.Module): dev.ps1 dice porta $($svc.Port), application.yml dice $($modulePorts[$svc.Module]) (task set-port SERVICE=$($svc.Module) PORT=<porta>)"
    }
}
foreach ($m in $modulePorts.Keys) {
    if (($devServices | Where-Object { $_.Module -eq $m }).Count -eq 0) {
        $errors += "$m e' avviabile ma non e' nella lista di task dev: non partira'"
    }
}
Write-Check -Label 'servizi di task dev' -Errors $errors -OkNote "OK ($($devServices.Count))"
$problems += $errors

# --- dev.sh allineato a dev.ps1 ----------------------------------------------

$devShText = Read-TextFile (Join-Path $PSScriptRoot 'dev.sh')
$uiPortSh = 0
$hit = [regex]::Match($devShText, '(?m)^UI_PORT=(\d+)')
if ($hit.Success) { $uiPortSh = [int]$hit.Groups[1].Value }

$shServices = @()
foreach ($m in ([regex]'"([^:"]+):([^:"]+):([^"]+)"').Matches($devShText)) {
    $raw = $m.Groups[3].Value
    $port = if ($raw -like '*UI_PORT*') { $uiPortSh } else { $raw -as [int] }
    if ($null -eq $port) { continue }
    $shServices += [pscustomobject]@{ Name = $m.Groups[1].Value; Module = $m.Groups[2].Value; Port = $port }
}

$errors = @()
if ($shServices.Count -ne $devServices.Count) {
    $errors += "dev.ps1 elenca $($devServices.Count) servizi, dev.sh $($shServices.Count)"
} else {
    for ($i = 0; $i -lt $devServices.Count; $i++) {
        $a = $devServices[$i]; $b = $shServices[$i]
        if ($a.Name -ne $b.Name -or $a.Module -ne $b.Module -or $a.Port -ne $b.Port) {
            $errors += "riga $($i + 1): dev.ps1 dice $($a.Name):$($a.Module):$($a.Port), dev.sh dice $($b.Name):$($b.Module):$($b.Port)"
        }
    }
}
Write-Check -Label 'dev.sh allineato' -Errors $errors
$problems += $errors

# --- docker-compose -----------------------------------------------------------

$composeLines = @(Split-TextLines (Read-TextFile (Join-Path $demoDir 'docker-compose.yml')))
$errors = @()
foreach ($svc in $devServices) {
    $idx = Find-LineIndex -Lines $composeLines -Pattern ("^\s+MODULE:\s+" + [regex]::Escape($svc.Module) + "\s*$")
    if ($idx -lt 0) {
        $errors += "docker-compose.yml non ha un servizio con MODULE: $($svc.Module)"
        continue
    }
    $end = $idx + 1
    while ($end -lt $composeLines.Count -and $composeLines[$end] -notmatch '^[A-Za-z0-9_-]+:\s*$' -and $composeLines[$end] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $end++ }
    $start = $idx
    while ($start -gt 0 -and $composeLines[$start] -notmatch '^  [A-Za-z0-9_-]+:\s*$') { $start-- }
    $block = ($composeLines[$start..($end - 1)]) -join "`n"

    if ($block -notmatch "SERVER_PORT:\s*$($svc.Port)\b") {
        $errors += "$($svc.Module): in docker-compose.yml SERVER_PORT non e' $($svc.Port)"
    }
    if ($block -notmatch "\bports:") {
        $errors += "$($svc.Module): in docker-compose.yml manca la pubblicazione della porta"
    } elseif ($block -notmatch """$($svc.Port):$($svc.Port)""") {
        $errors += "$($svc.Module): in docker-compose.yml la porta pubblicata non e' $($svc.Port):$($svc.Port)"
    }
}
Write-Check -Label 'docker-compose' -Errors $errors
$problems += $errors

# --- La configurazione degli editor -------------------------------------------
# Un launch.json che elenca servizi spariti manda in errore il tasto Debug, e
# uno che non li elenca non lo fa partire affatto.

$errors = @()
$launchPath = Join-Path $repoRoot '.vscode/launch.json'
if (Test-Path $launchPath) {
    $launchText = Read-TextFile $launchPath
    $launched = @([regex]::Matches($launchText, '"projectName"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    foreach ($svc in $devServices) {
        if ($launched -notcontains $svc.Module) {
            $errors += "$($svc.Module): manca in .vscode/launch.json"
        }
    }
    foreach ($name in $launched) {
        if (-not (Test-Path (Join-Path $demoDir "$name/pom.xml"))) {
            $errors += "${name}: e' in .vscode/launch.json ma il modulo non esiste"
        }
    }
    if ($errors.Count -gt 0) { $errors += 'riallinea con: task ide-sync' }
    Write-Check -Label 'editor (launch.json)' -Errors $errors
} else {
    Write-Host ('  {0,-26}{1}' -f 'editor (launch.json)', 'assente: task ide-sync') -ForegroundColor Yellow
}
$problems += $errors

# --- Porte riservate da Windows ----------------------------------------------

# Windows si riserva interi intervalli di porte (Hyper-V, WSL, l'avvio di
# Docker Desktop): dentro non fa il bind nessuno, ne' un servizio locale ne' un
# container. Nessun processo risulta in ascolto, quindi sembra tutto libero.
$errors = @()
$reserved = @()
if (-not $ProjectOnly) {
    $reserved = @($devServices | Where-Object { Test-PortReserved -Port $_.Port })
}
foreach ($svc in $reserved) {
    $errors += "$($svc.Module): la porta $($svc.Port) e' in un intervallo riservato da Windows, non la puo' usare nessuno"
}
if ($errors.Count -gt 0) {
    $errors += "vedile con: netsh interface ipv4 show excludedportrange protocol=tcp"
    $errors += "spostati con task set-port SERVICE=<modulo> PORT=<porta libera>, oppure libera le riserve da"
    $errors += "terminale amministratore con 'net stop winnat' e 'net start winnat' (chiude Docker)"
}
if ($ProjectOnly) {
    Write-Host ('  {0,-26}{1}' -f 'porte riservate', 'saltato (-ProjectOnly)') -ForegroundColor DarkGray
} else {
    Write-Check -Label 'porte riservate' -Errors $errors -OkNote 'OK (nessuna)'
    $problems += $errors
}

# --- Il compose e' anche YAML valido? ----------------------------------------

# `docker compose config` non ha bisogno del daemon acceso: legge e valida il
# file. Se Docker non c'e', non e' un errore: qui non lo si sta usando.
$errors = @()
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Push-Location $demoDir
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = cmd /c "docker compose config --quiet 2>&1"
        if ($LASTEXITCODE -ne 0) { $errors += "docker-compose.yml non e' valido: $output" }
    } finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    Write-Check -Label 'compose valido' -Errors $errors
    $problems += $errors
} else {
    Write-Host ('  {0,-26}{1}' -f 'compose valido', 'saltato (docker non installato)') -ForegroundColor DarkGray
}

# --- Esito --------------------------------------------------------------------

Write-Host ''
if ($problems.Count -eq 0) {
    Write-Host 'Tutto coerente.' -ForegroundColor Green
    Write-Host ''
    exit 0
}
Write-Host "$($problems.Count) problema/i da sistemare." -ForegroundColor Red
Write-Host ''
exit 1
