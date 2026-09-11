package esame.bibliotecaui;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

/**
 * I campi del form "Nuovo prestito". Una classe con getter e setter, non un
 * record: Thymeleaf (th:field) e Spring (il binding della POST) lavorano con
 * le proprieta' JavaBean. I messaggi sono quelli che vede l'utente.
 */
@Getter
@Setter
public class PrestitoForm {

    @NotNull(message = "Scegli un libro")
    private Long libroId;

    @NotBlank(message = "Serve l'email di chi prende il libro")
    @Email(message = "Questa non e' un'email")
    private String utenteEmail;

    @NotNull(message = "Quanti giorni?")
    @Min(value = 1, message = "Almeno un giorno")
    @Max(value = 60, message = "Al massimo 60 giorni")
    private Integer giorni = 30;
}
