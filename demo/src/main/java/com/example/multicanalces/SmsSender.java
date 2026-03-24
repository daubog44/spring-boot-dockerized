package com.example.multicanalces;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@Data
public class SmsSender implements SendService {

    @Autowired
    private TtfConfig config;

    @Override
    public void sendMsg(String msg, String recv) {
        log.info("SMS SERVER: {}", config.sms);
        log.info("SMS: {} -> {}", msg, recv);
    }

}
