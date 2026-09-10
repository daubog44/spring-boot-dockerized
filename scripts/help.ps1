<#
.SYNOPSIS
    Guida ai comandi: cosa lanciare, con quali variabili, in che ordine.

.DESCRIPTION
    E' quello che stampa `task` da solo e `task help`. Il testo e' volutamente
    generico sui nomi dei moduli: quelli del branch su cui sei li elenca
    `task status`.
#>

$ErrorActionPreference = 'Stop'

function Write-Section { param([string]$Title) ; Write-Host '' ; Write-Host $Title -ForegroundColor Cyan }
function Write-Cmd {
    param([string]$Command, [string]$What)
    Write-Host ('  {0,-42}{1}' -f $Command, $What)
}
function Write-Note { param([string]$Text) ; Write-Host "  $Text" -ForegroundColor DarkGray }

Write-Host ''
Write-Host 'COMANDI DEL PROGETTO' -ForegroundColor Green
Write-Host '  Si usano con variabili NOME=valore, mai con trattini.' -ForegroundColor DarkGray
Write-Host '  Dettaglio di uno solo: task --summary <comando>' -ForegroundColor DarkGray

Write-Section 'Dall''inizio alla consegna'
Write-Cmd 'task wizard' 'fa le domande e monta il progetto'
Write-Cmd 'task wizard SERVICE=<modulo>' 'le domande di un microservizio solo'
Write-Cmd 'task seed-data' 'dati di prova dalle @Entity (data.sql)'
Write-Cmd 'task db-schema' 'schema concettuale e logico, dalle @Entity'
Write-Cmd 'task consegna NOME=COGNOME_NOME' 'la cartella da consegnare'
Write-Note 'Il wizard e'' anche task init. seed-data: SERVICE=<modulo>, ROWS=<n>.'
Write-Note 'db-schema: OUT=<file>. consegna genera l''allegato tecnico gia'' compilato.'

Write-Section 'La giornata, in ordine'
Write-Cmd 'task dev' 'compila e avvia tutto in background'
Write-Cmd 'task logs' 'segue i log (Ctrl+C esce, i servizi restano)'
Write-Cmd 'task compile' 'dopo una modifica al codice: si riavvia da solo'
Write-Cmd 'task status' 'chi occupa le porte, chi e'' su Eureka'
Write-Cmd 'task dev-down' 'ferma tutto e libera le porte'
Write-Cmd 'task run SERVICE=<modulo>' 'un modulo solo, in primo piano'

Write-Section 'Modifiche strutturali (dopo queste ci vuole task dev)'
Write-Cmd 'task add-dep SERVICE=<modulo> DEPS=<a,b>' 'aggiunge dipendenze al pom'
Write-Cmd 'task add-dep LIST=1' 'i nomi brevi delle dipendenze'
Write-Cmd 'task set-port SERVICE=<modulo> PORT=<n>' 'sposta una porta, ovunque sia scritta'
Write-Cmd 'task new-service NAME=<nome>' 'crea un microservizio e lo collega'
Write-Cmd 'task remove-service SERVICE=<modulo>' 'lo toglie da tutto (l''inverso)'
Write-Cmd 'task use-postgres SERVICE=<modulo>' 'lo collega a PostgreSQL invece che a H2'
Write-Cmd 'task enable-swagger SERVICE=<modulo>' 'accende Swagger dove manca'
Write-Cmd 'task db-config' 'stampa credenziali e moduli collegati'
Write-Cmd 'task db-config DBNAME=<db> USER=<u>' 'le cambia dappertutto in una volta'
Write-Cmd 'task rename-project NAME=<nome>' 'rinomina la cartella dei moduli Maven'
Write-Note 'new-service: UI=1 per un modulo Thymeleaf, NODB=1 senza database,'
Write-Note 'PORT=<n> per sceglierla (di default la prima libera).'
Write-Note 'use-postgres: DBNAME=<db> per dare al modulo un database tutto suo.'
Write-Note 'Swagger sui moduli nuovi c''e'' gia'': enable-swagger serve solo a rimetterlo.'
Write-Host ''
Write-Host '  Le versioni delle dipendenze non si scrivono: le governa il pom.xml' -ForegroundColor DarkGray
Write-Host '  padre (Spring Boot piu'' il BOM di Spring Cloud), quindi basta il nome.' -ForegroundColor DarkGray
Write-Host '  LIST=1 stampa i 35 nomi brevi conosciuti (web, data-jpa, security,' -ForegroundColor DarkGray
Write-Host '  feign, kafka, postgresql...); se manca quello che ti serve, passa le' -ForegroundColor DarkGray
Write-Host '  coordinate: DEPS=org.apache.commons:commons-lang3:3.17.0' -ForegroundColor DarkGray

Write-Section 'Controlli'
Write-Cmd 'task check' 'moduli, porte, Docker e liste sono coerenti?'
Write-Cmd 'task test' 'collauda gli strumenti in una copia usa-e-getta'

Write-Section 'Esame senza rete'
Write-Cmd 'task offline-prep' 'DA FARE CON LA RETE: scarica tutto'
Write-Cmd 'task offline' 'dice se partirebbe a rete staccata'
Write-Note 'Senza rete presenta con task dev + task run-db: non ricompila dentro Docker.'

Write-Section 'Docker, per la demo'
Write-Cmd 'task docker-up' 'costruisce le immagini e avvia i container'
Write-Cmd 'task docker-logs' 'segue i log dei container'
Write-Cmd 'task docker-down' 'ferma i container, i dati restano'
Write-Cmd 'task docker-reset' 'ferma i container ED ELIMINA i dati'

Write-Section 'Varianti utili'
Write-Cmd 'task dev UI_PORT=9080' 'la UI su un''altra porta, solo per stavolta'
Write-Cmd 'task dev NOBUILD=1' 'hai gia'' compilato: solo riavvio'
Write-Cmd 'task dev KEEPFOREIGN=1' 'non chiudere le applicazioni estranee'
Write-Cmd 'task logs SERVICE=<nome>' 'un servizio solo'
Write-Cmd 'task logs SERVICE=<nome> TAIL=200' 'partendo da piu'' indietro'

Write-Section 'Se qualcosa va storto'
Write-Note 'task status         dice sempre chi tiene una porta'
Write-Note 'task logs SERVICE=<nome>   le ultime righe del colpevole'
Write-Note 'task dev            rilanciabile quando vuoi: fa pulizia da solo'
Write-Note 'GIORNO-ESAME.md     la procedura completa, passo per passo'

Write-Host ''
Write-Host '  task --list   elenca tutti i comandi, anche quelli non citati qui.' -ForegroundColor DarkGray
Write-Host ''
