package com.example.ttfcloud_esame.storeservice;

import java.util.List;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/suggestions")
@RequiredArgsConstructor
@Tag(name = "Suggestion Store API", description = "Servizio REST per la persistenza ed il recupero dello storico suggerimenti")
public class SuggestionController {

    private final SuggestionStoreService suggestionStoreService;

    @PostMapping
    @Operation(summary = "Salva suggerimento evento", description = "Persiste un nuovo suggerimento di evento nel database PostgreSQL")
    public StoredSuggestionResponse store(@Valid @RequestBody EventSuggestion suggestion) {
        return suggestionStoreService.store(suggestion);
    }

    @GetMapping
    @Operation(summary = "Recupera storico suggerimenti", description = "Restituisce gli ultimi N suggerimenti salvati in ordine decrescente")
    public List<StoredSuggestionResponse> latest(
        @Parameter(description = "Numero massimo di suggerimenti da recuperare (1-50)", example = "10") @RequestParam(defaultValue = "10") @Min(1) @Max(50) int limit
    ) {
        return suggestionStoreService.latest(limit);
    }
}
