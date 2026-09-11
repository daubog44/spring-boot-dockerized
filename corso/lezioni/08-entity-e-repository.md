# Le entity e i repository

<!-- parte: B · Svolgere la traccia | quando: 09:05 | durata: 40 minuti | obiettivo: Scrivi le classi @Entity della traccia e i loro repository, e sai che cosa diventa ogni annotazione nel database. -->

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

## La relazione

`@ManyToOne` sta dal lato «molti»: tanti libri hanno lo stesso autore, e la
colonna `autore_id` sta nella tabella `libri`. Il lato opposto
(`@OneToMany(mappedBy = "autore")` in `AutoreEntity`) si aggiunge solo se ti
serve davvero la lista dei libri di un autore: una relazione nei due sensi,
trasformata in JSON, gira in tondo all'infinito. È un'altra ragione per cui
dai servizi escono DTO e non entity.

## Fra due servizi, niente relazioni

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

`JpaRepository` ti dà già `findAll`, `findById`, `save`, `deleteById`, `count`.
Il resto si ottiene dal nome del metodo:

| Metodo | La query che scrive Spring |
| :--- | :--- |
| `findByGenere(Genere g)` | `WHERE genere = ?` |
| `findByTitoloContainingIgnoreCase(String t)` | `WHERE lower(titolo) LIKE %t%` |
| `findByAnnoPubblicazioneBetween(int da, int a)` | `WHERE anno_pubblicazione BETWEEN ? AND ?` |
| `findByAutoreCognome(String c)` | una `JOIN` su `autori`, `WHERE cognome = ?` |
| `countByDisponibileFalse()` | `SELECT count(*) ... WHERE disponibile = false` |
| `findTop5ByOrderByAnnoPubblicazioneDesc()` | i cinque più recenti |

Quando il nome diventerebbe una frase, si scrive la query con `@Query("select
l from LibroEntity l where ...")`, in JPQL: si ragiona su classi e campi, non su
tabelle e colonne.

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

> **Prova tu**
>
> Aggiungi a `LibroEntity` un campo `editore` (una stringa di 80 caratteri, che
> può mancare) e a `LibroRepository` il metodo `findByGenere(Genere genere)`.
> Poi lancia `task db-schema` e cerca la colonna nuova nella tabella `libri`.

> **Fatto quando**
>
> - [ ] le entity della traccia compilano e `task db-schema` le mostra
> - [ ] sai perché gli enum si salvano come stringa
> - [ ] sai dove sta la colonna di una relazione `@ManyToOne`
> - [ ] sai scrivere una query col nome del metodo
