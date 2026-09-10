<#
.SYNOPSIS
    Prepara la cartella di consegna: i moduli zippati, l'allegato tecnico, le
    istruzioni per eseguire il progetto.

.DESCRIPTION
    Mette in consegna/ tutto quello che va consegnato, e niente di quello che
    non serve:

      moduli/<modulo>.zip        i sorgenti di ogni microservizio, senza target/
      ALLEGATO-TECNICO.md        gia' compilato con moduli, porte, endpoint e
                                 schema del database; restano da scrivere le
                                 parti che solo tu puoi scrivere
      SCHEMA-DATABASE.md         lo schema da solo, comodo da copiare
      ISTRUZIONI-ESECUZIONE.md   come far girare il progetto, con e senza Docker
      docker-compose.yml         + Dockerfile e script di init: bastano a
                                 rimettere in piedi lo stack dai sorgenti
      <COGNOME_NOME>.zip         tutto quanto sopra, in un archivio solo

    Le cartelle target/ restano fuori: sono megabyte di roba ricompilabile.

.PARAMETER Nome
    Nome dell'archivio finale, di solito COGNOME_NOME.

.PARAMETER OutDir
    Dove preparare la consegna (default: consegna/ nella radice del progetto).

.EXAMPLE
    task consegna NOME=ROSSI_MARIO
#>
param(
    [string]$Nome = '',
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
if (-not $Nome) { $Nome = 'CONSEGNA' }
if (-not $OutDir) { $OutDir = Join-Path $repoRoot 'consegna' }

Write-Host ''
Write-Host '==> Preparazione della consegna' -ForegroundColor Cyan
Write-Host ''

# --- Prima di tutto: il progetto sta in piedi? -------------------------------

$check = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'check.ps1') -ProjectOnly 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host $check
    throw "task check non passa: sistema il progetto prima di consegnarlo."
}
Write-Step 'il progetto e'' coerente (task check)'

# --- Un zip che si apre bene ovunque -----------------------------------------

# Compress-Archive di PowerShell 5.1 scrive i percorsi con la barra rovesciata
# e salta le cartelle nascoste: su Linux (o con un altro programma di
# decompressione) ne escono nomi di file assurdi e manca .mvn/, senza il quale
# il wrapper Maven non parte. Ce lo scriviamo noi, file per file.
Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-PortableZip {
    param([string]$SourceDir, [string]$Destination, [string]$Prefix = '')
    if (Test-Path $Destination) { Remove-Item $Destination -Force }
    $archive = [System.IO.Compression.ZipFile]::Open($Destination, 'Create')
    try {
        foreach ($file in (Get-ChildItem -Path $SourceDir -Recurse -File -Force)) {
            $relative = $file.FullName.Substring($SourceDir.Length + 1) -replace '\\', '/'
            if ($Prefix) { $relative = $Prefix + '/' + $relative }
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative)
        }
    } finally {
        $archive.Dispose()
    }
}

# --- La cartella di consegna, da zero ----------------------------------------

if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutDir 'moduli') -Force | Out-Null

# --- Un pacchetto per microservizio, senza roba compilata --------------------

$staging = Join-Path ([System.IO.Path]::GetTempPath()) ('consegna-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$modules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') })
foreach ($module in $modules) {
    $dest = Join-Path $staging $module.Name
    # /XD target: i jar e le classi si ricompilano, non si consegnano.
    $null = robocopy $module.FullName $dest /E /XD target /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "Copia di $($module.Name) fallita (robocopy $LASTEXITCODE)." }
    $zip = Join-Path $OutDir ('moduli/' + $module.Name + '.zip')
    New-PortableZip -SourceDir $dest -Destination $zip -Prefix $module.Name
    $size = [math]::Round((Get-Item $zip).Length / 1KB)
    Write-Step ("moduli/" + $module.Name + ".zip  ($size KB)")
}

# --- Quello che serve a farlo girare -----------------------------------------

foreach ($file in @('docker-compose.yml', 'Dockerfile', '.dockerignore', 'pom.xml', 'mvnw', 'mvnw.cmd')) {
    $source = Join-Path $demoDir $file
    if (Test-Path $source) { Copy-Item $source (Join-Path $OutDir $file) -Force }
}
$mvnDir = Join-Path $demoDir '.mvn'
if (Test-Path $mvnDir) { $null = robocopy $mvnDir (Join-Path $OutDir '.mvn') /E /NFL /NDL /NJH /NJS /NP }
$initDir = Join-Path $demoDir 'postgres-init'
if (Test-Path $initDir) { $null = robocopy $initDir (Join-Path $OutDir 'postgres-init') /E /NFL /NDL /NJH /NJS /NP }
Write-Step 'docker-compose.yml, Dockerfile, pom aggregatore e wrapper Maven'

# --- Lo schema del database ---------------------------------------------------

$schemaFile = Join-Path $OutDir 'SCHEMA-DATABASE.md'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'db-schema.ps1') -OutFile $schemaFile | Out-Null
Write-Step 'SCHEMA-DATABASE.md (ricavato dalle @Entity)'
$schema = Read-TextFile $schemaFile

# --- I servizi, con porte, nomi Eureka ed endpoint ---------------------------

$devPs1Text = Read-TextFile (Join-Path $PSScriptRoot 'dev.ps1')
$uiPortDefault = 0
$hit = [regex]::Match($devPs1Text, '\[int\]\$UiPort\s*=\s*(\d+)')
if ($hit.Success) { $uiPortDefault = [int]$hit.Groups[1].Value }

$services = @()
foreach ($m in ([regex]"Name\s*=\s*'([^']+)';\s*Module\s*=\s*'([^']+)';\s*Port\s*=\s*(\`$UiPort|\d+)").Matches($devPs1Text)) {
    $port = if ($m.Groups[3].Value -eq '$UiPort') { $uiPortDefault } else { [int]$m.Groups[3].Value }
    $moduleName = $m.Groups[2].Value
    $moduleDir = Join-Path $demoDir $moduleName

    $appName = ''
    $yml = Join-Path $moduleDir 'src/main/resources/application.yml'
    if (Test-Path $yml) {
        $nameHit = [regex]::Match((Read-TextFile $yml), '(?m)^\s+name:\s*(\S+)')
        if ($nameHit.Success) { $appName = $nameHit.Groups[1].Value }
    }

    # Gli endpoint: prefisso della classe piu' percorso del metodo.
    $endpoints = @()
    $srcDir = Join-Path $moduleDir 'src/main/java'
    if (Test-Path $srcDir) {
        foreach ($file in (Get-ChildItem -Path $srcDir -Recurse -Filter '*.java')) {
            $text = Read-TextFile $file.FullName
            if ($text -notmatch '@(Rest)?Controller') { continue }
            $base = ''
            $baseHit = [regex]::Match($text, '@RequestMapping\s*\(\s*"([^"]*)"')
            if ($baseHit.Success) { $base = $baseHit.Groups[1].Value }
            foreach ($mapping in ([regex]'@(Get|Post|Put|Delete|Patch)Mapping\s*(?:\(\s*(?:value\s*=\s*)?"([^"]*)"\s*\))?').Matches($text)) {
                $verb = $mapping.Groups[1].Value.ToUpper()
                $path = $mapping.Groups[2].Value
                $full = ($base + $path)
                if (-not $full) { $full = '/' }
                $endpoints += ("$verb $full")
            }
        }
    }

    $services += [pscustomobject]@{
        Name = $m.Groups[1].Value
        Module = $moduleName
        Port = $port
        AppName = $appName
        Endpoints = ($endpoints | Select-Object -Unique)
    }
}

# --- L'allegato tecnico, con dentro quello che si puo' ricavare --------------

$today = Get-Date -Format 'dd/MM/yyyy'
$doc = New-Object System.Collections.Generic.List[string]
function Add-Line { param([string]$Line = '') ; $doc.Add($Line) }

Add-Line '# Allegato tecnico di progetto'
Add-Line ''
Add-Line "Candidato: **$Nome**  "
Add-Line "Data: $today"
Add-Line ''
Add-Line '> Le parti fra parentesi quadre sono le uniche da scrivere a mano: il'
Add-Line '> resto e'' stato ricavato dal progetto.'
Add-Line ''
Add-Line '---'
Add-Line ''
Add-Line '## 1. Analisi del problema e contesto applicativo'
Add-Line ''
Add-Line '[Due o tre paragrafi: cosa chiede la traccia, quali sono gli attori, che'
Add-Line 'cosa fa il sistema nel suo insieme.]'
Add-Line ''
Add-Line '## 2. Architettura della soluzione'
Add-Line ''
Add-Line 'Architettura a microservizi Spring Boot, con service discovery Eureka e'
Add-Line 'chiamate fra servizi via OpenFeign risolte per nome logico. Ogni servizio'
Add-Line 'espone i propri contratti REST tramite OpenAPI/Swagger UI. L''intero stack'
Add-Line 'e'' containerizzato con Docker Compose.'
Add-Line ''
Add-Line '| Modulo | Porta | Nome su Eureka | Ruolo |'
Add-Line '| :--- | :---: | :--- | :--- |'
foreach ($service in $services) {
    $role = if ($service.Module -match 'naming-server') { 'Eureka Naming Server' }
            elseif ($service.Module -match '(^|-)ui$') { 'Interfaccia web (Thymeleaf)' }
            else { 'Microservizio REST' }
    Add-Line ('| `' + $service.Module + '` | ' + $service.Port + ' | `' + $service.AppName + '` | ' + $role + ' |')
}
$hasPostgres = (Read-TextFile (Join-Path $demoDir 'docker-compose.yml')) -match 'image:\s*postgres'
if ($hasPostgres) {
    Add-Line '| `postgres` | 5432 | - | Database relazionale (container) |'
}
Add-Line ''
Add-Line 'Il modulo `common-dto` non e'' un servizio: contiene le classi DTO'
Add-Line 'condivise, cosi'' chi chiama e chi risponde usano lo stesso contratto.'
Add-Line ''
Add-Line '## 3. Schema concettuale e logico della base dati'
Add-Line ''
# Lo schema arriva gia' come documento: qui dentro scala di un livello.
foreach ($line in (Split-TextLines $schema)) {
    if ($line -match '^# ') { continue }
    if ($line -match '^#') { Add-Line ('#' + $line) } else { Add-Line $line }
}
Add-Line ''
Add-Line '## 4. Descrizione dei moduli implementati'
Add-Line ''
foreach ($service in $services) {
    Add-Line ('### `' + $service.Module + '` (porta ' + $service.Port + ')')
    Add-Line ''
    if ($service.Endpoints.Count -gt 0) {
        Add-Line 'Endpoint esposti:'
        Add-Line ''
        foreach ($endpoint in $service.Endpoints) { Add-Line ('- `' + $endpoint + '`') }
        Add-Line ''
        Add-Line ('Contratti OpenAPI: `http://localhost:' + $service.Port + '/swagger-ui.html`')
    } else {
        Add-Line 'Nessun endpoint REST: [descrivi cosa fa questo modulo].'
    }
    Add-Line ''
    Add-Line '[Una o due righe su cosa fa e su come lo fa.]'
    Add-Line ''
}
Add-Line '## 5. Descrizione dell''algoritmo'
Add-Line ''
Add-Line '[Se la traccia chiede un algoritmo (calcolo di una distanza, scelta di'
Add-Line 'un''ubicazione, estrazione casuale...), spiegalo qui a parole e indica la'
Add-Line 'classe e il metodo che lo implementano.]'
Add-Line ''
Add-Line '## 6. Istruzioni per il test della soluzione'
Add-Line ''
Add-Line 'Vedi `ISTRUZIONI-ESECUZIONE.md`, allegato alla consegna.'
Add-Line ''
Add-Line 'In sintesi, con Docker: `docker compose up -d --build` dalla cartella che'
Add-Line 'contiene `docker-compose.yml`, dopo aver scompattato i moduli. Poi:'
Add-Line ''
foreach ($service in $services) {
    if ($service.Module -match 'naming-server') {
        Add-Line ('- dashboard Eureka: `http://localhost:' + $service.Port + '`')
    } elseif ($service.Module -match '(^|-)ui$') {
        Add-Line ('- interfaccia web: `http://localhost:' + $service.Port + '`')
    } else {
        Add-Line ('- Swagger di `' + $service.Module + '`: `http://localhost:' + $service.Port + '/swagger-ui.html`')
    }
}
Add-Line ''

Write-TextFile -Path (Join-Path $OutDir 'ALLEGATO-TECNICO.md') -Text ($doc -join [Environment]::NewLine)
Write-Step 'ALLEGATO-TECNICO.md (moduli, porte, endpoint e schema gia'' dentro)'

# --- Istruzioni per chi la esegue --------------------------------------------

$run = New-Object System.Collections.Generic.List[string]
function Add-Run { param([string]$Line = '') ; $run.Add($Line) }

Add-Run '# Come eseguire il progetto'
Add-Run ''
Add-Run 'Nella cartella trovi:'
Add-Run ''
Add-Run '- `moduli/*.zip` - i sorgenti di ogni microservizio (senza le cartelle `target/`);'
Add-Run '- `docker-compose.yml`, `Dockerfile`, `pom.xml` e il wrapper Maven - l''infrastruttura;'
Add-Run '- `ALLEGATO-TECNICO.md` e `SCHEMA-DATABASE.md` - la documentazione.'
Add-Run ''
Add-Run '## 1. Ricostruire il progetto'
Add-Run ''
Add-Run 'Scompatta ogni archivio di `moduli/` **nella stessa cartella** dove si'
Add-Run 'trovano `pom.xml` e `docker-compose.yml`. Il risultato:'
Add-Run ''
Add-Run '```'
Add-Run 'progetto/'
Add-Run '+-- pom.xml'
Add-Run '+-- mvnw, mvnw.cmd, .mvn/'
Add-Run '+-- Dockerfile'
Add-Run '+-- docker-compose.yml'
foreach ($module in $modules) { Add-Run ('+-- ' + $module.Name + '/') }
Add-Run '```'
Add-Run ''
Add-Run '## 2. Con Docker (consigliato)'
Add-Run ''
Add-Run '```bash'
Add-Run 'docker compose up -d --build'
Add-Run '```'
Add-Run ''
Add-Run 'La prima build compila tutti i moduli e prepara un''immagine per servizio;'
Add-Run 'Eureka parte per primo e gli altri lo aspettano (healthcheck).'
Add-Run ''
Add-Run 'Per fermare tutto: `docker compose down` (i dati del database restano),'
Add-Run 'oppure `docker compose down -v` per cancellare anche il volume.'
Add-Run ''
Add-Run '## 3. Senza Docker'
Add-Run ''
Add-Run '```bash'
Add-Run './mvnw clean package -Dmaven.test.skip=true'
Add-Run '```'
Add-Run ''
Add-Run 'Poi, in terminali separati e **partendo da Eureka**:'
Add-Run ''
Add-Run '```bash'
foreach ($service in $services) {
    Add-Run ('./mvnw -pl ' + $service.Module + ' spring-boot:run')
}
Add-Run '```'
Add-Run ''
if ($hasPostgres) {
    Add-Run 'Se i servizi usano PostgreSQL, avvialo prima: `docker compose up -d postgres`.'
    Add-Run ''
}
Add-Run '## 4. Indirizzi'
Add-Run ''
Add-Run '| Cosa | Indirizzo |'
Add-Run '| :--- | :--- |'
foreach ($service in $services) {
    if ($service.Module -match 'naming-server') {
        Add-Run ('| Dashboard Eureka | `http://localhost:' + $service.Port + '` |')
    } elseif ($service.Module -match '(^|-)ui$') {
        Add-Run ('| Interfaccia web | `http://localhost:' + $service.Port + '` |')
    } else {
        Add-Run ('| Swagger `' + $service.Module + '` | `http://localhost:' + $service.Port + '/swagger-ui.html` |')
    }
}
if ($hasPostgres) { Add-Run '| PostgreSQL | `localhost:5432` |' }
Add-Run ''
Add-Run 'I servizi impiegano 10-15 secondi a registrarsi su Eureka: le prime'
Add-Run 'chiamate fra servizi, subito dopo l''avvio, possono fallire.'
Add-Run ''

Write-TextFile -Path (Join-Path $OutDir 'ISTRUZIONI-ESECUZIONE.md') -Text ($run -join [Environment]::NewLine)
Write-Step 'ISTRUZIONI-ESECUZIONE.md'

# --- L'archivio unico ---------------------------------------------------------

# L'archivio lo componiamo a mano, file per file, per due motivi:
# Compress-Archive salta le cartelle nascoste (e senza .mvn/ il wrapper Maven
# non parte su un'altra macchina), e CreateFromDirectory scrive i percorsi con
# le barre rovesciate, che su Linux diventano nomi di file assurdi.
$finalZip = Join-Path $repoRoot ($Nome + '.zip')
New-PortableZip -SourceDir $OutDir -Destination $finalZip
Move-Item $finalZip (Join-Path $OutDir ($Nome + '.zip')) -Force
$finalZip = Join-Path $OutDir ($Nome + '.zip')
Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue

$totalKB = [math]::Round((Get-Item $finalZip).Length / 1KB)
Write-Host ''
Write-Host "Consegna pronta in $OutDir" -ForegroundColor Green
Write-Host ''
Write-Host ("  {0}.zip   {1} KB   <- questo e' l'archivio da consegnare" -f $Nome, $totalKB)
Write-Host ''
Write-Host '  Prima di consegnare, apri ALLEGATO-TECNICO.md e riempi le parti fra' -ForegroundColor Yellow
Write-Host '  parentesi quadre: analisi, algoritmo e descrizione dei moduli.' -ForegroundColor Yellow
Write-Host ''
