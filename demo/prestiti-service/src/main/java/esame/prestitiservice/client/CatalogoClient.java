package esame.prestitiservice.client;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestParam;

import esame.common.dto.LibroDto;

// Il nome e' quello con cui catalogo-service si registra su Eureka
// (spring.application.name): niente URL, lo risolve il load balancer.
@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri/{id}")
    LibroDto libro(@PathVariable("id") Long id);

    @PutMapping("/api/libri/{id}/disponibilita")
    LibroDto cambiaDisponibilita(@PathVariable("id") Long id, @RequestParam("disponibile") boolean disponibile);
}
