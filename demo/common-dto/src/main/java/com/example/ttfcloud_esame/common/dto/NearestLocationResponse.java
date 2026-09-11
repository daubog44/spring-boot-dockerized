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
@Schema(description = "Risposta contenente l'ubicazione più vicina identificata dall'algoritmo")
public class NearestLocationResponse {

    @Schema(description = "ID dell'ubicazione sorgente", example = "1")
    private Long sourceLocationId;

    @Schema(description = "Ubicazione più vicina identificata (null se nessuna ubicazione è idonea)")
    private LocationDTO nearestLocation;

    @Schema(description = "Distanza di Manhattan calcolata tra l'armadio di partenza e quello di destinazione", example = "2")
    private Integer distance;

    @Schema(description = "Messaggio esplicativo", example = "Ubicazione trovata nell'armadio A2 (Fila 1, Col 3)")
    private String message;
}
