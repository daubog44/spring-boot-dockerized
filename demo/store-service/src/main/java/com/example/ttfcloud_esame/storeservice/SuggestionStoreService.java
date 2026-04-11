package com.example.ttfcloud_esame.storeservice;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import com.example.ttfcloud_esame.common.dto.StoredSuggestionResponse;
import com.example.ttfcloud_esame.storeservice.persistence.SuggestionEntity;
import com.example.ttfcloud_esame.storeservice.persistence.SuggestionRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class SuggestionStoreService {

    private final SuggestionRepository suggestionRepository;

    @Transactional
    public StoredSuggestionResponse store(EventSuggestion suggestion) {
        SuggestionEntity entity = new SuggestionEntity();
        entity.setEventId(suggestion.eventId());
        entity.setTitle(suggestion.title());
        entity.setDescription(suggestion.description());
        entity.setLocationName(suggestion.locationName());
        entity.setMunicipality(suggestion.municipality());
        entity.setImageUrl(suggestion.imageUrl());
        entity.setDetailUrl(suggestion.detailUrl());
        entity.setLatitude(suggestion.latitude());
        entity.setLongitude(suggestion.longitude());
        entity.setStartDate(suggestion.startDate());
        entity.setEndDate(suggestion.endDate());
        entity.setSuggestedAt(OffsetDateTime.now(ZoneOffset.UTC));

        return toResponse(suggestionRepository.save(entity));
    }

    @Transactional(readOnly = true)
    public List<StoredSuggestionResponse> latest(int limit) {
        int safeLimit = Math.max(1, limit);
        return suggestionRepository.findAllByOrderBySuggestedAtDesc(PageRequest.of(0, safeLimit))
            .stream()
            .map(this::toResponse)
            .toList();
    }

    private StoredSuggestionResponse toResponse(SuggestionEntity entity) {
        return new StoredSuggestionResponse(
            entity.getId(),
            entity.getEventId(),
            entity.getTitle(),
            entity.getDescription(),
            entity.getLocationName(),
            entity.getMunicipality(),
            entity.getImageUrl(),
            entity.getDetailUrl(),
            entity.getLatitude(),
            entity.getLongitude(),
            entity.getStartDate(),
            entity.getEndDate(),
            entity.getSuggestedAt()
        );
    }
}
