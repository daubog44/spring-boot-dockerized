package com.example.multicanalces;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;

import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
public class NotificationMenager {
    @Autowired
    @Qualifier("emailSender")
    private SendService emailService;

    @Autowired
    @Qualifier("smsSender")
    private SendService smsService;

    public void dispatch(String msg, String tasget) {
        log.info("Dispatching message {} to {}", msg, tasget);

        emailService.sendMsg(msg, tasget);
        smsService.sendMsg(msg, tasget);
    }
}
