package com.example.ttfcloud_esame.common.dto;

import java.util.List;

public record EventSearchResponse(int totalResults, List<EventSuggestion> events) {

    public EventSearchResponse {
        events = events == null ? List.of() : List.copyOf(events);
    }
}
