package com.example.ttfcloud_esame.storeservice;

import java.util.List;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;

@Validated
@RestController
@RequestMapping("/api/suggestions")
@RequiredArgsConstructor
public class SuggestionController {

    private final SuggestionStoreService suggestionStoreService;

    @PostMapping
    public StoredSuggestionResponse store(@Valid @RequestBody EventSuggestion suggestion) {
        return suggestionStoreService.store(suggestion);
    }

    @GetMapping
    public List<StoredSuggestionResponse> latest(
        @RequestParam(defaultValue = "10") @Min(1) @Max(50) int limit
    ) {
        return suggestionStoreService.latest(limit);
    }
}
