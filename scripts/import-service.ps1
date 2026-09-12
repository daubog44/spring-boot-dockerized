<#
.SYNOPSIS
    Importa un microservizio da uno zip o una cartella esistente e lo collega a Eureka e allo stack.

.DESCRIPTION
    Nelle prove d'esame viene spesso fornito un semilavorato (un file .zip o una
    cartella) con un microservizio mock o read-only. Questo comando:
      1. Estrae lo zip o copia la cartella in demo/<nome-modulo>
      2. Pulisce file temporanei (target/, .settings/, .project, etc.)
      3. Aggiunge le dipendenze Eureka Client e SpringDoc OpenAPI al pom.xml se mancanti
      4. Configura application.yml/properties con il collegamento a Eureka
      5. Registra il modulo in demo/pom.xml, Dockerfile, docker-compose.yml
      6. Aggiunge il servizio a scripts/dev.ps1 e dev.sh
      7. Sincronizza la configurazione degli editor (ide-sync)

.PARAMETER Src
    Percorso del file .zip o della cartella del servizio da importare.

.PARAMETER Name
    Nome del modulo di destinazione in demo/ (default: derivato da Src).

.PARAMETER Port
    Porta del servizio (default: letta da application.yml/properties o prima libera).

.EXAMPLE
    task import-service SRC="C:\percorso\prestazioni-service.zip"
    task import-service SRC="../forniti/catalogo-mock" NAME=catalogo-service PORT=8082
#>
param(
    [string]$Src = '',
    [string]$Name = '',
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$devPs1 = Join-Path $PSScriptRoot 'dev.ps1'
$devSh = Join-Path $PSScriptRoot 'dev.sh'

if (-not $Src) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task import-service SRC=<file.zip|cartella> [NAME=<nome-modulo>] [PORT=<porta>]"
    }
    Write-Host ''
    Write-Host 'IMPORTAZIONE MICROSERVIZIO ESISTENTE' -ForegroundColor Cyan
    $Src = (Read-Host "  Percorso del file .zip o cartella da importare").Trim()
    if (-not $Src) {
        throw "Uso: task import-service SRC=<file.zip|cartella> [NAME=<nome-modulo>] [PORT=<porta>]"
    }
    $nInput = (Read-Host "  Nome del modulo in demo/ (premi Invio per dedurlo dal nome file)").Trim()
    if ($nInput) { $Name = $nInput }
    $pInput = (Read-Host "  Porta specifica (premi Invio per usare quella del servizio o prima libera)").Trim()
    if ($pInput -match '^\d+$') { $Port = [int]$pInput }
}

$Src = $Src.Trim('"').Trim("'")
if (-not (Test-Path $Src)) {
    throw "File o cartella sorgente non trovato: $Src"
}

# --- 1. Determinazione Nome Modulo --------------------------------------------

$isZip = [System.IO.Path]::GetExtension($Src).ToLowerInvariant() -eq '.zip'
if (-not $Name) {
    if ($isZip) {
        $Name = [System.IO.Path]::GetFileNameWithoutExtension($Src).ToLowerInvariant()
    } else {
        $Name = (Split-Path -Leaf $Src).ToLowerInvariant()
    }
}
$Name = $Name -replace '[^a-z0-9_-]', '-' -replace '_', '-' -replace '-+', '-' -replace '^-', '' -replace '-$', ''
if (-not $Name) { throw "Impossibile ricavare un nome valido per il modulo da: $Src" }

$module = $Name
$moduleDir = Join-Path $demoDir $module
if (Test-Path $moduleDir) {
    throw "La cartella demo/$module esiste gia'. Rimuovila prima o usa un altro nome (NAME=...)."
}

Write-Host ''
Write-Host "==> Importazione di '$module' da $Src" -ForegroundColor Cyan

# --- 2. Estrazione o Copia ----------------------------------------------------

New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

if ($isZip) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ("import_" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Src, $tempExtract)
        # Se c'e' una sola sottocartella radice che contiene tutto, scendiamo di un livello
        $children = @(Get-ChildItem -Path $tempExtract)
        $effectiveSource = $tempExtract
        if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
            $effectiveSource = $children[0].FullName
        }
        Copy-Item -Path "$effectiveSource\*" -Destination $moduleDir -Recurse -Force
    } finally {
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
} else {
    Copy-Item -Path "$Src\*" -Destination $moduleDir -Recurse -Force
}

# Pulizia cartelle di build o metadati IDE
@('target', '.settings', '.idea', '.vscode', '.factorypath', '.project', '.classpath') | ForEach-Object {
    $junk = Join-Path $moduleDir $_
    if (Test-Path $junk) { Remove-Item -Path $junk -Recurse -Force -ErrorAction SilentlyContinue }
}

$pomPath = Join-Path $moduleDir 'pom.xml'
if (-not (Test-Path $pomPath)) {
    throw "Il progetto importato non contiene un pom.xml alla radice di demo/$module."
}
Write-Step "sorgenti estratti in demo/$module"

# --- 3. Determinazione Porta --------------------------------------------------

$ymlPath = Join-Path $moduleDir 'src/main/resources/application.yml'
$yamlPath = Join-Path $moduleDir 'src/main/resources/application.yaml'
$propPath = Join-Path $moduleDir 'src/main/resources/application.properties'

$detectedPort = 0
if (Test-Path $ymlPath) {
    $hit = [regex]::Match((Read-TextFile $ymlPath), '(?m)^\s*port:\s*(\d+)')
    if ($hit.Success) { $detectedPort = [int]$hit.Groups[1].Value }
} elseif (Test-Path $yamlPath) {
    $hit = [regex]::Match((Read-TextFile $yamlPath), '(?m)^\s*port:\s*(\d+)')
    if ($hit.Success) { $detectedPort = [int]$hit.Groups[1].Value }
} elseif (Test-Path $propPath) {
    $hit = [regex]::Match((Read-TextFile $propPath), '(?m)^\s*server\.port\s*=\s*(\d+)')
    if ($hit.Success) { $detectedPort = [int]$hit.Groups[1].Value }
}

if ($Port -gt 0) {
    $finalPort = $Port
} elseif ($detectedPort -gt 0) {
    $finalPort = $detectedPort
} else {
    # Prima porta libera da 8082 in poi
    $used = @()
    foreach ($hit in ([regex]'Port\s*=\s*(\d+)').Matches((Read-TextFile $devPs1))) {
        $used += [int]$hit.Groups[1].Value
    }
    $finalPort = 8082
    while ($used -contains $finalPort) { $finalPort++ }
}

# --- 4. Adattamento pom.xml per Eureka e SpringDoc ----------------------------

$pomText = Read-TextFile $pomPath

# Verifica dipendenza Eureka Client
if ($pomText -notmatch 'spring-cloud-starter-netflix-eureka-client') {
    $eurekaDep = @"
		<dependency>
			<groupId>org.springframework.cloud</groupId>
			<artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
		</dependency>
"@
    Add-LinesBefore -Path $pomPath -Anchor '^\s*</dependencies>' -NewLines @($eurekaDep)
    Write-Step "pom.xml: aggiunta dipendenza spring-cloud-starter-netflix-eureka-client"
    $pomText = Read-TextFile $pomPath
}

# Verifica dipendenza SpringDoc OpenAPI
if ($pomText -notmatch 'springdoc-openapi-starter-webmvc-ui') {
    $swaggerDep = @"
		<dependency>
			<groupId>org.springdoc</groupId>
			<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
			<version>2.8.5</version>
		</dependency>
"@
    Add-LinesBefore -Path $pomPath -Anchor '^\s*</dependencies>' -NewLines @($swaggerDep)
    Write-Step "pom.xml: aggiunta dipendenza springdoc-openapi-starter-webmvc-ui"
    $pomText = Read-TextFile $pomPath
}

# Verifica dependencyManagement per Spring Cloud
if ($pomText -notmatch 'spring-cloud-dependencies') {
    if ($pomText -notmatch '<spring-cloud\.version>') {
        if ($pomText -match '<properties>') {
            Add-LinesBefore -Path $pomPath -Anchor '^\s*</properties>' -NewLines @("		<spring-cloud.version>2025.1.2</spring-cloud.version>")
        }
    }
    $depMgmt = @"
	<dependencyManagement>
		<dependencies>
			<dependency>
				<groupId>org.springframework.cloud</groupId>
				<artifactId>spring-cloud-dependencies</artifactId>
				<version>`${spring-cloud.version:2025.1.2}</version>
				<type>pom</type>
				<scope>import</scope>
			</dependency>
		</dependencies>
	</dependencyManagement>
"@
    Add-LinesBefore -Path $pomPath -Anchor '^\s*</project>' -NewLines @($depMgmt)
    Write-Step "pom.xml: aggiunto dependencyManagement per Spring Cloud"
}

# --- 5. Configurazione Eureka e Porte nei file application.yml/properties -----

$activeConfigFile = $null
if (Test-Path $ymlPath) { $activeConfigFile = $ymlPath }
elseif (Test-Path $yamlPath) { $activeConfigFile = $yamlPath }

if ($activeConfigFile) {
    $cfgText = Read-TextFile $activeConfigFile
    $appName = ($module.ToUpper())
    if ($cfgText -match '(?m)^\s*application:\s*[\r\n]+\s*name:\s*([^\r\n]+)') {
        # gia' presente
    } elseif ($cfgText -match '(?m)^\s*spring\.application\.name:\s*([^\r\n]+)') {
        # gia' presente
    } else {
        $cfgText = "spring.application.name: $appName`n" + $cfgText
    }

    # Configura server.port dinamica se cablata fissa
    if ($cfgText -match '(?m)^\s*port:\s*\d+\s*$') {
        $cfgText = [regex]::Replace($cfgText, '(?m)^\s*port:\s*\d+\s*$', "  port: `${SERVER_PORT:$finalPort}")
    } elseif ($cfgText -notmatch 'server:\s*[\r\n]+\s*port:') {
        $cfgText = "server:`n  port: `${SERVER_PORT:$finalPort}`n" + $cfgText
    }

    # Blocco Eureka
    if ($cfgText -notmatch 'eureka:') {
        $eurekaBlock = @"

eureka:
  client:
    service-url:
      defaultZone: `${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
    registry-fetch-interval-seconds: 5
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 5
    lease-expiration-duration-in-seconds: 15

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
"@
        $cfgText = $cfgText.TrimEnd() + "`n" + $eurekaBlock + "`n"
    }
    Write-TextFile -Path $activeConfigFile -Text $cfgText
    Write-Step "application.yml: configurato Eureka client e porta $finalPort"
} elseif (Test-Path $propPath) {
    $cfgText = Read-TextFile $propPath
    if ($cfgText -notmatch 'eureka\.client') {
        $eurekaBlock = @"

# Eureka & OpenAPI
server.port=`${SERVER_PORT:$finalPort}
spring.application.name=${module}
eureka.client.service-url.defaultZone=`${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
eureka.client.registry-fetch-interval-seconds=5
eureka.instance.prefer-ip-address=true
eureka.instance.lease-renewal-interval-in-seconds=5
eureka.instance.lease-expiration-duration-in-seconds=15
springdoc.api-docs.path=/v3/api-docs
springdoc.swagger-ui.path=/swagger-ui.html
"@
        $cfgText = $cfgText.TrimEnd() + "`n" + $eurekaBlock + "`n"
        Write-TextFile -Path $propPath -Text $cfgText
        Write-Step "application.properties: configurato Eureka client e porta $finalPort"
    }
} else {
    $resDir = Join-Path $moduleDir 'src/main/resources'
    New-Item -ItemType Directory -Path $resDir -Force | Out-Null
    $newYml = @"
server:
  port: `${SERVER_PORT:$finalPort}

spring:
  application:
    name: $($module.ToUpper())

eureka:
  client:
    service-url:
      defaultZone: `${EUREKA_SERVER_URL:http://localhost:8761/eureka/}
    registry-fetch-interval-seconds: 5
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 5
    lease-expiration-duration-in-seconds: 15

springdoc:
  api-docs:
    path: /v3/api-docs
  swagger-ui:
    path: /swagger-ui.html
"@
    Write-TextFile -Path (Join-Path $resDir 'application.yml') -Text $newYml
    Write-Step "creato application.yml con configurazione Eureka e porta $finalPort"
}

# --- 6. pom aggregatore, demo/Dockerfile, docker-compose.yml -------------------

$aggregatorPom = Join-Path $demoDir 'pom.xml'
if ((Read-TextFile $aggregatorPom) -notmatch "<module>$module</module>") {
    Add-LinesBefore -Path $aggregatorPom -Anchor '^\s*</modules>' -NewLines @("        <module>$module</module>")
    Write-Step "demo/pom.xml: registrato modulo <module>$module</module>"
}

$rootDockerfile = Join-Path $demoDir 'Dockerfile'
if (Test-Path $rootDockerfile) {
    $dfText = Read-TextFile $rootDockerfile
    if ($dfText -notmatch "COPY $module/pom\.xml $module/pom\.xml") {
        Add-LinesAfterLast -Path $rootDockerfile -Anchor '^COPY .+/pom\.xml .+/pom\.xml$' -NewLines @("COPY $module/pom.xml $module/pom.xml")
        Write-Step "demo/Dockerfile: aggiunta riga COPY $module/pom.xml"
    }
}

$compose = Join-Path $demoDir 'docker-compose.yml'
if (Test-Path $compose) {
    $compText = Read-TextFile $compose
    if ($compText -notmatch "^\s*${module}:") {
        $composeBlock = @(
            "  ${module}:"
            '    build:'
            '      context: .'
            '      args:'
            "        MODULE: $module"
            '    environment:'
            "      SERVER_PORT: $finalPort"
            '      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/'
            '    ports:'
            "      - ""${finalPort}:${finalPort}"""
            '    depends_on:'
            '      eureka-server:'
            '        condition: service_healthy'
        )
        $composeLines = @(Split-TextLines $compText)
        $volumesIdx = Find-LineIndex -Lines $composeLines -Pattern '^volumes:'
        if ($volumesIdx -ge 0) {
            Add-LinesAt -Path $compose -Index $volumesIdx -NewLines ($composeBlock + @(''))
        } else {
            $tail = $composeLines.Count
            while ($tail -gt 0 -and [string]::IsNullOrWhiteSpace($composeLines[$tail - 1])) { $tail-- }
            Add-LinesAt -Path $compose -Index $tail -NewLines (@('') + $composeBlock)
        }
        Write-Step "demo/docker-compose.yml: aggiunto container $module sulla porta $finalPort"
    }
}

# --- 7. Registrazione in dev.ps1 e dev.sh --------------------------------------

$short = Get-ModuleShortName -Module $module

if ((Read-TextFile $devPs1) -notmatch "Module\s*=\s*'$module'") {
    $devLine = "    [pscustomobject]@{{ Name = {0,-14} Module = {1,-18} Port = {2} }}" -f "'$short';", "'$module';", $finalPort
    Add-LinesBefore -Path $devPs1 -Start '^\$services = @\(' -Anchor '^\)' -NewLines @($devLine)
    Write-Step ("scripts/dev.ps1: registrato {0} -> {1}:{2}" -f $short, $module, $finalPort)
}

if (Test-Path $devSh) {
    if ((Read-TextFile $devSh) -notmatch ":${module}:") {
        Add-LinesBefore -Path $devSh -Start '^SERVICES=\(' -Anchor '^\)' -NewLines @("  ""${short}:${module}:${finalPort}""")
        Write-Step ("scripts/dev.sh: registrato {0} -> {1}:{2}" -f $short, $module, $finalPort)
    }
}

# --- 8. ide-sync --------------------------------------------------------------

& (Join-Path $PSScriptRoot 'ide-sync.ps1') | Out-Null
Write-Step 'configurazione editor sincronizzata (ide-sync)'

Write-Host ''
Write-Host "Modulo '$module' importato con successo su porta $finalPort!" -ForegroundColor Green
Write-Host ''
Write-Host "  Swagger UI: http://localhost:$finalPort/swagger-ui.html"
Write-Host "  Eureka:     http://localhost:8761"
Write-Host ''
Write-Host "Per avviarlo assieme agli altri:"
Write-Host "  task dev" -ForegroundColor Cyan
Write-Host ''
