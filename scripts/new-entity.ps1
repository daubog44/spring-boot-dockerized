<#
.SYNOPSIS
    Genera l'entity, il repository, il service e il controller per una
    tabella, dentro un modulo che esiste gia'.

.DESCRIPTION
    Ogni tabella della traccia si scrive con lo stesso schema: una classe
    @Entity, un repository che estende JpaRepository, un service col CRUD e
    un controller REST con Swagger. Sono le stesse 4-5 righe ripetute per
    ogni tabella, in ogni modulo: questo comando le scrive, tu decidi solo i
    campi e le regole.

    Quello che NON genera, apposta: le relazioni fra entity (@ManyToOne,
    @OneToMany...) e le regole della tua traccia nel service. Sono decisioni
    tue, non boilerplate -- le aggiungi a mano dopo, come spiega la lezione 8
    del corso (task learn).

.PARAMETER Service
    Il modulo dove va la tabella, per esempio catalogo-service. Deve esistere
    gia' (task new-service) e avere un database (niente NODB=1 o UI=1).

.PARAMETER Name
    Nome dell'entity, in PascalCase: Libro, RigaOrdine. Diventa la classe
    LibroEntity (o RigaOrdineEntity) e, per default, la tabella e il percorso
    REST nella stessa forma minuscola: "libro", "/api/libro".

.PARAMETER Fields
    I campi, separati da virgola: nome:tipo[:modificatore]*. Tipi disponibili:
    string, string(N), text, int, long, decimal, bool, date, datetime, email,
    enum(VALORE1|VALORE2|...). Modificatori: required, unique, min(N), max(N).
    Esempio: titolo:string(150):required,isbn:string(13):unique,
    annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,
    genere:enum(ROMANZO|SAGGIO|GIALLO)

.PARAMETER Table
    Nome della tabella, se non vuoi quello di default (il nome dell'entity in
    minuscolo, senza andare a indovinare il plurale italiano).

.EXAMPLE
    task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):unique,annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,genere:enum(ROMANZO|SAGGIO|GIALLO)
#>
param(
    [string]$Service = '',
    [string]$Name = '',
    [string]$Fields = '',
    [string]$Table = '',
    [switch]$Dto
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Argomenti ------------------------------------------------------------

if (-not $Service -or -not $Name) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task new-entity SERVICE=<modulo> NAME=<Entita> FIELDS=<campo:tipo:modificatore,...>`n" +
              "Esempio: task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):unique"
    }

    $jpaModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        $p = Join-Path $_.FullName 'pom.xml'
        (Test-Path $p) -and ((Read-TextFile $p) -match 'spring-boot-starter-data-jpa')
    } | Select-Object -ExpandProperty Name)

    if ($jpaModules.Count -eq 0) {
        throw "Non ci sono moduli con JPA (database) in demo/. Creane uno con task new-service."
    }

    Write-Host ''
    Write-Host 'CREAZIONE ENTITY GUIDATA' -ForegroundColor Cyan
    if (-not $Service) {
        Write-Host "Seleziona il microservizio con database:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $jpaModules.Count; $i++) {
            Write-Host "  $($i + 1)) $($jpaModules[$i])"
        }
        $idx = Read-Host "  [1] >"
        $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
        $Service = $jpaModules[$idxNum - 1]
    }

    if (-not $Name) {
        $Name = (Read-Host "  Nome dell'Entity in PascalCase (es. Libro, Ordine, Articolo)").Trim()
        if (-not $Name) {
            throw "Uso: task new-entity SERVICE=<modulo> NAME=<Entita> FIELDS=<campo:tipo:modificatore,...>"
        }
    }

    if (-not $Fields) {
        Write-Host "  Campi (formato nome:tipo[:modificatore], es. nome:string:required,prezzo:decimal,disponibile:bool):" -ForegroundColor DarkGray
        $Fields = (Read-Host "  Campi (premi Invio se nessuno)").Trim()
    }

    if (-not $Dto) {
        $dAns = (Read-Host "  Generare anche il DTO in common-dto e mappare Service/Controller? [S/n]").Trim().ToLowerInvariant()
        if ($dAns -ne 'n' -and $dAns -ne 'no') {
            $Dto = $true
        }
    }
}
if ($Name -cnotmatch '^[A-Z][a-zA-Z0-9]*$') {
    throw "Nome non valido: '$Name'. Usa il PascalCase, come lo scriveresti in Java: Libro, RigaOrdine."
}

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/. Crealo prima con task new-service NAME=$Service."
}
$pomText = Read-TextFile (Join-Path $moduleDir 'pom.xml')
if ($pomText -notmatch 'spring-boot-starter-data-jpa') {
    throw "'$Service' non ha un database (creato con NODB=1 o UI=1): niente JPA, niente entity. " +
          "Rifallo senza NODB, o aggiungi a mano spring-boot-starter-data-jpa, h2, postgresql e validation al suo pom.xml."
}

$package = Get-ModulePackage -Module $Service
$packagePath = $package -replace '\.', '/'
$javaDir = Join-Path $moduleDir "src/main/java/$packagePath"

$entityDir = Join-Path $javaDir 'entity'
$repoDir = Join-Path $javaDir 'repository'
$serviceDir = Join-Path $javaDir 'service'
$controllerDir = Join-Path $javaDir 'controller'

$entityFile = Join-Path $entityDir "${Name}Entity.java"
if (Test-Path $entityFile) {
    throw "C'e' gia' $entityFile. Cancellalo prima, o scegli un altro nome."
}

function Convert-ToSnakeCase {
    param([string]$Text)
    $withUnderscores = [regex]::Replace($Text, '(?<!^)([A-Z])', '_$1')
    return $withUnderscores.ToLowerInvariant()
}

$tableName = if ($Table) { $Table } else { Convert-ToSnakeCase $Name }
$routeBase = $tableName -replace '_', '-'

# --- Il nome dei campi, in Java e nel resto -----------------------------------

function Get-PascalField {
    param([string]$Field)
    return ($Field.Substring(0, 1).ToUpperInvariant() + $Field.Substring(1))
}

# --- Interpretazione di FIELDS --------------------------------------------

# Un campo: nome:tipo[:modificatore]*. Il tipo puo' avere parentesi
# (string(150), enum(A|B|C)): dentro non ci sono mai virgole, quindi
# spezzare FIELDS sulla virgola resta sicuro.
$fieldSpecs = @()
if ($Fields) {
    foreach ($raw in ($Fields -split ',')) {
        $raw = $raw.Trim()
        if (-not $raw) { continue }
        $tokens = $raw -split ':'
        if ($tokens.Count -lt 2) {
            throw "Campo mal scritto: '$raw'. Serve almeno nome:tipo, es. titolo:string(150)."
        }
        $fieldName = $tokens[0].Trim()
        if ($fieldName -cnotmatch '^[a-z][a-zA-Z0-9]*$') {
            throw "Nome campo non valido: '$fieldName'. Usa il camelCase, come in Java: annoPubblicazione."
        }
        $typeToken = $tokens[1].Trim()
        # $tokens[2..($tokens.Count-1)] esploderebbe quando Count e' 2: in
        # PowerShell "2..1" e' un range DISCENDENTE (2,1), non vuoto.
        $modifiers = @()
        if ($tokens.Count -gt 2) {
            $modifiers = @($tokens[2..($tokens.Count - 1)] | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        $required = $modifiers -contains 'required'
        $unique = $modifiers -contains 'unique'
        $min = $null
        $max = $null
        foreach ($m in $modifiers) {
            if ($m -match '^min\((-?\d+)\)$') { $min = $Matches[1] }
            elseif ($m -match '^max\((-?\d+)\)$') { $max = $Matches[1] }
            elseif ($m -notin @('required', 'unique')) {
                throw "Modificatore non riconosciuto: '$m' (campo '$fieldName'). Validi: required, unique, min(N), max(N)."
            }
        }

        $javaType = $null
        $enumName = $null
        $enumValues = @()
        $columnAttrs = @()
        $validationLines = @()
        $length = $null

        if ($typeToken -eq 'string') {
            $javaType = 'String'
        } elseif ($typeToken -match '^string\((\d+)\)$') {
            $javaType = 'String'; $length = $Matches[1]
        } elseif ($typeToken -eq 'text') {
            $javaType = 'String'; $validationLines += '@Lob'
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
            $javaType = 'String'; $length = '120'; $validationLines += '@Email'
        } elseif ($typeToken -match '^enum\(([A-Za-z0-9_|]+)\)$') {
            $enumValues = @($Matches[1] -split '\|' | ForEach-Object { $_.Trim().ToUpperInvariant() })
            if ($enumValues.Count -lt 2) {
                throw "L'enum del campo '$fieldName' vuole almeno due valori: enum(A|B)."
            }
            $enumName = Get-PascalField $fieldName
            $javaType = $enumName
            $longest = ($enumValues | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
            $length = [Math]::Max(20, $longest)
        } else {
            throw "Tipo non riconosciuto per '$fieldName': '$typeToken'. Vedi task --summary new-entity."
        }

        if ($required) {
            $columnAttrs += 'nullable = false'
            if ($javaType -eq 'String' -and -not $enumName) { $validationLines += '@NotBlank' }
            else { $validationLines += '@NotNull' }
        }
        if ($unique) { $columnAttrs += 'unique = true' }
        if ($length) { $columnAttrs += "length = $length" }
        if ($null -ne $min) { $validationLines += "@Min($min)" }
        if ($null -ne $max) { $validationLines += "@Max($max)" }
        if ($enumName) { $validationLines += '@Enumerated(EnumType.STRING)' }

        $fieldSpecs += [pscustomobject]@{
            Name       = $fieldName
            Pascal     = (Get-PascalField $fieldName)
            JavaType   = $javaType
            EnumName   = $enumName
            EnumValues = $enumValues
            Column     = if ($columnAttrs.Count -gt 0) { '@Column(' + ($columnAttrs -join ', ') + ')' } else { $null }
            Validation = $validationLines
        }
    }
}

$usesBigDecimal = @($fieldSpecs | Where-Object { $_.JavaType -eq 'BigDecimal' }).Count -gt 0
$usesLocalDate = @($fieldSpecs | Where-Object { $_.JavaType -eq 'LocalDate' }).Count -gt 0
$usesLocalDateTime = @($fieldSpecs | Where-Object { $_.JavaType -eq 'LocalDateTime' }).Count -gt 0

# --- 1. Gli enum, uno per file --------------------------------------------

foreach ($f in ($fieldSpecs | Where-Object { $_.EnumName })) {
    $enumBody = ($f.EnumValues -join ",`n    ")
    $enumSrc = @"
package $package.entity;

public enum $($f.EnumName) {
    $enumBody
}
"@
    Write-TextFile -Path (Join-Path $entityDir "$($f.EnumName).java") -Text ($enumSrc + "`n")
    Write-Step "demo/$Service/src/main/java/$packagePath/entity/$($f.EnumName).java"
}

# --- 2. L'entity -----------------------------------------------------------

$fieldLines = foreach ($f in $fieldSpecs) {
    $lines = @()
    foreach ($v in $f.Validation) { $lines += "    $v" }
    if ($f.Column) { $lines += "    $($f.Column)" }
    $lines += "    private $($f.JavaType) $($f.Name);"
    ($lines -join "`n")
}
$entityFields = if ($fieldLines) { "`n" + ($fieldLines -join "`n`n") } else { '' }

$entitySrc = @"
package $package.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
$(if ($usesBigDecimal) { "import java.math.BigDecimal;`n" })$(if ($usesLocalDate) { "import java.time.LocalDate;`n" })$(if ($usesLocalDateTime) { "import java.time.LocalDateTime;`n" })
// Generata da task new-entity: aggiungi qui le relazioni (@ManyToOne,
// @OneToMany...) con altre entity DI QUESTO STESSO SERVIZIO. Con un altro
// servizio niente relazione: solo un id (Long) e una chiamata Feign, vedi
// la lezione 8 e la 10 del corso (task learn).
@Entity
@Table(name = "$tableName")
@Getter
@Setter
@NoArgsConstructor
public class ${Name}Entity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
$entityFields
}
"@
Write-TextFile -Path $entityFile -Text ($entitySrc + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/entity/${Name}Entity.java"

# --- 3. Il repository --------------------------------------------------------

$repoSrc = @"
package $package.repository;

import $package.entity.${Name}Entity;
import org.springframework.data.jpa.repository.JpaRepository;

// Vuoto apposta: JpaRepository da' gia' findAll, findById, save, deleteById,
// existsById, count. Le query della tua traccia le aggiungi qui, dal nome
// del metodo (findByGenere, existsByIsbn...) o con @Query -- vedi la
// lezione 8 del corso (task learn) per il catalogo completo.
public interface ${Name}Repository extends JpaRepository<${Name}Entity, Long> {
}
"@
Write-TextFile -Path (Join-Path $repoDir "${Name}Repository.java") -Text ($repoSrc + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/repository/${Name}Repository.java"

# --- 4. Generazione DTO opzionale (DTO=1) ------------------------------------

$basePkg = Get-BasePackage -RepoRoot $repoRoot

if ($Dto) {
    $dtoFields = if ($Fields -match '\bid:long\b') { $Fields } else { if ($Fields) { "id:long,$Fields" } else { "id:long" } }
    $dtoParams = @{ Name = $Name; Fields = $dtoFields; Service = 'common-dto' }
    & (Join-Path $PSScriptRoot 'new-dto.ps1') @dtoParams | Out-Null

    $dtoName = "${Name}Dto"
    $toDtoArgs = ($fieldSpecs | ForEach-Object { "            entity.get$($_.Pascal)()" }) -join ",`n"
    if ($toDtoArgs) { $toDtoArgs = ",`n" + $toDtoArgs }

    $toEntitySetters = ($fieldSpecs | ForEach-Object { "        entity.set$($_.Pascal)(dto.$($_.Name)());" }) -join "`n"
    $setterLinesFromDto = ($fieldSpecs | ForEach-Object { "        esistente.set$($_.Pascal)(dati.$($_.Name)());" }) -join "`n"
    if (-not $toEntitySetters) { $toEntitySetters = "        // Nessun campo aggiuntivo" }
    if (-not $setterLinesFromDto) { $setterLinesFromDto = "        // Nessun campo da aggiornare" }

    $serviceSrc = @"
package $package.service;

import $package.entity.${Name}Entity;
import $package.repository.${Name}Repository;
import $basePkg.common.dto.$dtoName;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ${Name}Service {

    private final ${Name}Repository repository;

    public List<$dtoName> elenco() {
        return repository.findAll().stream().map(${Name}Service::toDto).toList();
    }

    public $dtoName trova(Long id) {
        return toDto(trovaEntity(id));
    }

    public $dtoName crea($dtoName nuovo) {
        ${Name}Entity entity = toEntity(nuovo);
        entity.setId(null);
        return toDto(repository.save(entity));
    }

    public $dtoName aggiorna(Long id, $dtoName dati) {
        ${Name}Entity esistente = trovaEntity(id);
$setterLinesFromDto
        return toDto(repository.save(esistente));
    }

    public void elimina(Long id) {
        trovaEntity(id);
        repository.deleteById(id);
    }

    private ${Name}Entity trovaEntity(Long id) {
        return repository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "$Name " + id + " non trovato"));
    }

    // --- Mapper Entity <-> DTO ---

    public static $dtoName toDto(${Name}Entity entity) {
        if (entity == null) return null;
        return new $dtoName(
            entity.getId()$toDtoArgs
        );
    }

    public static ${Name}Entity toEntity($dtoName dto) {
        if (dto == null) return null;
        ${Name}Entity entity = new ${Name}Entity();
        entity.setId(dto.id());
$toEntitySetters
        return entity;
    }
}
"@

    $controllerSrc = @"
package $package.controller;

import $basePkg.common.dto.$dtoName;
import $package.service.${Name}Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "$Name", description = "CRUD per $Name basato su DTO")
@RestController
@RequestMapping("/api/$routeBase")
@RequiredArgsConstructor
public class ${Name}Controller {

    private final ${Name}Service service;

    @Operation(summary = "Tutti/e")
    @GetMapping
    public List<$dtoName> elenco() {
        return service.elenco();
    }

    @Operation(summary = "Per id (404 se non c'e')")
    @GetMapping("/{id}")
    public $dtoName perId(@PathVariable Long id) {
        return service.trova(id);
    }

    @Operation(summary = "Crea")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public $dtoName crea(@Valid @RequestBody $dtoName nuovo) {
        return service.crea(nuovo);
    }

    @Operation(summary = "Aggiorna (404 se non c'e')")
    @PutMapping("/{id}")
    public $dtoName aggiorna(@PathVariable Long id, @Valid @RequestBody $dtoName dati) {
        return service.aggiorna(id, dati);
    }

    @Operation(summary = "Elimina (404 se non c'e')")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
"@
} else {
    $setterLines = ($fieldSpecs | ForEach-Object { "        esistente.set$($_.Pascal)(dati.get$($_.Pascal)());" }) -join "`n"
    if (-not $setterLines) { $setterLines = "        // Nessun campo da FIELDS=: aggiungi qui i tuoi set..." }

    $serviceSrc = @"
package $package.service;

import $package.entity.${Name}Entity;
import $package.repository.${Name}Repository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ${Name}Service {

    private final ${Name}Repository repository;

    public List<${Name}Entity> elenco() {
        return repository.findAll();
    }

    public ${Name}Entity trova(Long id) {
        return repository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "$Name " + id + " non trovato"));
    }

    public ${Name}Entity crea(${Name}Entity nuovo) {
        return repository.save(nuovo);
    }

    // Sovrascrive tutti i campi: per un aggiornamento parziale, togli le
    // righe dei campi che non vuoi toccare.
    public ${Name}Entity aggiorna(Long id, ${Name}Entity dati) {
        ${Name}Entity esistente = trova(id);
$setterLines
        return repository.save(esistente);
    }

    public void elimina(Long id) {
        trova(id); // 404 prima di provare a cancellare, non un 500 a caso
        repository.deleteById(id);
    }
}
"@

    $controllerSrc = @"
package $package.controller;

import $package.entity.${Name}Entity;
import $package.service.${Name}Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// CRUD generato da task new-entity: aggiungi qui le regole della tua
// traccia. Se questi dati li consuma anche un altro servizio (Feign), o non
// vuoi esporre tutti i campi cosi' come sono in tabella, usa DTO=1 oppure sostituisci
// ${Name}Entity con un DTO tuo -- vedi la lezione 9 ("fuori dal servizio
// esce il DTO, mai l'entity") e la lezione 4 su common-dto.
@Tag(name = "$Name", description = "Generato da new-entity: descrivilo meglio")
@RestController
@RequestMapping("/api/$routeBase")
@RequiredArgsConstructor
public class ${Name}Controller {

    private final ${Name}Service service;

    @Operation(summary = "Tutti/e")
    @GetMapping
    public List<${Name}Entity> elenco() {
        return service.elenco();
    }

    @Operation(summary = "Per id (404 se non c'e')")
    @GetMapping("/{id}")
    public ${Name}Entity perId(@PathVariable Long id) {
        return service.trova(id);
    }

    @Operation(summary = "Crea")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ${Name}Entity crea(@Valid @RequestBody ${Name}Entity nuovo) {
        return service.crea(nuovo);
    }

    @Operation(summary = "Aggiorna (404 se non c'e')")
    @PutMapping("/{id}")
    public ${Name}Entity aggiorna(@PathVariable Long id, @Valid @RequestBody ${Name}Entity dati) {
        return service.aggiorna(id, dati);
    }

    @Operation(summary = "Elimina (404 se non c'e')")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
"@
}

Write-TextFile -Path (Join-Path $serviceDir "${Name}Service.java") -Text ($serviceSrc + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/service/${Name}Service.java"

Write-TextFile -Path (Join-Path $controllerDir "${Name}Controller.java") -Text ($controllerSrc + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/controller/${Name}Controller.java"

# --- Riepilogo -----------------------------------------------------------------

Write-Host ''
Write-Host "Fatto: ${Name}Entity in tabella '$tableName', su /api/$routeBase." -ForegroundColor Green
$uniqueFields = @($fieldSpecs | Where-Object { $_.Column -match 'unique = true' } | ForEach-Object { $_.Name })
if ($uniqueFields.Count -gt 0) {
    Write-Host "  'unique' su $($uniqueFields -join ', ') e' solo un vincolo del database: violarlo da' un 500" -ForegroundColor DarkGray
    Write-Host "  finche' non lo controlli tu nel service (es. un existsBy... prima del save)." -ForegroundColor DarkGray
}
Write-Host "  Restano da aggiungere a mano: le relazioni con altre entity, e le regole della traccia." -ForegroundColor DarkGray
Write-Host ''
