# L'interfaccia con Thymeleaf

<!-- parte: B · Svolgere la traccia | quando: 11:40 | durata: 60 minuti | obiettivo: La pagina mostra catalogo e prestiti, registra un prestito con un form validato e una restituzione con un bottone, e non va in errore se un servizio è spento. -->

L'interfaccia è un servizio come gli altri, con una differenza: invece di
restituire JSON, restituisce pagine HTML. Le scrive Thymeleaf, riempiendo un
modello di pagina con i dati che il controller gli passa. Niente JavaScript,
niente framework: un form HTML fa già tutto quello che serve.

## Come gira

1. il browser chiede `GET /`;
2. il metodo del `@Controller` prende i dati (qui con Feign) e li mette nel
   `Model`;
3. restituisce il nome di un modello di pagina, `"index"`: Spring apre
   `src/main/resources/templates/index.html`;
4. Thymeleaf sostituisce gli attributi `th:` con i valori, e al browser
   arriva HTML normale.

Il modulo creato con `task new-service NAME=biblioteca-ui UI=1` ha già la
dipendenza di Thymeleaf, un `HomeController` e una pagina da sostituire.

## Generare una vista completa con tabella e form: `task new-view`

Per non dover scrivere a mano controller, tabella, form e gestione errori:

```bash
task new-view SERVICE=biblioteca-ui NAME=Libri FIELDS=titolo:string:required,autore:string,anno:int
```

Genera:
1. `controller/LibriUiController.java`: controller Spring MVC con `@GetMapping` (elenco + form vuoto) e `@PostMapping` (salvataggio con `@Valid` e binding errori).
2. `src/main/resources/templates/libri.html`: pagina HTML completa, con stile pulito, tabella dinamica `th:each` e form collegato `th:object` con visualizzazione errori `th:errors`.

## Il controller

```java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/HomeController.java
@Controller
@RequiredArgsConstructor
public class HomeController {

    private final CatalogoClient catalogo;
    private final PrestitiClient prestiti;

    @GetMapping("/")
    public String home(Model model) {
        // Dopo un redirect il form puo' esserci gia' (flash): non sovrascriverlo.
        if (!model.containsAttribute("form")) {
            model.addAttribute("form", new PrestitoForm());
        }
        return pagina(model);
    }

    // POST, poi redirect, poi GET: se l'utente ricarica la pagina non rimanda
    // il form una seconda volta, e il messaggio arriva come "flash attribute".
    @PostMapping("/prestiti")
    public String presta(@Valid @ModelAttribute("form") PrestitoForm form, BindingResult errori,
            Model model, RedirectAttributes redirect) {
        if (errori.hasErrors()) {
            // Niente redirect: la pagina torna con i campi sbagliati segnati.
            return pagina(model);
        }
        try {
            PrestitoDto p = prestiti.presta(
                    new NuovoPrestitoRequest(form.getLibroId(), form.getUtenteEmail(), form.getGiorni()));
            redirect.addFlashAttribute("messaggio",
                    "Prestito registrato: \"" + p.titoloLibro() + "\", da restituire entro il " + p.dataScadenza() + ".");
        } catch (FeignException e) {
            redirect.addFlashAttribute("errore", spiega(e));
        }
        return "redirect:/";
    }

    private String pagina(Model model) {
        model.addAttribute("titolo", "Biblioteca di quartiere");
        try {
            List<LibroDto> libri = catalogo.libri();
            model.addAttribute("libri", libri);
            model.addAttribute("disponibili", libri.stream().filter(LibroDto::disponibile).toList());
            model.addAttribute("prestiti", prestiti.prestiti());
        } catch (RuntimeException e) {
            // Subito dopo l'avvio i servizi possono non essere ancora su
            // Eureka: meglio una pagina che lo dice di una pagina d'errore.
            model.addAttribute("errore", "I servizi non rispondono ancora: riprova fra qualche secondo.");
            model.addAttribute("libri", List.of());
            model.addAttribute("disponibili", List.of());
            model.addAttribute("prestiti", List.of());
        }
        return "index";
    }

    // Il codice HTTP che ha risposto l'altro servizio, detto in italiano.
    static String spiega(FeignException e) {
        return switch (e.status()) {
            case 400 -> "Dati non validi: controlla l'email e i giorni.";
            case 404 -> "Quel libro, o quel prestito, non esiste.";
            case 409 -> "Non si puo': il libro e' gia' in prestito, o il prestito e' gia' chiuso.";
            default -> "Il servizio dei prestiti non risponde: riprova fra qualche secondo.";
        };
    }
}
```

(Nel file c'è anche il metodo della restituzione: stesso schema, con
`@PostMapping("/prestiti/{id}/restituzione")`.)

- **`@Controller`**, non `@RestController`: il valore restituito è il nome di
  una pagina, non il corpo della risposta.
- **POST, redirect, GET**: dopo aver registrato il prestito non si mostra la
  pagina, si rimanda a `/`. Se l'utente ricarica, il browser rifà la GET e non
  un secondo prestito. Il messaggio sopravvive al redirect perché è un *flash
  attribute*: vive per una richiesta sola.
- **Il flash attribute sta nella sessione**, e al primo invio il browser non ne
  ha ancora una: Tomcat allora la scrive nell'indirizzo del redirect
  (`/;jsessionid=...`) e Spring non lo riconosce più come `/`. Il primo prestito
  finisce in un 500 senza form, i successivi vanno. Per questo l'`application.yml`
  della UI dice `server.servlet.session.tracking-modes: cookie` (con
  `task new-service UI=1` c'è già). Il collaudo l'ha trovato così: con `curl`, che
  segue il redirect com'è, il primo POST dava 500.
- **Se il form è sbagliato non si fa redirect**: si ridisegna la pagina con
  `BindingResult`, che porta con sé i messaggi di ogni campo.
- **Se un servizio non risponde**, la pagina lo dice e resta in piedi.

## Il form: una classe, non un record

```java demo/biblioteca-ui/src/main/java/esame/bibliotecaui/PrestitoForm.java
@Getter
@Setter
public class PrestitoForm {

    @NotNull(message = "Scegli un libro")
    private Long libroId;

    @NotBlank(message = "Serve l'email di chi prende il libro")
    @Email(message = "Questa non e' un'email")
    private String utenteEmail;

    @NotNull(message = "Quanti giorni?")
    @Min(value = 1, message = "Almeno un giorno")
    @Max(value = 60, message = "Al massimo 60 giorni")
    private Integer giorni = 30;
}
```

Thymeleaf (`th:field`) e il binding della POST lavorano con getter e setter,
e un record non li ha: per il form serve una classe normale. È anche il posto
giusto per i messaggi in italiano che vede l'utente. Poi il controller la
trasforma nel `NuovoPrestitoRequest` di `common-dto`.

## La pagina

Il form, con i messaggi di errore campo per campo:

```html demo/biblioteca-ui/src/main/resources/templates/index.html
<form class="nuovo" th:action="@{/prestiti}" th:object="${form}" method="post">
    <label>Libro
        <select th:field="*{libroId}">
            <option value="">scegli un libro disponibile</option>
            <option th:each="l : ${disponibili}" th:value="${l.id}" th:text="${l.titolo} + ' - ' + ${l.autore}"></option>
        </select>
        <span class="errore-campo" th:if="${#fields.hasErrors('libroId')}" th:errors="*{libroId}"></span>
    </label>
    <label>Email di chi lo prende
        <input type="text" th:field="*{utenteEmail}" placeholder="nome@esempio.it">
        <span class="errore-campo" th:if="${#fields.hasErrors('utenteEmail')}" th:errors="*{utenteEmail}"></span>
    </label>
    <label>Giorni
        <input type="number" th:field="*{giorni}" min="1" max="60">
    </label>
    <button type="submit">Presta</button>
</form>
```

La tabella dei prestiti, con il bottone per restituire solo dove serve:

```html demo/biblioteca-ui/src/main/resources/templates/index.html
<tr th:each="p : ${prestiti}">
    <td th:text="${p.titoloLibro}"></td>
    <td th:text="${p.utenteEmail}"></td>
    <td th:text="${#temporals.format(p.dataScadenza, 'dd/MM/yyyy')}"></td>
    <td th:classappend="${p.giorniRitardo > 0} ? 'ritardo'" th:text="${p.giorniRitardo} + ' gg'"></td>
    <td th:text="${#numbers.formatDecimal(p.penale, 1, 2, 'COMMA')} + ' EUR'"></td>
    <td>
        <form th:if="${p.stato == 'IN_CORSO'}" th:action="@{/prestiti/{id}/restituzione(id=${p.id})}" method="post">
            <button class="piccolo" type="submit">Restituisci</button>
        </form>
    </td>
</tr>
```

| Scrivi | Che cosa fa |
| :--- | :--- |
| `th:text="${titolo}"` | il testo dell'elemento, con l'HTML protetto |
| `th:each="p : ${prestiti}"` | ripete l'elemento per ogni prestito |
| `th:if="${messaggio}"` | l'elemento c'è solo se il valore c'è |
| `th:object="${form}"` e `th:field="*{utenteEmail}"` | lega il campo alla proprietà: scrive `name`, `id` e `value` |
| `th:errors="*{utenteEmail}"` | il messaggio di validazione di quel campo |
| `@{/prestiti/{id}/restituzione(id=${p.id})}` | un indirizzo con un pezzo variabile |
| `th:classappend="${...} ? 'ritardo'"` | una classe CSS in più, se la condizione è vera |
| `${#temporals.format(data, 'dd/MM/yyyy')}` | una data scritta all'italiana |
| `${#numbers.formatDecimal(n, 1, 2, 'COMMA')}` | 3,50 invece di 3.5 |

Il resto — frammenti, `th:switch`, messaggi da file — sta nel [cheat sheet di
Thymeleaf](../../guida_prova_finale_spring_boot.md#67-thymeleaf-il-cheat-sheet-delle-pagine)
della Guida 2.

## Com'è fatta la pagina

Il CSS sta in un blocco `<style>` in cima alla pagina: per l'esame basta, e
non ci sono file da servire. Poche regole fanno la differenza fra un elenco e
un'applicazione: le tabelle con le righe separate, i messaggi colorati (verde
se è andata, rosso se no), il ritardo in rosso, il form su una riga. Non
serve di più: la commissione guarda che le operazioni funzionino.

> **Prova tu**
>
> Aggiungi sopra il catalogo un campo di ricerca: un form con `method="get"` e
> un `<input name="q">`; nel controller `@RequestParam(required = false) String q`
> e un filtro sui titoli prima di metterli nel modello.

> **Fatto quando**
>
> - [ ] la pagina mostra catalogo e prestiti con ritardo e penale
> - [ ] un prestito con l'email sbagliata torna con il messaggio sotto il campo
> - [ ] dopo un prestito, ricaricare la pagina non ne registra un altro
> - [ ] col catalogo spento la pagina dice che cosa succede invece di dare errore
