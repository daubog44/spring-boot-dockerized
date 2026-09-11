package com.example.ttfcloud_esame.ui;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

@Validated
@ConfigurationProperties(prefix = "ui")
public record UiProperties(
    @Min(1) int historyLimit,
    @Min(1) int discoveryAttempts,
    @Min(100) long discoveryDelayMillis,
    @Valid ServiceIds serviceIds
) {

    public record ServiceIds(
        @NotBlank String tourist,
        @NotBlank String random,
        @NotBlank String store
    ) {
    }
}
