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
@Schema(description = "Ubicazione fisica all'interno di un armadio con relativo stato delle giacenze")
public class LocationDTO {

    @Schema(description = "ID univoco dell'ubicazione", example = "1123")
    private Long id;

    @Schema(description = "ID dell'armadio di appartenenza", example = "1")
    private Long cabinetId;

    @Schema(description = "Fila dell'armadio", example = "5")
    private Integer cabinetRow;

    @Schema(description = "Colonna dell'armadio", example = "8")
    private Integer cabinetCol;

    @Schema(description = "Ingombro massimo contenibile dall'ubicazione", example = "120")
    private Integer maxIngombro;

    @Schema(description = "Ingombro attualmente occupato dalle merci stoccate", example = "40")
    private Integer currentIngombro;

    @Schema(description = "ID del prodotto stoccato (null se vuota)", example = "101")
    private Long productId;

    @Schema(description = "Nome del prodotto stoccato (arricchito via Feign)", example = "Scatola cartone standard")
    private String productName;

    @Schema(description = "ID del cliente proprietario delle merci (null se vuota)", example = "201")
    private Long customerId;

    @Schema(description = "Dettagli cliente (arricchiti via Feign)", example = "Logistica Express Srl")
    private String customerName;

    @Schema(description = "Numero di pezzi stoccati nell'ubicazione", example = "4")
    private Integer quantity;

    public int getFreeIngombro() {
        return (maxIngombro != null ? maxIngombro : 0) - (currentIngombro != null ? currentIngombro : 0);
    }
}
