package com.example.bootlezione1;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
public class MainConsole implements CommandLineRunner {

    @Override
    public void run(String... args) throws Exception {
        log.info("Hello World");
    }
}
