# Il giorno dell'esame — procedura operativa

Questa pagina è pensata per essere aperta e seguita, non ricordata. Se hai un
minuto solo, leggi le **quattro fasi** qui sotto e ignora il resto finché non
serve.

---

## La sera prima — l'esame senza rete

Il giorno dell'esame potresti non avere internet. Non è un dettaglio: Maven
scarica le dipendenze in `~/.m2`, Docker le immagini di base, e senza rete
nessuno dei due può farlo. Va preparato **adesso**, con la connessione.

Un comando solo, e ci mette qualche minuto:

```bash
task offline-prep
```

Scarica le dipendenze Maven, compila una volta, scarica le immagini Docker e
fa una prima `docker compose build` (che riempie la cache dei livelli, compreso
quello che installa `curl` dentro l'immagine: senza rete non si potrebbe più
fare). Poi verifica:

```bash
task offline
```

Deve dire **Tutto pronto**. Se dice che manca qualcosa, hai ancora la rete per
rimediare.

**Portati il progetto su una chiavetta.** Non serve un `.exe` né un
generatore: il template *è* la cartella, e i comandi stanno tutti dentro. Copia
sulla chiavetta:

| Cosa | Perché |
| :--- | :--- |
| la cartella del progetto, `.git` compreso | è il template, e con `.git` puoi tornare indietro con `git checkout .` |
| la cartella `~/.m2/repository` | le dipendenze Maven: è la parte che senza rete non si recupera |
| l'installatore di go-task, del JDK e di Docker Desktop | solo se non sei sicuro della macchina d'esame |

Sul portatile d'esame: copi la cartella dove vuoi, copi `.m2` dentro la tua
home, e sei operativo. Il nome della cartella che contiene tutto non lo guarda
nessuno script: rinominala pure a mano.

> Se invece la rete c'è, `git clone` resta la strada più veloce. Ma non
> contarci.

**Come presentare senza rete**, in ordine di sicurezza:

1. `task dev` per i servizi e `task run-db` per il solo PostgreSQL: Maven
   lavora offline dalla `~/.m2` e Docker deve solo far partire un'immagine che
   hai già. È il modo che regge meglio.
2. `task docker-up`: ricostruisce le immagini, quindi rifà anche i passaggi
   Maven **dentro** il container. Funziona se hai lanciato `task offline-prep`
   (la cache di Maven del Dockerfile sopravvive fra una build e l'altra), ma
   dipende da più cose.

---

## Fase 0 — Prima di scrivere una riga di codice (10 minuti)

Fallo appena ti siedi, non quando ti serve.

```bash
git clone https://github.com/daubog44/spring-boot-dockerized.git
```

```bash
cd spring-boot-dockerized
```

Poi un giro a vuoto, che serve a scaricare dipendenze Maven e immagini Docker
**prima** di averne bisogno:

```bash
task dev
```

```bash
task dev-down
```

Se questi due comandi funzionano, il resto della giornata è in discesa. Se
falliscono, hai ancora tutto il tempo per capire perché.

Poi, una volta sola, un giro di prova degli strumenti (dura una decina di
secondi e non tocca il progetto):

```bash
task test
```

Se passa, sai che `new-service`, `add-dep` e `set-port` funzionano su questa
macchina: quando ti serviranno, non dovrai scoprirlo.

> Le porte le libera `task dev` da solo, chiudendo quello che le tiene occupate:
> non devi controllare niente prima.

---

## Fase 0-bis — Il wizard, per montare il progetto della traccia

Letta la traccia, sai quanti microservizi ti servono e che cosa fa ognuno. Un
comando solo li mette tutti in piedi, facendoti le domande giuste:

```bash
task wizard
```

Ti chiede, nell'ordine:

1. **come si chiama la cartella con i moduli Maven** — di default `demo`,
   perché così nasce da Spring Initializr; dagli il nome del progetto e la
   rinomina ovunque sia scritta (Taskfile, script, guide);
2. **se il progetto usa PostgreSQL**, e con quale database, utente e password;
3. **i microservizi, uno per uno**: nome, che cos'è (servizio REST con
   database, servizio REST senza, interfaccia Thymeleaf), su quale porta, e se
   usa H2 in memoria o PostgreSQL — condiviso o tutto suo.

Alla fine lancia `task check` da solo. Non fa niente di magico: chiama
`rename-project`, `db-config`, `new-service` e `use-postgres` nell'ordine
giusto, gli stessi comandi che puoi dare a mano.

Per un microservizio solo, quando la traccia te ne fa venire in mente un altro
a metà giornata:

```bash
task wizard SERVICE=spedizioni-service
```

Quello che vale per **tutti** i servizi non te lo chiede, perché non c'è niente
da decidere: Eureka, OpenFeign, Swagger, Lombok, validation, actuator e
`common-dto` sono già nel modulo appena nasce.

---

## Fase 1 — Sviluppo: il ciclo che ripeterai tutto il giorno

Questo branch è l'esempio svolto della traccia turismo: `tourist-service`,
`random-service`, `store-service` e `event-ui` ci sono già. Se ti serve un
servizio in più:

```bash
task new-service NAME=ordini-service
```

Poi, una volta sola all'inizio:

```bash
task dev
```

Compila tutto, avvia i servizi **in background** e ti restituisce il prompt.
Nessuna finestra sparsa da inseguire.

In un **secondo** terminale, se vuoi vedere cosa succede:

```bash
task logs
```

Ogni riga è prefissata dal nome del servizio e colorata. `Ctrl+C` chiude solo
questa vista: i servizi restano accesi. Per seguirne uno solo:
`task logs SERVICE=store`.

Poi il ciclo è **solo questo**:

> scrivi il codice → `task compile` → il servizio si riavvia da solo in ~5 secondi

```bash
task compile
```

**Non rilanciare `task dev` a ogni modifica.** Ti serve solo quando cambi
qualcosa che un riavvio a caldo non copre: un `application.yml`, una porta, una
dipendenza, un modulo nuovo. Per quei casi c'è un comando apposta: vedi
[Modifiche strutturali](#modifiche-strutturali-dipendenze-porte-moduli-nuovi).
Puoi lanciarlo quando vuoi, fa pulizia da solo.

Quando qualcosa non risponde, **prima di formulare ipotesi**:

```bash
task status
```

Ti dice, porta per porta, chi è in ascolto: un tuo servizio, i container, o
un'applicazione estranea. E cosa si è registrato su Eureka.

---

## Modifiche strutturali: dipendenze, porte, moduli

Queste cose non le copre il ciclo `task compile`, perché toccano più file che
devono restare d'accordo fra loro. Per ognuna c'è un comando, e tutti si usano
allo stesso modo: **variabili `NOME=valore`, senza trattini**.

`task help` (o `task` da solo) stampa l'elenco; `task --summary <comando>` il
dettaglio di uno.

### Aggiungere una dipendenza a un microservizio

```bash
task add-dep SERVICE=store-service DEPS=security,mail
```

Le versioni **non si scrivono**: le decide il `pom.xml` padre, che eredita da
Spring Boot e importa il BOM di Spring Cloud. Per questo una dipendenza si
aggiunge con il solo nome.

I nomi brevi riconosciuti (`web`, `data-jpa`, `security`, `feign`, `kafka`,
`postgresql`, ...) li stampa:

```bash
task add-dep LIST=1
```

Se ti serve qualcosa che non è in elenco, passa le coordinate per esteso:
`task add-dep SERVICE=store-service DEPS=org.apache.commons:commons-lang3:3.17.0`.

> **Poi serve `task dev`, non `task compile`.** Il classpath di un servizio è
> fissato quando parte: un jar nuovo lo vede solo un riavvio vero. Vale per
> ogni dipendenza aggiunta e per ogni modulo nuovo.

`devtools` non serve aggiungerlo: è già nel pom padre, quindi ce l'hanno tutti
i moduli — è lui a dare l'hot reload dopo `task compile`.

### Cambiare una porta

```bash
task set-port SERVICE=event-ui PORT=9080
```

Una porta è scritta in quattro punti: l'`application.yml` del modulo,
`docker-compose.yml` (variabile d'ambiente **e** pubblicazione) e la lista dei
servizi in `dev.ps1` e `dev.sh`. Cambiarne tre su quattro dà il caso peggiore:
in locale funziona e in Docker no, o viceversa. Il comando li cambia tutti, e
ti elenca i punti che restano (collaudo e documentazione) perché li guardi tu.

Il **codice Java non contiene porte**: i servizi si chiamano per nome via
Eureka e Feign, quindi spostare una porta non rompe nessuna chiamata. Anche
spostare Eureka funziona: il comando aggiorna il `defaultZone` di tutti.

Per una prova al volo, senza toccare i file, resta `task dev UI_PORT=9080`.

### Aggiungere un microservizio

```bash
task new-service NAME=ordini-service
```

Crea il modulo (pom, `Main`, `application.yml`, un endpoint `/api/ping`) e lo
collega dove serve: `<modules>` del pom aggregatore, `COPY` nel `Dockerfile`,
blocco in `docker-compose.yml`, lista dei servizi di `task dev`. La porta è la
prima libera, se non la passi tu con `PORT=`.

Varianti: `UI=1` per un modulo Thymeleaf invece di un servizio REST, `NODB=1`
per un servizio senza JPA.

Poi `task dev`, e il servizio nuovo si registra su Eureka con gli altri.

### Collegare un servizio a PostgreSQL

```bash
task use-postgres SERVICE=ordini-service
```

I servizi creati da `task new-service` partono con **H2 in memoria**: comodo
mentre sviluppi (nessun container da aspettare, database pulito a ogni
riavvio), ma i dati non sopravvivono. Quando la traccia chiede persistenza
vera, questo comando sposta il modulo sul PostgreSQL che è **già** nel
`docker-compose.yml`, in tutti i punti che servono: driver e JPA nel pom,
url/utente/password nell'`application.yml`, le stesse variabili nel compose
(dove il database non è `localhost` ma `postgres`), `depends_on` sul database,
e `task dev` che d'ora in poi lo avvia e ne aspetta la porta.

**Un database per servizio**, se lo vuoi:

```bash
task use-postgres SERVICE=ordini-service DBNAME=ordini
```

Crea anche `demo/postgres-init/create-ordini.sql`. PostgreSQL esegue gli script
di init **solo quando il volume è vuoto**: la prima volta serve un
`task docker-reset` (che cancella i dati già presenti).

> **Serve più di un database all'esame?** Quasi mai. Le tracce chiedono
> persistenza su uno o due servizi, e un solo database condiviso è accettato
> senza problemi — è quello che trovi già configurato (`esame`, utente e
> password `exam`). Se vuoi essere ortodosso ("un servizio, un database"), o se
> la traccia lo chiede esplicitamente, `DBNAME=` te lo dà: resta **un solo
> container** PostgreSQL, con più database dentro. Non serve un secondo
> container, e non conviene: sono altri 300 MB e un'altra porta da gestire.

### Cambiare nome, utente, password o porta del database

Senza variabili ti dice com'è configurato adesso e chi ci è collegato — è il
modo più veloce per ricordarsi la password mentre la commissione guarda:

```bash
task db-config
```

Con le variabili cambia i valori **dappertutto in una volta**: nel container
`postgres` del compose (compresa la sua healthcheck, che interroga il database
con quelle stesse credenziali, e la porta pubblicata sulla macchina), nelle
variabili d'ambiente di ogni modulo collegato, nell'`application.yml` di
ognuno, e negli script di init dei database dedicati.

```bash
task db-config DBNAME=magazzino USER=wms PASSWORD=wms123
```

```bash
task db-config PORT=5433
```

> PostgreSQL crea utente e database **solo al primo avvio, su volume vuoto**.
> Dopo aver cambiato nome, utente o password serve un `task docker-reset`,
> altrimenti il container continua a rispondere con i vecchi.
>
> `PORT=` cambia solo la porta pubblicata sulla macchina: dentro Docker i
> servizi parlano con `postgres:5432` e non cambia niente.

### Riempire il database di dati di prova

Scritte le entity, questo comando le legge e scrive un `data.sql` per modulo:

```bash
task seed-data
```

Spring Boot lo esegue all'avvio, dopo che Hibernate ha creato le tabelle. I
valori sono inventati ma plausibili — le stringhe seguono il nome della colonna
(un campo `citta` prende nomi di città, un `email` degli indirizzi), gli `enum`
vengono presi davvero dai valori dichiarati nel file Java, e le tabelle con
chiave esterna vengono riempite **dopo** quelle a cui puntano, così i
riferimenti esistono.

```bash
task seed-data SERVICE=tourist-service ROWS=10
```

Aggiunge da solo all'`application.yml` le due proprietà senza cui il file non
verrebbe eseguito, o verrebbe eseguito prima che le tabelle esistano:

```yaml
spring:
  jpa:
    defer-datasource-initialization: true
  sql:
    init:
      mode: always
```

Il `data.sql` è tuo: modificalo pure, non viene riscritto se non rilanci il
comando. Su PostgreSQL le INSERT vengono rieseguite a ogni avvio: se ti trovi
righe doppie, svuota con `task docker-reset`. Con H2 in memoria non succede,
perché il database riparte vuoto ogni volta.

I dati di prova valgono punti: una demo su tabelle vuote non si vede.


### Accendere Swagger dove manca

I moduli creati da `task new-service` hanno **già** Swagger: dipendenza nel pom
e blocco nell'`application.yml`, quindi `http://localhost:<porta>/swagger-ui.html`
risponde dal primo avvio — sia per un servizio REST sia per una UI. Non devi
fare niente.

Serve solo se lavori su un modulo scritto a mano, o da cui la dipendenza è
stata tolta:

```bash
task enable-swagger SERVICE=ordini-service
```

È idempotente: se c'è già tutto, te lo dice e non tocca niente.

### Togliere un microservizio

```bash
task remove-service SERVICE=ordini-service
```

L'inverso di `new-service`: cancella la cartella e toglie il modulo dagli
stessi sei posti. Ti avvisa se qualche altro modulo lo chiamava.

### Controllare che sia rimasto tutto a posto

```bash
task check
```

Non avvia niente: legge i file e verifica che moduli, porte, `Dockerfile`,
`docker-compose.yml` e liste dei servizi dicano la stessa cosa. Usalo dopo una
modifica fatta a mano, e prima della demo.

```bash
task test
```

Collauda gli strumenti stessi su una copia usa-e-getta del progetto (il
progetto vero non viene toccato): serve a sapere che funzionano **prima** di
averne bisogno. Con `task test FULL=1` compila anche il modulo generato.

### Rinominare la cartella dei moduli

Si chiama `demo` perche' cosi' nasce da Spring Initializr. Se all'esame
preferisci il nome del progetto:

```bash
task rename-project NAME=wms
```

Rinomina la cartella e aggiorna insieme a lei il Taskfile, gli script e le
guide che la nominano; alla fine lancia `task check`. I comandi non cambiano:
cambia solo il percorso dei sorgenti (`wms/<modulo>/src/...`).

La cartella che contiene *tutto* (quella del repository) rinominala pure a mano
da Esplora risorse: nessuno script dipende dal suo nome.

### Cambiare configurazione (`application.yml`)

Nessun comando: modifichi il file e rilanci `task dev`. Un `application.yml`
non è codice ricompilato, quindi l'hot reload non lo rilegge.

---

## Fase 2 — Collaudo, prima di chiamare la commissione

```bash
task check
```

Poi controlla che i servizi si vedano fra loro, non solo che siano accesi:
`task status` deve elencarli tutti nel registro Eureka.

Prova gli endpoint veri, uno per servizio: il modo più comodo è Swagger UI
(`http://localhost:<porta>/swagger-ui.html`), che mostra lo schema esatto
delle richieste. Infine percorri il flusso completo dalla UI, come lo mostrerai
alla commissione: è l'unico collaudo che conta davvero.

---

## Fase 3 — La demo

Non devi fermare niente prima: `task docker-up` spegne da solo lo stack locale.

```bash
task docker-up
```

Aspetta che `task status` mostri i quattro servizi registrati su Eureka, poi
apri nell'ordine:

1. `http://localhost:8080` — l'applicazione
2. `http://localhost:8761` — la dashboard Eureka, per far vedere il discovery
3. `http://localhost:8081/swagger-ui.html` — i contratti OpenAPI

Se ti chiedono della **resilienza**, spegni un servizio davanti a loro e
ricarica la dashboard: resta in piedi con i segnaposto invece di andare in
errore.

```bash
docker stop exam-random-service
```

Alla fine:

```bash
task docker-down
```

---

## Fase 4 — La consegna

```bash
task consegna NOME=COGNOME_NOME
```

Prepara la cartella `consegna/` con dentro tutto quello che va consegnato, e
niente di quello che non serve:

| File | Cos'è |
| :--- | :--- |
| `moduli/<modulo>.zip` | i sorgenti di ogni microservizio, **senza** `target/` |
| `ALLEGATO-TECNICO.md` | già compilato con moduli, porte, endpoint e schema del database |
| `SCHEMA-DATABASE.md` | lo schema concettuale e logico da solo, comodo da copiare |
| `ISTRUZIONI-ESECUZIONE.md` | come far girare il progetto, con e senza Docker |
| `docker-compose.yml` + `Dockerfile` + pom + wrapper | bastano a rimettere in piedi lo stack dai sorgenti |
| `COGNOME_NOME.zip` | tutto quanto sopra in un archivio solo: **è quello da consegnare** |

Le cartelle `target/` restano fuori apposta: sono megabyte di roba
ricompilabile.

Prima di consegnare apri `ALLEGATO-TECNICO.md` e riempi le parti fra parentesi
quadre — analisi, algoritmo, descrizione dei moduli. Il resto (elenco dei
moduli con porte e nome Eureka, endpoint di ogni controller, schema del
database) è già dentro, ricavato dal codice.

Lo schema del database lo puoi anche guardare da solo, in qualunque momento:

```bash
task db-schema
```

Legge le classi `@Entity` e ne ricava tabelle, colonne, tipi SQL, chiavi e
relazioni, più un diagramma ER in mermaid che GitHub e VS Code disegnano da
soli. Non si collega a nessun database: funziona anche a stack spento, e dice
la verità su quello che Hibernate creerà.

---

## Se qualcosa va storto

| Sintomo | Cosa fare |
| :--- | :--- |
| Un servizio non risponde | `task status`, poi `task logs SERVICE=<servizio>` |
| "Port N was already in use" | `task dev`: chiude lui chi tiene la porta |
| Su `localhost:8080` risponde un'altra app | `task dev` la chiude; se ti serve viva, `task dev KEEPFOREIGN=1 UI_PORT=9080` |
| Hai modificato il codice e non cambia niente | `task compile` (e controlla che non ci siano errori di compilazione) |
| Hai aggiunto una dipendenza e non la vede | `task dev`: il classpath si fissa all'avvio, `task compile` non basta |
| "Porta occupata da processo sconosciuto" | Non è un processo: Windows si è riservato quell'intervallo (succede quando parte Docker Desktop). `task status` la segna **RISERVATA**. Sposta il servizio con `task set-port`, o libera le riserve da terminale amministratore: `net stop winnat` e `net start winnat` |
| Il servizio è morto dopo una modifica | `task logs SERVICE=<servizio>`, poi `task dev` per ripartire pulito |
| I container non partono | `task docker-down`, poi `task docker-up` |
| Il database ha dati sporchi | `task docker-reset`, poi `task docker-up` — **cancella i dati** |
| È tutto ingarbugliato | `task dev-down`, poi `task dev`. **Non** `task kill-java`: chiude anche l'IDE |

**L'unica trappola vera**: `task docker-reset` cancella il database,
`task docker-down` no. Durante la demo usa sempre `docker-down`.

---

## Tutti i comandi

`task` da solo stampa questo elenco con le descrizioni.

| Comando | Cosa fa |
| :--- | :--- |
| `task wizard` | Fa le domande e monta il progetto (`SERVICE=<modulo>` per uno solo) |
| `task dev` | Libera le porte, compila e avvia tutto in background con hot reload |
| `task logs` | Segue i log di tutti i servizi in un terminale solo |
| `task compile` | Ricompila: i servizi toccati si riavviano da soli |
| `task status` | Chi occupa le porte, container attivi, registro Eureka |
| `task dev-down` | Ferma i servizi locali e libera le porte |
| `task add-dep` | Aggiunge dipendenze al pom di un modulo (`LIST=1` per l'elenco) |
| `task set-port` | Sposta un modulo su un'altra porta, ovunque sia scritta |
| `task new-service` | Crea un microservizio nuovo e lo collega a tutto |
| `task remove-service` | Toglie un modulo dal progetto e da tutti i file |
| `task use-postgres` | Collega un modulo a PostgreSQL (`DBNAME=` per un database suo) |
| `task enable-swagger` | Rimette Swagger su un modulo che non ce l'ha |
| `task db-config` | Stampa o cambia database, utente, password e porta di PostgreSQL |
| `task rename-project` | Rinomina la cartella dei moduli Maven, ovunque sia nominata |
| `task seed-data` | Dati di prova ricavati dalle `@Entity` (`data.sql`) |
| `task db-schema` | Schema concettuale e logico ricavato dalle `@Entity` |
| `task consegna` | Prepara la cartella da consegnare (`NOME=COGNOME_NOME`) |
| `task offline-prep` | **Con la rete**: scarica tutto quello che servira' all'esame |
| `task offline` | Dice se il progetto partirebbe a rete staccata |
| `task check` | Moduli, porte, Docker e liste sono coerenti? |
| `task test` | Collauda gli strumenti su una copia usa-e-getta |
| `task help` | Questa guida, dal terminale |
| `task docker-up` | Costruisce le immagini e avvia lo stack in container |
| `task docker-down` | Ferma i container, **conservando** i dati del database |
| `task docker-reset` | Ferma i container **ed elimina** i volumi |
| `task docker-logs` | Segue i log dei container |
| `task build` | Compila e impacchetta tutti i moduli Maven |
| `task run SERVICE=<modulo>` | Avvia un solo modulo, in primo piano |
| `task run-eureka` | Avvia il solo Eureka, in primo piano |
| `task kill-java` | Ultima spiaggia: termina **tutti** i java della macchina |

### Opzioni utili

Si passano come variabili, senza trattini.

| Variabile | Quando |
| :--- | :--- |
| `task dev UI_PORT=9080` | Vuoi la UI su un'altra porta |
| `task dev NOBUILD=1` | Hai già compilato e vuoi solo riavviare |
| `task dev KEEPFOREIGN=1` | Su una porta gira qualcosa che ti serve viva: non chiuderla |
| `task logs SERVICE=<nome>` | Un servizio solo |

---

## Cosa fa `task dev` all'avvio, in dettaglio

Serve saperlo solo se qualcosa va storto:

1. **Libera le porte** dello stack: ferma i suoi servizi di un avvio
   precedente, spegne i container dell'esame se sono loro a tenerle
   (`docker compose down`, i dati restano) e chiude le applicazioni estranee
   rimaste in ascolto. Non tocca mai i processi di sistema né l'infrastruttura
   di Docker: quelli te li segnala soltanto.
2. Cancella i log del giro precedente, così `task logs` non ti mostra roba
   vecchia.
3. Compila tutti i moduli, una volta sola.
4. Avvia Eureka e **aspetta** che sia in ascolto, poi tutti gli altri.
5. Se qualcosa non parte, stampa le ultime righe del log del colpevole e
   **ritira quello che aveva avviato**, invece di lasciare mezzo stack acceso.
