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
@Schema(description = "Rappresentazione di un Cliente gestito dal CRM")
public class CustomerDTO {

    @Schema(description = "ID univoco del cliente nel CRM", example = "201")
    private Long id;

    @Schema(description = "Nome e cognome del contatto referente", example = "Mario Rossi")
    private String name;

    @Schema(description = "Ragione sociale dell'azienda cliente", example = "Logistica Express Srl")
    private String company;

    @Schema(description = "Indirizzo Email di contatto", example = "mario.rossi@logisticaexpress.it")
    private String email;
}
