package com.example.ttfcloud_esame.randomservice;

import java.util.concurrent.ThreadLocalRandom;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.RandomNumberResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Min;

@Validated
@RestController
@RequestMapping("/api/random")
@Tag(name = "Random Index API", description = "Servizio REST per la generazione di indici numerici casuali")
public class RandomController {

    @GetMapping
    @Operation(summary = "Generazione indice casuale", description = "Restituisce un intero casuale compreso tra 0 (incluso) e upperBound (escluso)")
    public RandomNumberResponse random(
        @Parameter(description = "Limite superiore (escluso) per il numero casuale", example = "5") @RequestParam @Min(1) int upperBound
    ) {
        int value = ThreadLocalRandom.current().nextInt(upperBound);
        return new RandomNumberResponse(upperBound, value);
    }
}
