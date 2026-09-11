package com.example.ttfcloud_esame.wmsservice;

import java.util.List;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.CabinetDTO;
import com.example.ttfcloud_esame.common.dto.LocationDTO;
import com.example.ttfcloud_esame.common.dto.NearestLocationRequest;
import com.example.ttfcloud_esame.common.dto.NearestLocationResponse;
import com.example.ttfcloud_esame.common.dto.StockMovementRequest;
import com.example.ttfcloud_esame.common.dto.StockMovementResult;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/wms")
@RequiredArgsConstructor
@Tag(name = "WMS Magazzino API", description = "Servizio REST per la gestione di armadi, giacenze, movimentazioni merci ed algoritmi di ricerca")
public class WmsController {

    private final WmsService wmsService;

    @GetMapping("/cabinets")
    @Operation(summary = "Lista tutti gli armadi", description = "Restituisce l'elenco degli armadi presenti nella griglia del magazzino")
    public List<CabinetDTO> getCabinets() {
        return wmsService.getAllCabinets();
    }

    @GetMapping("/locations")
    @Operation(summary = "Lista ubicazioni per armadio", description = "Restituisce tutte le ubicazioni (o quelle del singolo armadio filtrato)")
    public List<LocationDTO> getLocations(
        @Parameter(description = "ID dell'armadio (opzionale)", example = "1") @RequestParam(required = false) Long cabinetId
    ) {
        return wmsService.getLocationsByCabinet(cabinetId);
    }

    @GetMapping("/locations/{id}")
    @Operation(summary = "Recupera una specifica ubicazione", description = "Restituisce i dettagli di giacenza e ingombro dell'ubicazione")
    public LocationDTO getLocationById(
        @Parameter(description = "ID dell'ubicazione", example = "1") @PathVariable Long id
    ) {
        return wmsService.getLocationById(id);
    }

    @PostMapping("/movements")
    @Operation(summary = "Effettua movimentazione merci", description = "Sposta pezzi da un'ubicazione ad un'altra con controlli di validazione (quantità, ingombro, prodotto, cliente)")
    public StockMovementResult moveStock(@Valid @RequestBody StockMovementRequest request) {
        return wmsService.moveStock(request);
    }

    @PostMapping("/nearest-location")
    @Operation(summary = "Calcola l'ubicazione più vicina", description = "Algoritmo che identifica l'ubicazione idonea più vicina (Distanza di Manhattan)")
    public NearestLocationResponse findNearestLocation(@Valid @RequestBody NearestLocationRequest request) {
        return wmsService.findNearestLocation(request);
    }
}
