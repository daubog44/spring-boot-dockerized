# Documentazione Esame Spring Cloud

## Obiettivo

Questa soluzione realizza una UI che suggerisce un evento locale vicino alla posizione inserita dall'utente.

Flusso richiesto dalla traccia:

1. la UI riceve coordinate geografiche, raggio e numero di alternative
2. la UI interroga `TOURIST-SERVICE` tramite Eureka
3. `TOURIST-SERVICE` usa OpenFeign come wrapper dell'endpoint OpenDataHub `/v1/Event`
4. la UI interroga `RANDOM-SERVICE` per ottenere un indice casuale
5. la UI salva il suggerimento scelto su `STORE-SERVICE`
6. `STORE-SERVICE` persiste lo storico su PostgreSQL tramite Hibernate/JPA
7. la UI mostra evento estratto e storico suggerimenti

## Architettura

Applicazioni Spring Boot presenti:

- `eureka-server`
- `tourist-service`
- `random-service`
- `store-service`
- `event-ui`

Package principali:

- `com.example.ttfcloud_esame.namingserver`
- `com.example.ttfcloud_esame.touristservice`
- `com.example.ttfcloud_esame.randomservice`
- `com.example.ttfcloud_esame.storeservice`
- `com.example.ttfcloud_esame.ui`
- `com.example.ttfcloud_esame.common.dto`

## Multi-Module Maven

Il progetto ora usa un parent Maven aggregatore in [demo/pom.xml](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/pom.xml) e sei moduli separati:

- [common-dto](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/common-dto)
- [naming-server](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/naming-server)
- [tourist-service](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/tourist-service)
- [random-service](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/random-service)
- [store-service](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/store-service)
- [event-ui](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/event-ui)

Cosa cambia davvero:

- le dipendenze non sono piu` condivise da tutto il progetto
- ogni servizio compila solo con gli starter che gli servono
- i DTO comuni stanno in un jar separato
- Docker e `spring-boot:run` lavorano sul singolo modulo, non su un monolite con piu` main class

Funziona bene?

- si`, per questo caso e` piu` pulito del single-module
- il comportamento applicativo non cambia
- migliora isolamento e leggibilita`
- l'unico costo e` avere piu` `pom.xml` e una struttura leggermente piu` articolata

## Tecnologie

- Spring Boot 4.0.5
- Spring Cloud Netflix Eureka
- Spring Cloud 2025.1.1
- Spring Cloud OpenFeign
- Spring Data JPA / Hibernate
- PostgreSQL 18.3
- Lombok 1.18.44
- Apache Maven Wrapper 3.9.14
- Thymeleaf
- Tailwind CSS compilato localmente
- Docker / Docker Compose
- Taskfile

Versioni GA verificate al 10/04/2026.
Nota: esiste anche Spring Boot `4.1.0-M4`, ma e` una milestone e non una release GA; per l'esame e` piu` sensato restare sulla latest stabile `4.0.5`.

## Installazioni necessarie

Per eseguire il progetto servono questi strumenti sull'host:

- Git
- Docker Desktop oppure Docker Engine + Docker Compose
- Task (`go-task`)

Per i task locali `run-*` servono anche:

- Java 25
- una shell con `mvnw` eseguibile

Installazioni minime consigliate:

- Docker: deve supportare `docker compose`
- Task: [https://taskfile.dev/installation/](https://taskfile.dev/installation/)
- Java: JDK 25 se vuoi usare esattamente lo stesso setup del progetto

Verifica rapida ambiente:

```bash
git --version
docker --version
docker compose version
task --version
java --version
```

Se vuoi usare solo Docker con `task docker-up`, Java non e` strettamente necessaria sull'host per l'esecuzione finale dell'app, ma resta utile per `task build` e per i `run-*`.

## Setup host

### Setup minimo per la demo

1. clona il repository
2. entra nella root del progetto
3. verifica che Docker sia avviato
4. esegui `task docker-up`
5. apri UI ed Eureka nel browser

Comandi:

```bash
git clone <url-repository>
cd spring-boot-dockerized
task docker-up
```

URL da aprire:

- `http://localhost:8080`
- `http://localhost:8761`

### Setup per usare tutti i task

Se vuoi usare anche i task locali oltre a Docker:

1. installa Java 25
2. installa Task
3. verifica che il percorso configurato in [Taskfile.yml](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/Taskfile.yml) per `JAVA_HOME_PATH` sia valido sul tuo host

Sul mio setup il Taskfile usa:

```text
C:/Program Files/Microsoft/jdk-25.0.2.10-hotspot
```

Se sul tuo PC Java e` installato altrove, aggiorna `JAVA_HOME_PATH` nel Taskfile.

## Porte e URL

Con stack Docker avviato:

- UI applicativa: `http://localhost:8080`
- Eureka dashboard: `http://localhost:8761`
- PostgreSQL: `localhost:5432`

Porte interne servizi:

- `tourist-service`: `8081`
- `random-service`: `8082`
- `store-service`: `8083`

## Persistenza

Database PostgreSQL:

- DB: `event_suggestions`
- user: `exam`
- password: `exam`

Tabella usata:

- `event_suggestions`

## Wrapper OpenDataHub

Il wrapper usa:

- base URL: `https://tourism.opendatahub.com`
- endpoint: `/v1/Event`

Filtri principali usati:

- `latitude`
- `longitude`
- `radius`
- `pagesize = limit`
- `begindate = oggi`
- `active = true`
- `odhactive = true`
- `sort = upcoming`
- `language`

## Eureka

Per chiarezza d'esame i servizi client dichiarano `@EnableDiscoveryClient`.

Servizi registrati:

- `TOURIST-SERVICE`
- `RANDOM-SERVICE`
- `STORE-SERVICE`
- `EVENT-UI`

## Task disponibili

Task verificati:

- `task build`
- `task docker-up`

Task utili:

- `task docker-down`
- `task docker-logs`
- `task run-db`
- `task clean-ports`

Task per singolo servizio:

- `task run-eureka`
- `task run-tourist`
- `task run-random`
- `task run-store`
- `task run-ui`

Nota:
I task `run-*` avviano processi foreground con `spring-boot:run` sul singolo modulo, quindi vanno lanciati in terminali separati.

## Avvio rapido

### Stack completo Docker

```bash
task docker-up
```

Apri poi:

- `http://localhost:8080`
- `http://localhost:8761`

Per spegnere tutto:

```bash
task docker-down
```

### Build

```bash
task build
```

### Coordinate demo consigliate

Per una demo veloce a Bolzano puoi usare questi esempi:

- Bolzano centro: `latitude=46.4983`, `longitude=11.3548`, `radius=10000`, `limit=5`, `language=it`
- Piazza Walther / centro storico: `latitude=46.4981`, `longitude=11.3540`, `radius=5000`, `limit=5`, `language=it`

Sono coordinate pratiche per ottenere eventi nell'area urbana di Bolzano senza dover cambiare altro nella UI.

### Tutorial rapido multi-module

1. entra nel parent Maven:

```bash
cd demo
```

2. build di tutti i moduli:

```bash
./mvnw clean package -Dmaven.test.skip=true
```

3. avvio di un solo modulo:

```bash
./mvnw -pl event-ui -am spring-boot:run
```

4. esempio per il tourist wrapper:

```bash
./mvnw -pl tourist-service -am spring-boot:run
```

5. build Docker di un solo servizio tramite argomento di build:

```bash
docker build --build-arg MODULE=event-ui -t exam-ui .
```

6. stack completo:

```bash
task docker-up
```

### Avvio locale senza stack completo Docker

Prima il DB:

```bash
task run-db
```

Poi in terminali separati:

```bash
task run-eureka
task run-tourist
task run-random
task run-store
task run-ui
```

## Verifiche eseguite

Verifiche completate nel workspace:

1. `task build` eseguito con successo
2. `task docker-up` eseguito con successo
3. Eureka raggiungibile su `http://localhost:8761`
4. UI raggiungibile su `http://localhost:8080`
5. submit della form riuscita con evento reale da OpenDataHub
6. persistenza verificata su PostgreSQL con incremento dei record
7. console browser pulita senza errori o warning

Nota tecnica:
Con Java 25 e Lombok 1.18.44 la build mostra ancora un warning interno su `sun.misc.Unsafe` proveniente da Lombok. La compilazione e l'esecuzione restano corrette; per eliminarlo del tutto servirebbe rinunciare a Lombok oppure scendere a una LTS piu` conservativa come Java 21.

## UI senza reload

La UI non ricarica piu` la pagina quando premi il bottone:

- il submit viene intercettato da `fetch`
- il server restituisce solo i frammenti HTML aggiornati
- vengono sostituiti solo feedback, evento estratto e storico

In piu` il fallback server-side usa `Post/Redirect/Get`, quindi il refresh del browser non ripete il `POST` e non salva suggerimenti duplicati.

File coinvolti:

- [UiController.java](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/event-ui/src/main/java/com/example/ttfcloud_esame/ui/UiController.java)
- [event-suggestion.html](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/event-ui/src/main/resources/templates/event-suggestion.html)
- [event-roulette.js](C:/Users/Utente/OneDrive%20-%20ITS%20Tech%20Talent%20Factory/Desktop/dev/spring-boot-dockerized/demo/event-ui/src/main/resources/static/js/event-roulette.js)

## Note da dire all'esame

- Maven non isola le dipendenze per package, ma per modulo.
- Per questo motivo il refactoring a multi-module e` il modo corretto per dare a ogni servizio solo le dipendenze che usa davvero.
- Il parent centralizza versioni e plugin, mentre ogni modulo dichiara solo i propri starter.
