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
- **Java 25**: Utilizzata dal progetto (`JAVA_HOME` impostato o gestito automaticamente).
- **Task (`go-task`)**: Strumento per l'automazione dei comandi d'esame.

---

## 2. Modalità d'Avvio Principali

### A. Avvio Stack Completo Containerizzato (CONSIGLIATO PER LA DEMO)

Esegue in container Docker isolati tutti i moduli del progetto — Eureka, i tuoi servizi — e il database PostgreSQL:

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

Un solo comando libera le porte (chiudendo chi le tiene occupate), compila tutto e lancia Eureka e i tuoi servizi, nell'ordine giusto (Eureka per primo, e ne aspetta la porta prima degli altri). Se un tuo servizio usa PostgreSQL, avvia anche quello: basta mettere `$usesPostgres = $true` in `scripts/dev.ps1` (`USES_POSTGRES=1` in `dev.sh`).

```bash
task dev
```

I servizi girano in background: niente finestre sparse, un terminale solo. Per vedere l'output di tutti insieme, ogni riga prefissata dal nome del servizio:

```bash
task logs
```

`Ctrl+C` chiude solo la vista, i servizi restano su. Per uno solo: `task logs SERVICE=<nome>`, col nome breve che vedi in `task status`. I log restano comunque su file in `.dev-logs/`.

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

**Perché non usare `task docker-up` mentre sviluppi**: `docker compose build` ricostruisce un'immagine per servizio, e poiché il `Dockerfile` copia i sorgenti prima di compilare, ogni singola modifica invalida la cache e fa ricompilare tutto in ogni immagine. Un ciclo costa minuti contro i ~20 secondi del build locale.

---

### C. Avvio Manuale dei Singoli Moduli

Se ti serve isolare un servizio e vederne l'output nel terminale:

```bash
task run SERVICE=<modulo>
```

Due scorciatoie per quello che c'è sempre:

```bash
task run-eureka
```

```bash
task run-db
```

`Ctrl+C` ferma il modulo. Per lo stack intero, in background, resta `task dev`.

---

## 3. Mappa delle Porte ed Endpoint OpenAPI / Swagger UI

Questo branch è il **template vuoto**: le uniche porte fisse sono quelle
dell'infrastruttura. Le altre le assegna `task new-service` (la prima libera
dopo l'ultima usata) e te le stampa `task dev` alla fine dell'avvio.

| Servizio | Porta Host | Endpoint / Dashboard | Swagger UI |
| :--- | :---: | :--- | :--- |
| **Eureka Naming Server** | `8761` | `http://localhost:8761` | N/A (dashboard Eureka) |
| **PostgreSQL** | `5432` | `jdbc:postgresql://localhost:5432/esame` (utente e password `exam`) | N/A |
| **I tuoi servizi REST** | `8081`, `8082`, ... | `http://localhost:<porta>/api/...` | `http://localhost:<porta>/swagger-ui.html` |
| **La tua UI** | la prima libera | `http://localhost:<porta>` | idem |

Per sapere in ogni momento chi sta su quale porta, e chi è registrato su Eureka:

```bash
task status
```

Per spostare una porta ovunque sia scritta (`application.yml`, compose, liste
di avvio):

```bash
task set-port SERVICE=<modulo> PORT=<porta>
```

---

## 4. Collaudo Rapido

### Prima: il progetto è coerente?

```bash
task check
```

Non avvia niente: verifica che moduli, porte, `Dockerfile`, `docker-compose.yml`
e liste di avvio dicano la stessa cosa, e che le porte siano davvero usabili su
questa macchina. Se qualcosa non torna te lo dice qui, non a demo iniziata.

### Poi: i servizi si vedono fra loro?

```bash
task status
```

Nella sezione **REGISTRO EUREKA** devono comparire tutti i tuoi servizi. Se uno
manca, o è partito da meno di 15 secondi, o non parte affatto: `task logs
SERVICE=<nome>`.

### Infine: gli endpoint rispondono?

Ogni servizio creato con `task new-service` nasce con un endpoint di prova e
con Swagger già collegato:

```bash
curl http://localhost:<porta>/api/ping
```

Swagger UI (`http://localhost:<porta>/swagger-ui.html`) è il modo più comodo
per provare gli endpoint veri: mostra lo schema esatto delle richieste e le
esegue dal browser, senza scrivere `curl` a mano.

L'ultimo collaudo, quello che conta, è percorrere il flusso completo dalla UI
come lo mostrerai alla commissione.

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

### 🚨 Emergenza 1-bis: "container exam-eureka is unhealthy"
`task docker-up` si interrompe con `dependency failed to start: container exam-eureka is unhealthy`, ma nei log Eureka scrive `Started Eureka Server`. L'healthcheck usa `curl`, che l'immagine `eclipse-temurin:25-jre` non contiene. Il `demo/Dockerfile` di questo repo lo installa già; se aggiungi un healthcheck HTTP a un altro servizio vale la stessa regola. Per leggere l'esito delle probe:
```bash
docker inspect exam-eureka --format "{{json .State.Health}}"
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
I client Eureka richiedono qualche secondo per aggiornare il registro locale delle istanze (cache heartbeat). Attendi 10-15 secondi dall'avvio completo del cluster prima di effettuare la prima richiesta HTTP.
