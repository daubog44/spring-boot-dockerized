# Service e controller REST

<!-- parte: B · Svolgere la traccia | quando: 09:45 | durata: 45 minuti | obiettivo: Il catalogo risponde in JSON con i codici HTTP giusti, le regole stanno nel service, e Swagger mostra ogni endpoint con la sua descrizione. -->

Le entity tengono i dati; adesso qualcuno deve darli fuori. Si fa in due
classi: il **service**, dove stanno le regole, e il **controller**, che parla
HTTP.

## Tre strati, tre mestieri

| Strato | Sa di | Non sa di |
| :--- | :--- | :--- |
| controller | percorsi, parametri, codici HTTP, JSON | database, regole |
| service | regole della traccia, transazioni, trasformare entity in DTO | HTTP |
| repository | tabelle e query | tutto il resto |

Un controller sottile e un service che non sa niente di HTTP: così le regole
stanno in un posto solo, e si provano senza avviare un server.

> 💡 **Scorciatoia d'esame**: Ricorda che eseguendo `task new-entity SERVICE=<modulo> NAME=<Nome> FIELDS=...` hai già ottenuto sia il `Service` che il `Controller` REST con le operazioni CRUD complete, la validazione e la documentazione Swagger! Qui vediamo come sono composti per personalizzarli.

## Il service

```java demo/catalogo-service/src/main/java/esame/catalogoservice/service/CatalogoService.java
@Service
@RequiredArgsConstructor
public class CatalogoService {

    private final LibroRepository libri;

    public List<LibroDto> tutti() {
        return libri.findAll().stream().map(CatalogoService::toDto).toList();
    }

    public List<LibroDto> disponibili() {
        return libri.findByDisponibileTrue().stream().map(CatalogoService::toDto).toList();
    }

    public LibroDto perId(Long id) {
        return toDto(trova(id));
    }

    // Dentro una transazione l'entity e' "gestita": basta cambiarla, e
    // Hibernate scrive l'UPDATE da solo alla fine del metodo.
    @Transactional
    public LibroDto cambiaDisponibilita(Long id, boolean disponibile) {
        LibroEntity libro = trova(id);
        libro.setDisponibile(disponibile);
        return toDto(libro);
    }

    private LibroEntity trova(Long id) {
        return libri.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Libro " + id + " non trovato"));
    }

    // Fuori dal servizio esce il DTO, mai l'entity: l'autore diventa una
    // stringa, e chi chiama non dipende da come e' fatto il database.
    static LibroDto toDto(LibroEntity libro) {
        AutoreEntity autore = libro.getAutore();
        return new LibroDto(
                libro.getId(),
                libro.getTitolo(),
                libro.getIsbn(),
                libro.getAnnoPubblicazione(),
                libro.getGenere() == null ? null : libro.getGenere().name(),
                Boolean.TRUE.equals(libro.getDisponibile()),
                autore == null ? null : autore.getNome() + " " + autore.getCognome());
    }
}
```

Tre cose da portarsi via:

- **`@RequiredArgsConstructor`** di Lombok scrive il costruttore con i campi
  `final`, e Spring ci passa il repository. È l'iniezione delle dipendenze,
  senza `@Autowired`;
- **`ResponseStatusException`** è il modo più corto per rispondere con un
  errore: lanciata ovunque, diventa la risposta HTTP con quel codice;
- **`@Transactional`** su un metodo che modifica: l'entity letta dentro la
  transazione è seguita da Hibernate, e ogni modifica diventa un `UPDATE` alla
  fine del metodo, senza chiamare `save`.

## Il controller

```java demo/catalogo-service/src/main/java/esame/catalogoservice/controller/LibroController.java
@Tag(name = "Catalogo", description = "I libri della biblioteca e la loro disponibilita'")
@RestController
@RequestMapping("/api/libri")
@RequiredArgsConstructor
public class LibroController {

    private final CatalogoService catalogo;

    @Operation(summary = "Tutti i libri del catalogo")
    @GetMapping
    public List<LibroDto> tutti() {
        return catalogo.tutti();
    }

    @Operation(summary = "Solo i libri che si possono prendere in prestito")
    @GetMapping("/disponibili")
    public List<LibroDto> disponibili() {
        return catalogo.disponibili();
    }

    @Operation(summary = "Un libro, per id (404 se non c'e')")
    @GetMapping("/{id}")
    public LibroDto perId(@PathVariable Long id) {
        return catalogo.perId(id);
    }

    // La chiama prestiti-service, via Feign, quando un libro esce o rientra.
    @Operation(summary = "Segna un libro come disponibile o in prestito")
    @PutMapping("/{id}/disponibilita")
    public LibroDto cambiaDisponibilita(@PathVariable Long id, @RequestParam boolean disponibile) {
        return catalogo.cambiaDisponibilita(id, disponibile);
    }
}
```

| Annotazione | Che cosa fa |
| :--- | :--- |
| `@RestController` | quello che il metodo restituisce diventa il corpo della risposta, in JSON |
| `@RequestMapping("/api/libri")` | il pezzo di percorso comune a tutti i metodi |
| `@GetMapping("/{id}")` + `@PathVariable` | `GET /api/libri/3`: il 3 arriva in `id` |
| `@RequestParam` | `?disponibile=false`: il valore arriva nel parametro |
| `@Tag`, `@Operation` | il gruppo e la descrizione che mostra Swagger |

## I codici di risposta

| Codice | Quando | Come lo ottieni |
| :--- | :--- | :--- |
| 200 | è andato bene | restituisci il valore |
| 201 | hai creato qualcosa | `@ResponseStatus(HttpStatus.CREATED)` sul metodo |
| 400 | la richiesta è sbagliata | da solo, con `@Valid` su un corpo che non rispetta i vincoli |
| 404 | la cosa non c'è | `ResponseStatusException(HttpStatus.NOT_FOUND, ...)` |
| 409 | c'è, ma la regola non lo permette | `ResponseStatusException(HttpStatus.CONFLICT, ...)` |
| 500 | un'eccezione non prevista | è un bug: guarda `task logs` |

Il corpo dell'errore lo scrive Spring Boot: `status`, `error`, `path`. Il
messaggio che hai scritto nell'eccezione, di serie, non c'è; se lo vuoi nella
risposta, aggiungi `server.error.include-message: always` all'`application.yml`.

## Una POST con validazione

```java demo/prestiti-service/src/main/java/esame/prestitiservice/controller/PrestitoController.java
@Tag(name = "Prestiti", description = "Prestiti, restituzioni e penali per ritardo")
@RestController
@RequestMapping("/api/prestiti")
@RequiredArgsConstructor
public class PrestitoController {

    private final PrestitoService servizio;

    @Operation(summary = "Tutti i prestiti, con ritardo e penale calcolati a oggi")
    @GetMapping
    public List<PrestitoDto> tutti() {
        return servizio.tutti();
    }

    // @Valid: se l'email non e' un'email o i giorni sono fuori da 1-60,
    // Spring risponde 400 prima ancora di entrare nel metodo.
    @Operation(summary = "Presta un libro: 201, 404 se non esiste, 409 se e' gia' fuori")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PrestitoDto presta(@Valid @RequestBody NuovoPrestitoRequest richiesta) {
        return servizio.presta(richiesta);
    }

    @Operation(summary = "Chiude un prestito: il libro torna disponibile")
    @PutMapping("/{id}/restituzione")
    public PrestitoDto restituisci(@PathVariable Long id) {
        return servizio.restituisci(id);
    }
}
```

`@RequestBody` trasforma il JSON in un `NuovoPrestitoRequest`; `@Valid` fa
controllare i vincoli scritti sul record (`@NotNull`, `@Email`, `@Min`,
`@Max`) prima di chiamare il metodo.

## Gestione globale degli errori con `task new-handler`

Quando un client invia dati errati (es. email non valida o campi obbligatori mancanti), Spring lancia un'eccezione di validazione (`MethodArgumentNotValidException`). Senza un gestore globale, rischieresti di restituire status non chiari o stack trace grezzi.

Per generare automaticamente un gestore `@RestControllerAdvice` centralizzato per il servizio:

```bash
task new-handler SERVICE=catalogo-service
```

Questo comando genera `exception/GlobalExceptionHandler.java` pronto all'uso, che:
- Intercetta gli errori di validazione dei campi (`@Valid`) e risponde con **400 Bad Request** e una lista dettagliata di ogni campo errato con il relativo messaggio;
- Intercetta `ResponseStatusException` mantenendo lo status HTTP specificato (es. 404, 409);
- Intercetta `EntityNotFoundException` / `NoSuchElementException` rispondendo con **404 Not Found**;
- Intercetta qualsiasi altro errore imprevisto rispondendo con un JSON pulito in formato standard.

## Provarlo: Swagger

Ogni modulo creato da `task new-service` ha Swagger acceso. Con lo stack
avviato:

- `http://localhost:8081/swagger-ui.html` — il catalogo
- `http://localhost:8082/swagger-ui.html` — i prestiti

Ci sono tutti gli endpoint, raggruppati per `@Tag`, con la descrizione di
`@Operation`, lo schema dei JSON e il bottone *Try it out* per mandare una
richiesta vera. È il modo più comodo per provare una POST, ed è una delle tre
cose da far vedere alla demo.

Per una GET basta il browser, oppure:

```bash
curl http://localhost:8081/api/libri/1
```

Su Windows PowerShell scrivi `curl.exe`: `curl` da solo lì è un'altra cosa
(`Invoke-WebRequest`). Una POST da bash (Git Bash, Linux, macOS):

```bash
curl -i -X POST http://localhost:8082/api/prestiti -H "Content-Type: application/json" -d '{"libroId":1,"utenteEmail":"anna@esempio.it","giorni":14}'
```

La seconda volta, con lo stesso libro, la risposta è `409`.

> **Prova tu**
>
> Aggiungi al catalogo `GET /api/libri/cerca?titolo=rosa`: un metodo
> `findByTitoloContainingIgnoreCase` nel repository, uno nel service, uno nel
> controller con `@RequestParam String titolo`. Poi provalo da Swagger.

> **Fatto quando**
>
> - [ ] le regole stanno nel service e il controller non fa altro che chiamarlo
> - [ ] un id che non esiste dà 404, non 500
> - [ ] una POST con l'email sbagliata dà 400
> - [ ] Swagger mostra ogni endpoint con la sua descrizione
