<#
.SYNOPSIS
    Ricava lo schema del database dalle @Entity del progetto.

.DESCRIPTION
    Legge le classi annotate con @Entity, modulo per modulo, e ne ricava le
    tabelle: colonne, tipi SQL, chiavi primarie ed esterne, relazioni. E' lo
    "schema concettuale e logico della base dati" che l'allegato tecnico
    chiede, ricavato dal codice invece che ricordato a memoria.

    Non si collega a nessun database: legge i sorgenti. Quindi funziona anche a
    stack spento, e dice la verita' su quello che Hibernate creera'.

.PARAMETER OutFile
    Scrive il risultato su file invece che a schermo (lo usa task consegna).

.EXAMPLE
    task db-schema
    task db-schema OUT=schema.md
#>
param([string]$OutFile = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Da tipo Java a tipo SQL --------------------------------------------------

function Get-SqlType {
    param([string]$JavaType, [bool]$IsEnum, [int]$Length)
    if ($IsEnum) { return 'VARCHAR(255)' }
    switch -Regex ($JavaType) {
        '^(String)$'                    { if ($Length -gt 0) { return "VARCHAR($Length)" } else { return 'VARCHAR(255)' } }
        '^(Long|long)$'                 { return 'BIGINT' }
        '^(Integer|int)$'               { return 'INTEGER' }
        '^(Short|short)$'               { return 'SMALLINT' }
        '^(Double|double)$'             { return 'DOUBLE PRECISION' }
        '^(Float|float)$'               { return 'REAL' }
        '^(Boolean|boolean)$'           { return 'BOOLEAN' }
        '^BigDecimal$'                  { return 'NUMERIC(19,2)' }
        '^LocalDate$'                   { return 'DATE' }
        '^(LocalDateTime|Instant)$'     { return 'TIMESTAMP' }
        '^LocalTime$'                   { return 'TIME' }
        '^(UUID)$'                      { return 'UUID' }
        '^byte\[\]$'                    { return 'BYTEA' }
        default                         { return 'VARCHAR(255)' }
    }
}

# I nomi che Hibernate genera quando non li scrivi: CamelCase -> snake_case.
function ConvertTo-SnakeCase {
    param([string]$Name)
    $out = [regex]::Replace($Name, '([a-z0-9])([A-Z])', '$1_$2')
    return $out.ToLower()
}

# --- Lettura delle entity -----------------------------------------------------

$entities = @()

foreach ($moduleDir in (Get-ChildItem -Path $demoDir -Directory)) {
    $srcDir = Join-Path $moduleDir.FullName 'src/main/java'
    if (-not (Test-Path $srcDir)) { continue }

    foreach ($file in (Get-ChildItem -Path $srcDir -Recurse -Filter '*.java')) {
        $text = Read-TextFile $file.FullName
        if ($text -notmatch '(?m)^\s*@Entity\b') { continue }

        $className = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $tableName = ''
        $tableHit = [regex]::Match($text, '@Table\s*\(\s*name\s*=\s*"([^"]+)"')
        if ($tableHit.Success) { $tableName = $tableHit.Groups[1].Value }
        else { $tableName = ConvertTo-SnakeCase -Name $className }

        $columns = @()
        $relations = @()

        # Un campo per volta, con le annotazioni che lo precedono.
        $fieldPattern = '(?ms)((?:^[ \t]*@[\w.]+(?:\s*\([^)]*\))?[ \t]*\r?\n)*)^[ \t]*(?:private|protected|public)\s+([\w<>\[\], .]+?)\s+(\w+)\s*(?:=[^;]+)?;'
        foreach ($match in ([regex]$fieldPattern).Matches($text)) {
            $annotations = $match.Groups[1].Value
            $javaType = $match.Groups[2].Value.Trim()
            $fieldName = $match.Groups[3].Value

            if ($annotations -match '@Transient') { continue }

            # Relazioni: la colonna e' una FK, oppure sta dall'altra parte.
            if ($annotations -match '@(ManyToOne|OneToOne)') {
                $joinHit = [regex]::Match($annotations, '@JoinColumn\s*\([^)]*name\s*=\s*"([^"]+)"')
                $fkColumn = if ($joinHit.Success) { $joinHit.Groups[1].Value } else { (ConvertTo-SnakeCase -Name $fieldName) + '_id' }
                $target = ($javaType -replace 'Entity$', '')
                $columns += [pscustomobject]@{
                    Name = $fkColumn; Type = 'BIGINT'; Key = 'FK'
                    Nullable = ($annotations -notmatch 'optional\s*=\s*false')
                    Note = "riferimento a $target"
                }
                $kind = if ($annotations -match '@OneToOne') { 'uno a uno' } else { 'molti a uno' }
                $relations += "``$className`` -> ``$target`` ($kind, colonna ``$fkColumn``)"
                continue
            }
            if ($annotations -match '@(OneToMany|ManyToMany)') {
                $inner = [regex]::Match($javaType, '<\s*(\w+)\s*>')
                $target = if ($inner.Success) { $inner.Groups[1].Value -replace 'Entity$', '' } else { $javaType }
                $kind = if ($annotations -match '@ManyToMany') { 'molti a molti (tabella di collegamento)' } else { 'uno a molti (la FK sta nell''altra tabella)' }
                $relations += "``$className`` -> ``$target`` ($kind)"
                continue
            }

            $isId = $annotations -match '@Id\b'
            $isEnum = $annotations -match '@Enumerated'
            $length = 0
            $lengthHit = [regex]::Match($annotations, '@Column\s*\([^)]*length\s*=\s*(\d+)')
            if ($lengthHit.Success) { $length = [int]$lengthHit.Groups[1].Value }

            $columnName = ConvertTo-SnakeCase -Name $fieldName
            $nameHit = [regex]::Match($annotations, '@Column\s*\([^)]*name\s*=\s*"([^"]+)"')
            if ($nameHit.Success) { $columnName = $nameHit.Groups[1].Value }

            $note = @()
            if ($annotations -match '@GeneratedValue') { $note += 'generato automaticamente' }
            if ($annotations -match '@Column\s*\([^)]*unique\s*=\s*true') { $note += 'univoco' }
            if ($isEnum) { $note += 'enum salvato come stringa' }

            $columns += [pscustomobject]@{
                Name = $columnName
                Type = (Get-SqlType -JavaType $javaType -IsEnum $isEnum -Length $length)
                Key = if ($isId) { 'PK' } else { '' }
                Nullable = -not ($isId -or ($annotations -match '@Column\s*\([^)]*nullable\s*=\s*false'))
                Note = ($note -join ', ')
            }
        }

        $entities += [pscustomobject]@{
            Module = $moduleDir.Name
            Class = $className
            Table = $tableName
            Columns = $columns
            Relations = $relations
        }
    }
}

# --- Scrittura ----------------------------------------------------------------

$out = New-Object System.Collections.Generic.List[string]
function Emit { param([string]$Line = '') ; $out.Add($Line) }

Emit '# Schema concettuale e logico della base dati'
Emit ''
if ($entities.Count -eq 0) {
    Emit 'Nessuna classe `@Entity` trovata: il progetto non ha ancora persistenza.'
    Emit ''
    Emit 'Le entity si riconoscono cosi'':'
    Emit ''
    Emit '```java'
    Emit '@Entity'
    Emit '@Table(name = "ordini")'
    Emit 'public class OrdineEntity { ... }'
    Emit '```'
} else {
    Emit ('Ricavato dalle classi `@Entity` del progetto: ' + $entities.Count + ' tabella/e.')
    Emit ''

    # --- Concettuale: entita' e relazioni, a parole e in diagramma ------------
    Emit '## Modello concettuale'
    Emit ''
    foreach ($group in ($entities | Group-Object Module)) {
        Emit ("**Modulo ``" + $group.Name + "``**")
        Emit ''
        foreach ($entity in $group.Group) {
            $attributes = ($entity.Columns | Where-Object { $_.Key -ne 'FK' } | ForEach-Object { $_.Name }) -join ', '
            Emit ("- **" + ($entity.Class -replace 'Entity$', '') + "** (" + $attributes + ")")
        }
        Emit ''
    }

    $allRelations = @($entities | ForEach-Object { $_.Relations } | Where-Object { $_ })
    if ($allRelations.Count -gt 0) {
        Emit '**Relazioni**'
        Emit ''
        foreach ($relation in ($allRelations | Select-Object -Unique)) { Emit ("- " + $relation) }
        Emit ''
    }

    # Diagramma ER: GitHub e VS Code lo disegnano da soli.
    Emit '```mermaid'
    Emit 'erDiagram'
    foreach ($entity in $entities) {
        $name = ($entity.Table).ToUpper()
        Emit ("    $name {")
        foreach ($column in $entity.Columns) {
            $type = ($column.Type -replace '\(.*\)', '')
            $mark = if ($column.Key -eq 'PK') { ' PK' } elseif ($column.Key -eq 'FK') { ' FK' } else { '' }
            Emit ("        $type " + $column.Name + $mark)
        }
        Emit '    }'
    }
    foreach ($entity in $entities) {
        foreach ($relation in $entity.Relations) {
            # Nel testo i nomi sono fra apici inversi singoli.
            $hit = [regex]::Match($relation, '`(\w+)` -> `(\w+)`')
            if (-not $hit.Success) { continue }
            $fromEntity = $entities | Where-Object { $_.Class -eq $hit.Groups[1].Value } | Select-Object -First 1
            $toEntity = $entities | Where-Object { ($_.Class -replace 'Entity$', '') -eq $hit.Groups[2].Value } | Select-Object -First 1
            if (-not $fromEntity -or -not $toEntity) { continue }
            $cardinality = if ($relation -match 'molti a molti') { '}o--o{' } elseif ($relation -match 'uno a molti') { '||--o{' } elseif ($relation -match 'uno a uno') { '||--||' } else { '}o--||' }
            Emit ('    ' + ($fromEntity.Table).ToUpper() + " $cardinality " + ($toEntity.Table).ToUpper() + ' : ""')
        }
    }
    Emit '```'
    Emit ''

    # --- Logico: le tabelle, colonna per colonna -----------------------------
    Emit '## Modello logico'
    Emit ''
    foreach ($entity in $entities) {
        Emit ("### Tabella ``" + $entity.Table + "``")
        Emit ''
        Emit ("Modulo ``" + $entity.Module + "``, classe ``" + $entity.Class + "``.")
        Emit ''
        Emit '| Colonna | Tipo | Chiave | Null | Note |'
        Emit '| :--- | :--- | :---: | :---: | :--- |'
        foreach ($column in $entity.Columns) {
            $nullable = if ($column.Nullable) { 'si' } else { 'no' }
            Emit ('| `' + $column.Name + '` | ' + $column.Type + ' | ' + $column.Key + ' | ' + $nullable + ' | ' + $column.Note + ' |')
        }
        Emit ''
    }

    Emit '> Le tabelle le crea Hibernate all''avvio (`ddl-auto: update`) leggendo'
    Emit '> queste stesse classi: quello che vedi qui e'' quello che troverai nel'
    Emit '> database. I nomi non scritti a mano seguono la regola CamelCase ->'
    Emit '> snake_case, suffisso `Entity` compreso: se preferisci un altro nome,'
    Emit '> scrivilo tu con `@Table(name = "...")`.'
}
Emit ''

$text = ($out -join [Environment]::NewLine)
if ($OutFile) {
    Write-TextFile -Path $OutFile -Text $text
    Write-Host "Schema scritto in $OutFile" -ForegroundColor Green
} else {
    Write-Host $text
}
