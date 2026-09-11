<#
.SYNOPSIS
    Dice quali domini di internet rispondono da questa macchina.

.DESCRIPTION
    All'esame la rete c'e', ma filtrata: una whitelist lascia passare alcuni
    domini (Maven Central si') e altri chissa'. Questo comando bussa ai domini
    che servono al template e dice, per ognuno, se risponde e che cosa fare se
    non risponde. Non cambia niente e ci mette pochi secondi.

    Una risposta qualsiasi, anche un "401 non autorizzato", vuol dire che il
    dominio si raggiunge: il filtro lo lascia passare.

.PARAMETER Url
    Solo per le prove: altri indirizzi da provare al posto di quelli di sempre.

.PARAMETER TimeoutSeconds
    Quanto aspettare ogni dominio (default 5).

.EXAMPLE
    task rete
#>
param([string[]]$Url = @(), [int]$TimeoutSeconds = 5)

$ErrorActionPreference = 'Continue'
# PowerShell 5.1 parte con TLS 1.0: Maven Central e Docker Hub vogliono 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$targets = @(
    [pscustomobject]@{ Nome = 'Maven Central'; Url = 'https://repo.maven.apache.org/maven2/'
        Serve = 'le dipendenze Maven: moduli nuovi, add-dep, il wrapper'
        SeNo = 'si compila solo con la ~/.m2 della sera prima (task offline)' }
    [pscustomobject]@{ Nome = 'Docker Hub'; Url = 'https://registry-1.docker.io/v2/'
        Serve = 'le immagini di base: eclipse-temurin e postgres'
        SeNo = 'le immagini devono essere gia'' sul disco (task offline-prep, la sera prima)' }
    [pscustomobject]@{ Nome = 'Ubuntu'; Url = 'http://archive.ubuntu.com/ubuntu/'
        Serve = 'curl dentro l''immagine, quando la cache di Docker non ce l''ha'
        SeNo = 'docker compose build regge solo con la cache (task offline-prep)' }
    [pscustomobject]@{ Nome = 'GitHub'; Url = 'https://github.com/'
        Serve = 'git clone e le release del template'
        SeNo = 'il template arriva dalla chiavetta' }
    [pscustomobject]@{ Nome = 'VS Code Marketplace'; Url = 'https://marketplace.visualstudio.com/'
        Serve = 'le estensioni di VS Code'
        SeNo = 'valgono solo le estensioni gia'' installate' }
)
if ($Url.Count -gt 0) {
    $targets = @($Url | ForEach-Object { [pscustomobject]@{ Nome = $_; Url = $_; Serve = 'indirizzo di prova'; SeNo = 'non raggiungibile' } })
}

# Il codice HTTP della risposta, o 0 se non risponde nessuno (dominio
# bloccato, nome che non si risolve, tempo scaduto).
function Get-HttpCode {
    param([string]$Address)
    try {
        $request = [System.Net.HttpWebRequest]::Create($Address)
        $request.Method = 'HEAD'
        $request.Timeout = $TimeoutSeconds * 1000
        $request.AllowAutoRedirect = $false
        $response = $request.GetResponse()
        $code = [int]$response.StatusCode
        $response.Close()
        return $code
    } catch {
        # PowerShell avvolge l'eccezione di .NET: la WebException, con la
        # risposta del server, sta dentro.
        $ex = $_.Exception
        while ($ex -and -not ($ex -is [System.Net.WebException])) { $ex = $ex.InnerException }
        if ($ex -and $ex.Response) {
            $code = [int]$ex.Response.StatusCode
            $ex.Response.Close()
            return $code
        }
        return 0
    }
}

Write-Host ''
Write-Host 'LA RETE, DA QUESTA MACCHINA' -ForegroundColor Cyan
Write-Host ''

$blocked = @()
foreach ($t in $targets) {
    $code = Get-HttpCode -Address $t.Url
    if ($code -gt 0) {
        Write-Host ('  {0,-21}{1,-15}{2}' -f $t.Nome, 'risponde', $t.Serve) -ForegroundColor Green
    } else {
        Write-Host ('  {0,-21}{1,-15}{2}' -f $t.Nome, 'NON risponde', $t.Serve) -ForegroundColor Yellow
        $blocked += $t
    }
}

Write-Host ''
if ($blocked.Count -eq 0) {
    Write-Host 'Passa tutto: si lavora come a casa.' -ForegroundColor Green
} else {
    Write-Host 'Quello che non passa, e cosa vuol dire:' -ForegroundColor Yellow
    foreach ($t in $blocked) { Write-Host ('  {0,-21}{1}' -f $t.Nome, $t.SeNo) }
}
Write-Host ''
Write-Host '  Dietro un proxy? Maven lo legge da ~/.m2/settings.xml, Docker dalle' -ForegroundColor DarkGray
Write-Host '  impostazioni di Docker Desktop: questo comando usa quello di Windows.' -ForegroundColor DarkGray
Write-Host ''
exit 0
