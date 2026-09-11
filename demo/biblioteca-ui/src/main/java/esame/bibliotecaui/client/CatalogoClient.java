package esame.bibliotecaui.client;

import java.util.List;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;

import esame.common.dto.LibroDto;

@FeignClient(name = "CATALOGO-SERVICE")
public interface CatalogoClient {

    @GetMapping("/api/libri")
    List<LibroDto> libri();
}
