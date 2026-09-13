<#
.SYNOPSIS
    Genera un gestore globale delle eccezioni (@RestControllerAdvice) per un modulo.

.DESCRIPTION
    Intercetta automaticamente:
      1. Errori di validazione (@Valid e MethodArgumentNotValidException) -> 400 Bad Request
         con mappa "campo: messaggio d'errore".
      2. Eccezioni con stato HTTP (ResponseStatusException, es. 404 Not Found) -> codice relativo.
      3. Eccezioni generiche impreviste -> 500 Internal Server Error con JSON pulito.

.PARAMETER Service
    Nome del modulo (es. catalogo-service, ordini-service).

.EXAMPLE
    task new-handler SERVICE=ordini-service
#>
param(
    [string]$Service = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'

if (-not $Service) {
    if ([Console]::IsInputRedirected) {
        throw "Uso: task new-handler SERVICE=<modulo>"
    }

    $allModules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'pom.xml')) -and ($_.Name -ne 'common-dto')
    } | Select-Object -ExpandProperty Name)

    if ($allModules.Count -eq 0) {
        throw "Non ci sono moduli in demo/."
    }

    Write-Host ''
    Write-Host 'GENERATORE GLOBAL EXCEPTION HANDLER' -ForegroundColor Cyan
    Write-Host "Seleziona il modulo in cui inserire GlobalExceptionHandler:" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $allModules.Count; $i++) {
        Write-Host "  $($i + 1)) $($allModules[$i])"
    }
    $idx = Read-Host "  [1] >"
    $idxNum = if ($idx -match '^\d+$') { [int]$idx } else { 1 }
    $Service = $allModules[$idxNum - 1]
}

$moduleDir = Join-Path $demoDir $Service
if (-not (Test-Path (Join-Path $moduleDir 'pom.xml'))) {
    throw "Non trovo il modulo '$Service' in demo/."
}

$package = Get-ModulePackage -Module $Service
$packagePath = $package -replace '\.', '/'
$controllerDir = Join-Path $moduleDir "src/main/java/$packagePath/controller"
if (-not (Test-Path $controllerDir)) {
    New-Item -ItemType Directory -Path $controllerDir -Force | Out-Null
}

$handlerFile = Join-Path $controllerDir 'GlobalExceptionHandler.java'
if (Test-Path $handlerFile) {
    Write-Host "  GlobalExceptionHandler gia' presente in $Service." -ForegroundColor Yellow
    exit 0
}

$code = @"
package $package.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Gestore centralizzato delle eccezioni generato da task new-handler.
 * Trasforma errori di validazione (@Valid), 404 e 500 in risposte JSON strutturate.
 *
 * Punti di estensione per la traccia d'esame:
 *   - Aggiungi @ExceptionHandler per eccezioni di business custom (es. PostiEsauritiException.class)
 *   - Aggiungi @ExceptionHandler per feign.FeignException per intercettare errori da altri microservizi
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    // TODO: Aggiungi qui gestori per eccezioni di business specifiche della tua traccia:
    // @ExceptionHandler(PostiEsauritiException.class)
    // public ResponseEntity<Map<String, Object>> handleCustom(PostiEsauritiException ex) { ... }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            errors.put(error.getField(), error.getDefaultMessage());
        }

        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("error", "Bad Request");
        body.put("message", "Errori di validazione sui campi della richiesta");
        body.put("details", errors);

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatusException(ResponseStatusException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", ex.getStatusCode().value());
        body.put("error", ex.getStatusCode().toString());
        body.put("message", ex.getReason());

        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
        body.put("error", "Internal Server Error");
        body.put("message", ex.getMessage() != null ? ex.getMessage() : "Errore interno imprevisto");

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }
}
"@

Write-TextFile -Path $handlerFile -Text $code
Write-Step "demo/$Service/src/main/java/$packagePath/controller/GlobalExceptionHandler.java"
Write-Host ''
Write-Host "GlobalExceptionHandler generato con successo per '$Service'." -ForegroundColor Green
Write-Host ''
