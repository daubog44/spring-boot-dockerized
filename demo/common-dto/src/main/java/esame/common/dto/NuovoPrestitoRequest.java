package esame.common.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Il corpo di POST /api/prestiti. Sta in common-dto perche' lo usano in due:
 * prestiti-service lo riceve, biblioteca-ui lo manda via Feign.
 * Senza giorni, il prestito dura 30 giorni.
 */
public record NuovoPrestitoRequest(
        @NotNull Long libroId,
        @NotBlank @Email String utenteEmail,
        @Min(1) @Max(60) Integer giorni) {
}
