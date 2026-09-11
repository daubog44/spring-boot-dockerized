<#
.SYNOPSIS
    Collaudo end-to-end della traccia Biblioteca: tutti i flussi, anche
    quelli che devono dire di no.

.DESCRIPTION
    Da lanciare con lo stack acceso, in locale (task dev) o in Docker
    (task docker-up): le porte sono le stesse. Stampa una riga per prova e
    alla fine il conto; esce con 1 se qualcosa non va.

    Non dipende dai dati di prova: sceglie da solo un libro disponibile e
    senza prestiti in corso, e controlla la penale di ogni prestito con la
    formula della traccia.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
#>
param(
    [int]$UiPort = 8090,
    [int]$CatalogoPort = 8081,
    [int]$PrestitiPort = 8082,
    [int]$EurekaPort = 8761
)

$ErrorActionPreference = 'Stop'
$ok = 0
$ko = 0
$catalogo = "http://localhost:$CatalogoPort"
$prestiti = "http://localhost:$PrestitiPort"
$ui = "http://localhost:$UiPort"

function Test-Step {
    param([string]$Label, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:ok++
        Write-Host ('  OK   {0}  {1}' -f $Label, $Detail) -ForegroundColor Green
    } else {
        $script:ko++
        Write-Host ('  NO   {0}  {1}' -f $Label, $Detail) -ForegroundColor Red
    }
}

# Il codice HTTP e il JSON della risposta, anche quando e' un errore.
function Invoke-Api {
    param([string]$Method, [string]$Url, $Body = $null)
    $params = @{ Method = $Method; Uri = $Url; UseBasicParsing = $true; TimeoutSec = 30 }
    if ($null -ne $Body) {
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json))
        $params.ContentType = 'application/json; charset=utf-8'
    }
    try {
        $r = Invoke-WebRequest @params
        # Con un tipo che non conosce (l'actuator risponde
        # application/vnd.spring-boot.actuator.v3+json) PowerShell 5.1 da' i byte.
        $text = if ($r.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($r.Content) } else { $r.Content }
        $json = if ($text) { $text | ConvertFrom-Json } else { $null }
        return [pscustomobject]@{ Code = [int]$r.StatusCode; Json = $json }
    } catch {
        $response = $_.Exception.Response
        $code = if ($response) { [int]$response.StatusCode } else { 0 }
        return [pscustomobject]@{ Code = $code; Json = $null }
    }
}

Write-Host ''
Write-Host 'COLLAUDO DELLA BIBLIOTECA' -ForegroundColor Cyan
Write-Host ''

# --- Eureka conosce tutti? ---------------------------------------------------
$attesi = @('BIBLIOTECA-UI', 'CATALOGO-SERVICE', 'PRESTITI-SERVICE')
$apps = @()
for ($i = 0; $i -lt 60; $i++) {
    try {
        $reg = Invoke-RestMethod -Uri "http://localhost:$EurekaPort/eureka/apps" -Headers @{ Accept = 'application/json' } -TimeoutSec 5
        $apps = @($reg.applications.application | ForEach-Object { $_.name })
    } catch { $apps = @() }
    if (@($attesi | Where-Object { $apps -notcontains $_ }).Count -eq 0) { break }
    Start-Sleep -Seconds 2
}
Test-Step 'Eureka conosce i tre servizi' (@($attesi | Where-Object { $apps -notcontains $_ }).Count -eq 0) (($apps | Sort-Object) -join ' ')
# I client Feign rileggono il registro ogni 5 secondi: un giro di margine.
Start-Sleep -Seconds 12

foreach ($port in @($EurekaPort, $CatalogoPort, $PrestitiPort, $UiPort)) {
    $h = Invoke-Api GET "http://localhost:$port/actuator/health"
    Test-Step "health :$port" ($h.Code -eq 200 -and $h.Json.status -eq 'UP') ([string]$h.Json.status)
}

# --- Il catalogo -----------------------------------------------------------------
$libri = @((Invoke-Api GET "$catalogo/api/libri").Json)
Test-Step 'catalogo: ci sono i libri dei dati di prova' ($libri.Count -ge 5) "$($libri.Count) libri"
Test-Step 'catalogo: un libro inesistente e'' un 404' ((Invoke-Api GET "$catalogo/api/libri/999999").Code -eq 404)

# Un libro disponibile e senza prestiti in corso: i dati di prova non
# conoscono la regola che attraversa i due servizi, quindi lo cerchiamo.
$inCorso = @((Invoke-Api GET "$prestiti/api/prestiti").Json | Where-Object { $_.stato -eq 'IN_CORSO' } | ForEach-Object { $_.libroId })
$libro = $libri | Where-Object { $_.disponibile -and ($inCorso -notcontains $_.id) } | Select-Object -First 1
Test-Step 'catalogo: c''e'' un libro da prestare' ($null -ne $libro) $(if ($libro) { "id $($libro.id)" } else { '' })

if ($libro) {
    # --- Un prestito, e i suoi no ---------------------------------------------------
    $r = Invoke-Api POST "$prestiti/api/prestiti" @{ libroId = $libro.id; utenteEmail = 'mario@esempio.it'; giorni = 14 }
    Test-Step 'prestiti: POST -> 201 (Feign verso il catalogo)' ($r.Code -eq 201) "HTTP $($r.Code)"
    $prestitoId = $r.Json.id
    Test-Step 'prestiti: scadenza a 14 giorni' ($r.Json.dataScadenza -eq (Get-Date).AddDays(14).ToString('yyyy-MM-dd')) ([string]$r.Json.dataScadenza)
    $d = (Invoke-Api GET "$catalogo/api/libri/$($libro.id)").Json.disponibile
    Test-Step 'catalogo: il libro prestato non e'' piu'' disponibile' ($d -eq $false) "disponibile=$d"

    $r = Invoke-Api POST "$prestiti/api/prestiti" @{ libroId = $libro.id; utenteEmail = 'anna@esempio.it' }
    Test-Step 'prestiti: lo stesso libro due volte -> 409' ($r.Code -eq 409) "HTTP $($r.Code)"
    $r = Invoke-Api POST "$prestiti/api/prestiti" @{ libroId = 999999; utenteEmail = 'anna@esempio.it' }
    Test-Step 'prestiti: un libro inesistente -> 404' ($r.Code -eq 404) "HTTP $($r.Code)"
    $r = Invoke-Api POST "$prestiti/api/prestiti" @{ libroId = $libro.id; utenteEmail = 'non-una-email' }
    Test-Step 'prestiti: un''email non valida -> 400' ($r.Code -eq 400) "HTTP $($r.Code)"
    $r = Invoke-Api POST "$prestiti/api/prestiti" @{ libroId = $libro.id; utenteEmail = 'anna@esempio.it'; giorni = 90 }
    Test-Step 'prestiti: piu'' di 60 giorni -> 400' ($r.Code -eq 400) "HTTP $($r.Code)"

    # --- La restituzione ---------------------------------------------------------------
    $r = Invoke-Api PUT "$prestiti/api/prestiti/$prestitoId/restituzione"
    Test-Step 'prestiti: restituzione -> 200' ($r.Code -eq 200 -and $r.Json.stato -eq 'RESTITUITO') "HTTP $($r.Code)"
    $d = (Invoke-Api GET "$catalogo/api/libri/$($libro.id)").Json.disponibile
    Test-Step 'catalogo: il libro restituito torna disponibile' ($d -eq $true) "disponibile=$d"
    $r = Invoke-Api PUT "$prestiti/api/prestiti/$prestitoId/restituzione"
    Test-Step 'prestiti: restituire due volte -> 409' ($r.Code -eq 409) "HTTP $($r.Code)"
}

# --- La penale, con la formula della traccia ---------------------------------------
$elenco = @((Invoke-Api GET "$prestiti/api/prestiti").Json)
$sbagliate = @($elenco | Where-Object {
        $attesa = [math]::Min(0.5 * [double]$_.giorniRitardo, 20.0)
        [math]::Abs([double]$_.penale - $attesa) -gt 0.001 -or $_.giorniRitardo -lt 0
    })
Test-Step 'prestiti: penale = min(0,50 x ritardo; 20) per ogni prestito' ($elenco.Count -gt 0 -and $sbagliate.Count -eq 0) "$($elenco.Count) prestiti"
$conTitolo = @($elenco | Where-Object { $_.titoloLibro -and -not $_.titoloLibro.StartsWith('(libro') })
Test-Step 'prestiti: i titoli arrivano dal catalogo via Feign' ($conTitolo.Count -eq $elenco.Count) "$($conTitolo.Count) di $($elenco.Count)"

foreach ($port in @($CatalogoPort, $PrestitiPort)) {
    Test-Step "Swagger :$port /v3/api-docs" ((Invoke-Api GET "http://localhost:$port/v3/api-docs").Code -eq 200)
}

# --- La pagina: mostra, valida, presta, restituisce -----------------------------------
$pagina = Invoke-WebRequest -Uri "$ui/" -UseBasicParsing -SessionVariable sessione -TimeoutSec 30
Test-Step 'UI: la pagina ha catalogo, prestiti e form' ($pagina.Content -match 'Biblioteca di quartiere' -and $pagina.Content -match 'Nuovo prestito' -and $pagina.Content -notmatch 'non rispondono')

$sbagliato = Invoke-WebRequest -Uri "$ui/prestiti" -Method Post -Body @{ libroId = ''; utenteEmail = 'x'; giorni = '30' } -WebSession $sessione -UseBasicParsing -TimeoutSec 30
Test-Step 'UI: un form sbagliato torna con i messaggi sotto i campi' ($sbagliato.Content -match 'Scegli un libro' -and $sbagliato.Content -match 'Questa non e')

if ($libro) {
    # POST, redirect, GET: il messaggio arriva come flash attribute, nella sessione.
    $fatto = Invoke-WebRequest -Uri "$ui/prestiti" -Method Post -Body @{ libroId = $libro.id; utenteEmail = 'lucia@esempio.it'; giorni = '7' } -WebSession $sessione -UseBasicParsing -TimeoutSec 30
    Test-Step 'UI: prestito dal form, con il messaggio dopo il redirect' ($fatto.Content -match 'Prestito registrato')
    $nuovo = @((Invoke-Api GET "$prestiti/api/prestiti").Json | Where-Object { $_.libroId -eq $libro.id -and $_.stato -eq 'IN_CORSO' }) | Select-Object -First 1
    if ($nuovo) {
        $reso = Invoke-WebRequest -Uri "$ui/prestiti/$($nuovo.id)/restituzione" -Method Post -WebSession $sessione -UseBasicParsing -TimeoutSec 30
        Test-Step 'UI: restituzione dal bottone' ($reso.Content -match 'rientrato')
    } else {
        Test-Step 'UI: restituzione dal bottone' $false 'il prestito fatto dal form non c''e'''
    }
}

Write-Host ''
$colore = if ($ko -eq 0) { 'Green' } else { 'Red' }
Write-Host "  $ok verifiche superate, $ko fallite" -ForegroundColor $colore
Write-Host ''
if ($ko -gt 0) { exit 1 }
