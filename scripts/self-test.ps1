<#
.SYNOPSIS
    Collauda gli strumenti del template su una copia usa-e-getta del progetto.

.DESCRIPTION
    Copia il repository in una cartella temporanea (senza .git, target e log) e
    li' esegue new-service, add-dep, set-port e check, verificando il risultato
    file per file. Il progetto vero non viene toccato, e alla fine la copia
    viene cancellata (se qualcosa fallisce resta, e ti dico dov'e').

    Serve a sapere che gli strumenti funzionano PRIMA di averne bisogno.

.PARAMETER Full
    Compila anche con Maven il modulo generato: piu' lento, ma verifica che il
    codice prodotto sia davvero compilabile.

.EXAMPLE
    task test
    task test FULL=1
#>
param([switch]$Full)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scaffold-lib.ps1')

$repoRoot = Get-ScaffoldRepoRoot
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('esame-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
# La copia di prova ha il suo progetto Docker Compose: il nome del progetto
# vero (lo passano task test e scaffold-lib) non deve arrivarle, se no un suo
# docker compose toccherebbe i tuoi container. Gli script lo ricavano dalla
# cartella della copia.
Remove-Item Env:COMPOSE_PROJECT_NAME -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'COLLAUDO DEGLI STRUMENTI' -ForegroundColor Cyan
Write-Host "  copia di prova: $sandbox" -ForegroundColor DarkGray
Write-Host ''

# robocopy esce con codici 0-7 quando ha funzionato (1 = file copiati).
# /XF .git oltre a /XD .git: in un worktree di git (git worktree add) .git e'
# un FILE che punta al repository vero. Copiato nella prova, faceva lavorare
# git mv di rename-project sull'indice del worktree vero: la rinomina di demo
# finiva nel commit successivo.
$null = robocopy $repoRoot $sandbox /E /XD target .git .dev-logs node_modules .task consegna /XF .git /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "Copia del progetto fallita (robocopy $LASTEXITCODE)." }
if (Test-Path (Join-Path $sandbox '.git')) {
    throw "La copia di prova ha un .git: le prove toccherebbero il repository vero. Mi fermo."
}

$sandboxScripts = Join-Path $sandbox 'scripts'
$demo = Join-Path $sandbox 'demo'

# --- Piccola libreria di prova ------------------------------------------------

$passed = 0
$failed = @()
$skipped = @()

function Invoke-Tool {
    param([string]$Script, [string[]]$Arguments = @())
    $path = Join-Path $sandboxScripts $Script
    # Qui vogliamo osservare i fallimenti, non subirli: con
    # $ErrorActionPreference = 'Stop' ogni riga di stderr di un processo
    # esterno diventerebbe un'eccezione nostra, e una prova che verifica un
    # errore atteso risulterebbe fallita.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $path @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{ ExitCode = $code; Output = $output }
}

function Get-BashPath {
    # Su Windows 'bash' nel PATH e' quello di WSL, che qui non esiste: cerchiamo
    # prima quello di Git for Windows.
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git/bin/bash.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'Git/bin/bash.exe')
        (Join-Path $env:LOCALAPPDATA 'Programs/Git/bin/bash.exe')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $found = Get-Command bash -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notmatch 'System32') { return $found.Source }
    return $null
}

function Get-Text { param([string]$RelativePath) ; return (Read-TextFile (Join-Path $sandbox $RelativePath)) }

# Il pacchetto di un modulo nella copia di prova, come percorso: la base cambia
# da un branch all'altro (e la cambiano il wizard e set-package), quindi la
# leggiamo ogni volta.
function Get-SandboxPackagePath {
    param([string]$Module)
    return ((Get-ModulePackage -Module $Module -Base (Get-BasePackage -RepoRoot $sandbox)) -replace '\.', '/')
}

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text -notmatch [regex]::Escape($Needle)) { throw "$Message (non trovo: $Needle)" }
}
function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text -match [regex]::Escape($Needle)) { throw "$Message (trovato invece: $Needle)" }
}
function Assert-Ok {
    param($Result, [string]$Message)
    if ($Result.ExitCode -ne 0) { throw "$Message`n$($Result.Output)" }
}
function Assert-Fails {
    param($Result, [string]$Message)
    if ($Result.ExitCode -eq 0) { throw "$Message (invece e' andato a buon fine)`n$($Result.Output)" }
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        Write-Host ("  OK    {0}" -f $Name) -ForegroundColor Green
        $script:passed++
    } catch {
        # Una prova che non si puo' eseguire qui (manca uno strumento) non e'
        # un fallimento: lo diciamo e andiamo avanti.
        if ($_.Exception.Message -like 'SALTATO*') {
            Write-Host ("  SALTATA  {0} -- {1}" -f $Name, ($_.Exception.Message -replace '^SALTATO:\s*', '')) -ForegroundColor Yellow
            $script:skipped += $Name
            return
        }
        Write-Host ("  FALLITO  {0}" -f $Name) -ForegroundColor Red
        Write-Host ("           {0}" -f ($_.Exception.Message -replace "`r?`n", "`n           ")) -ForegroundColor Red
        $script:failed += $Name
    }
}

# --- Le prove -----------------------------------------------------------------

Test-Case 'il progetto di partenza e'' coerente (task check)' {
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'task check non passa sul progetto cosi'' com''e'''
}

Test-Case 'ogni copia del progetto ha il suo progetto Docker Compose' {
    # Col nome di default (demo) la copia di prova e quella dell'esame si
    # prendevano container e volume del database: con credenziali diverse
    # PostgreSQL rifiutava la seconda ("password authentication failed").
    $atteso = (Split-Path -Leaf $sandbox).ToLowerInvariant() -replace '[^a-z0-9_-]+', '-' -replace '^[^a-z0-9]+', ''
    $nome = ("" + (& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$(Join-Path $sandboxScripts 'dev-lib.ps1')'; `$env:COMPOSE_PROJECT_NAME")).Trim()
    Assert-That ($nome -eq $atteso) "progetto Compose '$nome' invece di '$atteso'"
    Assert-Contains (Get-Text 'Taskfile.yml') 'COMPOSE_PROJECT_NAME:' 'il Taskfile non passa il nome del progetto a docker compose'
    # Un docker compose lanciato a mano da demo/ lo trova in demo/.env.
    Assert-Contains (Get-Text 'demo/.env') "COMPOSE_PROJECT_NAME=$atteso" 'demo/.env non porta il nome del progetto'
}

Test-Case 'new-service crea il modulo e lo collega ovunque' {
    $r = Invoke-Tool 'new-service.ps1' @('-Name', 'alfa-service')
    Assert-Ok $r 'new-service e'' fallito'

    Assert-That (Test-Path (Join-Path $demo 'alfa-service/pom.xml')) 'manca il pom del modulo'
    Assert-That (Test-Path (Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/Main.java'))) 'manca Main.java'
    Assert-That (Test-Path (Join-Path $demo 'alfa-service/src/main/resources/application.yml')) 'manca application.yml'

    [void][xml](Get-Text 'demo/alfa-service/pom.xml')
    Assert-Contains (Get-Text 'demo/alfa-service/pom.xml') '<artifactId>alfa-service</artifactId>' 'artifactId sbagliato'
    Assert-Contains (Get-Text 'demo/pom.xml') '<module>alfa-service</module>' 'non aggiunto ai <modules>'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'COPY alfa-service/pom.xml' 'non aggiunto al Dockerfile'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'MODULE: alfa-service' 'non aggiunto al compose'
    # Un nome fisso farebbe scontrare due copie del progetto sulla stessa macchina.
    Assert-That ((Get-Text 'demo/docker-compose.yml') -notmatch '(?m)^\s+container_name:') 'il compose non deve fissare i nomi dei container'
    # Ogni dipendenza sulla sua riga: e' un file che si consegna.
    Assert-NotContains (Get-Text 'demo/alfa-service/pom.xml') '</dependency>        <dependency>' 'due dipendenze sulla stessa riga del pom'
    # Senza queste due, le prime chiamate Feign dopo l'avvio falliscono per
    # 30-60 secondi ("Load balancer does not contain an instance").
    $alfaYml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $alfaYml 'registry-fetch-interval-seconds: 5' 'il registro di Eureka si rileggerebbe ogni 30 secondi'
    Assert-Contains $alfaYml 'ttl: 5s' 'la cache del load balancer resterebbe a 35 secondi'
    Assert-Contains (Get-Text 'scripts/dev.ps1') "Module = 'alfa-service'" 'non aggiunto alla lista di dev.ps1'
    Assert-Contains (Get-Text 'scripts/dev.sh') ':alfa-service:' 'non aggiunto alla lista di dev.sh'
}

Test-Case 'il modulo nuovo e'' coerente (task check)' {
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo new-service il progetto non e'' piu'' coerente'
}

Test-Case 'new-service UI=1 genera Thymeleaf e la pagina, senza JPA' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'beta-ui', '-Ui')) 'new-service -Ui e'' fallito'
    $pom = Get-Text 'demo/beta-ui/pom.xml'
    Assert-Contains $pom 'spring-boot-starter-thymeleaf' 'manca thymeleaf'
    Assert-NotContains $pom 'spring-boot-starter-data-jpa' 'una UI non deve avere JPA'
    Assert-That (Test-Path (Join-Path $demo 'beta-ui/src/main/resources/templates/index.html')) 'manca la pagina index.html'
    Assert-NotContains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'datasource' 'una UI non deve avere datasource'
    # Senza, il primo POST con redirect finisce su "/;jsessionid=..." e risponde 500.
    Assert-Contains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'tracking-modes: cookie' 'la UI deve tenere la sessione solo nel cookie'
}

Test-Case 'new-service NODB=1 lascia fuori database e driver' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'gamma-service', '-NoDb')) 'new-service -NoDb e'' fallito'
    $pom = Get-Text 'demo/gamma-service/pom.xml'
    Assert-NotContains $pom 'spring-boot-starter-data-jpa' 'NoDb non deve mettere JPA'
    Assert-NotContains $pom '<artifactId>h2</artifactId>' 'NoDb non deve mettere H2'
    Assert-NotContains $pom '<artifactId>postgresql</artifactId>' 'NoDb non deve mettere PostgreSQL'
}

Test-Case 'new-service assegna porte diverse a moduli diversi' {
    $a = [regex]::Match((Get-Text 'demo/alfa-service/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    $b = [regex]::Match((Get-Text 'demo/beta-ui/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    $c = [regex]::Match((Get-Text 'demo/gamma-service/src/main/resources/application.yml'), 'SERVER_PORT:(\d+)').Groups[1].Value
    Assert-That ($a -and $b -and $c) 'porta non scritta in qualche application.yml'
    Assert-That ((@($a, $b, $c) | Select-Object -Unique).Count -eq 3) "porte assegnate: $a, $b, $c"
}

Test-Case 'new-service rifiuta un modulo che esiste gia''' {
    Assert-Fails (Invoke-Tool 'new-service.ps1' @('-Name', 'alfa-service')) 'ha ricreato un modulo esistente'
}

Test-Case 'new-service rifiuta un nome non valido' {
    Assert-Fails (Invoke-Tool 'new-service.ps1' @('-Name', 'Alfa_Service')) 'ha accettato un nome con maiuscole e underscore'
}

Test-Case 'new-service senza NAME spiega come si usa' {
    $r = Invoke-Tool 'new-service.ps1'
    Assert-Fails $r 'senza NAME dovrebbe fallire'
    Assert-Contains $r.Output 'task new-service NAME=' 'il messaggio non dice come si usa'
}

Test-Case 'new-entity genera entity, repository, service e controller' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'epsilon-service')) 'new-service epsilon-service e'' fallito'
    $r = Invoke-Tool 'new-entity.ps1' @('-Service', 'epsilon-service', '-Name', 'Libro',
        '-Fields', 'titolo:string(150):required,isbn:string(13):unique,annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,genere:enum(ROMANZO|SAGGIO|GIALLO)')
    Assert-Ok $r 'new-entity e'' fallito'

    $pkg = Get-SandboxPackagePath 'epsilon-service'
    $base = "demo/epsilon-service/src/main/java/$pkg"
    $entity = Get-Text "$base/entity/LibroEntity.java"
    Assert-Contains $entity '@Table(name = "libro")' 'il nome tabella non e'' quello atteso'
    Assert-Contains $entity '@Column(nullable = false, length = 150)' 'required + string(N) non genera il @Column atteso'
    Assert-Contains $entity '@Column(unique = true, length = 13)' 'unique + string(N) non genera il @Column atteso'
    Assert-Contains $entity '@Min(1450)' 'manca @Min dal modificatore min(N)'
    Assert-Contains $entity '@Max(2100)' 'manca @Max dal modificatore max(N)'
    Assert-Contains $entity '@NotBlank' 'un campo string required non ha @NotBlank'
    Assert-Contains $entity '@NotNull' 'un campo non-string required non ha @NotNull'
    Assert-Contains $entity '@Enumerated(EnumType.STRING)' 'il campo enum non ha @Enumerated'
    Assert-Contains $entity 'private Genere genere;' 'il tipo del campo enum non e'' il nome dell''enum'

    $enum = Get-Text "$base/entity/Genere.java"
    Assert-Contains $enum 'ROMANZO,' 'manca un valore dell''enum'
    Assert-Contains $enum 'GIALLO' 'manca l''ultimo valore dell''enum'

    $repo = Get-Text "$base/repository/LibroRepository.java"
    Assert-Contains $repo 'extends JpaRepository<LibroEntity, Long>' 'il repository non estende JpaRepository'

    $service = Get-Text "$base/service/LibroService.java"
    Assert-Contains $service 'ResponseStatusException(HttpStatus.NOT_FOUND' 'il service non risponde 404 su un id assente'
    Assert-Contains $service 'esistente.setTitolo(dati.getTitolo());' 'aggiorna() non copia un campo da FIELDS='

    $controller = Get-Text "$base/controller/LibroController.java"
    Assert-Contains $controller '@RequestMapping("/api/libro")' 'il percorso REST non e'' quello atteso'
    Assert-Contains $controller '@Valid @RequestBody LibroEntity nuovo' 'la creazione non valida il corpo con @Valid'
    Assert-Contains $controller '@ResponseStatus(HttpStatus.CREATED)' 'la creazione non risponde 201'

    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo new-entity il progetto non e'' coerente'
}

Test-Case 'new-entity rifiuta un modulo senza database' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'epsilon-nodb-service', '-NoDb')) 'new-service NoDb e'' fallito'
    $r = Invoke-Tool 'new-entity.ps1' @('-Service', 'epsilon-nodb-service', '-Name', 'Cosa')
    Assert-Fails $r 'ha accettato un modulo NODB=1, che non ha JPA'
    Assert-Contains $r.Output 'non ha un database' 'il messaggio non spiega perche'''
}

Test-Case 'new-entity rifiuta un''entity che esiste gia''' {
    $r = Invoke-Tool 'new-entity.ps1' @('-Service', 'epsilon-service', '-Name', 'Libro', '-Fields', 'x:int')
    Assert-Fails $r 'ha rigenerato un''entity che esisteva gia'''
    Assert-Contains $r.Output 'gia''' 'il messaggio non dice che c''e'' gia'''
}

Test-Case 'new-entity DTO=1 genera entity, dto in common-dto, service con mapper e controller con dto' {
    $r = Invoke-Tool 'new-entity.ps1' @('-Service', 'epsilon-service', '-Name', 'Editore',
        '-Fields', 'ragioneSociale:string:required,citta:string', '-Dto')
    Assert-Ok $r 'new-entity con -Dto e'' fallito'

    $pkg = Get-SandboxPackagePath 'epsilon-service'
    $base = "demo/epsilon-service/src/main/java/$pkg"
    $basePkg = (Get-BasePackage -RepoRoot $sandbox) -replace '\.', '/'
    $dtoFile = Join-Path $demo "common-dto/src/main/java/$basePkg/common/dto/EditoreDto.java"
    Assert-That (Test-Path $dtoFile) 'EditoreDto non creato in common-dto'

    $service = Get-Text "$base/service/EditoreService.java"
    Assert-Contains $service 'List<EditoreDto> elenco()' 'il service non restituisce List<EditoreDto>'
    Assert-Contains $service 'public static EditoreDto toDto(EditoreEntity entity)' 'manca toDto nel service'
    Assert-Contains $service 'public static EditoreEntity toEntity(EditoreDto dto)' 'manca toEntity nel service'

    $controller = Get-Text "$base/controller/EditoreController.java"
    Assert-Contains $controller 'List<EditoreDto> elenco()' 'il controller non usa EditoreDto'
    Assert-Contains $controller 'public EditoreDto crea(@Valid @RequestBody EditoreDto nuovo)' 'crea non usa EditoreDto'
}

Test-Case 'new-entity guidato campo per campo accetta tipo e modificatori dal menu' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'wizfields-service')) 'new-service wizfields-service e'' fallito'

    # Stesso elenco che new-entity.ps1 costruisce in modalita' interattiva: la
    # risposta al menu dipende da dove finisce il modulo appena creato, non da
    # un indice fisso che un'altra prova aggiunta prima potrebbe spostare.
    $jpaModules = @(Get-ChildItem -Path $demo -Directory | Where-Object {
        $p = Join-Path $_.FullName 'pom.xml'
        (Test-Path $p) -and ((Get-Content -Raw $p) -match 'spring-boot-starter-data-jpa')
    } | Select-Object -ExpandProperty Name)
    $idx = [array]::IndexOf($jpaModules, 'wizfields-service') + 1
    Assert-That ($idx -gt 0) 'wizfields-service non risulta fra i moduli con JPA'

    $answers = Join-Path $sandbox 'risposte-new-entity.txt'
    $lines = @(
        "$idx"                              # modulo: wizfields-service
        'Prova'                             # nome entity
        '1'                                  # modalita': guidato campo per campo
        'codice', '2', '20', '1,2'          # campo: codice, string(N), required+unique
        ''                                   # un altro campo? si
        'durata', '9', '3,4', '1', '600'    # campo: durata, int, min(1)+max(600)
        'n'                                  # basta campi
        'n'                                  # niente DTO
    )
    Write-TextFile -Path $answers -Text (($lines -join "`n") + "`n")
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'new-entity.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Ok $r 'new-entity guidato campo per campo e'' fallito'

    $entityFile = Join-Path $demo ('wizfields-service/src/main/java/' + (Get-SandboxPackagePath 'wizfields-service') + '/entity/ProvaEntity.java')
    Assert-That (Test-Path $entityFile) 'ProvaEntity.java non e'' stato creato dal wizard'
    $entity = Get-Text ('demo/wizfields-service/src/main/java/' + (Get-SandboxPackagePath 'wizfields-service') + '/entity/ProvaEntity.java')
    Assert-Contains $entity 'private String codice;' 'il tipo string(N) scelto dal menu non e'' stato applicato'
    Assert-Contains $entity '@Column(nullable = false, unique = true, length = 20)' 'i modificatori scelti dal menu non sono stati applicati'
    Assert-Contains $entity 'private Integer durata;' 'il tipo int scelto dal menu non e'' stato applicato'
    Assert-Contains $entity '@Min(1)' 'min(N) scelto dal menu dei modificatori non applicato'
    Assert-Contains $entity '@Max(600)' 'max(N) scelto dal menu dei modificatori non applicato'
}

Test-Case 'new-entity guidato lascia scegliere anche la riga sola, stile FIELDS=' {
    $jpaModules = @(Get-ChildItem -Path $demo -Directory | Where-Object {
        $p = Join-Path $_.FullName 'pom.xml'
        (Test-Path $p) -and ((Get-Content -Raw $p) -match 'spring-boot-starter-data-jpa')
    } | Select-Object -ExpandProperty Name)
    $idx = [array]::IndexOf($jpaModules, 'wizfields-service') + 1
    Assert-That ($idx -gt 0) 'wizfields-service non risulta fra i moduli con JPA'

    $answers = Join-Path $sandbox 'risposte-new-entity-riga.txt'
    $lines = @(
        "$idx"                                                       # modulo: wizfields-service
        'Riga'                                                       # nome entity
        '2'                                                          # modalita': riga sola
        'codice:string(20):required,descrizione:string:required'     # campi in una riga
        'n'                                                          # niente DTO
    )
    Write-TextFile -Path $answers -Text (($lines -join "`n") + "`n")
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'new-entity.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Ok $r 'new-entity riga sola e'' fallito'

    $entity = Get-Text ('demo/wizfields-service/src/main/java/' + (Get-SandboxPackagePath 'wizfields-service') + '/entity/RigaEntity.java')
    Assert-Contains $entity 'private String codice;' 'campo da riga sola non applicato'
    Assert-Contains $entity 'private String descrizione;' 'secondo campo da riga sola non applicato'
}

Test-Case 'add-relation configura ManyToOne e OneToMany fra due entity' {
    $r = Invoke-Tool 'add-relation.ps1' @('-Service', 'epsilon-service', '-From', 'Libro', '-To', 'Editore', '-Type', 'many-to-one')
    Assert-Ok $r 'add-relation e'' fallito'

    $pkg = Get-SandboxPackagePath 'epsilon-service'
    $base = "demo/epsilon-service/src/main/java/$pkg"
    $fromEntity = Get-Text "$base/entity/LibroEntity.java"
    Assert-Contains $fromEntity '@ManyToOne(fetch = FetchType.LAZY)' 'manca @ManyToOne su Libro'
    Assert-Contains $fromEntity '@JoinColumn(name = "editore_id")' 'manca @JoinColumn su Libro'
    Assert-Contains $fromEntity 'private EditoreEntity editore;' 'manca campo editore su Libro'

    $toEntity = Get-Text "$base/entity/EditoreEntity.java"
    Assert-Contains $toEntity '@OneToMany(mappedBy = "editore"' 'manca @OneToMany inverso su Editore'
    Assert-Contains $toEntity 'CascadeType.ALL' 'manca CascadeType.ALL'
    Assert-Contains $toEntity 'private List<LibroEntity> libroList = new ArrayList<>();' 'manca campo libroList su Editore'
    Assert-Contains $toEntity 'import java.util.List;' 'manca import List'
}

Test-Case 'new-dto genera record in common-dto con validazione' {
    # "Volume", non "Libro": su example/biblioteca esiste gia' un vero
    # LibroDto.java in common-dto, e il nome collide col progetto reale.
    Assert-Ok (Invoke-Tool 'new-dto.ps1' @('-Name', 'Volume', '-Fields', 'id:long,titolo:string(150):required,disponibile:bool')) 'new-dto e'' fallito'
    $basePkgPath = (Get-BasePackage -RepoRoot $sandbox) -replace '\.', '/'
    $dtoFile = Join-Path $demo "common-dto/src/main/java/$basePkgPath/common/dto/VolumeDto.java"
    Assert-That (Test-Path $dtoFile) 'VolumeDto.java non e'' in common-dto'
    $dto = Get-Text "demo/common-dto/src/main/java/$basePkgPath/common/dto/VolumeDto.java"
    Assert-Contains $dto 'public record VolumeDto' 'non e'' un record Java'
    Assert-Contains $dto '@Size(max = 150)' 'manca @Size'
    Assert-Contains $dto '@NotBlank' 'manca @NotBlank'
}

Test-Case 'new-client genera FeignClient collegato al servizio target' {
    Assert-Ok (Invoke-Tool 'new-client.ps1' @('-From', 'alfa-service', '-To', 'epsilon-service', '-Dto', 'VolumeDto')) 'new-client e'' fallito'
    $clientFile = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/client/EpsilonClient.java')
    Assert-That (Test-Path $clientFile) 'EpsilonClient.java non e'' nel modulo chiamante'
    $client = Read-TextFile $clientFile
    Assert-Contains $client '@FeignClient(name = "EPSILON-SERVICE")' 'nome Eureka errato'
    Assert-Contains $client 'List<VolumeDto> getAll()' 'manca getAll'
}

Test-Case 'new-view genera controller e template thymeleaf nel modulo UI' {
    Assert-Ok (Invoke-Tool 'new-view.ps1' @('-Service', 'beta-ui', '-Name', 'Libri', '-Fields', 'titolo:string:required,autore:string')) 'new-view e'' fallito'
    $ctrlFile = Join-Path $demo ('beta-ui/src/main/java/' + (Get-SandboxPackagePath 'beta-ui') + '/controller/LibriUiController.java')
    $tplFile = Join-Path $demo 'beta-ui/src/main/resources/templates/libri.html'
    Assert-That (Test-Path $ctrlFile) 'LibriUiController.java non trovato'
    Assert-That (Test-Path $tplFile) 'libri.html non trovato'
    $ctrl = Read-TextFile $ctrlFile
    Assert-Contains $ctrl '@Controller' 'manca @Controller'
    Assert-Contains $ctrl '@RequestMapping("/libri")' 'rotta non corretta'
    $tpl = Read-TextFile $tplFile
    Assert-Contains $tpl 'xmlns:th="http://www.thymeleaf.org"' 'manca namespace thymeleaf'
}

Test-Case 'new-client crea automaticamente il DTO in common-dto se sono passati FIELDS' {
    Assert-Ok (Invoke-Tool 'new-client.ps1' @('-From', 'alfa-service', '-To', 'beta-ui', '-Name', 'BetaClient', '-Dto', 'AutoreDto', '-Fields', 'nome:string:required')) 'new-client con FIELDS fallito'
    $basePkgPath = (Get-BasePackage -RepoRoot $sandbox) -replace '\.', '/'
    $dtoFile = Join-Path $demo "common-dto/src/main/java/$basePkgPath/common/dto/AutoreDto.java"
    $clientFile = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/client/BetaClient.java')
    Assert-That (Test-Path $dtoFile) 'AutoreDto.java non e'' stato creato automaticamente in common-dto'
    Assert-That (Test-Path $clientFile) 'BetaClient.java non e'' stato creato nel chiamante'
}

Test-Case 'task new-client (CLI reale, senza ROUTE) non spezza la riga di comando' {
    # Passa per il Taskfile vero, non per lo script diretto come le altre prove:
    # una variabile Task chiamata come una variabile d'ambiente di sistema
    # (successo con PATH, prima di diventare ROUTE) viene risolta con quella
    # del sistema anche se non la passi, e senza virgolette rompe il parsing
    # di mvdan/sh sulla prima parentesi che trova (es. "Program Files (x86)").
    $taskCmd = Get-Command task -ErrorAction SilentlyContinue
    if (-not $taskCmd) { throw 'SALTATO: comando task non trovato sul PATH' }
    Push-Location $sandbox
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & task new-client FROM=epsilon-service TO=gamma-service 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
        Pop-Location
    }
    Assert-That ($code -eq 0) "task new-client FROM=epsilon-service TO=gamma-service e'' fallito:`n$output"
    $clientFile = Join-Path $demo ('epsilon-service/src/main/java/' + (Get-SandboxPackagePath 'epsilon-service') + '/client/GammaClient.java')
    Assert-That (Test-Path $clientFile) 'GammaClient.java non e'' stato creato (task new-client via CLI reale)'
}

Test-Case 'new-auth configura la sicurezza su database (UtenteEntity, Repo, UserDetailsService, BCrypt)' {
    Assert-Ok (Invoke-Tool 'new-auth.ps1' @('-Service', 'epsilon-service', '-Type', 'db')) 'new-auth db e'' fallito'
    $epsPath = Get-SandboxPackagePath 'epsilon-service'
    Assert-That (Test-Path (Join-Path $demo "epsilon-service/src/main/java/$epsPath/entity/UtenteEntity.java")) 'manca UtenteEntity.java'
    Assert-That (Test-Path (Join-Path $demo "epsilon-service/src/main/java/$epsPath/repository/UtenteRepository.java")) 'manca UtenteRepository.java'
    Assert-That (Test-Path (Join-Path $demo "epsilon-service/src/main/java/$epsPath/service/CustomUserDetailsService.java")) 'manca CustomUserDetailsService.java'
    Assert-That (Test-Path (Join-Path $demo "epsilon-service/src/main/java/$epsPath/config/SecurityConfig.java")) 'manca SecurityConfig.java'
}

Test-Case 'new-auth configura form login su modulo UI (LoginController, login.html)' {
    Assert-Ok (Invoke-Tool 'new-auth.ps1' @('-Service', 'beta-ui', '-Type', 'form')) 'new-auth form e'' fallito'
    $uiPath = Get-SandboxPackagePath 'beta-ui'
    Assert-That (Test-Path (Join-Path $demo "beta-ui/src/main/java/$uiPath/controller/LoginController.java")) 'manca LoginController.java'
    Assert-That (Test-Path (Join-Path $demo 'beta-ui/src/main/resources/templates/login.html')) 'manca login.html'
    $tpl = Read-TextFile (Join-Path $demo 'beta-ui/src/main/resources/templates/login.html')
    Assert-Contains $tpl 'th:action="@{/login}"' 'form action non corretta'
}

Test-Case 'new-handler genera GlobalExceptionHandler (@RestControllerAdvice)' {
    Assert-Ok (Invoke-Tool 'new-handler.ps1' @('-Service', 'alfa-service')) 'new-handler e'' fallito'
    $hPath = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/controller/GlobalExceptionHandler.java')
    Assert-That (Test-Path $hPath) 'GlobalExceptionHandler.java non trovato'
    $handler = Read-TextFile $hPath
    Assert-Contains $handler '@RestControllerAdvice' 'manca @RestControllerAdvice'
    Assert-Contains $handler 'MethodArgumentNotValidException' 'manca gestione validazione'
}

Test-Case 'add-dep aggiunge dal catalogo e crea SecurityConfig se security' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'security,mail')) 'add-dep e'' fallito'
    $pom = Get-Text 'demo/alfa-service/pom.xml'
    [void][xml]$pom
    Assert-Contains $pom 'spring-boot-starter-security' 'manca security'
    Assert-Contains $pom 'spring-boot-starter-mail' 'manca mail'
    $secFile = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service') + '/config/SecurityConfig.java')
    Assert-That (Test-Path $secFile) 'manca SecurityConfig.java generato da add-dep security'
}

Test-Case 'add-dep non duplica quello che c''e'' gia''' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'security')) 'la seconda add-dep e'' fallita'
    $count = ([regex]'<artifactId>spring-boot-starter-security</artifactId>').Matches((Get-Text 'demo/alfa-service/pom.xml')).Count
    Assert-That ($count -eq 1) "security compare $count volte nel pom"
}

Test-Case 'add-dep accetta le coordinate per esteso' {
    Assert-Ok (Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'org.apache.commons:commons-lang3:3.17.0')) 'coordinate rifiutate'
    $pom = Get-Text 'demo/alfa-service/pom.xml'
    Assert-Contains $pom '<artifactId>commons-lang3</artifactId>' 'manca commons-lang3'
    Assert-Contains $pom '<version>3.17.0</version>' 'manca la versione delle coordinate'
}

Test-Case 'add-dep rifiuta un nome sconosciuto e non tocca il pom' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'non-esiste-questa')
    Assert-Fails $r 'ha accettato una dipendenza inventata'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'il pom e'' stato modificato lo stesso'
}

Test-Case 'add-dep salta devtools, che e'' gia'' nel pom padre' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'add-dep.ps1' @('-Module', 'alfa-service', '-Deps', 'devtools')
    Assert-Ok $r 'devtools non dovrebbe essere un errore'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'ha aggiunto devtools al modulo'
}

Test-Case 'add-dep LIST=1 elenca il catalogo' {
    $r = Invoke-Tool 'add-dep.ps1' @('-List')
    Assert-Ok $r 'LIST=1 e'' fallito'
    Assert-Contains $r.Output 'data-jpa' 'il catalogo non elenca data-jpa'
    Assert-Contains $r.Output 'feign' 'il catalogo non elenca feign'
}

Test-Case 'set-port sposta la porta in tutti i file' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'alfa-service', '-Port', '8199')) 'set-port e'' fallito'
    Assert-Contains (Get-Text 'demo/alfa-service/src/main/resources/application.yml') 'SERVER_PORT:8199' 'application.yml non aggiornato'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'SERVER_PORT: 8199' 'compose: variabile d''ambiente non aggiornata'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') '"8199:8199"' 'compose: porta pubblicata non aggiornata'
    Assert-Contains (Get-Text 'scripts/dev.ps1') 'Port = 8199' 'dev.ps1 non aggiornato'
    Assert-Contains (Get-Text 'scripts/dev.sh') ':alfa-service:8199' 'dev.sh non aggiornato'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-port il progetto non e'' piu'' coerente'
}

Test-Case 'set-port rifiuta una porta gia'' occupata' {
    Assert-Fails (Invoke-Tool 'set-port.ps1' @('-Module', 'gamma-service', '-Port', '8199')) 'ha accettato una porta gia'' usata'
}

Test-Case 'set-port su Eureka aggiorna chi lo cerca' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'naming-server', '-Port', '8762')) 'set-port su naming-server e'' fallito'
    Assert-Contains (Get-Text 'demo/alfa-service/src/main/resources/application.yml') 'localhost:8762' 'il defaultZone di un client non e'' stato aggiornato'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'eureka-server:8762' 'EUREKA_SERVER_URL dei container non aggiornato'
    Assert-NotContains (Get-Text 'demo/docker-compose.yml') 'localhost:8761/actuator' 'healthcheck di Eureka rimasto sulla porta vecchia'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo aver spostato Eureka il progetto non e'' piu'' coerente'
}

Test-Case 'enable-swagger e'' idempotente su un modulo che ce l''ha gia''' {
    $before = Get-Text 'demo/alfa-service/pom.xml'
    $r = Invoke-Tool 'enable-swagger.ps1' @('-Module', 'alfa-service')
    Assert-Ok $r 'enable-swagger e'' fallito'
    Assert-That ((Get-Text 'demo/alfa-service/pom.xml') -eq $before) 'ha toccato un pom che era gia'' a posto'
    Assert-Contains $r.Output 'gia'' presente' 'non dice che c''era gia'' tutto'
}

Test-Case 'enable-swagger rimette springdoc dove manca' {
    # Simuliamo un modulo scritto a mano: niente dipendenza, niente blocco yml.
    $pomPath = Join-Path $demo 'beta-ui/pom.xml'
    $pattern = '\s*<dependency>\s*<groupId>org\.springdoc</groupId>.*?</dependency>'
    Write-TextFile -Path $pomPath -Text ([regex]::Replace((Read-TextFile $pomPath), $pattern, '', 'Singleline'))
    $ymlPath = Join-Path $demo 'beta-ui/src/main/resources/application.yml'
    $yml = Read-TextFile $ymlPath
    Write-TextFile -Path $ymlPath -Text ($yml.Substring(0, $yml.IndexOf('springdoc:')).TrimEnd() + "`n")

    Assert-Ok (Invoke-Tool 'enable-swagger.ps1' @('-Module', 'beta-ui')) 'enable-swagger e'' fallito'
    Assert-Contains (Get-Text 'demo/beta-ui/pom.xml') '<artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>' 'dipendenza non rimessa'
    Assert-Contains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'swagger-ui:' 'blocco yml non rimesso'
}

Test-Case 'use-postgres collega il modulo al database condiviso' {
    Assert-Ok (Invoke-Tool 'use-postgres.ps1' @('-Module', 'alfa-service')) 'use-postgres e'' fallito'
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $yml 'jdbc:postgresql://localhost:5432/' 'application.yml non punta a postgres'
    Assert-NotContains $yml 'jdbc:h2:mem' 'e'' rimasto l''H2'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'jdbc:postgresql://postgres:5432/' 'il compose non passa l''url del container'
    Assert-Contains (Get-Text 'demo/alfa-service/pom.xml') '<artifactId>postgresql</artifactId>' 'manca il driver nel pom'
    Assert-Contains (Get-Text 'scripts/dev.ps1') '$usesPostgres = $true' 'task dev non avviera'' il database'
    Assert-Contains (Get-Text 'scripts/dev.sh') 'USES_POSTGRES=1' 'dev.sh non allineato'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo use-postgres il progetto non e'' piu'' coerente'
}

Test-Case 'use-postgres con DBNAME crea il database dedicato' {
    Assert-Ok (Invoke-Tool 'use-postgres.ps1' @('-Module', 'beta-ui', '-DbName', 'betadb')) 'use-postgres con DBNAME e'' fallito'
    Assert-That (Test-Path (Join-Path $demo 'postgres-init/create-betadb.sql')) 'manca lo script di init'
    Assert-Contains (Get-Text 'demo/postgres-init/create-betadb.sql') 'CREATE DATABASE betadb' 'lo script non crea il database'
    Assert-Contains (Get-Text 'demo/docker-compose.yml') 'postgres-init:/docker-entrypoint-initdb.d' 'il compose non monta gli script di init'
    Assert-Contains (Get-Text 'demo/beta-ui/src/main/resources/application.yml') 'betadb' 'il modulo non punta al suo database'
}

Test-Case 'use-postgres rifiuta un modulo che non esiste' {
    Assert-Fails (Invoke-Tool 'use-postgres.ps1' @('-Module', 'questo-non-esiste')) 'ha accettato un modulo inventato'
}

Test-Case 'remove-service toglie il modulo da tutti i file' {
    Assert-Ok (Invoke-Tool 'remove-service.ps1' @('-Module', 'gamma-service')) 'remove-service e'' fallito'
    Assert-That (-not (Test-Path (Join-Path $demo 'gamma-service'))) 'la cartella del modulo e'' rimasta'
    Assert-NotContains (Get-Text 'demo/pom.xml') '<module>gamma-service</module>' 'ancora fra i <modules>'
    Assert-NotContains (Get-Text 'demo/Dockerfile') 'COPY gamma-service/pom.xml' 'ancora nel Dockerfile'
    Assert-NotContains (Get-Text 'demo/docker-compose.yml') 'MODULE: gamma-service' 'ancora nel compose'
    Assert-NotContains (Get-Text 'scripts/dev.ps1') "Module = 'gamma-service'" 'ancora nella lista di dev.ps1'
    Assert-NotContains (Get-Text 'scripts/dev.sh') ':gamma-service:' 'ancora nella lista di dev.sh'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo remove-service il progetto non e'' piu'' coerente'
}

Test-Case 'remove-service rifiuta un modulo che non esiste' {
    Assert-Fails (Invoke-Tool 'remove-service.ps1' @('-Module', 'questo-non-esiste')) 'ha accettato un modulo inventato'
}

# --- La configurazione degli editor ------------------------------------------

Test-Case 'new-service mette il modulo nuovo nel launch.json' {
    $launch = Get-Text '.vscode/launch.json'
    Assert-Contains $launch '"projectName": "alfa-service"' 'il modulo nuovo non e'' fra le configurazioni di debug'
    Assert-Contains $launch '"projectName": "naming-server"' 'manca Eureka'
    Assert-Contains $launch 'Stack completo' 'manca il compound che li avvia tutti'
    # La classe Main deve essere quella vera, o il debug parte e non trova niente.
    $alfaMain = ((Get-SandboxPackagePath 'alfa-service') -replace '/', '.') + '.Main'
    Assert-Contains $launch $alfaMain 'classe Main sbagliata'
    # common-dto e' una libreria: non si avvia.
    Assert-NotContains $launch '"projectName": "common-dto"' 'una libreria non va fra le configurazioni di avvio'
    # Zed ha il suo file, con l'adattatore della sua estensione Java.
    $zedDebug = Get-Text '.zed/debug.json'
    Assert-Contains $zedDebug '"projectName": "alfa-service"' 'il modulo nuovo non e'' nel debug.json di Zed'
    Assert-Contains $zedDebug '"adapter": "Java"' 'il debug.json di Zed non usa l''adattatore Java'
    Assert-Contains $zedDebug $alfaMain 'classe Main sbagliata nel debug.json'
    Assert-NotContains $zedDebug '"projectName": "common-dto"' 'una libreria non va nel debug.json'
}

Test-Case 'i file degli editor sono JSON validi' {
    foreach ($relative in @('.vscode/launch.json', '.vscode/tasks.json', '.vscode/settings.json', '.zed/tasks.json', '.zed/debug.json', '.zed/settings.json')) {
        # I file di configurazione degli editor ammettono i commenti //: li
        # togliamo prima di darli al parser.
        $text = (Get-Text $relative) -replace '(?m)^\s*//.*$', ''
        try { $null = ConvertFrom-Json $text } catch { throw "$relative non e' JSON valido: $($_.Exception.Message)" }
    }
}

Test-Case 'remove-service toglie il modulo anche dal launch.json' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'delta-service')) 'new-service e'' fallito'
    Assert-Contains (Get-Text '.vscode/launch.json') '"projectName": "delta-service"' 'non aggiunto al launch.json'
    Assert-Ok (Invoke-Tool 'remove-service.ps1' @('-Module', 'delta-service')) 'remove-service e'' fallito'
    Assert-NotContains (Get-Text '.vscode/launch.json') 'delta-service' 'rimasto nel launch.json'
    Assert-NotContains (Get-Text '.zed/debug.json') 'delta-service' 'rimasto nel debug.json di Zed'
}

Test-Case 'set-port aggiorna la porta scritta nel launch.json' {
    Assert-Ok (Invoke-Tool 'set-port.ps1' @('-Module', 'alfa-service', '-Port', '8399')) 'set-port e'' fallito'
    Assert-Contains (Get-Text '.vscode/launch.json') 'alfa-service (:8399)' 'la porta nel launch.json e'' rimasta indietro'
    Assert-Contains (Get-Text '.zed/debug.json') 'alfa-service (:8399)' 'la porta nel debug.json di Zed e'' rimasta indietro'
}

Test-Case 'check si accorge se il launch.json e'' rimasto indietro' {
    $launchPath = Join-Path $sandbox '.vscode/launch.json'
    $saved = Read-TextFile $launchPath
    Write-TextFile -Path $launchPath -Text ($saved -replace '"projectName": "alfa-service"', '"projectName": "servizio-fantasma"')
    $r = Invoke-Tool 'check.ps1' @('-ProjectOnly')
    Assert-Fails $r 'check non si e'' accorto del modulo fantasma'
    Assert-Contains $r.Output 'task ide-sync' 'check non dice come rimediare'
    Write-TextFile -Path $launchPath -Text $saved
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'rimesso a posto, check dovrebbe passare'
}

# --- Database: credenziali, dati di prova, schema ----------------------------

Test-Case 'db-config stampa la configurazione del database' {
    $r = Invoke-Tool 'db-config.ps1'
    Assert-Ok $r 'db-config senza variabili e'' fallito'
    # Il nome del database cambia da un branch all'altro: lo leggiamo dal compose.
    $dbNow = [regex]::Match((Get-Text 'demo/docker-compose.yml'), '(?m)^\s+POSTGRES_DB:\s*(\S+)').Groups[1].Value
    Assert-Contains $r.Output $dbNow 'non stampa il nome del database'
    Assert-Contains $r.Output 'alfa-service' 'non elenca i moduli collegati'
}

Test-Case 'db-config cambia le credenziali dappertutto' {
    Assert-Ok (Invoke-Tool 'db-config.ps1' @('-DbName', 'collaudo', '-User', 'tester', '-Password', 'segreta', '-Port', '5544')) 'db-config e'' fallito'
    $compose = Get-Text 'demo/docker-compose.yml'
    Assert-Contains $compose 'POSTGRES_DB: collaudo' 'il container non ha il database nuovo'
    Assert-Contains $compose 'POSTGRES_USER: tester' 'il container non ha l''utente nuovo'
    Assert-Contains $compose 'pg_isready -U tester -d collaudo' 'la healthcheck e'' rimasta indietro'
    Assert-Contains $compose '"5544:5432"' 'la porta pubblicata non e'' cambiata'
    Assert-Contains $compose 'jdbc:postgresql://postgres:5432/collaudo' 'il modulo nel compose punta ancora al vecchio database'
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-Contains $yml 'jdbc:postgresql://localhost:5544/collaudo' 'application.yml non aggiornato'
    Assert-Contains $yml '_DB_USERNAME:tester}' 'utente non aggiornato in application.yml'
    Assert-Contains (Get-Text 'demo/postgres-init/create-betadb.sql') 'TO tester;' 'la GRANT del database dedicato e'' rimasta indietro'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo db-config il progetto non e'' piu'' coerente'
}

Test-Case 'db-config rifiuta un valore che PostgreSQL non accetterebbe' {
    Assert-Fails (Invoke-Tool 'db-config.ps1' @('-DbName', 'non valido!')) 'ha accettato un nome impossibile'
}

# --- Java e pacchetto -----------------------------------------------------------

Test-Case 'set-java imposta la versione in pom, Dockerfile e VS Code' {
    Assert-Ok (Invoke-Tool 'set-java.ps1' @('-Version', '21')) 'set-java VERSION=21 e'' fallito'
    Assert-Contains (Get-Text 'demo/pom.xml') '<java.version>21</java.version>' 'il pom non e'' passato a Java 21'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'eclipse-temurin:21-jdk' 'l''immagine di build e'' rimasta indietro'
    Assert-Contains (Get-Text 'demo/Dockerfile') 'eclipse-temurin:21-jre' 'l''immagine finale e'' rimasta indietro'
    Assert-Contains (Get-Text '.vscode/settings.json') '"JavaSE-21"' 'il runtime di VS Code e'' rimasto indietro'
}

Test-Case 'set-java rifiuta una versione troppo vecchia per Spring Boot 4' {
    Assert-Fails (Invoke-Tool 'set-java.ps1' @('-Version', '11')) 'ha accettato Java 11'
    Assert-Contains (Get-Text 'demo/pom.xml') '<java.version>21</java.version>' 'dopo il rifiuto il pom e'' cambiato lo stesso'
}

Test-Case 'set-java senza VERSION usa il JDK di questa macchina' {
    $jdk = Get-MachineJdk
    if (-not $jdk) { throw 'SALTATO: su questa macchina non c''e'' un JDK' }
    Assert-Ok (Invoke-Tool 'set-java.ps1') 'set-java e'' fallito'
    Assert-Contains (Get-Text 'demo/pom.xml') "<java.version>$($jdk.Version)</java.version>" 'il pom non segue il JDK della macchina'
    Assert-Contains (Get-Text '.vscode/settings.json') $jdk.Home 'VS Code non punta al JDK della macchina'
    Assert-Contains (Get-Text 'Taskfile.yml') $jdk.Home 'il JDK di ripiego del Taskfile e'' rimasto indietro'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-java il progetto non e'' coerente'
}

# --- Il wizard ----------------------------------------------------------------
# Le risposte gliele diamo da un file (WIZARD_ANSWERS), una per riga: una riga
# vuota vale come Invio.

Test-Case 'il wizard senza terminale si rifiuta invece di restare appeso' {
    $path = Join-Path $sandboxScripts 'wizard.ps1'
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # < NUL: nessuna tastiera. La redirezione la fa cmd, come farebbe una
        # pipeline o un'esecuzione automatica.
        $out = cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$path`" < NUL 2>&1" | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    Assert-That ($code -ne 0) "senza terminale doveva fermarsi`n$out"
    Assert-Contains $out 'terminale vero' 'non dice perche'' si ferma'
}

Test-Case 'il wizard si ferma se le risposte finiscono prima delle domande' {
    $answers = Join-Path $sandbox 'risposte-corte.txt'
    Write-TextFile -Path $answers -Text ''
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'wizard.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Fails $r 'con le risposte finite doveva fermarsi'
    Assert-Contains $r.Output 'risposte sono finite' 'non dice perche'' si ferma'
}

Test-Case 'il wizard monta database e servizi rispondendo alle domande' {
    $answers = Join-Path $sandbox 'risposte.txt'
    $lines = @(
        ''                                          # cartella dei moduli: resta com'e'
        'it.wiz'                                    # pacchetto Java: it.wiz invece di quello di oggi
        's', 'wizdb', 'wiz', 'wizpass', '5439'      # PostgreSQL, credenziali, porta
        'omega-service', '1', '', '2'               # REST con database, porta automatica, database condiviso
        'sigma-ui', '3', '', 'n'                    # interfaccia web, porta automatica, niente Swagger
        ''                                          # fine dei microservizi
    )
    # L'a capo in fondo serve: senza, l'ultima riga vuota non verrebbe letta.
    Write-TextFile -Path $answers -Text (($lines -join "`n") + "`n")
    $env:WIZARD_ANSWERS = $answers
    try { $r = Invoke-Tool 'wizard.ps1' } finally { Remove-Item Env:WIZARD_ANSWERS -ErrorAction SilentlyContinue }
    Assert-Ok $r 'il wizard e'' fallito'

    $compose = Get-Text 'demo/docker-compose.yml'
    Assert-Contains $compose 'POSTGRES_DB: wizdb' 'il database non e'' quello scelto'
    Assert-Contains $compose '"5439:5432"' 'la porta scelta non e'' pubblicata'
    Assert-Contains (Get-Text 'demo/omega-service/src/main/resources/application.yml') 'jdbc:postgresql://localhost:5439/wizdb' 'il servizio non punta al database condiviso, sulla porta scelta'
    Assert-That (Test-Path (Join-Path $demo 'sigma-ui/src/main/resources/templates/index.html')) 'l''interfaccia web non ha la sua pagina'
    Assert-That (Test-Path (Join-Path $demo 'omega-service/src/main/java/it/wiz/omegaservice/Main.java')) 'il servizio non e'' nel pacchetto scelto'
    Assert-That (Test-Path (Join-Path $demo 'naming-server/src/main/java/it/wiz/namingserver/Main.java')) 'Eureka non si e'' spostato nel pacchetto scelto'
    Assert-Contains (Get-Text '.vscode/launch.json') '"projectName": "omega-service"' 'il servizio non e'' nel launch.json'
    Assert-Contains (Get-Text '.zed/debug.json') '"projectName": "sigma-ui"' 'l''interfaccia non e'' nel debug.json di Zed'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo il wizard il progetto non e'' coerente'
}

# Da qui in poi serve un dominio con delle @Entity: il "serraglio" di
# scripts/self-test-entities, con i casi che rompevano i generatori a regex
# (sequenze, UUID, chiavi composte, ereditarieta', @MapsId, @Pattern...).
$alfaPackage = (Get-SandboxPackagePath 'alfa-service') -replace '/', '.'
$entityDir = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service'))
$fixtures = @(Get-ChildItem -Path (Join-Path $sandboxScripts 'self-test-entities') -Filter '*.java.txt')
foreach ($fixture in $fixtures) {
    $text = (Read-TextFile $fixture.FullName) -replace '__PKG__', $alfaPackage
    Write-TextFile -Path (Join-Path $entityDir ($fixture.Name -replace '\.txt$', '')) -Text $text
}
# Le entity concrete: quante devono riempirsi.
$entityCount = @($fixtures | Where-Object { $t = Read-TextFile $_.FullName; $t -match '(?m)^@Entity' -and $t -notmatch 'abstract class' }).Count

Test-Case 'seed-data scrive dev-data.rows e toglie il vecchio data.sql' {
    $sql = Join-Path $demo 'alfa-service/src/main/resources/data.sql'
    Write-TextFile -Path $sql -Text "-- Dati di prova generati da task seed-data.`nINSERT INTO x VALUES (1);`n"
    Assert-Ok (Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '3', '-NoCheck')) 'seed-data -NoCheck e'' fallito'
    Assert-That (-not (Test-Path $sql)) 'il data.sql della versione vecchia e'' rimasto'
    Assert-Ok (Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '4', '-NoCheck')) 'seed-data rilanciato e'' fallito'
    $yml = Get-Text 'demo/alfa-service/src/main/resources/application.yml'
    Assert-That (([regex]'(?m)^dev-data:').Matches($yml).Count -eq 1) 'dev-data compare piu'' di una volta'
    Assert-Contains $yml '  rows: 4' 'il numero di righe non e'' stato aggiornato'
}

Test-Case 'seed-data avvisa se lo stack e'' gia'' acceso (mvnw non si ricompila da solo)' {
    $devLogDir = Join-Path $sandbox '.dev-logs'
    New-Item -ItemType Directory -Path $devLogDir -Force | Out-Null
    $pidsFile = Join-Path $devLogDir 'dev.pids'
    Write-TextFile -Path $pidsFile -Text "99999 alfa`n"
    try {
        $r = Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '3', '-NoCheck')
        Assert-Ok $r 'seed-data -NoCheck e'' fallito con lo stack acceso'
        Assert-Contains $r.Output 'gia'' acceso' 'non avvisa che lo stack e'' gia'' acceso'
        Assert-Contains $r.Output 'task compile' 'non suggerisce task compile'
    } finally {
        Remove-Item $pidsFile -Force -ErrorAction SilentlyContinue
    }
}

Test-Case 'seed-data riempie ogni tabella passando da Hibernate (Maven + H2)' {
    $r = Invoke-Tool 'seed-data.ps1' @('-Module', 'alfa-service', '-Rows', '12')
    Assert-Ok $r 'seed-data con la prova e'' fallito'
    Assert-NotContains $r.Output 'ERRORE' 'una entity non si e'' riempita'
    Assert-Contains $r.Output "$entityCount entity riempite" 'non tutte le entity si sono riempite'
    # Le righe che puntano ad altre arrivano dopo: la tabella di collegamento
    # del molti a molti e l'elenco di valori non restano vuoti.
    Assert-That ($r.Output -match 'studente_entity_corsi [1-9]') 'la tabella di collegamento e'' vuota'
    Assert-That ($r.Output -match 'ordine_entity_etichette [1-9]') 'l''@ElementCollection e'' vuota'
    Assert-Contains $r.Output 'veicolo_entity 24' 'le due sottoclassi non hanno 12 righe ciascuna'
}

Test-Case 'seed-data SQL=1 scrive un data.sql vero, con INSERT semplici' {
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'sqlseed-service')) 'new-service sqlseed-service e'' fallito'
    Assert-Ok (Invoke-Tool 'new-entity.ps1' @('-Service', 'sqlseed-service', '-Name', 'Editore', '-Fields', 'nome:string(80):required')) 'new-entity Editore e'' fallito'
    Assert-Ok (Invoke-Tool 'new-entity.ps1' @('-Service', 'sqlseed-service', '-Name', 'Volume', '-Fields', 'titolo:string(150):required,prezzo:decimal,uscita:date,attivo:bool:required')) 'new-entity Volume e'' fallito'
    Assert-Ok (Invoke-Tool 'add-relation.ps1' @('-Service', 'sqlseed-service', '-From', 'Volume', '-To', 'Editore', '-Type', 'many-to-one')) 'add-relation Volume -> Editore e'' fallito'

    $r = Invoke-Tool 'seed-data.ps1' @('-Module', 'sqlseed-service', '-Rows', '3', '-Sql')
    Assert-Ok $r 'seed-data SQL=1 e'' fallito'
    Assert-Contains $r.Output 'data.sql  scritto' 'non conferma di aver scritto data.sql'

    $sqlPath = Join-Path $demo 'sqlseed-service/src/main/resources/data.sql'
    Assert-That (Test-Path $sqlPath) 'manca data.sql'
    $sqlLines = @(Get-Content $sqlPath)
    Assert-That ($sqlLines[0] -match 'data\.sql generato da task seed-data SQL=1') 'manca l''intestazione che lo marca come generato'
    $editoreLines = @($sqlLines | Where-Object { $_ -match '^INSERT INTO editore' })
    $volumeLines = @($sqlLines | Where-Object { $_ -match '^INSERT INTO volume' })
    Assert-That ($editoreLines.Count -eq 3) 'non ci sono 3 INSERT su editore'
    Assert-That ($volumeLines.Count -eq 3) 'non ci sono 3 INSERT su volume'
    $editoreIdx = [array]::IndexOf($sqlLines, $editoreLines[0])
    $volumeIdx = [array]::IndexOf($sqlLines, $volumeLines[0])
    Assert-That ($editoreIdx -lt $volumeIdx) 'editore (a cui volume punta con una chiave esterna) non viene prima nel file'

    $yml = Get-Text 'demo/sqlseed-service/src/main/resources/application.yml'
    Assert-Contains $yml 'defer-datasource-initialization: true' 'manca defer-datasource-initialization'
    Assert-Contains $yml 'mode: always' 'manca sql.init.mode'
    Assert-Contains $yml 'rows: 0' 'dev-data.rows non e'' stato spento dopo aver scritto data.sql'
}

Test-Case 'db-schema legge tabelle, chiavi e vincoli dal database' {
    # Senza -NoBuild: sui branch svolti ci sono altri moduli con delle entity,
    # che seed-data (limitato ad alfa-service) non ha compilato.
    $r = Invoke-Tool 'db-schema.ps1'
    Assert-Ok $r 'db-schema e'' fallito'
    foreach ($needle in @('## Modulo `alfa-service`', 'Modello concettuale', 'Modello logico', 'erDiagram',
            'Tabella `articoli`', 'Tabella `deposito_entity`', '| `stato` | VARCHAR(20) |', 'valori ammessi: DISPONIBILE',
            'generato da Hibernate con una sequenza', 'enum salvato come numero', 'Tabella `studente_entity_corsi`',
            'Chiave primaria composta', 'una sola tabella per tutta la gerarchia', '**Studente** <-> **Corso**: molti a molti',
            'riferimento a `deposito_entity`(`id`)', 'DEPOSITO_ENTITY |o--o{ ARTICOLI')) {
        Assert-Contains $r.Output $needle 'lo schema non dice tutto'
    }
}

Test-Case 'set-package sposta i sorgenti e riscrive package, import e mainClass' {
    $old = Get-BasePackage -RepoRoot $sandbox
    $alfaOld = Join-Path $demo ('alfa-service/src/main/java/' + (Get-SandboxPackagePath 'alfa-service'))
    # Una stringa che nomina la base ma non un suo sottopacchetto: deve restare com'e'.
    Write-TextFile -Path (Join-Path $alfaOld 'Frase.java') -Text ("package $old.alfaservice;`n`nclass Frase {`n    static final String TESTO = `"$old.pdf`";`n}`n")
    Assert-Ok (Invoke-Tool 'set-package.ps1' @('-Package', 'it.prova')) 'set-package e'' fallito'

    $alfaNew = Join-Path $demo 'alfa-service/src/main/java/it/prova/alfaservice'
    Assert-That (Test-Path (Join-Path $alfaNew 'Main.java')) 'Main.java non e'' nella cartella nuova'
    Assert-That (Test-Path (Join-Path $alfaNew 'ArticoloEntity.java')) 'le entity non si sono spostate'
    Assert-That (-not (Test-Path $alfaOld)) 'la cartella vecchia e'' rimasta'
    Assert-Contains (Read-TextFile (Join-Path $alfaNew 'ArticoloEntity.java')) 'package it.prova.alfaservice;' 'package non riscritto'
    Assert-Contains (Read-TextFile (Join-Path $alfaNew 'Frase.java')) "`"$old.pdf`"" 'ha riscritto una stringa che non era un pacchetto'
    Assert-That (Test-Path (Join-Path $demo 'naming-server/src/main/java/it/prova/namingserver/Main.java')) 'Eureka non si e'' spostato'
    Assert-Contains (Get-Text 'demo/naming-server/pom.xml') '<mainClass>it.prova.namingserver.Main</mainClass>' 'la mainClass del pom e'' rimasta indietro'
    Assert-Contains (Get-Text '.vscode/launch.json') 'it.prova.alfaservice.Main' 'launch.json non riallineato'
    $vecchi = @(Get-ChildItem -Path $demo -Recurse -Filter '*.java' | Where-Object {
        $_.FullName -notmatch '[\\/]target[\\/]' -and (Read-TextFile $_.FullName) -match ('(?m)^\s*(package|import)\s+' + [regex]::Escape($old) + '\.')
    })
    Assert-That ($vecchi.Count -eq 0) ('package o import ancora col pacchetto vecchio: ' + (($vecchi | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ', '))

    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', 'zeta-service', '-NoDb')) 'new-service dopo set-package e'' fallito'
    Assert-That (Test-Path (Join-Path $demo 'zeta-service/src/main/java/it/prova/zetaservice/Main.java')) 'il modulo nuovo non usa la base nuova'
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo set-package il progetto non e'' coerente'
}

Test-Case 'set-package rifiuta un pacchetto non valido' {
    Assert-Fails (Invoke-Tool 'set-package.ps1' @('-Package', 'It.Prova')) 'ha accettato le maiuscole'
    Assert-Fails (Invoke-Tool 'set-package.ps1' @('-Package', 'it.class')) 'ha accettato una parola riservata'
}

Test-Case 'rete dice quali domini non passano, senza fallire' {
    $r = Invoke-Tool 'rete.ps1' @('-Url', 'http://127.0.0.1:9/', '-TimeoutSeconds', '3')
    Assert-Ok $r 'task rete e'' fallito'
    Assert-Contains $r.Output 'NON risponde' 'non ha visto che l''indirizzo non risponde'
}

Test-Case 'offline-prep scarica anche una copia di scorta di task' {
    # Il download vero servirebbe la rete: qui verifichiamo solo che lo
    # script sappia dove metterla, e che il collaudo (senza -Prep) e
    # usa-task-locale sappiano trovarla dopo.
    Assert-Contains (Get-Text 'scripts/offline.ps1') '.tools/task' 'offline-prep non prepara una copia di scorta di task'
    Assert-Contains (Get-Text 'scripts/offline.ps1') 'usa-task-locale.ps1' 'offline non dice come usare la copia locale'
}

Test-Case 'usa-task-locale trova ed espone la copia locale di task' {
    $usaScript = Join-Path $sandboxScripts 'usa-task-locale.ps1'

    # Senza una copia locale: lo dice chiaramente, senza esplodere.
    $senzaCopia = ("" + (& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$usaScript'" 2>&1))
    Assert-Contains $senzaCopia 'offline-prep' 'senza una copia locale non spiega come procurarsela'

    # Con una copia (anche finta) di task.exe: la trova e la mette sul PATH
    # di questa sessione. Dev'essere lanciato col punto (dot-sourcing).
    $taskDir = Join-Path $sandbox '.tools/task'
    New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
    Set-Content -Path (Join-Path $taskDir 'task.exe') -Value 'finto' -Encoding ascii
    $sulPath = ("" + (& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$usaScript'; `$env:Path -split ';' -contains '$taskDir'")).Trim()
    Assert-That ($sulPath -match 'True') 'non aggiunge la copia locale al PATH di questa sessione'
}

Test-Case 'learn raccoglie lezioni, guide e moduli in contenuti.js' {
    Assert-Ok (Invoke-Tool 'learn.ps1' @('-NoOpen')) 'task learn e'' fallito'
    $js = Get-Text 'corso/contenuti.js'
    $lessons = @(Get-ChildItem (Join-Path $sandbox 'corso/lezioni') -Filter '*.md').Count
    Assert-That ($lessons -gt 0) 'nessuna lezione in corso/lezioni'
    Assert-That (([regex]"file: 'corso/lezioni/").Matches($js).Count -eq $lessons) 'non ci sono tutte le lezioni'
    Assert-Contains $js "file: 'GIORNO-ESAME.md'" 'manca la guida del giorno d''esame'
    Assert-Contains $js "nome: 'alfa-service'" 'manca un modulo del progetto'
    # I testi stanno fra apici inversi: dentro, apici inversi e ${ vanno
    # protetti, altrimenti il JavaScript si rompe e la pagina resta vuota.
    Assert-Contains $js '\${SERVER_PORT' 'un ${...} non e'' protetto'
    $protetti = ($js -replace '\\\\', '') -replace '\\`', ''
    $entries = ([regex]'testo: `').Matches($js).Count
    Assert-That (([regex]'`').Matches($protetti).Count -eq 2 * $entries) 'un apice inverso non protetto rompe il JavaScript'
}

Test-Case 'consegna prepara un archivio che parte appena scompattato' {
    $r = Invoke-Tool 'consegna.ps1' @('-Nome', 'ROSSI_MARIO')
    Assert-Ok $r 'consegna e'' fallita'
    Assert-Contains $r.Output 'ATTENZIONE: nessun data.sql trovato per' 'non avvisa che manca un data.sql, con le entity senza'
    $zip = Join-Path $sandbox 'consegna/ROSSI_MARIO.zip'
    Assert-That (Test-Path $zip) 'manca consegna/ROSSI_MARIO.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try { $entries = @($archive.Entries | ForEach-Object { $_.FullName }) } finally { $archive.Dispose() }
    $storte = @($entries | Where-Object { $_ -match '\\' })
    Assert-That ($storte.Count -eq 0) ('percorsi con la barra rovesciata: ' + (($storte | Select-Object -First 3) -join ', '))

    # Scompattato come farebbe chi corregge, e poi quello che la build cerca:
    # i moduli del pom aggregatore e i pom che il Dockerfile copia.
    $dest = Join-Path $sandbox 'consegna-scompattata'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
    try {
        foreach ($f in @('docker-compose.yml', 'Dockerfile', 'pom.xml', 'mvnw', '.mvn/wrapper/maven-wrapper.properties', 'ALLEGATO-TECNICO.md', 'ISTRUZIONI-ESECUZIONE.md', 'SCHEMA-DATABASE.md')) {
            Assert-That (Test-Path (Join-Path $dest $f)) "scompattato l'archivio, manca $f accanto al compose"
        }
        foreach ($m in [regex]::Matches((Read-TextFile (Join-Path $dest 'pom.xml')), '<module>([^<]+)</module>')) {
            $mod = $m.Groups[1].Value
            Assert-That (Test-Path (Join-Path $dest "$mod/pom.xml")) "il pom aggregatore cerca $mod/pom.xml, che non c'e'"
            Assert-That (Test-Path (Join-Path $dest "$mod/src")) "mancano i sorgenti di $mod"
        }
        foreach ($m in [regex]::Matches((Read-TextFile (Join-Path $dest 'Dockerfile')), '(?m)^COPY\s+(\S+/pom\.xml)\s')) {
            Assert-That (Test-Path (Join-Path $dest $m.Groups[1].Value)) "il Dockerfile copia $($m.Groups[1].Value), che non c'e'"
        }
        $target = @(Get-ChildItem -Path $dest -Recurse -Directory -Filter 'target')
        Assert-That ($target.Count -eq 0) 'nella consegna ci sono cartelle target/'
        Assert-That (-not (Test-Path (Join-Path $dest 'common-dto/src/main/java/devdata'))) 'devdata e'' rimasto in common-dto nella consegna'
        Assert-That (-not (Test-Path (Join-Path $dest 'common-dto/src/main/resources/META-INF'))) 'META-INF e'' rimasto in common-dto nella consegna'
        $zips = @(Get-ChildItem -Path $dest -Recurse -File -Filter '*.zip')
        Assert-That ($zips.Count -eq 0) ('archivi dentro l''archivio: ' + ($zips.Name -join ', '))
        Assert-NotContains (Read-TextFile (Join-Path $dest 'ISTRUZIONI-ESECUZIONE.md')) 'Scompatta ogni archivio' 'le istruzioni chiedono ancora di ricomporre il progetto'
    } finally {
        Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
    }
}

Test-Case 'consegna non avvisa per un modulo che ha gia'' un data.sql' {
    $dataSql = Join-Path $demo 'alfa-service/src/main/resources/data.sql'
    Write-TextFile -Path $dataSql -Text "-- dati veri per la traccia`nINSERT INTO libro (titolo) VALUES ('Prova');`n"
    try {
        $r = Invoke-Tool 'consegna.ps1' @('-Nome', 'ROSSI_MARIO')
        Assert-Ok $r 'consegna con data.sql e'' fallita'
        $attnLine = @($r.Output -split "`n" | Where-Object { $_ -match 'ATTENZIONE: nessun data.sql' })
        Assert-That (($attnLine.Count -eq 0) -or ($attnLine[0] -notmatch 'alfa-service')) 'avvisa anche per alfa-service, che ha gia'' un data.sql'
    } finally {
        Remove-Item -Force $dataSql -ErrorAction SilentlyContinue
    }
}

Test-Case 'consegna mette nell''archivio il testo scritto in allegato.md' {
    # Prima la consegna faceva l'archivio e poi diceva di riempire l'allegato:
    # l'archivio restava coi segnaposto, e una consegna rifatta cancellava il testo.
    $allegato = Join-Path $sandbox 'allegato.md'
    Assert-That (Test-Path $allegato) 'la prima consegna non ha creato allegato.md'
    Assert-Contains (Read-TextFile $allegato) '## alfa-service' 'allegato.md non ha la sezione dei moduli'
    Write-TextFile -Path $allegato -Text "# Le mie parti`n`n## Analisi`n`nLa biblioteca di prova presta libri.`n`n## Algoritmo`n`nLa penale di prova.`n"
    $r = Invoke-Tool 'consegna.ps1' @('-Nome', 'ROSSI_MARIO')
    Assert-Ok $r 'la seconda consegna e'' fallita'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $sandbox 'consegna/ROSSI_MARIO.zip'))
    try {
        $reader = New-Object System.IO.StreamReader($archive.GetEntry('ALLEGATO-TECNICO.md').Open())
        $testo = $reader.ReadToEnd()
        $reader.Close()
    } finally { $archive.Dispose() }
    Assert-Contains $testo 'La biblioteca di prova presta libri.' 'l''analisi di allegato.md non e'' nell''archivio'
    Assert-Contains $testo 'La penale di prova.' 'l''algoritmo di allegato.md non e'' nell''archivio'
    Assert-NotContains $testo '[Due o tre paragrafi' 'e'' rimasto il segnaposto dell''analisi'
    Assert-Contains $r.Output 'mancano ancora' 'non dice che mancano le descrizioni dei moduli'
    $dopo = Read-TextFile $allegato
    Assert-Contains $dopo '## alfa-service' 'non ha aggiunto ad allegato.md la sezione del modulo'
    Assert-Contains $dopo 'La biblioteca di prova presta libri.' 'ha perso il testo di allegato.md'
}

# Questa cambia il nome della cartella dei moduli: va per ultima.
Test-Case 'rename-project rinomina la cartella e i file che la nominano' {
    # Un modulo che comincia con il nome della cartella (biblioteca e
    # biblioteca-ui) non deve essere rinominato insieme a lei.
    $omonimo = (Split-Path -Leaf $demo) + '-extra'
    Assert-Ok (Invoke-Tool 'new-service.ps1' @('-Name', $omonimo, '-NoDb')) 'new-service del modulo omonimo e'' fallito'
    Assert-Ok (Invoke-Tool 'rename-project.ps1' @('-Name', 'collaudo-modules')) 'rename-project e'' fallito'
    Assert-That (Test-Path (Join-Path $sandbox 'collaudo-modules/pom.xml')) 'la cartella nuova non c''e'''
    Assert-That (-not (Test-Path $demo)) 'la cartella vecchia e'' rimasta'
    Assert-Contains (Get-Text 'Taskfile.yml') 'dir: collaudo-modules' 'il Taskfile punta ancora alla cartella vecchia'
    Assert-Contains (Get-Text 'scripts/check.ps1') "'collaudo-modules'" 'gli script puntano ancora alla cartella vecchia'
    Assert-That (Test-Path (Join-Path $sandbox "collaudo-modules/$omonimo/pom.xml")) "il modulo $omonimo non c'e' piu'"
    Assert-Contains (Get-Text 'scripts/dev.ps1') "Module = '$omonimo'" "il modulo $omonimo e' stato rinominato insieme alla cartella"
    Assert-Ok (Invoke-Tool 'check.ps1' @('-ProjectOnly')) 'dopo rename-project il progetto non e'' piu'' coerente'
}

Test-Case 'ogni comando ha un riepilogo dettagliato (task --summary)' {
    $taskfile = Get-Text 'Taskfile.yml'
    $lines = $taskfile -split "`n"
    $missing = @()
    $name = ''; $hasDesc = $false; $hasSummary = $false; $hasInternal = $false
    foreach ($line in $lines) {
        if ($line -match '^  [a-z][a-zA-Z0-9_-]*:$') {
            if ($name -and $hasDesc -and -not $hasInternal -and -not $hasSummary) { $missing += $name }
            $name = $line.Trim().TrimEnd(':')
            $hasDesc = $false; $hasSummary = $false; $hasInternal = $false
            continue
        }
        if ($line -match '^    desc:') { $hasDesc = $true }
        if ($line -match '^    summary:') { $hasSummary = $true }
        if ($line -match '^    internal:\s*true') { $hasInternal = $true }
    }
    if ($name -and $hasDesc -and -not $hasInternal -and -not $hasSummary) { $missing += $name }
    Assert-That ($missing.Count -eq 0) ("comandi senza summary: " + ($missing -join ' '))
}

Test-Case 'gli script PowerShell hanno sintassi valida' {
    $bad = @()
    foreach ($file in (Get-ChildItem -Path $sandboxScripts -Filter '*.ps1')) {
        $errors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        if ($errors.Count -gt 0) { $bad += "$($file.Name): $($errors[0].Message)" }
    }
    Assert-That ($bad.Count -eq 0) ($bad -join "`n")
}

Test-Case 'gli script POSIX hanno sintassi valida' {
    $bash = Get-BashPath
    if (-not $bash) { throw 'SALTATO: bash non e'' installato su questa macchina' }
    $bad = @()
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($file in (Get-ChildItem -Path $sandboxScripts -Filter '*.sh')) {
            $out = & $bash -n $file.FullName 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { $bad += "$($file.Name): $out" }
        }
    } finally {
        $ErrorActionPreference = $previous
    }
    Assert-That ($bad.Count -eq 0) ($bad -join "`n")
}

if ($Full) {
    Test-Case 'il modulo generato compila (Maven)' {
        Push-Location $demo
        # Maven scrive avvisi su stderr anche quando va tutto bene (Lombok e
        # sun.misc.Unsafe): la redirezione la fa cmd, non PowerShell, che
        # altrimenti li trasformerebbe in errori nostri.
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            cmd /c ".\mvnw.cmd -q -pl alfa-service -am install -Dmaven.test.skip=true > NUL 2>&1"
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previous
            Pop-Location
        }
        Assert-That ($code -eq 0) "la compilazione del modulo generato e' fallita (exit $code)"
    }
}

# --- Esito --------------------------------------------------------------------

Write-Host ''
$skippedNote = if ($skipped.Count -gt 0) { " ($($skipped.Count) saltate)" } else { '' }
if ($failed.Count -eq 0) {
    Write-Host "$passed prove superate, nessun fallimento.$skippedNote" -ForegroundColor Green
    Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    Write-Host ''
    exit 0
}
Write-Host "$passed superate, $($failed.Count) fallite: $($failed -join ', ')" -ForegroundColor Red
Write-Host "La copia di prova resta qui, per guardarci dentro: $sandbox" -ForegroundColor Yellow
Write-Host ''
exit 1
