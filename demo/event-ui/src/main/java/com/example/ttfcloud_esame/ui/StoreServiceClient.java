package com.example.ttfcloud_esame.ui;

import java.net.URI;
import java.util.List;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;

@Service
public class StoreServiceClient {

    private static final ParameterizedTypeReference<List<StoredSuggestionResponse>> HISTORY_TYPE =
        new ParameterizedTypeReference<>() {
        };

    private final RestClient restClient;
    private final DiscoveryUrlResolver discoveryUrlResolver;
    private final UiProperties uiProperties;

    public StoreServiceClient(
        RestClient.Builder restClientBuilder,
        DiscoveryUrlResolver discoveryUrlResolver,
        UiProperties uiProperties
    ) {
        this.restClient = restClientBuilder == null ? null : restClientBuilder.build();
        this.discoveryUrlResolver = discoveryUrlResolver;
        this.uiProperties = uiProperties;
    }

    public StoredSuggestionResponse store(EventSuggestion suggestion) {
        URI uri = UriComponentsBuilder.fromUri(discoveryUrlResolver.resolve(uiProperties.serviceIds().store()))
            .path("/api/suggestions")
            .build(true)
            .toUri();

        return restClient.post()
            .uri(uri)
            .body(suggestion)
            .retrieve()
            .body(StoredSuggestionResponse.class);
    }

    public List<StoredSuggestionResponse> history(int limit) {
        URI uri = UriComponentsBuilder.fromUri(discoveryUrlResolver.resolve(uiProperties.serviceIds().store()))
            .path("/api/suggestions")
            .queryParam("limit", limit)
            .build(true)
            .toUri();

        List<StoredSuggestionResponse> response = restClient.get()
            .uri(uri)
            .retrieve()
            .body(HISTORY_TYPE);

        return response == null ? List.of() : response;
    }
}
