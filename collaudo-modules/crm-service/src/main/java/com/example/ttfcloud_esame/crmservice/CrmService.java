package com.example.ttfcloud_esame.crmservice;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

import com.example.ttfcloud_esame.common.dto.CustomerDTO;

import jakarta.annotation.PostConstruct;

@Service
public class CrmService {

    private final Map<Long, CustomerDTO> customerMap = new ConcurrentHashMap<>();

    @PostConstruct
    public void initData() {
        customerMap.put(201L, new CustomerDTO(201L, "Mario Rossi", "Logistica Express Srl", "mario.rossi@logisticaexpress.it"));
        customerMap.put(202L, new CustomerDTO(202L, "Giuseppe Verdi", "Trasporti Nazionali Spa", "g.verdi@trasportinazionali.it"));
        customerMap.put(203L, new CustomerDTO(203L, "Elena Bianchi", "Tech Distribution SpA", "elena@techdistribution.com"));
    }

    public List<CustomerDTO> findAll() {
        return List.copyOf(customerMap.values());
    }

    public CustomerDTO findById(Long id) {
        CustomerDTO customer = customerMap.get(id);
        if (customer == null) {
            throw new IllegalArgumentException("Cliente CRM non trovato con ID: " + id);
        }
        return customer;
    }
}
