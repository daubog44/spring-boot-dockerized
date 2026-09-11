package com.example.ttfcloud_esame.touristservice;

import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.server.ResponseStatusException;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;
import feign.FeignException;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import tools.jackson.databind.JsonNode;

@Service
@Slf4j
@RequiredArgsConstructor
public class TouristCatalogService {

    private final OpenDataHubEventClient openDataHubEventClient;
    private final TouristApiProperties properties;
    private final TouristEventMapper eventMapper;

    public EventSearchResponse findNearbyEvents(
        double latitude,
        double longitude,
        Integer limit,
        Integer radius,
        String language
    ) {
        int safeLimit = limit == null ? properties.defaultLimit() : Math.max(1, limit);
        int safeRadius = radius == null ? properties.defaultRadius() : Math.max(100, radius);
        String safeLanguage = StringUtils.hasText(language) ? language : properties.defaultLanguage();

        try {
            JsonNode response = openDataHubEventClient.searchEvents(
                safeLimit,
                1,
                latitude,
                longitude,
                safeRadius,
                LocalDate.now().toString(),
                true,
                true,
                "upcoming",
                safeLanguage,
                true
            );

            if (response == null) {
                return new EventSearchResponse(0, List.of());
            }

            return eventMapper.mapResponse(response, safeLanguage);
        } catch (FeignException exception) {
            log.error(
                "OpenDataHub call failed with status {} and body {}",
                exception.status(),
                exception.contentUTF8(),
                exception
            );
            throw new ResponseStatusException(
                HttpStatus.BAD_GATEWAY,
                "Impossibile interrogare il servizio turistico esterno",
                exception
            );
        }
    }
}
