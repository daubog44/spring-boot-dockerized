# Spring Boot Dockerized - Soluzione d'Esame WMS

Questo branch contiene la **soluzione d'esame completa e collaudata** per la traccia **WMS Magazzino "Spostati S.r.l."**, costruita sul template multi-modulo Maven del branch [`main`](https://github.com/daubog44/spring-boot-dockerized/tree/main) con **Spring Boot**, **Spring Cloud Eureka**, **OpenFeign**, **OpenAPI/Swagger UI**, **PostgreSQL** e **Docker Compose**.

---

## 📚 Documentazione & Guide per l'Esame

- **[🚨 Il giorno dell'esame: procedura operativa](./GIORNO-ESAME.md)** — le quattro fasi, dal clone alla demo. Parti da qui.
- **[📓 Il corso: Dalla traccia alla consegna](./corso/index.html)** — diciassette lezioni dalla A alla Z: com'è fatto il template, come si parlano i servizi, `common-dto`, la rete dell'esame, e poi la traccia **Biblioteca** svolta pezzo per pezzo col suo codice, fino al collaudo, a Docker e alla consegna. Dentro ci sono anche tutte le guide, con la ricerca, e la mappa dei moduli di questo progetto. Si apre con **`task learn`**: pagina statica, senza server e senza rete.
- [La giornata alla lavagna](./corso/giornata.html) — la stessa giornata in nove fasi, con una lavagna che le legge ad alta voce; il video lo registra `powershell -File corso/genera-video.ps1`.
- [📖 Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [📘 Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md) — con il **cheat sheet di Thymeleaf** (§ 6.7)
- [🛠️ Guida 3: Multi-Modulo Maven e Funzionamento](./guida_multi_modulo_maven.md)
- [📝 Documentazione Specifica Esame (README-ESAME-TTFCLOUD.md)](./README-ESAME-TTFCLOUD.md)

---

## 🌿 Branch del Repository

- **[`main`](https://github.com/daubog44/spring-boot-dockerized/tree/main)**: Template d'Esame pulito e neutro, adattabile a qualsiasi traccia.
- **`solution/wms`** (questo branch): Soluzione completa della traccia **WMS Magazzino "Spostati S.r.l."** con algoritmo di calcolo distanza Manhattan, DTO condivisi e script di collaudo automatizzato PowerShell.
- **[`example/tourist-events`](https://github.com/daubog44/spring-boot-dockerized/tree/example/tourist-events)**: Esempio svolto della traccia Eventi/Turismo (OpenDataHub).

---

## 🏗️ Architettura dei Servizi WMS

Il progetto è un aggregatore Multi-Module Maven dentro la cartella `demo`. I moduli **attivi in questa soluzione** sono:

1. **`naming-server`**: Eureka Naming Server (Porta `8761`).
2. **`common-dto`**: Modulo libreria con i DTO condivisi tra i microservizi.
3. **`product-service`** (Porta `8081`): Anagrafica prodotti (`ProductController`), persistenza JPA/Hibernate.
4. **`crm-service`** (Porta `8082`): Anagrafica clienti (`CustomerController`). Servizio mock: **nessuna persistenza**, dati in memoria.
5. **`wms-service`** (Porta `8083`): Backend di magazzino (`WmsController`) con persistenza JPA/Hibernate. Consuma `PRODUCT-SERVICE` e `CRM-SERVICE` via OpenFeign (`ProductClient`, `CrmClient`) risolti tramite Eureka.
6. **`wms-ui`** (Porta `8080`): Web UI Thymeleaf (`WmsUiController`), consuma `WMS-SERVICE` via OpenFeign (`WmsClient`).

> 💡 Il branch conserva anche i moduli scheletro del template (`tourist-service`, `random-service`, `store-service`, `event-ui`): sono dichiarati nel `pom.xml` aggregatore ma **non fanno parte dello stack Docker WMS**.

Nomi con cui i servizi si registrano su Eureka: `PRODUCT-SERVICE`, `CRM-SERVICE`, `WMS-SERVICE`, `WMS-UI`.

### 🗄️ Database

`product-service` e `wms-service` girano di default su **H2 in-memory**: i dati vengono ricreati a ogni riavvio del container. Entrambi hanno comunque il driver PostgreSQL a classpath e l'URL è parametrico, quindi si passa a Postgres senza toccare il codice, valorizzando le variabili d'ambiente nel `docker-compose.yml`:

- `product-service`: `PRODUCT_DB_URL`, `PRODUCT_DB_DRIVER`
- `wms-service`: `WMS_DB_URL`, `WMS_DB_DRIVER`

> ⚠️ Il `docker-compose.yml` **avvia il container `postgres` ma non lo collega ad alcun servizio**: finché quelle variabili non sono impostate, PostgreSQL resta inutilizzato. Tienilo presente se la traccia richiede persistenza reale.

---

## ⚡ Come lavorare durante l'esame

**Per sviluppare, un comando solo:**

```bash
task dev
```

Prima **libera le porte**: ferma i servizi di un avvio precedente, spegne i container dell'esame se sono loro a tenerle e chiude le applicazioni estranee rimaste in ascolto (non tocca i processi di sistema né l'infrastruttura di Docker). Poi compila tutti i moduli una volta sola, avvia Eureka, ne attende la porta e infine lancia gli altri quattro servizi.

**Un terminale solo, nessuna finestra sparsa**: i servizi girano in background e scrivono in `.dev-logs/`. Per vedere cosa fanno:

```bash
task logs
```

Mostra l'output di tutti i servizi insieme, ogni riga prefissata dal nome (`wms | ...`) e di un colore diverso. `Ctrl+C` chiude solo la vista, i servizi restano su. Per seguirne uno solo: `task logs SERVICE=wms`.

**Hot reload**: ogni servizio gira con `spring-boot-devtools`. Dopo aver modificato del codice:

```bash
task compile
```

Il servizio interessato si riavvia da solo in pochi secondi, senza rilanciare nulla. In VS Code, con la build automatica attiva, il riavvio parte già al salvataggio.

**Per fermare tutto:**

```bash
task dev-down
```

Libera le porte esattamente come fa `task dev` all'avvio: usano la stessa funzione, quindi non possono comportarsi in modo diverso.

**Quando qualcosa non risponde**, prima di ogni altra cosa:

```bash
task status
```

Dice chi occupa ognuna delle porte (un tuo servizio, i container, o un'applicazione estranea), quali container girano e cosa si è registrato su Eureka.

> 💡 Se su una delle porte gira un'applicazione che ti serve viva, dillo: `task dev KEEPFOREIGN=1 UI_PORT=9080`. Senza `KEEPFOREIGN=1` viene chiusa.

**Per la demo finale**, usa lo stack containerizzato, che è quello che presenterai:

```bash
task docker-up
```

Locale e Docker usano le stesse porte, ma non devi ricordartene: `task docker-up` ferma da solo lo stack locale prima di partire, e `task dev` spegne da solo i container (con `docker compose down`, i dati del database restano).

### Elenco completo dei task

Il comando `task` da solo stampa questo elenco.

Sviluppo:

- `task wizard`: Fa le domande e monta il progetto (`SERVICE=<modulo>` per uno solo).
- `task new-entity SERVICE=<modulo> NAME=<Nome> FIELDS=...`: Genera entity, repository, service e controller.
- `task consegna NOME=COGNOME_NOME`: Prepara la cartella da consegnare.
- `task seed-data`: Dati di prova ricavati dalle `@Entity`.
- `task db-schema`: Schema concettuale e logico ricavato dalle `@Entity`.
- `task db-config`: Stampa o cambia le credenziali del database.
- `task rename-project NAME=<nome>`: Rinomina la cartella dei moduli Maven.
- `task ide-sync`: Riallinea VS Code e Zed ai moduli veri.
- `task learn`: Il corso nel browser, dalla traccia alla consegna.
- `task rete`: Quali domini passano dalla rete dell'aula (all'esame e' filtrata: Maven Central passa).
- `task offline-prep` / `task offline`: Scarica la sera prima, e verifica, quello che la rete potrebbe non far passare.
- `task dev`: Pulisce, compila e avvia l'intero stack in locale con hot reload.
- `task dev-down`: Ferma i servizi locali e libera le porte.
- `task logs`: Segue i log di tutti i servizi in un terminale solo (`task logs SERVICE=wms` per uno).
- `task status`: Chi occupa le porte, quali container girano, cosa è registrato su Eureka.
- `task compile`: Ricompila e fa ripartire i servizi già avviati.
- `task build`: Compila e impacchetta tutti i moduli Maven tramite wrapper (`mvnw`).

Container:

- `task docker-up`: Avvia l'intero stack WMS su Docker Compose con healthcheck.
- `task docker-down`: Ferma i container. **I dati del database restano.**
- `task docker-reset`: Ferma i container **ed elimina i volumi**: database ricreato da zero.
- `task docker-logs`: Monitora i log di tutti i microservizi.

Collaudo e pulizia:

- `task test-e2e`: Esegue lo script di collaudo automatizzato [`test_e2e_wms.ps1`](./test_e2e_wms.ps1). Si può lanciare anche a stack acceso: se ne accorge e compila senza `clean`, per non far cadere i servizi.
- `task clean-ports`: Come `dev-down`, libera le porte dello stack.
- `task kill-java`: Ultima spiaggia, termina **tutti** i processi Java della macchina, anche quelli estranei al progetto.

Avvio manuale dei singoli moduli, se ti serve isolarne uno: `task run-eureka`, `task run-product`, `task run-crm`, `task run-wms`, `task run-wms-ui`, `task run-db`.

---

### L'editor

Apri **la cartella del repository**, non quella di un singolo servizio: e' un
progetto Maven multi-modulo.

- **VS Code**: `F5` -> **Stack completo** avvia tutti i servizi in debug, Eureka
  per primo. Serve l'*Extension Pack for Java*; le altre estensioni consigliate
  te le propone VS Code stesso (`.vscode/extensions.json`).
- **Zed**: `F4` → il servizio da avviare in debug (`.zed/debug.json`); palette
  → *task: Spawn* per i comandi `task`. Serve l'estensione *Java*, che al primo
  file `.java` scarica jdtls, Lombok e il debugger: la prima volta, con la rete.
- **IntelliJ IDEA**: niente da configurare, apri il pom aggregatore.

`launch.json` e i due `tasks.json` sono generati: li riscrivono `new-service`,
`remove-service` e `set-port`. Se l'elenco dei servizi non torna:

```bash
task ide-sync
```

## Wizard, dati di prova e consegna

Il giorno dell'esame, letta la traccia, il modo piu' rapido per montare il
progetto e' il wizard: chiede come si chiama la cartella dei moduli, se serve
PostgreSQL e con quali credenziali, e poi i microservizi uno per uno.

```bash
task wizard
```

Per un microservizio solo: `task wizard SERVICE=<nome>`. Non fa niente di
magico: chiama `set-java`, `rename-project`, `set-package`, `db-config`,
`new-service` e `use-postgres` nell'ordine giusto, e finisce con `task check`.


Scritte le entity, due comandi le mettono al lavoro. Tutti e due passano dal
database vero, non dalla lettura dei sorgenti: avviano l'applicazione, lasciano
che Hibernate crei le tabelle e lavorano su quelle.

```bash
task seed-data
```

Accende i dati di prova: a ogni avvio le tabelle vuote si riempiono da sole
con righe plausibili, salvate passando da Hibernate, quindi con id, relazioni,
enum e vincoli di validazione rispettati. Prima prova su un H2 usa-e-getta e
ti dice tabella per tabella com'e' andata. Una demo su tabelle vuote non si
vede.

```bash
task db-schema
```

Lo schema concettuale e logico della base dati - entita' e relazioni, tabelle,
colonne, tipi SQL, chiavi, vincoli e un diagramma ER - letto dal database dopo
che Hibernate l'ha creato. E' quello che chiede l'allegato tecnico.

E a fine giornata:

```bash
task consegna NOME=COGNOME_NOME
```

Prepara `consegna/`: il progetto pronto da eseguire (i moduli senza `target/`,
accanto a pom e compose), l'allegato tecnico già compilato con moduli, porte,
endpoint e schema, le istruzioni di esecuzione, e un archivio unico da
consegnare. Chi lo corregge lo scompatta e lancia `docker compose up --build`.

### La rete all'esame

All'esame la rete passa da una whitelist di domini: Maven Central si', il
resto non si sa.

```bash
task rete
```

Dice, dominio per dominio (Maven Central, Docker Hub, Ubuntu, GitHub, le
estensioni di VS Code), se risponde e che cosa fare se no. La sera prima, con
la connessione di casa, `task offline-prep` scarica quello che potrebbe non
passare: le dipendenze Maven, anche quelle dei moduli che creerai, le immagini
Docker, una prima build dei container e una copia di scorta del comando
`task` stesso (in `.tools/task`, per quando GitHub non passa o la macchina
dell'esame non ce l'ha: si attiva con `scripts/usa-task-locale.ps1`/`.sh`).
`task offline` verifica. Portati la cartella del progetto e la `~/.m2` su una
chiavetta: il template *e'* la cartella, non serve altro.

---

## 🌐 Mappa delle Porte ed Interfacce OpenAPI / Swagger UI

- **UI Applicativa WMS**: `http://localhost:8080`
- **Dashboard Eureka**: `http://localhost:8761`
- **PostgreSQL**: `localhost:5432` (db `event_suggestions`, utente `exam`, password `exam`) — avviato ma non collegato ai servizi, vedi sezione Database
- **Swagger UI Product Service**: `http://localhost:8081/swagger-ui.html`
- **Swagger UI CRM Service**: `http://localhost:8082/swagger-ui.html`
- **Swagger UI WMS Service**: `http://localhost:8083/swagger-ui.html`
- **Swagger UI WMS UI**: `http://localhost:8080/swagger-ui.html`

---

## 🩺 Troubleshooting

### `dependency failed to start: container <cartella>-eureka-server-1 is unhealthy`

Sintomo: `task docker-up` fallisce, il container di `eureka-server` risulta `unhealthy` e nessun microservizio parte, anche se nei log Eureka scrive regolarmente `Started Eureka Server`.

Causa: l'healthcheck di `eureka-server` invoca `curl` su `/actuator/health`, ma l'immagine runtime `eclipse-temurin:25-jre` **non include `curl`**. Ogni probe fallisce con `curl: not found`, il container resta `unhealthy` e tutti i servizi con `depends_on: condition: service_healthy` non vengono mai avviati.

Il `demo/Dockerfile` di questo repo installa già `curl` nello stage runtime, quindi il problema non si presenta. Se aggiungi un healthcheck HTTP a un altro servizio, ricordati che vale la stessa regola.

Per capire *perché* un healthcheck non passa, leggi l'output delle probe (dalla cartella dei moduli, quella con `docker-compose.yml`):

```bash
docker inspect $(docker compose ps -q eureka-server) --format "{{json .State.Health}}"
```

### Su `http://localhost:8080` risponde qualcos'altro

Sintomo: il browser mostra una pagina che non è la tua (`Method Not Allowed`, un errore di un altro server, una app che non c'entra), anche se i servizi risultano avviati.

Causa: un'altra applicazione della macchina è in ascolto su `127.0.0.1:8080`. Su Windows il bind più specifico vince su quello generico, quindi `http://localhost:8080` finisce a quel processo anche quando Docker pubblica la porta su `0.0.0.0`. Se invece è lo stack locale a dover partire, Tomcat non riesce nemmeno a fare il bind e il servizio muore con `Web server failed to start. Port 8080 was already in use`.

```bash
task status
```

Elenca ogni processo in ascolto sulle porte dello stack e segnala esplicitamente questo caso. `task dev` chiude da solo quel processo al prossimo avvio; se invece ti serve tenerlo vivo, sposta la UI con `task dev KEEPFOREIGN=1 UI_PORT=9080` (e poi collauda con `task test-e2e UI_PORT=9080`).

### Altri controlli utili

```bash
docker compose ps
```

```bash
docker compose logs wms-service --tail 50
```

Per verificare quali servizi si sono effettivamente registrati su Eureka:

```bash
docker compose exec eureka-server curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps
```

I container non hanno un nome fisso: Docker Compose li chiama `<progetto>-<servizio>-1`, e il progetto è la cartella del repository (lo impostano il Taskfile e gli script). Così la copia di prova e quella dell'esame hanno container e volume del database loro, anche con credenziali diverse. Per questo i comandi qui sopra usano il nome del **servizio** (`eureka-server`, `postgres`), e vanno lanciati dalla cartella dei moduli; fuori da `task`, `docker compose` usa il nome della cartella dei moduli, quindi aggiungi `-p <cartella-del-repository>`.
