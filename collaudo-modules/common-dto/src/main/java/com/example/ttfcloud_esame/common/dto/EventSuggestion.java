package com.example.ttfcloud_esame.common.dto;

import java.time.OffsetDateTime;

import jakarta.validation.constraints.NotBlank;

public record EventSuggestion(
    @NotBlank String eventId,
    @NotBlank String title,
    String description,
    String locationName,
    String municipality,
    String imageUrl,
    String detailUrl,
    Double latitude,
    Double longitude,
    OffsetDateTime startDate,
    OffsetDateTime endDate
) {
}
