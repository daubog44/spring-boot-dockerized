package com.example.ttfcloud_esame.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Esito della movimentazione merci")
public class StockMovementResult {

    @Schema(description = "Esito positivo o negativo dell'operazione", example = "true")
    private boolean success;

    @Schema(description = "Messaggio esplicativo di successo o d'errore", example = "Spostamento effettuato con successo")
    private String message;

    @Schema(description = "Stato aggiornato dell'ubicazione di partenza")
    private LocationDTO sourceLocation;

    @Schema(description = "Stato aggiornato dell'ubicazione di destinazione")
    private LocationDTO destLocation;
}
