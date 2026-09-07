# Spring Boot Dockerized - Esempio Eventi/Turismo

Questo branch contiene un **esempio d'esame svolto** sulla traccia **Eventi/Turismo (OpenDataHub)**, costruito sul template multi-modulo Maven del branch [`main`](https://github.com/daubog44/spring-boot-dockerized/tree/main) con **Spring Boot**, **Spring Cloud Eureka**, **OpenFeign**, **OpenAPI/Swagger UI**, **PostgreSQL** e **Docker Compose**.

Flusso applicativo: la UI riceve coordinate, raggio e numero di alternative, interroga `TOURIST-SERVICE` (wrapper Feign di OpenDataHub), estrae un indice tramite `RANDOM-SERVICE` e salva il suggerimento scelto su `STORE-SERVICE`, che lo persiste su PostgreSQL.

---

## 📚 Documentazione & Guide per l'Esame

- [📖 Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [📘 Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md)
- [🛠️ Guida 3: Multi-Modulo Maven e Funzionamento](./guida_multi_modulo_maven.md)
- [📝 Documentazione Specifica Esame (README-ESAME-TTFCLOUD.md)](./README-ESAME-TTFCLOUD.md)

---

## 🌿 Branch del Repository

- **[`main`](https://github.com/daubog44/spring-boot-dockerized/tree/main)**: Template d'Esame pulito e neutro, adattabile a qualsiasi traccia.
- **[`solution/wms`](https://github.com/daubog44/spring-boot-dockerized/tree/solution/wms)**: Soluzione completa della traccia WMS Magazzino "Spostati S.r.l." con script di collaudo automatizzato.
- **`example/tourist-events`** (questo branch): Esempio svolto della traccia Eventi/Turismo.

---

## 🏗️ Architettura dei Servizi

Il progetto è un aggregatore Multi-Module Maven dentro la cartella `demo`:

1. **`naming-server`**: Eureka Naming Server (Porta `8761`).
2. **`common-dto`**: Modulo libreria con i DTO condivisi tra i microservizi.
3. **`tourist-service`** (Porta `8081`): Wrapper REST dell'endpoint OpenDataHub `/v1/Event` (`TouristController`, `OpenDataHubEventClient` via OpenFeign). Base URL configurabile con `TOURIST_API_BASE_URL`.
4. **`random-service`** (Porta `8082`): Generatore di indici casuali (`RandomController`).
5. **`store-service`** (Porta `8083`): Storico dei suggerimenti (`SuggestionController`), persistenza JPA/Hibernate su PostgreSQL.
6. **`event-ui`** (Porta `8080`): Web UI Thymeleaf (`UiController`), consuma gli altri tre servizi via OpenFeign (`TouristServiceClient`, `RandomServiceClient`, `StoreServiceClient`) risolti tramite Eureka.

> ⚠️ Il container Docker della UI si chiama `ui-service` nel `docker-compose.yml`, mentre il modulo Maven è `event-ui`.

Nomi con cui i servizi si registrano su Eureka: `TOURIST-SERVICE`, `RANDOM-SERVICE`, `STORE-SERVICE`, `EVENT-UI`.

### 🗄️ Database

`store-service` è collegato a PostgreSQL tramite le variabili d'ambiente già impostate nel `docker-compose.yml` (`STORE_DB_URL`, `STORE_DB_USERNAME`, `STORE_DB_PASSWORD`). Gli altri servizi non hanno persistenza.

---

## ⚡ Come lavorare

**Per sviluppare, un comando solo:**

```bash
task dev
```

Prima ferma quello che fosse rimasto acceso da un avvio precedente e libera le porte, poi avvia PostgreSQL su Docker, compila tutti i moduli una volta sola, lancia Eureka, ne attende la porta e infine avvia gli altri quattro servizi.

**Un terminale solo, nessuna finestra sparsa**: i servizi girano in background e scrivono in `.dev-logs/`. Per vedere cosa fanno:

```bash
task logs
```

Mostra l'output di tutti i servizi insieme, ogni riga prefissata dal nome (`store | ...`) e di un colore diverso. `Ctrl+C` chiude solo la vista, i servizi restano su. Per seguirne uno solo: `task logs -- store`.

**Hot reload**: ogni servizio gira con `spring-boot-devtools`. Dopo aver modificato del codice, `task compile` ricompila e il servizio interessato si riavvia da solo.

**Per fermare tutto**: `task dev-down`, che ferma anche il container PostgreSQL avviato da `task dev` (il volume resta, i dati non si perdono).

**Quando qualcosa non risponde**: `task status` dice chi occupa ognuna delle porte (un tuo servizio, i container, o un'applicazione estranea), quali container girano e cosa si è registrato su Eureka.

> 💡 Se una porta è occupata da un'applicazione estranea, `task dev` si ferma e ti dice quale processo la tiene. Per spostare la sola UI: `task dev -- -UiPort 9080`.

**Per la demo**, usa lo stack containerizzato:

```bash
task docker-up
```

Locale e Docker usano le stesse porte, ma non devi ricordartene: `task docker-up` ferma da solo lo stack locale prima di partire, e `task dev` si rifiuta di partire se i container sono accesi.

### Elenco completo dei task

Il comando `task` da solo stampa questo elenco.

Sviluppo:

- `task dev`: Pulisce, compila e avvia l'intero stack in locale con hot reload.
- `task dev-down`: Ferma i servizi locali e libera le porte.
- `task logs`: Segue i log di tutti i servizi in un terminale solo (`task logs -- store` per uno).
- `task status`: Chi occupa le porte, quali container girano, cosa è registrato su Eureka.
- `task compile`: Ricompila e fa ripartire i servizi già avviati.
- `task build`: Compila e impacchetta tutti i moduli Maven tramite wrapper (`mvnw`).

Container:

- `task docker-up`: Avvia l'intero cluster di microservizi su Docker Compose con healthcheck.
- `task docker-down`: Ferma i container. **I dati del database restano.**
- `task docker-reset`: Ferma i container **ed elimina i volumi**: database ricreato da zero.
- `task docker-logs`: Monitora i log di tutti i microservizi.

Pulizia:

- `task clean-ports`: Come `dev-down`, libera le porte dello stack.
- `task kill-java`: Ultima spiaggia, termina **tutti** i processi Java della macchina, anche quelli estranei al progetto.

Avvio manuale dei singoli moduli: `task run-eureka`, `task run-tourist`, `task run-random`, `task run-store`, `task run-ui`, `task run-db`.

---

## 🌐 Mappa delle Porte ed Interfacce OpenAPI / Swagger UI

- **UI Applicativa**: `http://localhost:8080`
- **Dashboard Eureka**: `http://localhost:8761`
- **PostgreSQL**: `localhost:5432` (db `event_suggestions`, utente `exam`, password `exam`)
- **Swagger UI Tourist Service**: `http://localhost:8081/swagger-ui.html`
- **Swagger UI Random Service**: `http://localhost:8082/swagger-ui.html`
- **Swagger UI Store Service**: `http://localhost:8083/swagger-ui.html`
- **Swagger UI Event UI**: `http://localhost:8080/swagger-ui.html`

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

Elenca ogni processo in ascolto sulle porte dello stack e segnala esplicitamente questo caso. Chiudi il processo indicato, oppure sposta la UI: `task dev -- -UiPort 9080`.

### Altri controlli utili

```bash
docker compose ps
```

```bash
docker logs exam-store-service --tail 50
```

Per verificare quali servizi si sono effettivamente registrati su Eureka, apri `http://localhost:8761` nel browser oppure, dall'host:

```bash
curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps
```
