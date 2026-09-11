package com.example.ttfcloud_esame.storeservice.persistence;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "event_suggestions")
@Getter
@Setter
public class SuggestionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String eventId;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    private String locationName;
    private String municipality;

    @Column(columnDefinition = "TEXT")
    private String imageUrl;

    @Column(columnDefinition = "TEXT")
    private String detailUrl;

    private Double latitude;
    private Double longitude;
    private OffsetDateTime startDate;
    private OffsetDateTime endDate;

    @Column(nullable = false)
    private OffsetDateTime suggestedAt;

}
