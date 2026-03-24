package com.example.ttfcloud.convertionservice;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@RestController
@RequestMapping("convertion")
public class ConvertionServiceController {

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class Response {
        String from, to;
        float exchangeRate, amount, convertedAmount;
    }

    @GetMapping("convert/{amount}/from/{from}/to/{to}")
    public Response convert(@PathVariable float amount, @PathVariable String from, @PathVariable String to) {
        return new Response(from, to, 1.25f, amount, amount * 1.25f);
    }
}
