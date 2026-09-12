# Il giorno dell'esame — procedura operativa

Questa pagina è pensata per essere aperta e seguita, non ricordata. Se hai un
minuto solo, leggi le **quattro fasi** qui sotto e ignora il resto finché non
serve. Per imparare prima, con calma e col codice di una traccia svolta,
c'è il corso: `task learn`.

---

## La sera prima — la rete dell'esame

All'esame la rete c'è, ma filtrata: una whitelist di domini lascia passare
Maven Central, quindi Maven scarica le dipendenze come a casa. Degli altri
domini non si sa niente finché non ci provi: Docker Hub (le immagini di base),
i repository di Ubuntu (`curl` dentro l'immagine, alla prima build), GitHub, le
estensioni degli editor. Quello che potrebbe non passare va scaricato
**adesso**, con la connessione di casa.

Un comando solo, e ci mette qualche minuto:

```bash
task offline-prep
```

Scarica anche una copia del comando `task` stesso, dentro `.tools/task`: se
sulla macchina dell'esame non c'è o GitHub non passa dalla whitelist, l'hai
già nella cartella del progetto. Se `task` non risponde, attivala con
`. .\scripts\usa-task-locale.ps1` (o `source scripts/usa-task-locale.sh`) —
col punto davanti, altrimenti l'effetto sparisce subito.

Poi scarica le dipendenze Maven, compila una volta, scarica le immagini Docker
e fa una prima `docker compose build` (che riempie la cache dei livelli,
compreso quello che installa `curl` dentro l'immagine: senza rete non si
potrebbe più fare). Alla fine verifica:

```bash
task offline
```

Deve dire **Tutto pronto**. Se dice che manca qualcosa, hai ancora la rete per
rimediare. Guarda anche le righe dell'editor: l'estensione Java di Zed scarica
jdtls, Lombok e il debugger al primo file `.java` che apri, quindi aprine uno
**adesso**.

**Portati il progetto su una chiavetta.** Non serve un `.exe` né un
generatore: il template *è* la cartella, e i comandi stanno tutti dentro. Copia
sulla chiavetta:

| Cosa | Perché |
| :--- | :--- |
| la cartella del progetto, `.git` compreso | è il template, e con `.git` puoi tornare indietro con `git checkout .` |
| la cartella `~/.m2/repository` | le dipendenze Maven, se Maven Central non dovesse passare |
| l'installatore del JDK e di Docker Desktop | solo se non sei sicuro della macchina d'esame (`task` non serve: c'è già in `.tools/task`) |

Sul portatile d'esame: copi la cartella dove vuoi, copi `.m2` dentro la tua
home, e sei operativo. Il nome della cartella che contiene tutto non lo guarda
nessuno script: rinominala pure a mano.

> Se GitHub passa (`task rete` te lo dice), `git clone` resta la strada più
> veloce. Ma non contarci.

**Come presentare se Docker Hub non passa**, in ordine di sicurezza:

1. `task dev` per i servizi e `task run-db` per il solo PostgreSQL: Maven
   lavora offline dalla `~/.m2` e Docker deve solo far partire un'immagine che
   hai già. È il modo che regge meglio.
2. `task docker-up`: ricostruisce le immagini, quindi rifà anche i passaggi
   Maven **dentro** il container. Funziona se hai lanciato `task offline-prep`
   (la cache di Maven del Dockerfile sopravvive fra una build e l'altra), ma
   dipende da più cose.

---

## Fase 0 — Prima di scrivere una riga di codice (10 minuti)

Fallo appena ti siedi, non quando ti serve. Prima di tutto, che cosa passa
dalla rete dell'aula:

```bash
task rete
```

Dominio per dominio, dice se risponde e che cosa fare se no. Se GitHub passa:

```bash
git clone https://github.com/daubog44/spring-boot-dockerized.git
```

```bash
cd spring-boot-dockerized
```

Altrimenti copia dalla chiavetta la cartella del progetto e la cartella
`.m2` dentro la tua home (vedi *La sera prima*), poi entra nella cartella e
controlla di essere a posto:

```bash
task offline
```

Poi un giro a vuoto, che serve a scaldare tutto **prima** di averne bisogno:

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

Prima di tutto, senza chiedere niente, **allinea Java al JDK di questo PC**:
se il progetto è su Java 25 e sulla macchina del laboratorio c'è Java 21,
passa a 21 il pom, le immagini Docker e VS Code (`task set-java`). Se il JDK
è più vecchio di 17, il minimo di Spring Boot 4, te lo dice e lascia stare.

Poi ti chiede, nell'ordine:

1. **come si chiama la cartella con i moduli Maven** — di default `demo`,
   perché così nasce da Spring Initializr; dagli il nome del progetto e la
   rinomina ovunque sia scritta (Taskfile, script, guide);
2. **il pacchetto Java di base** — di default `esame`, così i sorgenti stanno
   in `src/main/java/esame/<modulo>/`; se la traccia o il docente vogliono
   `it.cognome`, scrivilo qui e sposta tutto (`task set-package`);
3. **se il progetto usa PostgreSQL**, e con quale database, utente, password e
   porta — se sul PC la 5432 è già occupata (nei laboratori capita, con un
   PostgreSQL installato) te ne propone un'altra;
4. **i microservizi, uno per uno**: nome, che cos'è (servizio REST con
   database, servizio REST senza, interfaccia Thymeleaf), su quale porta, e se
   usa H2 in memoria o PostgreSQL — condiviso o tutto suo.

Alla fine lancia `task check` da solo. Non fa niente di magico: chiama
`set-java`, `rename-project`, `set-package`, `db-config`, `new-service` e
`use-postgres` nell'ordine giusto, gli stessi comandi che puoi dare a mano.

Per un microservizio solo, quando la traccia te ne fa venire in mente un altro
a metà giornata:

```bash
task wizard SERVICE=spedizioni-service
```

Quello che vale per **tutti** i servizi non te lo chiede, perché non c'è niente
da decidere: Eureka, OpenFeign, Swagger, Lombok, validation, actuator e
`common-dto` sono già nel modulo appena nasce.

---

## L'editor: VS Code, Zed, IntelliJ

Il progetto si apre **dalla cartella del repository**, non da quella di un
singolo servizio: è un progetto Maven multi-modulo, e l'editor deve vedere il
pom aggregatore per capirlo.

### VS Code

Nel repository ci sono già:

| File | Cosa fa |
| :--- | :--- |
| `.vscode/launch.json` | una configurazione di debug per servizio, più il compound **Stack completo** che li avvia tutti in ordine (Eureka per primo) |
| `.vscode/tasks.json` | i comandi `task` dalla palette: `Ctrl+Shift+P` → *Tasks: Run Task* |
| `.vscode/settings.json` | salvataggio automatico (senza, l'hot reload di `task compile` non si accorge di niente), `target/` nascosto dalla ricerca |
| `.vscode/extensions.json` | le estensioni consigliate: `Ctrl+Shift+P` → *Extensions: Show Recommended Extensions* |

L'unica indispensabile è **Extension Pack for Java**: senza, il tasto Debug non
esiste. Le altre (Spring Boot Extension Pack, Docker, YAML, Task) fanno comodo
ma non sono obbligatorie.

Premi `F5`, scegli **Stack completo** e hai tutti i servizi in debug, con i
breakpoint che funzionano. Se invece ti basta vederli girare, `task dev` resta
più leggero.

> `launch.json` e `tasks.json` (e i loro gemelli di Zed) sono **generati**: li riscrivono `new-service`,
> `remove-service` e `set-port`. Se li modifichi a mano, le modifiche si
> perdono al comando successivo. `settings.json` ed `extensions.json` no: quelli
> sono tuoi.

### Zed

| File | Cosa fa |
| :--- | :--- |
| `.zed/debug.json` | una configurazione di debug per servizio: `F4` e scegli quale avviare |
| `.zed/tasks.json` | i comandi `task` dalla palette: *task: Spawn* |
| `.zed/settings.json` | Java formattato al salvataggio, `target/` fuori dall'indice, jdtls che non va a cercare aggiornamenti |

Serve l'estensione **Java** (palette → *zed: extensions*). Al primo file
`.java` che apri scarica tre cose: `jdtls` (autocompletamento, errori,
navigazione fra i moduli), Lombok e il debugger. **Fallo la sera prima, con la
rete**: poi le impostazioni del progetto (`"check_updates": "once"`) dicono a
Zed di usare quello che ha già, e `task offline` ti conferma che c'è.

Il debug è quello vero, con i breakpoint, ma un servizio per volta: Zed non ha
il compound *Stack completo*. Se ti serve tutto lo stack in debug insieme, VS
Code (`F5` → *Stack completo*) resta la strada più corta.

### IntelliJ IDEA

Non c'è niente da configurare: *File → Open* sulla cartella del repository,
IntelliJ riconosce il pom aggregatore e importa i moduli da solo. Le
configurazioni di avvio se le crea lui quando apri una classe `Main`.

### Se l'elenco dei servizi non torna

```bash
task ide-sync
```

Riscrive `launch.json`, `debug.json` e i due `tasks.json` leggendo i moduli veri: trova la
classe `Main` nei sorgenti (quindi funziona anche per un modulo scritto a mano)
e la porta nell'`application.yml`. Serve solo se hai toccato i moduli senza
passare dai comandi; se il `launch.json` resta indietro, te lo dice `task check`.

---

## Fase 1 — Sviluppo: il ciclo che ripeterai tutto il giorno

Questo branch è il template vuoto: c'è Eureka, il modulo `common-dto` per le
classi condivise, e nient'altro. I servizi della traccia li crei tu, un
comando per uno:

```bash
task new-service NAME=ordini-service
```

```bash
task new-service NAME=ordini-ui UI=1
```

Il primo ti dà un servizio REST (con JPA, H2 e Swagger già collegati), il
secondo una UI Thymeleaf. Entrambi si registrano su Eureka e possono chiamarsi
per nome con Feign. Poi:

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
`task logs SERVICE=<nome>`, con il nome breve che vedi in `task status`.

Poi il ciclo è **solo questo**:

> scrivi il codice → `task compile` → il servizio si riavvia da solo in ~5 secondi

```bash
task compile
```

**Non rilanciare `task dev` a ogni modifica.** Ti serve solo quando cambi
qualcosa che un riavvio a caldo non copre: un `application.yml`, una porta, una
dipendenza, un modulo nuovo. Per quei casi c'è un comando apposta: vedi
[Modifiche strutturali](#modifiche-strutturali-dipendenze-porte-moduli).
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

> 💡 **MODALITÀ INTERATTIVA (WIZARD) PER TUTTI I COMANDI**:
> Non ricordi la sintassi o i parametri esatti? **Lancia il comando da solo, senza argomenti!**
> Per esempio: `task new-service`, `task new-entity`, `task add-relation`, `task new-client`, `task new-dto`, `task new-view`, `task new-auth`, `task new-handler`, `task add-dep`, `task set-port`, `task remove-service`, `task use-postgres`, `task consegna`.
> Ognuno di essi aprirà un comodo menu interattivo guidato nel terminale che rileverà i moduli e le opzioni disponibili e ti farà le domande passo dopo passo.

`task help` (o `task` da solo) stampa l'elenco; `task --summary <comando>` il
dettaglio di uno (variabili, valori di default, esempio). `task new-entity --help`
**non funziona**: `--help` lo intercetta `task` stesso, prima che arrivi allo
script — usa sempre `--summary`.

### Aggiungere una dipendenza a un microservizio

```bash
task add-dep SERVICE=ordini-service DEPS=security,mail
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
`task add-dep SERVICE=ordini-service DEPS=org.apache.commons:commons-lang3:3.17.0`.

> **Poi serve `task dev`, non `task compile`.** Il classpath di un servizio è
> fissato quando parte: un jar nuovo lo vede solo un riavvio vero. Vale per
> ogni dipendenza aggiunta e per ogni modulo nuovo.

`devtools` non serve aggiungerlo: è già nel pom padre, quindi ce l'hanno tutti
i moduli — è lui a dare l'hot reload dopo `task compile`.

### Cambiare una porta

```bash
task set-port SERVICE=ordini-service PORT=8090
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

Oppure lancialo senza argomenti (`task new-service`) per farti guidare dal wizard!
Crea il modulo (pom, `Main`, `application.yml`, un endpoint `/api/ping`) e lo
collega dove serve: `<modules>` del pom aggregatore, `COPY` nel `Dockerfile`,
blocco in `docker-compose.yml`, lista dei servizi di `task dev`. La porta è la
prima libera, se non la passi tu con `PORT=`.

Varianti: `UI=1` per un modulo Thymeleaf invece di un servizio REST, `NODB=1`
per un servizio senza JPA.

Poi `task dev`, e il servizio nuovo si registra su Eureka con gli altri.

### Generare Entity, Repository, Service e Controller: task new-entity

Invece di scrivere a mano le classi ripetitive di ogni tabella:

```bash
task new-entity SERVICE=ordini-service NAME=Ordine FIELDS=numero:string:required,totale:decimal:required,data:date DTO=1
```

Oppure semplicemente `task new-entity` per la modalità interattiva!
Genera le classi canoniche nello standard del progetto:
- `OrdineEntity.java` con annotazioni JPA e validazione Jakarta.
- `OrdineRepository.java` che estende `JpaRepository`.
- `OrdineDto.java` in `common-dto` (se `DTO=1`).
- `OrdineService.java` con il CRUD pronto (e mapper Entity <-> DTO).
- `OrdineController.java` con gli endpoint REST documentati in OpenAPI/Swagger.

> 💡 **Nota sui moduli con database e UI ibridi**:
> `task new-entity` elenca e accetta solo i moduli che contengono `spring-boot-starter-data-jpa` nel proprio `pom.xml`.
> Se hai creato un modulo UI (`UI=1`) o senza DB (`NODB=1`) e la traccia richiede che gestisca tabelle proprie (es. `cup-ui` con slot e medici locali), puoi abilitare JPA e H2 in un attimo:
> ```bash
> task add-dep SERVICE=cup-ui DEPS=data-jpa,h2
> ```
> Appena eseguito, il modulo comparirà automaticamente nell'elenco di `task new-entity`.

> 💡 **Gestione errori REST di default**:
> Ogni volta che crei un nuovo microservizio REST con `task new-service`, viene generato automaticamente `GlobalExceptionHandler.java` (`@RestControllerAdvice`), pronto a intercettare errori `@Valid` (restituendo HTTP 400 con la mappa dettagliata dei campi), `ResponseStatusException` (es. 404) ed eccezioni generiche (500). Sui moduli UI (`UI=1`) non viene generato di default per non restituire JSON al posto dei template Thymeleaf.

### Collegare le relazioni JPA: task add-relation

Per collegare due tabelle dello stesso database relazionale:

```bash
task add-relation SERVICE=catalogo-service FROM=Libro TO=Categoria TYPE=many-to-one
```

Oppure `task add-relation` senza parametri per scegliere entità e cardinalità dal menu interattivo!
Il comando:
- Inserisce `@ManyToOne`, `@OneToMany`, `@OneToOne` o `@ManyToMany` con `fetch = FetchType.LAZY`.
- Configura `@JoinColumn` sul lato proprietario e `mappedBy` sul lato inverso.
- Inserisce automaticamente `@JsonIgnoreProperties` su entrambi i lati per spezzare qualsiasi ciclo di serializzazione Jackson ed evitare lo `StackOverflowError` a monte!
- Importa tutte le annotazioni e collezioni necessarie.

### Contratti DTO e Feign Client in un solo comando: task new-client e task new-dto

I microservizi non condividono le entity: si scambiano DTO definiti nel modulo `common-dto`.
Per collegare due microservizi:

```bash
task new-client FROM=report-service TO=ordini-service DTO=OrdineDto FIELDS=id:long,numero:string:required,totale:decimal
```

Se passi `FIELDS=...` o se il DTO non esiste ancora in `common-dto`, il comando genera automaticamente il record Java `OrdineDto` con validazione in `common-dto` e crea subito dopo il `@FeignClient` dentro `FROM`.
Per generare solo un DTO: `task new-dto NAME=ProdottoDto FIELDS=...`.

### Pagine Web Thymeleaf: task new-view

Se stai lavorando su un modulo UI (`task new-service NAME=web-ui UI=1`):

```bash
task new-view SERVICE=web-ui NAME=Ordini FIELDS=numero:string:required,totale:decimal
```

Genera:
- `OrdiniController.java` con `@Controller` per le rotte GET e POST.
- `templates/ordini.html` con tabella dinamica per visualizzare i record e form HTML per l'inserimento con validazione.

### Sicurezza e Login: task new-auth

Per proteggere le API o aggiungere una pagina di login senza configurare Spring Security a mano:

```bash
task new-auth SERVICE=ordini-service TYPE=db        # Utenti su DB con BCrypt e ruoli (ROLE_USER, ROLE_ADMIN)
task new-auth SERVICE=web-ui TYPE=form             # Form login Thymeleaf con LoginController e login.html
task new-auth SERVICE=ordini-service TYPE=inmemory # Basic Auth leggera in memoria
```

### Gestione Errori Globale REST: task new-handler

Per intercettare gli errori di validazione (`@Valid`) e rispondere con un JSON chiaro (`400 Bad Request`) invece di schermate d'errore grezze:

```bash
task new-handler SERVICE=ordini-service
```

Genera `GlobalExceptionHandler.java` con `@RestControllerAdvice`.

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

Scritte le entity:

```bash
task seed-data
```

Scrive due righe nell'`application.yml` di ogni modulo con delle `@Entity`:

```yaml
dev-data:
  rows: 5
```

e da lì in poi, a ogni avvio, le tabelle ancora vuote si riempiono da sole. Lo
fa il pacchetto `devdata` di `common-dto`, dentro l'applicazione, **dopo** che
Hibernate ha creato le tabelle: costruisce oggetti delle tue classi `@Entity`
con valori inventati e li salva con `persist()`, come farebbe il tuo codice.
Per questo rispetta tutto quello che rispetta la tua applicazione:

- gli id li genera chi deve (IDENTITY, sequenze, UUID); chiavi composte e
  `@MapsId` compresi;
- le relazioni puntano a righe che esistono (prima si riempiono le tabelle a
  cui le altre puntano), e le tabelle di collegamento dei molti a molti si
  riempiono anche loro;
- gli `enum` sono i tuoi, salvati come stringa o come numero;
- lunghezza delle colonne, `@NotNull`, `@Size`, `@Min`/`@Max`, `@Email`,
  `@Past`/`@Future` e perfino `@Pattern`: una targa `[A-Z]{2}[0-9]{3}[A-Z]{2}`
  diventa `AB123CD`;
- i valori seguono il nome del campo e dell'entity: il `nome` di un Articolo è
  un prodotto, quello di una Categoria una categoria, una `citta` una città.

Una riga rifiutata viene rifatta con valori diversi; se proprio non entra si
passa oltre e il log dice perché: l'avvio non fallisce mai per i dati di
prova. Vale su H2, su PostgreSQL e dentro Docker, e un riavvio non duplica
niente, perché si riempiono solo le tabelle vuote.

Il comando poi fa la prova: compila, avvia ogni modulo su un H2 usa-e-getta e
ti dice tabella per tabella quante righe sono entrate — o perché no, adesso e
non davanti al docente.

```bash
task seed-data SERVICE=ordini-service ROWS=10
task seed-data ROWS=0      # spenti
```

**`task seed-data` (senza SQL=1) è solo per te, mentre sviluppi.** `task
consegna` toglie di proposito il pacchetto `devdata` e la riga `dev-data:
rows:` da ogni `application.yml`: nell'archivio finale non deve restare
traccia degli strumenti del template, solo codice tuo.

Se un modulo non ha ancora un `data.sql`, **`task consegna` lo genera in
automatico prima di impacchettare** (lanciando `task seed-data SQL=1` in modo
idempotente): chi apre la consegna si ritrova il database già pronto che si
popola all'avvio con lo script SQL, senza che tu debba ricordarti di lanciarlo
prima. Se vuoi invece generarlo tu prima della consegna (o con un numero di righe diverso):

```bash
task seed-data SQL=1
task seed-data SERVICE=ordini-service SQL=1 ROWS=10
```

Non serve scriverlo a mano: `SQL=1` genera le stesse righe di sempre (via
Hibernate, quindi con relazioni e vincoli rispettati) e le scrive in un
`data.sql` vero, come `INSERT` SQL semplici — nessuna sintassi di un motore in
particolare, letti dal database dopo che le righe ci sono davvero, non
costruiti a mano riga per riga. Quel file sopravvive alla consegna (`devdata`
no): quello che il correttore vede è un file SQL indistinguibile da uno
scritto a mano, non codice del template. Aggiunge anche da solo le due chiavi
che servono perché `data.sql` giri dopo Hibernate, anche su PostgreSQL:

```yaml
spring:
  jpa:
    defer-datasource-initialization: true
  sql:
    init:
      mode: always
      continue-on-error: true
```

e spegne `dev-data.rows` sul modulo (le righe ora sono fisse: non serve più
generarle a ogni avvio). Rilancialo quante volte vuoi: rigenera lo stesso
file. Se preferisci scrivere tu i valori esatti della tua traccia, scrivi un
`data.sql` a mano: `SQL=1` non tocca un `data.sql` che non ha scritto lui.

I dati di prova valgono punti: una demo su tabelle vuote non si vede.

> ⚠️ **Se lo stack è già acceso (`task dev` in corso)**: questo comando scrive
> solo `src/main/resources/application.yml`, e `mvnw spring-boot:run` non lo
> ricompila da solo — non è come salvare in un IDE con la build automatica. Il
> comando se ne accorge e te lo dice; la riga giusta dopo `task seed-data` è
> `task compile`, che ricompila e fa ripartire i moduli già avviati: da lì il
> riempimento scatta. Lanciarlo prima di `task dev` resta il modo più diretto.


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

Si chiama `demo` perché così nasce da Spring Initializr. Se all'esame preferisci
il nome del progetto:

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

## La Logica di Business: dove, quando e come scriverla

I comandi `task` generano in pochi secondi tutto lo scheletro dell'architettura: i microservizi, il database relazionale (H2 o Postgres), le entity, i repository JPA, i DTO, i controller REST con Swagger e i client Feign per comunicare tra servizi.
**La logica di business richiesta dalla traccia è l'unica parte di codice che scriverai tu a mano.**

### 1. DOVE si scrive?
Sempre e soltanto all'interno dei metodi della classe `@Service` (es. `src/main/java/.../service/OrdineService.java`), **MAI** nel Controller o nell'Entity:
- **No nel Controller**: il controller deve solo ricevere la richiesta HTTP, validarla con `@Valid` e delegare al service.
- **No nell'Entity**: l'entity rappresenta solo la riga del database.
- **Sì nel Service**: il service contiene le decisioni, le formule matematiche, i controlli di disponibilità e le chiamate inter-servizio con Feign.

### 2. QUANDO si scrive?
All'esame segui questo ordine naturale:
1. Generi i microservizi (`task new-service`)
2. Generi le entità con DTO (`task new-entity ... DTO=1`)
3. Colleghi le relazioni tra tabelle (`task add-relation`)
4. Colleghi i microservizi tra loro (`task new-client`)
5. 👉 **ADESSO apri il Service Java e inserisci la logica di business!**

### 3. Esempi pratici di Business Logic tipici d'esame:

#### Esempio 1: Calcolo e validazione importi (es. Carrello o Ordine)
Nel file `OrdineService.java`, arricchisci il metodo `crea` o aggiungi un metodo specifico:
```java
@Transactional
public OrdineDto creaOrdine(NuovoOrdineRequest req) {
    // 1. Regola di validazione di business
    if (req.quantita() <= 0) {
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La quantita' deve essere maggiore di zero");
    }

    // 2. Chiamata Feign a un altro microservizio per verificare disponibilità e prezzo
    ArticoloDto articolo = catalogoClient.perId(req.articoloId());
    if (!Boolean.TRUE.equals(articolo.disponibile())) {
        throw new ResponseStatusException(HttpStatus.CONFLICT, "Articolo non disponibile");
    }

    // 3. Formula di business (totale = prezzo * quantita con eventuale sconto)
    BigDecimal totale = articolo.prezzo().multiply(BigDecimal.valueOf(req.quantita()));
    if (req.quantita() >= 10) {
        totale = totale.multiply(BigDecimal.valueOf(0.90)); // 10% di sconto quantità
    }

    // 4. Salvataggio e restituzione DTO
    OrdineEntity ordine = new OrdineEntity();
    ordine.setArticoloId(req.articoloId());
    ordine.setQuantita(req.quantita());
    ordine.setTotale(totale);
    ordine.setData(LocalDate.now());

    return toDto(repository.save(ordine));
}
```

#### Esempio 2: Controllo giacenze e scalamento scorte
```java
@Transactional
public void decrementaGiacenza(Long articoloId, int quantita) {
    ArticoloEntity articolo = repository.findById(articoloId).orElseThrow(
        () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Articolo non trovato"));
    
    if (articolo.getGiacenza() < quantita) {
        throw new ResponseStatusException(HttpStatus.CONFLICT, "Giacenza insufficiente: disponibili solo " + articolo.getGiacenza() + " pezzi");
    }
    
    articolo.setGiacenza(articolo.getGiacenza() - quantita);
    if (articolo.getGiacenza() == 0) {
        articolo.setDisponibile(false);
    }
    // Hibernate esegue l'UPDATE automatico alla fine del metodo transazionale!
}
```

### 4. Come collaudare subito la logica?
- Salva il file Java.
- Nel terminale dai `task compile` (che ricarica il jar in ~5 secondi con devtools).
- Apri **Swagger UI** (`http://localhost:<porta>/swagger-ui.html`) e clicca **Try it out** sul metodo per testare la richiesta.

---

## Il Percorso Completo Guidato per una Traccia d'Esame (Passo dopo Passo)

Ecco la scaletta esatta da seguire per svolgere qualsiasi traccia d'esame:

1. **Inizializzazione**:
   - `task rete` e `task check` per verificare che l'ambiente sia pronto.
2. **Creazione Microservizi**:
   - `task new-service` (in modalità interattiva per ogni servizio del dominio, es. `catalogo-service`, `ordini-service`).
   - Se la traccia chiede una web app: `task new-service NAME=web-ui UI=1`.
3. **Creazione Entità e Tabelle**:
   - `task new-entity` (in modalità interattiva con `DTO=1` per ogni tabella richiesta, es. `Categoria`, `Articolo`, `Ordine`).
4. **Relazioni JPA e DTO-in-DTO**:
   - `task add-relation` (in modalità interattiva per collegare le chiavi esterne `@ManyToOne` e generare il nested DTO).
5. **Comunicazione tra Microservizi**:
   - `task new-client` (per creare il client Feign nel servizio chiamante che deve interrogare l'altro).
6. **Scrittura della Logica di Business**:
   - Apri i file `...Service.java` ed inserisci i calcoli, i controlli di integrità e le chiamate Feign.
7. **Interfaccia Web (se richiesta)**:
   - `task new-view` (collega automaticamente la vista Thymeleaf al Feign Client per elenco e form).
8. **Dati di Prova e Schema del Database**:
   - `task seed-data` per riempire le tabelle con dati plausibili validati.
   - `task db-schema` per generare il diagramma ER e il modello concettuale/logico.
9. **Avvio e Collaudo**:
   - `task dev` per avviare tutto lo stack.
   - Controlla con `task status`, su Eureka (`http://localhost:8761`) e prova le API su Swagger UI.
10. **Consegna Finale**:
    - `task consegna NOME=MIO_COGNOME` per generare lo ZIP completo e autosufficiente con l'allegato tecnico.

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

Aspetta che `task status` mostri i tuoi servizi registrati su Eureka, poi
apri nell'ordine:

1. la tua UI — l'applicazione (l'indirizzo lo stampa `task dev`)
2. `http://localhost:8761` — la dashboard Eureka, per far vedere il discovery
3. lo Swagger di un servizio — i contratti OpenAPI

Se ti chiedono della **resilienza**, spegni un servizio davanti a loro e
ricarica la pagina: resta in piedi con i segnaposto invece di andare in
errore. Dalla cartella dei moduli (quella con `docker-compose.yml`), col nome
del servizio:

```bash
docker compose stop <servizio>
```

e poi `docker compose start <servizio>` per riaccenderlo.

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
| `<modulo>/` | i sorgenti di ogni microservizio, **senza** `target/` |
| `docker-compose.yml` + `Dockerfile` + pom + wrapper | accanto ai moduli, come nel progetto: lo stack riparte dai sorgenti |
| `ALLEGATO-TECNICO.md` | già compilato con moduli, porte, endpoint e schema del database |
| `SCHEMA-DATABASE.md` | lo schema concettuale e logico da solo, comodo da copiare |
| `ISTRUZIONI-ESECUZIONE.md` | come far girare il progetto, con e senza Docker |
| `COGNOME_NOME.zip` | tutto quanto sopra in un archivio solo: **è quello da consegnare** |

Le cartelle `target/` restano fuori apposta: sono megabyte di roba
ricompilabile.

Dentro l'archivio non ci sono altri archivi: chi corregge lo scompatta, entra
nella cartella dove c'è `docker-compose.yml` e lancia
`docker compose up -d --build`. Prima di consegnare fai tu la stessa prova:
scompatta `COGNOME_NOME.zip` in una cartella nuova e avvialo da lì.

Le parti dell'allegato che scrivi tu — analisi, algoritmo, che cosa fa ogni
modulo, e se servono le risposte teoriche — stanno in `allegato.md`, nella
cartella del progetto, una sezione `##` per parte. La prima consegna lo crea
con i titoli pronti; le altre ne prendono il testo e lo mettono al suo posto
in `ALLEGATO-TECNICO.md` **prima** di fare l'archivio, così l'archivio ha
sempre dentro l'ultima versione e puoi rilanciare la consegna quante volte
vuoi. Alla fine ti dice che cosa manca ancora. Il resto (moduli con porte e
nome Eureka, endpoint di ogni controller, schema del database) è ricavato dal
progetto.

Lo schema del database lo puoi anche guardare da solo, in qualunque momento:

```bash
task db-schema
```

Avvia ogni modulo con delle `@Entity` su un database H2 usa-e-getta, lascia
che Hibernate crei le tabelle e le interroga: entità e relazioni (modello
concettuale), tabelle, colonne, tipi SQL, chiavi e vincoli (modello logico),
più un diagramma ER in mermaid che GitHub e VS Code disegnano da soli. Le
tabelle di collegamento, le colonne delle relazioni e i valori ammessi degli
enum sono quelli che Hibernate crea davvero, non quelli che ci si aspetta.
Funziona a stack spento e senza rete: serve solo Maven.

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
| `task ide-sync` | Riallinea VS Code e Zed ai moduli veri (lo chiamano da soli new-service, remove-service, set-port) |
| `task rename-project` | Rinomina la cartella dei moduli Maven, ovunque sia nominata |
| `task seed-data` | Dati di prova: a ogni avvio le tabelle vuote si riempiono, passando da Hibernate |
| `task db-schema` | Schema concettuale e logico, letto dal database che crea Hibernate |
| `task consegna` | Prepara la cartella da consegnare (`NOME=COGNOME_NOME`) |
| `task learn` | Il corso nel browser, dalla traccia alla consegna |
| `task rete` | Quali domini passano dalla rete dell'aula, e cosa fare se no |
| `task offline-prep` | **La sera prima, a casa**: scarica tutto quello che servirà all'esame |
| `task offline` | Dice se il progetto partirebbe anche senza rete |
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
