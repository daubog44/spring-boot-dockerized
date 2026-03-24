package com.example.multicanalces;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
@Data
public class EmailSender implements SendService {

    @Autowired
    private TtfConfig config;

    @Override
    public void sendMsg(String msg, String recv) {
        log.info("EMAIL SERVER: {}", config.email);
        log.info("EMAIL: {} -> {}", msg, recv);
    }

}
