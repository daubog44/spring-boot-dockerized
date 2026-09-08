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

function Get-DevServiceMap {
    <#
    .SYNOPSIS
        Mappa porta -> nome del servizio, com'erano all'ultimo `task dev`.
    .DESCRIPTION
        dev.ps1 scrive dev.ports e dev.services nello stesso ordine: leggendoli
        in coppia, `task status` sa come si chiama chi sta su ogni porta senza
        che i nomi vadano ripetuti anche qui.
    #>
    param([string]$LogDir)

    $map = [ordered]@{}
    $portFile = Join-Path $LogDir 'dev.ports'
    $nameFile = Join-Path $LogDir 'dev.services'
    if (-not (Test-Path $portFile) -or -not (Test-Path $nameFile)) { return $map }

    $ports = @(Get-Content $portFile | Where-Object { $_ -match '^\d+$' })
    $names = @(Get-Content $nameFile | Where-Object { $_ -match '\S' })
    for ($i = 0; $i -lt [Math]::Min($ports.Count, $names.Count); $i++) {
        $map[[string]$ports[$i]] = $names[$i].Trim()
    }
    return $map
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

function Get-ReservedPortRanges {
    <#
        Gli intervalli di porte che Windows si e' riservato (Hyper-V, WSL,
        Docker Desktop): nessuno puo' farci il bind e nessun processo risulta
        in ascolto, quindi la porta sembra libera ma non lo e'.
    #>
    $ranges = @()
    try {
        $output = netsh interface ipv4 show excludedportrange protocol=tcp 2>$null
        foreach ($line in $output) {
            if ($line -match '^\s*(\d+)\s+(\d+)') {
                $ranges += [pscustomobject]@{ Start = [int]$Matches[1]; End = [int]$Matches[2] }
            }
        }
    } catch { }
    return $ranges
}

function Test-PortReserved {
    param([int]$Port)
    foreach ($range in (Get-ReservedPortRanges)) {
        if ($Port -ge $range.Start -and $Port -le $range.End) { return $true }
    }
    return $false
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

function Test-ProtectedProcess {
    <#
        Processi che non vanno terminati per liberare una porta: chiuderli fa
        cadere Windows o Docker Desktop, non il nostro stack. Su una di queste
        porte ci finiscono, per esempio, il portproxy di WinNAT o IIS Express,
        che girano dentro svchost.
    #>
    param([pscustomobject]$Listener)

    if ($Listener.IsDocker) { return $true }
    if ($Listener.Id -le 4) { return $true }
    $protected = @(
        'system', 'idle', 'registry', 'memory compression', 'ntoskrnl',
        'svchost', 'services', 'wininit', 'winlogon', 'csrss', 'smss', 'lsass', 'dwm',
        'explorer', 'dockerd', 'containerd'
    )
    return ($protected -contains $Listener.Name.ToLower())
}

function Stop-DevStack {
    <#
    .SYNOPSIS
        Ferma i servizi locali e libera le porte dello stack.
    .DESCRIPTION
        Libera davvero le porte: termina i nostri processi java, spegne i
        container dell'esame se sono loro a tenerle, e chiude le applicazioni
        estranee rimaste in ascolto. Restano intoccati i processi di sistema e
        l'infrastruttura di Docker (vedi Test-ProtectedProcess).
    .PARAMETER Ports
        Porte da liberare. Se omesso usa quelle dell'ultimo avvio piu' i default:
        dev.ps1 passa qui le porte della sua configurazione, cosi' cambiarle in
        un posto solo basta anche per la pulizia.
    .PARAMETER KeepForeign
        Non chiudere le applicazioni estranee: le segnala soltanto.
    #>
    param(
        [string]$LogDir,
        [string]$RepoRoot,
        [int[]]$Ports,
        [switch]$Quiet,
        [switch]$KeepForeign
    )

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

    # 2. Tutto quello che e' rimasto in ascolto sulle porte dello stack: i nostri
    #    java di un avvio precedente di cui non abbiamo piu' i PID, i container
    #    dell'esame, e le applicazioni estranee. L'obiettivo e' che dopo questa
    #    funzione le porte siano libere, senza doverci pensare.
    $dockerHoldsPorts = $false
    $portsToFree = if ($Ports) { @($Ports + (Get-DevPorts -LogDir $LogDir)) | Sort-Object -Unique } else { Get-DevPorts -LogDir $LogDir }
    foreach ($port in $portsToFree) {
        foreach ($listener in (Get-PortListeners -Port $port)) {

            if ($listener.IsOurs) {
                if (-not $Quiet) { Write-Host "  fermo java (PID $($listener.Id)) sulla porta $port" }
                Stop-Process -Id $listener.Id -Force -ErrorAction SilentlyContinue
                $stopped++
                continue
            }

            # I container li fermiamo una volta sola, con docker compose: sono
            # nostri quanto i processi java, ma vanno spenti dal loro gestore.
            if ($listener.IsDocker) { $dockerHoldsPorts = $true; continue }

            if (Test-ProtectedProcess -Listener $listener) {
                if (-not $Quiet) {
                    Write-Host "  porta $port occupata da $($listener.Name) (PID $($listener.Id)): processo di sistema, non lo tocco." -ForegroundColor Yellow
                }
                continue
            }

            if ($KeepForeign) {
                if (-not $Quiet) {
                    Write-Host "  porta $port occupata da $($listener.Name) (PID $($listener.Id)), estraneo allo stack: lasciato in esecuzione." -ForegroundColor Yellow
                }
                continue
            }

            Write-Host "  chiudo $($listener.Name) (PID $($listener.Id)), estraneo allo stack, che teneva la porta $port" -ForegroundColor Yellow
            Stop-Process -Id $listener.Id -Force -ErrorAction SilentlyContinue
            if ($?) { $stopped++ }
        }
    }

    # 3. I container dell'esame. `down` e non `down -v`: i dati del database restano.
    if ($dockerHoldsPorts -and $RepoRoot) {
        if (-not $Quiet) { Write-Host '  fermo i container dell''esame, che tenevano le porte' -ForegroundColor Yellow }
        Push-Location (Join-Path $RepoRoot 'demo')
        # docker compose scrive l'avanzamento su stderr: con ErrorActionPreference
        # a Stop ogni riga diventerebbe un errore terminante, e il conteggio dei
        # processi fermati salterebbe.
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            docker compose down --remove-orphans 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $stopped++
            } else {
                Write-Host '  (docker compose non raggiungibile: container ancora accesi)' -ForegroundColor Yellow
            }
        } finally {
            $ErrorActionPreference = $previousPreference
            Pop-Location
        }
    }

    # Le porte in chiusura restano qualche istante in TIME_WAIT: senza questa
    # pausa un `task dev` subito dopo un `task dev-down` trova ancora occupato.
    if ($stopped -gt 0) { Start-Sleep -Seconds 2 }
    return $stopped
}
