<#
.SYNOPSIS
    Lo schema concettuale e logico della base dati, letto dal database vero.

.DESCRIPTION
    Per ogni modulo con delle @Entity compila, avvia l'applicazione su un
    database H2 usa-e-getta, lascia che Hibernate crei le tabelle e poi le
    interroga con JDBC (il pacchetto devdata di common-dto):

      modello concettuale   entita', attributi e relazioni con la loro
                            cardinalita', come le vede Hibernate;
      modello logico        tabelle, colonne, tipi, chiavi primarie ed esterne,
                            vincoli di unicita' e di valore, piu' un diagramma
                            ER in mermaid che GitHub e VS Code disegnano da soli.

    E' lo "schema concettuale e logico della base dati" che chiede l'allegato
    tecnico. Non si indovina niente leggendo i sorgenti: i nomi delle tabelle,
    le colonne delle relazioni e le tabelle di collegamento sono quelli che
    Hibernate crea davvero. Il database del progetto non viene toccato.

.PARAMETER OutFile
    Scrive il risultato su file invece che a schermo (lo usa task consegna).

.PARAMETER NoBuild
    Non ricompila: usa i jar che ci sono gia' in target/.

.EXAMPLE
    task db-schema
    task db-schema OUT=schema.md
#>
param(
    [string]$OutFile = '',
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$targets = @(Get-JpaModules -RepoRoot $repoRoot | Where-Object { $_.HasEntities })

$out = New-Object System.Collections.Generic.List[string]
function Emit { param([string]$Line = '') ; $out.Add($Line) }

Emit '# Schema concettuale e logico della base dati'
Emit ''
$failed = 0

if ($targets.Count -eq 0) {
    Emit 'Nessuna classe `@Entity` trovata: il progetto non ha ancora persistenza.'
    Emit ''
    Emit 'Le entity si riconoscono cosi'':'
    Emit ''
    Emit '```java'
    Emit '@Entity'
    Emit '@Table(name = "ordini")'
    Emit 'public class OrdineEntity { ... }'
    Emit '```'
    Emit ''
} else {
    Emit 'Letto dal database vero: per ogni modulo con delle `@Entity` l''applicazione'
    Emit 'e'' stata avviata su un database vuoto, Hibernate ha creato le tabelle e'
    Emit 'queste sono state interrogate con JDBC. Ogni microservizio ha il suo'
    Emit 'database, quindi lo schema e'' diviso per modulo.'
    Emit ''

    $buildOk = $true
    if (-not $NoBuild) {
        Write-Host '  db-schema: compilo con Maven...' -ForegroundColor DarkGray
        $build = Invoke-ModuleBuild -Modules @($targets | ForEach-Object { $_.Name }) -RepoRoot $repoRoot
        if ($build.ExitCode -ne 0) {
            $buildOk = $false
            Write-Host '  La compilazione e'' fallita:' -ForegroundColor Red
            foreach ($line in $build.Errors) { Write-Host "    $line" -ForegroundColor DarkGray }
        }
    }

    foreach ($target in $targets) {
        Emit ('## Modulo `' + $target.Name + '`')
        Emit ''
        if (-not $buildOk) {
            Emit '> Schema non letto: il progetto non compila. Sistema gli errori e rilancia `task db-schema`.'
            Emit ''
            $failed++
            continue
        }
        Write-Host "  db-schema: $($target.Name)..." -ForegroundColor DarkGray
        $fragment = Join-Path ([System.IO.Path]::GetTempPath()) ('schema-' + $target.Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.md')
        $result = Invoke-DevDataRun -Module $target -Arguments @("--dev-data.schema-out=$fragment") -OwnDatabase:(-not $target.HasH2)
        if ($result.ExitCode -eq 0 -and (Test-Path $fragment)) {
            if (-not $target.HasH2) {
                Emit '> Senza H2 fra le dipendenze lo schema e'' stato letto dal database configurato del modulo.'
                Emit ''
            }
            foreach ($line in (Split-TextLines (Read-TextFile $fragment))) { Emit $line }
            Remove-Item $fragment -Force -ErrorAction SilentlyContinue
        } else {
            $failed++
            Emit ('> Schema non letto: ' + $(if ($result.Problem) { $result.Problem } else { 'l''applicazione non e'' partita' }) + '. Rilancia `task db-schema` per i dettagli.')
            Emit ''
            Write-Host "  $($target.Name): schema non letto" -ForegroundColor Red
            [void](Write-DevDataResult -Result $result)
        }
    }

    Emit '> Le tabelle le crea Hibernate all''avvio (`ddl-auto: update`) leggendo le'
    Emit '> classi `@Entity`: qui sono lette dal database dopo che le ha create, quindi'
    Emit '> nomi, tipi e vincoli sono quelli veri. Su PostgreSQL i tipi sono gli'
    Emit '> stessi; un enum salvato come stringa e'' un VARCHAR con un CHECK sui valori.'
    Emit ''
}

$text = ($out -join [Environment]::NewLine)
if ($OutFile) {
    Write-TextFile -Path $OutFile -Text $text
    Write-Host "Schema scritto in $OutFile" -ForegroundColor Green
} else {
    Write-Host $text
}
if ($failed -gt 0) { exit 1 }
