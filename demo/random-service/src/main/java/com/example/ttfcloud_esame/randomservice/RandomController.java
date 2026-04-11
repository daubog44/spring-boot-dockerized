package com.example.ttfcloud_esame.randomservice;

import java.util.concurrent.ThreadLocalRandom;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.ttfcloud_esame.common.dto.RandomNumberResponse;

import jakarta.validation.constraints.Min;

@Validated
@RestController
@RequestMapping("/api/random")
public class RandomController {

    @GetMapping
    public RandomNumberResponse random(@RequestParam @Min(1) int upperBound) {
        int value = ThreadLocalRandom.current().nextInt(upperBound);
        return new RandomNumberResponse(upperBound, value);
    }
}
