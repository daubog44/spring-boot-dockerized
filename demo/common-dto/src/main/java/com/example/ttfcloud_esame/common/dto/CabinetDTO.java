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
@Schema(description = "Armadio situato nella griglia di magazzino")
public class CabinetDTO {

    @Schema(description = "ID univoco dell'armadio", example = "1")
    private Long id;

    @Schema(description = "Indice Fila (riga) nella griglia", example = "5")
    private Integer row;

    @Schema(description = "Indice Colonna nella griglia", example = "8")
    private Integer col;

    @Schema(description = "Nome/Codice identificativo dell'armadio", example = "Armadio Fila 5 Col 8")
    private String name;
}
