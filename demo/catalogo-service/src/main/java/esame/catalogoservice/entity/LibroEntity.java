package esame.catalogoservice.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "libri")
@Getter
@Setter
@NoArgsConstructor
public class LibroEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String titolo;

    // ISBN-13: tredici cifre che cominciano con 978 o 979.
    @Pattern(regexp = "97[89][0-9]{10}")
    @Column(nullable = false, unique = true, length = 13)
    private String isbn;

    @Min(1450)
    @Max(2100)
    private Integer annoPubblicazione;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Genere genere;

    @Column(nullable = false)
    private Boolean disponibile;

    // Molti libri, un autore: la colonna autore_id sta nella tabella libri.
    @ManyToOne(optional = false)
    @JoinColumn(name = "autore_id", nullable = false)
    private AutoreEntity autore;
}
