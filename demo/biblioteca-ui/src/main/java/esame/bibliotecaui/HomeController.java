package esame.bibliotecaui;

import java.util.List;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import esame.bibliotecaui.client.CatalogoClient;
import esame.bibliotecaui.client.PrestitiClient;
import esame.common.dto.LibroDto;
import esame.common.dto.NuovoPrestitoRequest;
import esame.common.dto.PrestitoDto;
import feign.FeignException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

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

    @PostMapping("/prestiti/{id}/restituzione")
    public String restituisci(@PathVariable Long id, RedirectAttributes redirect) {
        try {
            PrestitoDto p = prestiti.restituisci(id);
            String penale = p.giorniRitardo() > 0
                    ? " Ritardo di " + p.giorniRitardo() + " giorni: penale di " + p.penale() + " euro."
                    : " Nei tempi, nessuna penale.";
            redirect.addFlashAttribute("messaggio", "\"" + p.titoloLibro() + "\" e' rientrato." + penale);
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
