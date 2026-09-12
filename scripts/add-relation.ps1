<#
.SYNOPSIS
    Aggiunge una relazione JPA tra due entità dello stesso microservizio.

.DESCRIPTION
    All'interno di un microservizio le tabelle condividono lo stesso database relazionale.
    Questo comando inserisce le annotazioni JPA corrette (@ManyToOne, @OneToMany, @ManyToMany,
    @OneToOne) e gestisce:
    - fetch = FetchType.LAZY di default per evitare query N+1;
    - chiave esterna @JoinColumn nel lato proprietario;
    - lato inverso con mappedBy e cascade (opzionale o bidirezionale);
    - import necessari (jakarta.persistence.*, collezioni java.util.*).

.PARAMETER Service
    Il modulo in cui si trovano le entità (es. catalogo-service).

.PARAMETER From
    L'entità sorgente / proprietaria della relazione (es. Libro o LibroEntity).

.PARAMETER To
    L'entità destinazione (es. Autore o AutoreEntity).

.PARAMETER Type
    Tipo di relazione: many-to-one (default), one-to-many, many-to-many, one-to-one.

.PARAMETER Field
    Nome del campo Java da inserire (default: derivato dal nome dell'entità target).

.PARAMETER Unidirectional
    Se specificato, non aggiunge il lato inverso nella seconda entità.

.EXAMPLE
    task add-relation SERVICE=catalogo-service FROM=Libro TO=Autore TYPE=many-to-one
    task add-relation SERVICE=catalogo-service FROM=Studente TO=Corso TYPE=many-to-many
#>
param(
    [string]$Service = '',
    [string]$From = '',
    [string]$To = '',
    [string]$Type = 'many-to-one',
    [string]$Field = '',
    [switch]$Unidirectional
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Modalità Interattiva se mancano parametri -----------------------------

if (-not $Service) {
    $jpaModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        $p = Join-Path $_.FullName 'pom.xml'
        (Test-Path $p) -and ((Read-TextFile $p) -match 'spring-boot-starter-data-jpa')
    } | Select-Object -ExpandProperty Name)

    if ($jpaModules.Count -eq 0) {
        throw "Non ci sono moduli con JPA (database) in demo/. Creane uno con task new-service."
    }

    if ([Console]::IsInputRedirected) {
        throw "Uso: task add-relation SERVICE=<modulo> FROM=<Entita1> TO=<Entita2> [TYPE=many-to-one|one-to-many|many-to-many|one-to-one] [FIELD=<nomeCampo>]"
    }

    Write-Host ''
    Write-Host 'Seleziona il microservizio con le entita'': ' -ForegroundColor Cyan
    for ($i = 0; $i -lt $jpaModules.Count; $i++) {
        Write-Host "  $($i + 1)) $($jpaModules[$i])"
    }
    $idx = Read-Host "  [1] >"
    $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
    $Service = $jpaModules[$idxNum - 1]
}

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/."
}

$package = Get-ModulePackage -Module $Service
$packagePath = $package -replace '\.', '/'
$entityDir = Join-Path $moduleDir "src/main/java/$packagePath/entity"

if (-not (Test-Path $entityDir)) {
    throw "Non trovo la cartella entity in $Service ($entityDir). Crea prima le entita' con task new-entity."
}

$existingEntities = @(Get-ChildItem -Path $entityDir -Filter '*Entity.java' | Select-Object -ExpandProperty BaseName | ForEach-Object { $_ -replace 'Entity$', '' })

if ($existingEntities.Count -lt 2) {
    throw "Nel modulo '$Service' ci sono meno di 2 entita'. Crea almeno due entita' con task new-entity prima di collegarle."
}

if (-not $From) {
    if ([Console]::IsInputRedirected) { throw "Specifica FROM=<NomeEntita>." }
    Write-Host ''
    Write-Host "Scegli l'entita' di partenza (FROM):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $existingEntities.Count; $i++) {
        Write-Host "  $($i + 1)) $($existingEntities[$i])"
    }
    $idx = Read-Host "  [1] >"
    $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
    $From = $existingEntities[$idxNum - 1]
}

if (-not $To) {
    if ([Console]::IsInputRedirected) { throw "Specifica TO=<NomeEntita>." }
    $candidates = @($existingEntities | Where-Object { $_ -ne $From })
    Write-Host ''
    Write-Host "Scegli l'entita' di arrivo (TO):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  $($i + 1)) $($candidates[$i])"
    }
    $idx = Read-Host "  [1] >"
    $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
    $To = $candidates[$idxNum - 1]
}

$cleanFrom = $From -replace 'Entity$', ''
$cleanTo = $To -replace 'Entity$', ''

$fromFile = Join-Path $entityDir "${cleanFrom}Entity.java"
$toFile = Join-Path $entityDir "${cleanTo}Entity.java"

if (-not (Test-Path $fromFile)) { throw "Non trovo l'entita' sorgente: $fromFile" }
if (-not (Test-Path $toFile)) { throw "Non trovo l'entita' target: $toFile" }

$cleanType = $Type.ToLowerInvariant().Trim()
if ($cleanType -notin @('many-to-one', 'one-to-many', 'many-to-many', 'one-to-one')) {
    throw "Tipo relazione non valido: '$Type'. Usa many-to-one, one-to-many, many-to-many o one-to-one."
}

# --- Nomi campi e colonne --------------------------------------------------

function Convert-ToCamelCase {
    param([string]$Text)
    if (-not $Text) { return '' }
    return $Text.Substring(0, 1).ToLowerInvariant() + $Text.Substring(1)
}

function Convert-ToSnakeCase {
    param([string]$Text)
    $withUnderscores = [regex]::Replace($Text, '(?<!^)([A-Z])', '_$1')
    return $withUnderscores.ToLowerInvariant()
}

$fromCamel = Convert-ToCamelCase $cleanFrom
$toCamel = Convert-ToCamelCase $cleanTo
$fromSnake = Convert-ToSnakeCase $cleanFrom
$toSnake = Convert-ToSnakeCase $cleanTo

$fromFieldName = if ($Field) { $Field } else {
    switch ($cleanType) {
        'many-to-one' { $toCamel }
        'one-to-one'  { $toCamel }
        'one-to-many' { "${toCamel}List" }
        'many-to-many'{ "${toCamel}Set" }
    }
}

$toFieldName = switch ($cleanType) {
    'many-to-one' { "${fromCamel}List" }
    'one-to-many' { $fromCamel }
    'one-to-one'  { $fromCamel }
    'many-to-many'{ "${fromCamel}Set" }
}

# --- Funzioni di inserimento nel sorgente Java -----------------------------

function Add-ImportsToJava {
    param([string]$FilePath, [string[]]$NewImports)
    $content = Read-TextFile $FilePath
    $lines = Split-TextLines $content
    
    $lastImportIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^import\s+') {
            $lastImportIdx = $i
        }
    }
    
    $neededImports = @()
    foreach ($imp in $NewImports) {
        if ($content -notmatch [regex]::Escape($imp)) {
            $neededImports += "import $imp;"
        }
    }
    
    if ($neededImports.Count -eq 0) { return }
    
    $eol = Get-TextEol $content
    $resultLines = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $lines) { $resultLines.Add($l) }
    
    if ($lastImportIdx -ge 0) {
        for ($k = 0; $k -lt $neededImports.Count; $k++) {
            $resultLines.Insert($lastImportIdx + 1 + $k, $neededImports[$k])
        }
    } else {
        $pkgIdx = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^package\s+') { $pkgIdx = $i; break }
        }
        $resultLines.Insert($pkgIdx + 1, '')
        for ($k = 0; $k -lt $neededImports.Count; $k++) {
            $resultLines.Insert($pkgIdx + 2 + $k, $neededImports[$k])
        }
    }
    
    Write-TextFile -Path $FilePath -Text ($resultLines -join $eol)
}

function Add-FieldToEntity {
    param([string]$FilePath, [string]$FieldBlock, [string]$CheckFieldName)
    $content = Read-TextFile $FilePath
    if ($content -match "\b$CheckFieldName\b") {
        throw "Il campo '$CheckFieldName' esiste gia' in $(Split-Path -Leaf $FilePath)."
    }
    
    $lastBraceIdx = $content.LastIndexOf('}')
    if ($lastBraceIdx -lt 0) { throw "Formato file non valido in $FilePath (graffa di chiusura mancante)." }
    
    $eol = Get-TextEol $content
    $before = $content.Substring(0, $lastBraceIdx).TrimEnd()
    $newContent = $before + $eol + $eol + $FieldBlock + $eol + "}" + $eol
    
    Write-TextFile -Path $FilePath -Text $newContent
}

# --- Generazione blocchi di codice -----------------------------------------

Write-Host ''
Write-Host "==> Configurazione relazione $cleanType tra $cleanFrom e $cleanTo in $Service..." -ForegroundColor Cyan

switch ($cleanType) {
    'many-to-one' {
        $fromBlock = @"
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${toSnake}_id")
    private ${cleanTo}Entity ${fromFieldName};
"@
        Add-ImportsToJava -FilePath $fromFile -NewImports @(
            'jakarta.persistence.ManyToOne',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType'
        )
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @ManyToOne $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @OneToMany(mappedBy = "${fromFieldName}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${cleanFrom}Entity> ${toFieldName} = new ArrayList<>();
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.OneToMany',
                'jakarta.persistence.CascadeType',
                'java.util.List',
                'java.util.ArrayList'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @OneToMany $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'one-to-many' {
        $fromBlock = @"
    @OneToMany(mappedBy = "${toFieldName}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${cleanTo}Entity> ${fromFieldName} = new ArrayList<>();
"@
        Add-ImportsToJava -FilePath $fromFile -NewImports @(
            'jakarta.persistence.OneToMany',
            'jakarta.persistence.CascadeType',
            'java.util.List',
            'java.util.ArrayList'
        )
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @OneToMany $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${fromSnake}_id")
    private ${cleanFrom}Entity ${toFieldName};
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.ManyToOne',
                'jakarta.persistence.JoinColumn',
                'jakarta.persistence.FetchType'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @ManyToOne $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'one-to-one' {
        $fromBlock = @"
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @JoinColumn(name = "${toSnake}_id", unique = true)
    private ${cleanTo}Entity ${fromFieldName};
"@
        Add-ImportsToJava -FilePath $fromFile -NewImports @(
            'jakarta.persistence.OneToOne',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType',
            'jakarta.persistence.CascadeType'
        )
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @OneToOne $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @OneToOne(mappedBy = "${fromFieldName}", fetch = FetchType.LAZY)
    private ${cleanFrom}Entity ${toFieldName};
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.OneToOne',
                'jakarta.persistence.FetchType'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @OneToOne $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'many-to-many' {
        $joinTable = "${fromSnake}_${toSnake}"
        $fromBlock = @"
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "${joinTable}",
        joinColumns = @JoinColumn(name = "${fromSnake}_id"),
        inverseJoinColumns = @JoinColumn(name = "${toSnake}_id")
    )
    private Set<${cleanTo}Entity> ${fromFieldName} = new HashSet<>();
"@
        Add-ImportsToJava -FilePath $fromFile -NewImports @(
            'jakarta.persistence.ManyToMany',
            'jakarta.persistence.JoinTable',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType',
            'java.util.Set',
            'java.util.HashSet'
        )
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @ManyToMany $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @ManyToMany(mappedBy = "${fromFieldName}", fetch = FetchType.LAZY)
    private Set<${cleanFrom}Entity> ${toFieldName} = new HashSet<>();
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.ManyToMany',
                'jakarta.persistence.FetchType',
                'java.util.Set',
                'java.util.HashSet'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @ManyToMany $toFieldName in ${cleanTo}Entity.java"
        }
    }
}

Write-Host ''
Write-Host "Relazione $cleanType configurata con successo!" -ForegroundColor Green
Write-Host "  Sorgente:      $fromFile"
if (-not $Unidirectional) {
    Write-Host "  Destinazione:  $toFile"
}
Write-Host ''
Write-Host "  Regola d'oro: Usa sempre un DTO nel Controller per evitare ricorsioni cicliche Jackson!" -ForegroundColor Yellow
Write-Host ''
