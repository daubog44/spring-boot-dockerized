package esame.bibliotecaui.client;

import java.util.List;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;

import esame.common.dto.NuovoPrestitoRequest;
import esame.common.dto.PrestitoDto;

// Le stesse firme del PrestitoController di prestiti-service, con gli stessi
// DTO di common-dto: Feign scrive la richiesta HTTP, Jackson il JSON.
@FeignClient(name = "PRESTITI-SERVICE")
public interface PrestitiClient {

    @GetMapping("/api/prestiti")
    List<PrestitoDto> prestiti();

    @PostMapping("/api/prestiti")
    PrestitoDto presta(@RequestBody NuovoPrestitoRequest richiesta);

    @PutMapping("/api/prestiti/{id}/restituzione")
    PrestitoDto restituisci(@PathVariable("id") Long id);
}
