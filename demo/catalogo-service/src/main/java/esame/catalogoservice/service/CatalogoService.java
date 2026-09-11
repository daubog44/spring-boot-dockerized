package esame.catalogoservice.service;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import esame.catalogoservice.entity.AutoreEntity;
import esame.catalogoservice.entity.LibroEntity;
import esame.catalogoservice.repository.LibroRepository;
import esame.common.dto.LibroDto;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class CatalogoService {

    private final LibroRepository libri;

    public List<LibroDto> tutti() {
        return libri.findAll().stream().map(CatalogoService::toDto).toList();
    }

    public List<LibroDto> disponibili() {
        return libri.findByDisponibileTrue().stream().map(CatalogoService::toDto).toList();
    }

    public LibroDto perId(Long id) {
        return toDto(trova(id));
    }

    // Dentro una transazione l'entity e' "gestita": basta cambiarla, e
    // Hibernate scrive l'UPDATE da solo alla fine del metodo.
    @Transactional
    public LibroDto cambiaDisponibilita(Long id, boolean disponibile) {
        LibroEntity libro = trova(id);
        libro.setDisponibile(disponibile);
        return toDto(libro);
    }

    private LibroEntity trova(Long id) {
        return libri.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Libro " + id + " non trovato"));
    }

    // Fuori dal servizio esce il DTO, mai l'entity: l'autore diventa una
    // stringa, e chi chiama non dipende da come e' fatto il database.
    static LibroDto toDto(LibroEntity libro) {
        AutoreEntity autore = libro.getAutore();
        return new LibroDto(
                libro.getId(),
                libro.getTitolo(),
                libro.getIsbn(),
                libro.getAnnoPubblicazione(),
                libro.getGenere() == null ? null : libro.getGenere().name(),
                Boolean.TRUE.equals(libro.getDisponibile()),
                autore == null ? null : autore.getNome() + " " + autore.getCognome());
    }
}
