package com.example.ttfcloud.exchangeservice;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Data;

@Data
@Component
@ConfigurationProperties(prefix = "exchange")
public class ExchangeConfig {
    private String disclaimer;
    private int delay;
}
