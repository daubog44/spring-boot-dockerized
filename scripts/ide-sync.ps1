<#
.SYNOPSIS
    Riallinea la configurazione degli editor (VS Code, Zed) ai moduli veri del
    progetto.

.DESCRIPTION
    Un `launch.json` che elenca servizi che non esistono piu' e' peggio di non
    averlo: il tasto Debug parte e fallisce. Questo comando lo riscrive
    leggendo i moduli veri:

      .vscode/launch.json   una configurazione di debug per modulo, con la
                            classe Main trovata nei sorgenti, piu' il compound
                            "Stack completo" che li avvia tutti
      .vscode/tasks.json    i comandi task, dalla palette (Ctrl+Shift+P,
                            "Run Task")
      .zed/tasks.json       gli stessi comandi per Zed (task: Spawn)

    E, solo se mancano, i file che non dipendono dai moduli e che puoi
    modificare a piacere: .vscode/settings.json, .vscode/extensions.json,
    .zed/settings.json, .editorconfig.

    Lo chiamano da soli `task new-service`, `task remove-service` e
    `task set-port`: a mano serve solo se hai toccato i moduli senza passare da
    loro.

.EXAMPLE
    task ide-sync
#>
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoName = Get-AggregatorName -RepoRoot $repoRoot
$demoDir = Join-Path $repoRoot $demoName

# --- I moduli veri, con la loro classe Main e la loro porta ------------------

function Get-LaunchTargets {
    $result = @()
    $pomText = Read-TextFile (Join-Path $demoDir 'pom.xml')
    $modules = @([regex]::Matches($pomText, '<module>([^<]+)</module>') | ForEach-Object { $_.Groups[1].Value })

    foreach ($module in $modules) {
        $srcDir = Join-Path $demoDir "$module/src/main/java"
        if (-not (Test-Path $srcDir)) { continue }

        # La classe Main la cerchiamo nei sorgenti invece di dedurla dal nome:
        # cosi' funziona anche per un modulo scritto a mano.
        $mainClass = ''
        foreach ($file in (Get-ChildItem -Path $srcDir -Recurse -Filter '*.java')) {
            $text = Read-TextFile $file.FullName
            if ($text -notmatch '@SpringBootApplication') { continue }
            $packageHit = [regex]::Match($text, '(?m)^\s*package\s+([\w.]+)\s*;')
            $className = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $mainClass = if ($packageHit.Success) { $packageHit.Groups[1].Value + '.' + $className } else { $className }
            break
        }
        # Una libreria (common-dto) non si avvia: niente Main, niente voce.
        if (-not $mainClass) { continue }

        $port = ''
        $ymlPath = Join-Path $demoDir "$module/src/main/resources/application.yml"
        if (Test-Path $ymlPath) {
            $portHit = [regex]::Match((Read-TextFile $ymlPath), 'SERVER_PORT:(\d+)')
            if ($portHit.Success) { $port = $portHit.Groups[1].Value }
        }

        $result += [pscustomobject]@{ Module = $module; MainClass = $mainClass; Port = $port }
    }

    # Eureka per primo: e' l'ordine in cui vanno accesi, ed e' l'ordine in cui
    # VS Code esegue le configurazioni del compound.
    return @($result | Sort-Object @{ Expression = { if ($_.Module -eq 'naming-server') { 0 } else { 1 } } }, Module)
}

$targets = @(Get-LaunchTargets)

Write-Host ''
Write-Host '==> Configurazione degli editor' -ForegroundColor Cyan
Write-Host ''

# --- .vscode/launch.json ------------------------------------------------------

$vscodeDir = Join-Path $repoRoot '.vscode'
$zedDir = Join-Path $repoRoot '.zed'

$configs = @()
$names = @()
$i = 0
foreach ($target in $targets) {
    $i++
    $label = if ($target.Port) { "$i. $($target.Module) (:$($target.Port))" } else { "$i. $($target.Module)" }
    $names += $label
    $configs += @(
        '        {'
        '            "type": "java",'
        ('            "name": "' + $label + '",')
        '            "request": "launch",'
        ('            "mainClass": "' + $target.MainClass + '",')
        ('            "projectName": "' + $target.Module + '"')
        '        }'
    ) -join [Environment]::NewLine
}

$launch = New-Object System.Collections.Generic.List[string]
$launch.Add('// Generato da `task ide-sync`: lo riscrivono new-service, remove-service')
$launch.Add('// e set-port. Le modifiche a mano si perdono al prossimo comando.')
$launch.Add('{')
$launch.Add('    "version": "0.2.0",')
if ($configs.Count -eq 0) {
    $launch.Add('    "configurations": []')
} else {
    $launch.Add('    "configurations": [')
    $launch.Add(($configs -join (',' + [Environment]::NewLine)))
    $launch.Add('    ],')
    $launch.Add('    "compounds": [')
    $launch.Add('        {')
    $launch.Add('            "name": "Stack completo",')
    $launch.Add('            "configurations": [')
    $launch.Add((($names | ForEach-Object { '                "' + $_ + '"' }) -join (',' + [Environment]::NewLine)))
    $launch.Add('            ],')
    $launch.Add('            "stopAll": true')
    $launch.Add('        }')
    $launch.Add('    ]')
}
$launch.Add('}')
Write-TextFile -Path (Join-Path $vscodeDir 'launch.json') -Text ($launch -join [Environment]::NewLine)
Write-Step (".vscode/launch.json (" + $targets.Count + " servizio/i)")

# --- I comandi, uguali per i due editor --------------------------------------

$commands = @(
    @{ Label = 'task dev';        Args = @('dev');        What = 'compila e avvia tutto in background' }
    @{ Label = 'task compile';    Args = @('compile');    What = 'ricompila: i servizi si riavviano da soli' }
    @{ Label = 'task logs';       Args = @('logs');       What = 'segue i log in un terminale solo' }
    @{ Label = 'task status';     Args = @('status');     What = 'porte, container, registro Eureka' }
    @{ Label = 'task dev-down';   Args = @('dev-down');   What = 'ferma tutto e libera le porte' }
    @{ Label = 'task check';      Args = @('check');      What = 'il progetto e'' coerente?' }
    @{ Label = 'task test';       Args = @('test');       What = 'collauda gli strumenti' }
    @{ Label = 'task docker-up';  Args = @('docker-up');  What = 'lo stack in container, per la demo' }
    @{ Label = 'task docker-down';Args = @('docker-down');What = 'ferma i container, i dati restano' }
    @{ Label = 'task db-schema';  Args = @('db-schema');  What = 'lo schema del database dalle @Entity' }
    @{ Label = 'task seed-data';  Args = @('seed-data');  What = 'dati di prova dalle @Entity' }
)

$tasks = New-Object System.Collections.Generic.List[string]
$tasks.Add('// Generato da `task ide-sync`. Ctrl+Shift+P -> "Tasks: Run Task".')
$tasks.Add('{')
$tasks.Add('    "version": "2.0.0",')
$tasks.Add('    "tasks": [')
$entries = @()
foreach ($command in $commands) {
    $entries += @(
        '        {'
        ('            "label": "' + $command.Label + '",')
        ('            "detail": "' + $command.What + '",')
        '            "type": "shell",'
        ('            "command": "task ' + ($command.Args -join ' ') + '",')
        '            "problemMatcher": [],'
        '            "presentation": { "reveal": "always", "panel": "dedicated" }'
        '        }'
    ) -join [Environment]::NewLine
}
$tasks.Add(($entries -join (',' + [Environment]::NewLine)))
$tasks.Add('    ]')
$tasks.Add('}')
Write-TextFile -Path (Join-Path $vscodeDir 'tasks.json') -Text ($tasks -join [Environment]::NewLine)
Write-Step '.vscode/tasks.json'

# Zed usa un elenco piatto, con comando e argomenti separati.
$zedTasks = New-Object System.Collections.Generic.List[string]
$zedTasks.Add('// Generato da `task ide-sync`. Palette: "task: Spawn".')
$zedTasks.Add('[')
$entries = @()
foreach ($command in $commands) {
    $entries += @(
        '    {'
        ('        "label": "' + $command.Label + '",')
        '        "command": "task",'
        ('        "args": [' + (($command.Args | ForEach-Object { '"' + $_ + '"' }) -join ', ') + '],')
        '        "use_new_terminal": false,'
        '        "allow_concurrent_runs": false,'
        '        "reveal": "always"'
        '    }'
    ) -join [Environment]::NewLine
}
$zedTasks.Add(($entries -join (',' + [Environment]::NewLine)))
$zedTasks.Add(']')
Write-TextFile -Path (Join-Path $zedDir 'tasks.json') -Text ($zedTasks -join [Environment]::NewLine)
Write-Step '.zed/tasks.json'

# --- I file che non dipendono dai moduli: solo se mancano --------------------
# Questi puoi modificarli a piacere: ide-sync non ci torna sopra.

function Write-IfMissing {
    param([string]$Path, [string[]]$Lines, [string]$Label)
    if (Test-Path $Path) { return }
    Write-TextFile -Path $Path -Text ($Lines -join [Environment]::NewLine)
    Write-Step "$Label (creato)"
}

Write-IfMissing -Path (Join-Path $vscodeDir 'settings.json') -Label '.vscode/settings.json' -Lines @(
    '{'
    '    "java.configuration.updateBuildConfiguration": "automatic",'
    '    "java.compile.nullAnalysis.mode": "automatic",'
    '    // Lo stesso JDK che usa il Taskfile. Se sulla macchina d''esame sta'
    '    // altrove, correggi qui il percorso (o togli il blocco: VS Code cerca'
    '    // da solo, ma puo'' pescare un Java piu'' vecchio).'
    '    "java.configuration.runtimes": ['
    '        {'
    '            "name": "JavaSE-25",'
    '            "path": "C:/Program Files/Microsoft/jdk-25.0.2.10-hotspot",'
    '            "default": true'
    '        }'
    '    ],'
    '    // L''hot reload di task compile ricompila quello che hai salvato: senza'
    '    // salvataggio automatico non si accorge di niente.'
    '    "files.autoSave": "afterDelay",'
    '    "files.autoSaveDelay": 1000,'
    '    "files.exclude": {'
    '        "**/target": true,'
    '        "**/.dev-logs": true'
    '    },'
    '    "search.exclude": {'
    '        "**/target": true,'
    '        "**/consegna": true'
    '    },'
    '    "[java]": { "editor.tabSize": 4 },'
    '    "[yaml]": { "editor.tabSize": 2, "editor.insertSpaces": true }'
    '}'
)

Write-IfMissing -Path (Join-Path $vscodeDir 'extensions.json') -Label '.vscode/extensions.json' -Lines @(
    '{'
    '    // Ctrl+Shift+P -> "Extensions: Show Recommended Extensions".'
    '    "recommendations": ['
    '        "vscjava.vscode-java-pack",'
    '        "vmware.vscode-boot-dev-pack",'
    '        "ms-azuretools.vscode-docker",'
    '        "redhat.vscode-yaml",'
    '        "task.vscode-task"'
    '    ]'
    '}'
)

Write-IfMissing -Path (Join-Path $zedDir 'settings.json') -Label '.zed/settings.json' -Lines @(
    '// Zed legge il Java dall''estensione "Java" (jdtls): installala da'
    '// "zed: extensions". Il progetto e'' Maven multi-modulo, quindi apri la'
    '// cartella del repository, non quella di un singolo servizio.'
    '{'
    '    "format_on_save": "on",'
    '    "languages": {'
    '        "Java": { "tab_size": 4 },'
    '        "YAML": { "tab_size": 2 }'
    '    },'
    '    "file_scan_exclusions": ['
    '        "**/target",'
    '        "**/.dev-logs",'
    '        "**/consegna",'
    '        "**/.git"'
    '    ]'
    '}'
)

Write-IfMissing -Path (Join-Path $repoRoot '.editorconfig') -Label '.editorconfig' -Lines @(
    '# Vale per VS Code, Zed, IntelliJ ed Eclipse: nessuno dei quattro va'
    '# configurato a mano.'
    'root = true'
    ''
    '[*]'
    'charset = utf-8'
    'end_of_line = lf'
    'insert_final_newline = true'
    'trim_trailing_whitespace = true'
    'indent_style = space'
    ''
    '[*.java]'
    'indent_size = 4'
    ''
    '[*.{yml,yaml,json,xml,html}]'
    'indent_size = 2'
    ''
    '[*.md]'
    'trim_trailing_whitespace = false'
    ''
    '# Gli script POSIX e il wrapper Maven vogliono LF anche su Windows.'
    '[*.sh]'
    'end_of_line = lf'
)

Write-Host ''
Write-Host 'Editor riallineati.' -ForegroundColor Green
Write-Host ''
if ($targets.Count -gt 0) {
    Write-Host '  VS Code: F5 -> "Stack completo" avvia tutti i servizi in debug.'
    Write-Host '  Zed:     palette "task: Spawn" per i comandi task.'
} else {
    Write-Host '  Nessun servizio avviabile: crea un modulo con task new-service.'
}
Write-Host ''
Write-Host '  Per il debug in VS Code serve l''estensione Extension Pack for Java;' -ForegroundColor DarkGray
Write-Host '  IntelliJ non ha bisogno di niente: apri il pom aggregatore.' -ForegroundColor DarkGray
Write-Host ''
