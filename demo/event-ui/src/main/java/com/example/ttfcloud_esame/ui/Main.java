package com.example.ttfcloud_esame.ui;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication(
    scanBasePackages = {
        "com.example.ttfcloud_esame.ui",
        "com.example.ttfcloud_esame.common"
    }
)
@EnableDiscoveryClient
@ConfigurationPropertiesScan(basePackageClasses = UiProperties.class)
public class Main {

    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
