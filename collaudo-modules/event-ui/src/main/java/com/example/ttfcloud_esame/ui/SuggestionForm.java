package com.example.ttfcloud_esame.ui;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class SuggestionForm {

    @NotNull
    @DecimalMin("-90.0")
    @DecimalMax("90.0")
    private Double latitude = 46.4983;

    @NotNull
    @DecimalMin("-180.0")
    @DecimalMax("180.0")
    private Double longitude = 11.3548;

    @NotNull
    @Min(100)
    @Max(100000)
    private Integer radius = 10000;

    @NotNull
    @Min(1)
    @Max(20)
    private Integer limit = 5;

    @NotBlank
    private String language = "it";

}
