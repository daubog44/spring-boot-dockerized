package com.example.ttfcloud_esame.ui;

import java.net.URI;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;

@Service
public class TouristServiceClient {

    private final RestClient restClient;
    private final DiscoveryUrlResolver discoveryUrlResolver;
    private final UiProperties uiProperties;

    public TouristServiceClient(
        RestClient.Builder restClientBuilder,
        DiscoveryUrlResolver discoveryUrlResolver,
        UiProperties uiProperties
    ) {
        this.restClient = restClientBuilder == null ? null : restClientBuilder.build();
        this.discoveryUrlResolver = discoveryUrlResolver;
        this.uiProperties = uiProperties;
    }

    public EventSearchResponse findNearby(SuggestionForm form) {
        URI uri = UriComponentsBuilder.fromUri(discoveryUrlResolver.resolve(uiProperties.serviceIds().tourist()))
            .path("/api/events/nearby")
            .queryParam("latitude", form.getLatitude())
            .queryParam("longitude", form.getLongitude())
            .queryParam("radius", form.getRadius())
            .queryParam("limit", form.getLimit())
            .queryParam("language", form.getLanguage())
            .build(true)
            .toUri();

        EventSearchResponse response = restClient.get()
            .uri(uri)
            .retrieve()
            .body(EventSearchResponse.class);

        return response == null ? new EventSearchResponse(0, List.of()) : response;
    }
}
