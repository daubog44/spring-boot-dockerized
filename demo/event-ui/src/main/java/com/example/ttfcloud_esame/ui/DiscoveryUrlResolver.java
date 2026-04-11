package com.example.ttfcloud_esame.ui;

import java.net.URI;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class DiscoveryUrlResolver {

    private final DiscoveryClient discoveryClient;
    private final UiProperties uiProperties;

    public URI resolve(String serviceId) {
        for (int attempt = 1; attempt <= uiProperties.discoveryAttempts(); attempt++) {
            Optional<URI> resolved = resolveAvailableInstance(serviceId);
            if (resolved.isPresent()) {
                return resolved.get();
            }

            if (attempt < uiProperties.discoveryAttempts()) {
                sleepBeforeRetry(serviceId, attempt);
            }
        }

        throw new IllegalStateException("Servizio non disponibile su Eureka: " + serviceId);
    }

    private Optional<URI> resolveAvailableInstance(String serviceId) {
        List<ServiceInstance> instances = discoveryClient.getInstances(serviceId);
        if (instances.isEmpty()) {
            instances = discoveryClient.getInstances(serviceId.toUpperCase(Locale.ROOT));
        }

        return instances.stream()
            .map(ServiceInstance::getUri)
            .findFirst();
    }

    private void sleepBeforeRetry(String serviceId, int attempt) {
        try {
            Thread.sleep(uiProperties.discoveryDelayMillis());
        } catch (InterruptedException interruptedException) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                "Interrotta l'attesa di registrazione Eureka per il servizio: " + serviceId + " (tentativo " + attempt + ")",
                interruptedException
            );
        }
    }
}
