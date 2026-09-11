package esame.catalogoservice.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import esame.catalogoservice.entity.LibroEntity;

public interface LibroRepository extends JpaRepository<LibroEntity, Long> {

    // Spring Data scrive la query dal nome: ... WHERE disponibile = true
    List<LibroEntity> findByDisponibileTrue();
}
