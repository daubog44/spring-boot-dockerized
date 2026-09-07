# Spring Boot Dockerized - Soluzione d'Esame WMS

Questo branch contiene la **soluzione d'esame completa e collaudata** per la traccia **WMS Magazzino "Spostati S.r.l."**, costruita sul template multi-modulo Maven del branch [`main`](https://github.com/daubog44/spring-boot-dockerized/tree/main) con **Spring Boot**, **Spring Cloud Eureka**, **OpenFeign**, **OpenAPI/Swagger UI**, **PostgreSQL** e **Docker Compose**.

---

## 📚 Documentazione & Guide per l'Esame

- **[🚨 Il giorno dell'esame: procedura operativa](./GIORNO-ESAME.md)** — le quattro fasi, dal clone alla demo. Parti da qui.
- [📖 Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [📘 Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md)
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

> 💡 Se su una delle porte gira un'applicazione che ti serve viva, dillo: `task dev KEEPFOREIGN=1 UI_PORT=9080`. Senza `-KeepForeign` viene chiusa.

**Per la demo finale**, usa lo stack containerizzato, che è quello che presenterai:

```bash
task docker-up
```

Locale e Docker usano le stesse porte, ma non devi ricordartene: `task docker-up` ferma da solo lo stack locale prima di partire, e `task dev` spegne da solo i container (con `docker compose down`, i dati del database restano).

### Elenco completo dei task

Il comando `task` da solo stampa questo elenco.

Sviluppo:

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

### `dependency failed to start: container exam-eureka is unhealthy`

Sintomo: `task docker-up` fallisce, `exam-eureka` risulta `unhealthy` e nessun microservizio parte, anche se nei log Eureka scrive regolarmente `Started Eureka Server`.

Causa: l'healthcheck di `eureka-server` invoca `curl` su `/actuator/health`, ma l'immagine runtime `eclipse-temurin:25-jre` **non include `curl`**. Ogni probe fallisce con `curl: not found`, il container resta `unhealthy` e tutti i servizi con `depends_on: condition: service_healthy` non vengono mai avviati.

Il `demo/Dockerfile` di questo repo installa già `curl` nello stage runtime, quindi il problema non si presenta. Se aggiungi un healthcheck HTTP a un altro servizio, ricordati che vale la stessa regola.

Per capire *perché* un healthcheck non passa, leggi l'output delle probe:

```bash
docker inspect exam-eureka --format "{{json .State.Health}}"
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
docker logs exam-wms-service --tail 50
```

Per verificare quali servizi si sono effettivamente registrati su Eureka:

```bash
docker exec exam-eureka curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps
```
