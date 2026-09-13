<#
.SYNOPSIS
    Genera un DTO (Java record o classe) in common-dto (o in un modulo), con campi e validazione.

.DESCRIPTION
    I DTO sono i contratti scambiati fra i microservizi (via Feign o REST):
    non contengono logica ne' annotazioni JPA. Questo comando genera un record
    Java moderno con i campi e le annotazioni di validazione (jakarta.validation).

.PARAMETER Name
    Nome del DTO, in PascalCase: Libro, Ordine o LibroDto. Se non termina con Dto
    o DTO, viene aggiunto automaticamente (es. Libro -> LibroDto).

.PARAMETER Fields
    Campi separati da virgola: nome:tipo[:modificatore]*.
    Tipi: string, string(N), text, int, long, decimal, bool, date, datetime, email, enum(A|B|...).
    Modificatori: required, min(N), max(N).

.PARAMETER Service
    Modulo di destinazione (default: common-dto). Se omesso va in common-dto
    nel pacchetto <base>.common.dto, visibile a tutti i moduli.

.PARAMETER Class
    Genera una classe standard (con Lombok @Getter @Setter @NoArgsConstructor @AllArgsConstructor)
    invece di un Java record.

.EXAMPLE
    task new-dto NAME=Libro FIELDS=id:long,titolo:string(150):required,prezzo:decimal,disponibile:bool
    task new-dto NAME=Prestito FIELDS=libroId:long:required,utenteEmail:email:required,dataInizio:date
#>
param(
    [string]$Name = '',
    [string]$Fields = '',
    [string]$Service = 'common-dto',
    [switch]$Class
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Helper Read-Answer (supporta WIZARD_ANSWERS per test automatici) ---
$script:answers = $null
if ($env:WIZARD_ANSWERS) {
    if (-not (Test-Path $env:WIZARD_ANSWERS)) { throw "WIZARD_ANSWERS: non trovo $env:WIZARD_ANSWERS" }
    $script:answers = New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($line in [System.IO.File]::ReadAllLines($env:WIZARD_ANSWERS)) { $script:answers.Enqueue($line) }
}
function Read-Answer {
    param([string]$Prompt = '  >')
    if ($null -ne $script:answers) {
        if ($script:answers.Count -eq 0) { throw 'WIZARD_ANSWERS: le risposte sono finite prima delle domande.' }
        $answer = $script:answers.Dequeue()
        Write-Host "$Prompt $answer"
        return $answer
    }
    return (Read-Host $Prompt)
}

if (-not $Name -or -not $Fields) {
    if ([Console]::IsInputRedirected -and $null -eq $script:answers) {
        if (-not $Name) {
            throw "Uso: task new-dto NAME=<Nome> [FIELDS=<campo:tipo:modificatore,...>] [SERVICE=common-dto]`n" +
                  "Esempio: task new-dto NAME=Libro FIELDS=id:long,titolo:string(150):required,disponibile:bool"
        }
    } else {
        if (-not $Name) {
            Write-Host ''
            Write-Host 'CREAZIONE DTO/RECORD GUIDATA' -ForegroundColor Cyan
            $Name = (Read-Answer "  Nome del DTO in PascalCase (es. LibroDto, OrdineDto, ArticoloDto)").Trim()
            if (-not $Name) {
                throw "Uso: task new-dto NAME=<Nome> [FIELDS=<campo:tipo:modificatore,...>] [SERVICE=common-dto]"
            }
        }

        if (-not $Fields) {
            Write-Host ''
            Write-Host '  Come vuoi definire i campi?' -ForegroundColor DarkGray
            Write-Host '    1) guidato, un campo alla volta (tipo e modificatori da menu)'
            Write-Host '    2) tutti insieme, in una riga (come FIELDS=... da riga di comando)'
            $fieldMode = (Read-Answer "  Modalita' [1]").Trim()
            if ($fieldMode -eq '2') {
                Write-Host '  Esempio: id:long,titolo:string(150):required,anno:int:min(1900),prezzo:decimal' -ForegroundColor DarkGray
                $Fields = (Read-Answer '  Campi').Trim()
            } else {
                $fieldTokens = @()
                while ($true) {
                    $fName = (Read-Answer '  Nome campo (Invio per terminare)').Trim()
                    if (-not $fName) { break }

                    Write-Host '    1) string      4) long       7) date        10) email'
                    Write-Host '    2) string(N)   5) decimal    8) datetime    11) enum(A|B|C)'
                    Write-Host '    3) text        6) bool       9) int'
                    $typeChoice = (Read-Answer '    Tipo [1]').Trim()
                    $typeToken = switch ($typeChoice) {
                        '2' { "string(" + (Read-Answer '    Lunghezza massima').Trim() + ")" }
                        '3' { 'text' }
                        '4' { 'long' }
                        '5' { 'decimal' }
                        '6' { 'bool' }
                        '7' { 'date' }
                        '8' { 'datetime' }
                        '9' { 'int' }
                        '10' { 'email' }
                        '11' { "enum(" + (Read-Answer '    Valori separati da | (es. ATTIVO|SOSPESO)').Trim() + ")" }
                        default { 'string' }
                    }

                    Write-Host '    Modificatori, numeri separati da virgola (Invio per nessuno):'
                    Write-Host '      1) required   2) unique   3) min(N)   4) max(N)'
                    $modChoice = (Read-Answer '    Modificatori').Trim()
                    $mods = @()
                    if ($modChoice) {
                        foreach ($m in ($modChoice -split ',')) {
                            switch ($m.Trim()) {
                                '1' { $mods += 'required' }
                                '2' { $mods += 'unique' }
                                '3' { $mods += "min(" + (Read-Answer '      Minimo').Trim() + ")" }
                                '4' { $mods += "max(" + (Read-Answer '      Massimo').Trim() + ")" }
                            }
                        }
                    }

                    $token = "${fName}:${typeToken}"
                    if ($mods.Count -gt 0) { $token += ':' + ($mods -join ':') }
                    $fieldTokens += $token
                    Write-Host "    -> $token" -ForegroundColor DarkGray
                    Write-Host ''

                    $again = (Read-Answer '  Un altro campo? [S/n]').Trim().ToLowerInvariant()
                    if ($again -eq 'n' -or $again -eq 'no') { break }
                }
                $Fields = $fieldTokens -join ','
            }
        }

        if (-not $Class) {
            $cAns = (Read-Answer "  Tipo: [1] Record moderno (default), [2] Classe classica con Lombok (CLASS=1)").Trim()
            if ($cAns -eq '2') { $Class = $true }
        }
    }
}

if ($Name -cnotmatch '^[A-Z][a-zA-Z0-9]*$') {
    throw "Nome non valido: '$Name'. Usa il PascalCase: Libro, DettaglioOrdine."
}

$className = if ($Name -match '(?i)dto$') { $Name } else { "${Name}Dto" }

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/. Crealo prima se e' un servizio, o usa SERVICE=common-dto."
}

$basePkg = Get-BasePackage -RepoRoot $repoRoot
$package = if ($Service -eq 'common-dto') {
    "$basePkg.common.dto"
} else {
    $modPkg = Get-ModulePackage -Module $Service
    "$modPkg.dto"
}
$packagePath = $package -replace '\.', '/'
$targetDir = Join-Path $moduleDir "src/main/java/$packagePath"
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

$targetFile = Join-Path $targetDir "$className.java"
if (Test-Path $targetFile) {
    throw "C'e' gia' $targetFile. Cancellalo prima, o scegli un altro nome."
}

function Get-PascalField {
    param([string]$Field)
    return ($Field.Substring(0, 1).ToUpperInvariant() + $Field.Substring(1))
}

# --- Parsing dei campi ---
$fieldSpecs = @()
if ($Fields) {
    foreach ($raw in ($Fields -split ',')) {
        $raw = $raw.Trim()
        if (-not $raw) { continue }
        $tokens = $raw -split ':'
        if ($tokens.Count -lt 2) {
            throw "Campo mal scritto: '$raw'. Serve almeno nome:tipo, es. titolo:string."
        }
        $fieldName = $tokens[0].Trim()
        if ($fieldName -cnotmatch '^[a-z][a-zA-Z0-9]*$') {
            throw "Nome campo non valido: '$fieldName'. Usa il camelCase: dataScadenza."
        }
        $typeToken = $tokens[1].Trim()
        $modifiers = @()
        if ($tokens.Count -gt 2) {
            $modifiers = @($tokens[2..($tokens.Count - 1)] | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $required = $modifiers -contains 'required'
        $min = $null
        $max = $null
        foreach ($m in $modifiers) {
            if ($m -match '^min\((-?\d+)\)$') { $min = $Matches[1] }
            elseif ($m -match '^max\((-?\d+)\)$') { $max = $Matches[1] }
            elseif ($m -notin @('required', 'unique')) {
                throw "Modificatore non riconosciuto per DTO: '$m'. Validi: required, min(N), max(N)."
            }
        }

        $javaType = $null
        $enumName = $null
        $enumValues = @()
        $validationLines = @()
        $length = $null

        if ($typeToken -eq 'string') {
            $javaType = 'String'
        } elseif ($typeToken -match '^string\((\d+)\)$') {
            $javaType = 'String'; $length = $Matches[1]
            $validationLines += "@Size(max = $length)"
        } elseif ($typeToken -eq 'text') {
            $javaType = 'String'
        } elseif ($typeToken -eq 'int') {
            $javaType = 'Integer'
        } elseif ($typeToken -eq 'long') {
            $javaType = 'Long'
        } elseif ($typeToken -eq 'decimal') {
            $javaType = 'BigDecimal'
        } elseif ($typeToken -eq 'bool') {
            $javaType = 'Boolean'
        } elseif ($typeToken -eq 'date') {
            $javaType = 'LocalDate'
        } elseif ($typeToken -eq 'datetime') {
            $javaType = 'LocalDateTime'
        } elseif ($typeToken -eq 'email') {
            $javaType = 'String'
            $validationLines += '@Email'
        } elseif ($typeToken -match '^enum\(([A-Za-z0-9_|]+)\)$') {
            $enumValues = @($Matches[1] -split '\|' | ForEach-Object { $_.Trim().ToUpperInvariant() })
            $enumName = Get-PascalField $fieldName
            $javaType = $enumName
        } else {
            throw "Tipo non riconosciuto: '$typeToken'."
        }

        if ($required) {
            if ($javaType -eq 'String' -and -not $enumName) { $validationLines += '@NotBlank' }
            else { $validationLines += '@NotNull' }
        }
        if ($null -ne $min) { $validationLines += "@Min($min)" }
        if ($null -ne $max) { $validationLines += "@Max($max)" }

        $fieldSpecs += [pscustomobject]@{
            Name       = $fieldName
            Pascal     = (Get-PascalField $fieldName)
            JavaType   = $javaType
            EnumName   = $enumName
            EnumValues = $enumValues
            Validation = $validationLines
        }
    }
}

# --- Enum generazione se presenti ---
foreach ($f in ($fieldSpecs | Where-Object { $_.EnumName })) {
    $enumFile = Join-Path $targetDir "$($f.EnumName).java"
    if (-not (Test-Path $enumFile)) {
        $enumBody = ($f.EnumValues -join ",`n    ")
        $enumSrc = @"
package $package;

public enum $($f.EnumName) {
    $enumBody
}
"@
        Write-TextFile -Path $enumFile -Text ($enumSrc + "`n")
        Write-Step "demo/$Service/src/main/java/$packagePath/$($f.EnumName).java"
    }
}

$usesBigDecimal = @($fieldSpecs | Where-Object { $_.JavaType -eq 'BigDecimal' }).Count -gt 0
$usesLocalDate = @($fieldSpecs | Where-Object { $_.JavaType -eq 'LocalDate' }).Count -gt 0
$usesLocalDateTime = @($fieldSpecs | Where-Object { $_.JavaType -eq 'LocalDateTime' }).Count -gt 0
$hasValidation = @($fieldSpecs | Where-Object { $_.Validation.Count -gt 0 }).Count -gt 0

$imports = New-Object System.Collections.Generic.List[string]
if ($hasValidation) { $imports.Add("import jakarta.validation.constraints.*;") }
if ($usesBigDecimal) { $imports.Add("import java.math.BigDecimal;") }
if ($usesLocalDate) { $imports.Add("import java.time.LocalDate;") }
if ($usesLocalDateTime) { $imports.Add("import java.time.LocalDateTime;") }

$importBlock = if ($imports.Count -gt 0) { ($imports -join "`n") + "`n`n" } else { "" }

if ($Class) {
    $fieldLines = foreach ($f in $fieldSpecs) {
        $lines = @()
        foreach ($v in $f.Validation) { $lines += "    $v" }
        $lines += "    private $($f.JavaType) $($f.Name);"
        ($lines -join "`n")
    }
    $body = if ($fieldLines) { "`n" + ($fieldLines -join "`n`n") + "`n" } else { "" }

    $dtoSrc = @"
package $package;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
${importBlock}/**
 * DTO per $className.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class $className {$body}
"@
} else {
    # Java record moderno (default)
    $paramLines = foreach ($f in $fieldSpecs) {
        $valPrefix = if ($f.Validation.Count -gt 0) { ($f.Validation -join ' ') + ' ' } else { '' }
        "    ${valPrefix}$($f.JavaType) $($f.Name)"
    }
    $body = if ($paramLines) { "`n" + ($paramLines -join ",`n") + "`n" } else { "" }

    $dtoSrc = @"
package $package;

${importBlock}/**
 * DTO immutabile per $className (Java record).
 */
public record $className($body) {}
"@
}

Write-TextFile -Path $targetFile -Text ($dtoSrc.Trim() + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/$className.java"
