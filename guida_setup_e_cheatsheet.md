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

Per arrestare lo stack e pulire le risorse:
```bash
task docker-down
```

---

### B. Sviluppo Locale con Hot Reload (CONSIGLIATO MENTRE SVILUPPI)

Un solo comando avvia PostgreSQL, compila tutto e lancia Eureka e i quattro servizi, ognuno nella propria finestra:

```bash
task dev
```

Dopo una modifica al codice, ricompila e i servizi interessati si riavviano da soli grazie a `spring-boot-devtools`:

```bash
task compile
```

Per fermare lo stack locale (PostgreSQL resta attivo):

```bash
task dev-down
```

I log dei servizi restano consultabili in `.dev-logs/`.

**Perché non usare `task docker-up` mentre sviluppi**: `docker compose build` ricostruisce tutte e cinque le immagini, e poiché il `Dockerfile` copia i sorgenti prima di compilare, ogni singola modifica invalida la cache e fa ricompilare tutto in ogni immagine. Un ciclo costa minuti contro i ~20 secondi del build locale.

---

### C. Avvio Manuale dei Singoli Moduli

Se ti serve isolare un servizio, in terminali distinti:

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
Se sono rimasti appesi i servizi dello stack locale:
```bash
task dev-down
```
Se hai lo stack Docker attivo:
```bash
task docker-down
```
Come ultima risorsa, termina tutti i processi Java della macchina:
```bash
task clean-ports
```

Se invece la porta è tenuta da un'applicazione **estranea** al progetto, `task dev` si ferma e ti dice quale processo la occupa. Tomcat non riesce a fare il bind nemmeno quando l'altro processo ascolta solo su `127.0.0.1`: il servizio muore con `Web server failed to start. Port N was already in use`. Chiudi quel processo, oppure sposta la UI:
```bash
task dev -- -UiPort 9080
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
task docker-down
```
```bash
docker volume rm demo_postgres-data
```
```bash
task docker-up
```

> ℹ️ Il volume è montato su `/var/lib/postgresql`, non sul percorso legacy `/var/lib/postgresql/data`: dalla versione 18 l'immagine tiene i dati in `/var/lib/postgresql/<versione>/docker`, e col mount vecchio il volume restava vuoto e il container non partiva.

### 🚨 Emergenza 4: "Eureka registra i servizi ma i Feign Client danno 500"
I client Eureka richiedono qualche secondo per aggiornare il registro locale delle istanze (cache heartbeat). Attendi 10-15 secondi dall'avvio completo del cluster prima di effettuare la prima richiesta HTTP.
