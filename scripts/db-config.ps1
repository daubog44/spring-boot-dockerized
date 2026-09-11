<#
.SYNOPSIS
    Cambia nome, utente, password o porta del PostgreSQL del progetto, e
    aggiorna tutti i moduli che ci sono collegati.

.DESCRIPTION
    Le credenziali del database stanno scritte in parecchi posti che devono
    restare d'accordo fra loro:

      - docker-compose.yml: POSTGRES_DB / POSTGRES_USER / POSTGRES_PASSWORD del
        container, la sua healthcheck (pg_isready -U utente -d database) e la
        porta pubblicata sulla macchina;
      - docker-compose.yml, di nuovo: le variabili <PREFISSO>_DB_* di ogni
        modulo collegato, dove il database si chiama "postgres";
      - src/main/resources/application.yml di ogni modulo: gli stessi valori,
        ma come default per quando lo avvii in locale (li' il database si
        chiama "localhost");
      - demo/postgres-init/*.sql: le GRANT sui database dedicati.

    Questo comando li cambia tutti insieme. Quello che non passi resta com'e'.

    ATTENZIONE: il container PostgreSQL crea utente e database la prima volta
    che parte, e poi non li tocca piu'. Dopo aver cambiato nome, utente o
    password serve `task docker-reset` (che cancella i dati) perche' il
    container riparta con i valori nuovi.

.PARAMETER DbName
    Nome del database condiviso (default del compose: esame).

.PARAMETER User
    Utente del database.

.PARAMETER Password
    Password dell'utente.

.PARAMETER Port
    Porta pubblicata sulla macchina (dentro Docker resta sempre 5432).

.EXAMPLE
    task db-config
    task db-config DBNAME=magazzino USER=wms PASSWORD=wms123
    task db-config PORT=5433
#>
param(
    [string]$DbName = '',
    [string]$User = '',
    [string]$Password = '',
    [string]$Port = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$compose = Join-Path $demoDir 'docker-compose.yml'

if (-not (Test-Path $compose)) { throw "Non trovo $compose." }
$composeText = Read-TextFile $compose
if ($composeText -notmatch '(?m)^\s+POSTGRES_DB:') {
    throw "In docker-compose.yml non c'e' un servizio postgres."
}

# --- Come sta adesso ----------------------------------------------------------

$oldDb = [regex]::Match($composeText, '(?m)^\s+POSTGRES_DB:\s*(\S+)').Groups[1].Value
$oldUser = [regex]::Match($composeText, '(?m)^\s+POSTGRES_USER:\s*(\S+)').Groups[1].Value
$oldPassword = [regex]::Match($composeText, '(?m)^\s+POSTGRES_PASSWORD:\s*(\S+)').Groups[1].Value
$portHit = [regex]::Match($composeText, '(?m)^\s+-\s*"(\d+):5432"')
$oldPort = if ($portHit.Success) { $portHit.Groups[1].Value } else { '5432' }

# Se non passi niente, il comando racconta com'e' configurato e si ferma: e'
# il modo piu' veloce per ricordarsi la password durante la demo.
if (-not $DbName -and -not $User -and -not $Password -and -not $Port) {
    Write-Host ''
    Write-Host '==> Database del progetto' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  database   $oldDb"
    Write-Host "  utente     $oldUser"
    Write-Host "  password   $oldPassword"
    Write-Host "  porta      $oldPort  (dentro Docker sempre 5432)"
    Write-Host ''
    $connected = @()
    foreach ($dir in (Get-ChildItem -Path $demoDir -Directory)) {
        $yml = Join-Path $dir.FullName 'src/main/resources/application.yml'
        if ((Test-Path $yml) -and (Read-TextFile $yml) -match 'jdbc:postgresql') { $connected += $dir.Name }
    }
    if ($connected.Count -gt 0) {
        Write-Host ('  moduli collegati: ' + ($connected -join ', '))
    } else {
        Write-Host '  Nessun modulo collegato: task use-postgres SERVICE=<modulo>'
    }
    Write-Host ''
    Write-Host '  Per cambiare qualcosa:'
    Write-Host '    task db-config DBNAME=magazzino USER=wms PASSWORD=wms123'
    Write-Host '    task db-config PORT=5433'
    Write-Host ''
    Write-Host "  psql: docker compose exec postgres psql -U $oldUser -d $oldDb   (dalla cartella $(Split-Path -Leaf $demoDir))" -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}

$newDb = if ($DbName) { $DbName } else { $oldDb }
$newUser = if ($User) { $User } else { $oldUser }
$newPassword = if ($Password) { $Password } else { $oldPassword }
$newPort = if ($Port) { $Port } else { $oldPort }

foreach ($pair in @(@('DBNAME', $newDb), @('USER', $newUser), @('PASSWORD', $newPassword))) {
    if ($pair[1] -notmatch '^[A-Za-z0-9_]+$') {
        throw ("Valore non valido per " + $pair[0] + ": '" + $pair[1] + "'. Usa lettere, numeri e underscore (PostgreSQL non ama il resto).")
    }
}
if ($newPort -notmatch '^\d+$') { throw "PORT deve essere un numero." }

Write-Host ''
Write-Host '==> Configurazione del database' -ForegroundColor Cyan
Write-Host ''
if ($newDb -ne $oldDb) { Write-Host "  database   $oldDb -> $newDb" }
if ($newUser -ne $oldUser) { Write-Host "  utente     $oldUser -> $newUser" }
if ($newPassword -ne $oldPassword) { Write-Host "  password   $oldPassword -> $newPassword" }
if ($newPort -ne $oldPort) { Write-Host "  porta      $oldPort -> $newPort" }
Write-Host ''

# --- 1. Il container ----------------------------------------------------------

[void](Edit-TextFile -Path $compose -Pattern '(?m)^(\s+POSTGRES_DB:\s*)\S+' -Replacement ('${1}' + $newDb))
[void](Edit-TextFile -Path $compose -Pattern '(?m)^(\s+POSTGRES_USER:\s*)\S+' -Replacement ('${1}' + $newUser))
[void](Edit-TextFile -Path $compose -Pattern '(?m)^(\s+POSTGRES_PASSWORD:\s*)\S+' -Replacement ('${1}' + $newPassword))
# La healthcheck interroga il database con quelle stesse credenziali: se resta
# indietro, i servizi che aspettano "service_healthy" non partono piu'.
[void](Edit-TextFile -Path $compose -Pattern 'pg_isready -U \S+ -d \S+?(?=")' -Replacement ("pg_isready -U $newUser -d $newDb"))
[void](Edit-TextFile -Path $compose -Pattern '(?m)^(\s+-\s*")\d+(:5432")' -Replacement ('${1}' + $newPort + '${2}'))
Write-Step 'demo/docker-compose.yml (container postgres)'

# --- 2. Le variabili dei moduli nel compose ----------------------------------
# Dentro Docker la porta e' sempre 5432: la porta pubblicata riguarda solo chi
# si collega dalla macchina.

$changed = (Edit-TextFile -Path $compose -Pattern '(?m)^(\s+\w+_DB_USERNAME:\s*)\S+' -Replacement ('${1}' + $newUser))
$changed += (Edit-TextFile -Path $compose -Pattern '(?m)^(\s+\w+_DB_PASSWORD:\s*)\S+' -Replacement ('${1}' + $newPassword))
if ($newDb -ne $oldDb) {
    # Solo il database condiviso: quelli dedicati (task use-postgres DBNAME=...)
    # restano com'erano.
    $changed += (Edit-TextFile -Path $compose -Pattern ('(?m)^(\s+\w+_DB_URL:\s*jdbc:postgresql://postgres:5432/)' + [regex]::Escape($oldDb) + '\s*$') -Replacement ('${1}' + $newDb))
}
if ($changed -gt 0) { Write-Step 'demo/docker-compose.yml (variabili dei moduli)' }

# --- 3. application.yml di ogni modulo ---------------------------------------

$touched = @()
foreach ($dir in (Get-ChildItem -Path $demoDir -Directory)) {
    $ymlPath = Join-Path $dir.FullName 'src/main/resources/application.yml'
    if (-not (Test-Path $ymlPath)) { continue }
    if ((Read-TextFile $ymlPath) -notmatch 'jdbc:postgresql') { continue }

    $n = (Edit-TextFile -Path $ymlPath -Pattern '(?m)(_DB_USERNAME:)[^}]*(\})' -Replacement ('${1}' + $newUser + '${2}'))
    $n += (Edit-TextFile -Path $ymlPath -Pattern '(?m)(_DB_PASSWORD:)[^}]*(\})' -Replacement ('${1}' + $newPassword + '${2}'))
    $n += (Edit-TextFile -Path $ymlPath -Pattern '(?m)(jdbc:postgresql://localhost:)\d+(/)' -Replacement ('${1}' + $newPort + '${2}'))
    if ($newDb -ne $oldDb) {
        $n += (Edit-TextFile -Path $ymlPath -Pattern ('(jdbc:postgresql://localhost:\d+/)' + [regex]::Escape($oldDb) + '(\})') -Replacement ('${1}' + $newDb + '${2}'))
    }
    if ($n -gt 0) {
        Write-Step ('demo/' + $dir.Name + '/src/main/resources/application.yml')
        $touched += $dir.Name
    }
}

# --- 4. Gli script di init dei database dedicati -----------------------------

$initDir = Join-Path $demoDir 'postgres-init'
if (Test-Path $initDir) {
    foreach ($file in (Get-ChildItem -Path $initDir -Filter '*.sql')) {
        if ((Edit-TextFile -Path $file.FullName -Pattern ('(TO\s+)' + [regex]::Escape($oldUser) + '\s*;') -Replacement ('${1}' + $newUser + ';')) -gt 0) {
            Write-Step ('demo/postgres-init/' + $file.Name)
        }
    }
}

# --- Fatto --------------------------------------------------------------------

Write-Host ''
Write-Host 'Configurazione aggiornata.' -ForegroundColor Green
Write-Host ''
if ($touched.Count -eq 0) {
    Write-Host '  Nessun modulo era collegato al database: quando lo colleghi' -ForegroundColor DarkGray
    Write-Host '  (task use-postgres SERVICE=<modulo>) prendera'' questi valori.' -ForegroundColor DarkGray
    Write-Host ''
}
if ($newDb -ne $oldDb -or $newUser -ne $oldUser -or $newPassword -ne $oldPassword) {
    Write-Host '  PostgreSQL crea utente e database solo al primo avvio, su volume' -ForegroundColor Yellow
    Write-Host '  vuoto. Perche'' i valori nuovi valgano davvero serve:' -ForegroundColor Yellow
    Write-Host '    task docker-reset      # ATTENZIONE: cancella i dati gia'' presenti'
    Write-Host ''
}
Write-Host '  task check        verifica che sia rimasto tutto coerente'
Write-Host '  task dev          riavvia lo stack in locale'
Write-Host ''
