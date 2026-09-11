package com.example.ttfcloud_esame.ui;

import java.util.List;

import org.springframework.stereotype.Service;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;
import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class SuggestionFacade {

    private final TouristServiceClient touristServiceClient;
    private final RandomServiceClient randomServiceClient;
    private final StoreServiceClient storeServiceClient;
    private final UiProperties uiProperties;

    public SuggestionWorkflowResult pickSuggestion(SuggestionForm form) {
        EventSearchResponse response = touristServiceClient.findNearby(form);
        if (response.events().isEmpty()) {
            throw new IllegalStateException("Nessun evento trovato con i parametri indicati");
        }

        int selectedIndex = randomServiceClient.pickIndex(response.events().size());
        EventSuggestion selectedEvent = response.events().get(selectedIndex);
        storeServiceClient.store(selectedEvent);

        List<StoredSuggestionResponse> history = storeServiceClient.history(uiProperties.historyLimit());
        return new SuggestionWorkflowResult(selectedEvent, selectedIndex, response.events().size(), history);
    }

    public List<StoredSuggestionResponse> history() {
        return storeServiceClient.history(uiProperties.historyLimit());
    }

    public record SuggestionWorkflowResult(
        EventSuggestion selectedEvent,
        int selectedIndex,
        int availableCount,
        List<StoredSuggestionResponse> history
    ) {
    }
}
