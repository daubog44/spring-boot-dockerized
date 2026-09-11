package com.example.ttfcloud_esame.touristservice;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

@Validated
@ConfigurationProperties(prefix = "tourist.api")
public record TouristApiProperties(
    @NotBlank String baseUrl,
    @NotBlank String defaultLanguage,
    @Min(1) int defaultLimit,
    @Min(100) int defaultRadius
) {
}
