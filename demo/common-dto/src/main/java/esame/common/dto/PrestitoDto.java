package esame.common.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Un prestito, con il ritardo e la penale gia' calcolati. */
public record PrestitoDto(
        Long id,
        Long libroId,
        String titoloLibro,
        String utenteEmail,
        LocalDate dataPrestito,
        LocalDate dataScadenza,
        String stato,
        long giorniRitardo,
        BigDecimal penale) {
}
