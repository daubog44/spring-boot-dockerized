<#
.SYNOPSIS
    Genera un client OpenFeign per chiamare un altro microservizio via Eureka.

.DESCRIPTION
    Nei microservizi i moduli comunicano via HTTP con OpenFeign risolvendo i nomi
    tramite Eureka (nessun IP cablato). Questo comando genera l'interfaccia
    @FeignClient nel modulo chiamante (FROM), gia' collegata al nome logico del
    servizio target (TO) e con i metodi REST pronti.

.PARAMETER From
    Modulo chiamante, es. prestiti-service o event-ui.

.PARAMETER To
    Modulo da chiamare, es. catalogo-service.

.PARAMETER Name
    Nome dell'interfaccia client (default: derivato da TO, es. CatalogoClient).

.PARAMETER Dto
    Nome della classe DTO da usare per richieste e risposte (es. LibroDto).
    Viene importata automaticamente da common-dto se esiste.

.PARAMETER Path
    Prefisso della rotta REST sul servizio target (default: /api/<risorsa> o /api).

.EXAMPLE
    task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto
    task new-client FROM=event-ui TO=store-service ROUTE=/api/suggerimenti
#>
param(
    [string]$From = '',
    [string]$To = '',
    [string]$Name = '',
    [string]$Dto = '',
    [string]$Path = '',
    [string]$Fields = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

if (-not $From -or -not $To) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task new-client FROM=<modulo-chiamante> TO=<modulo-target> [DTO=<NomeDto>] [FIELDS=<campi>] [NAME=<ClientName>] [ROUTE=<rotta>]`n" +
              "Esempio: task new-client FROM=prestiti-service TO=catalogo-service DTO=LibroDto FIELDS=id:long,titolo:string:required"
    }

    $allModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'pom.xml')) -and ($_.Name -ne 'common-dto')
    } | Select-Object -ExpandProperty Name)

    if ($allModules.Count -lt 2) {
        throw "Servono almeno due moduli in demo/ per collegare un client OpenFeign."
    }

    Write-Host ''
    Write-Host 'CREAZIONE OPENFEIGN CLIENT GUIDATA' -ForegroundColor Cyan
    if (-not $From) {
        Write-Host "Seleziona il modulo CHIAMANTE (da dove parte la chiamata):" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $allModules.Count; $i++) {
            Write-Host "  $($i + 1)) $($allModules[$i])"
        }
        $idx = Read-Host "  [1] >"
        $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
        $From = $allModules[$idxNum - 1]
    }

    if (-not $To) {
        $targets = @($allModules | Where-Object { $_ -ne $From })
        Write-Host "Seleziona il modulo TARGET (chi risponde):" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $targets.Count; $i++) {
            Write-Host "  $($i + 1)) $($targets[$i])"
        }
        $idx = Read-Host "  [1] >"
        $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
        $To = $targets[$idxNum - 1]
    }

    if (-not $Dto) {
        $Dto = (Read-Host "  Nome DTO scambiato (es. LibroDto, OrdineDto)").Trim()
    }
}

$fromDir = Join-Path $demoDir $From
if (-not (Test-Path (Join-Path $fromDir 'pom.xml'))) {
    throw "Non trovo il modulo chiamante '$From' in demo/."
}
$toDir = Join-Path $demoDir $To
if (-not (Test-Path (Join-Path $toDir 'pom.xml'))) {
    throw "Non trovo il modulo target '$To' in demo/."
}

# Ricava il nome registrato su Eureka da application.yml del target
$eurekaName = $To.ToUpperInvariant()
$toYml = Join-Path $toDir 'src/main/resources/application.yml'
if (Test-Path $toYml) {
    $hit = [regex]::Match((Read-TextFile $toYml), '(?m)^\s+name:\s*(\S+)')
    if ($hit.Success) { $eurekaName = $hit.Groups[1].Value.ToUpperInvariant() }
}

# Nome del client in PascalCase
function Convert-ToPascal {
    param([string]$Text)
    $clean = $Text -replace '[^a-zA-Z0-9]+', ' '
    $words = $clean -split '\s+' | Where-Object { $_ }
    $res = foreach ($w in $words) { $w.Substring(0, 1).ToUpperInvariant() + $w.Substring(1).ToLowerInvariant() }
    return ($res -join '')
}

$clientName = if ($Name) {
    $Name
} else {
    $baseName = $To -replace '-(service|app|api)$', ''
    (Convert-ToPascal $baseName) + 'Client'
}

# Se non specificato, cerca rotta e DTO dai controller del target
$routePath = $Path
$dtoName = $Dto

if (-not $routePath) {
    $toControllers = @(Get-ChildItem -Path (Join-Path $toDir 'src/main/java') -Recurse -Filter '*Controller.java' -ErrorAction SilentlyContinue)
    foreach ($c in $toControllers) {
        $cText = Read-TextFile $c.FullName
        $m = [regex]::Match($cText, '@RequestMapping\s*\(\s*(?:(?:value|path)\s*=\s*)?"([^"]+)"\s*\)')
        if ($m.Success -and $m.Groups[1].Value -ne '/api/ping') {
            $routePath = $m.Groups[1].Value
            break
        }
    }
    if (-not $routePath) { $routePath = '/api' }
}

if (-not $dtoName) {
    if ($Fields) {
        $targetBase = $To -replace '-(service|app|api)$', ''
        $dtoName = (Convert-ToPascal $targetBase) + 'Dto'
    } else {
        $basePkg = Get-BasePackage
        $basePkgPath = $basePkg -replace '\.', '/'
        $commonDtoDir = Join-Path $demoDir "common-dto/src/main/java/$basePkgPath/common/dto"

        $routeToken = ($routePath.Trim('/') -split '/')[-1]
        $routeDto = (Convert-ToPascal $routeToken) + 'Dto'
        $targetBase = $To -replace '-(service|app|api)$', ''
        $candidateDto = (Convert-ToPascal $targetBase) + 'Dto'

        if (Test-Path (Join-Path $commonDtoDir "$routeDto.java")) {
            $dtoName = $routeDto
        } elseif (Test-Path (Join-Path $commonDtoDir "$candidateDto.java")) {
            $dtoName = $candidateDto
        } else {
            $dtoName = 'Object'
        }
    }
}

# Auto-generazione DTO in common-dto se sono forniti FIELDS o se il DTO indicato non esiste ancora
if ($dtoName -ne 'Object') {
    $basePkg = Get-BasePackage
    $basePkgPath = $basePkg -replace '\.', '/'
    $dtoFile = Join-Path $demoDir "common-dto/src/main/java/$basePkgPath/common/dto/$dtoName.java"
    if ($Fields -or (-not (Test-Path $dtoFile))) {
        $cleanDtoBase = $dtoName -replace '(?i)dto$', ''
        $dtoParams = @{ Name = $cleanDtoBase }
        if ($Fields) { $dtoParams['Fields'] = $Fields }
        & (Join-Path $PSScriptRoot 'new-dto.ps1') @dtoParams | Out-Null
    }
}

$fromPkg = Get-ModulePackage -Module $From
$fromPkgPath = $fromPkg -replace '\.', '/'
$clientDir = Join-Path $fromDir "src/main/java/$fromPkgPath/client"
if (-not (Test-Path $clientDir)) { New-Item -ItemType Directory -Path $clientDir -Force | Out-Null }

$clientFile = Join-Path $clientDir "$clientName.java"
if (Test-Path $clientFile) {
    throw "C'e' gia' $clientFile. Cancellalo prima, o specifica NAME=<AltroNome>."
}

$basePkg = Get-BasePackage -RepoRoot $repoRoot
$dtoImport = if ($dtoName -ne 'Object') { "import $basePkg.common.dto.$dtoName;`n" } else { "" }
$contextId = $clientName.Substring(0, 1).ToLowerInvariant() + $clientName.Substring(1)

$clientSrc = @"
package $fromPkg.client;

${dtoImport}import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * Client OpenFeign per comunicare con $eurekaName via Eureka.
 * Generato da task new-client.
 */
@FeignClient(name = "$eurekaName", contextId = "$contextId")
public interface $clientName {

    @GetMapping("$routePath")
    List<$dtoName> getAll();

    @GetMapping("$routePath/{id}")
    $dtoName getById(@PathVariable("id") Long id);

    @PostMapping("$routePath")
    $dtoName create(@RequestBody $dtoName body);

    @PutMapping("$routePath/{id}")
    $dtoName update(@PathVariable("id") Long id, @RequestBody $dtoName body);

    @DeleteMapping("$routePath/{id}")
    void delete(@PathVariable("id") Long id);
}
"@

Write-TextFile -Path $clientFile -Text ($clientSrc.Trim() + "`n")
Write-Step "demo/$From/src/main/java/$fromPkgPath/client/$clientName.java"
