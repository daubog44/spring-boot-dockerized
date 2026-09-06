package com.example.ttfcloud_esame.crmservice;

import java.util.List;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.CustomerDTO;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/customers")
@RequiredArgsConstructor
@Tag(name = "Anagrafica Clienti CRM API", description = "Servizio Mock CRM per la consultazione dell'anagrafica clienti")
public class CustomerController {

    private final CrmService crmService;

    @GetMapping
    @Operation(summary = "Lista tutti i clienti CRM", description = "Restituisce l'elenco completo dei clienti registrati nel sistema CRM")
    public List<CustomerDTO> getAll() {
        return crmService.findAll();
    }

    @GetMapping("/{id}")
    @Operation(summary = "Recupera un cliente per ID", description = "Restituisce i dettagli del singolo cliente dato il suo ID CRM")
    public CustomerDTO getById(
        @Parameter(description = "ID univoco del cliente", example = "201") @PathVariable Long id
    ) {
        return crmService.findById(id);
    }
}
