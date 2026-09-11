package esame.common.dto;

/** Un libro del catalogo, come lo vede chi lo chiede via Feign. */
public record LibroDto(
        Long id,
        String titolo,
        String isbn,
        Integer annoPubblicazione,
        String genere,
        boolean disponibile,
        String autore) {
}
