package com.example.ttfcloud_esame.touristservice;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import com.example.ttfcloud_esame.common.dto.EventSearchResponse;
import com.example.ttfcloud_esame.common.dto.EventSuggestion;
import tools.jackson.databind.JsonNode;

@Component
public class TouristEventMapper {

    public EventSearchResponse mapResponse(JsonNode root, String language) {
        JsonNode items = root.path("Items");
        if (!items.isArray()) {
            return new EventSearchResponse(0, List.of());
        }

        List<EventSuggestion> events = new ArrayList<>();
        for (JsonNode item : items) {
            EventSuggestion mapped = mapItem(item, language);
            if (mapped != null) {
                events.add(mapped);
            }
        }

        int totalResults = root.path("TotalResults").asInt(events.size());
        return new EventSearchResponse(totalResults, events);
    }

    EventSuggestion mapItem(JsonNode item, String language) {
        String eventId = text(item.path("Id"));
        String title = firstNonBlank(
            localizedDetailValue(item.path("Detail"), language, "Title"),
            text(item.path("Shortname")),
            eventId
        );

        if (!StringUtils.hasText(eventId) || !StringUtils.hasText(title)) {
            return null;
        }

        JsonNode firstEventDate = firstArrayElement(item.path("EventDate"));
        JsonNode firstGps = firstArrayElement(item.path("GpsInfo"));
        String startDate = firstNonBlank(
            firstEventDate == null ? null : text(firstEventDate.path("From")),
            text(item.path("DateBegin"))
        );
        String endDate = firstNonBlank(
            firstEventDate == null ? null : text(firstEventDate.path("To")),
            text(item.path("DateEnd"))
        );
        JsonNode latitudeNode = firstGps == null
            ? item.path("Latitude")
            : firstNonBlankNode(firstGps.path("Latitude"), item.path("Latitude"));
        JsonNode longitudeNode = firstGps == null
            ? item.path("Longitude")
            : firstNonBlankNode(firstGps.path("Longitude"), item.path("Longitude"));

        return new EventSuggestion(
            eventId,
            title,
            firstNonBlank(
                localizedDetailValue(item.path("Detail"), language, "BaseText"),
                localizedDetailValue(item.path("Detail"), language, "IntroText")
            ),
            firstNonBlank(
                localizedValue(item.path("LocationInfo").path("DistrictInfo").path("Name"), language),
                localizedValue(item.path("LocationInfo").path("MunicipalityInfo").path("Name"), language),
                text(item.path("ContactInfos").path(language).path("Address"))
            ),
            firstNonBlank(
                localizedValue(item.path("LocationInfo").path("MunicipalityInfo").path("Name"), language),
                text(item.path("ContactInfos").path(language).path("City"))
            ),
            text(item.path("ImageGallery").path(0).path("ImageUrl")),
            firstNonBlank(
                localizedValue(item.path("EventBooking").path("BookingUrl"), language),
                localizedValue(item.path("EventUrls").path(0).path("Url"), language),
                text(item.path("ContactInfos").path(language).path("Url")),
                text(item.path("Self"))
            ),
            numeric(latitudeNode),
            numeric(longitudeNode),
            parseDate(startDate),
            parseDate(endDate)
        );
    }

    private JsonNode firstArrayElement(JsonNode node) {
        return node != null && node.isArray() && !node.isEmpty() ? node.get(0) : null;
    }

    private JsonNode firstNonBlankNode(JsonNode preferred, JsonNode fallback) {
        return preferred != null && !preferred.isMissingNode() && !preferred.isNull() ? preferred : fallback;
    }

    private String localizedDetailValue(JsonNode detailNode, String language, String fieldName) {
        if (detailNode == null || detailNode.isMissingNode() || detailNode.isNull()) {
            return null;
        }

        JsonNode preferredLanguage = detailNode.path(language);
        String preferredValue = text(preferredLanguage.path(fieldName));
        if (StringUtils.hasText(preferredValue)) {
            return preferredValue;
        }

        Iterator<JsonNode> languages = detailNode.iterator();
        while (languages.hasNext()) {
            String value = text(languages.next().path(fieldName));
            if (StringUtils.hasText(value)) {
                return value;
            }
        }

        return null;
    }

    private String localizedValue(JsonNode node, String language) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }

        if (node.isString()) {
            return text(node);
        }

        if (node.isObject()) {
            JsonNode preferred = node.get(language);
            if (preferred != null) {
                String preferredValue = localizedValue(preferred, language);
                if (StringUtils.hasText(preferredValue)) {
                    return preferredValue;
                }
            }

            JsonNode urlNode = node.get("Url");
            if (urlNode != null) {
                String urlValue = localizedValue(urlNode, language);
                if (StringUtils.hasText(urlValue)) {
                    return urlValue;
                }
            }

            Iterator<JsonNode> values = node.iterator();
            while (values.hasNext()) {
                String value = localizedValue(values.next(), language);
                if (StringUtils.hasText(value)) {
                    return value;
                }
            }
        }

        return null;
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (StringUtils.hasText(value)) {
                return value;
            }
        }
        return null;
    }

    private String text(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }

        String value = node.asString();
        return StringUtils.hasText(value) ? value : null;
    }

    private Double numeric(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }
        return node.asDouble();
    }

    private OffsetDateTime parseDate(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }

        try {
            return OffsetDateTime.parse(value);
        } catch (DateTimeParseException ignored) {
        }

        try {
            return LocalDateTime.parse(value).atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException ignored) {
        }

        try {
            return LocalDate.parse(value).atStartOfDay().atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }
}
