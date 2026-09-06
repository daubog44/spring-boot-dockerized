package com.example.ttfcloud_esame.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Richiesta per calcolare l'ubicazione compatibile più vicina")
public class NearestLocationRequest {

    @NotNull(message = "L'ubicazione sorgente è obbligatoria")
    @Schema(description = "ID dell'ubicazione sorgente U", example = "1")
    private Long sourceLocationId;

    @NotNull(message = "La quantità è obbligatoria")
    @Min(value = 1, message = "La quantità da spostare deve essere almeno 1")
    @Schema(description = "Quantità Q di pezzi da spostare", example = "2")
    private Integer quantity;
}
