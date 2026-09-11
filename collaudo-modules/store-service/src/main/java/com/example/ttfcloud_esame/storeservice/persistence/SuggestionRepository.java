package com.example.ttfcloud_esame.storeservice.persistence;

import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SuggestionRepository extends JpaRepository<SuggestionEntity, Long> {

    List<SuggestionEntity> findAllByOrderBySuggestedAtDesc(Pageable pageable);
}
