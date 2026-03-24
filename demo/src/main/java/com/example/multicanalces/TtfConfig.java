package com.example.multicanalces;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Data;

@Component
@Data
@ConfigurationProperties(prefix = "ttf")
public class TtfConfig {
    SmsConfig sms;
    EmailConfig email;

    @Data
    public static class SmsConfig {
        private String server, token;
    }

    @Data
    public static class EmailConfig {
        private String server, username, password;
        private int port;
    }
}
