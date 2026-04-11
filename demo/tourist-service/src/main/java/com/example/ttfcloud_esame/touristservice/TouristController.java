package com.example.ttfcloud_esame.touristservice;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/events")
@RequiredArgsConstructor
public class TouristController {

    private final TouristCatalogService touristCatalogService;

    @GetMapping("/nearby")
    public EventSearchResponse nearby(
        @RequestParam double latitude,
        @RequestParam double longitude,
        @RequestParam(required = false) @Min(1) @Max(20) Integer limit,
        @RequestParam(required = false) @Min(100) @Max(100000) Integer radius,
        @RequestParam(required = false) String language
    ) {
        return touristCatalogService.findNearbyEvents(latitude, longitude, limit, radius, language);
    }
}
