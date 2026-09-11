# Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot

Manuale strategico e tecnico per la preparazione ed il superamento della **Prova Finale Backend ITS (Technologies Talent Factory)** basata su Spring Boot, Microservizi, Docker ed OpenAPI.

---

## 1. Struttura della Prova Finale & Griglia di Valutazione

La prova ha una durata tipica di **6 ore** e richiede la consegna di un archivio zip denominato `COGNOME_NOME.zip`.

### Griglia standard dei punteggi (Totale 40 Punti):

1. **Allegato Tecnico (fino a 8 Punti)**: Documento di analisi con schema DB distribuito, descrizione dei moduli, porte HTTP, descrizione algoritmi e istruzioni di collaudo.
2. **Server Naming Eureka (fino a 3 Punti)**: Progetto Spring Boot configurato come Eureka Server per il Service Discovery.
3. **Microservizio Anagrafica / Backend Core (fino a 8 Punti)**: Microservizio REST con persistenza DB, Swagger/OpenAPI e dati di test (dump SQL o inizializzatore Java).
4. **Applicazione UI / WMS / Servizio Principale (fino a 10 Punti)**: Frontend Web (Thymeleaf/JS), integrazione con DB e chiamate ai servizi esterni tramite Eureka.
5. **Servizio Ausiliario / Mock Esterno (fino a 3 Punti)**: Registrazione su Eureka del servizio mock/fornitore preesistente.
6. **Domanda Teorica A (fino a 4 Punti)**: Docker vs VM, Docker Compose, Sicurezza e Federazione dei Servizi (Spring Security, OAuth2, Keycloak).
7. **Domanda Teorica B (fino a 4 Punti)**: DB Relazionali vs NoSQL, integrazione NoSQL nella soluzione, Confronto Stack JEE vs Spring Boot.

---

## 1.1 Matrice delle Responsabilità: Tu vs Template / Comandi task

All'esame il tempo è prezioso: delega agli strumenti il lavoro meccanico e concentrati su quello che viene valutato dalla commissione:

| Ambito | Cosa deleghi al Template / ai comandi `task` | Cosa spetta a TE (Candidato) |
| :--- | :--- | :--- |
| **Architettura & Moduli** | `task new-service` collega il modulo in tutti i 6 punti (pom aggregatore, Dockerfile, docker-compose, dev, VS Code, porte). | Scegliere i nomi dei moduli dalla traccia (es. `catalogo-service`, `ordini-service`, `ui-service`). |
| **Persistenza & Entity** | `task new-entity` genera Entity, Repository, Service CRUD e Controller REST con Swagger. | Definire le **relazioni JPA** (@ManyToOne, @ManyToMany...) all'interno del modulo e i metodi custom del repository. |
| **Microservizi & Database** | Ogni modulo ha il suo database isolato (H2 in-memory o Postgres dedicato con `task use-postgres`). | **NON creare mai chiavi esterne tra moduli diversi!** Usare solo l'ID numerico (`Long libroId`) e OpenFeign. |
| **Contratti DTO & Record** | `task new-dto` genera i record Java in `common-dto` con validazione Bean Validation. | Decidere quali campi esporre e scambiare tra i microservizi. |
| **Chiamate tra Servizi** | `task new-client` crea l'interfaccia `@FeignClient` pronta con metodi CRUD risolti tramite Eureka. | Invocare il client nel `@Service` chiamante e gestire le eccezioni di business (es. 404 se un record non esiste). |
| **Interfaccia Web (UI)** | `task new-view` crea Controller Thymeleaf e template HTML con tabella dinamica e form validato. | Personalizzare i campi del form e visualizzare i dati ricevuti da Feign nel Model. |
| **Sicurezza (Spring Security)** | `task add-dep SERVICE=... DEPS=security` genera `SecurityConfig.java` già funzionante (CSRF disattivato, Swagger/Eureka aperti, utenti `admin`/`user`). | Configurare le regole di autorizzazione per ruolo (es. `.requestMatchers("/admin/**").hasRole("ADMIN")`) se richieste dalla traccia. |
| **Logica di Business & Algoritmo** | *Nessuna automazione (apposta)*. | **È il cuore della valutazione:** implementare i calcoli, controlli di disponibilità, regole di sconto, algoritmi richiesti. |
| **Documentazione & Consegna** | `task db-schema` estrae lo schema ER; `task consegna` prepara lo zip pulito rimuovendo tutte le classi interne del template (`devdata`). | Scrivere analisi del problema, algoritmo e risposte teoriche in `allegato.md`. |

---

## 2. Workflow Operativo d'Esame in 6 Ore (Passo-Passo)

Per massimizzare il punteggio e completare l'esame senza stress, segui questa tabella di marcia temporale:

```
[0:00 - 0:45] Fase 1: Analisi & Allegato Tecnico (8pt)
      │
[0:45 - 1:15] Fase 2: Naming Server Eureka (3pt)
      │
[1:15 - 2:45] Fase 3: Microservizio Core / Anagrafica REST + OpenAPI (8pt)
      │
[2:45 - 4:15] Fase 4: Applicazione UI / WMS + Feign Clients + Algoritmo (10pt)
      │
[4:15 - 5:15] Fase 5: Risposte alle Domande Teoriche A e B (8pt)
      │
[5:15 - 6:00] Fase 6: Containerizzazione Docker, Collaudo & Impacchettamento
```

### 📋 Dettaglio Operativo delle Fasi:

- **Fase 1 (0:00 - 0:45) - Analisi & Allegato Tecnico**:
  1. Leggi l'intero testo d'esame ed evidenzia i requisiti funzionali (es. prodotti, ubicazioni, particelle, visite).
  2. Definisci le porte HTTP per ciascun servizio (es. Eureka `8761`, Anagrafica `8081`, Mock `8082`, UI `8080`, Postgres `5432`).
  3. Disegna lo schema ER/Logico distribuito delle tabelle.
  4. Scrivi subito la sezione dell'algoritmo nell'Allegato Tecnico (es. formula della distanza di Manhattan e complessità $O(N \times M)$) per bloccare gli 8 punti dell'Allegato prima di scrivere codice.

- **Fase 2 (0:45 - 1:15) - Eureka Naming Server**:
  1. Crea o avvia il modulo `naming-server`.
  2. Inserisci `@EnableEurekaServer` sulla classe `Main`.
  3. Configura `server.port: 8761` e disabilita l'auto-registrazione in `application.yml`.
  4. Verifica la dashboard aprendo `http://localhost:8761`.

- **Fase 3 (1:15 - 2:45) - Microservizio Anagrafica / REST Core**:
  1. Definisci le classi `@Entity` JPA con i campi richiesti.
  2. Crea l'interfaccia `JpaRepository`.
  3. Realizza il `@RestController` con gli endpoint CRUD (`@GetMapping`, `@PostMapping`, `@DeleteMapping`).
  4. Aggiungi `springdoc-openapi-starter-webmvc-ui` e le annotazioni `@Tag`, `@Operation`, `@Parameter`.
  5. Inizializza i dati di prova tramite un bean `@Bean CommandLineRunner` o file `data.sql`.
  6. Collauda le API da `http://localhost:8081/swagger-ui.html`.

- **Fase 4 (2:45 - 4:15) - Applicazione WMS / UI & Client Feign**:
  1. Inserisci `@EnableFeignClients` e crea le interfacce `@FeignClient` per invocare l'anagrafica e il servizio mock tramite il nome logico registrato su Eureka.
  2. Implementa le regole di business (es. spostamento merci con verifica ingombro/cliente, oppure apertura/chiusura pratica catasto con ricalcolo classe energetica).
  3. Crea il controller Thymeleaf `@Controller` o le API REST per l'interfaccia web.
  4. Implementa il form HTML e, facoltativamente, la chiamata `fetch()` JavaScript per aggiornamenti asincroni senza reload.

- **Fase 5 (4:15 - 5:15) - Domande Teoriche A e B**:
  1. Compila le risposte teoriche (utilizzando il testo precompilato della Sezione 9 di questo manuale).
  2. Verifica di aver coperto: Docker vs VM, Docker Compose, OAuth2/Keycloak/Gateway per la Domanda A; SQL vs NoSQL (MongoDB/Redis) e JEE vs Spring Boot per la Domanda B.

- **Fase 6 (5:15 - 6:00) - Containerizzazione Docker, Collaudo & Consegna**:
  1. Configura `docker-compose.yml` mappando tutte le porte host.
  2. Esegui `task docker-up` e accertati che su Eureka tutti i microservizi risultino in stato **UP**.
  3. Compila l'archivio ZIP finale `COGNOME_NOME.zip` organizzato secondo le indicazioni della traccia d'esame.

---

## 3. OpenAPI & Swagger UI: Guida Passo-Passo

### 3.1 Perché è fondamentale
Nelle tracce d'esame è espressamente richiesto:
> *"Il servizio di anagrafica deve pubblicare i propri servizi REST tramite opportuno descrittore SWAGGER/(OPEN-API) e fornire l'interfaccia web SWAGGER-UI per i test."*

### 3.2 Abilitazione in Spring Boot (versione 3.x / 4.x)

1. **Aggiunta della Dipendenza Maven (`pom.xml`)**:
   ```xml
   <dependency>
       <groupId>org.springdoc</groupId>
       <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
       <version>2.8.5</version>
   </dependency>
   ```

   > In **questo** template la versione non si scrive: la governa il `pom.xml`
   > padre, che la fissa una volta per tutti i moduli. E i servizi creati con
   > `task new-service` hanno già springdoc dentro. Per aggiungerlo altrove:
   > `task add-dep SERVICE=<modulo> DEPS=springdoc`.

2. **Configurazione in `application.yml`**:
   ```yaml
   springdoc:
     api-docs:
       path: /v3/api-docs
     swagger-ui:
       path: /swagger-ui.html
       operations-sorter: method
   ```

3. **Annotazione dei Controller Java**:
   ```java
   @RestController
   @RequestMapping("/api/prodotti")
   @Tag(name = "Anagrafica Prodotti", description = "API per la gestione del catalogo prodotti")
   public class ProdottoController {

       @GetMapping("/{id}")
       @Operation(summary = "Recupera un prodotto", description = "Restituisce i dettagli del prodotto dato il suo ID univoco")
       public ResponseEntity<ProdottoDTO> getById(
           @Parameter(description = "ID del prodotto", example = "101") 
           @PathVariable Long id
       ) {
           return ResponseEntity.ok(prodottoService.findById(id));
       }
   }
   ```

4. **Visualizzazione dal Browser**:
   - Accedi a: `http://localhost:<PORTA>/swagger-ui.html`
   - Si aprirà l'interfaccia interattiva dove la commissione d'esame potrà testare i contratti REST ed inviare richieste HTTP con il tasto **"Try it out"**.

---

## 4. Proprietà e Configurazioni (`application.yml`)

Di seguito viene spiegato il significato ed il ruolo di ogni proprietà di configurazione utilizzata nei microservizi Spring Boot:

```yaml
# ===================================================================
# CONFIGURAZIONE SERVER & NOME APPLICAZIONE
# ===================================================================
server:
  port: 8081 # Porta HTTP su cui risponde l'applicazione

spring:
  application:
    name: ORDINI-SERVICE # Nome logico registrato su Eureka (sempre MAIUSCOLO per convenzione)

# ===================================================================
# CONFIGURAZIONE EUREKA NAMING SERVER (CLIENT DISCOVERY)
# ===================================================================
eureka:
  client:
    register-with-eureka: true # True per i microservizi normali; False solo per il Server Eureka
    fetch-registry: true # Permette al servizio di scaricare l'elenco degli altri servizi da Eureka
    service-url:
      defaultZone: ${EUREKA_SERVER_URL:http://localhost:8761/eureka/} # URL del registro Eureka

  instance:
    prefer-ip-address: true # Eureka registra l'indirizzo IP invece dell'hostname (fondamentale in Docker)
    lease-renewal-interval-in-seconds: 10 # Frequenza invio heartbeat a Eureka
    lease-expiration-duration-in-seconds: 30 # Tempo massimo attesa prima di rimuovere il servizio disconnesso

# ===================================================================
# CONFIGURAZIONE DATABASE & DATABASE JPA / HIBERNATE
# ===================================================================
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/esame # URL JDBC di connessione
    username: exam
    password: exam
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: update # update: crea/aggiorna le tabelle in automatico; create-drop: cancella al termine
    show-sql: true # Stampa le query SQL eseguite nella console di log
    properties:
      hibernate:
        format_sql: true # Formatta le query SQL stampate nei log rendendole leggibili
        dialect: org.hibernate.dialect.PostgreSQLDialect

# ===================================================================
# CONFIGURAZIONE SPRINGDOC OPENAPI / SWAGGER UI
# ===================================================================
springdoc:
  api-docs:
    path: /v3/api-docs # Endpoint JSON che restituisce la specifica OpenAPI 3
  swagger-ui:
    path: /swagger-ui.html # URL Web per accedere all'interfaccia di collaudo Swagger
    operations-sorter: method # Ordina i metodi per tipo (GET, POST, PUT, DELETE)

# ===================================================================
# CONFIGURAZIONE OPENFEIGN (TIMEOUT E LOGGING)
# ===================================================================
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connectTimeout: 5000 # Timeout di connessione HTTP (in ms)
            readTimeout: 5000 # Timeout di lettura risposta HTTP (in ms)

# ===================================================================
# CONFIGURAZIONE LIVELLO LOGGING
# ===================================================================
logging:
  level:
    root: INFO
    esame: DEBUG # Abilita il log dettagliato per i package del progetto (la base: task set-package)
    org.hibernate.SQL: DEBUG # Stampa i parametri delle query SQL
```

---

## 5. Come funziona il tutto insieme

Le librerie di questo progetto non sono pezzi indipendenti: ognuna accende un
anello della stessa catena. Vale la pena vederla una volta intera, perché
quando qualcosa non funziona il punto è quasi sempre uno di questi anelli.

### 5.1 Il giro completo di una richiesta

```
browser
   │  GET /
   ▼
<nome>-ui            Spring Web + Thymeleaf: un @Controller restituisce il nome
   │                 di una pagina, Thymeleaf la riempie coi dati del Model
   │  ordiniClient.tutti()
   ▼
OpenFeign            l'interfaccia @FeignClient(name = "ORDINI-SERVICE"),
   │                 a runtime, diventa una vera chiamata HTTP
   │  "dove sta ORDINI-SERVICE?"
   ▼
Eureka  :8761        il registro risponde con indirizzo e porta dell'istanza
   │
   │  GET http://10.1.2.3:8081/api/ordini
   ▼
<nome>-service       un @RestController riceve la richiesta
   │  ordineRepository.findAll()
   ▼
Spring Data JPA      l'interfaccia JpaRepository diventa una query, senza che
   │                 tu scriva l'implementazione
   ▼
Hibernate            traduce in SQL e rimappa le righe sulle @Entity
   │
   ▼
H2 in memoria (o PostgreSQL)
```

Nel frattempo, in parallelo e senza che tu scriva niente:

- **springdoc** legge gli stessi `@RestController` e pubblica `/v3/api-docs` e `/swagger-ui.html`;
- **Lombok** ha già generato getter, setter e costruttori delle classi che passano di lì;
- **devtools** tiene d'occhio le classi compilate: dopo `task compile` il servizio si riavvia da solo.

### 5.2 Chi accende cosa

Ogni pezzo si accende con una dipendenza nel `pom.xml` (che è quello che fa
`task add-dep`), e spesso con un'annotazione sulla classe `Main`.

| Cosa vuoi | Dipendenza (nome breve) | Annotazione / configurazione | Come te ne accorgi |
| :--- | :--- | :--- | :--- |
| Endpoint REST | `web` | `@RestController`, `@RequestMapping` | il servizio risponde su `http://localhost:<porta>/api/...` |
| Pagine HTML | `thymeleaf` | `@Controller` + file in `resources/templates/` | il browser mostra la pagina invece del JSON |
| Registrarsi su Eureka | `eureka-client` | `@EnableDiscoveryClient` + `eureka.client.service-url.defaultZone` | compare in `task status`, sezione REGISTRO EUREKA |
| Chiamare un altro servizio | `feign` | `@EnableFeignClients` + `@FeignClient(name = "ALTRO-SERVICE")` | la chiamata parte senza che tu scriva un URL |
| Persistenza | `data-jpa` + `h2` o `postgresql` | `@Entity`, `JpaRepository`, `spring.datasource.*` | Hibernate stampa le query nei log |
| Contratti OpenAPI | `springdoc` | nessuna: legge i controller | `http://localhost:<porta>/swagger-ui.html` |
| Meno codice ripetuto | `lombok` | `@Data`, `@RequiredArgsConstructor`, `@Slf4j` | le classi restano corte |
| Validazione degli input | `validation` | `@Valid` + `@NotNull`, `@Size`, ... | una richiesta sbagliata torna 400 invece di rompersi dopo |

I moduli creati con `task new-service` nascono già con quasi tutto questo
collegato: `Main` ha `@EnableDiscoveryClient` e `@EnableFeignClients`,
l'`application.yml` ha Eureka, il datasource e springdoc.

### 5.3 I nomi: dove nascono e chi li usa

È il punto che confonde di più, e vale un paragrafo suo.

```yaml
# demo/ordini-service/src/main/resources/application.yml
spring:
  application:
    name: ORDINI-SERVICE      # <-- il nome con cui si registra su Eureka
```

```java
// dentro un ALTRO modulo, che vuole chiamarlo
@FeignClient(name = "ORDINI-SERVICE")   // <-- lo stesso nome, non un URL
public interface OrdiniClient {
    @GetMapping("/api/ordini")
    List<OrdineDTO> tutti();
}
```

Le due stringhe devono coincidere: è l'unico collegamento fra chi chiama e chi
risponde. Da qui discendono tre conseguenze pratiche:

1. **Nel codice non compaiono mai host e porte.** Per questo `task set-port`
   può spostare un servizio senza rompere niente.
2. **Se sbagli il nome, l'errore arriva a runtime**, non in compilazione: una
   `500` con dentro un messaggio tipo *"Load balancer does not contain an
   instance for the service ORDINI-SERVICE"*. Controlla `task status`.
3. **Il registro non è immediato.** Ogni client tiene una copia del registro, e
   il load balancer una copia di quella: con i valori di Spring passano anche
   30-60 secondi prima che un servizio appena acceso sia chiamabile. I moduli
   di `task new-service` le rinfrescano ogni 5 secondi
   (`registry-fetch-interval-seconds`, `spring.cloud.loadbalancer.cache.ttl`),
   quindi basta poco; una `500` nei primissimi secondi non è un bug: riprova.

### 5.4 `common-dto`: il contratto condiviso

Quando due moduli si scambiano un oggetto, quell'oggetto deve avere **la stessa
forma da entrambe le parti**. Le strade sono due: duplicare la classe in ogni
modulo — e scoprire a metà esame che una delle due copie ha un campo in più —
oppure tenerla in un modulo solo, che gli altri usano come libreria. Quel
modulo è `common-dto`.

Non è un servizio: non ha `Main`, non ha una porta, non si registra su Eureka.
È un barattolo di classi.

**Aggiungere un DTO**: crei la classe dentro `demo/common-dto/src/main/java/...`

```java
package esame.common.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data                 // getter, setter, equals, toString
@NoArgsConstructor    // Jackson ne ha bisogno per ricostruire l'oggetto dal JSON
@AllArgsConstructor
public class OrdineDTO {
    private Long id;
    private String cliente;
    private int quantita;
}
```

`@NoArgsConstructor` non è decorativo: senza costruttore vuoto Jackson non sa
ricostruire l'oggetto, e la chiamata Feign fallisce con un errore che parla di
deserializzazione e non di DTO.

**Usarlo**: i moduli lo dichiarano già nel loro `pom.xml`, con la versione
presa dal progetto stesso —

```xml
<dependency>
    <groupId>com.example</groupId>
    <artifactId>common-dto</artifactId>
    <version>${project.version}</version>
</dependency>
```

— quindi ti basta importarlo. Lo usa chi risponde:

```java
@GetMapping("/api/ordini")
public List<OrdineDTO> tutti() { ... }
```

e lo usa chi chiama, nella firma del `@FeignClient`. Stessa classe, stesso
JSON, nessuna sorpresa.

**La trappola**: `common-dto` è una dipendenza compilata, non un servizio. Se
lo modifichi, gli altri moduli continuano a usare la versione già installata
finché non li ricompili — e `task compile` fa esattamente questo, per tutti,
in un colpo solo. Se dopo una modifica a un DTO vedi un campo sparire dal
JSON, la causa è quasi sempre questa.

**Cosa ci va e cosa no**: DTO e piccoli `enum` condivisi. Non ci vanno le
`@Entity` (sono il modello del database di *un* servizio, non un contratto fra
servizi) né la logica di business.

### 5.5 Spring Security: Perché blocca tutto di default e come usarla all'esame

Quando aggiungi `spring-boot-starter-security` (con `task add-dep SERVICE=... DEPS=security`), Spring Boot attiva immediatamente l'autoconfigurazione di sicurezza:
1. **Blocca ogni rotta di default**: qualsiasi richiesta riceve `401 Unauthorized` (o redirect a `/login`).
2. **Genera una password casuale al boot**: visibile nei log con `Using generated security password: ...`.
3. **Abilita la protezione CSRF**: qualsiasi chiamata REST `POST`, `PUT`, `DELETE` inviata da Postman, curl o Feign viene bloccata con `403 Forbidden` perché priva del token CSRF.

#### Come si risolve per l'esame
Con `task add-dep SERVICE=... DEPS=security`, il template crea automaticamente `config/SecurityConfig.java`:
- Disabilita CSRF per consentire chiamate REST senza token.
- Apre in `permitAll()` le rotte tecniche (`/swagger-ui/**`, `/v3/api-docs/**`, `/actuator/**`, `/h2-console/**`).
- Registra due utenti in-memory (`admin`/`admin123` con ruolo `ADMIN`, `user`/`user123` con ruolo `USER`).
- Se la traccia richiede autorizzazioni per ruolo, basta una sola riga nel bean `SecurityFilterChain`:
  ```java
  .requestMatchers(HttpMethod.POST, "/api/**").hasRole("ADMIN")
  .requestMatchers(HttpMethod.GET, "/api/**").hasAnyRole("USER", "ADMIN")
  ```

### 5.6 Relazioni JPA tra tabelle & Il confine sacro tra Microservizi

#### 1. All'interno dello stesso modulo (Stesso Database)
- **Many-to-One / One-to-Many**: La chiave esterna `autore_id` sta nella tabella del lato *Molti* (`libri`).
  ```java
  // In LibroEntity (lato Molti, detiene la FK)
  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "autore_id", nullable = false)
  private AutoreEntity autore;

  // In AutoreEntity (lato Uno, opzionale)
  @OneToMany(mappedBy = "autore", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<LibroEntity> libri = new ArrayList<>();
  ```
- **Many-to-Many**: Per relazioni N:N pure, Hibernate crea una tabella di giunzione automatica:
  ```java
  @ManyToMany(fetch = FetchType.LAZY)
  @JoinTable(name = "studenti_corsi",
      joinColumns = @JoinColumn(name = "studente_id"),
      inverseJoinColumns = @JoinColumn(name = "corso_id"))
  private Set<CorsoEntity> corsi = new HashSet<>();
  ```
  *Attenzione*: se la relazione ha attributi extra (es. `dataIscrizione`, `voto`), non usare `@ManyToMany`: crea un'entità intermedia con due `@ManyToOne`.
- **One-to-One**: Chiave esterna univoca (`unique = true`):
  ```java
  @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
  @JoinColumn(name = "tessera_id", unique = true)
  private TesseraEntity tessera;
  ```
- **Regole d'oro**:
  1. Usa sempre `FetchType.LAZY`.
  2. Mai `@Data` di Lombok sulle Entity con relazioni (causa `StackOverflowError` nel `toString()`).
  3. Inizializza sempre le liste (`= new ArrayList<>()`).
  4. Restituisci DTO dai controller per evitare loop infiniti di serializzazione JSON Jackson.

#### 2. Tra Moduli Diversi (Microservizi Diversi)
> **NON creare MAI relazioni JPA o chiavi esterne SQL che attraversano due moduli!**
> Ogni microservizio ha il proprio database. Salva esclusivamente l'ID numerico come colonna semplice (`private Long libroId;`) e recupera i dettagli invocando l'API REST dell'altro servizio via **OpenFeign** (`task new-client`) scambiando DTO (`task new-dto`).

---

## 6. Mini-Guida Completa alle Librerie ed Annotazioni Java

Per ogni libreria: la tabella delle annotazioni, e sotto un esempio completo
che dice **in quale modulo** va il codice.

### 6.1 Spring Web & MVC (`@RestController`, `@Controller`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@RestController` | Classe Controller | Marca la classe come controller REST. Ogni metodo restituisce direttamente JSON o dati strutturati (combina `@Controller` e `@ResponseBody`). |
| `@Controller` | Classe Controller | Marca la classe come controller Web tradizionali (Thymeleaf/HTML). I metodi restituiscono il nome del template HTML da renderizzare. |
| `@RequestMapping("/api")` | Classe / Metodo | Definisce il prefisso del percorso URL base gestito dal controller. |
| `@GetMapping("/path")` | Metodo | Mappa le richieste HTTP **GET** (lettura dati). |
| `@PostMapping("/path")` | Metodo | Mappa le richieste HTTP **POST** (creazione dati / form submit). |
| `@PutMapping("/{id}")` | Metodo | Mappa le richieste HTTP **PUT** (aggiornamento completo risorsa). |
| `@DeleteMapping("/{id}")` | Metodo | Mappa le richieste HTTP **DELETE** (cancellazione risorsa). |
| `@PathVariable` | Parametro metodo | Estrae un parametro variabile direttamente dal path dell'URL (es. `/api/prodotti/{id}`). |
| `@RequestParam` | Parametro metodo | Estrae un parametro dalla Query String (es. `/api/prodotti?categoria=A1`). |
| `@RequestBody` | Parametro metodo | Deserializza il corpo della richiesta HTTP JSON nel relativo DTO o Oggetto Java. |
| `@ModelAttribute` | Parametro metodo | Binda i dati inviati da un form HTML (Thymeleaf) ad un oggetto Java DTO. |
| `@Validated` / `@Valid` | Classe / Parametro | Attiva la validazione automatica delle annotazioni di vincolo (es. `@NotNull`, `@Min`) sui parametri di input. |

#### Esempio completo — un controller REST e uno Thymeleaf

Il primo va in un **servizio** (`ordini-service`), il secondo in una **UI**
(`ordini-ui`): stessa libreria, due usi diversi.

```java
// demo/ordini-service/src/main/java/.../OrdineController.java
package esame.ordiniservice;

import esame.common.dto.OrdineDTO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController                       // ogni metodo restituisce JSON
@RequestMapping("/api/ordini")        // prefisso comune di tutti i path
@RequiredArgsConstructor              // Lombok: costruttore con i campi final
public class OrdineController {

    private final OrdineService service;   // iniettato dal costruttore

    // GET /api/ordini            -> elenco completo
    // GET /api/ordini?cliente=X  -> filtrato
    @GetMapping
    public List<OrdineDTO> elenco(@RequestParam(required = false) String cliente) {
        return (cliente == null) ? service.tutti() : service.perCliente(cliente);
    }

    // GET /api/ordini/7
    @GetMapping("/{id}")
    public ResponseEntity<OrdineDTO> uno(@PathVariable Long id) {
        return service.trova(id)
                .map(ResponseEntity::ok)                             // 200 col corpo
                .orElseGet(() -> ResponseEntity.notFound().build()); // 404
    }

    // POST /api/ordini, col JSON dell'ordine nel corpo
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)   // 201 invece del 200 di default
    public OrdineDTO crea(@Valid @RequestBody OrdineDTO nuovo) {
        return service.salva(nuovo);
    }

    @PutMapping("/{id}")
    public OrdineDTO aggiorna(@PathVariable Long id, @Valid @RequestBody OrdineDTO modifiche) {
        return service.aggiorna(id, modifiche);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)   // 204: fatto, niente da restituire
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
```

```java
// demo/ordini-ui/src/main/java/.../OrdineWebController.java
package esame.ordiniui;

import esame.common.dto.OrdineDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

@Controller                    // NON @RestController: qui si restituiscono pagine
@RequiredArgsConstructor
public class OrdineWebController {

    private final OrdiniClient ordiniClient;   // il @FeignClient, vedi 6.3

    @GetMapping("/")
    public String elenco(Model model) {
        model.addAttribute("ordini", ordiniClient.tutti());
        model.addAttribute("nuovo", new OrdineDTO());   // oggetto vuoto per il form
        return "ordini";      // -> src/main/resources/templates/ordini.html
    }

    @PostMapping("/ordini")
    public String crea(@ModelAttribute OrdineDTO nuovo) {   // dati del form HTML
        ordiniClient.crea(nuovo);
        return "redirect:/";   // dopo una POST: niente doppio invio col refresh
    }
}
```

```html
<!-- demo/ordini-ui/src/main/resources/templates/ordini.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org">
<head><meta charset="UTF-8"><title>Ordini</title></head>
<body>
    <table>
        <tr th:each="o : ${ordini}">
            <td th:text="${o.id}">1</td>
            <td th:text="${o.cliente}">Rossi</td>
            <td th:text="${o.quantita}">3</td>
        </tr>
    </table>

    <form th:action="@{/ordini}" th:object="${nuovo}" method="post">
        <input type="text" th:field="*{cliente}">
        <input type="number" th:field="*{quantita}">
        <button type="submit">Aggiungi</button>
    </form>
</body>
</html>
```

> Tre cose che all'esame fanno perdere tempo: `@RestController` su una classe
> che dovrebbe restituire pagine (il browser si ritrova il nome del template
> come testo), il `redirect:` dimenticato dopo una POST, e `@RequestBody` al
> posto di `@ModelAttribute` per i dati di un form — un form HTML non manda
> JSON.

---

### 6.2 OpenAPI / Springdoc (`Swagger`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@Tag(name = "...", description = "...")` | Classe Controller | Raggruppa gli endpoint sotto una categoria nell'interfaccia Swagger UI. |
| `@Operation(summary = "...", description = "...")` | Metodo REST | Descrive il titolo breve ed il dettaglio di cosa fa il singolo endpoint. |
| `@Parameter(description = "...", example = "...")` | Parametro metodo | Aggiunge descrizione ed un valore di esempio al parametro nella UI Swagger. |
| `@ApiResponse(responseCode = "200", description = "...")` | Metodo REST | Documenta l'esito HTTP di risposta restituito dall'API (200 OK, 400 Bad Request, 404 Not Found). |
| `@Schema(description = "...", example = "...")` | Campo DTO / Class | Documenta il significato ed i valori di esempio per le proprietà dei DTO nella sezione Schemas. |

#### Esempio completo — lo stesso controller, documentato

Va nel **servizio REST**; il `@Schema` dei campi va sul DTO, quindi in
**common-dto**. Senza nessuna di queste annotazioni Swagger funziona lo stesso
(elenca gli endpoint e li fa provare): servono a farlo leggere bene alla
commissione, ed è il punto della traccia che chiede il "descrittore".

```java
// demo/ordini-service/src/main/java/.../OrdineController.java
package esame.ordiniservice;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/ordini")
@RequiredArgsConstructor
@Tag(name = "Ordini", description = "Creazione e consultazione degli ordini")
public class OrdineController {

    private final OrdineService service;

    @GetMapping("/{id}")
    @Operation(summary = "Un ordine per id",
               description = "Restituisce l'ordine, o 404 se quell'id non esiste")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Ordine trovato"),
        @ApiResponse(responseCode = "404", description = "Nessun ordine con quell'id",
                     content = @Content)   // 404 senza corpo: nessuno schema da mostrare
    })
    public ResponseEntity<OrdineDTO> uno(
            @Parameter(description = "Id dell'ordine", example = "7")
            @PathVariable Long id) {
        return service.trova(id).map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
```

```java
// demo/common-dto/src/main/java/.../OrdineDTO.java
import io.swagger.v3.oas.annotations.media.Schema;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Un ordine di magazzino")
public class OrdineDTO {

    @Schema(description = "Assegnato dal servizio", example = "7",
            accessMode = Schema.AccessMode.READ_ONLY)
    private Long id;

    @Schema(description = "Ragione sociale del cliente", example = "Rossi S.r.l.")
    private String cliente;

    @Schema(description = "Pezzi ordinati", example = "3")
    private int quantita;
}
```

Titolo e versione dell'API, se non vuoi che la pagina si chiami "OpenAPI
definition" — una classe di configurazione, nello stesso servizio:

```java
// demo/ordini-service/src/main/java/.../OpenApiConfig.java
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI openApi() {
        return new OpenAPI().info(new Info()
                .title("Ordini Service")
                .version("1.0")
                .description("API degli ordini — prova finale"));
    }
}
```

> `@Tag` di Swagger è `io.swagger.v3.oas.annotations.tags.Tag`: se l'IDE
> importa `org.junit.jupiter.api.Tag`, il progetto non compila e l'errore parla
> di tutt'altro. Nel template la dipendenza c'è già in ogni modulo generato;
> altrimenti `task enable-swagger SERVICE=<modulo>`.

---

### 6.3 Spring Cloud (Eureka & OpenFeign)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@EnableEurekaServer` | Classe Main | Trasforma l'applicazione Spring Boot nel Server Eureka per il Service Discovery. |
| `@EnableDiscoveryClient` | Classe Main | Abilita l'applicazione client a registrarsi presso il registro Eureka Naming Server. |
| `@EnableFeignClients` | Classe Main / Config | Attiva la scansione e la generazione automatica delle interfacce OpenFeign. |
| `@FeignClient(name = "ORDINI-SERVICE")` | Interfaccia Java | Dichiara un client REST dichiarativo. Spring imposta automaticamente il bilanciamento del carico verso il servizio registrato su Eureka con quel nome logico. |

#### Esempio completo — il server, il client, e la chiamata

Tre moduli diversi. **Il server** (`naming-server`) è già nel template e non lo
tocchi quasi mai:

```java
// demo/naming-server/src/main/java/.../Main.java
package esame.namingserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;

@EnableEurekaServer          // questa applicazione E' il registro
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
```

```yaml
# demo/naming-server/src/main/resources/application.yml
server:
  port: ${SERVER_PORT:8761}
eureka:
  client:
    register-with-eureka: false   # il registro non si registra su se stesso
    fetch-registry: false
```

**Chi chiama** (una UI, o un servizio che ne consuma un altro): l'annotazione
sulla `Main` e un'interfaccia. Nei moduli creati da `task new-service` la
`Main` è già così:

```java
// demo/ordini-ui/src/main/java/.../Main.java
@EnableDiscoveryClient       // mi registro su Eureka
@EnableFeignClients          // cerca le interfacce @FeignClient e le implementa
@SpringBootApplication
public class Main {
    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
```

```java
// demo/ordini-ui/src/main/java/.../OrdiniClient.java
package esame.ordiniui;

import esame.common.dto.OrdineDTO;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// "ORDINI-SERVICE" e' lo spring.application.name dell'altro modulo,
// non un indirizzo: host e porta li chiede a Eureka.
@FeignClient(name = "ORDINI-SERVICE")
public interface OrdiniClient {

    @GetMapping("/api/ordini")
    List<OrdineDTO> tutti();

    @GetMapping("/api/ordini/{id}")
    OrdineDTO uno(@PathVariable("id") Long id);

    @GetMapping("/api/ordini")
    List<OrdineDTO> perCliente(@RequestParam("cliente") String cliente);

    @PostMapping("/api/ordini")
    OrdineDTO crea(@RequestBody OrdineDTO nuovo);
}
```

Usarla è come chiamare un metodo normale — l'HTTP è nascosto:

```java
// demo/ordini-ui/src/main/java/.../OrdineFacade.java
@Service
@RequiredArgsConstructor
@Slf4j
public class OrdineFacade {

    private final OrdiniClient ordiniClient;

    public List<OrdineDTO> elenco() {
        try {
            return ordiniClient.tutti();
        } catch (Exception e) {
            // Se il servizio e' spento, la UI resta in piedi con l'elenco vuoto:
            // e' la "resilienza" che la commissione chiede spesso di mostrare.
            log.warn("ORDINI-SERVICE non risponde: {}", e.getMessage());
            return List.of();
        }
    }
}
```

> Nel `@FeignClient` i `@PathVariable` e i `@RequestParam` **devono avere il
> nome scritto** (`@PathVariable("id")`): in un'interfaccia i nomi dei
> parametri non sopravvivono alla compilazione, e senza quella stringa parte un
> errore poco leggibile all'avvio.
>
> E ricorda che il registro non è immediato: un client appena avviato non ha
> ancora la lista delle istanze, e la primissima chiamata può fallire anche se
> è tutto a posto (vedi 5.3: nei moduli generati bastano pochi secondi).

---

### 6.4 Spring Data JPA & Hibernate

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@Entity` | Classe Modello | Dichiara che la classe Java è una tabella del database gestita da JPA/Hibernate. |
| `@Table(name = "nome_tabella")` | Classe Entity | Mappa il nome esatto della tabella SQL sul DB relazionale. |
| `@Id` | Campo Entity | Mappa la Chiave Primaria (Primary Key) della tabella. |
| `@GeneratedValue(strategy = GenerationType.IDENTITY)` | Campo Id | Imposta l'incremento automatico del valore dell'ID a livello DB (`AUTO_INCREMENT` / `SERIAL`). |
| `@Column(name = "...", nullable = false)` | Campo Entity | Mappa il nome della colonna SQL e vincoli di nullabilità o lunghezza. |
| `@Enumerated(EnumType.STRING)` | Campo Enum | Memorizza un valore `enum` Java nel database come stringa di testo anziché come numero indice. |
| `@Transient` | Campo Entity | Indica a JPA di ignorare il campo (non verrà creata alcuna colonna sul DB). |
| `@ManyToOne` / `@OneToMany` | Campo Entity | Definisce le relazioni tra tabelle (Molti-a-Uno, Uno-a-Molti) con gestione delle Foreign Key. |
| `JpaRepository<Entity, IdType>` | Interfaccia Repo | Interfaccia Spring Data che fornisce gratuitamente tutti i metodi CRUD (`save`, `findById`, `findAll`, `deleteById`). |

#### Esempio completo — entity, repository, service, dati di prova

Tutto dentro **il servizio che possiede quei dati**: le `@Entity` non si
condividono e non vanno in `common-dto`.

```java
// demo/ordini-service/src/main/java/.../persistence/OrdineEntity.java
package esame.ordiniservice.persistence;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "ordini")
@Getter @Setter          // su una @Entity meglio questi che @Data (vedi 6.5)
@NoArgsConstructor       // richiesto da JPA
@AllArgsConstructor
public class OrdineEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "cliente", nullable = false, length = 120)
    private String cliente;

    @Column(nullable = false)
    private int quantita;

    @Enumerated(EnumType.STRING)     // salva "IN_CORSO", non 0
    @Column(nullable = false)
    private StatoOrdine stato;

    private LocalDate consegna;

    @Transient                       // calcolato, non salvato
    private boolean urgente;

    // Molti ordini appartengono a un magazzino: la FK sta qui.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "magazzino_id")
    private MagazzinoEntity magazzino;
}
```

```java
// demo/ordini-service/src/main/java/.../persistence/OrdineRepository.java
package esame.ordiniservice.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

// save, findById, findAll, deleteById, count... arrivano gratis.
public interface OrdineRepository extends JpaRepository<OrdineEntity, Long> {

    // Query derivate dal nome del metodo: Spring le traduce in SQL da sola.
    List<OrdineEntity> findByCliente(String cliente);
    List<OrdineEntity> findByQuantitaGreaterThanOrderByQuantitaDesc(int soglia);
    boolean existsByCliente(String cliente);

    // Quando il nome non basta, JPQL (sulle CLASSI, non sulle tabelle):
    @Query("SELECT o FROM OrdineEntity o WHERE o.stato = :stato AND o.quantita >= :min")
    List<OrdineEntity> daEvadere(@Param("stato") StatoOrdine stato, @Param("min") int min);
}
```

```java
// demo/ordini-service/src/main/java/.../OrdineService.java
package esame.ordiniservice;

import esame.common.dto.OrdineDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class OrdineService {

    private final OrdineRepository repository;

    public List<OrdineDTO> tutti() {
        return repository.findAll().stream().map(this::toDto).toList();
    }

    public Optional<OrdineDTO> trova(Long id) {
        return repository.findById(id).map(this::toDto);
    }

    @Transactional                       // scrittura: tutto o niente
    public OrdineDTO salva(OrdineDTO dto) {
        OrdineEntity entity = new OrdineEntity();
        entity.setCliente(dto.getCliente());
        entity.setQuantita(dto.getQuantita());
        entity.setStato(StatoOrdine.IN_CORSO);
        return toDto(repository.save(entity));   // save() torna l'entity con l'id
    }

    // L'@Entity resta dentro il servizio, fuori esce il DTO condiviso.
    private OrdineDTO toDto(OrdineEntity e) {
        return new OrdineDTO(e.getId(), e.getCliente(), e.getQuantita());
    }
}
```

I **dati di prova** valgono punti nella griglia d'esame ("dati di test"). Il
modo più corto è un `CommandLineRunner`, che gira all'avvio:

```java
// demo/ordini-service/src/main/java/.../DatiDiProva.java
@Configuration
@RequiredArgsConstructor
public class DatiDiProva {

    @Bean
    CommandLineRunner inizializza(OrdineRepository repository) {
        return args -> {
            if (repository.count() > 0) return;   // solo su database vuoto
            repository.save(new OrdineEntity(null, "Rossi S.r.l.", 3, StatoOrdine.IN_CORSO, null, false, null));
            repository.save(new OrdineEntity(null, "Bianchi SPA", 12, StatoOrdine.EVASO, null, false, null));
        };
    }
}
```

In alternativa, un `demo/ordini-service/src/main/resources/data.sql` con degli
`INSERT`: Spring Boot lo esegue da solo dopo che Hibernate ha creato le tabelle.

> Con H2 in memoria le tabelle nascono e muoiono a ogni riavvio, quindi i dati
> di prova si ricreano sempre. Passando a PostgreSQL
> (`task use-postgres SERVICE=ordini-service`) restano: per questo il
> `CommandLineRunner` qui sopra controlla `count() > 0` prima di inserire.

---

### 6.5 Lombok (Riduzione del Codice Boilerplate)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@Data` | Classe DTO / Entity | Genera automaticamente Getters, Setters, `equals()`, `hashCode()` e `toString()`. |
| `@Getter` / `@Setter` | Campo / Classe | Genera i metodi di lettura e scrittura per le proprietà della classe. |
| `@NoArgsConstructor` | Classe | Genera il costruttore pubblico senza argomenti (richiesto obbligatoriamente da JPA/Jackson). |
| `@AllArgsConstructor` | Classe | Genera il costruttore completo con tutti i campi della classe. |
| `@RequiredArgsConstructor` | Classe | Genera un costruttore contenente solo i campi dichiarati `private final` (usato per l'Iniezione delle Dipendenze pulita). |
| `@Builder` | Classe | Pattern Builder per la creazione fluida degli oggetti (es. `Prodotto.builder().nome("X").build()`). |
| `@Slf4j` | Classe | Inietta un logger SLF4J denominato `log` per stampare log nel codice (`log.info(...)`, `log.error(...)`). |

#### Esempio completo — un DTO e un service, prima e dopo

Il DTO sta in **common-dto**, il service nel **modulo che lo usa**.

```java
// demo/common-dto/src/main/java/.../OrdineDTO.java
package esame.common.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data                  // getter, setter, equals, hashCode, toString
@Builder               // OrdineDTO.builder().cliente("Rossi").build()
@NoArgsConstructor     // serve a Jackson per ricostruire l'oggetto dal JSON
@AllArgsConstructor    // serve al @Builder e ai costruttori a mano
public class OrdineDTO {
    private Long id;
    private String cliente;
    private int quantita;
}
```

Le stesse tre righe, senza Lombok, sarebbero una sessantina: due costruttori,
sei fra getter e setter, `equals`, `hashCode` e `toString`.

```java
// demo/ordini-service/src/main/java/.../OrdineService.java
package esame.ordiniservice;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor   // costruttore con i soli campi final: niente @Autowired
@Slf4j                     // mette a disposizione "log"
public class OrdineService {

    private final OrdineRepository repository;   // final = iniettato
    private final ProdottiClient prodottiClient;

    public OrdineDTO salva(OrdineDTO dto) {
        log.info("Nuovo ordine per {}, {} pezzi", dto.getCliente(), dto.getQuantita());
        ...
    }
}
```

Uso del builder, comodo quando i campi sono tanti e non vuoi ricordarne
l'ordine:

```java
OrdineDTO dto = OrdineDTO.builder()
        .cliente("Rossi S.r.l.")
        .quantita(3)
        .build();          // gli altri campi restano a null / 0
```

> **Su una `@Entity` non mettere `@Data`.** Genera `equals` e `hashCode` su
> tutti i campi, relazioni comprese: con un `@ManyToOne` Hibernate finisce per
> caricare mezzo database (o cicla all'infinito) solo per confrontare due
> oggetti. Su un'entity: `@Getter @Setter @NoArgsConstructor`, e se ti serve
> `equals` scrivilo sull'id.
>
> Se i getter "non esistono" in compilazione, il processore di annotazioni non
> sta girando: in VS Code serve l'estensione Lombok, e in ogni caso `task
> compile` da terminale compila lo stesso, perché Maven ce l'ha configurato.

---

### 6.6 Jakarta Validation (`jakarta.validation.constraints`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@NotNull` | Campo DTO | Il valore non può essere `null`. |
| `@NotBlank` | Campo Stringa | La stringa non può essere `null`, vuota `""` o contenere solo spazi bianchi `" "`. |
| `@NotEmpty` | Campo Collection/String | La collezione o stringa non deve essere vuota. |
| `@Min(valore)` / `@Max(valore)` | Campo Numerico | Imposta i limiti numerici minimo e massimo ammessi. |
| `@Size(min = X, max = Y)` | Campo String/Collection | Controlla la lunghezza minima e massima di caratteri o elementi. |

#### Esempio completo — vincoli sul DTO, controllo nel controller, errore leggibile

I vincoli stanno sul DTO (**common-dto**), il `@Valid` nel controller del
**servizio**, e il gestore degli errori nello stesso servizio.

```java
// demo/common-dto/src/main/java/.../OrdineDTO.java
package esame.common.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrdineDTO {

    private Long id;    // lo assegna il servizio: nessun vincolo

    @NotBlank(message = "il cliente e' obbligatorio")
    @Size(max = 120, message = "il nome del cliente supera i 120 caratteri")
    private String cliente;

    @Min(value = 1, message = "la quantita' deve essere almeno 1")
    private int quantita;
}
```

```java
// nel controller del servizio: @Valid fa scattare i vincoli
@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public OrdineDTO crea(@Valid @RequestBody OrdineDTO nuovo) {
    return service.salva(nuovo);
}
```

Senza altro, una richiesta non valida torna **400** con un corpo lungo e poco
leggibile. Una classe sola lo trasforma in un messaggio pulito — e fa una bella
figura in Swagger:

```java
// demo/ordini-service/src/main/java/.../GestioneErrori.java
package esame.ordiniservice;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice          // vale per tutti i controller del modulo
public class GestioneErrori {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)     // 400
    public Map<String, String> vincoliViolati(MethodArgumentNotValidException e) {
        Map<String, String> errori = new HashMap<>();
        e.getBindingResult().getFieldErrors()
                .forEach(err -> errori.put(err.getField(), err.getDefaultMessage()));
        return errori;   // {"cliente": "il cliente e' obbligatorio"}
    }
}
```

Nella UI Thymeleaf i vincoli si controllano con `@Valid` + `BindingResult`, e
il messaggio si mostra accanto al campo:

```java
@PostMapping("/ordini")
public String crea(@Valid @ModelAttribute("nuovo") OrdineDTO nuovo,
                   BindingResult errori,          // DEVE stare subito dopo l'oggetto
                   Model model) {
    if (errori.hasErrors()) {
        model.addAttribute("ordini", ordiniClient.tutti());
        return "ordini";      // torna al form, coi messaggi
    }
    ordiniClient.crea(nuovo);
    return "redirect:/";
}
```

```html
<input type="text" th:field="*{cliente}">
<span th:if="${#fields.hasErrors('cliente')}" th:errors="*{cliente}"></span>
```

> `@Valid` senza la dipendenza `validation` nel pom non fa niente, in silenzio:
> l'annotazione compila e i vincoli non scattano. `task add-dep
> SERVICE=<modulo> DEPS=validation` (nei moduli generati c'è già).
>
> E `BindingResult` va **subito dopo** l'oggetto annotato con `@Valid`: se ci
> metti un altro parametro in mezzo, Spring lancia l'eccezione invece di
> passarti gli errori.

---

### 6.7 Thymeleaf: il cheat sheet delle pagine

Thymeleaf è il motore delle pagine della UI (`<nome>-ui`, quella che crei con
`task new-service NAME=ordini-ui UI=1`). Un template è HTML normale, che si
apre anche nel browser come file; gli attributi `th:*` dicono a Thymeleaf cosa
sostituire con i dati che il controller ha messo nel `Model`.

Tutto quello che c'è qui sotto è stato provato su questo template (Spring Boot
4.0.5, Thymeleaf 3.1): gli esempi sono copiati da pagine che girano, e dove
Thymeleaf si comporta in modo inatteso c'è scritto.

#### Come si aggancia a Spring Boot

| Cosa | Dove / come |
| :--- | :--- |
| La libreria | `spring-boot-starter-thymeleaf` nel pom del modulo UI (la mette `new-service ... UI=1`). Nient'altro da configurare. |
| Le pagine | `src/main/resources/templates/`. Il controller restituisce il percorso da lì, **senza** `.html` e **senza** barra iniziale: `return "ordini/elenco";` apre `templates/ordini/elenco.html`. |
| CSS, JS, immagini | `src/main/resources/static/`: `static/css/app.css` si carica come `/css/app.css`. |
| I testi | `src/main/resources/messages.properties`, letto da solo: `#{chiave}` nelle pagine. |
| Le pagine d'errore | `templates/error/404.html`, `error/500.html` (o `error.html` per tutte): Spring Boot le usa da solo, con `${status}`, `${error}`, `${path}`. |
| La cache | Con devtools (ereditato dal pom padre) è già spenta: dopo `task compile` la pagina nuova si vede col refresh. |

Il giro di una pagina:

```text
browser  GET /ordini?q=ros
   │
   ▼
@Controller  @GetMapping("/ordini")        prende i dati (dal Feign client)
   │         model.addAttribute("ordini", ...)
   │         return "ordini/elenco";
   ▼
Thymeleaf   templates/ordini/elenco.html   sostituisce i th:* con i dati del Model
   │
   ▼
browser     riceve HTML normale: di Thymeleaf non resta traccia
```

#### Le cinque espressioni

| Sintassi | Cosa legge | Esempio | Risultato |
| :--- | :--- | :--- | :--- |
| `${...}` | una variabile del `Model` (dentro c'è SpEL) | `${ordine.cliente}` | chiama `getCliente()`, o `cliente()` se è un record |
| `*{...}` | un campo dell'oggetto scelto con `th:object` | `<div th:object="${ordine}">` … `*{cliente}` | come `${ordine.cliente}`, più corto |
| `@{...}` | un link, con parametri già codificati | `@{/ordini/{id}(id=${o.id})}` | `/ordini/2` |
| | | `@{/ordini(q=${q}, pagina=2)}` | `/ordini?q=ros&pagina=2` |
| `#{...}` | un testo di `messages.properties` | `#{ordini.titolo}` | `Ordini in corso` |
| | | `#{ordini.saluto('Rossi', 3)}` con `ordini.saluto=Ciao {0}, hai {1} ordini` | `Ciao Rossi, hai 3 ordini` |
| `~{...}` | un frammento di un altro template | `~{fragments/layout :: menu}` | il `<nav>` del layout |

#### Gli attributi

| Attributo | Cosa fa | Esempio |
| :--- | :--- | :--- |
| `th:text` | sostituisce il contenuto del tag; l'HTML nei dati viene **escapato** (`<b>` diventa testo) | `<td th:text="${o.cliente}">Rossi</td>` |
| `th:utext` | come `th:text` ma **senza** escape: l'HTML passa com'è. Mai con testo scritto dagli utenti | `<p th:utext="${avviso}"></p>` |
| `th:each` | ripete il tag per ogni elemento | `<tr th:each="o, st : ${ordini}">` |
| `th:if` / `th:unless` | tiene il tag se la condizione è vera / falsa (vedi sotto cosa conta come vero) | `<p th:if="${#lists.isEmpty(ordini)}">Nessun ordine.</p>` |
| `th:switch` / `th:case` | uno fra tanti; `th:case="*"` è il resto | `<td th:switch="${o.stato.name()}"><span th:case="'NUOVO'">…` |
| `th:href` `th:src` `th:action` | link, immagini, destinazione dei form: sempre con `@{...}` | `<form th:action="@{/ordini}" method="post">` |
| `th:object` | sceglie l'oggetto per le `*{...}` (un form, o un blocco di pagina) | `<form th:object="${ordine}">` |
| `th:field` | lega un campo del form all'oggetto: scrive `id`, `name` e `value` (e `selected`/`checked`); alla POST Spring rimette il valore nell'oggetto | `<input type="text" th:field="*{cliente}">` |
| `th:errors` | i messaggi di validazione di un campo; se non ci sono errori il tag sparisce | `<span th:errors="*{cliente}"></span>` |
| `th:errorclass` | aggiunge una classe CSS al campo solo quando è sbagliato | `<input th:field="*{cliente}" th:errorclass="campo-errato">` |
| `th:value` | solo il `value`, senza legare niente (per un campo fuori da `th:object`) | `<input name="q" th:value="${q}">` |
| `th:classappend` | aggiunge una classe a quelle che il tag ha già | `<tr th:classappend="${o.urgente} ? 'urgente'">` |
| `th:disabled` `th:checked` `th:selected` `th:readonly` | attributi booleani: presenti se vero, spariscono se falso | `th:disabled="*{stato.name() == 'CONSEGNATO'}"` |
| `th:data-*` (e qualsiasi `th:<attributo>`) | scrive l'attributo con quel nome | `<button th:data-id="*{id}">` → `data-id="2"` |
| `th:with` | una variabile locale al tag | `<p th:with="totale=*{quantita * prezzo}">` |
| `th:fragment` | dà un nome a un pezzo di pagina, anche con parametri | `<head th:fragment="head(titolo)">` |
| `th:replace` / `th:insert` | mette il frammento **al posto** del tag / **dentro** il tag | `<nav th:replace="~{fragments/layout :: menu}"></nav>` |
| `th:block` | un contenitore che non finisce nell'HTML: per ripetere più tag insieme | `<th:block th:each="o : ${ordini}">…</th:block>` |
| `th:remove="all"` | toglie il tag: righe finte che servono solo aprendo il file nel browser | `<tr th:remove="all"><td>Riga finta</td></tr>` |
| `th:inline="javascript"` | dati Java dentro uno `<script>`, già trasformati in JSON | `const ordini = /*[[${ordini}]]*/ [];` |
| `[[...]]` / `[(...)]` | un'espressione dentro il testo, con / senza escape | `<p>Ciao [[${nome}]]</p>` |

#### Operatori e scorciatoie

| Cosa | Come si scrive | Nota |
| :--- | :--- | :--- |
| Concatenare | `${o.quantita} + ' pezzi'` | |
| Sostituzione letterale | `\|Ordine n. ${o.id}\|` | fra due barre verticali: più leggibile del `+` |
| Condizione | `${o.urgente} ? 'sì' : 'no'` | senza la parte `: …`, se è falso non scrive niente: comodo con `th:classappend` |
| Valore di riserva (Elvis) | `${o.note} ?: 'nessuna'` | scatta solo con `null`: una stringa vuota resta vuota |
| Navigazione sicura | `${o.note?.toUpperCase()}` | se `note` è `null` non esplode, scrive vuoto |
| Confronti | `gt` `lt` `ge` `le` `eq` `ne` (oppure `>` `<` `>=` `<=` `==` `!=`) | dentro un attributo HTML il `<` può rompere il tag: usa `lt` |
| Logici | `and` `or` `not` | |
| Metodi | `${o.stato.name()}`, `${ordini.size()}` | SpEL chiama qualsiasi metodo pubblico |
| Classi ed enum | `${T(esame.common.dto.Stato).values()}` | funziona, ma un `@ModelAttribute` nel controller è più leggibile |
| Bean di Spring | `${@environment.getProperty('spring.application.name')}` | `@nomeDelBean` |
| Proiezione | `${ordini.![quantita]}` | la lista dei soli `quantita`: si passa a `#aggregates` e `#lists` |
| Parametri della richiesta | `${param.q}` per scriverlo, `${param.q[0]}` per confrontarlo | `param.q` è l'elenco dei valori di `?q=`; meglio ancora: rimettilo nel `Model` |
| Sessione | `${session.utente}` | gli attributi messi con `session.setAttribute(...)` |

#### Gli oggetti di utilità (`#...`)

| Oggetto | Esempio | Risultato |
| :--- | :--- | :--- |
| `#strings` | `${#strings.abbreviate(o.note, 20)}` | `Consegnare al por...` |
| | `isEmpty(s)`, `toUpperCase(s)`, `contains(s, 'x')`, `replace(s, '-', '+')`, `substring(s, 1, 3)` | |
| `#numbers` | `${#numbers.formatDecimal(o.prezzo, 1, 'POINT', 2, 'COMMA')}` | `1.234,50` |
| | `${#numbers.formatDecimal(x, 1, 2)}` | due decimali, separatore della lingua del browser |
| | `${#numbers.formatInteger(1234567, 1, 'POINT')}` | `1.234.567` |
| `#temporals` | `${#temporals.format(o.consegna, 'dd/MM/yyyy')}` | `20/09/2026` (per `LocalDate`, `LocalDateTime`) |
| | `#temporals.createToday()`, `#temporals.day(data)` | |
| `#dates` | `${#dates.format(data, 'dd/MM/yyyy')}` | lo stesso, per il vecchio `java.util.Date` |
| `#lists` | `isEmpty(l)`, `size(l)`, `contains(l, x)`, `sort(l)` | |
| `#aggregates` | `${#aggregates.sum(ordini.![quantita])}`, `avg(...)` | su una lista **vuota** restituisce `null`: usalo dentro un `th:unless="${#lists.isEmpty(...)}"` |
| `#fields` | `${#fields.hasErrors('cliente')}`, `${#fields.hasAnyErrors()}` | solo dentro un `th:object` |
| `#objects` | `${#objects.nullSafe(x, 'riserva')}` | come Elvis |

#### Il ciclo: la variabile di stato

`th:each="o, st : ${ordini}"` dà, oltre all'elemento `o`, lo stato `st` (se
non lo dichiari si chiama `oStat` da solo):

| `st.` | Valore |
| :--- | :--- |
| `index` | posizione contando da 0 |
| `count` | posizione contando da 1 |
| `size` | quanti sono in tutto |
| `first` / `last` | è il primo / l'ultimo |
| `even` / `odd` | pari / dispari, contando da 1 |
| `current` | l'elemento corrente |

#### Cosa conta come vero in `th:if`

| Valore | `th:if` |
| :--- | :--- |
| `null` | falso |
| `false`, e le stringhe `"false"`, `"off"`, `"no"` | falso |
| il numero `0` | falso |
| una stringa vuota `""` | **vero** |
| una lista vuota | **vero** |
| qualsiasi altra cosa | vero |

Quindi `th:if="${ordini}"` è sempre vero, anche senza ordini: per le liste si
scrive `th:if="${#lists.isEmpty(ordini)}"`, per le stringhe
`th:unless="${#strings.isEmpty(s)}"`.

#### Esempio completo — elenco, dettaglio e form con validazione

Tutto nel modulo **UI** (`ordini-ui`). I dati arrivano da `ordini-service`
attraverso il `@FeignClient` `OrdiniClient` (vedi 6.3); qui conta cosa succede
fra controller e pagine.

```java
// demo/ordini-ui/src/main/java/.../OrdineForm.java
// L'oggetto del form: un campo per ogni <input>, coi vincoli di validazione.
package esame.ordiniui;

import esame.common.dto.Stato;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;

@Data                                   // getter e setter: th:field li usa entrambi
public class OrdineForm {

    @NotBlank(message = "Il cliente è obbligatorio")
    private String cliente;

    @NotNull(message = "Quanti pezzi?")
    @Min(value = 1, message = "Almeno un pezzo")
    private Integer quantita;

    private Stato stato = Stato.NUOVO;  // il valore iniziale della <select>
    private boolean urgente;            // una checkbox

    // <input type="date"> manda 2026-10-01: senza questa riga Spring non sa leggerla.
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate consegna;
}
```

> Anche un **record** va bene come oggetto del form: `th:field` lo legge e alla
> POST Spring lo costruisce col costruttore (provato con testo e numeri). Così
> puoi usare direttamente il DTO di `common-dto`, per esempio
> `new OrdineDTO(null, null)` nel metodo GET.

```java
// demo/ordini-ui/src/main/java/.../OrdiniWebController.java
package esame.ordiniui;

import esame.common.dto.Stato;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller                        // pagine, non JSON: niente @RestController qui
@RequestMapping("/ordini")
@RequiredArgsConstructor
public class OrdiniWebController {

    private final OrdiniClient ordini;   // il @FeignClient verso ordini-service

    // Un metodo @ModelAttribute gira prima di ogni pagina di questo controller:
    // la <select> degli stati ce l'ha sempre, anche quando il form torna con errori.
    @ModelAttribute("stati")
    public Stato[] stati() {
        return Stato.values();
    }

    // GET /ordini  e  GET /ordini?q=ros
    @GetMapping
    public String elenco(@RequestParam(required = false) String q, Model model) {
        model.addAttribute("ordini", ordini.cerca(q));
        model.addAttribute("q", q);             // per rimetterlo nella casella di ricerca
        return "ordini/elenco";                 // templates/ordini/elenco.html
    }

    // GET /ordini/2
    @GetMapping("/{id}")
    public String dettaglio(@PathVariable Long id, Model model) {
        model.addAttribute("ordine", ordini.uno(id));
        return "ordini/dettaglio";
    }

    // Il form parte da un oggetto vuoto: senza, th:object non ha niente da
    // legare e la pagina va in errore.
    @GetMapping("/nuovo")
    public String nuovo(Model model) {
        model.addAttribute("ordine", new OrdineForm());
        return "ordini/form";
    }

    @PostMapping
    public String salva(@Valid @ModelAttribute("ordine") OrdineForm ordine,
                        BindingResult errori,        // SUBITO dopo l'oggetto validato
                        RedirectAttributes redirect) {
        if (errori.hasErrors()) {
            return "ordini/form";    // la stessa pagina: i dati inseriti e gli errori restano
        }
        ordini.crea(ordine);
        // Un attributo "flash" sopravvive al redirect e sparisce alla pagina dopo.
        redirect.addFlashAttribute("messaggio", "Ordine salvato");
        return "redirect:/ordini";   // dopo una POST: il refresh non rimanda il form
    }

    // I form HTML conoscono solo GET e POST: si cancella con una POST, e la
    // DELETE vera la fa il Feign client verso il servizio.
    @PostMapping("/{id}/elimina")
    public String elimina(@PathVariable Long id, RedirectAttributes redirect) {
        ordini.elimina(id);
        redirect.addFlashAttribute("messaggio", "Ordine eliminato");
        return "redirect:/ordini";
    }
}
```

I pezzi comuni a tutte le pagine stanno in un file di frammenti:

```html
<!-- demo/ordini-ui/src/main/resources/templates/fragments/layout.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:fragment="head(titolo)">
    <meta charset="UTF-8">
    <title th:text="${titolo}">Titolo</title>
    <link rel="stylesheet" th:href="@{/css/app.css}">
</head>
<body>
    <nav th:fragment="menu">
        <a th:href="@{/ordini}">Ordini</a> |
        <a th:href="@{/ordini/nuovo}">Nuovo ordine</a>
    </nav>

    <!-- Il messaggio flash: c'è solo subito dopo un redirect. -->
    <p th:fragment="flash" th:if="${messaggio}" class="flash" th:text="${messaggio}">Salvato</p>
</body>
</html>
```

L'elenco, con ricerca, tabella, formati e cancellazione:

```html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/elenco.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Ordini')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>
    <p th:replace="~{fragments/layout :: flash}"></p>

    <h1 th:text="#{ordini.titolo}">Ordini</h1>

    <!-- GET: i campi finiscono nella query, ?q=... -->
    <form th:action="@{/ordini}" method="get">
        <input type="text" name="q" th:value="${q}" placeholder="Cliente">
        <button type="submit">Cerca</button>
    </form>

    <p th:if="${#lists.isEmpty(ordini)}">Nessun ordine.</p>

    <table th:unless="${#lists.isEmpty(ordini)}">
        <tr>
            <th>#</th><th>Cliente</th><th>Pezzi</th><th>Stato</th><th>Consegna</th><th>Prezzo</th><th></th>
        </tr>
        <tr th:each="o, st : ${ordini}" th:classappend="${o.urgente} ? 'urgente'">
            <td th:text="${st.count}">1</td>
            <td><a th:href="@{/ordini/{id}(id=${o.id})}" th:text="${o.cliente}">Rossi</a></td>
            <td th:text="${o.quantita}">3</td>
            <td th:switch="${o.stato.name()}">
                <span th:case="'NUOVO'">da spedire</span>
                <span th:case="'SPEDITO'">in viaggio</span>
                <span th:case="*" th:text="${o.stato}">altro</span>
            </td>
            <td th:text="${o.consegna != null} ? ${#temporals.format(o.consegna, 'dd/MM/yyyy')} : '-'">20/09/2026</td>
            <td th:text="${#numbers.formatDecimal(o.prezzo, 1, 'POINT', 2, 'COMMA')} + ' €'">12,50 €</td>
            <td>
                <form th:action="@{/ordini/{id}/elimina(id=${o.id})}" method="post"
                      onsubmit="return confirm('Eliminare l\'ordine?')">
                    <button type="submit">Elimina</button>
                </form>
            </td>
        </tr>
        <tr th:remove="all"><td>2</td><td>Riga finta, solo per l'anteprima</td></tr>
    </table>

    <p th:unless="${#lists.isEmpty(ordini)}"
       th:text="|Ordini: ${#lists.size(ordini)}, pezzi in tutto: ${#aggregates.sum(ordini.![quantita])}|">Totale</p>
</body>
</html>
```

Il dettaglio, con `th:object` e le espressioni `*{...}`:

```html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/dettaglio.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Dettaglio ordine')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>

    <div th:object="${ordine}">
        <h1 th:text="|Ordine n. *{id}|">Ordine n. 1</h1>
        <p>Cliente: <strong th:text="*{cliente}">Rossi</strong></p>
        <p th:with="totale=*{quantita * prezzo}">
            Totale: <span th:text="${#numbers.formatDecimal(totale, 1, 2)}">37,50</span>
        </p>
        <p th:if="*{urgente}" class="urgente">Urgente!</p>
        <p>Note: <span th:text="*{note} ?: 'nessuna'">nessuna</span></p>
        <button type="button" th:data-id="*{id}"
                th:disabled="*{stato.name() == 'CONSEGNATO'}">Spedisci</button>
    </div>
</body>
</html>
```

Il form, che serve sia la prima volta sia quando torna con gli errori:

```html
<!-- demo/ordini-ui/src/main/resources/templates/ordini/form.html -->
<!DOCTYPE html>
<html xmlns:th="http://www.thymeleaf.org" lang="it">
<head th:replace="~{fragments/layout :: head(titolo='Nuovo ordine')}"></head>
<body>
    <nav th:replace="~{fragments/layout :: menu}"></nav>

    <form th:action="@{/ordini}" th:object="${ordine}" method="post">
        <p th:if="${#fields.hasAnyErrors()}" class="errore">Correggi i campi segnati.</p>

        <label>Cliente
            <input type="text" th:field="*{cliente}" th:errorclass="campo-errato">
        </label>
        <span class="errore" th:if="${#fields.hasErrors('cliente')}" th:errors="*{cliente}">obbligatorio</span>

        <label>Pezzi <input type="number" th:field="*{quantita}"></label>
        <span class="errore" th:errors="*{quantita}"></span>

        <label>Stato
            <select th:field="*{stato}">
                <option th:each="s : ${stati}" th:value="${s}" th:text="${s}">NUOVO</option>
            </select>
        </label>

        <label><input type="checkbox" th:field="*{urgente}"> Urgente</label>

        <label>Consegna <input type="date" th:field="*{consegna}"></label>

        <button type="submit">Salva</button>
    </form>
</body>
</html>
```

```properties
# demo/ordini-ui/src/main/resources/messages.properties
ordini.titolo=Ordini in corso
ordini.saluto=Ciao {0}, hai {1} ordini
```

Cosa esce, per capire cosa fa ogni pezzo:

- `th:field="*{cliente}"` diventa `<input type="text" id="cliente" name="cliente" value="">`;
  dopo una POST con errori, `value` è quello scritto dall'utente e la classe
  `campo-errato` è aggiunta.
- La `<select>` marca da sola come `selected` l'opzione uguale a `stato`.
- La checkbox diventa `<input type="checkbox" id="urgente1" name="urgente" value="true">`
  più un `<input type="hidden" name="_urgente">`: è quello che fa arrivare
  `false` quando la casella è vuota. Nota l'`id` con l'`1`, se ci attacchi una
  `<label for=...>`.
- `th:errors` scrive il `message` del vincolo (`Il cliente è obbligatorio`);
  senza errori il tag sparisce.
- Il messaggio flash compare alla prima pagina dopo il redirect, e al refresh
  successivo non c'è più.

#### Gli errori che fanno perdere tempo

| Cosa vedi | Perché | Rimedio |
| :--- | :--- | :--- |
| `Neither BindingResult nor plain target object for bean name 'ordine'` | il metodo GET non ha messo l'oggetto del form nel `Model` | `model.addAttribute("ordine", new OrdineForm());` |
| La stessa eccezione (o un 404) solo al primo invio del form, con l'indirizzo che finisce in `;jsessionid=...` | il browser non ha ancora il cookie di sessione: Tomcat mette la sessione nell'URL del redirect, e Spring non lo riconosce più come `/` | nell'`application.yml` della UI: `server.servlet.session.tracking-modes: cookie` (`task new-service UI=1` lo mette già) |
| `Error resolving template [/ordini/elenco]` | barra all'inizio del nome (in IntelliJ va, nel jar e in Docker no), oppure file fuori da `templates/`, oppure nome scritto diverso | `return "ordini/elenco";` e controlla il percorso del file |
| Il browser mostra la scritta `ordini/elenco` | la classe è `@RestController` | `@Controller` |
| Gli errori di validazione non compaiono | manca `@Valid`, o `BindingResult` non è il parametro subito dopo, o dopo gli errori fai `redirect:` | vedi il metodo `salva` qui sopra |
| Il messaggio non arriva dopo il redirect | `model.addAttribute` invece di `redirect.addFlashAttribute` | `RedirectAttributes` |
| `EL1007E: Property or field 'cliente' cannot be found on null` | l'oggetto è `null` | `${ordine?.cliente}`, oppure un `th:if` prima |
| `EL1008E: Property or field 'nome' cannot be found on object of type ...` | il campo si chiama diversamente (in un record: il nome del componente) | guarda la classe o il record |
| `th:if="${lista}"` è vero anche senza elementi | una lista vuota conta come vera | `th:if="${#lists.isEmpty(lista)}"` |
| `pezzi in tutto: null` | `#aggregates.sum` su una lista vuota | dentro un `th:unless="${#lists.isEmpty(...)}"` |
| `Only variable expressions returning numbers or booleans are allowed in this context` | Thymeleaf 3.1 non accetta testo dei dati dentro `th:onclick` e gli altri `th:on*` (per sicurezza) | l'`onclick` scritto normale, e i dati in un `th:data-*` |
| La pagina modificata non cambia | Spring legge i template da `target/classes` | `task compile` |
| Nella pagina d'errore `${message}` è vuoto | Spring Boot nasconde il messaggio delle eccezioni | `server.error.include-message: always` in `application.yml` |
| Il servizio risponde 404 e la UI mostra una pagina 500 | il Feign client trasforma il 404 in `FeignException.NotFound` | `try { … } catch (FeignException.NotFound e) { … }` e mostra un messaggio |

---

## 7. Risoluzione Guidata delle 3 Tracce d'Esame

### Traccia 1: WMS Magazzino ("Spostati S.r.l.")
- **Obiettivo**: Gestione magazzino diviso in armadi (griglia $R \times C$) contenenti ubicazioni con ingombro massimo.
- **Microservizi**:
  1. `EUREKA-SERVER` (Porta 8761)
  2. `PRODUCT-SERVICE` (Porta 8081) - Anagrafica prodotti CRUD + OpenAPI.
  3. `CRM-SERVICE` (Porta 8082) - Mock anagrafica clienti registrato su Eureka.
  4. `WMS-UI-SERVICE` (Porta 8080) - Gestione giacenze e movimentazioni merci.
- **Algoritmo di Ricerca Ubicazione Ottimale Vicina**:
  - *Problema*: Data un'ubicazione sorgente $U_{start}$ (armadio a riga $r_1$, colonna $c_1$) e una quantità $Q$ di un prodotto $P$ per il cliente $C$, trovare l'ubicazione $U_{dest}$ più vicina che abbia capienza libera $S_{libero} \ge Q \times Ingombro(P)$ e contenga lo stesso prodotto/cliente o sia vuota.
  - *Calcolo Distanza*: Distanza di Manhattan tra le coordinate degli armadi:
    $$d(A_1, A_2) = |r_1 - r_2| + |c_1 - c_2|$$
  - *Complessità Temporale*: $O(N_{armadi} \times M_{ubicazioni})$, poiché per ciascun armadio si controllano le ubicazioni disponibili. Se i dati sono mantenuti in strutture in memoria (es. `Map<Coordinate, Armadio>`), la ricerca richiede tempo lineare proporzionale al numero totale di ubicazioni $O(U_{totale})$.

---

### Traccia 2: Catasto Comunale & Incentivi Edilizi
- **Obiettivo**: Informatizzazione bonus ristrutturazioni edilizie con miglioramento classe energetica (A-G).
- **Microservizi**:
  1. `ALIQUOTE-STATALI-SERVICE` (Read-only, lista aliquote per categoria A1, A3, B1).
  2. `CATASTO-NAZIONALE-SERVICE` (Anagrafica particelle edili e proprietari con credito fiscale maturato).
  3. `COMUNE-APP-SERVICE` (UI Web per apertura pratica 6 mesi "IN CORSO" e chiusura pratica "TERMINATA" con aggiornamento classe energetica e accredito fiscale al proprietario).

---

### Traccia 3: Prenotazione Ospedaliera ("Sant'Isidoro")
- **Obiettivo**: Gestione appuntamenti medici e integrazione con il sistema regionale delle prescrizioni.
- **Microservizi**:
  1. `MOCK-REGIONALE-SERVICE` (Read-only prescrizioni mediche).
  2. `AGENDA-OSPEDALE-SERVICE` (Anagrafica medici, orari e disponibilità visite).
  3. `PRENOTAZIONI-UI` (Interfaccia web paziente per scelta data/medico e conferma prenotazione).

---

## 8. Template Standard per l'Allegato Tecnico (8 Punti)

Copia ed adatta questa struttura per il file `ALLEGATO_TECNICO.docx` / `ALLEGATO_TECNICO.pdf` da consegnare:

```markdown
# ALLEGATO TECNICO DI PROGETTO
Candidato: [NOME COGNOME]
Data: [DATA ESAME]

## 1. Analisi del Problema e Contesto Applicativo
[Breve sintesi degli obiettivi di business e dell'architettura a microservizi scelta].

## 2. Schema Concettuale e Logico della Base Dati
- Tabella `prodotti` (id, nome, descrizione, prezzo, ingombro) -> Servizio Product
- Tabella `ubicazioni` (id, armadio_riga, armadio_colonna, ingombro_max, ingombro_occupato, prodotto_id, cliente_id, quantita) -> Servizio WMS

## 3. Descrizione dei Moduli Implementati
- `eureka-server`: Naming Server (Porta 8761)
- `anagrafica-service`: Microservizio REST con OpenAPI (Porta 8081)
- `main-ui-app`: Web Application Thymeleaf/Spring Boot (Porta 8080)

## 4. Descrizione dell'Algoritmo (se richiesto dalla traccia)
[Descrizione dell'algoritmo di ricerca/calcolo con formula matematica e complessità temporale Big-O].

## 5. Istruzioni per il Test della Soluzione
1. Eseguire `task docker-up`
2. Aprire `http://localhost:8761` per verificare la registrazione dei servizi su Eureka.
3. Aprire `http://localhost:8081/swagger-ui.html` per testare gli endpoint REST.
4. Aprire `http://localhost:8080` per utilizzare l'interfaccia utente.
```

---

## 9. Svolgimento Completo delle Domande Teoriche (A e B)

### Domanda Teorica A: Containerizzazione Docker, Compose, Sicurezza e Federazione

#### Part A1: Docker vs Macchine Virtuali (VM) & Docker Compose
- **Architettura Docker vs VM**:
  - Le **Macchine Virtuali (VM)** utilizzano un **Hypervisor** (es. ESXi, VirtualBox) per emulare l'hardware sottostante e richiedono un **Guest OS completo** per ciascuna istanza. Questo comporta un elevato consumo di RAM/CPU, dimensioni delle immagini di diversi GB e tempi di avvio nell'ordine dei minuti.
  - I **Container Docker** condividono il **Kernel del Sistema Operativo Host** e isolano i processi nello spazio utente tramite le funzionalità del kernel Linux (`namespaces` per l'isolamento e `cgroups` per la limitazione delle risorse). Conseguentemente, sono estremamente leggeri (dimensione in MB), si avviano in pochissimi secondi e consumano solo le risorse necessarie ai processi applicativi.
- **Ruolo di Docker Compose**:
  - Docker Compose è uno strumento di orchestrazione multi-container che definisce l'intera infrastruttura in un file descrittore dichiarativo `docker-compose.yml`.
  - Consente di specificare: immagini da compilare/scaricare, variabili d'ambiente, mappatura delle porte, dipendenze di avvio (`depends_on` con `healthcheck`), volumi per la persistenza dei dati e reti virtuali isolate.

#### Part A2: Sicurezza e Federazione dei Servizi
- **Autenticazione e Autorizzazione Centralizzata**:
  - Per rendere sicura la soluzione si introduce un **Identity Provider (IdP)** basato sullo standard **OAuth2 / OpenID Connect (OIDC)** (es. **Keycloak** o **Spring Authorization Server**).
  - Gli utenti (es. personale del comune o operatori) effettuano il login su Keycloak e ricevono un token digitale firmato **JWT (JSON Web Token)** contenente i ruoli dell'utente (es. `ROLE_OPERATORE`, `ROLE_ADMIN`).
- **Federazione e API Gateway**:
  - Si inserisce un **Spring Cloud Gateway** come punto di accesso unico (Single Point of Entry) per tutte le richieste esterne.
  - L'API Gateway intercetta le richieste, valida la firma del token JWT con la chiave pubblica di Keycloak e inoltra le chiamate ai microservizi downstream tramite il registro Eureka.
  - Ciascun microservizio funge da **OAuth2 Resource Server** e verifica i permessi a livello di singolo endpoint utilizzando annotazioni come `@PreAuthorize("hasRole('ROLE_ADMIN')")`.

---

### Domanda Teorica B: DB Relazionali vs NoSQL & Stack JEE vs Spring Boot

#### Part B1: Database Relazionali vs NoSQL & Integrazione Soluzione
- **Differenze Fondamentali**:
  - **Relazionali (SQL)**: Basati sulle proprietà **ACID** (Atomicità, Consistenza, Isolamento, Durabilità). Utilizzano uno schema rigido prefissato e relazioni espresse tramite chiavi esterne. Scalano principalmente in modo **verticale** (hardware più potente).
  - **NoSQL (Document, Key-Value, Column, Graph)**: Basati solitamente sul principio **BASE** (Basically Available, Soft-state, Eventual consistency). Non hanno uno schema fisso (schemaless), gestiscono dati non strutturati o semi-strutturati e scalano in modo **orizzontale** aggiungendo nuovi nodi al cluster.
- **Proposta di Integrazione NoSQL**:
  - **MongoDB (Document Store)**: Utilizzabile nel sistema WMS per memorizzare lo **storico delle movimentazioni merci** o le tracciature degli audit log. La flessibilità del formato JSON/BSON consente di aggiungere campi analitici variabilmente nel tempo senza dover eseguire complesse migrazioni di schema SQL (`ALTER TABLE`).
  - **Redis (Key-Value In-Memory)**: Utilizzabile per la **gestione delle sessioni web** o come **cache ad alte prestazioni** delle interrogazioni più frequenti al catalogo prodotti, riducendo drasticamente il carico sul database relazionale sottostante.

#### Part B2: Confronto Stack JEE Tradizionale vs Spring Boot

| Componente Architetturale | Stack JEE Tradizionale | Stack Spring Boot / Spring Cloud | Ruolo nel Sistema |
| :--- | :--- | :--- | :--- |
| **View (Interfaccia Utente)** | JSP (JavaServer Pages) / JSF (JavaServer Faces) | Thymeleaf / HTML5 + JavaScript (Fetch API) | Rendering dinamico delle pagine web e gestione form utente. |
| **Controller (Logica)** | Servlets / JAX-RS (Jersey, RESTEasy) | `@RestController` / `@Controller` (Spring MVC) | Intercettazione richieste HTTP, validazione DTO e orchestrazione risposte. |
| **Data Layer (Persistenza)** | JPA / EJB (Enterprise JavaBeans) Entity | Spring Data JPA / Hibernate Repositories | Astrazione dell'accesso ai dati, mapping ORM ed esecuzione query. |
| **Runtime / Application Server** | Application Server esterno (JBoss/WildFly, GlassFish, WebSphere) | Embedded Container (Tomcat / Netty autonomo) | Esecuzione dell'applicazione packaged come jar autosufficiente. |
| **Dependency Injection** | CDI (Contexts and Dependency Injection) | Spring IoC Container (`@Autowired`, `@Component`) | Gestione del ciclo di vita dei bean e inversione del controllo. |
