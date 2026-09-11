# common-dto, il contratto fra i servizi

<!-- parte: A · Prima di cominciare | quando: la settimana prima | durata: 20 minuti | obiettivo: Sai che cosa mettere in common-dto e che cosa no, e perché due servizi che si scambiano dati devono usare la stessa classe. -->

Quando `prestiti-service` chiede un libro al catalogo, il JSON viaggia fra due
programmi diversi. Perché funzioni, chi lo scrive e chi lo legge devono essere
d'accordo su come è fatto: gli stessi campi, con gli stessi nomi e gli stessi
tipi. `common-dto` è il posto dove quell'accordo è scritto una volta sola.

## Che cos'è

Un modulo Maven che non parte: niente `Main`, niente porta. Produce un jar che
gli altri moduli usano come dipendenza, e ogni modulo creato da
`task new-service` ce l'ha già nel pom:

```xml demo/prestiti-service/pom.xml
<dependency>
    <groupId>com.example</groupId>
    <artifactId>common-dto</artifactId>
    <version>${project.version}</version>
</dependency>
```

Se un modulo non ce l'ha (uno scritto a mano), si aggiunge con
`task add-dep SERVICE=<modulo> DEPS=common-dto`.

## Che cosa ci va

I **record** che due servizi si passano. Nella Biblioteca sono tre:

```java demo/common-dto/src/main/java/esame/common/dto/LibroDto.java
/** Un libro del catalogo, come lo vede chi lo chiede via Feign. */
public record LibroDto(
        Long id,
        String titolo,
        String isbn,
        Integer annoPubblicazione,
        String genere,
        boolean disponibile,
        String autore) {
}
```

```java demo/common-dto/src/main/java/esame/common/dto/NuovoPrestitoRequest.java
/**
 * Il corpo di POST /api/prestiti. Sta in common-dto perche' lo usano in due:
 * prestiti-service lo riceve, biblioteca-ui lo manda via Feign.
 */
public record NuovoPrestitoRequest(
        @NotNull Long libroId,
        @NotBlank @Email String utenteEmail,
        @Min(1) @Max(60) Integer giorni) {
}
```

| Record | Chi lo scrive | Chi lo legge |
| :--- | :--- | :--- |
| `LibroDto` | `catalogo-service` | `prestiti-service`, `biblioteca-ui` |
| `PrestitoDto` | `prestiti-service` | `biblioteca-ui` |
| `NuovoPrestitoRequest` | `biblioteca-ui` | `prestiti-service` |

Il record è la forma giusta per un DTO: immutabile, con costruttore,
accessori, `equals` e `toString` già fatti, e Jackson lo trasforma in JSON e
ritorno senza configurazione. Le annotazioni di validazione sui componenti
funzionano: `prestiti-service` riceve `@Valid @RequestBody NuovoPrestitoRequest`
e risponde 400 se l'email non è un'email. `common-dto` ha già
`jakarta.validation-api` fra le dipendenze.

## Che cosa **non** ci va

- **Le entity.** `LibroEntity` sta in `catalogo-service` e ci resta: è il modo
  in cui il catalogo tiene i suoi dati, e nessun altro deve dipenderne. Se
  domani la tabella cambia, il DTO no. Il catalogo trasforma l'entity in DTO
  prima di rispondere: lo vedi nella [lezione sui
  controller](09-service-e-controller.md).
- **Le classi di un servizio solo.** `PrestitoForm`, i campi del form della
  pagina, lo usa solo `biblioteca-ui`, e sta lì. In `common-dto` va quello che
  attraversa la rete.
- **La logica.** Niente service, niente repository: solo la forma dei dati.

## Il vantaggio: gli errori arrivano quando compili

Se cambi `LibroDto` — aggiungi `editore`, togli `isbn` — chi lo usa non
compila più finché non lo sistemi. È molto meglio di un campo che arriva
`null` in silenzio durante la demo. Dopo aver cambiato un DTO:

```bash
task compile
```

ricompila tutti i moduli, `common-dto` compreso. Se un servizio acceso non vede
il campo nuovo, `task dev` lo riavvia da capo.

## In common-dto ci sono anche i dati di prova

In `common-dto` c'è un pacchetto che non devi toccare, `devdata`: è il codice
che all'avvio riempie le tabelle vuote e che legge lo schema per l'allegato
(`task seed-data` e `task db-schema`, nella [lezione sui dati di
prova](13-dati-e-schema.md)). Sta qui perché così arriva in ogni servizio senza
dipendenze in più, e si accende solo nei moduli che hanno un database.

> **Prova tu**
>
> Aggiungi a `LibroDto` un campo `String editore` e lancia `task build`. Leggi
> l'errore: ti dice esattamente dove il record viene costruito
> (`CatalogoService.toDto`). Poi togli il campo.

> **Fatto quando**
>
> - [ ] sai perché `LibroDto` sta in `common-dto` e `LibroEntity` no
> - [ ] sai dove mettere la classe del corpo di una POST che una pagina manda a un servizio
> - [ ] sai che cosa fare dopo aver cambiato un DTO
