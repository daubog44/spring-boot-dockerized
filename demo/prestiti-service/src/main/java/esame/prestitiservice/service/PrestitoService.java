package esame.prestitiservice.service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import esame.common.dto.LibroDto;
import esame.common.dto.NuovoPrestitoRequest;
import esame.common.dto.PrestitoDto;
import esame.prestitiservice.client.CatalogoClient;
import esame.prestitiservice.entity.PrestitoEntity;
import esame.prestitiservice.entity.StatoPrestito;
import esame.prestitiservice.repository.PrestitoRepository;
import feign.FeignException;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PrestitoService {

    static final int GIORNI_DEFAULT = 30;
    static final BigDecimal PENALE_GIORNALIERA = new BigDecimal("0.50");
    static final BigDecimal PENALE_MASSIMA = new BigDecimal("20.00");

    private final PrestitoRepository prestiti;
    private final CatalogoClient catalogo;

    public List<PrestitoDto> tutti() {
        LocalDate oggi = LocalDate.now();
        // Un titolo per libro, non uno per prestito: lo stesso libro puo'
        // comparire in piu' prestiti, e ogni titolo e' una chiamata Feign.
        Map<Long, String> titoli = new HashMap<>();
        return prestiti.findAll().stream()
                .map(p -> toDto(p, titoli.computeIfAbsent(p.getLibroId(), this::titolo), oggi))
                .toList();
    }

    @Transactional
    public PrestitoDto presta(NuovoPrestitoRequest richiesta) {
        LibroDto libro;
        try {
            libro = catalogo.libro(richiesta.libroId());
        } catch (FeignException.NotFound e) {
            // Il 404 del catalogo diventa il nostro 404, con un messaggio chiaro.
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "Libro " + richiesta.libroId() + " non presente nel catalogo");
        }
        if (!libro.disponibile() || prestiti.existsByLibroIdAndStato(libro.id(), StatoPrestito.IN_CORSO)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "\"" + libro.titolo() + "\" e' gia' in prestito");
        }

        LocalDate oggi = LocalDate.now();
        int giorni = richiesta.giorni() == null ? GIORNI_DEFAULT : richiesta.giorni();
        PrestitoEntity prestito = new PrestitoEntity();
        prestito.setLibroId(libro.id());
        prestito.setUtenteEmail(richiesta.utenteEmail());
        prestito.setDataPrestito(oggi);
        prestito.setDataScadenza(oggi.plusDays(giorni));
        prestito.setStato(StatoPrestito.IN_CORSO);
        prestiti.save(prestito);

        catalogo.cambiaDisponibilita(libro.id(), false);
        return toDto(prestito, libro.titolo(), oggi);
    }

    @Transactional
    public PrestitoDto restituisci(Long id) {
        PrestitoEntity prestito = prestiti.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Prestito " + id + " non trovato"));
        if (prestito.getStato() == StatoPrestito.RESTITUITO) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Il prestito " + id + " e' gia' chiuso");
        }
        LocalDate oggi = LocalDate.now();
        prestito.setStato(StatoPrestito.RESTITUITO);
        prestito.setDataRestituzione(oggi);
        catalogo.cambiaDisponibilita(prestito.getLibroId(), true);
        return toDto(prestito, titolo(prestito.getLibroId()), oggi);
    }

    // --- L'algoritmo della penale -------------------------------------------
    // 0,50 euro per ogni giorno oltre la scadenza, fino a un massimo di 20
    // euro. Per un prestito ancora aperto il ritardo si conta fino a oggi, per
    // uno chiuso fino al giorno della restituzione. Due funzioni pure, senza
    // database ne' Feign: si provano con un test in un attimo.

    static long giorniRitardo(LocalDate scadenza, LocalDate riferimento) {
        return Math.max(0, ChronoUnit.DAYS.between(scadenza, riferimento));
    }

    static BigDecimal penale(long giorniRitardo) {
        return PENALE_GIORNALIERA.multiply(BigDecimal.valueOf(giorniRitardo)).min(PENALE_MASSIMA);
    }

    private PrestitoDto toDto(PrestitoEntity p, String titolo, LocalDate oggi) {
        LocalDate riferimento = p.getDataRestituzione() != null ? p.getDataRestituzione() : oggi;
        long ritardo = giorniRitardo(p.getDataScadenza(), riferimento);
        return new PrestitoDto(p.getId(), p.getLibroId(), titolo, p.getUtenteEmail(), p.getDataPrestito(),
                p.getDataScadenza(), p.getStato().name(), ritardo, penale(ritardo));
    }

    private String titolo(Long libroId) {
        try {
            return catalogo.libro(libroId).titolo();
        } catch (FeignException e) {
            // Il catalogo non risponde, o il libro non c'e' piu': il prestito
            // si mostra lo stesso.
            return "(libro " + libroId + ")";
        }
    }
}
