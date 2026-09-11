package com.example.ttfcloud_esame.wmsservice.client;

import java.util.List;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

import com.example.ttfcloud_esame.common.dto.CustomerDTO;

@FeignClient(name = "CRM-SERVICE")
public interface CrmClient {

    @GetMapping("/api/customers")
    List<CustomerDTO> getAllCustomers();

    @GetMapping("/api/customers/{id}")
    CustomerDTO getCustomerById(@PathVariable("id") Long id);
}
