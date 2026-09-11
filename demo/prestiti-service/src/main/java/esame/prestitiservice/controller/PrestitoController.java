package esame.prestitiservice.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import esame.common.dto.NuovoPrestitoRequest;
import esame.common.dto.PrestitoDto;
import esame.prestitiservice.service.PrestitoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

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
