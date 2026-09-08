<#
.SYNOPSIS
    Mostra lo stato dello stack: chi occupa le porte, container e registro Eureka.

.DESCRIPTION
    E' il primo comando da lanciare quando qualcosa non risponde: dice subito se
    la porta e' libera, se e' tenuta da un nostro servizio, dai container Docker
    o da un'applicazione estranea (il caso che fa fallire il bind di Tomcat).
#>

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$logDir = Get-DevLogDir

# I nomi arrivano dall'ultimo `task dev`, quindi seguono da soli le porte
# configurate in dev.ps1 (compreso -UiPort). Le chiavi sono stringhe: su un
# dizionario ordinato una chiave numerica verrebbe interpretata come posizione
# nell'elenco invece che come chiave.
$portNames = Get-DevServiceMap -LogDir $logDir

# Ripiego per quando .dev-logs non c'e' ancora (subito dopo un clone).
$fallbackNames = [ordered]@{
    '8761' = 'eureka'
    '5432' = 'postgres'
}
foreach ($port in (Get-DevPorts -LogDir $logDir)) {
    $key = [string]$port
    if ($portNames.Contains($key)) { continue }
    if ($fallbackNames.Contains($key)) { $portNames[$key] = $fallbackNames[$key] } else { $portNames[$key] = '?' }
}

$format = '  {0,-6} {1,-16} {2,-11} {3,-18} {4}'

Write-Host ''
Write-Host 'PORTE' -ForegroundColor Cyan
Write-Host ($format -f 'PORTA', 'SERVIZIO', 'STATO', 'ASCOLTA SU', 'PROCESSO')

$hijacked = @()
foreach ($entry in $portNames.GetEnumerator()) {
    $port = [int]$entry.Key
    $listeners = @(Get-PortListeners -Port $port)

    if ($listeners.Count -eq 0) {
        if (Test-PortReserved -Port $port) {
            # Nessuno in ascolto, ma il bind fallirebbe: la porta e' dentro un
            # intervallo riservato da Windows, e nessun servizio potra' usarla.
            Write-Host ($format -f $port, $entry.Value, 'RISERVATA', 'Windows', 'nessun processo: intervallo riservato') -ForegroundColor Red
        } else {
            Write-Host ($format -f $port, $entry.Value, 'libera', '-', '-') -ForegroundColor DarkGray
        }
        continue
    }

    # Docker pubblica ogni porta con piu' processi e piu' indirizzi: una riga
    # sola, il dettaglio non aggiunge niente. Gli altri li elenchiamo tutti,
    # perche' e' proprio la convivenza di due listener a creare i problemi.
    if ($listeners | Where-Object { $_.IsDocker }) {
        Write-Host ($format -f $port, $entry.Value, 'container', 'docker', 'pubblicata dai container') -ForegroundColor Cyan
    }

    foreach ($group in ($listeners | Where-Object { -not $_.IsDocker } | Group-Object Name, Id)) {
        $listener = $group.Group[0] | Select-Object *
        # Uno stesso processo compare una volta per indirizzo (IPv4, IPv6, loopback).
        $listener.Address = (($group.Group | ForEach-Object { $_.Address } | Sort-Object -Unique) -join ', ')
        $process = "$($listener.Name) (PID $($listener.Id))"
        if ($listener.IsOurs) {
            Write-Host ($format -f $port, $entry.Value, 'in ascolto', $listener.Address, $process) -ForegroundColor Green
        } else {
            Write-Host ($format -f $port, $entry.Value, 'ESTRANEO', $listener.Address, $process) -ForegroundColor Red
            if ($listener.Address -like '*127.0.0.1*') { $hijacked += [pscustomobject]@{ Port = $port; Listener = $listener } }
        }
    }
}

# Il caso che confonde di piu': i servizi girano, ma su localhost risponde un
# altro processo, perche' su Windows il bind su 127.0.0.1 batte quello su 0.0.0.0.
foreach ($item in $hijacked) {
    Write-Host ''
    Write-Host ("  ATTENZIONE: http://localhost:{0} risponde da {1} (PID {2}), non dal tuo servizio." -f $item.Port, $item.Listener.Name, $item.Listener.Id) -ForegroundColor Red
    Write-Host '  Chiudi quel processo, oppure usa un''altra porta: task dev -- -UiPort 9080' -ForegroundColor Yellow
}

# --- Container ----------------------------------------------------------------

Write-Host ''
Write-Host 'CONTAINER' -ForegroundColor Cyan
$containers = docker ps --filter 'name=exam-' --format '  {{.Names}}  {{.Status}}' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '  Docker non raggiungibile.' -ForegroundColor DarkGray
} elseif (-not $containers) {
    Write-Host '  Nessun container dell''esame in esecuzione.' -ForegroundColor DarkGray
} else {
    $containers | ForEach-Object { Write-Host $_ }
}

# --- Registro Eureka ----------------------------------------------------------

Write-Host ''
Write-Host 'REGISTRO EUREKA' -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri 'http://localhost:8761/eureka/apps' -Headers @{ Accept = 'application/json' } -TimeoutSec 3
    $apps = @($response.applications.application)
    if ($apps.Count -eq 0) {
        Write-Host '  Eureka risponde ma nessun servizio e registrato.' -ForegroundColor Yellow
    } else {
        foreach ($app in $apps) {
            $instances = @($app.instance)
            Write-Host ('  {0,-16} {1} istanza/e  ({2})' -f $app.name, $instances.Count, $instances[0].status)
        }
    }
} catch {
    Write-Host '  Eureka non risponde su http://localhost:8761' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  task dev / task dev-down    stack locale'
Write-Host '  task docker-up / docker-down  stack in container'
Write-Host ''
