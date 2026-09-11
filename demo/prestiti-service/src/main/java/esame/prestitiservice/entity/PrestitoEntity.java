package esame.prestitiservice.entity;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.validation.constraints.Email;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

// Il libro vive in un altro servizio, con il suo database: qui se ne tiene
// solo l'id. Niente chiave esterna, perche' la tabella libri non e' qui.
@Entity
@Table(name = "prestiti")
@Getter
@Setter
@NoArgsConstructor
public class PrestitoEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long libroId;

    @Email
    @Column(nullable = false, length = 120)
    private String utenteEmail;

    @Column(nullable = false)
    private LocalDate dataPrestito;

    @Column(nullable = false)
    private LocalDate dataScadenza;

    private LocalDate dataRestituzione;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatoPrestito stato;
}
