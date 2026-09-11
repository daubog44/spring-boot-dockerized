# Guida 1: Setup & Cheat Sheet Operativo per l'Esame

Guida rapida e prassi operative per eseguire, collaudare e gestire in emergenza l'ambiente **Spring Boot Dockerized** il giorno della prova finale.

---

## 1. Verifiche Preliminari Ambiente Host

Prima di iniziare l'esame, apri il terminale e verifica la presenza degli strumenti:

```bash
git --version
docker --version
docker compose version
task --version
java --version
```

- **Docker Desktop / Docker Engine**: Deve essere in esecuzione.
- **Java 17 o più recente** (il template nasce su Java 25): `task set-java` allinea pom, Dockerfile e VS Code al JDK installato (quello di `JAVA_HOME`, se no quello del `PATH`). Lo fa da solo anche `task wizard`, all'inizio.
- **Task (`go-task`)**: Strumento per l'automazione dei comandi d'esame.

---

## 2. Modalità d'Avvio Principali

### A. Avvio Stack Completo Containerizzato (CONSIGLIATO PER LA DEMO)

Esegue tutti i 5 microservizi Spring Boot e il database PostgreSQL in container Docker isolati:

```bash
# Entra nella cartella di progetto
cd spring-boot-dockerized

# Compila l'intero progetto e avvia i container
task docker-up
```

Per monitorare i log in tempo reale:
```bash
task docker-logs
```

Per arrestare i container conservando i dati del database:
```bash
task docker-down
```

Per ripartire da un database vuoto (rimuove anche i volumi):
```bash
task docker-reset
```

> ℹ️ Locale e Docker usano le stesse porte, ma non devi ricordartene: `task docker-up` ferma da solo lo stack locale prima di partire, e `task dev` spegne da solo i container (con `docker compose down`, i dati del database restano).

---

### B. Sviluppo Locale con Hot Reload (CONSIGLIATO MENTRE SVILUPPI)

Un solo comando libera le porte (chiudendo chi le tiene occupate), avvia PostgreSQL, compila tutto e lancia Eureka e i quattro servizi:

```bash
task dev
```

I servizi girano in background: niente finestre sparse, un terminale solo. Per vedere l'output di tutti insieme, ogni riga prefissata dal nome del servizio:

```bash
task logs
```

`Ctrl+C` chiude solo la vista, i servizi restano su. Per uno solo: `task logs SERVICE=store`. I log restano comunque su file in `.dev-logs/`.

Dopo una modifica al codice, ricompila e i servizi interessati si riavviano da soli grazie a `spring-boot-devtools`:

```bash
task compile
```

Per fermare lo stack locale e liberare le porte (ferma anche il PostgreSQL avviato da `task dev`, conservando i dati):

```bash
task dev-down
```

Quando qualcosa non risponde, il primo comando da lanciare è:

```bash
task status
```

Dice chi occupa ogni porta (un tuo servizio, i container, o un'applicazione estranea), quali container girano e cosa si è registrato su Eureka.

**Perché non usare `task docker-up` mentre sviluppi**: `docker compose build` ricostruisce tutte e cinque le immagini, e poiché il `Dockerfile` copia i sorgenti prima di compilare, ogni singola modifica invalida la cache e fa ricompilare tutto in ogni immagine. Un ciclo costa minuti contro i ~20 secondi del build locale.

---

### C. Avvio Manuale dei Singoli Moduli

Se ti serve isolare un servizio, in terminali distinti:

```bash
task run SERVICE=<modulo>
```

Le scorciatoie di questa traccia:

```bash
task run-db
task run-eureka
task run-tourist
task run-random
task run-store
task run-ui
```

---

## 3. Mappa delle Porte ed Endpoint OpenAPI / Swagger UI

| Servizio | Porta Host | Endpoint Principal / Dashboard | Swagger UI (Contratti OpenAPI) |
| :--- | :---: | :--- | :--- |
| **Event UI** | `8080` | `http://localhost:8080` | `http://localhost:8080/swagger-ui.html` |
| **Eureka Naming Server** | `8761` | `http://localhost:8761` | N/A (Dashboard Eureka) |
| **Tourist Service** | `8081` | `http://localhost:8081/api/events/nearby` | `http://localhost:8081/swagger-ui.html` |
| **Random Service** | `8082` | `http://localhost:8082/api/random` | `http://localhost:8082/swagger-ui.html` |
| **Store Service** | `8083` | `http://localhost:8083/api/suggestions` | `http://localhost:8083/swagger-ui.html` |
| **PostgreSQL DB** | `5432` | `jdbc:postgresql://localhost:5432/event_suggestions` | N/A (Postgres Native) |

### Il database

Il `docker-compose.yml` contiene **un** container PostgreSQL (database `esame`,
utente e password `exam`), che di suo non è collegato a nessun servizio: i
moduli creati da `task new-service` usano H2 in memoria. Per collegarne uno:

```bash
task use-postgres SERVICE=<modulo>
```

Con `DBNAME=<nome>` quel modulo ottiene un database tutto suo, sempre dentro
lo stesso container. Vedi GIORNO-ESAME.md, "Collegare un servizio a PostgreSQL".



Le credenziali non sono scolpite nella pietra:

```bash
task db-config
```

Senza variabili stampa nome, utente, password, porta e moduli collegati. Con
`DBNAME=`, `USER=`, `PASSWORD=` o `PORT=` le cambia in tutti i punti in cui
sono scritte (container, healthcheck, variabili dei moduli, `application.yml`,
script di init). Dopo un cambio di nome, utente o password serve un
`task docker-reset`: PostgreSQL crea utente e database solo al primo avvio.

E per non presentare tabelle vuote:

```bash
task seed-data
```

Accende i dati di prova: a ogni avvio le tabelle vuote si riempiono da sole,
con righe salvate passando da Hibernate (id, relazioni, enum e vincoli
rispettati). Prima prova su un H2 usa-e-getta e ti dice com'è andata.

---

## 4. Collaudo Rapido & Coordinate Demo (Bolzano)

Per dimostrare il funzionamento durante la presentazione della prova finale, inserisci nella UI o nei test HTTP le seguenti coordinate testate:

### Coordinate Bolzano Centro:
- **Latitudine**: `46.4983`
- **Longitudine**: `11.3548`
- **Raggio**: `10000` (metri)
- **Limit**: `5` (eventi)
- **Lingua**: `it`

### Test Rapido via `curl` (API Direct Check)

```bash
# 1. Test Tourist Service via OpenDataHub Wrapper
curl "http://localhost:8081/api/events/nearby?latitude=46.4983&longitude=11.3548&limit=5&radius=10000&language=it"

# 2. Test Random Service
curl "http://localhost:8082/api/random?upperBound=5"

# 3. Test Store Service (Storico)
curl "http://localhost:8083/api/suggestions?limit=10"
```

---

## 5. Cheat Sheet Risoluzione Emergenze Esame

### 🚨 Emergenza 1: "Porta 8080 / 8761 / 5432 già in uso"
Prima di tutto, guarda chi la occupa:
```bash
task status
```

Nella maggior parte dei casi non devi fare niente: **`task dev` libera lui le porte all'avvio**, chiudendo i suoi servizi rimasti appesi, i container dell'esame e le applicazioni estranee in ascolto. Restano intoccati solo i processi di sistema e l'infrastruttura di Docker, che ti vengono segnalati.

Per liberarle senza avviare nulla:
```bash
task dev-down
```
Come ultima risorsa, termina tutti i processi Java della macchina — **anche quelli estranei al progetto, IDE compreso**:
```bash
task kill-java
```

Perché conta: Tomcat non riesce a fare il bind nemmeno quando l'altro processo ascolta solo su `127.0.0.1`, e il servizio muore con `Web server failed to start. Port N was already in use`. E se lo stack è nei container, la porta è pubblicata ma `http://localhost:8080` continua a rispondere dall'altra applicazione, perché su Windows il bind più specifico vince.

Se su una di quelle porte gira qualcosa che ti serve viva, dillo e sposta la UI:
```bash
task dev KEEPFOREIGN=1 UI_PORT=9080
```

### 🚨 Emergenza 1-bis: "container ...-eureka-server-1 is unhealthy"
`task docker-up` si interrompe con `dependency failed to start: container <cartella>-eureka-server-1 is unhealthy`, ma nei log Eureka scrive `Started Eureka Server`. L'healthcheck usa `curl`, che l'immagine `eclipse-temurin:25-jre` non contiene. Il `demo/Dockerfile` di questo repo lo installa già; se aggiungi un healthcheck HTTP a un altro servizio vale la stessa regola. Per leggere l'esito delle probe, dalla cartella dei moduli:
```bash
docker inspect $(docker compose ps -q eureka-server) --format "{{json .State.Health}}"
```

### 🚨 Emergenza 1-ter: "porta occupata da processo sconosciuto"

`task dev` dice che una porta è occupata, `task status` la segna **RISERVATA** e
nessun processo risulta in ascolto. Non c'è niente da chiudere: Windows si
riserva interi intervalli di porte (Hyper-V, WSL, **l'avvio di Docker
Desktop**), e dentro quegli intervalli non fa il bind nessuno — né un servizio
locale né un container, per cui anche `task docker-up` fallirebbe con
`bind: An attempt was made to access a socket in a way forbidden by its access permissions`.

Per vedere gli intervalli:
```bash
netsh interface ipv4 show excludedportrange protocol=tcp
```

Due strade: spostare il servizio fuori dagli intervalli,
```bash
task set-port SERVICE=<modulo> PORT=<porta libera>
```
oppure liberare le riserve, da terminale **amministratore** (chiude Docker):
```bash
net stop winnat
```
```bash
net start winnat
```

### 🚨 Emergenza 2: "Docker Compose non aggiorna il codice modificato"
Se hai modificato il codice Java ma `task docker-up` usa la vecchia immagine cached:
```bash
cd demo
docker compose build --no-cache
docker compose up -d
```

### 🚨 Emergenza 3: "PostgreSQL non si connette o DDL-Auto fallisce"
Reset completo del volume del database:
```bash
task docker-reset
```
```bash
task docker-up
```

> ⚠️ `task docker-reset` **cancella i dati**. Per il semplice arresto usa `task docker-down`, che conserva il volume.

> ℹ️ Il volume è montato su `/var/lib/postgresql`, non sul percorso legacy `/var/lib/postgresql/data`: dalla versione 18 l'immagine tiene i dati in `/var/lib/postgresql/<versione>/docker`, e col mount vecchio il volume restava vuoto e il container non partiva.

### 🚨 Emergenza 4: "Eureka registra i servizi ma i Feign Client danno 500"
Ogni servizio tiene una copia locale del registro di Eureka, e il load balancer di Feign una copia di quella. Con i valori di Spring le due cache insieme fanno anche 30-60 secondi di "Load balancer does not contain an instance for the service ...". I moduli creati da `task new-service` le accorciano a 5 secondi (`registry-fetch-interval-seconds` e `spring.cloud.loadbalancer.cache.ttl` nell'`application.yml`), e Eureka rinfresca le sue risposte ogni 5: dopo l'avvio bastano pochi secondi. Se un modulo scritto a mano ha ancora il problema, copia quelle righe da un modulo generato.


---

## 6. L'editor

Apri **la cartella del repository**: e' un progetto Maven multi-modulo, e
l'editor deve vedere il pom aggregatore.

**VS Code** trova gia' nel repository `.vscode/launch.json` (un profilo di
debug per servizio, piu' il compound *Stack completo* che li avvia tutti in
ordine), `.vscode/tasks.json` (i comandi `task` dalla palette),
`settings.json` ed `extensions.json`. L'unica estensione indispensabile e'
**Extension Pack for Java**: senza, il tasto Debug non esiste. `F5` ->
*Stack completo* e hai tutti i servizi con i breakpoint attivi.

**Zed** ha `.zed/debug.json` (`F4` -> un servizio in debug, con i breakpoint),
`.zed/tasks.json` (palette -> *task: Spawn*) e `.zed/settings.json`. Serve
l'estensione *Java*: al primo file `.java` scarica jdtls, Lombok e il debugger,
quindi aprilo una volta con la rete (`task offline` controlla che ci siano).

**IntelliJ IDEA** non ha bisogno di niente: *File -> Open* sulla cartella del
repository.

`launch.json`, `debug.json` e i due `tasks.json` sono **generati**: li riscrivono
`new-service`, `remove-service` e `set-port`. Se li hai scavalcati modificando
i moduli a mano:

```bash
task ide-sync
```

Se restano indietro lo segnala `task check`, alla voce *editor (launch.json)*.

---

## Prima e dopo: la rete dell'esame e la consegna

All'esame la rete passa da una whitelist di domini: Maven Central sì, il resto
non si sa. `task rete` dice, dominio per dominio, che cosa passa e che cosa
fare se no. La sera prima, con la connessione di casa:

```bash
task offline-prep
```

Scarica le dipendenze Maven in `~/.m2`, anche quelle dei moduli che creerai,
le immagini Docker di base e fa una prima build dei container. `task offline`
verifica lo stato e prova davvero una compilazione offline (`mvnw -o`).
Portati la cartella del progetto **e** la cartella `~/.m2` su una chiavetta: il
template è la cartella, non serve altro.

Se Docker Hub non passa, presenta con `task dev` più `task run-db` (il solo
PostgreSQL in container): non ricompila niente dentro Docker, quindi è il modo
che regge meglio.

A fine giornata:

```bash
task consegna NOME=COGNOME_NOME
```

Prepara `consegna/` con il progetto pronto da eseguire (i moduli senza
`target/`, accanto a pom e compose), l'allegato tecnico già compilato (moduli,
porte, endpoint, schema del database), le istruzioni di esecuzione, e un
archivio unico da consegnare: scompattato, parte con `docker compose up --build`.
Le parti dell'allegato da scrivere a mano (analisi, algoritmo, che cosa fa ogni
modulo) stanno in `allegato.md`: la consegna le mette al loro posto prima di
fare l'archivio, quindi si può rilanciare quante volte si vuole.
