<#
.SYNOPSIS
    Aggiunge al PATH di QUESTA sessione la copia di task scaricata da
    "task offline-prep" (in .tools/task), per quando la macchina dell'esame
    non ha task installato, o non e' sul PATH.

.DESCRIPTION
    Va lanciato col punto davanti, "dot-sourcing", altrimenti il PATH
    cambierebbe solo nel processo figlio che esegue lo script, e sparirebbe
    subito:

        . .\scripts\usa-task-locale.ps1

    L'effetto dura solo questa finestra di PowerShell: chiudendola, sparisce.
    Per tenerlo per sempre, copia .tools/task/task.exe in una cartella gia'
    sul PATH (per esempio dove hai gia' git.exe), oppure aggiungi .tools/task
    al PATH di sistema dalle impostazioni di Windows.

    Questo script non usa "task" per funzionare: e' pensato apposta per il
    momento in cui "task" non c'e' ancora.

.EXAMPLE
    . .\scripts\usa-task-locale.ps1
#>
$repoRoot = Split-Path -Parent $PSScriptRoot
$taskDir = Join-Path $repoRoot '.tools/task'
$taskExe = Join-Path $taskDir 'task.exe'

if (-not (Test-Path $taskExe)) {
    Write-Host "Non c'e' una copia locale in .tools/task." -ForegroundColor Yellow
    Write-Host "Procurala con la rete: task offline-prep (o scripts/offline.ps1 -Prep)." -ForegroundColor Yellow
    return
}

if (($env:Path -split ';') -notcontains $taskDir) {
    $env:Path = "$taskDir;$env:Path"
}
Write-Host "Aggiunta al PATH di questa sessione: $taskDir" -ForegroundColor Green
try {
    $version = (& $taskExe --version 2>$null)
    if ($LASTEXITCODE -eq 0) { Write-Host "task pronto: $($version -join ' ')" -ForegroundColor Green }
} catch {
    # Una copia corrotta o incompleta: il PATH resta comunque aggiornato,
    # cosi' un "task --version" a mano dice l'errore vero.
}
Write-Host "Per tenerlo oltre questa finestra, copia $taskExe dove hai gia' un eseguibile sul PATH." -ForegroundColor DarkGray
