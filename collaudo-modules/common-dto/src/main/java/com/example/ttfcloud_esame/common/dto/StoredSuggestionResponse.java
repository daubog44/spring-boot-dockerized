package com.example.ttfcloud_esame.common.dto;

import java.time.OffsetDateTime;

public record StoredSuggestionResponse(
    Long id,
    String eventId,
    String title,
    String description,
    String locationName,
    String municipality,
    String imageUrl,
    String detailUrl,
    Double latitude,
    Double longitude,
    OffsetDateTime startDate,
    OffsetDateTime endDate,
    OffsetDateTime suggestedAt
) {
}
