package com.example.ttfcloud.exchangeservice;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@RestController
public class ExchangeServiceController {

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class ExchangeResult {
        String from;
        String to;
        float rate;
        ExchangeConfig cfg;
        int port;
    }

    @Value("${server.port}")
    int port;
    @Autowired
    ExchangeConfig cfg;

    @GetMapping("/exchange/from/{from}/to/{to}")
    public ExchangeResult getExchange(@PathVariable String from, @PathVariable String to) {
        return new ExchangeResult(from, to, 1.25f, cfg, port);
    }
}
