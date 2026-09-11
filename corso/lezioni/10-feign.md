# Chiamare un altro servizio: OpenFeign

<!-- parte: B · Svolgere la traccia | quando: 10:30 | durata: 40 minuti | obiettivo: prestiti-service chiede i libri al catalogo e gli dice quando escono e rientrano; sai che cosa succede quando l'altro servizio risponde con un errore, o non risponde affatto. -->

È la parte che vale di più nella griglia: un servizio che ne chiama un altro
per nome, attraverso Eureka. Con Feign è un'interfaccia e una chiamata di
metodo.

## Il client

```java demo/prestiti-service/src/main/java/esame/prestitiservice/client/CatalogoClient.java
// Il nome e' quello con cui catalogo-service si registra su Eureka
// (spring.application.name): niente URL, lo risolve il load balancer.
@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri/{id}")
    LibroDto libro(@PathVariable("id") Long id);

    @PutMapping("/api/libri/{id}/disponibilita")
    LibroDto cambiaDisponibilita(@PathVariable("id") Long id, @RequestParam("disponibile") boolean disponibile);
}
```

Le regole sono tre:

1. `name` è lo `spring.application.name` dell'altro servizio, lettera per
   lettera;
2. ogni metodo copia il metodo del controller che chiama: stesso verbo, stesso
   percorso completo (`/api/libri/{id}`, non `/{id}`), stessi parametri;
3. il tipo restituito è il DTO di `common-dto`, lo stesso che l'altro servizio
   restituisce.

Il `Main` generato da `task new-service` ha già `@EnableFeignClients`: ogni
interfaccia `@FeignClient` sotto il suo pacchetto diventa un bean che puoi
iniettare come qualsiasi altro.

## Usarlo

```java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
@Transactional
public PrestitoDto presta(NuovoPrestitoRequest richiesta) {
    LibroDto libro;
    try {
        libro = catalogo.libro(richiesta.libroId());
    } catch (FeignException.NotFound e) {
        // Il 404 del catalogo diventa il nostro 404, con un messaggio chiaro.
        throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Libro " + richiesta.libroId() + " non presente nel catalogo");
    }
    if (!libro.disponibile() || prestiti.existsByLibroIdAndStato(libro.id(), StatoPrestito.IN_CORSO)) {
        throw new ResponseStatusException(HttpStatus.CONFLICT, "\"" + libro.titolo() + "\" e' gia' in prestito");
    }

    LocalDate oggi = LocalDate.now();
    int giorni = richiesta.giorni() == null ? GIORNI_DEFAULT : richiesta.giorni();
    PrestitoEntity prestito = new PrestitoEntity();
    prestito.setLibroId(libro.id());
    prestito.setUtenteEmail(richiesta.utenteEmail());
    prestito.setDataPrestito(oggi);
    prestito.setDataScadenza(oggi.plusDays(giorni));
    prestito.setStato(StatoPrestito.IN_CORSO);
    prestiti.save(prestito);

    catalogo.cambiaDisponibilita(libro.id(), false);
    return toDto(prestito, libro.titolo(), oggi);
}
```

Quando l'altro servizio risponde con un errore, Feign lancia una
`FeignException`, con una sottoclasse per i codici più comuni:
`FeignException.NotFound` per il 404, `Conflict` per il 409, `BadRequest` per
il 400. Senza il `try`, il 404 del catalogo diventerebbe un 500 dei prestiti:
un errore di chi chiama, non di chi ha sbagliato. Qui invece diventa un 404
con un messaggio che si capisce.

## Quando l'altro servizio non risponde

Se il catalogo è spento, la chiamata non arriva nemmeno: Feign lancia comunque
una `FeignException` (con `status()` uguale a -1, o 503 se Eureka non conosce
nessuna istanza). Dove il dato è un di più, si va avanti senza:

```java demo/prestiti-service/src/main/java/esame/prestitiservice/service/PrestitoService.java
private String titolo(Long libroId) {
    try {
        return catalogo.libro(libroId).titolo();
    } catch (FeignException e) {
        // Il catalogo non risponde, o il libro non c'e' piu': il prestito
        // si mostra lo stesso.
        return "(libro " + libroId + ")";
    }
}
```

L'elenco dei prestiti resta in piedi anche col catalogo spento, con
«(libro 3)» al posto del titolo. È esattamente quello che vuoi far vedere se
alla demo ti chiedono della resilienza.

## Nell'interfaccia: una POST via Feign

`biblioteca-ui` ha i suoi client, con le stesse regole. Per mandare un prestito
serve il corpo della POST: è `NuovoPrestitoRequest`, e per questo sta in
`common-dto`.

```java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/client/PrestitiClient.java
// Le stesse firme del PrestitoController di prestiti-service, con gli stessi
// DTO di common-dto: Feign scrive la richiesta HTTP, Jackson il JSON.
@FeignClient(name = "PRESTITI-SERVICE")
public interface PrestitiClient {

    @GetMapping("/api/prestiti")
    List<PrestitoDto> prestiti();

    @PostMapping("/api/prestiti")
    PrestitoDto presta(@RequestBody NuovoPrestitoRequest richiesta);

    @PutMapping("/api/prestiti/{id}/restituzione")
    PrestitoDto restituisci(@PathVariable("id") Long id);
}
```

## Le trappole, e come si riconoscono

| Che cosa vedi nei log | Che cosa è successo | Che cosa fai |
| :--- | :--- | :--- |
| `Load balancer does not contain an instance for the service CATALOGO-SERVICE` | il nome non è registrato: sbagliato, o il servizio non è ancora su | confronta con la dashboard di Eureka; subito dopo l'avvio aspetta 10 secondi |
| `FeignException$NotFound` su un percorso che esiste | il percorso nel client non è quello del controller | copia il percorso completo, `@RequestMapping` compreso |
| `No qualifying bean of type 'CatalogoClient'` | manca `@EnableFeignClients`, o il client è fuori dal pacchetto di `Main` | guarda `Main` e i pacchetti |
| un campo sempre `null` | i due servizi usano classi diverse per lo stesso JSON | un DTO solo, in `common-dto` |
| `Connection refused` | il servizio è registrato ma spento | `task status`, poi `task logs SERVICE=<nome>` |

Una cosa da sapere: **le transazioni non attraversano la rete.** Se `presta`
fallisce dopo `cambiaDisponibilita`, l'inserimento del prestito si annulla ma
il catalogo resta com'è. Per questo nel codice la chiamata che modifica l'altro
servizio viene per ultima, dopo tutti i controlli.

> **Prova tu**
>
> Con lo stack acceso, spegni il catalogo (`task dev-down` e poi riaccendi
> solo gli altri, oppure in Docker `docker compose stop catalogo-service` dalla
> cartella `demo`). Apri `http://localhost:8082/api/prestiti`: i prestiti ci
> sono, con «(libro N)» al posto del titolo. Poi riaccendi tutto.

> **Fatto quando**
>
> - [ ] il client ha lo stesso nome, gli stessi percorsi e gli stessi DTO dell'altro servizio
> - [ ] un libro che non esiste dà 404 anche passando da Feign
> - [ ] l'elenco dei prestiti non va in errore se il catalogo è spento
> - [ ] sai leggere *Load balancer does not contain an instance*
