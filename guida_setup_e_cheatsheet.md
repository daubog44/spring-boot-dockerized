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

### A. Sviluppo Locale con Hot Reload (CONSIGLIATO MENTRE SVILUPPI)

Un solo comando compila tutto e avvia Eureka, `product-service`, `crm-service`, `wms-service` e `wms-ui`, ognuno nella propria finestra:

```bash
task dev
```

Dopo una modifica al codice, ricompila e i servizi interessati si riavviano da soli grazie a `spring-boot-devtools`:

```bash
task compile
```

Per fermare lo stack locale:

```bash
task dev-down
```

I log dei servizi restano consultabili in `.dev-logs/`.

**Perché non usare `task docker-up` mentre sviluppi**: `docker compose build` ricostruisce tutte e cinque le immagini, e poiché il `Dockerfile` copia i sorgenti prima di compilare, ogni singola modifica invalida la cache e fa ricompilare tutto in ogni immagine. Un ciclo costa minuti contro i ~20 secondi del build locale.

---

### B. Avvio Stack Completo Containerizzato (CONSIGLIATO PER LA DEMO)

È lo stack che presenterai alla commissione. Esegue i 5 microservizi Spring Boot e PostgreSQL in container isolati:

```bash
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

> ⚠️ Locale e Docker usano le stesse porte: non tenerli attivi insieme. `task dev-down` prima di `task docker-up`, e viceversa.

---

### C. Avvio Manuale dei Singoli Moduli

Se ti serve isolare un servizio, in terminali distinti:

```bash
task run-eureka
task run-product
task run-crm
task run-wms
task run-wms-ui
```

`task run-db` avvia solo PostgreSQL su Docker. Su questo branch **non serve**: i servizi usano H2 in memoria (vedi il README).

---

## 3. Mappa delle Porte ed Endpoint OpenAPI / Swagger UI

| Servizio | Porta Host | Endpoint Principale / Dashboard | Swagger UI (Contratti OpenAPI) |
| :--- | :---: | :--- | :--- |
| **WMS UI** | `8080` | `http://localhost:8080` | `http://localhost:8080/swagger-ui.html` |
| **Eureka Naming Server** | `8761` | `http://localhost:8761` | N/A (Dashboard Eureka) |
| **Product Service** | `8081` | `http://localhost:8081` | `http://localhost:8081/swagger-ui.html` |
| **CRM Service** | `8082` | `http://localhost:8082` | `http://localhost:8082/swagger-ui.html` |
| **WMS Service** | `8083` | `http://localhost:8083` | `http://localhost:8083/swagger-ui.html` |
| **PostgreSQL DB** | `5432` | `jdbc:postgresql://localhost:5432/event_suggestions` | Avviato dal compose ma non collegato ai servizi |

---

## 4. Collaudo Rapido

### Collaudo automatizzato (il modo più veloce)

```bash
task test-e2e
```

Esegue [`test_e2e_wms.ps1`](./test_e2e_wms.ps1), che percorre l'intero flusso sui servizi avviati.

### Test manuale via `curl` (API Direct Check)

```bash
# 1. Catalogo prodotti
curl "http://localhost:8081/api/products"
```

```bash
# 2. Anagrafica clienti
curl "http://localhost:8082/api/customers"
```

```bash
# 3. Scaffali e ubicazioni di magazzino
curl "http://localhost:8083/api/wms/cabinets"
```

```bash
# 4. Ubicazioni (wms-service interroga product-service e crm-service via Feign)
curl "http://localhost:8083/api/wms/locations"
```

Gli endpoint `POST /api/wms/movements` e `POST /api/wms/nearest-location` accettano un corpo JSON: il modo più comodo per provarli è Swagger UI su `http://localhost:8083/swagger-ui.html`, che mostra lo schema esatto della richiesta.

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
