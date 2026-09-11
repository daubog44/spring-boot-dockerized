package esame.prestitiservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import esame.prestitiservice.entity.PrestitoEntity;
import esame.prestitiservice.entity.StatoPrestito;

public interface PrestitoRepository extends JpaRepository<PrestitoEntity, Long> {

    // ... WHERE libro_id = ? AND stato = ?, e dice solo se c'e' almeno una riga.
    boolean existsByLibroIdAndStato(Long libroId, StatoPrestito stato);
}
