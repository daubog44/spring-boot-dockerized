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
    com.example.ttfcloud_esame: DEBUG # Abilita il log dettagliato per i package del progetto
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
3. **Il registro non è immediato.** Dopo l'avvio (o un riavvio da devtools) i
   client impiegano 10-15 secondi ad accorgersi dell'istanza. Una `500` nei
   primi secondi spesso non è un bug: riprova.

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
package com.example.ttfcloud_esame.commondto;

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

---

## 6. Mini-Guida Completa alle Librerie ed Annotazioni Java

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

---

### 6.2 OpenAPI / Springdoc (`Swagger`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@Tag(name = "...", description = "...")` | Classe Controller | Raggruppa gli endpoint sotto una categoria nell'interfaccia Swagger UI. |
| `@Operation(summary = "...", description = "...")` | Metodo REST | Descrive il titolo breve ed il dettaglio di cosa fa il singolo endpoint. |
| `@Parameter(description = "...", example = "...")` | Parametro metodo | Aggiunge descrizione ed un valore di esempio al parametro nella UI Swagger. |
| `@ApiResponse(responseCode = "200", description = "...")` | Metodo REST | Documenta l'esito HTTP di risposta restituito dall'API (200 OK, 400 Bad Request, 404 Not Found). |
| `@Schema(description = "...", example = "...")` | Campo DTO / Class | Documenta il significato ed i valori di esempio per le proprietà dei DTO nella sezione Schemas. |

---

### 6.3 Spring Cloud (Eureka & OpenFeign)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@EnableEurekaServer` | Classe Main | Trasforma l'applicazione Spring Boot nel Server Eureka per il Service Discovery. |
| `@EnableDiscoveryClient` | Classe Main | Abilita l'applicazione client a registrarsi presso il registro Eureka Naming Server. |
| `@EnableFeignClients` | Classe Main / Config | Attiva la scansione e la generazione automatica delle interfacce OpenFeign. |
| `@FeignClient(name = "ORDINI-SERVICE")` | Interfaccia Java | Dichiara un client REST dichiarativo. Spring imposta automaticamente il bilanciamento del carico verso il servizio registrato su Eureka con quel nome logico. |

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

---

### 6.6 Jakarta Validation (`jakarta.validation.constraints`)

| Annotazione | Scope / Uso | Spiegazione Pratica |
| :--- | :--- | :--- |
| `@NotNull` | Campo DTO | Il valore non può essere `null`. |
| `@NotBlank` | Campo Stringa | La stringa non può essere `null`, vuota `""` o contenere solo spazi bianchi `" "`. |
| `@NotEmpty` | Campo Collection/String | La collezione o stringa non deve essere vuota. |
| `@Min(valore)` / `@Max(valore)` | Campo Numerico | Imposta i limiti numerici minimo e massimo ammessi. |
| `@Size(min = X, max = Y)` | Campo String/Collection | Controlla la lunghezza minima e massima di caratteri o elementi. |

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
