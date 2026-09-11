package com.example.ttfcloud_esame.touristservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

@SpringBootApplication(
    scanBasePackages = {
        "com.example.ttfcloud_esame.touristservice",
        "com.example.ttfcloud_esame.common"
    }
)
@EnableFeignClients(basePackageClasses = OpenDataHubEventClient.class)
@EnableDiscoveryClient
@ConfigurationPropertiesScan(basePackageClasses = TouristApiProperties.class)
public class Main {

    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }
}
