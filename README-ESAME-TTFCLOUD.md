# Documentazione Esame Spring Cloud — WMS Magazzino "Spostati S.r.l."

## Obiettivo

Questa soluzione realizza un sistema di gestione magazzino (WMS) distribuito su microservizi, con una UI che permette di consultare le giacenze, spostare merce fra ubicazioni e calcolare l'ubicazione compatibile più vicina.

Flusso richiesto dalla traccia:

1. il magazzino è una griglia di **armadi**, ognuno identificato da fila e colonna
2. ogni armadio contiene **ubicazioni**, ciascuna con una capienza massima (`maxIngombro`)
3. ogni ubicazione può contenere pezzi di **un solo prodotto** appartenente a **un solo cliente**
4. la UI mostra armadi e ubicazioni interrogando `WMS-SERVICE` tramite Eureka
5. `WMS-SERVICE` arricchisce i dati chiedendo nome prodotto a `PRODUCT-SERVICE` e ragione sociale a `CRM-SERVICE`, entrambi via OpenFeign
6. la UI permette di **spostare Q pezzi** da un'ubicazione a un'altra, con validazione delle regole di magazzino
7. la UI permette di calcolare l'**ubicazione idonea più vicina** usando la distanza di Manhattan sulla griglia degli armadi

## Architettura

Applicazioni Spring Boot presenti nello stack:

- `eureka-server` (modulo `naming-server`)
- `product-service`
- `crm-service`
- `wms-service`
- `wms-ui`

Package principali:

- `com.example.ttfcloud_esame.namingserver`
- `com.example.ttfcloud_esame.productservice`
- `com.example.ttfcloud_esame.crmservice`
- `com.example.ttfcloud_esame.wmsservice`
- `com.example.ttfcloud_esame.wmsui`

Catena delle chiamate:

```
wms-ui  --Feign-->  WMS-SERVICE  --Feign-->  PRODUCT-SERVICE
                         |
                         +------Feign------>  CRM-SERVICE
```

Nessun client conosce host o porta degli altri: i `@FeignClient` usano il **nome logico** registrato su Eureka (`WMS-SERVICE`, `PRODUCT-SERVICE`, `CRM-SERVICE`) e il load balancer risolve l'istanza.

### Resilienza delle chiamate Feign

`WmsService` non lascia propagare gli errori dei servizi remoti: se `PRODUCT-SERVICE` o `CRM-SERVICE` non rispondono, i metodi `fetchProduct` / `fetchCustomer` intercettano l'eccezione, scrivono un warning e restituiscono un oggetto segnaposto (`Prodotto #101`, `Cliente #201`, ingombro di default 10). La dashboard resta quindi consultabile anche con un servizio a valle spento — è un punto interessante da mostrare all'esame staccando un container.

## Modello dati

`CabinetEntity` — armadio nella griglia:

| Campo | Significato |
| :--- | :--- |
| `id` | identificativo armadio |
| `row` | indice di fila nella griglia |
| `col` | indice di colonna nella griglia |
| `name` | etichetta descrittiva |

`LocationEntity` — ubicazione dentro un armadio:

| Campo | Significato |
| :--- | :--- |
| `id` | identificativo ubicazione |
| `cabinetId` | armadio di appartenenza |
| `maxIngombro` | capienza massima |
| `currentIngombro` | ingombro attualmente occupato |
| `productId` | prodotto contenuto (`null` se vuota) |
| `customerId` | cliente proprietario (`null` se vuota) |
| `quantity` | numero di pezzi presenti |

L'ingombro non è un conteggio di pezzi: ogni prodotto ha un **ingombro unitario** (`ProductDTO.ingombro`) e l'occupazione di uno spostamento vale `quantità × ingombro unitario`.

### Dati di prova caricati all'avvio

Ogni servizio popola i propri dati con un `CommandLineRunner` (o `@PostConstruct` nel CRM) solo se il repository è vuoto.

**Prodotti** (`product-service`):

| ID | Nome | Prezzo | Ingombro unitario |
| :--- | :--- | :--- | :--- |
| 101 | Scatola cartone standard | 15.00 | 10 |
| 102 | Pallet legno pesante | 85.00 | 50 |
| 103 | Contenitore plastico isolato | 45.00 | 25 |

**Clienti** (`crm-service`):

| ID | Referente | Azienda |
| :--- | :--- | :--- |
| 201 | Mario Rossi | Logistica Express Srl |
| 202 | Giuseppe Verdi | Trasporti Nazionali Spa |
| 203 | Elena Bianchi | Tech Distribution SpA |

**Armadi e ubicazioni** (`wms-service`):

| Armadio | Fila | Colonna | Ubicazioni |
| :--- | :---: | :---: | :--- |
| 1 | 1 | 1 | `1` (4 pz prod. 101, cliente 201, 40/100) · `2` (vuota, 0/120) |
| 2 | 1 | 3 | `3` (2 pz prod. 102, cliente 202, 100/150) · `4` (vuota, 0/200) |
| 3 | 4 | 2 | `5` (1 pz prod. 103, cliente 201, 25/80) · `6` (vuota, 0/100) |

## Regole di movimentazione

`POST /api/wms/movements` applica quattro controlli in ordine. Se uno fallisce, la risposta ha `success: false` e un messaggio esplicativo — **non** viene sollevata un'eccezione, così la UI può mostrare l'errore all'utente.

1. **Pezzi disponibili**: l'ubicazione di partenza deve contenere almeno la quantità richiesta.
2. **Coerenza prodotto**: se la destinazione non è vuota, deve contenere lo stesso `productId`.
3. **Coerenza cliente**: se la destinazione non è vuota, deve contenere lo stesso `customerId`.
4. **Ingombro libero**: `maxIngombro − currentIngombro` della destinazione deve coprire `quantità × ingombro unitario`.

A movimentazione riuscita, sorgente e destinazione vengono aggiornate; se la sorgente si svuota completamente, `productId`, `customerId` e `currentIngombro` vengono azzerati, rendendola disponibile per qualsiasi altro prodotto.

## Algoritmo dell'ubicazione più vicina

`POST /api/wms/nearest-location` riceve un'ubicazione sorgente `U` e una quantità `Q`, e cerca l'ubicazione idonea più vicina.

Per ogni ubicazione candidata (esclusa la sorgente) vengono applicati i filtri di idoneità:

- deve avere ingombro libero sufficiente per `Q × ingombro unitario`
- se non è vuota, deve contenere lo stesso prodotto **e** lo stesso cliente della sorgente

Fra le candidate idonee si sceglie quella a **distanza di Manhattan** minima, calcolata sulle coordinate degli armadi:

```
d = |fila_sorgente − fila_destinazione| + |colonna_sorgente − colonna_destinazione|
```

Due ubicazioni nello stesso armadio hanno quindi `d = 0`. Se nessuna candidata supera i filtri, la risposta contiene il messaggio `Nessuna ubicazione idonea disponibile`.

### Esempio da mostrare all'esame

Sorgente ubicazione `1` (armadio 1, fila 1, colonna 1), quantità `2` di prodotto 101 (ingombro unitario 10 → servono 20):

- ubicazione `2` — stesso armadio, vuota, 120 liberi → idonea, `d = |1−1| + |1−1| = 0`
- ubicazione `4` — armadio 2 (fila 1, col 3), vuota, 200 liberi → idonea, `d = 0 + 2 = 2`
- ubicazione `3` — contiene prodotto 102, diverso → **scartata**

Risultato: ubicazione `2`, distanza `0`.

Per far vedere un rifiuto, prova a spostare dall'ubicazione `1` alla `3`: contengono prodotti diversi e il servizio risponde `Le due ubicazioni contengono prodotti diversi`.

## API

**`product-service`** — `/api/products`

| Metodo | Path | Descrizione |
| :--- | :--- | :--- |
| GET | `/api/products` | elenco prodotti |
| GET | `/api/products/{id}` | dettaglio prodotto |
| GET | `/api/products/search?query=` | ricerca per nome o descrizione |
| POST | `/api/products` | crea o aggiorna un prodotto |
| DELETE | `/api/products/{id}` | elimina un prodotto |

**`crm-service`** — `/api/customers`

| Metodo | Path | Descrizione |
| :--- | :--- | :--- |
| GET | `/api/customers` | elenco clienti |
| GET | `/api/customers/{id}` | dettaglio cliente |

**`wms-service`** — `/api/wms`

| Metodo | Path | Descrizione |
| :--- | :--- | :--- |
| GET | `/api/wms/cabinets` | elenco armadi |
| GET | `/api/wms/locations?cabinetId=` | ubicazioni, opzionalmente filtrate per armadio |
| GET | `/api/wms/locations/{id}` | dettaglio ubicazione |
| POST | `/api/wms/movements` | esegue una movimentazione |
| POST | `/api/wms/nearest-location` | calcola l'ubicazione idonea più vicina |

Ogni servizio espone la propria Swagger UI su `/swagger-ui.html`: è il modo più comodo per provare i due POST, perché mostra lo schema esatto del corpo JSON.

## UI

`wms-ui` è un'applicazione Thymeleaf con un unico template, `wms-dashboard.html`, servito da `WmsUiController` su `/`. Contiene:

- il filtro per armadio (`?cabinetId=`)
- la tabella delle ubicazioni con prodotto e cliente già risolti per nome
- il form di movimentazione (`POST /movement`)
- il form di calcolo dell'ubicazione più vicina (`POST /nearest-location`)

Entrambi i form fanno redirect su `/` passando l'esito come flash attribute, così un refresh del browser non riesegue l'operazione. Se il cluster non risponde, il controller cattura l'eccezione e mostra un messaggio d'errore invece di una pagina di stack trace.

Lo stile è CSS inline dentro il template: la dashboard non dipende da Tailwind né da asset esterni.

## Persistenza

`product-service` e `wms-service` usano JPA/Hibernate con `ddl-auto: update`.

Di default girano su **H2 in memoria**: i dati vengono ricreati a ogni riavvio dai `CommandLineRunner`. `crm-service` non ha persistenza affatto, tiene i clienti in una `ConcurrentHashMap`.

Entrambi hanno il driver PostgreSQL a classpath e l'URL parametrico, quindi si passa a Postgres senza toccare il codice valorizzando le variabili d'ambiente nel `docker-compose.yml`:

- `product-service`: `PRODUCT_DB_URL`, `PRODUCT_DB_DRIVER`
- `wms-service`: `WMS_DB_URL`, `WMS_DB_DRIVER`

> ⚠️ Il `docker-compose.yml` avvia il container `postgres` ma **non lo collega ad alcun servizio**: finché quelle variabili non sono impostate, PostgreSQL resta inutilizzato. Se la commissione chiede persistenza reale, è il primo punto da sistemare.

## Eureka

`naming-server` espone la dashboard su `http://localhost:8761`. I quattro servizi si registrano con i nomi `PRODUCT-SERVICE`, `CRM-SERVICE`, `WMS-SERVICE` e `WMS-UI`.

L'URL del registro è configurabile con `EUREKA_SERVER_URL`, impostato nel compose a `http://eureka-server:8761/eureka/`; in locale usa il default `http://localhost:8761/eureka/`.

I client Eureka aggiornano la loro cache del registro ogni 30 secondi: dopo l'avvio dello stack, attendi 10-15 secondi prima della prima richiesta, altrimenti i Feign client possono rispondere 500 perché non conoscono ancora le istanze.

## Porte e URL

| Servizio | Porta | URL |
| :--- | :---: | :--- |
| WMS UI | `8080` | `http://localhost:8080` |
| Eureka | `8761` | `http://localhost:8761` |
| Product Service | `8081` | `http://localhost:8081/swagger-ui.html` |
| CRM Service | `8082` | `http://localhost:8082/swagger-ui.html` |
| WMS Service | `8083` | `http://localhost:8083/swagger-ui.html` |
| PostgreSQL | `5432` | avviato dal compose, non collegato ai servizi |

## Multi-Module Maven

Il progetto usa un parent Maven aggregatore in [demo/pom.xml](./demo/pom.xml). I moduli attivi in questa soluzione sono:

- [common-dto](./demo/common-dto) — DTO condivisi
- [naming-server](./demo/naming-server)
- [product-service](./demo/product-service)
- [crm-service](./demo/crm-service)
- [wms-service](./demo/wms-service)
- [wms-ui](./demo/wms-ui)

Il branch conserva anche i moduli scheletro del template (`tourist-service`, `random-service`, `store-service`, `event-ui`): sono dichiarati nel `pom.xml` aggregatore, quindi vengono compilati, ma non fanno parte dello stack Docker WMS.

Cosa cambia rispetto a un progetto single-module:

- le dipendenze non sono più condivise da tutto il progetto: ogni servizio compila solo con gli starter che gli servono
- i DTO comuni stanno in un jar separato, così UI e servizi parlano lo stesso linguaggio senza duplicare classi
- Docker e `spring-boot:run` lavorano sul singolo modulo, non su un monolite con più main class
- il costo è avere più `pom.xml` e una struttura leggermente più articolata

## Tecnologie

- Spring Boot 4.0.5
- Spring Cloud 2025.1.1 (Netflix Eureka, OpenFeign)
- Spring Data JPA / Hibernate
- H2 (runtime di default), driver PostgreSQL 18.3 disponibile
- springdoc-openapi 2.8.5 (Swagger UI)
- Lombok 1.18.44
- Apache Maven Wrapper 3.9.14
- Thymeleaf
- Docker / Docker Compose
- Taskfile (`go-task`)

## Installazioni necessarie

Sull'host servono:

- Git
- Docker Desktop oppure Docker Engine + Docker Compose
- Task (`go-task`)
- Java 25 (per `task dev`, `task build` e i `run-*`)

Verifica rapida dell'ambiente:

```bash
git --version
```

```bash
docker compose version
```

```bash
task --version
```

```bash
java --version
```

Il Taskfile usa come `JAVA_HOME_PATH` il percorso `C:/Program Files/Microsoft/jdk-25.0.2.10-hotspot`. Se sul tuo PC Java è installato altrove, aggiorna quella variabile in [Taskfile.yml](./Taskfile.yml) oppure imposta `JAVA_HOME` nell'ambiente: il Taskfile lo usa se presente.

## Avvio

### Sviluppo (consigliato mentre lavori)

```bash
task dev
```

Libera le porte da eventuali avanzi, compila tutti i moduli una volta sola, avvia Eureka, ne attende la porta e poi lancia gli altri quattro servizi. Girano in background, in un terminale solo: l'output va in `.dev-logs/`.

Per seguire i log di tutti insieme, ogni riga prefissata dal nome del servizio:

```bash
task logs
```

`Ctrl+C` chiude solo la vista. Per uno solo: `task logs SERVICE=wms`.

Dopo una modifica al codice:

```bash
task compile
```

Il servizio interessato si riavvia da solo grazie a `spring-boot-devtools`.

Per fermare lo stack locale e liberare le porte:

```bash
task dev-down
```

Se qualcosa non risponde, `task status` dice chi occupa ogni porta, quali container girano e cosa si è registrato su Eureka.

### Demo (quello che presenti alla commissione)

```bash
task docker-up
```

Per i log:

```bash
task docker-logs
```

Per arrestare i container conservando i dati del database:

```bash
task docker-down
```

Per ripartire da un database vuoto: `task docker-reset`.

> ℹ️ Locale e Docker usano le stesse porte, ma non devi ricordartene: `task docker-up` ferma da solo lo stack locale, e `task dev` spegne da solo i container.

### Collaudo automatizzato

```bash
task test-e2e
```

Esegue [`test_e2e_wms.ps1`](./test_e2e_wms.ps1), che percorre il flusso completo sui servizi avviati. Se hai spostato la UI su un'altra porta, passala anche qui: `task test-e2e UI_PORT=9080`.

## Task disponibili

| Task | Cosa fa |
| :--- | :--- |
| `task` | Elenca tutti i task disponibili |
| `task dev` | Pulisce, compila e avvia l'intero stack in locale con hot reload |
| `task dev-down` | Ferma i servizi locali e libera le porte |
| `task logs` | Segue i log di tutti i servizi in un terminale solo |
| `task status` | Chi occupa le porte, quali container girano, cosa è su Eureka |
| `task compile` | Ricompila e fa ripartire i servizi già avviati |
| `task build` | Compila tutti i moduli Maven |
| `task docker-up` | Avvia lo stack containerizzato |
| `task docker-down` | Arresta i container, conservando i dati del database |
| `task docker-reset` | Arresta i container ed elimina i volumi |
| `task docker-logs` | Segue i log dei container |
| `task test-e2e` | Esegue lo script di collaudo |
| `task clean-ports` | Come `dev-down`, libera le porte dello stack |
| `task kill-java` | Ultima spiaggia: termina tutti i processi Java della macchina |
| `task run-eureka` · `run-product` · `run-crm` · `run-wms` · `run-wms-ui` | Avvio manuale di un singolo modulo |
| `task run-db` | Avvia solo PostgreSQL (non necessario: i servizi usano H2) |

## Note da dire all'esame

- **Perché Eureka**: i servizi si trovano per nome logico, non per host e porta. Si può scalare o spostare un servizio senza toccare la configurazione dei client.
- **Perché OpenFeign**: il client REST è un'interfaccia dichiarativa; l'integrazione con il load balancer di Spring Cloud risolve il nome logico in un'istanza concreta.
- **Perché `common-dto`**: UI e servizi condividono lo stesso contratto senza duplicare le classi, e un cambio di campo si propaga a compile time invece che a runtime.
- **Gestione degli errori di dominio**: le violazioni delle regole di magazzino tornano come `StockMovementResult` con `success: false`, non come eccezioni HTTP. È una scelta deliberata: l'utente della UI deve leggere *perché* lo spostamento è stato rifiutato.
- **Degradazione controllata**: se `PRODUCT-SERVICE` o `CRM-SERVICE` cadono, `WMS-SERVICE` continua a rispondere con dati segnaposto invece di restituire 500. Si può dimostrare fermando un container durante la demo.
- **Distanza di Manhattan**: è la metrica giusta per una griglia di scaffalature, dove ci si muove lungo corsie ortogonali e non in diagonale.
- **Healthcheck e ordine di avvio**: nel compose i servizi dipendono da `eureka-server` con `condition: service_healthy`, quindi non partono finché il registro non risponde. L'healthcheck usa `curl`, che il `Dockerfile` installa esplicitamente perché l'immagine `eclipse-temurin:25-jre` non lo include.
