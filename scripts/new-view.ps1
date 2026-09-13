<#
.SYNOPSIS
    Genera un Controller Thymeleaf e una vista HTML con tabella e form per un modulo UI.

.DESCRIPTION
    Nei moduli interfaccia (UI), scrivere a mano le pagine Thymeleaf, la tabella
    dinamica, il binding dei form e la gestione degli errori fa perdere tempo.
    Questo comando genera:
      1. Il controller Spring MVC (@Controller) con GET (lista) e POST (salvataggio).
      2. Il template HTML (templates/<nome>.html) con tabella reattiva e form con validazione.

.PARAMETER Service
    Il modulo UI dove inserire la vista (es. event-ui o un modulo creato con UI=1).

.PARAMETER Name
    Nome della vista in PascalCase (es. Libri, Eventi, Prodotti).

.PARAMETER Route
    Percorso URL della pagina (default: /<nome-in-minuscolo>, es. /libri).

.PARAMETER Fields
    Campi della tabella e del form: nome:tipo[:modificatore]*.
    Tipi: string, int, long, decimal, bool, date.
    Modificatori: required, min(N), max(N).
    Se omesso e specificato CLIENT, i campi vengono ricavati automaticamente dal DTO.
    Se omesso senza CLIENT, viene avviato il wizard interattivo (un campo alla volta o tutti insieme).

.PARAMETER Client
    Nome del Feign Client da collegare alla vista (es. LibriClient). Se omesso in un
    terminale interattivo, new-view elenca i client disponibili e propone il collegamento.

.EXAMPLE
    task new-view SERVICE=event-ui NAME=Eventi FIELDS=titolo:string:required,luogo:string,data:date
    task new-view SERVICE=event-ui NAME=Eventi CLIENT=EventiClient
    task new-view SERVICE=wms-ui NAME=Prodotti ROUTE=/prodotti FIELDS=codice:string:required,descrizione:string,quantita:int:min(1)
#>
param(
    [string]$Service = '',
    [string]$Name = '',
    [string]$Route = '',
    [string]$Fields = '',
    [string]$Client = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

# --- Helper Read-Answer (supporta WIZARD_ANSWERS per test automatici) ---
$script:_wizAnswers = $null
if ($env:WIZARD_ANSWERS -and (Test-Path $env:WIZARD_ANSWERS)) {
    $script:_wizAnswers = New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($line in [System.IO.File]::ReadAllLines($env:WIZARD_ANSWERS)) { $script:_wizAnswers.Enqueue($line) }
}
function Read-Answer {
    param([string]$Prompt = '  >')
    if ($null -ne $script:_wizAnswers) {
        if ($script:_wizAnswers.Count -eq 0) { throw 'WIZARD_ANSWERS: le risposte sono finite prima delle domande.' }
        $a = $script:_wizAnswers.Dequeue()
        Write-Host "$Prompt $a"
        return $a
    }
    return (Read-Host $Prompt)
}

$script:_fieldsAskedInWizard = $false

if (-not $Service -or -not $Name) {
    if ([Console]::IsInputRedirected -and $null -eq $script:_wizAnswers) {
        throw "Uso: task new-view SERVICE=<modulo-ui> NAME=<Nome> [ROUTE=<percorso>] [FIELDS=<campi>]`n" +
              "Esempio: task new-view SERVICE=event-ui NAME=Libri FIELDS=titolo:string:required,autore:string,anno:int"
    }

    $uiModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        $p = Join-Path $_.FullName 'pom.xml'
        (Test-Path $p) -and ((Read-TextFile $p) -match 'spring-boot-starter-thymeleaf')
    } | Select-Object -ExpandProperty Name)

    if ($uiModules.Count -eq 0) {
        throw "Non ci sono moduli UI (Thymeleaf) in demo/. Creane uno con task new-service NAME=<nome-ui> UI=1."
    }

    Write-Host ''
    Write-Host 'CREAZIONE VISTA THYMELEAF GUIDATA' -ForegroundColor Cyan
    if (-not $Service) {
        Write-Host "Seleziona il modulo UI:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $uiModules.Count; $i++) {
            Write-Host "  $($i + 1)) $($uiModules[$i])"
        }
        $idx = Read-Answer "  [1] >"
        $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
        $Service = $uiModules[$idxNum - 1]
    }

    if (-not $Name) {
        $Name = (Read-Answer "  Nome della Vista in PascalCase (es. Libri, Eventi, Clienti)").Trim()
        if (-not $Name) {
            throw "Uso: task new-view SERVICE=<modulo-ui> NAME=<Nome> [ROUTE=<percorso>] [FIELDS=<campi>]"
        }
    }

    # FIELDS verrà chiesto DOPO il rilevamento del Feign Client (potrebbe auto-derivarli).
    # Marchiamo il flag per ricordarci di chiedere i campi se non vengono auto-derivati.
    if (-not $Fields) { $script:_fieldsAskedInWizard = $true }
}

# Se SERVICE e NAME erano gia' noti, il flag non e' stato settato sopra:
# lo settiamo qui se FIELDS e' vuoto e abbiamo un contesto interattivo.
if (-not $Fields -and (-not [Console]::IsInputRedirected -or $null -ne $script:_wizAnswers)) {
    $script:_fieldsAskedInWizard = $true
}

if ($Name -cnotmatch '^[A-Z][a-zA-Z0-9]*$') {
    throw "Nome non valido: '$Name'. Usa il PascalCase: Libri, Eventi, Prenotazioni."
}

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/."
}
$pomTextSvc = Read-TextFile (Join-Path $moduleDir 'pom.xml')
if ($pomTextSvc -notmatch 'spring-boot-starter-thymeleaf') {
    throw "'$Service' non e' un modulo UI (non ha spring-boot-starter-thymeleaf).`n" +
          "Crea un modulo UI con: task new-service NAME=<nome> UI=1`n" +
          "oppure usa un modulo gia' creato con UI=1."
}

$slug = $Name.ToLowerInvariant()
$routePath = if ($Route) { $Route } else { "/$slug" }
if (-not $routePath.StartsWith('/')) { $routePath = "/$routePath" }

$package = Get-ModulePackage -Module $Service
$packagePath = $package -replace '\.', '/'
$javaDir = Join-Path $moduleDir "src/main/java/$packagePath"
$controllerDir = Join-Path $javaDir 'controller'
if (-not (Test-Path $controllerDir)) { New-Item -ItemType Directory -Path $controllerDir -Force | Out-Null }

$templatesDir = Join-Path $moduleDir 'src/main/resources/templates'
if (-not (Test-Path $templatesDir)) { New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null }

$controllerName = "${Name}UiController"
$controllerFile = Join-Path $controllerDir "$controllerName.java"
$templateFile = Join-Path $templatesDir "$slug.html"

if (Test-Path $controllerFile) {
    throw "C'e' gia' $controllerFile. Cancellalo prima o scegli un altro nome."
}
if (Test-Path $templateFile) {
    throw "C'e' gia' $templateFile. Cancellalo prima o scegli un altro nome."
}

# --- Rilevamento / Configurazione Client Feign ---
if (-not $Client -and -not [Console]::IsInputRedirected) {
    $existingClients = @(Get-ChildItem -Path (Join-Path $javaDir 'client') -Filter '*Client.java' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName)
    if ($existingClients.Count -eq 1) {
        $cName = $existingClients[0]
        $ans = Read-Host "  Trovato Feign Client '$cName'. Vuoi collegarlo automaticamente alla vista? [S/n] >"
        if ($ans -match '^(s|si|y|yes)?$' -or -not $ans) { $Client = $cName }
    } elseif ($existingClients.Count -gt 1) {
        Write-Host "  Trovati $($existingClients.Count) Feign Client nel modulo. Scegli quale collegare:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $existingClients.Count; $i++) {
            Write-Host "    $($i + 1)) $($existingClients[$i])"
        }
        $cIdx = Read-Host "    [1] (premi Invio per primo, o 'n' per nessuno) >"
        if ($cIdx -match '^\d+$') {
            $Client = $existingClients[[int]$cIdx - 1]
        } elseif ($cIdx -ne 'n') {
            $Client = $existingClients[0]
        }
    }
}

$targetDtoName = $null
$targetDtoPkg = $null
$targetDtoRawParams = $null
$clientFile = $null

if ($Client) {
    $clientFile = Join-Path $javaDir "client/$Client.java"
    if (-not (Test-Path $clientFile)) {
        $candidates = @(Get-ChildItem -Path (Join-Path $javaDir 'client') -Filter "${Client}*.java" -ErrorAction SilentlyContinue)
        if ($candidates.Count -gt 0) { $clientFile = $candidates[0].FullName; $Client = $candidates[0].BaseName }
    }

    if (Test-Path $clientFile) {
        $cContent = Read-TextFile $clientFile
        if ($cContent -match 'create\s*\(\s*@RequestBody\s*(\w+)\s+body\)') {
            $targetDtoName = $Matches[1]
        } elseif ($cContent -match 'List<(\w+)>\s+getAll\(') {
            $targetDtoName = $Matches[1]
        }

        if ($targetDtoName -and $targetDtoName -ne 'Object') {
            $commonDtoDir = Join-Path $demoDir 'common-dto/src/main/java'
            $dtoFiles = @(Get-ChildItem -Path $commonDtoDir -Recurse -Filter "$targetDtoName.java" -ErrorAction SilentlyContinue)
            if ($dtoFiles.Count -gt 0) {
                $dtoContent = Read-TextFile $dtoFiles[0].FullName
                $targetDtoPkg = [regex]::Match($dtoContent, '(?m)^\s*package\s+([\w.]+)\s*;').Groups[1].Value
                if (-not $targetDtoPkg) { $targetDtoPkg = (Get-BasePackage) + '.common.dto' }
                $m = [regex]::Match($dtoContent, 'public\s+record\s+\w+\s*\(([\s\S]*?)\)\s*\{')
                if ($m.Success) {
                    $targetDtoRawParams = $m.Groups[1].Value -split ','
                    if (-not $Fields) {
                        $autoFields = @()
                        foreach ($rp in $targetDtoRawParams) {
                            $rp = $rp.Trim()
                            if (-not $rp) { continue }
                            $cleanP = ($rp -replace '@\w+(\([^)]*\))?', '').Trim()
                            $pTokens = $cleanP -split '\s+'
                            if ($pTokens.Count -lt 2) { continue }
                            $pType = $pTokens[-2].Trim()
                            $pName = $pTokens[-1].Trim()
                            if ($pName -eq 'id') { continue }
                            $fType = 'string'
                            $fMod = ':required'
                            if ($pType -match '^(int|Integer)$') { $fType = 'int' }
                            elseif ($pType -match '^(long|Long)$') { $fType = 'long' }
                            elseif ($pType -match '^(BigDecimal)$') { $fType = 'decimal' }
                            elseif ($pType -match '^(boolean|Boolean)$') { $fType = 'bool'; $fMod = '' }
                            elseif ($pType -match '^(LocalDate)$') { $fType = 'date' }
                            elseif ($pType -match '^(String)$') { $fType = 'string' }
                            else { $fType = 'string'; $fMod = '' }
                            $autoFields += "${pName}:${fType}${fMod}"
                        }
                        if ($autoFields.Count -gt 0) {
                            $Fields = $autoFields -join ','
                            Write-Host "  -> Campi ricavati automaticamente da ${targetDtoName}: $Fields" -ForegroundColor Green
                        }
                    }
                }
            }
        }
    }
}

# --- Wizard interattivo per i campi (se non sono stati specificati / auto-derivati) ---
if ($script:_fieldsAskedInWizard -and -not $Fields) {
    Write-Host ''
    Write-Host '  Come vuoi definire i campi del form e della tabella?' -ForegroundColor DarkGray
    Write-Host '    1) guidato, un campo alla volta (tipo e modificatori da menu)'
    Write-Host '    2) tutti insieme, in una riga (come FIELDS=... da riga di comando)'
    $fieldMode = (Read-Answer "  Modalita' [1]").Trim()
    if ($fieldMode -eq '2') {
        Write-Host '  Esempio: titolo:string:required,autore:string,anno:int:min(1900)' -ForegroundColor DarkGray
        $Fields = (Read-Answer '  Campi').Trim()
        # Invio senza nulla = usa default (nome/descrizione), gestito dopo
    } else {
        $fieldTokens = @()
        while ($true) {
            $fName = (Read-Answer '  Nome campo (Invio per finire)').Trim()
            if (-not $fName) { break }

            Write-Host '    1) string      4) long       7) date'
            Write-Host '    2) string(N)   5) decimal    8) enum(A|B|C)'
            Write-Host '    3) int         6) bool'
            $typeChoice = (Read-Answer '    Tipo [1]').Trim()
            $typeToken = switch ($typeChoice) {
                '2' { "string(" + (Read-Answer '    Lunghezza massima').Trim() + ")" }
                '3' { 'int' }
                '4' { 'long' }
                '5' { 'decimal' }
                '6' { 'bool' }
                '7' { 'date' }
                '8' { "enum(" + (Read-Answer '    Valori separati da | (es. ROSSO|VERDE|BLU)').Trim() + ")" }
                default { 'string' }
            }

            Write-Host '    Modificatori, numeri separati da virgola (Invio per nessuno):'
            Write-Host '      1) required   2) min(N)   3) max(N)   4) unique'
            $modChoice = (Read-Answer '    Modificatori').Trim()
            $mods = @()
            if ($modChoice) {
                foreach ($m in ($modChoice -split ',')) {
                    switch ($m.Trim()) {
                        '1' { $mods += 'required' }
                        '2' { $mods += "min(" + (Read-Answer '      Minimo').Trim() + ")" }
                        '3' { $mods += "max(" + (Read-Answer '      Massimo').Trim() + ")" }
                        '4' { $mods += 'unique' }
                    }
                }
            }

            $token = "${fName}:${typeToken}"
            if ($mods.Count -gt 0) { $token += ':' + ($mods -join ':') }
            $fieldTokens += $token
            Write-Host "    -> $token" -ForegroundColor DarkGray
            Write-Host ''
        }
        $Fields = $fieldTokens -join ','
    }
}

# --- Parsing dei campi ---
$fieldList = @()
if ($Fields) {
    foreach ($raw in ($Fields -split ',')) {
        $raw = $raw.Trim()
        if (-not $raw) { continue }
        $tokens = $raw -split ':'
        $fName = $tokens[0].Trim()
        $fType = if ($tokens.Count -gt 1) { $tokens[1].Trim().ToLowerInvariant() } else { 'string' }
        $required = $false
        $fMin = $null
        $fMax = $null
        if ($tokens.Count -eq 2 -and $tokens[1].Trim() -eq 'required') { $fType = 'string'; $required = $true }
        for ($ti = 2; $ti -lt $tokens.Count; $ti++) {
            $mod = $tokens[$ti].Trim()
            if ($mod -eq 'required') { $required = $true }
            elseif ($mod -match '^min\((-?\d+)\)$') { $fMin = $Matches[1] }
            elseif ($mod -match '^max\((-?\d+)\)$') { $fMax = $Matches[1] }
        }

        $jType = 'String'
        $htmlInput = 'text'
        if ($fType -eq 'int') { $jType = 'Integer'; $htmlInput = 'number' }
        elseif ($fType -eq 'long') { $jType = 'Long'; $htmlInput = 'number' }
        elseif ($fType -eq 'decimal') { $jType = 'java.math.BigDecimal'; $htmlInput = 'number' }
        elseif ($fType -eq 'bool') { $jType = 'Boolean'; $htmlInput = 'checkbox' }
        elseif ($fType -eq 'date') { $jType = 'java.time.LocalDate'; $htmlInput = 'date' }
        elseif ($fType -eq 'email') { $jType = 'String'; $htmlInput = 'email' }

        $fieldList += [pscustomobject]@{
            Name = $fName
            JavaType = $jType
            InputType = $htmlInput
            Required = $required
            Min = $fMin
            Max = $fMax
        }
    }
}
if ($fieldList.Count -eq 0) {
    $fieldList += [pscustomobject]@{ Name = 'nome'; JavaType = 'String'; InputType = 'text'; Required = $true; Min = $null; Max = $null }
    $fieldList += [pscustomobject]@{ Name = 'descrizione'; JavaType = 'String'; InputType = 'text'; Required = $false; Min = $null; Max = $null }
}

$hasClient = $false
$clientInject = ''
$clientCallGetAll = @"
        // Sostituisci questa lista con i dati caricati dal Feign client
        List<${Name}Form> items = new ArrayList<>();
        model.addAttribute("items", items);
"@
$clientCallCreate = @"
        // TODO: Invia 'form' al microservizio corrispondente tramite Feign client
        // client.create(form);
"@
$clientErrorCatch = @"
        if (bindingResult.hasErrors()) {
            model.addAttribute("items", new ArrayList<${Name}Form>());
            return "$slug";
        }
"@

if ($Client -and $clientFile -and (Test-Path $clientFile)) {
    $hasClient = $true
    $clientCamel = $Client.Substring(0, 1).ToLowerInvariant() + $Client.Substring(1)
    $clientInject = "    private final $package.client.$Client $clientCamel;`n"
    $clientCallGetAll = @"
        try {
            model.addAttribute("items", ${clientCamel}.getAll());
        } catch (Exception e) {
            model.addAttribute("items", new ArrayList<>());
            model.addAttribute("errorMessage", "Impossibile recuperare i dati dal microservizio: " + e.getMessage());
        }
"@

    $clientErrorCatch = @"
        if (bindingResult.hasErrors()) {
            try { model.addAttribute("items", ${clientCamel}.getAll()); } catch (Exception e) { model.addAttribute("items", new ArrayList<>()); }
            return "$slug";
        }
"@

    if ($targetDtoName -and $targetDtoRawParams) {
        $argExprs = @()
        foreach ($rp in $targetDtoRawParams) {
            $rp = $rp.Trim()
            if (-not $rp) { continue }
            $pTokens = ($rp -replace '@\w+(\([^)]*\))?', '').Trim() -split '\s+'
            $pName = $pTokens[-1].Trim()
            $pPascal = $pName.Substring(0, 1).ToUpperInvariant() + $pName.Substring(1)
            if ($pName -eq 'id') {
                $argExprs += 'null'
            } elseif ($fieldList | Where-Object { $_.Name -eq $pName }) {
                $argExprs += "form.get$pPascal()"
            } elseif ($pName -in @('disponibile', 'attivo')) {
                $argExprs += 'true'
            } else {
                $argExprs += 'null'
            }
        }
        $dtoArgsStr = ($argExprs | ForEach-Object { "                $_" }) -join ",`n"
        $clientCallCreate = @"
        try {
            ${clientCamel}.create(new ${targetDtoPkg}.$targetDtoName(
$dtoArgsStr
            ));
        } catch (Exception e) {
            model.addAttribute("errorMessage", "Errore nel salvataggio: " + e.getMessage());
            try { model.addAttribute("items", ${clientCamel}.getAll()); } catch (Exception ex) { model.addAttribute("items", new ArrayList<>()); }
            return "$slug";
        }
"@
    }
}

# --- Form DTO static class dentro il Controller ---
$formFieldLines = foreach ($f in $fieldList) {
    $annotations = ''
    if ($f.Required -and $f.JavaType -eq 'String') {
        $annotations += "        @NotBlank(message = `"$($f.Name) e' obbligatorio`")`n"
    } elseif ($f.Required) {
        $annotations += "        @NotNull`n"
    }
    if ($null -ne $f.Min) { $annotations += "        @Min($($f.Min))`n" }
    if ($null -ne $f.Max) { $annotations += "        @Max($($f.Max))`n" }
    "${annotations}        private $($f.JavaType) $($f.Name);"
}
$formFieldsStr = $formFieldLines -join "`n"

$controllerSrc = @"
package $package.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
$(if ($hasClient) { "import lombok.RequiredArgsConstructor;`n" })import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

/**
 * Controller Thymeleaf per la vista $Name ($routePath).
 * Generato da task new-view.
 *
 * Punti di estensione:
 *   - GET  index(): aggiungi filtri, paginazione, o carica dati da piu' sorgenti.
 *   - POST save():  aggiungi logica di business (es. verifica disponibilita', cambio stato).
 *   - Aggiungi @GetMapping("/{id}") per il dettaglio, o @PostMapping("/{id}/cancella") ecc.
 */
@Controller
@RequestMapping("$routePath")$(if ($hasClient) { "`n@RequiredArgsConstructor" })
public class $controllerName {

$clientInject
    @Getter @Setter @NoArgsConstructor
    public static class ${Name}Form {
$formFieldsStr
    }

    @GetMapping
    public String index(Model model) {
$clientCallGetAll
        model.addAttribute("form", new ${Name}Form());
        return "$slug";
    }

    @PostMapping
    public String save(@Valid @ModelAttribute("form") ${Name}Form form,
                       BindingResult bindingResult,
                       Model model) {
$clientErrorCatch
$clientCallCreate
        // TODO: aggiungi qui logica di business specifica della traccia.
        return "redirect:${routePath}?success";
    }
}
"@

Write-TextFile -Path $controllerFile -Text ($controllerSrc.Trim() + "`n")
Write-Step "demo/$Service/src/main/java/$packagePath/controller/$controllerName.java"

# --- Template HTML ---
$thHeaders = ($fieldList | ForEach-Object { "                    <th>$($_.Name.Substring(0,1).ToUpper() + $_.Name.Substring(1))</th>" }) -join "`n"
$thCells = ($fieldList | ForEach-Object { "                    <td th:text=`"`$`{item.$($_.Name)}`">Valore</td>" }) -join "`n"

$formInputs = foreach ($f in $fieldList) {
    $label = $f.Name.Substring(0,1).ToUpper() + $f.Name.Substring(1)
    if ($f.InputType -eq 'checkbox') {
        @"
            <div class="form-group-check">
                <label>
                    <input type="checkbox" th:field="*{$($f.Name)}" />
                    <span>$label</span>
                </label>
            </div>
"@
    } else {
        @"
            <div class="form-group">
                <label for="$($f.Name)">$label</label>
                <input id="$($f.Name)" type="$($f.InputType)" th:field="*{$($f.Name)}" class="form-control" />
                <span class="error-msg" th:if="`$`{#fields.hasErrors('$($f.Name)')}" th:errors="*{$($f.Name)}">Errore</span>
            </div>
"@
    }
}
$formInputsStr = $formInputs -join "`n"

$htmlSrc = @"
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestione $Name</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 2rem; }
        .container { max-width: 900px; margin: 0 auto; }
        .card { background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); padding: 1.5rem; margin-bottom: 2rem; }
        h1, h2 { margin-top: 0; color: #0f172a; }
        table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
        th, td { padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #e2e8f0; }
        th { background: #f1f5f9; font-weight: 600; }
        .form-group { margin-bottom: 1rem; }
        .form-group label { display: block; font-weight: 500; margin-bottom: 0.25rem; }
        .form-control { width: 100%; box-sizing: border-box; padding: 0.5rem 0.75rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 1rem; }
        .error-msg { color: #dc2626; font-size: 0.875rem; margin-top: 0.25rem; display: block; }
        .alert-success { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem; }
        .btn { background: #2563eb; color: white; border: none; padding: 0.6rem 1.25rem; border-radius: 6px; cursor: pointer; font-size: 1rem; font-weight: 500; }
        .btn:hover { background: #1d4ed8; }
        .empty-state { text-align: center; color: #64748b; padding: 2rem 0; }
    </style>
</head>
<body>
<div class="container">
    <div class="card">
        <h1>Gestione $Name</h1>
        <p>Interfaccia generata da <code>task new-view</code>. Collega i dati al Feign Client per visualizzare i record reali.</p>

        <div th:if="`$`{param.success}" class="alert-success">
            Operazione completata con successo!
        </div>

        <div th:if="`$`{errorMessage}" style="background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 0.75rem 1rem; border-radius: 6px; margin-bottom: 1rem;">
            <span th:text="`$`{errorMessage}">Messaggio errore</span>
        </div>

        <h2>Elenco</h2>
        <div th:if="`$`{items != null and !items.isEmpty()}">
            <table>
                <thead>
                <tr>
$thHeaders
                </tr>
                </thead>
                <tbody>
                <tr th:each="item : `$`{items}">
$thCells
                </tr>
                </tbody>
            </table>
        </div>
        <div th:if="`$`{items == null or items.isEmpty()}" class="empty-state">
            Nessun elemento presente.
        </div>
    </div>

    <div class="card">
        <h2>Nuovo Elemento</h2>
        <form th:action="@{$routePath}" th:object="`$`{form}" method="post">
$formInputsStr
            <button type="submit" class="btn">Salva</button>
        </form>
    </div>
</div>
</body>
</html>
"@

Write-TextFile -Path $templateFile -Text ($htmlSrc.Trim() + "`n")
Write-Step "demo/$Service/src/main/resources/templates/$slug.html"
