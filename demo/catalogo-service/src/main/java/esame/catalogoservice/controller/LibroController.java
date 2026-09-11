package esame.catalogoservice.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import esame.catalogoservice.service.CatalogoService;
import esame.common.dto.LibroDto;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

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
