# Il giorno dell'esame — procedura operativa

Questa pagina è pensata per essere aperta e seguita, non ricordata. Se hai un
minuto solo, leggi le **quattro fasi** qui sotto e ignora il resto finché non
serve.

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

## Se qualcosa va storto

| Sintomo | Cosa fare |
| :--- | :--- |
| Un servizio non risponde | `task status`, poi `task logs SERVICE=<servizio>` |
| "Port N was already in use" | `task dev`: chiude lui chi tiene la porta |
| Su `localhost:8080` risponde un'altra app | `task dev` la chiude; se ti serve viva, `task dev KEEPFOREIGN=1 UI_PORT=9080` |
| Hai modificato il codice e non cambia niente | `task compile` (e controlla che non ci siano errori di compilazione) |
| Hai aggiunto una dipendenza e non la vede | `task dev`: il classpath si fissa all'avvio, `task compile` non basta |
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
| `task dev` | Libera le porte, compila e avvia tutto in background con hot reload |
| `task logs` | Segue i log di tutti i servizi in un terminale solo |
| `task compile` | Ricompila: i servizi toccati si riavviano da soli |
| `task status` | Chi occupa le porte, container attivi, registro Eureka |
| `task dev-down` | Ferma i servizi locali e libera le porte |
| `task add-dep` | Aggiunge dipendenze al pom di un modulo (`LIST=1` per l'elenco) |
| `task set-port` | Sposta un modulo su un'altra porta, ovunque sia scritta |
| `task new-service` | Crea un microservizio nuovo e lo collega a tutto |
| `task remove-service` | Toglie un modulo dal progetto e da tutti i file |
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
