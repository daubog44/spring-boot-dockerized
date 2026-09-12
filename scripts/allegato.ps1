<#
.SYNOPSIS
    Genera o aggiorna allegato.md e compila l'anteprima di ALLEGATO-TECNICO.md e SCHEMA-DATABASE.md.

.DESCRIPTION
    Consente di predisporre e verificare l'Allegato Tecnico durante lo svolgimento
    della prova, senza attendere la consegna finale:
      1. Genera o sincronizza allegato.md con tutti i microservizi rilevati in demo/
      2. Compila ALLEGATO-TECNICO.md integrando la tabella delle porte, i contratti REST,
         lo schema concettuale/logico del DB e i testi scritti dal candidato
      3. Controlla e segnala le sezioni ancora da compilare (placeholder fra quadre)

.PARAMETER Nome
    Nome e cognome del candidato da inserire nell'intestazione del documento.

.PARAMETER OutDir
    Cartella di output per ALLEGATO-TECNICO.md (default: radice del repository).

.EXAMPLE
    task allegato
    task allegato NOME="Mario Rossi"
#>
param(
    [string]$Nome = 'CANDIDATO',
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$devPs1 = Join-Path $PSScriptRoot 'dev.ps1'
$allegatoFile = Join-Path $repoRoot 'allegato.md'

if (-not $OutDir) { $OutDir = $repoRoot }

Write-Host ''
Write-Host '==> Generazione e verifica Allegato Tecnico' -ForegroundColor Cyan

# --- 1. Rilevazione Moduli e Servizi -----------------------------------------

$services = @()
$textDev = Read-TextFile $devPs1
$uiPortDefault = 0
$hitUi = [regex]::Match($textDev, '\[int\]\$UiPort\s*=\s*(\d+)')
if ($hitUi.Success) { $uiPortDefault = [int]$hitUi.Groups[1].Value }

foreach ($match in [regex]::Matches($textDev, "Name\s*=\s*'([^']+)';\s*Module\s*=\s*'([^']+)';\s*Port\s*=\s*(\`$UiPort|\d+)")) {
    $mName = $match.Groups[2].Value
    $mDir = Join-Path $demoDir $mName
    if (-not (Test-Path $mDir)) { continue }

    $port = if ($match.Groups[3].Value -eq '$UiPort') { $uiPortDefault } else { [int]$match.Groups[3].Value }

    $appName = $mName.ToUpper()
    $cfg = Get-ModuleConfigFile -ModuleDir $mDir
    if ($cfg) {
        $cfgText = Read-TextFile $cfg
        $hit = [regex]::Match($cfgText, '(?m)^\s*application:\s*[\r\n]+\s*name:\s*([^\r\n]+)')
        if ($hit.Success) { $appName = $hit.Groups[1].Value.Trim() }
        else {
            $hit2 = [regex]::Match($cfgText, '(?m)^\s*spring\.application\.name\s*[:=]\s*([^\r\n]+)')
            if ($hit2.Success) { $appName = $hit2.Groups[1].Value.Trim() }
        }
    }

    # Endpoint REST
    $endpoints = @()
    $javaDir = Join-Path $mDir 'src/main/java'
    if (Test-Path $javaDir) {
        foreach ($jf in (Get-ChildItem -Path $javaDir -Recurse -Filter '*.java')) {
            $cText = Read-TextFile $jf.FullName
            $prefix = ''
            $mReq = [regex]::Match($cText, '@RequestMapping\s*\(\s*(?:(?:value|path)\s*=\s*)?"([^"]+)"\)')
            if ($mReq.Success) { $prefix = $mReq.Groups[1].Value }

            foreach ($em in [regex]::Matches($cText, '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\s*(?:\(\s*(?:(?:value|path)\s*=\s*)?"?([^"\)]*)"?\s*\))?')) {
                $verb = $em.Groups[1].Value.Replace('Mapping', '').ToUpper()
                $p = $em.Groups[2].Value
                $pClean = if ($p) { if ($p.StartsWith('/')) { $p } else { "/$p" } } else { '' }
                $prefClean = $prefix.TrimEnd('/')
                $fullPath = $prefClean + $pClean
                if (-not $fullPath) { $fullPath = '/' }
                $endpoints += "$verb $fullPath"
            }
        }
    }

    $services += [pscustomobject]@{
        Short     = $match.Groups[1].Value
        Module    = $mName
        Port      = $port
        AppName   = $appName
        Endpoints = $endpoints
    }
}

# --- 2. Sincronizzazione allegato.md ------------------------------------------

$hints = @{
    Analisi   = '[Descrivi brevemente il contesto, il problema e gli obiettivi del progetto.]'
    Algoritmo = '[Descrivi la logica algoritmica implementata (es. selezione slot, verifica disponibilità), con passaggi e complessità temporale.]'
    Modulo    = '[Descrivi il ruolo di questo modulo, le dipendenze e le scelte implementative.]'
    Domanda   = '[Inserisci qui la tua risposta alla domanda teorica.]'
}

if (-not (Test-Path $allegatoFile)) {
    $lines = @(
        '# Allegato tecnico: le parti scritte da te'
        ''
        'task allegato e task consegna prendono ogni sezione di questo file e la inseriscono'
        'in ALLEGATO-TECNICO.md, accanto a quanto ricavato in automatico dal codice'
        '(moduli, porte, endpoint, schema del database).'
        ''
        '## Analisi', '', $hints.Analisi, ''
        '## Algoritmo', '', $hints.Algoritmo, ''
    )
    foreach ($s in $services) { $lines += @("## $($s.Module)", '', $hints.Modulo, '') }
    $lines += @('## Domanda A', '', $hints.Domanda, '', '## Domanda B', '', $hints.Domanda)
    Write-TextFile -Path $allegatoFile -Text (($lines -join "`n") + "`n")
    Write-Step "creato $allegatoFile"
}

# Lettura sezioni
$parts = @{}
$currentSec = $null
$buf = New-Object System.Collections.Generic.List[string]
foreach ($line in (Split-TextLines (Read-TextFile $allegatoFile))) {
    if ($line -match '^##\s+(.+?)\s*$') {
        if ($currentSec) { $parts[$currentSec] = ($buf -join "`n").Trim() }
        $currentSec = ($Matches[1] -replace '`', '').Trim().ToLowerInvariant()
        $buf.Clear()
    } elseif ($currentSec) {
        $buf.Add($line)
    }
}
if ($currentSec) { $parts[$currentSec] = ($buf -join "`n").Trim() }

# Se ci sono nuovi moduli non presenti in allegato.md, aggiungili
$added = @($services | Where-Object { -not $parts.ContainsKey($_.Module.ToLowerInvariant()) } | ForEach-Object { $_.Module })
if ($added.Count -gt 0) {
    $extra = ($added | ForEach-Object { "`n## $_`n`n$($hints.Modulo)" }) -join "`n"
    Write-TextFile -Path $allegatoFile -Text ((Read-TextFile $allegatoFile).TrimEnd() + "`n" + $extra + "`n")
    Write-Step ("allegato.md: aggiunta sezione per " + ($added -join ', '))
    # ricarica parti
    $parts = @{}
    $currentSec = $null
    $buf.Clear()
    foreach ($line in (Split-TextLines (Read-TextFile $allegatoFile))) {
        if ($line -match '^##\s+(.+?)\s*$') {
            if ($currentSec) { $parts[$currentSec] = ($buf -join "`n").Trim() }
            $currentSec = ($Matches[1] -replace '`', '').Trim().ToLowerInvariant()
            $buf.Clear()
        } elseif ($currentSec) { $buf.Add($line) }
    }
    if ($currentSec) { $parts[$currentSec] = ($buf -join "`n").Trim() }
}

# --- 3. Generazione Schema DB -------------------------------------------------

$schemaFile = Join-Path $PSScriptRoot 'db-schema.ps1'
$schemaText = ''
if (Test-Path $schemaFile) {
    try {
        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $schemaFile 2>&1
        $schemaText = ($raw | Out-String).Trim()
    } catch {
        $schemaText = 'Nessuna entita'' persistente rilevata.'
    }
}
if (-not $schemaText) { $schemaText = 'Nessuna entita'' persistente rilevata.' }

$schemaOut = Join-Path $OutDir 'SCHEMA-DATABASE.md'
Write-TextFile -Path $schemaOut -Text ($schemaText.Trim() + "`n")
Write-Step "generato SCHEMA-DATABASE.md"

# --- 4. Compilazione ALLEGATO-TECNICO.md --------------------------------------

$missingSections = New-Object System.Collections.Generic.List[string]

function Get-SectionText {
    param([string]$Key, [string]$DefaultHint)
    $low = $Key.ToLowerInvariant()
    if ($parts.ContainsKey($low)) {
        $t = $parts[$low]
        if ($t -and -not $t.StartsWith('[')) {
            return $t
        }
    }
    $missingSections.Add($Key)
    return $DefaultHint
}

$today = Get-Date -Format 'dd/MM/yyyy'
$doc = New-Object System.Collections.Generic.List[string]

$doc.Add('# Allegato Tecnico di Progetto')
$doc.Add('')
$doc.Add("Candidato: **$Nome**  ")
$doc.Add("Data: $today  ")
$doc.Add('')
$doc.Add('---')
$doc.Add('')
$doc.Add('## 1. Analisi del problema e contesto applicativo')
$doc.Add('')
$doc.Add((Get-SectionText 'Analisi' $hints.Analisi))
$doc.Add('')
$doc.Add('## 2. Architettura della soluzione e ripartizione moduli')
$doc.Add('')
$doc.Add('Architettura a microservizi Spring Boot, con service discovery Netflix Eureka e')
$doc.Add('chiamate inter-servizio tramite OpenFeign risolte per nome logico. Ogni microservizio')
$doc.Add('espone i propri contratti REST documentati tramite OpenAPI / Swagger UI.')
$doc.Add('')
$doc.Add('| Modulo | Porta | Nome Eureka | Ruolo Architetturale |')
$doc.Add('| :--- | :---: | :--- | :--- |')
foreach ($s in $services) {
    $role = if ($s.Module -match 'naming-server') { 'Eureka Naming Server (Discovery)' }
            elseif ($s.Module -match '(^|-)ui$') { 'Interfaccia Web (Spring MVC / Thymeleaf)' }
            else { 'Microservizio REST (Business Logic / DB)' }
    $doc.Add('| `' + $s.Module + '` | ' + $s.Port + ' | `' + $s.AppName + '` | ' + $role + ' |')
}
$doc.Add('')
$doc.Add('Il modulo `common-dto` contiene classi record/DTO condivise per garantire coerenza nei contratti di comunicazione.')
$doc.Add('')
$doc.Add('## 3. Schema concettuale e logico della base dati')
$doc.Add('')
foreach ($l in (Split-TextLines $schemaText)) {
    if ($l -match '^# ') { continue }
    if ($l -match '^#') { $doc.Add('#' + $l) } else { $doc.Add($l) }
}
$doc.Add('')
$doc.Add('## 4. Descrizione dei singoli moduli implementati')
$doc.Add('')
foreach ($s in $services) {
    $doc.Add('### Modulo `' + $s.Module + '` (Porta ' + $s.Port + ')')
    $doc.Add('')
    if ($s.Endpoints.Count -gt 0) {
        $doc.Add('Endpoint REST esposti:')
        $doc.Add('')
        foreach ($ep in $s.Endpoints) { $doc.Add('- `' + $ep + '`') }
        $doc.Add('')
        $doc.Add('Documentazione OpenAPI / Swagger: `http://localhost:' + $s.Port + '/swagger-ui.html`')
    } else {
        $doc.Add('Nessun endpoint REST esposto direttamente (servizio infrastrutturale o interfaccia web).')
    }
    $doc.Add('')
    $doc.Add((Get-SectionText $s.Module $hints.Modulo))
    $doc.Add('')
}

$doc.Add('## 5. Descrizione dell''algoritmo e complessità')
$doc.Add('')
$doc.Add((Get-SectionText 'Algoritmo' $hints.Algoritmo))
$doc.Add('')
$doc.Add('## 6. Istruzioni per l''esecuzione e il collaudo')
$doc.Add('')
$doc.Add('### Avvio con Docker Compose')
$doc.Add('```bash')
$doc.Add('docker compose up -d --build')
$doc.Add('```')
$doc.Add('')
$doc.Add('### Porte e Dashboard di riferimento')
foreach ($s in $services) {
    if ($s.Module -match 'naming-server') {
        $doc.Add('- Dashboard Eureka: `http://localhost:' + $s.Port + '`')
    } elseif ($s.Module -match '(^|-)ui$') {
        $doc.Add('- Interfaccia Web: `http://localhost:' + $s.Port + '`')
    } else {
        $doc.Add('- Swagger UI `' + $s.Module + '`: `http://localhost:' + $s.Port + '/swagger-ui.html`')
    }
}
$doc.Add('')

# Domande teoriche
$ansA = Get-SectionText 'Domanda A' ''
$ansB = Get-SectionText 'Domanda B' ''
if ($ansA -or $ansB) {
    $doc.Add('---')
    $doc.Add('')
    $doc.Add('## 7. Risposte alle Domande Teoriche')
    $doc.Add('')
    if ($ansA) {
        $doc.Add('### Domanda A')
        $doc.Add('')
        $doc.Add($ansA)
        $doc.Add('')
    }
    if ($ansB) {
        $doc.Add('### Domanda B')
        $doc.Add('')
        $doc.Add($ansB)
        $doc.Add('')
    }
}

$allegatoOut = Join-Path $OutDir 'ALLEGATO-TECNICO.md'
Write-TextFile -Path $allegatoOut -Text (($doc -join "`n") + "`n")
Write-Step "compilato ALLEGATO-TECNICO.md"

# --- 5. Riepilogo e Controllo Completezza -------------------------------------

Write-Host ''
if ($missingSections.Count -eq 0) {
    Write-Host "STATO: Allegato Tecnico COMPLETO al 100%! Pronto per la consegna." -ForegroundColor Green
} else {
    Write-Host "STATO: Allegato Tecnico compilato con sezioni ANCORA DA COMPLETARE in allegato.md:" -ForegroundColor Yellow
    foreach ($ms in $missingSections) {
        Write-Host "  - [DA COMPILARE] $ms" -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host "Apri 'allegato.md', scrivi i testi sotto i titoli indicati e rilancia 'task allegato'." -ForegroundColor Cyan
}
Write-Host ''
