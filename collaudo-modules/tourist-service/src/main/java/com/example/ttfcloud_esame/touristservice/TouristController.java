package com.example.ttfcloud_esame.touristservice;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/events")
@RequiredArgsConstructor
@Tag(name = "Tourist Events API", description = "Servizio REST per la ricerca di eventi turistici tramite OpenDataHub")
public class TouristController {

    private final TouristCatalogService touristCatalogService;

    @GetMapping("/nearby")
    @Operation(summary = "Ricerca eventi nelle vicinanze", description = "Recupera la lista di eventi vicini alle coordinate geografiche inserite")
    public EventSearchResponse nearby(
        @Parameter(description = "Latitudine della posizione", example = "46.4983") @RequestParam double latitude,
        @Parameter(description = "Longitudine della posizione", example = "11.3548") @RequestParam double longitude,
        @Parameter(description = "Numero massimo di risultati (1-20)", example = "5") @RequestParam(required = false) @Min(1) @Max(20) Integer limit,
        @Parameter(description = "Raggio di ricerca in metri (100-100000)", example = "10000") @RequestParam(required = false) @Min(100) @Max(100000) Integer radius,
        @Parameter(description = "Lingua dei contenuti (es: it, de, en)", example = "it") @RequestParam(required = false) String language
    ) {
        return touristCatalogService.findNearbyEvents(latitude, longitude, limit, radius, language);
    }
}
