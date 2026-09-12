# Le entity e i repository

<!-- parte: B · Svolgere la traccia | quando: 09:05 | durata: 55 minuti | obiettivo: Scrivi le classi @Entity della traccia e i loro repository, e sai che cosa diventa ogni annotazione e ogni parola chiave del nome del metodo nel database. -->

Un'entity è una classe Java che Hibernate trasforma in una tabella: un campo,
una colonna; un oggetto, una riga. Il repository è l'interfaccia con cui la
leggi e la scrivi, senza scrivere SQL.

## Dove vanno

```text
demo/catalogo-service/src/main/java/esame/catalogoservice/
├── Main.java
├── entity/        AutoreEntity, LibroEntity, Genere
├── repository/    LibroRepository
├── service/       CatalogoService
└── controller/    LibroController
```

Spring trova da solo tutto quello che sta sotto il pacchetto di `Main`: i
sottopacchetti sono un ordine per te, non una configurazione.

## Generare tutto in 5 secondi: `task new-entity`

Invece di creare a mano classi, costruttori, annotazioni e interfacce, hai a disposizione il task di scaffolding completo:

```bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):required:unique,annoPubblicazione:int,disponibile:bool
```

> 💡 **Modalità Interattiva**: se non ricordi i parametri a memoria, puoi anche lanciare semplicemente `task new-entity` senza argomenti. Un wizard ti chiederà a quale modulo applicarlo, il nome dell'entità, i campi e se desideri generare anche il DTO!

In un solo colpo questo comando genera quattro file sincronizzati:
1. **`entity/LibroEntity.java`**: classe `@Entity` con `@Table(name = "libri")`, chiave `@Id @GeneratedValue`, campi con annotazioni di validazione (`@NotBlank`, `@NotNull`, ecc.) e getter/setter Lombok.
2. **`repository/LibroRepository.java`**: interfaccia `JpaRepository<LibroEntity, Long>` pronta con tutti i metodi CRUD.
3. **`service/LibroService.java`**: classe `@Service` con metodi operativi completi (`tutti()`, `perId()`, `crea()`, `aggiorna()`, `elimina()`).
4. **`controller/LibroController.java`**: `@RestController` mappato su `/api/libri` con documentazione OpenAPI Swagger (`@Tag`, `@Operation`), `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping` e validazione `@Valid`.

### I tipi e i modificatori ammessi in `FIELDS=`

| Sintassi | Tipo Java | Colonna DB / Validazione |
| :--- | :--- | :--- |
| `nome:string` | `String` | `VARCHAR(255)` |
| `nome:string(150)` | `String` | `VARCHAR(150)` + `@Size(max=150)` |
| `nome:int` o `nome:integer` | `Integer` | `INTEGER` |
| `nome:long` | `Long` | `BIGINT` |
| `nome:decimal` | `BigDecimal` | `NUMERIC(12,2)` |
| `nome:bool` o `nome:boolean` | `Boolean` | `BOOLEAN` |
| `nome:date` | `LocalDate` | `DATE` |
| `nome:datetime` | `LocalDateTime` | `TIMESTAMP` |
| `nome:email` | `String` | `@Email` + `VARCHAR(255)` |
| `nome:text` | `String` | `@Lob` (`TEXT`) |
| `:required` | vincolo | `@NotNull` / `@NotBlank` + `nullable = false` |
| `:unique` | vincolo | `unique = true` sul database |

### Generazione automatica con DTO (`DTO=1`)

Se aggiungi `DTO=1`:
```bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,prezzo:decimal,disponibile:bool DTO=1
```
Il comando:
1. Crea automaticamente il record immutabile `LibroDto` in `common-dto` con tutte le validazioni.
2. Genera in `LibroService` i metodi mapper statici `toDto(entity)` e `toEntity(dto)`.
3. Modifica `LibroController` in modo che riceva e restituisca `LibroDto` invece dell'Entity. In questo modo rispetti alla lettera la best practice "fuori dal service esce solo il DTO" ed eviti per sempre i loop di serializzazione Jackson con le relazioni bidirezionali!

Dopo aver lanciato il comando, puoi aprire i file per aggiungere relazioni (`@ManyToOne`, `@OneToMany`), campi speciali (enum) o metodi di ricerca nel repository come vediamo qui sotto.

## Un'entity

```java demo/catalogo-service/src/main/java/esame/catalogoservice/entity/LibroEntity.java
@Entity
@Table(name = "libri")
@Getter
@Setter
@NoArgsConstructor
public class LibroEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String titolo;

    // ISBN-13: tredici cifre che cominciano con 978 o 979.
    @Pattern(regexp = "97[89][0-9]{10}")
    @Column(nullable = false, unique = true, length = 13)
    private String isbn;

    @Min(1450)
    @Max(2100)
    private Integer annoPubblicazione;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Genere genere;

    @Column(nullable = false)
    private Boolean disponibile;

    // Molti libri, un autore: la colonna autore_id sta nella tabella libri.
    @ManyToOne(optional = false)
    @JoinColumn(name = "autore_id", nullable = false)
    private AutoreEntity autore;
}
```

E che cosa ne fa Hibernate. Questa tabella è l'uscita vera di
`task db-schema` sul branch della Biblioteca:

| Colonna | Tipo | Chiave | Null | Note |
| :--- | :--- | :---: | :---: | :--- |
| `id` | BIGINT | PK | no | generato dal database (identity) |
| `titolo` | VARCHAR(150) |  | no |  |
| `isbn` | VARCHAR(13) |  | no | univoco |
| `anno_pubblicazione` | INTEGER |  | sì | da 1450 a 2100 |
| `genere` | VARCHAR(20) |  | sì | valori ammessi: ROMANZO, SAGGIO, GIALLO, FANTASY, STORICO |
| `disponibile` | BOOLEAN |  | no |  |
| `autore_id` | BIGINT | FK | no | riferimento a `autori`(`id`) |

| Annotazione | Che cosa fa |
| :--- | :--- |
| `@Entity`, `@Table(name = "libri")` | la classe è una tabella, e si chiama `libri` |
| `@Id`, `@GeneratedValue(strategy = IDENTITY)` | chiave primaria, numerata dal database |
| `@Column(nullable = false, length = 150)` | `NOT NULL`, `VARCHAR(150)` |
| `unique = true` | un vincolo di unicità |
| `@Min`, `@Max`, `@Pattern` | validazione: Hibernate la controlla prima di salvare, e per `@Min`/`@Max` mette anche un CHECK |
| `@Enumerated(EnumType.STRING)` | l'enum si salva col nome (`GIALLO`), non col numero |
| `@ManyToOne` + `@JoinColumn` | la chiave esterna `autore_id` verso `autori` |

I nomi dei campi diventano colonne in minuscolo con i trattini bassi:
`annoPubblicazione` diventa `anno_pubblicazione`.

## L'enum, e perché come stringa

```java demo/catalogo-service/src/main/java/esame/catalogoservice/entity/Genere.java
public enum Genere {
    ROMANZO,
    SAGGIO,
    GIALLO,
    FANTASY,
    STORICO
}
```

Senza `@Enumerated(EnumType.STRING)` Hibernate salverebbe la posizione:
`GIALLO` = 2. Basta aggiungere un genere in mezzo e tutti i dati già salvati
cambiano significato. Con `STRING` si salva il nome, e l'ordine non conta.

## Le relazioni tra tabelle (nello stesso modulo)

All'interno dello **stesso modulo**, le tabelle risiedono nello stesso database.
JPA supporta tutte le cardinalità: ecco come si scrivono e le regole per non
sbagliare.

### 1. Many-to-One e One-to-Many (la più frequente all'esame)

Tanti libri hanno un solo autore (`@ManyToOne`); un autore ha una collezione di
libri (`@OneToMany`). La colonna della chiave esterna (`autore_id`) sta
**sempre** nella tabella del lato *Molti* (`libri`).

**Lato proprietario (`LibroEntity`, dove sta la chiave esterna):**

```java
@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "autore_id", nullable = false)
private AutoreEntity autore;
```

**Lato inverso (`AutoreEntity`, opzionale: aggiungilo solo se ti serve):**

```java
@OneToMany(mappedBy = "autore", cascade = CascadeType.ALL, orphanRemoval = true)
private List<LibroEntity> libri = new ArrayList<>();
```

- `mappedBy = "autore"` indica il nome del campo Java nella classe `LibroEntity`.
- `cascade = CascadeType.ALL`: salvando o cancellando l'autore, si sincronizzano anche i suoi libri.
- `orphanRemoval = true`: se togli un libro dalla lista `libri`, Hibernate lo elimina dalla tabella.

### 2. Many-to-Many (Molti a Molti)

Tanti studenti seguono molti corsi; ogni corso ha molti studenti. Hibernate crea
automaticamente la tabella di giunzione ponte (`studenti_corsi`).

**Lato proprietario (`StudenteEntity`):**

```java
@ManyToMany(fetch = FetchType.LAZY)
@JoinTable(
    name = "studenti_corsi",
    joinColumns = @JoinColumn(name = "studente_id"),
    inverseJoinColumns = @JoinColumn(name = "corso_id")
)
private Set<CorsoEntity> corsi = new HashSet<>();
```

**Lato inverso (`CorsoEntity`):**

```java
@ManyToMany(mappedBy = "corsi", fetch = FetchType.LAZY)
private Set<StudenteEntity> studenti = new HashSet<>();
```

> 💡 **Regola d'oro d'esame per Many-to-Many**: Se la relazione ha **dati propri**
> (es. `dataIscrizione`, `votoEsame`), **non** usare `@ManyToMany` semplice!
> Crea un'entità intermedia `IscrizioneEntity` che ha due `@ManyToOne`:
> uno verso `StudenteEntity` e uno verso `CorsoEntity`.

### 3. One-to-One (Uno a Uno)

Un utente ha un solo profilo/tessera. La chiave esterna (`tessera_id`) sta
in una delle due tabelle (es. `utenti`), con vincolo di unicità `unique = true`:

```java
// In UtenteEntity (lato che detiene la foreign key tessera_id)
@OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
@JoinColumn(name = "tessera_id", unique = true)
private TesseraEntity tessera;
```

```java
// In TesseraEntity (lato inverso, opzionale)
@OneToOne(mappedBy = "tessera", fetch = FetchType.LAZY)
private UtenteEntity utente;
```

### Le 4 trappole da evitare all'esame

1. **Usa sempre `fetch = FetchType.LAZY`**: di default `@ManyToOne` e `@OneToOne`
   usano `EAGER`, caricando a cascata decine di record non richiesti.
2. **Inizializza sempre le collezioni**: `= new ArrayList<>()` o `= new HashSet<>()`,
   altrimenti rischi `NullPointerException`.
3. **MAI `@Data` di Lombok sulle entity con relazioni**: genera in automatico
   `toString()`, `equals()` e `hashCode()` ricorsivi. Con relazioni bidirezionali,
   `toString()` entra in un loop infinito che fa esplodere la JVM con `StackOverflowError`.
   Usa sempre `@Getter`, `@Setter` e `@NoArgsConstructor`.

---

## Serializzazione JSON delle Relazioni & Join Completi

Quando due tabelle sono collegate da una relazione bidirezionale (es. un `Articolo` ha una `Categoria`, e una `Categoria` ha una lista di `Articoli`), sorgono due sfide cruciali:
1. **Loop infinito Jackson**: Jackson serializza `Articolo` -> trova `categoria` -> serializza `Categoria` -> trova `articoli` -> serializza di nuovo ogni `Articolo`... all'infinito (`StackOverflowError`).
2. **`LazyInitializationException`**: con `fetch = FetchType.LAZY`, se la serializzazione JSON avviene nel Controller fuori dal confine transazionale del Service, la sessione Hibernate è chiusa e l'accesso all'oggetto correlato fallisce.

Ecco le due soluzioni complete a confronto:

### Soluzione 1: Senza DTO — `@JsonIgnoreProperties` + `JOIN FETCH`

Se nel tuo microservizio hai scelto di restituire direttamente le classi `@Entity` dal controller, puoi risolvere il ciclo e ottenere l'entità correlata completa annotando `@JsonIgnoreProperties`:

```java
// ArticoloEntity.java
@Entity
@Table(name = "articoli")
@Getter @Setter @NoArgsConstructor
public class ArticoloEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String nome;
    private BigDecimal prezzo;

    // Mostra l'intera Categoria in JSON, ma ignora la lista 'articoli' dentro di essa per spezzare il loop!
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categoria_id")
    @JsonIgnoreProperties("articoli")
    private CategoriaEntity categoria;
}
```

```java
// CategoriaEntity.java
@Entity
@Table(name = "categorie")
@Getter @Setter @NoArgsConstructor
public class CategoriaEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String nome;

    // Quando chiedi la Categoria, mostra la lista di articoli ma ignora il puntatore indietro 'categoria'!
    @OneToMany(mappedBy = "categoria", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("categoria")
    private List<ArticoloEntity> articoli = new ArrayList<>();
}
```

#### E come si fa il JOIN nel Database?
Con `fetch = FetchType.LAZY`, chiamare `findAll()` farebbe una query per la tabella principale più una query per ogni categoria correlata (problema della query N+1), oppure lancerebbe `LazyInitializationException`.
Per fare un **vero JOIN SQL** in un'unica query veloce, definisci una query con `JOIN FETCH` nel Repository:

```java
public interface ArticoloRepository extends JpaRepository<ArticoloEntity, Long> {

    // Esegue una sola query SQL con LEFT JOIN caricando Articolo e Categoria insieme
    @Query("SELECT a FROM ArticoloEntity a LEFT JOIN FETCH a.categoria")
    List<ArticoloEntity> findAllWithCategoria();

    @Query("SELECT a FROM ArticoloEntity a LEFT JOIN FETCH a.categoria WHERE a.id = :id")
    Optional<ArticoloEntity> findByIdWithCategoria(@Param("id") Long id);
}
```

In questo modo il database esegue:
```sql
SELECT a.*, c.* FROM articoli a LEFT JOIN categorie c ON a.categoria_id = c.id;
```
Tutti i dati sono già in memoria, e Jackson restituisce il JSON completo con la categoria annidata senza alcun errore!

---

### Soluzione 2: Con DTO — Pattern "DTO in DTO" per un Join Completo (Consigliata)

È la soluzione enterprise standard: non tocca le entity con annotazioni Jackson e garantisce che fuori dal microservizio escano solo contratti stabili e documentati in OpenAPI.

#### 1. I DTO in `common-dto`
Definisci in `common-dto` sia il DTO della tabella secondaria che quello principale, annidando il primo nel secondo:

```java
// common-dto/.../CategoriaDto.java
public record CategoriaDto(
    Long id,
    @NotBlank String nome
) {}
```

```java
// common-dto/.../ArticoloDto.java (annida CategoriaDto)
public record ArticoloDto(
    Long id,
    @NotBlank String nome,
    @NotNull BigDecimal prezzo,
    Integer quantita,
    Boolean disponibile,
    CategoriaDto categoria // <-- DTO in DTO: l'intera entita' correlata!
) {}
```

#### 2. Il Repository (con JOIN FETCH per caricare tutto in 1 query)
```java
public interface ArticoloRepository extends JpaRepository<ArticoloEntity, Long> {
    @Query("SELECT a FROM ArticoloEntity a LEFT JOIN FETCH a.categoria")
    List<ArticoloEntity> findAllConCategoria();
}
```

#### 3. Il Service (metodo mapper `toDto`)
Nel Service mappi l'entity correlata nel relativo DTO annidato:

```java
@Service
@RequiredArgsConstructor
public class ArticoloService {
    private final ArticoloRepository articoli;

    public List<ArticoloDto> tutti() {
        return articoli.findAllConCategoria().stream()
                .map(ArticoloService::toDto)
                .toList();
    }

    public static ArticoloDto toDto(ArticoloEntity entity) {
        CategoriaDto catDto = null;
        if (entity.getCategoria() != null) {
            catDto = new CategoriaDto(
                entity.getCategoria().getId(),
                entity.getCategoria().getNome()
            );
        }
        return new ArticoloDto(
            entity.getId(),
            entity.getNome(),
            entity.getPrezzo(),
            entity.getQuantita(),
            entity.getDisponibile(),
            catDto // Oggetto annidato
        );
    }
}
```

#### 4. Il JSON risultante
L'API REST risponde con un JSON pulito e senza campi superflui:
```json
{
  "id": 1,
  "nome": "Smartphone Galaxy",
  "prezzo": 599.90,
  "quantita": 25,
  "disponibile": true,
  "categoria": {
    "id": 2,
    "nome": "Telefonia"
  }
}
```

> 💡 **E se voglio il join inverso? (Categoria con la lista di Articoli)**:
> Basta definire:
> ```java
> public record CategoriaConArticoliDto(Long id, String nome, List<ArticoloDto> articoli) {}
> ```
> E nel `CategoriaService`:
> ```java
> static CategoriaConArticoliDto toDto(CategoriaEntity c) {
>     List<ArticoloDto> list = c.getArticoli() != null
>         ? c.getArticoli().stream().map(ArticoloService::toDto).toList()
>         : List.of();
>     return new CategoriaConArticoliDto(c.getId(), c.getNome(), list);
> }
> ```

> 💡 **Alternativa: DTO Piatto (Flat DTO)**:
> Se per il frontend o per OpenFeign non ti serve l'oggetto annidato ma bastano le colonne appiattite:
> ```java
> public record ArticoloFlatDto(Long id, String nome, BigDecimal prezzo, Long categoriaId, String categoriaNome) {}
> ```

---

### Tabella di Confronto: `@JsonIgnoreProperties` vs DTO in DTO

| Caratteristica | Soluzione 1: `@JsonIgnoreProperties` | Soluzione 2: "DTO in DTO" (Consigliata) |
| :--- | :--- | :--- |
| **Dove si configura** | Sulle annotazioni `@ManyToOne` / `@OneToMany` delle `@Entity`. | Nei record Java in `common-dto` e nel mapper `toDto()`. |
| **Esecuzione del Join DB** | Tramite `@Query("... LEFT JOIN FETCH ...")` nel repository. | Tramite `@Query("... LEFT JOIN FETCH ...")` nel repository. |
| **Rischio loop infinito** | Evitato se `@JsonIgnoreProperties` è configurato su entrambi i lati. | **Zero assoluto**: i DTO record sono immutabili e lineari. |
| **Rischio LazyInitException** | Possibile se accedi all'oggetto fuori da transazione senza `JOIN FETCH`. | Nessuno: il mapping avviene dentro il Service. |
| **Documentazione Swagger** | Mostra l'intera Entity con tutti i dettagli interni. | Mostra solo lo schema esatto dei dati esposti. |
| **Flessibilità per Feign/UI** | I client devono importare le annotazioni di serializzazione. | I client usano direttamente il record DTO condiviso. |

### Configurare le relazioni in 5 secondi: `task add-relation`

Invece di scrivere annotazioni, chiavi esterne e collezioni inverse a mano col rischio di dimenticare `fetch = FetchType.LAZY`, `mappedBy`, o gli import:

```bash
task add-relation SERVICE=catalogo-service FROM=Libro TO=Autore TYPE=many-to-one
```

Oppure lancialo **senza argomenti**:
```bash
task add-relation
```
Si aprirà una comoda procedura guidata nel terminale: ti chiederà in quale microservizio vuoi operare, elencherà tutte le entità rilevate e ti farà scegliere il tipo di relazione desiderata (`many-to-one`, `one-to-many`, `one-to-one`, `many-to-many`).

Cosa fa per te:
- Inserisce l'annotazione corretta con `fetch = FetchType.LAZY`.
- Configura `@JoinColumn(name = "autore_id")` sul lato proprietario.
- Configura il lato inverso con `mappedBy` e lista già inizializzata (`= new ArrayList<>()`).
- Aggiunge automaticamente tutti gli `import` necessari (`jakarta.persistence.*`, `java.util.List`, ecc.).
- Con `UNIDIRECTIONAL=1` evita di aggiungere il campo inverso se ti serve unidirezionale.

---

## Fra due servizi, niente relazioni nel database

```java demo/prestiti-service/src/main/java/esame/prestitiservice/entity/PrestitoEntity.java
// Il libro vive in un altro servizio, con il suo database: qui se ne tiene
// solo l'id. Niente chiave esterna, perche' la tabella libri non e' qui.
@Entity
@Table(name = "prestiti")
@Getter
@Setter
@NoArgsConstructor
public class PrestitoEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long libroId;

    @Email
    @Column(nullable = false, length = 120)
    private String utenteEmail;

    @Column(nullable = false)
    private LocalDate dataPrestito;

    @Column(nullable = false)
    private LocalDate dataScadenza;

    private LocalDate dataRestituzione;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatoPrestito stato;
}
```

`LocalDate` diventa `DATE`: per le date senza ora è il tipo giusto, e con
`ChronoUnit.DAYS.between` si contano i giorni senza pensieri.

## I repository

```java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {

    // Spring Data scrive la query dal nome: ... WHERE disponibile = true
    List<LibroEntity> findByDisponibileTrue();
}
```

```java demo/prestiti-service/src/main/java/esame/prestitiservice/repository/PrestitoRepository.java
public interface PrestitoRepository extends JpaRepository<PrestitoEntity, Long> {

    // ... WHERE libro_id = ? AND stato = ?, e dice solo se c'e' almeno una riga.
    boolean existsByLibroIdAndStato(Long libroId, StatoPrestito stato);
}
```

`JpaRepository<LibroEntity, Long>` ti dà già, senza scrivere niente:
`findAll()`, `findById(Long)` (torna un `Optional`), `save(entity)` (inserisce
o aggiorna, decide lui guardando l'`id`), `deleteById(Long)`, `count()`,
`existsById(Long)`. Il resto — quello specifico della tua traccia — si scrive
da solo nel nome del metodo: Spring Data lo legge e costruisce la query.

## Il nome del metodo è la query: tutte le parole chiave

Lo schema è `<verbo><NomeCampo><Condizione>And/Or<AltroCampo>...`. Il verbo
decide che cosa torna, il resto la clausola `WHERE`. Il campo si scrive come
in Java (`autore.cognome` diventa `AutoreCognome`, e Spring fa la `JOIN` da
solo).

| Verbo | Torna | Esempio |
| :--- | :--- | :--- |
| `findBy...` / `getBy...` / `queryBy...` | `List<T>` (o un solo `T`/`Optional<T>` se il campo è unico) | `findByIsbn(String isbn)` → `Optional<LibroEntity>` |
| `existsBy...` | `boolean` | `existsByIsbn(String isbn)` |
| `countBy...` | `long` | `countByGenere(Genere g)` |
| `deleteBy...` / `removeBy...` | `void` o `long` (righe cancellate) | `deleteByDisponibileFalse()` |

| Condizione nel nome | `WHERE` generato | Esempio |
| :--- | :--- | :--- |
| `findByGenere(Genere g)` | `genere = ?` | uguaglianza semplice |
| `findByGenereAndDisponibileTrue(Genere g)` | `genere = ? AND disponibile = true` | `And`/`Or` fra più campi |
| `findByAnnoPubblicazioneGreaterThan(int a)` | `anno_pubblicazione > ?` | anche `GreaterThanEqual`, `LessThan`, `LessThanEqual` |
| `findByAnnoPubblicazioneBetween(int da, int a)` | `anno_pubblicazione BETWEEN ? AND ?` | due parametri, in ordine |
| `findByTitoloContainingIgnoreCase(String t)` | `lower(titolo) LIKE lower('%'+?+'%')` | anche `StartingWith`, `EndingWith` |
| `findByTitoloIsNull()` / `IsNotNull()` | `titolo IS NULL` / `IS NOT NULL` | senza parametri |
| `findByGenereIn(List<Genere> generi)` | `genere IN (...)` | anche `NotIn` |
| `findByDisponibileTrue()` / `False()` | `disponibile = true` / `= false` | scorciatoia per i booleani, meglio di `Is(true)` |
| `findByGenereNot(Genere g)` | `genere <> ?` | negazione |
| `findByAutoreCognome(String c)` | `JOIN autori ON ... WHERE cognome = ?` | attraversa la relazione `@ManyToOne` |
| `findByOrderByAnnoPubblicazioneDesc()` | `ORDER BY anno_pubblicazione DESC` | anche senza condizione, solo ordinamento |
| `findTop5ByOrderByAnnoPubblicazioneDesc()` | `ORDER BY ... DESC LIMIT 5` | `Top3`, `First10`... |
| `findDistinctByGenere(Genere g)` | `SELECT DISTINCT ...` | toglie i duplicati |

Si combinano: `findTop10ByGenereAndDisponibileTrueOrderByAnnoPubblicazioneDesc(Genere g)`
è lungo da leggere ma resta un metodo solo, senza una riga di SQL.

## Un solo risultato che potrebbe non esserci: `Optional`

```java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {
    Optional<LibroEntity> findByIsbn(String isbn);
}
```

Nel service, non si controlla mai un `null` a mano: si sceglie che cosa fare
quando manca, nello stesso punto in cui si legge.

```java demo/catalogo-service/src/main/java/esame/catalogoservice/service/CatalogoService.java
public LibroDto trovaPerIsbn(String isbn) {
    LibroEntity libro = libroRepository.findByIsbn(isbn)
            .orElseThrow(() -> new LibroNonTrovatoException(isbn));   // -> 404, vedi lezione 9
    return toDto(libro);
}
```

`findById` di `JpaRepository` torna `Optional<LibroEntity>` per lo stesso
motivo: un id che non esiste più non è un errore di Java, è un caso normale
da gestire.

## Ordinare e paginare senza scriverlo nel nome

Per un ordinamento deciso a runtime (non fisso come `OrderByTitoloAsc`) si
passa un `Sort`; per una lista lunga, invece di tornare tutto, si passa un
`Pageable` e si torna una `Page<T>`, che porta con sé anche il totale delle
righe:

```java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {
    List<LibroEntity> findByGenere(Genere genere, Sort sort);
    Page<LibroEntity> findByDisponibileTrue(Pageable pageable);
}
```

```java
libroRepository.findByGenere(Genere.GIALLO, Sort.by("titolo").ascending());
Page<LibroEntity> pagina = libroRepository.findByDisponibileTrue(PageRequest.of(0, 20));
pagina.getContent();        // i 20 elementi
pagina.getTotalElements();  // quanti sono in tutto, non solo in questa pagina
```

Per una traccia d'esame, quasi sempre basta `List` senza paginazione: usala
solo se il numero di righe è dichiaratamente grande.

## Quando il nome non basta: `@Query`

Un `JOIN` con più condizioni, un `GROUP BY`, o solo un nome che diventerebbe
illeggibile: si scrive la query a mano, in **JPQL** (si ragiona su classi e
campi Java, non su tabelle e colonne — niente `libri`, `LibroEntity`; niente
`anno_pubblicazione`, `annoPubblicazione`):

```java demo/catalogo-service/src/main/java/esame/catalogoservice/repository/LibroRepository.java
public interface LibroRepository extends JpaRepository<LibroEntity, Long> {

    @Query("select l from LibroEntity l where l.autore.cognome = :cognome and l.disponibile = true")
    List<LibroEntity> disponibiliDiUnAutore(@Param("cognome") String cognome);

    // native = true: SQL vero, per quando serve una funzione del database
    // che JPQL non ha (qui, il conteggio per genere).
    @Query(value = "select genere, count(*) from libri group by genere", nativeQuery = true)
    List<Object[]> conteggioPerGenere();
}
```

`@Param("cognome")` collega il segnaposto `:cognome` nella query al parametro
del metodo — il nome deve combaciare. Una query nativa torna righe grezze
(`Object[]`, o una proiezione con un'interfaccia), non entity: usala solo
quando JPQL davvero non basta.

Una query che **scrive** (`UPDATE`/`DELETE` in JPQL) vuole in più
`@Modifying` e va chiamata dentro una transazione:

```java
@Modifying
@Transactional
@Query("update LibroEntity l set l.disponibile = false where l.id = :id")
void segnaNonDisponibile(@Param("id") Long id);
```

Per una traccia d'esame è raro servirne una: quasi sempre basta caricare
l'entity col repository, cambiarne un campo col setter, e richiamare `save`
(Hibernate si accorge da solo che è un update, non un insert, perché l'`id`
c'è già).

## Paura dell'autocompletamento nell'editor? Le 3 strategie a prova di bomba

Negli editor (come Zed, VS Code o IntelliJ), il Language Server Java suggerisce immediatamente tutti i metodi standard di `JpaRepository`:
- `findAll()`, `findById(id)`, `save(entity)` (fa sia `INSERT` che `UPDATE`), `deleteById(id)`, `existsById(id)`, `count()`. Nel 90% delle tracce d'esame questi metodi predefiniti bastano per coprire l'intero CRUD!

Tuttavia, quando vuoi scrivere un metodo di ricerca personalizzato (es. `findByTitoloContainingIgnoreCase`), l'editor spesso **non può suggerirlo in anticipo** con l'autocompletamento, perché in Spring Data i *derived query methods* vengono sintetizzati a runtime da Spring via proxy dinamico.

Se all'esame ti viene il dubbio sulla sintassi esatta, hai tre strategie infallibili:

### Strategia 1: La formula mnemonica del nome
La regola è sempre lineare:
```text
findBy + <NomeCampoJava> + [Condizione] + [And/Or + AltroCampo]
```
- Uguaglianza: `findByGenere(Genere g)`
- Testo parziale: `findByTitoloContainingIgnoreCase(String testo)`
- Confronto numerico: `findByPrezzoLessThan(BigDecimal max)`
- Combinazione: `findByPrezzoLessThanAndDisponibileTrue(BigDecimal max)`
- Esistenza rapida: `existsByCodice(String codice)`

### Strategia 2: La query a mano con `@Query` (Il salvagente definitivo)
Non perdere tempo a indovinare il nome del metodo! Dai al metodo il nome che preferisci tu e scrivi la query sopra l'interfaccia:
- **In JPQL (oggetti Java)**: usi il nome della classe Entity e dei suoi campi Java:
  ```java
  @Query("SELECT l FROM LibroEntity l WHERE l.prezzo <= :max AND l.disponibile = true")
  List<LibroEntity> trovaEconomici(@Param("max") BigDecimal max);
  ```
- **In SQL Nativo (`nativeQuery = true`)**: usi il normalissimo SQL del database (nomi di tabelle e colonne SQL reali):
  ```java
  @Query(value = "SELECT * FROM libri WHERE prezzo <= :max AND disponibile = true", nativeQuery = true)
  List<LibroEntity> trovaEconomiciSql(@Param("max") BigDecimal max);
  ```
  Con `nativeQuery = true` scrivi la query SQL esattamente come la testeresti in DBeaver o nella console di PostgreSQL.

### Strategia 3: Il cheat sheet offline con `task learn`
Il giorno dell'esame lancia `task learn` in un terminale: si aprirà questa guida nel browser **completamente offline e senza connessione**. Puoi consultare la tabella delle parole chiave in qualsiasi momento e fare copia-incolla delle firme.

## Chi crea le tabelle

Nessuno le scrive: le crea Hibernate all'avvio, leggendo le entity, perché
l'`application.yml` generato dice

```yaml demo/catalogo-service/src/main/resources/application.yml
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
```

`update` crea quello che manca e non cancella niente; `show-sql` stampa ogni
query nei log (`task logs SERVICE=catalogo`), che è il modo più veloce per
capire che cosa fa davvero un repository. Lo stesso codice gira su H2 in
memoria e su PostgreSQL.

## Lombok, e una trappola

`@Getter`, `@Setter` e `@NoArgsConstructor` bastano per un'entity: Hibernate
vuole un costruttore vuoto e i metodi per leggere e scrivere i campi. **Non**
usare `@Data` sulle entity: genera `equals`, `hashCode` e `toString` su tutti
i campi, relazioni comprese, e con due entity che si nominano a vicenda
`toString` non finisce più.

## Le stesse quattro classi, ogni volta: `task new-entity`

Ogni tabella della traccia rifà lo stesso giro: un'entity, un repository, un
service col CRUD, un controller con Swagger. Adesso che sai cosa c'è dentro
ognuno, un comando li scrive per te:

```bash
task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):unique,annoPubblicazione:int:min(1450):max(2100),disponibile:bool:required,genere:enum(ROMANZO|SAGGIO|GIALLO)
```

`FIELDS` è una lista `nome:tipo[:modificatore]*`: i tipi sono `string`,
`string(N)`, `text`, `int`, `long`, `decimal`, `bool`, `date`, `datetime`,
`email`, `enum(A|B|C)` (genera anche l'enum, in un file a parte); i
modificatori sono `required`, `unique`, `min(N)`, `max(N)`. Il catalogo
completo è in `task --summary new-entity`.

Quello che **non** genera, apposta: le relazioni con altre entity
(`@ManyToOne`, `@OneToMany`...) e le regole della tua traccia nel service. Le
aggiungi tu, a mano, dopo — sono la parte che si valuta, non boilerplate. Il
controller generato torna `LibroEntity` direttamente: se questi dati li
consuma anche un altro servizio via Feign, o vuoi nascondere dei campi,
sostituiscilo con un DTO come hai visto nella lezione 9 (te lo ricorda anche
un commento nel file generato).

> **Prova tu**
>
> Aggiungi a `LibroEntity` un campo `editore` (una stringa di 80 caratteri, che
> può mancare) e a `LibroRepository` il metodo `findByGenere(Genere genere)`.
> Poi lancia `task db-schema` e cerca la colonna nuova nella tabella `libri`.
> Poi prova anche il comando: `task new-entity SERVICE=catalogo-service
> NAME=Autore FIELDS=nome:string(80):required,cognome:string(80):required` e
> guarda i quattro file che genera.

> **Fatto quando**
>
> - [ ] le entity della traccia compilano e `task db-schema` le mostra
> - [ ] sai perché gli enum si salvano come stringa
> - [ ] sai dove sta la colonna di una relazione `@ManyToOne`
> - [ ] sai scrivere una query col nome del metodo, comprese `And`, `Between`, `ContainingIgnoreCase`, `OrderBy`
> - [ ] sai quando un repository torna `Optional` e come si gestisce con `orElseThrow`
> - [ ] sai quando serve `@Query` invece del nome del metodo
> - [ ] sai cosa genera `task new-entity` e cosa resta da aggiungere a mano
