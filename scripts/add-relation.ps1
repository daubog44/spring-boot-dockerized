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
    [switch]$Unidirectional,
    [switch]$Dto
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$basePkg = Get-BasePackage -Aggregator $demoDir

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

if (-not $PSBoundParameters.ContainsKey('Type') -and -not [Console]::IsInputRedirected) {
    Write-Host ''
    Write-Host "Tipo di relazione:" -ForegroundColor Cyan
    Write-Host "  1) many-to-one (es. Un Articolo appartiene a una Categoria) [default]"
    Write-Host "  2) one-to-many"
    Write-Host "  3) many-to-many"
    Write-Host "  4) one-to-one"
    $tChoice = Read-Host "  [1] >"
    switch ($tChoice.Trim()) {
        '2' { $Type = 'one-to-many' }
        '3' { $Type = 'many-to-many' }
        '4' { $Type = 'one-to-one' }
        default { $Type = 'many-to-one' }
    }
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
        $fromBlock = if (-not $Unidirectional) {
@"
    @JsonIgnoreProperties("${toFieldName}")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${toSnake}_id")
    private ${cleanTo}Entity ${fromFieldName};
"@
        } else {
@"
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${toSnake}_id")
    private ${cleanTo}Entity ${fromFieldName};
"@
        }
        $fromImports = @(
            'jakarta.persistence.ManyToOne',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType'
        )
        if (-not $Unidirectional) {
            $fromImports += 'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
        }
        Add-ImportsToJava -FilePath $fromFile -NewImports $fromImports
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @ManyToOne $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @JsonIgnoreProperties("${fromFieldName}")
    @OneToMany(mappedBy = "${fromFieldName}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${cleanFrom}Entity> ${toFieldName} = new ArrayList<>();
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.OneToMany',
                'jakarta.persistence.CascadeType',
                'java.util.List',
                'java.util.ArrayList',
                'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @OneToMany $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'one-to-many' {
        $fromBlock = if (-not $Unidirectional) {
@"
    @JsonIgnoreProperties("${toFieldName}")
    @OneToMany(mappedBy = "${toFieldName}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${cleanTo}Entity> ${fromFieldName} = new ArrayList<>();
"@
        } else {
@"
    @OneToMany(mappedBy = "${toFieldName}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${cleanTo}Entity> ${fromFieldName} = new ArrayList<>();
"@
        }
        $fromImports = @(
            'jakarta.persistence.OneToMany',
            'jakarta.persistence.CascadeType',
            'java.util.List',
            'java.util.ArrayList'
        )
        if (-not $Unidirectional) {
            $fromImports += 'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
        }
        Add-ImportsToJava -FilePath $fromFile -NewImports $fromImports
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @OneToMany $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @JsonIgnoreProperties("${fromFieldName}")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${fromSnake}_id")
    private ${cleanFrom}Entity ${toFieldName};
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.ManyToOne',
                'jakarta.persistence.JoinColumn',
                'jakarta.persistence.FetchType',
                'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @ManyToOne $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'one-to-one' {
        $fromBlock = if (-not $Unidirectional) {
@"
    @JsonIgnoreProperties("${toFieldName}")
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @JoinColumn(name = "${toSnake}_id", unique = true)
    private ${cleanTo}Entity ${fromFieldName};
"@
        } else {
@"
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @JoinColumn(name = "${toSnake}_id", unique = true)
    private ${cleanTo}Entity ${fromFieldName};
"@
        }
        $fromImports = @(
            'jakarta.persistence.OneToOne',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType',
            'jakarta.persistence.CascadeType'
        )
        if (-not $Unidirectional) {
            $fromImports += 'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
        }
        Add-ImportsToJava -FilePath $fromFile -NewImports $fromImports
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @OneToOne $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @JsonIgnoreProperties("${fromFieldName}")
    @OneToOne(mappedBy = "${fromFieldName}", fetch = FetchType.LAZY)
    private ${cleanFrom}Entity ${toFieldName};
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.OneToOne',
                'jakarta.persistence.FetchType',
                'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @OneToOne $toFieldName in ${cleanTo}Entity.java"
        }
    }

    'many-to-many' {
        $joinTable = "${fromSnake}_${toSnake}"
        $fromBlock = if (-not $Unidirectional) {
@"
    @JsonIgnoreProperties("${toFieldName}")
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "${joinTable}",
        joinColumns = @JoinColumn(name = "${fromSnake}_id"),
        inverseJoinColumns = @JoinColumn(name = "${toSnake}_id")
    )
    private Set<${cleanTo}Entity> ${fromFieldName} = new HashSet<>();
"@
        } else {
@"
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "${joinTable}",
        joinColumns = @JoinColumn(name = "${fromSnake}_id"),
        inverseJoinColumns = @JoinColumn(name = "${toSnake}_id")
    )
    private Set<${cleanTo}Entity> ${fromFieldName} = new HashSet<>();
"@
        }
        $fromImports = @(
            'jakarta.persistence.ManyToMany',
            'jakarta.persistence.JoinTable',
            'jakarta.persistence.JoinColumn',
            'jakarta.persistence.FetchType',
            'java.util.Set',
            'java.util.HashSet'
        )
        if (-not $Unidirectional) {
            $fromImports += 'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
        }
        Add-ImportsToJava -FilePath $fromFile -NewImports $fromImports
        Add-FieldToEntity -FilePath $fromFile -FieldBlock $fromBlock -CheckFieldName $fromFieldName
        Write-Step "Aggiunto @ManyToMany $fromFieldName in ${cleanFrom}Entity.java"

        if (-not $Unidirectional) {
            $toBlock = @"
    @JsonIgnoreProperties("${fromFieldName}")
    @ManyToMany(mappedBy = "${fromFieldName}", fetch = FetchType.LAZY)
    private Set<${cleanFrom}Entity> ${toFieldName} = new HashSet<>();
"@
            Add-ImportsToJava -FilePath $toFile -NewImports @(
                'jakarta.persistence.ManyToMany',
                'jakarta.persistence.FetchType',
                'java.util.Set',
                'java.util.HashSet',
                'com.fasterxml.jackson.annotation.JsonIgnoreProperties'
            )
            Add-FieldToEntity -FilePath $toFile -FieldBlock $toBlock -CheckFieldName $toFieldName
            Write-Step "Aggiunto @ManyToMany $toFieldName in ${cleanTo}Entity.java"
        }
    }
}

# --- Automazione DTO in DTO ---
$commonDtoDir = Join-Path $demoDir 'common-dto/src/main/java'
$fromDtoFiles = @(Get-ChildItem -Path $commonDtoDir -Recurse -Filter "${cleanFrom}Dto.java" -ErrorAction SilentlyContinue)
$toDtoFiles = @(Get-ChildItem -Path $commonDtoDir -Recurse -Filter "${cleanTo}Dto.java" -ErrorAction SilentlyContinue)

if ($fromDtoFiles.Count -gt 0 -and $toDtoFiles.Count -gt 0) {
    $fromDtoPath = $fromDtoFiles[0].FullName
    $toDtoPath = $toDtoFiles[0].FullName

    $shouldUpdateDto = $Dto
    if (-not $Dto -and -not [Console]::IsInputRedirected) {
        Write-Host ''
        Write-Host "Trovati ${cleanFrom}Dto e ${cleanTo}Dto in common-dto." -ForegroundColor Cyan
        $ans = Read-Host "  Vuoi aggiornare ${cleanFrom}Dto col pattern DTO in DTO (${cleanTo}Dto annidato) e il Service? [S/n] >"
        if ($ans -match '^(s|si|y|yes)?$' -or -not $ans) { $shouldUpdateDto = $true }
    }

    if ($shouldUpdateDto) {
        # 1. Aggiorna FromDto.java
        $dtoContent = Read-TextFile $fromDtoPath
        if ($dtoContent -notmatch "\b${cleanTo}Dto\b") {
            $lastCloseParen = $dtoContent.LastIndexOf(')')
            if ($lastCloseParen -gt 0) {
                $beforeParen = $dtoContent.Substring(0, $lastCloseParen).TrimEnd()
                $afterParen = $dtoContent.Substring($lastCloseParen)
                $eol = Get-TextEol $dtoContent
                $needsComma = ($beforeParen.TrimEnd() -notmatch '[\(\,]$')
                $newParams = if ($needsComma) { ",${eol}    ${cleanTo}Dto ${fromFieldName},${eol}    Long ${fromFieldName}Id" } else { "${eol}    ${cleanTo}Dto ${fromFieldName},${eol}    Long ${fromFieldName}Id" }
                $updatedDtoContent = $beforeParen + $newParams + $eol + $afterParen
                Write-TextFile -Path $fromDtoPath -Text $updatedDtoContent
                Write-Step "Aggiornato DTO con ${cleanTo}Dto ${fromFieldName}: $fromDtoPath"
            }
        }

        # 2. Aggiorna FromService.java se esiste
        $serviceFile = Join-Path $moduleDir "src/main/java/$packagePath/service/${cleanFrom}Service.java"
        $toRepoFile = Join-Path $moduleDir "src/main/java/$packagePath/repository/${cleanTo}Repository.java"
        if (Test-Path $serviceFile) {
            Add-ImportsToJava -FilePath $serviceFile -NewImports @("${basePkg}.common.dto.${cleanTo}Dto")
            $svcContent = Read-TextFile $serviceFile
            $eol = Get-TextEol $svcContent

            $toCamel = $cleanTo.Substring(0, 1).ToLowerInvariant() + $cleanTo.Substring(1)
            $repoFieldName = "${toCamel}Repository"

            if ((Test-Path $toRepoFile) -and ($svcContent -notmatch "\b$repoFieldName\b")) {
                $svcContent = $svcContent -replace "(private final ${cleanFrom}Repository\s+repository;)", "`$1${eol}    private final ${package}.repository.${cleanTo}Repository ${repoFieldName};"
            }

            if ($svcContent -match "public ${cleanFrom}Dto crea\(" -and $svcContent -notmatch "set${cleanTo}") {
                $svcContent = $svcContent -replace "(entity\.setId\(null\);)", "`$1${eol}        if (nuovo.${fromFieldName}Id() != null) {${eol}            ${repoFieldName}.findById(nuovo.${fromFieldName}Id()).ifPresent(entity::set${cleanTo});${eol}        }"
            }

            if ($svcContent -match "public ${cleanFrom}Dto aggiorna\(" -and $svcContent -notmatch "esistente\.set${cleanTo}") {
                $svcContent = $svcContent -replace "(return toDto\(repository\.save\(esistente\)\);)", "if (dati.${fromFieldName}Id() != null) {${eol}            ${repoFieldName}.findById(dati.${fromFieldName}Id()).ifPresent(esistente::set${cleanTo});${eol}        }${eol}        `$1"
            }

            if ($svcContent -match "public static ${cleanFrom}Dto toDto\(${cleanFrom}Entity entity\)" -and $svcContent -notmatch "${fromFieldName}Dto") {
                $pascalFromField = $fromFieldName.Substring(0, 1).ToUpperInvariant() + $fromFieldName.Substring(1)
                $mappingCode = "        ${cleanTo}Dto ${fromFieldName}Dto = ${package}.service.${cleanTo}Service.toDto(entity.get${pascalFromField}());${eol}        Long ${fromFieldName}Id = entity.get${pascalFromField}() != null ? entity.get${pascalFromField}().getId() : null;"
                $svcContent = $svcContent -replace "(if \(entity == null\) return null;)", "`$1${eol}$mappingCode"

                $svcContent = $svcContent -replace "(return new ${cleanFrom}Dto\([\s\S]*?)(entity\.get\w+\(\)|entity\.getId\(\))([\r\n\s]*\);)", "`$1`$2,${eol}            ${fromFieldName}Dto,${eol}            ${fromFieldName}Id`$3"
            }

            Write-TextFile -Path $serviceFile -Text $svcContent
            Write-Step "Aggiornato Service con mapper DTO in DTO: $serviceFile"
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
