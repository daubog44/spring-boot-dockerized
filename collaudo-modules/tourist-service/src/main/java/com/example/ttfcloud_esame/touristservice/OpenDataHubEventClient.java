package com.example.ttfcloud_esame.touristservice;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

import tools.jackson.databind.JsonNode;

@FeignClient(name = "openDataHubEventClient", url = "${tourist.api.base-url}")
public interface OpenDataHubEventClient {

    @GetMapping("/v1/Event")
    JsonNode searchEvents(
        @RequestParam("pagesize") int pageSize,
        @RequestParam("pagenumber") int pageNumber,
        @RequestParam("latitude") double latitude,
        @RequestParam("longitude") double longitude,
        @RequestParam("radius") int radius,
        @RequestParam("begindate") String beginDate,
        @RequestParam("active") boolean active,
        @RequestParam("odhactive") boolean odhActive,
        @RequestParam("sort") String sort,
        @RequestParam("language") String language,
        @RequestParam("removenullvalues") boolean removeNullValues
    );
}
