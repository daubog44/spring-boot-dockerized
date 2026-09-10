<#
.SYNOPSIS
    Genera dati di prova a partire dalle @Entity: un data.sql per modulo.

.DESCRIPTION
    Legge le classi @Entity, ne ricava tabelle, colonne e relazioni, e scrive
    un `src/main/resources/data.sql` con le INSERT. Spring Boot lo esegue
    all'avvio, dopo che Hibernate ha creato le tabelle.

    I valori sono inventati ma plausibili: le stringhe seguono il nome della
    colonna (un campo "citta" prende nomi di citta', un "email" indirizzi), i
    numeri crescono, le date sono recenti, gli `enum` vengono presi davvero dai
    valori dichiarati nel file Java. Le tabelle con chiave esterna vengono
    riempite dopo quelle a cui puntano, cosi' i riferimenti esistono.

    Perche' funzioni con `ddl-auto: update` servono due proprieta', che il
    comando aggiunge da solo all'application.yml:
      spring.jpa.defer-datasource-initialization: true   (prima le tabelle)
      spring.sql.init.mode: always                       (anche su PostgreSQL)

    I dati di test valgono punti nella griglia d'esame.

.PARAMETER Module
    Un modulo solo. Se omesso, tutti quelli che hanno delle @Entity.

.PARAMETER Rows
    Quante righe per tabella (default 5).

.EXAMPLE
    task seed-data
    task seed-data SERVICE=ordini-service ROWS=10
#>
param(
    [string]$Module = '',
    [int]$Rows = 5
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Valori inventati, ma che sembrano veri ----------------------------------

$Nomi = @('Rossi S.r.l.', 'Bianchi SPA', 'Verdi & Figli', 'Neri Logistica', 'Gialli Trasporti', 'Azzurri Import', 'Ferrari Componenti', 'Moretti Distribuzione')
$Citta = @('Bolzano', 'Trento', 'Verona', 'Milano', 'Bologna', 'Padova', 'Brescia', 'Modena')
$Persone = @('Mario Rossi', 'Anna Bianchi', 'Luca Verdi', 'Giulia Neri', 'Paolo Gialli', 'Sara Azzurri', 'Marco Ferrari', 'Elena Moretti')
$Descrizioni = @('Prima consegna del mese', 'Ordine urgente', 'Riassortimento magazzino', 'Reso da cliente', 'Fornitura periodica', 'Campione gratuito', 'Ordine ricorrente', 'Spedizione parziale')
$Prodotti = @('Vite M6', 'Dado esagonale', 'Cuscinetto 6203', 'Guarnizione 40mm', 'Molla a trazione', 'Rondella piana', 'Perno filettato', 'Boccola in ottone')

# Un valore dalla tabella, con il numero di riga appeso quando la tabella
# finisce: cosi' anche con ROWS=50 non nascono due righe uguali, che su una
# colonna unique = true farebbero fallire l'avvio.
function Get-FromTable {
    param([string[]]$Table, [int]$Index)
    $value = $Table[($Index - 1) % $Table.Count]
    if ($Index -gt $Table.Count) { $value = "$value $Index" }
    return $value
}

function Get-StringValue {
    param([string]$Column, [int]$Index)
    switch -Regex ($Column) {
        'email'                      { return ('utente' + $Index + '@esempio.it') }
        '(citta|city|comune|luogo)'  { return (Get-FromTable -Table $Citta -Index $Index) }
        '(indirizzo|via|address)'    { return ('Via Roma ' + ($Index * 3)) }
        '(codice|sigla|targa|cod)'   { return ('COD-' + $Index.ToString('000')) }
        '(descrizione|note|testo)'   { return (Get-FromTable -Table $Descrizioni -Index $Index) }
        '(prodotto|articolo|item)'   { return (Get-FromTable -Table $Prodotti -Index $Index) }
        '(cliente|fornitore|ragione|azienda|societa)' { return (Get-FromTable -Table $Nomi -Index $Index) }
        '(nome|cognome|utente|referente|responsabile)' { return (Get-FromTable -Table $Persone -Index $Index) }
        '(stato|status|tipo)'        { return ('VALORE_' + $Index) }
        default                      { return ($Column.Replace('_', ' ') + ' ' + $Index) }
    }
}

function Get-Value {
    param([pscustomobject]$Column, [int]$Index)
    if ($Column.EnumValues -and $Column.EnumValues.Count -gt 0) {
        return ("'" + $Column.EnumValues[($Index - 1) % $Column.EnumValues.Count] + "'")
    }
    switch -Regex ($Column.JavaType) {
        '^(String)$'                { return ("'" + (Get-StringValue -Column $Column.Name -Index $Index).Replace("'", "''") + "'") }
        '^(Long|long|Integer|int|Short|short)$' {
            if ($Column.Name -match '(quantita|pezzi|numero|qta|scorta)') { return (($Index * 7) % 50 + 1) }
            return ($Index * 10)
        }
        '^(Double|double|Float|float|BigDecimal)$' { return ([string]([math]::Round(($Index * 12.5) + 0.5, 2))) }
        '^(Boolean|boolean)$'       { if ($Index % 2 -eq 0) { return 'true' } else { return 'false' } }
        '^LocalDate$'               { return ("'" + (Get-Date).AddDays(-$Index).ToString('yyyy-MM-dd') + "'") }
        '^(LocalDateTime|Instant)$' { return ("'" + (Get-Date).AddHours(-$Index).ToString('yyyy-MM-dd HH:mm:ss') + "'") }
        '^LocalTime$'               { return ("'" + (Get-Date).AddHours(-$Index).ToString('HH:mm:ss') + "'") }
        default                     { return ("'valore" + $Index + "'") }
    }
}

function ConvertTo-SnakeCase {
    param([string]$Name)
    return ([regex]::Replace($Name, '([a-z0-9])([A-Z])', '$1_$2')).ToLower()
}

# --- Lettura delle entity (come task db-schema) ------------------------------

function Get-Entities {
    param([string]$ModuleDir)

    $result = @()
    $srcDir = Join-Path $ModuleDir 'src/main/java'
    if (-not (Test-Path $srcDir)) { return $result }
    $javaFiles = @(Get-ChildItem -Path $srcDir -Recurse -Filter '*.java')

    foreach ($file in $javaFiles) {
        $text = Read-TextFile $file.FullName
        if ($text -notmatch '(?m)^\s*@Entity\b') { continue }

        $className = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $tableHit = [regex]::Match($text, '@Table\s*\(\s*name\s*=\s*"([^"]+)"')
        $tableName = if ($tableHit.Success) { $tableHit.Groups[1].Value } else { ConvertTo-SnakeCase -Name $className }

        $columns = @()
        $dependsOn = @()
        $fieldPattern = '(?ms)((?:^[ \t]*@[\w.]+(?:\s*\([^)]*\))?[ \t]*\r?\n)*)^[ \t]*(?:private|protected|public)\s+([\w<>\[\], .]+?)\s+(\w+)\s*(?:=[^;]+)?;'
        foreach ($match in ([regex]$fieldPattern).Matches($text)) {
            $annotations = $match.Groups[1].Value
            $javaType = $match.Groups[2].Value.Trim()
            $fieldName = $match.Groups[3].Value
            if ($annotations -match '@Transient') { continue }
            if ($annotations -match '@(OneToMany|ManyToMany)') { continue }

            if ($annotations -match '@(ManyToOne|OneToOne)') {
                $joinHit = [regex]::Match($annotations, '@JoinColumn\s*\([^)]*name\s*=\s*"([^"]+)"')
                $fkColumn = if ($joinHit.Success) { $joinHit.Groups[1].Value } else { (ConvertTo-SnakeCase -Name $fieldName) + '_id' }
                $columns += [pscustomobject]@{ Name = $fkColumn; JavaType = 'FK'; IsId = $false; EnumValues = @(); Target = $javaType }
                $dependsOn += $javaType
                continue
            }
            if ($annotations -match '@Id\b') {
                # La PK generata la lascia fare al database: non la scriviamo.
                if ($annotations -match '@GeneratedValue') {
                    $columns += [pscustomobject]@{ Name = (ConvertTo-SnakeCase -Name $fieldName); JavaType = $javaType; IsId = $true; EnumValues = @(); Target = '' }
                    continue
                }
            }

            $columnName = ConvertTo-SnakeCase -Name $fieldName
            $nameHit = [regex]::Match($annotations, '@Column\s*\([^)]*name\s*=\s*"([^"]+)"')
            if ($nameHit.Success) { $columnName = $nameHit.Groups[1].Value }

            # Se e' un enum, i valori veri stanno nel suo file.
            $enumValues = @()
            if ($annotations -match '@Enumerated') {
                $enumFile = $javaFiles | Where-Object { $_.BaseName -eq $javaType } | Select-Object -First 1
                if ($enumFile) {
                    $enumText = Read-TextFile $enumFile.FullName
                    $body = [regex]::Match($enumText, '(?s)enum\s+' + [regex]::Escape($javaType) + '\s*\{(.*?)[;}]')
                    if ($body.Success) {
                        $enumValues = @([regex]::Matches($body.Groups[1].Value, '\b([A-Z][A-Z0-9_]*)\b') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
                    }
                }
                if ($enumValues.Count -eq 0) { $enumValues = @('VALORE_A', 'VALORE_B') }
            }

            $columns += [pscustomobject]@{ Name = $columnName; JavaType = $javaType; IsId = $false; EnumValues = $enumValues; Target = '' }
        }

        $result += [pscustomobject]@{
            Class = $className
            Table = $tableName
            Columns = $columns
            DependsOn = $dependsOn
        }
    }
    return $result
}

# --- Ordine di inserimento: prima chi non dipende da nessuno -----------------

function Get-InsertOrder {
    param([array]$Entities)
    $ordered = @()
    $remaining = @($Entities)
    while ($remaining.Count -gt 0) {
        $ready = @($remaining | Where-Object {
            $entity = $_
            -not ($entity.DependsOn | Where-Object { $target = $_; ($remaining | Where-Object { $_.Class -eq $target -and $_.Class -ne $entity.Class }) })
        })
        if ($ready.Count -eq 0) { $ready = @($remaining[0]) }   # ciclo: si sceglie e si va avanti
        foreach ($entity in $ready) { $ordered += $entity }
        $remaining = @($remaining | Where-Object { $ready -notcontains $_ })
    }
    return $ordered
}

# --- Generazione --------------------------------------------------------------

$targets = @()
if ($Module) {
    $dir = Join-Path $demoDir $Module
    if (-not (Test-Path (Join-Path $dir 'pom.xml'))) { throw "Modulo '$Module' non trovato." }
    $targets += Get-Item $dir
} else {
    $targets = @(Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') })
}

Write-Host ''
Write-Host '==> Dati di prova dalle @Entity' -ForegroundColor Cyan
Write-Host ''

$generated = 0
foreach ($target in $targets) {
    $entities = @(Get-Entities -ModuleDir $target.FullName)
    if ($entities.Count -eq 0) { continue }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('-- Dati di prova generati da task seed-data.')
    $lines.Add('-- Spring Boot esegue questo file all''avvio, dopo che Hibernate ha')
    $lines.Add('-- creato le tabelle. Modificalo pure: non viene sovrascritto se non')
    $lines.Add('-- rilanci il comando.')
    $lines.Add('')

    foreach ($entity in (Get-InsertOrder -Entities $entities)) {
        $insertable = @($entity.Columns | Where-Object { -not $_.IsId })
        if ($insertable.Count -eq 0) { continue }
        $lines.Add('-- ' + $entity.Class)
        for ($i = 1; $i -le $Rows; $i++) {
            $names = @()
            $values = @()
            foreach ($column in $insertable) {
                $names += $column.Name
                if ($column.JavaType -eq 'FK') {
                    # Punta a una riga che esiste di sicuro: le tabelle padre
                    # sono state riempite prima, con lo stesso numero di righe.
                    $values += ((($i - 1) % $Rows) + 1)
                } else {
                    $values += (Get-Value -Column $column -Index $i)
                }
            }
            $lines.Add('INSERT INTO ' + $entity.Table + ' (' + ($names -join ', ') + ') VALUES (' + ($values -join ', ') + ');')
        }
        $lines.Add('')
    }

    $dataSql = Join-Path $target.FullName 'src/main/resources/data.sql'
    Write-TextFile -Path $dataSql -Text ($lines -join [Environment]::NewLine)
    Write-Step ("demo/" + $target.Name + "/src/main/resources/data.sql  (" + $entities.Count + " tabella/e x $Rows righe)")

    # Senza queste due proprieta' il file non viene eseguito, o viene eseguito
    # prima che le tabelle esistano.
    $ymlPath = Join-Path $target.FullName 'src/main/resources/application.yml'
    if (Test-Path $ymlPath) {
        $yml = Read-TextFile $ymlPath
        if ($yml -notmatch 'defer-datasource-initialization') {
            $lines2 = @(Split-TextLines $yml)
            $jpaIndex = Find-LineIndex -Lines $lines2 -Pattern '(?m)^\s+jpa:'
            if ($jpaIndex -ge 0) {
                Add-LinesAt -Path $ymlPath -Index ($jpaIndex + 1) -NewLines @('    defer-datasource-initialization: true')
            } else {
                Add-LinesBefore -Path $ymlPath -Anchor '(?m)^eureka:' -NewLines @('  jpa:', '    defer-datasource-initialization: true', '')
            }
            $yml = Read-TextFile $ymlPath
        }
        if ($yml -notmatch 'sql:\s*[\r\n]+\s+init:') {
            Add-LinesBefore -Path $ymlPath -Anchor '(?m)^eureka:' -NewLines @('  sql:', '    init:', '      mode: always', '')
        }
        Write-Step ("demo/" + $target.Name + "/src/main/resources/application.yml (esecuzione di data.sql)")
    }
    $generated++
}

Write-Host ''
if ($generated -eq 0) {
    Write-Host 'Nessuna @Entity trovata: non c''e'' niente da popolare.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Crea prima le entity del tuo dominio, poi rilancia questo comando.'
    Write-Host ''
    exit 0
}
Write-Host 'Dati di prova generati.' -ForegroundColor Green
Write-Host ''
Write-Host '  task dev          riavvia: le tabelle si riempiono da sole'
Write-Host '  task db-schema    lo schema che questi dati rispettano'
Write-Host ''
Write-Host '  Su PostgreSQL le INSERT vengono rieseguite a ogni avvio: se ti trovi' -ForegroundColor DarkGray
Write-Host '  righe doppie, svuota con task docker-reset. Con H2 in memoria non' -ForegroundColor DarkGray
Write-Host '  succede, perche'' il database riparte vuoto ogni volta.' -ForegroundColor DarkGray
Write-Host ''
