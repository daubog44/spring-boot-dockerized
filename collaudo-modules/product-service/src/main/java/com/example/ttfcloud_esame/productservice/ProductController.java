package com.example.ttfcloud_esame.productservice;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.ProductDTO;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
@Tag(name = "Anagrafica Prodotti API", description = "Servizio REST per la gestione del catalogo prodotti")
public class ProductController {

    private final ProductService productService;

    @GetMapping
    @Operation(summary = "Lista tutti i prodotti", description = "Restituisce l'elenco completo dei prodotti a catalogo")
    public List<ProductDTO> getAll() {
        return productService.findAll();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Recupera un prodotto per ID", description = "Restituisce i dettagli del singolo prodotto dato il suo ID numerico")
    public ProductDTO getById(
        @Parameter(description = "ID del prodotto", example = "101") @PathVariable Long id
    ) {
        return productService.findById(id);
    }

    @GetMapping("/search")
    @Operation(summary = "Cerca prodotti per nome/descrizione", description = "Filtra i prodotti contenenti la stringa cercata nel nome o nella descrizione")
    public List<ProductDTO> search(
        @Parameter(description = "Testo da cercare", example = "cartone") @RequestParam String query
    ) {
        return productService.search(query);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Crea un nuovo prodotto", description = "Inserisce un nuovo prodotto nel catalogo anagrafica")
    public ProductDTO create(@Valid @RequestBody ProductDTO dto) {
        return productService.save(dto);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Cancella un prodotto per ID", description = "Rimuove un prodotto esistente tramite il suo ID numerico")
    public void delete(
        @Parameter(description = "ID del prodotto da cancellare", example = "101") @PathVariable Long id
    ) {
        productService.delete(id);
    }
}
