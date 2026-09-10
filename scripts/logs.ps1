<#
.SYNOPSIS
    Segue i log dei servizi avviati con `task dev`.

.DESCRIPTION
    Sostituisce le finestre separate: un solo terminale mostra l'output di tutti
    i servizi, ogni riga prefissata dal nome del servizio e di un colore diverso.

    task logs              tutti i servizi
    task logs SERVICE=<nome>            solo quel servizio
    task logs SERVICE=<nome> TAIL=200  parte da piu' indietro nello storico
    task logs -- <a> <b>               piu' servizi insieme

    Ctrl+C per uscire: chiude solo questa vista, i servizi restano in esecuzione.
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Services,

    [int]$Tail = 30
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'dev-lib.ps1')

$logDir = Get-DevLogDir
if (-not (Test-Path $logDir)) {
    Write-Host "Nessun log in $logDir. Avvia prima lo stack con 'task dev'." -ForegroundColor Yellow
    exit 1
}

# Senza argomenti seguiamo i servizi dell'ultimo avvio, nel loro ordine
# (eureka per primo), non tutti i .log che si trovano nella cartella.
if (-not $Services) {
    $serviceFile = Join-Path $logDir 'dev.services'
    if (Test-Path $serviceFile) {
        $Services = @(Get-Content $serviceFile | Where-Object { $_ -ne '' })
    }
}

$files = Get-ChildItem -Path $logDir -Filter '*.log' -ErrorAction SilentlyContinue
if ($Services) {
    $known = @($files | ForEach-Object { $_.BaseName })
    # Un Where-Object non conserverebbe l'ordine richiesto.
    $files = foreach ($name in $Services) {
        if ($known -contains $name) {
            $files | Where-Object { $_.BaseName -eq $name }
        } else {
            Write-Host "Nessun log per '$name'." -ForegroundColor Yellow
        }
    }
}

if (-not $files) {
    Write-Host "Nessun log da seguire. Avvia prima lo stack con 'task dev'." -ForegroundColor Yellow
    exit 1
}

$palette = @('Cyan', 'Green', 'Yellow', 'Magenta', 'Blue', 'White')
$i = 0
$tracked = foreach ($file in $files) {
    [pscustomobject]@{
        Name   = $file.BaseName
        Path   = $file.FullName
        Color  = $palette[$i % $palette.Count]
        Offset = [long]0
    }
    $i++
}

function Write-LogLines {
    param([pscustomobject]$Entry, [string]$Text)

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -eq '') { continue }
        Write-Host ("{0,-8} | " -f $Entry.Name) -ForegroundColor $Entry.Color -NoNewline
        Write-Host $line
    }
}

function Read-NewText {
    <#
        Legge quello che e' stato aggiunto al file dall'ultima lettura.
        Apre in FileShare ReadWrite perche' il servizio lo tiene aperto in
        scrittura, e usa la lunghezza dello stream invece di quella di Get-Item:
        finche' il file resta aperto Windows aggiorna la dimensione nella
        cartella in ritardo, e le righe nuove comparirebbero a scatti.
    #>
    param([pscustomobject]$Entry)

    if (-not (Test-Path -LiteralPath $Entry.Path)) { return $null }

    $stream = [System.IO.File]::Open($Entry.Path, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        # Un nuovo `task dev` ricrea il log da zero: se si e' accorciato ripartiamo.
        if ($stream.Length -lt $Entry.Offset) { $Entry.Offset = 0 }
        if ($stream.Length -le $Entry.Offset) { return $null }

        [void]$stream.Seek($Entry.Offset, [System.IO.SeekOrigin]::Begin)
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd()
        $Entry.Offset = $stream.Position
        return $text
    } finally {
        $stream.Dispose()
    }
}

Write-Host ("Seguo: {0}   (Ctrl+C per uscire)" -f (($tracked | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Cyan
Write-Host ''

function Get-FileLength {
    param([string]$Path)

    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { return $stream.Length } finally { $stream.Dispose() }
}

# Storico iniziale: le ultime righe di ogni log, poi si prosegue in tempo reale.
foreach ($entry in $tracked) {
    # Prima la posizione, poi lo storico: al massimo qualche riga viene mostrata
    # due volte, invece di perdersi quelle scritte nel frattempo.
    $entry.Offset = Get-FileLength -Path $entry.Path
    try {
        $history = Get-Content -LiteralPath $entry.Path -Tail $Tail -ErrorAction Stop
        if ($history) { Write-LogLines -Entry $entry -Text ($history -join "`n") }
    } catch {
        # log bloccato in scrittura proprio ora: lo riprendiamo dal polling
    }
}

while ($true) {
    foreach ($entry in $tracked) {
        $text = Read-NewText -Entry $entry
        if ($text) { Write-LogLines -Entry $entry -Text $text }
    }
    Start-Sleep -Milliseconds 400
}
