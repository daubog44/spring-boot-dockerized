package com.example.ttfcloud_esame.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Rappresentazione di un Prodotto nel catalogo anagrafica")
public class ProductDTO {

    @Schema(description = "ID univoco del prodotto", example = "101")
    private Long id;

    @NotBlank(message = "Il nome del prodotto non può essere vuoto")
    @Schema(description = "Nome del prodotto", example = "Scatola cartone standard")
    private String name;

    @Schema(description = "Descrizione dettagliata del prodotto", example = "Dimensione 30x30x30 cm")
    private String description;

    @NotNull(message = "Il prezzo è obbligatorio")
    @Min(value = 0, message = "Il prezzo non può essere negativo")
    @Schema(description = "Prezzo in euro", example = "15.50")
    private Double price;

    @NotNull(message = "L'ingombro è obbligatorio")
    @Min(value = 1, message = "L'ingombro deve essere almeno 1")
    @Schema(description = "Ingombro fisicità/peso del singolo pezzo (intero positivo)", example = "10")
    private Integer ingombro;
}
