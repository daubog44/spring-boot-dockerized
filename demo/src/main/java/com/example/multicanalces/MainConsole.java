package com.example.multicanalces;

import java.util.Scanner;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
public class MainConsole implements CommandLineRunner {

    @Autowired
    private NotificationMenager notificationMenager;

    @Autowired
    private Scanner scanner;

    @Override
    public void run(String... args) throws Exception {
        log.info("Enter message: ");
        String msg = scanner.nextLine();

        log.info("Enter receiver: ");
        String recv = scanner.nextLine();

        notificationMenager.dispatch(msg, recv);
    }
}
