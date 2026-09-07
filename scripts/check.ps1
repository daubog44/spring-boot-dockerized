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

.EXAMPLE
    task check
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

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
foreach ($m in $declared) {
    if ($dockerfile -notmatch [regex]::Escape("COPY $m/pom.xml")) {
        $errors += "demo/Dockerfile non copia $m/pom.xml: la build in Docker fallira'"
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
