<#
.SYNOPSIS
    Ferma lo stack locale avviato con `task dev`.

.DESCRIPTION
    Termina i processi in ascolto sulle porte dello stack e chiude le finestre
    aperte da dev.ps1. A differenza di `task clean-ports` non tocca gli altri
    processi Java eventualmente attivi sulla macchina.
#>

$ErrorActionPreference = 'Stop'

# Porte di default, piu' quelle realmente usate dall'ultimo `task dev`
# (che possono differire se e' stato passato -UiPort).
$ports = @(8761, 8081, 8082, 8083, 8080)
$portFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.dev-logs\dev.ports'
if (Test-Path $portFile) {
    $recorded = Get-Content $portFile | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    $ports = @($ports + $recorded | Sort-Object -Unique)
}

$stopped = 0

foreach ($port in $ports) {
    $pids = @()
    try {
        $pids = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique
    } catch {
        # nessun listener su questa porta
        continue
    }

    foreach ($processId in $pids) {
        $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }

        # Sulle porte dello stack possono essere in ascolto processi che non
        # abbiamo avviato noi (Docker, o un'altra applicazione qualsiasi della
        # macchina): terminiamo solo i processi Java, che sono i nostri servizi.
        if ($proc.ProcessName -ne 'java') {
            if ($proc.ProcessName -like 'com.docker*' -or $proc.ProcessName -eq 'vpnkit') {
                Write-Host "Porta $port pubblicata da Docker ($($proc.ProcessName)): usa 'task docker-down'." -ForegroundColor Yellow
            } else {
                Write-Host "Porta $port occupata da $($proc.ProcessName) (PID $processId), estraneo allo stack: lasciato in esecuzione." -ForegroundColor Yellow
            }
            continue
        }

        Write-Host "Termino $($proc.ProcessName) (PID $processId) sulla porta $port"
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        $stopped++
    }
}

# Chiude le finestre aperte da dev.ps1, riconoscibili dal titolo che imposta.
Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match '^(eureka|product|crm|wms|wms-ui) \(:\d+\)$' } |
    ForEach-Object {
        Write-Host "Chiudo la finestra '$($_.MainWindowTitle)'"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        $stopped++
    }

if ($stopped -eq 0) {
    Write-Host 'Nessun processo dello stack locale in esecuzione.' -ForegroundColor Yellow
} else {
    Write-Host 'Stack locale fermato.' -ForegroundColor Green
}
