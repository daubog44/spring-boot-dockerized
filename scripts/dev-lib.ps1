<#
.SYNOPSIS
    Funzioni condivise dagli script di sviluppo (dev, dev-down, logs, status).

.DESCRIPTION
    La gestione delle porte e l'arresto dei servizi stanno qui, in un posto solo:
    `dev.ps1` fa pulizia all'avvio con le stesse funzioni che `dev-down.ps1` usa
    all'arresto, quindi i due comandi non possono comportarsi in modo diverso.
#>

# Porte dello stack. Servono anche quando .dev-logs\dev.ports non esiste piu'
# (per esempio dopo un riavvio del PC con dei processi Java rimasti appesi).
$DevDefaultPorts = @(8761, 8081, 8082, 8083, 8080)

function Get-DevLogDir {
    Join-Path (Split-Path -Parent $PSScriptRoot) '.dev-logs'
}

function Get-DevPorts {
    param([string]$LogDir)

    $ports = $DevDefaultPorts
    # L'ultimo avvio puo' aver usato una porta diversa per la UI (-UiPort).
    $portFile = Join-Path $LogDir 'dev.ports'
    if (Test-Path $portFile) {
        $recorded = Get-Content $portFile | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        $ports = @($ports + $recorded)
    }
    $ports | Sort-Object -Unique
}

function Get-PortListenerIds {
    param([int]$Port)
    try {
        Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique
    } catch {
        @()
    }
}

function Get-PortListeners {
    <#
        Tutti i processi in ascolto sulla porta, con l'indirizzo su cui ascoltano.
        Servono tutti: su una stessa porta possono convivere un listener su
        0.0.0.0 (Docker, o un altro servizio) e uno su 127.0.0.1, e su Windows
        e' il secondo a rispondere a http://localhost.
    #>
    param([int]$Port)

    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    } catch {
        return @()
    }

    foreach ($connection in $connections) {
        $proc = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        [pscustomobject]@{
            Address  = $connection.LocalAddress
            Id       = $connection.OwningProcess
            Name     = $proc.ProcessName
            IsOurs   = ($proc.ProcessName -eq 'java')
            IsDocker = ($proc.ProcessName -like 'com.docker*' -or $proc.ProcessName -eq 'vpnkit' -or $proc.ProcessName -eq 'wslrelay')
        }
    }
}

function Get-PortOwner {
    param([int]$Port)
    Get-PortListeners -Port $Port | Select-Object -First 1
}

function Test-CanBind {
    param([System.Net.IPAddress]$Address, [int]$Port)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new($Address, $Port)
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener) { $listener.Stop() }
    }
}

function Get-PortStatus {
    <#
        Esito possibile: free, docker, busy, blocked, loopback-taken.
        Il test di bind da solo non basta: Docker pubblica le porte su IPv6, e
        un bind IPv4 riuscirebbe lasciando comunque http://localhost sul
        container. Prima guardiamo chi e' in ascolto, poi proviamo il bind.
    #>
    param([int]$Port)

    $listeners = @(Get-PortListeners -Port $Port)
    if ($listeners | Where-Object { $_.IsDocker }) { return 'docker' }
    if ($listeners.Count -gt 0) { return 'busy' }

    # Spring Boot fa bind su 0.0.0.0: se questo fallisce il servizio non parte.
    if (-not (Test-CanBind -Address ([System.Net.IPAddress]::Any) -Port $Port)) {
        return 'blocked'
    }
    # Il bind su 0.0.0.0 riesce ma qualcuno tiene 127.0.0.1: su Windows il bind
    # piu' specifico vince, quindi http://localhost:PORT servirebbe l'altro processo.
    if (-not (Test-CanBind -Address ([System.Net.IPAddress]::Loopback) -Port $Port)) {
        return 'loopback-taken'
    }
    return 'free'
}

function Wait-ForPort {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 120,
        # Per PostgreSQL, che gira in un container e non e' un processo java.
        [switch]$AnyProcess
    )

    # Non basta che la porta risponda: un'applicazione estranea in ascolto sulla
    # stessa porta darebbe un falso positivo. Attendiamo un processo java.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($owner in (Get-PortListenerIds -Port $Port)) {
            if ($AnyProcess) { return $true }
            $proc = Get-Process -Id $owner -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -eq 'java') { return $true }
        }
        Start-Sleep -Milliseconds 700
    }
    return $false
}

function Stop-DevStack {
    <#
    .SYNOPSIS
        Ferma i servizi locali e libera le porte dello stack.
    .DESCRIPTION
        Non tocca i processi che non abbiamo avviato noi: sulle porte dello
        stack termina solo i processi java, e per Docker o altre applicazioni
        si limita a segnalare chi occupa la porta.
    #>
    param([string]$LogDir, [switch]$Quiet)

    $stopped = 0
    $pidFile = Join-Path $LogDir 'dev.pids'

    # 1. I processi avviati da dev.ps1, per PID. Ognuno e' un cmd che ha maven
    #    come figlio e la JVM dell'applicazione come nipote: /T chiude l'albero,
    #    altrimenti resterebbero JVM orfane ancora in ascolto.
    if (Test-Path $pidFile) {
        foreach ($line in (Get-Content $pidFile)) {
            if ($line -notmatch '^(\d+)\s+(\S+)') { continue }
            $processId = [int]$Matches[1]
            $name = $Matches[2]
            if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) { continue }
            if (-not $Quiet) { Write-Host "  fermo $name (PID $processId)" }
            cmd /c "taskkill /PID $processId /T /F >nul 2>&1"
            $stopped++
        }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    # 2. Rete di sicurezza: qualunque java rimasto in ascolto sulle porte dello
    #    stack, anche di un avvio precedente di cui non abbiamo piu' i PID.
    foreach ($port in (Get-DevPorts -LogDir $LogDir)) {
        $listeners = @(Get-PortListeners -Port $port)

        foreach ($listener in ($listeners | Where-Object { $_.IsOurs })) {
            if (-not $Quiet) { Write-Host "  fermo java (PID $($listener.Id)) sulla porta $port" }
            Stop-Process -Id $listener.Id -Force -ErrorAction SilentlyContinue
            $stopped++
        }

        if ($Quiet) { continue }

        # Sugli altri non interveniamo: una riga sola per porta, non una per
        # processo, altrimenti Docker (che ne usa piu' d'uno) riempie lo schermo.
        $foreign = @($listeners | Where-Object { -not $_.IsOurs })
        if ($foreign.Count -eq 0) { continue }
        if ($foreign | Where-Object { $_.IsDocker }) {
            Write-Host "  porta $port pubblicata dai container: la libera 'task docker-down'." -ForegroundColor Yellow
        } else {
            $other = $foreign[0]
            Write-Host "  porta $port occupata da $($other.Name) (PID $($other.Id)), estraneo allo stack: lasciato in esecuzione." -ForegroundColor Yellow
        }
    }

    # Le porte in chiusura restano qualche istante in TIME_WAIT: senza questa
    # pausa un `task dev` subito dopo un `task dev-down` trova ancora occupato.
    if ($stopped -gt 0) { Start-Sleep -Seconds 2 }
    return $stopped
}
