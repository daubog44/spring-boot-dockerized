package com.example.ttfcloud_esame.ui;

import java.net.URI;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import com.example.ttfcloud_esame.common.dto.RandomNumberResponse;

@Service
public class RandomServiceClient {

    private final RestClient restClient;
    private final DiscoveryUrlResolver discoveryUrlResolver;
    private final UiProperties uiProperties;

    public RandomServiceClient(
        RestClient.Builder restClientBuilder,
        DiscoveryUrlResolver discoveryUrlResolver,
        UiProperties uiProperties
    ) {
        this.restClient = restClientBuilder == null ? null : restClientBuilder.build();
        this.discoveryUrlResolver = discoveryUrlResolver;
        this.uiProperties = uiProperties;
    }

    public int pickIndex(int upperBound) {
        URI uri = UriComponentsBuilder.fromUri(discoveryUrlResolver.resolve(uiProperties.serviceIds().random()))
            .path("/api/random")
            .queryParam("upperBound", upperBound)
            .build(true)
            .toUri();

        RandomNumberResponse response = restClient.get()
            .uri(uri)
            .retrieve()
            .body(RandomNumberResponse.class);

        if (response == null) {
            throw new IllegalStateException("Il random-service non ha restituito un valore valido");
        }

        return response.value();
    }
}
