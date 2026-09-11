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
@Schema(description = "Richiesta di movimentazione merci da un'ubicazione ad un'altra")
public class StockMovementRequest {

    @NotNull(message = "L'ubicazione di partenza è obbligatoria")
    @Schema(description = "ID dell'ubicazione di partenza", example = "1")
    private Long sourceLocationId;

    @NotNull(message = "L'ubicazione di destinazione è obbligatoria")
    @Schema(description = "ID dell'ubicazione di destinazione", example = "2")
    private Long destLocationId;

    @NotNull(message = "La quantità è obbligatoria")
    @Min(value = 1, message = "La quantità deve essere almeno 1")
    @Schema(description = "Numero di pezzi da spostare", example = "2")
    private Integer quantity;
}
