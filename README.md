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

Avvia PostgreSQL su Docker, compila tutti i moduli una volta sola, lancia Eureka, ne attende la porta e poi avvia i quattro servizi, ognuno nella propria finestra. I log finiscono anche in `.dev-logs/`.

**Hot reload**: ogni servizio gira con `spring-boot-devtools`. Dopo aver modificato del codice, `task compile` ricompila e il servizio interessato si riavvia da solo.

**Per fermare tutto**: `task dev-down` (PostgreSQL resta attivo, fermalo con `task docker-down`).

> 💡 Se una porta è occupata da un'applicazione estranea, `task dev` si ferma e ti dice quale processo la tiene. Per spostare la sola UI: `task dev -- -UiPort 9080`.

**Per la demo**, usa lo stack containerizzato:

```bash
task docker-up
```

> ⚠️ Non tenere attivi contemporaneamente `task dev` e `task docker-up`: usano le stesse porte.

### Elenco completo dei task

- `task dev`: Compila e avvia l'intero stack in locale con hot reload.
- `task dev-down`: Ferma lo stack locale.
- `task compile`: Ricompila e fa ripartire i servizi già avviati.
- `task build`: Compila tutti i moduli Maven tramite wrapper (`mvnw`).
- `task docker-up`: Avvia l'intero cluster di microservizi su Docker Compose con healthcheck.
- `task docker-down`: Arresta tutti i container e pulisce le risorse.
- `task docker-logs`: Monitora i log di tutti i microservizi.
- `task clean-ports`: Termina **tutti** i processi Java della macchina (più drastico di `dev-down`).

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
