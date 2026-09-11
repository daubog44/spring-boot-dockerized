package esame.prestitiservice.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.junit.jupiter.api.Test;

// L'algoritmo della traccia, provato da solo: niente Spring, niente database,
// niente Feign. Si lancia con
//   cd demo && ./mvnw -pl prestiti-service -am test
class PenaleTest {

    private static final LocalDate SCADENZA = LocalDate.of(2026, 3, 10);

    @Test
    void restituitoInTempoNonHaRitardo() {
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA));
        assertEquals(0, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.minusDays(4)));
    }

    @Test
    void ogniGiornoDopoLaScadenzaConta() {
        assertEquals(7, PrestitoService.giorniRitardo(SCADENZA, SCADENZA.plusDays(7)));
    }

    @Test
    void cinquantaCentesimiAlGiorno() {
        assertEquals(new BigDecimal("3.50"), PrestitoService.penale(7));
    }

    @Test
    void laPenaleSiFermaAVentiEuro() {
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(40));
        assertEquals(new BigDecimal("20.00"), PrestitoService.penale(400));
    }
}
