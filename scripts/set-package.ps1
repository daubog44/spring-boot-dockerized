<#
.SYNOPSIS
    Cambia il pacchetto Java di base di tutti i moduli: sposta le cartelle dei
    sorgenti e riscrive package, import e mainClass.

.DESCRIPTION
    Il pacchetto di un modulo e' <base>.<modulo senza trattini>: con la base
    esame, ordini-service vive in src/main/java/esame/ordiniservice/. La base
    non e' scritta in una configurazione: e' quella di Eureka (naming-server),
    e new-service la segue da sola.

    Per ogni modulo:
      - sposta src/main/java/<base vecchia>/ in src/main/java/<base nuova>/
        (e lo stesso per src/test/java);
      - riscrive la base nei .java (package, import, nomi completi), nei pom
        (mainClass) e negli application.yml e .properties (logging.level...).
    Poi riallinea VS Code e Zed (la classe Main di ogni configurazione di
    debug) e lancia task check.

    Riscrive solo "<base>.<sottopacchetto che esiste davvero>": una frase come
    "Buon esame." dentro una stringa resta com'e'.

    Il groupId Maven (com.example) non cambia: e' un nome di pubblicazione, non
    una cartella.

.PARAMETER Package
    La base nuova: parole minuscole separate da punti (esame, it.rossi). Senza,
    stampa quella attuale.

.EXAMPLE
    task set-package
    task set-package PACKAGE=it.rossi
#>
param([string]$Package = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$demoDir = Join-Path $repoRoot 'demo'
$current = Get-BasePackage -RepoRoot $repoRoot

if (-not $Package) {
    Write-Host ''
    Write-Host ("Il pacchetto di base e' '{0}': i sorgenti stanno in src/main/java/{1}/<modulo>/." -f $current, ($current -replace '\.', '/')) -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  task set-package PACKAGE=<nuovo>     es. PACKAGE=it.rossi'
    Write-Host ''
    exit 0
}

$keywords = @('abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char', 'class', 'const',
    'continue', 'default', 'do', 'double', 'else', 'enum', 'extends', 'final', 'finally', 'float', 'for',
    'goto', 'if', 'implements', 'import', 'instanceof', 'int', 'interface', 'long', 'native', 'new',
    'package', 'private', 'protected', 'public', 'return', 'short', 'static', 'strictfp', 'super',
    'switch', 'synchronized', 'this', 'throw', 'throws', 'transient', 'try', 'void', 'volatile', 'while',
    'true', 'false', 'null', 'record', 'var', 'yield')
if ($Package -cnotmatch '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$') {
    throw "Pacchetto non valido: '$Package'. Parole minuscole separate da punti, ognuna comincia con una lettera: esame, it.rossi."
}
$reserved = @($Package.Split('.') | Where-Object { $_ -in $keywords })
if ($reserved.Count -gt 0) { throw "Pacchetto non valido: '$($reserved[0])' e' una parola riservata di Java." }
if ($Package -eq $current) {
    Write-Host ''
    Write-Host "Il pacchetto di base e' gia' '$Package': non c'e' niente da fare." -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

function Join-Package {
    # src/main/java + it.rossi -> src/main/java/it/rossi, coi separatori giusti.
    param([string]$Root, [string]$Name)
    $path = $Root
    foreach ($segment in $Name.Split('.')) { $path = Join-Path $path $segment }
    return $path
}

Write-Host ''
Write-Host "==> $current -> $Package" -ForegroundColor Cyan
Write-Host ''

# --- 1. Dove sono i sorgenti, e con quali sottopacchetti ---------------------
# Si riscrivono solo questi: "esame.ordiniservice" si', "esame.pdf" no.

$modules = @(Get-ChildItem -Path $demoDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'pom.xml') })
$roots = @()
$subpackages = @()
foreach ($module in $modules) {
    foreach ($kind in @('src\main\java', 'src\test\java')) {
        $root = Join-Path $module.FullName $kind
        $oldDir = Join-Package -Root $root -Name $current
        if (-not (Test-Path $oldDir)) { continue }
        $roots += $root
        $subpackages += @(Get-ChildItem -Path $oldDir -Directory | ForEach-Object { $_.Name })
    }
}
$subpackages = @($subpackages | Select-Object -Unique)
if ($subpackages.Count -eq 0) {
    throw "Non trovo sorgenti in src/main/java/$($current -replace '\.', '/')/: il pacchetto di base e' davvero '$current'?"
}

# --- 2. Le cartelle -------------------------------------------------------------
# Prima in una cartella d'appoggio, poi al posto nuovo: cosi' funziona anche
# quando la base nuova sta dentro la vecchia (esame -> esame.pro) o viceversa.

foreach ($root in $roots) {
    $oldDir = Join-Package -Root $root -Name $current
    $temp = Join-Path $root ('.set-package-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Move-Item -Path $oldDir -Destination $temp
    # Le cartelle rimaste vuote risalendo verso src/main/java (com/example/...).
    $parent = Split-Path -Parent $oldDir
    while ($parent.Length -gt $root.Length -and (Test-Path $parent) -and -not (Get-ChildItem -Path $parent -Force | Select-Object -First 1)) {
        Remove-Item -Path $parent -Force
        $parent = Split-Path -Parent $parent
    }
    $newDir = Join-Package -Root $root -Name $Package
    if (Test-Path $newDir) {
        foreach ($child in (Get-ChildItem -Path $temp -Force)) { Move-Item -Path $child.FullName -Destination $newDir }
        Remove-Item -Path $temp -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $newDir) -Force | Out-Null
        Move-Item -Path $temp -Destination $newDir
    }
    Write-Step ('{0}/{1}/' -f ($root.Substring($demoDir.Length + 1) -replace '\\', '/'), ($Package -replace '\.', '/'))
}

# --- 3. Il testo: package, import, mainClass, configurazione ------------------

$pattern = '(?<![\w])' + [regex]::Escape($current) + '(?=\.(?:' + (($subpackages | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b)'
$touched = 0
foreach ($module in $modules) {
    $files = Get-ChildItem -Path $module.FullName -Recurse -File -Include '*.java', 'pom.xml', '*.yml', '*.yaml', '*.properties' |
        Where-Object { $_.FullName -notmatch '[\\/]target[\\/]' }
    foreach ($file in $files) {
        if ((Edit-TextFile -Path $file.FullName -Pattern $pattern -Replacement $Package) -gt 0) { $touched++ }
    }
}
Write-Step "$touched file riscritti (package, import, mainClass, configurazione)"

# --- 4. Gli editor, e la prova del nove ---------------------------------------

& (Join-Path $PSScriptRoot 'ide-sync.ps1') | Out-Null
Write-Step 'VS Code e Zed riallineati (la classe Main di ogni servizio)'

& (Join-Path $PSScriptRoot 'check.ps1') -ProjectOnly
if ($LASTEXITCODE -ne 0) {
    Write-Host 'task check ha trovato qualcosa: guarda sopra.' -ForegroundColor Yellow
    exit 1
}

Write-Host ("  I moduli nuovi nasceranno in src/main/java/{0}/<modulo>/." -f ($Package -replace '\.', '/'))
Write-Host '  task build          compila da capo e toglie le classi col pacchetto vecchio'
Write-Host ''
